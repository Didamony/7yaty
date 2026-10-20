import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/store.dart';
import 'files.dart';

/// The Firebase project, passed at build time with
/// `--dart-define-from-file` (see README and the GitHub workflows).
abstract final class CloudConfig {
  static const apiKey = String.fromEnvironment('FB_API_KEY');
  static const authDomain = String.fromEnvironment('FB_AUTH_DOMAIN');
  static const projectId = String.fromEnvironment('FB_PROJECT_ID');
  static const bucket = String.fromEnvironment('FB_STORAGE_BUCKET');
  static const senderId = String.fromEnvironment('FB_SENDER_ID');
  static const webAppId = String.fromEnvironment('FB_WEB_APP_ID');
  static const androidAppId = String.fromEnvironment('FB_ANDROID_APP_ID');

  /// Talk to the local Firebase emulators instead (for testing).
  static const emulator = bool.fromEnvironment('FB_EMULATOR');

  static bool get configured => apiKey.isNotEmpty && projectId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey,
    appId: kIsWeb || androidAppId.isEmpty ? webAppId : androidAppId,
    messagingSenderId: senderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: bucket.isEmpty ? null : bucket,
  );
}

/// The account that activates others and sets the payment details. Must
/// match `firestore.rules` and `storage.rules`.
const adminEmail = 'medsyncplus@gmail.com';

/// How long a new account can use the app before paying. Must match the
/// rules.
const trialLength = Duration(hours: 2);

/// Whether an account may use the app: paid once for life, or still in its
/// free trial. Kept in Firestore at `access/{uid}`; only the admin can mark
/// it paid.
class Access {
  Access({required this.uid, this.email, this.trialStart, this.paid = false});

  final String uid;
  final String? email;
  final DateTime? trialStart;
  final bool paid;

  DateTime? get trialEnd => trialStart?.add(trialLength);

  bool inTrial(DateTime now) => trialEnd != null && now.isBefore(trialEnd!);

  bool allowed(DateTime now) => paid || inTrial(now);

  factory Access.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final j = d.data() ?? {};
    return Access(
      uid: d.id,
      email: j['email'] as String?,
      trialStart: (j['trialStart'] as Timestamp?)?.toDate(),
      paid: j['paid'] == true,
    );
  }
}

/// The owner's InstaPay address, used until the admin sets another.
const defaultInstapay = 'didamony372@instapay';

/// Payment details shown to users whose trial ended, set by the admin.
class PayInfo {
  PayInfo({this.price = '', this.instapay = defaultInstapay, this.link = ''});

  /// e.g. "300 جنيه".
  String price;

  /// InstaPay address or phone number to send to.
  String instapay;

  /// Optional InstaPay payment link.
  String link;

  Map<String, dynamic> toJson() => {
    'price': price,
    'instapay': instapay,
    'link': link,
  };

  factory PayInfo.fromJson(Map<String, dynamic>? j) => PayInfo(
    price: j?['price'] ?? '',
    instapay: (j?['instapay'] as String?)?.isNotEmpty == true
        ? j!['instapay']
        : defaultInstapay,
    link: j?['link'] ?? '',
  );
}

/// A user's word that they paid, for the owner to check against InstaPay.
/// Kept at `requests/{uid}`.
class PayRequest {
  PayRequest({
    required this.uid,
    required this.email,
    required this.name,
    required this.from,
    required this.amount,
    required this.ref,
    required this.code,
    this.at,
    this.status = 'pending',
  });

  final String uid;
  final String email;

  /// Sender's name as InstaPay shows it.
  final String name;

  /// The phone or InstaPay address they paid from.
  final String from;
  final String amount;

  /// InstaPay's reference number for the transfer.
  final String ref;

  /// The account's code, written as the transfer's reason.
  final String code;
  final DateTime? at;

  /// pending, approved or rejected.
  final String status;

  Map<String, dynamic> toJson() => {
    'email': email,
    'name': name,
    'from': from,
    'amount': amount,
    'ref': ref,
    'code': code,
    'at': FieldValue.serverTimestamp(),
    'status': 'pending',
  };

  factory PayRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final j = d.data() ?? {};
    return PayRequest(
      uid: d.id,
      email: j['email'] ?? '',
      name: j['name'] ?? '',
      from: j['from'] ?? '',
      amount: j['amount'] ?? '',
      ref: j['ref'] ?? '',
      code: j['code'] ?? '',
      at: (j['at'] as Timestamp?)?.toDate(),
      status: j['status'] ?? 'pending',
    );
  }
}

/// A short code for the account, for the user to write as the transfer's
/// reason so the owner can tell whose payment it is.
String activationCode(String uid) => 'HY-${uid.substring(0, 6).toUpperCase()}';

/// Folders whose files are kept in the cloud.
const _folders = ['recordings', 'books', 'media'];

/// Firestore keeps documents under 1 MiB; the data goes in parts.
const _partSize = 500000;

/// Who owns the data on this device, so another account never sees it.
const _ownerKey = 'hayati.owner';

/// The user's account (email and password, with a confirmed email) and a
/// copy of all their data in Firebase, so it comes back on any device,
/// however long after.
///
/// Firestore: `users/{uid}` holds when it was saved and which files are
/// stored; `users/{uid}/parts/{i}` hold the data JSON. Cloud Storage:
/// `users/{uid}/{folder}/{name}` holds recordings, books and pictures.
class Cloud extends ChangeNotifier {
  Cloud._();

  static final instance = Cloud._();

  bool _ready = false;
  bool busy = false;
  String? error;
  Timer? _debounce;
  StreamSubscription<User?>? _sub;

  bool get enabled => CloudConfig.configured && _ready;
  User? get user => enabled ? FirebaseAuth.instance.currentUser : null;
  bool get signedIn => user != null;
  bool get verified => (user?.emailVerified ?? false) && !_tokenStale;

  /// The email was just confirmed but the sign-in token doesn't say so yet,
  /// so the database would still refuse this account.
  bool _tokenStale = false;

  bool get isAdmin =>
      verified && user?.email?.toLowerCase() == adminEmail.toLowerCase();

  /// Whether this account may use the app now; saving to the cloud waits
  /// for it. Set by the sign-in gate.
  bool allowed = false;

  // -------------------------------------------------------------- access

  CollectionReference<Map<String, dynamic>> get _access =>
      FirebaseFirestore.instance.collection('access');

  DocumentReference<Map<String, dynamic>> get _payDoc =>
      FirebaseFirestore.instance.collection('config').doc('pay');

  /// This account's access, starting its free trial on first use.
  Future<Access> loadAccess() async {
    final ref = _access.doc(user!.uid);
    var snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'trialStart': FieldValue.serverTimestamp(),
        'email': user!.email,
      });
      snap = await ref.get();
    }
    return Access.fromDoc(snap);
  }

  Future<PayInfo> loadPayInfo() async =>
      PayInfo.fromJson((await _payDoc.get()).data());

  Future<void> savePayInfo(PayInfo info) => _payDoc.set(info.toJson());

  CollectionReference<Map<String, dynamic>> get _requests =>
      FirebaseFirestore.instance.collection('requests');

  /// This account's payment request, if it sent one.
  Future<PayRequest?> myRequest() async {
    final d = await _requests.doc(user!.uid).get();
    return d.exists ? PayRequest.fromDoc(d) : null;
  }

  /// Saves the user's payment details for the owner's panel.
  Future<void> sendRequest(PayRequest r) =>
      _requests.doc(r.uid).set(r.toJson());

  /// Payment requests, newest first, as they come.
  Stream<List<PayRequest>> watchRequests() => _requests
      .orderBy('at', descending: true)
      .limit(200)
      .snapshots()
      .map((q) => q.docs.map(PayRequest.fromDoc).toList());

  /// Activates the account for life and closes its request.
  Future<void> approve(String uid) async {
    final batch = FirebaseFirestore.instance.batch()
      ..update(_access.doc(uid), {
        'paid': true,
        'paidAt': FieldValue.serverTimestamp(),
      });
    final req = await _requests.doc(uid).get();
    if (req.exists) batch.update(req.reference, {'status': 'approved'});
    await batch.commit();
  }

  Future<void> reject(String uid) =>
      _requests.doc(uid).update({'status': 'rejected'});

  /// Newest accounts first, for the admin.
  Future<List<Access>> recentAccounts() async {
    final q = await _access
        .orderBy('trialStart', descending: true)
        .limit(200)
        .get();
    return q.docs.map(Access.fromDoc).toList();
  }

  Future<Access?> findAccount(String email) async {
    final q = await _access
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    return q.docs.isEmpty ? null : Access.fromDoc(q.docs.first);
  }

  Future<void> setPaid(String uid, bool paid) => _access.doc(uid).update({
    'paid': paid,
    'paidAt': paid ? FieldValue.serverTimestamp() : null,
  });

  Future<void> init(String lang) async {
    if (!CloudConfig.configured || _ready) return;
    try {
      await Firebase.initializeApp(options: CloudConfig.options);
      final auth = FirebaseAuth.instance;
      if (CloudConfig.emulator) {
        await auth.useAuthEmulator('localhost', 9099);
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
      }
      await auth.setLanguageCode(lang);
      _ready = true;
      _sub = auth.userChanges().listen((_) => notifyListeners());
    } catch (e) {
      error = '$e';
      debugPrint('hayati: Firebase did not start: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- account

  Future<void> signUp(String email, String password) async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.sendEmailVerification();
  }

  Future<void> signIn(String email, String password) => FirebaseAuth.instance
      .signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> sendVerification() async =>
      FirebaseAuth.instance.currentUser?.sendEmailVerification();

  /// Checks again whether the email was confirmed.
  Future<bool> refresh() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;
    if (!u.emailVerified) _tokenStale = true;
    try {
      await u.reload();
      // Fresh token, so the database rules see the confirmed email.
      if (FirebaseAuth.instance.currentUser!.emailVerified) {
        await FirebaseAuth.instance.currentUser!.getIdToken(true);
      }
    } finally {
      _tokenStale = false;
    }
    notifyListeners();
    return FirebaseAuth.instance.currentUser!.emailVerified;
  }

  Future<void> resetPassword(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut(AppData data) async {
    _debounce?.cancel();
    await backup(data);
    allowed = false;
    await FirebaseAuth.instance.signOut();
  }

  /// The message to show for a failed account action.
  static String errorCode(Object e) =>
      e is FirebaseAuthException ? e.code : 'unknown';

  // ---------------------------------------------------------------- data

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('users').doc(user!.uid);

  Reference _file(String sub, String name) =>
      FirebaseStorage.instance.ref('users/${user!.uid}/$sub/$name');

  /// Called once the account is ready on this device. Brings the saved data
  /// down or sends this device's data up. [askKeepLocal] is asked when both
  /// this device (from before signing in) and the account have data, and
  /// answers whether to keep this device's.
  Future<void> attach(
    AppStore store,
    Future<bool> Function(DateTime saved) askKeepLocal,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = user!.uid;
    final owner = prefs.getString(_ownerKey);
    final snap = await _doc.get();
    final remoteAt = snap.data()?['updatedAt'] as int?;

    if (owner != null && owner != uid) {
      // Another account's data: never mix it in, nor upload its files.
      for (final sub in _folders) {
        for (final name in await Files.list(sub)) {
          await Files.delete(sub, name);
        }
      }
      await store.replaceAll(AppData()..settings = store.data.settings);
    }
    final local = store.data;
    if (remoteAt == null) {
      await backup(local);
    } else if (owner == uid) {
      if (remoteAt > local.updatedAt) {
        await _restoreInto(store);
      } else {
        await backup(local);
      }
    } else if (local.isEmpty ||
        !await askKeepLocal(DateTime.fromMillisecondsSinceEpoch(remoteAt))) {
      await _restoreInto(store);
    } else {
      await backup(local);
    }
    await prefs.setString(_ownerKey, uid);
  }

  Future<void> _restoreInto(AppStore store) async {
    final data = await restore();
    if (data != null) await store.replaceAll(data);
  }

  /// Uploads the data, and any file the cloud does not have yet.
  Future<bool> backup(AppData data) async {
    if (user == null || !verified || !allowed || busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final snap = await _doc.get();
      final stored = Map<String, int>.from(snap.data()?['files'] ?? {});
      if (CloudConfig.bucket.isNotEmpty && Files.supported) {
        for (final sub in _folders) {
          if (sub == 'books' && !data.settings.syncBooks) continue;
          for (final name in await Files.list(sub)) {
            final size = await Files.size(sub, name);
            if (stored['$sub/$name'] == size) continue;
            final bytes = await Files.read(sub, name);
            if (bytes == null) continue;
            try {
              await _file(sub, name).putData(bytes);
              stored['$sub/$name'] = size;
            } on FirebaseException catch (e) {
              // Data still saves if file storage isn't set up.
              debugPrint('hayati: could not upload $sub/$name: $e');
            }
          }
        }
      }
      data.settings.lastSync = DateTime.now().millisecondsSinceEpoch;
      final json = jsonEncode(data.toJson());
      final parts = <String>[
        for (var i = 0; i < json.length; i += _partSize)
          json.substring(i, (i + _partSize).clamp(0, json.length)),
      ];
      final oldParts = snap.data()?['parts'] as int? ?? 0;
      final batch = FirebaseFirestore.instance.batch();
      for (final (i, s) in parts.indexed) {
        batch.set(_doc.collection('parts').doc('$i'), {'s': s});
      }
      for (var i = parts.length; i < oldParts; i++) {
        batch.delete(_doc.collection('parts').doc('$i'));
      }
      batch.set(_doc, {
        'updatedAt': data.updatedAt,
        'savedAt': data.settings.lastSync,
        'parts': parts.length,
        'files': stored,
      });
      await batch.commit();
      return true;
    } catch (e) {
      error = '$e';
      debugPrint('hayati: backup failed: $e');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Downloads the saved data and the files missing on this device.
  Future<AppData?> restore() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final snap = await _doc.get();
      final meta = snap.data();
      if (meta == null) return null;
      final n = meta['parts'] as int? ?? 0;
      final buf = StringBuffer();
      for (var i = 0; i < n; i++) {
        final part = await _doc.collection('parts').doc('$i').get();
        buf.write(part.data()?['s'] ?? '');
      }
      final data = AppData.fromJson(jsonDecode(buf.toString()));
      if (CloudConfig.bucket.isNotEmpty && Files.supported) {
        for (final key in Map<String, int>.from(meta['files'] ?? {}).keys) {
          final i = key.indexOf('/');
          final sub = key.substring(0, i), name = key.substring(i + 1);
          if (await Files.exists(sub, name)) continue;
          try {
            final bytes = await _file(sub, name).getData(200 * 1024 * 1024);
            if (bytes != null) await Files.write(sub, name, bytes);
          } on FirebaseException catch (e) {
            debugPrint('hayati: could not download $key: $e');
          }
        }
      }
      return data;
    } catch (e) {
      error = '$e';
      debugPrint('hayati: restore failed: $e');
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Saves to the cloud a little while after the last change.
  void backupSoon(AppData data) {
    if (user == null || !verified || !allowed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 5), () => backup(data));
  }
}
