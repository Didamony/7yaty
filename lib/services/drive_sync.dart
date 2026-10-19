import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../data/store.dart';
import 'files.dart';

const _scope = drive.DriveApi.driveAppdataScope;
const _dataName = 'hayati-data.json';

/// The OAuth "Web client" ID from Google Cloud, passed at build time with
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`. See README.
const _serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

/// Folders whose files go to Drive, and the prefix each gets there.
const _folders = {'recordings': 'rec__', 'books': 'book__', 'media': 'media__'};

class _AuthClient extends http.BaseClient {
  _AuthClient(this._headers);

  final Map<String, String> _headers;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

/// Keeps a copy of everything in the user's own Google Drive, in the app's
/// private folder (`appDataFolder`), so a reinstall can bring it all back.
class DriveSync extends ChangeNotifier {
  DriveSync._();

  static final instance = DriveSync._();

  bool _ready = false;
  bool busy = false;
  String? error;
  Timer? _debounce;

  bool get supported => !kIsWeb && GoogleSignIn.instance.supportsAuthenticate();

  Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      );
      _ready = true;
    } catch (e) {
      error = '$e';
    }
  }

  /// Interactive sign-in. Returns the account email.
  Future<String> signIn() async {
    await init();
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const [_scope],
    );
    await account.authorizationClient.authorizeScopes(const [_scope]);
    return account.email;
  }

  Future<void> signOut() async {
    await init();
    await GoogleSignIn.instance.signOut();
  }

  Future<drive.DriveApi?> _api({bool prompt = false}) async {
    await init();
    if (!_ready) return null;
    final headers = await GoogleSignIn.instance.authorizationClient
        .authorizationHeaders(const [_scope], promptIfNecessary: prompt);
    if (headers == null) return null;
    return drive.DriveApi(_AuthClient(headers));
  }

  Future<Map<String, drive.File>> _remoteFiles(drive.DriveApi api) async {
    final out = <String, drive.File>{};
    String? page;
    do {
      final res = await api.files.list(
        spaces: 'appDataFolder',
        $fields: 'nextPageToken, files(id, name, size, modifiedTime)',
        pageSize: 1000,
        pageToken: page,
      );
      for (final f in res.files ?? <drive.File>[]) {
        out[f.name!] = f;
      }
      page = res.nextPageToken;
    } while (page != null);
    return out;
  }

  Future<void> _put(
    drive.DriveApi api,
    Map<String, drive.File> remote,
    String name,
    List<int> bytes,
  ) async {
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final existing = remote[name];
    if (existing != null) {
      await api.files.update(drive.File(), existing.id!, uploadMedia: media);
    } else {
      await api.files.create(
        drive.File()
          ..name = name
          ..parents = ['appDataFolder'],
        uploadMedia: media,
      );
    }
  }

  Future<List<int>> _get(drive.DriveApi api, String id) async {
    final media = await api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  /// When the copy on Drive was last saved, or null if there is none.
  Future<int?> remoteUpdatedAt() async {
    final api = await _api();
    if (api == null) return null;
    final remote = await _remoteFiles(api);
    final f = remote[_dataName];
    if (f == null) return null;
    final json = jsonDecode(utf8.decode(await _get(api, f.id!)));
    return json['updatedAt'] as int?;
  }

  /// Uploads the data and any file Drive does not have yet.
  Future<bool> backup(AppData data, {bool prompt = false}) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final api = await _api(prompt: prompt);
      if (api == null) throw StateError('not signed in');
      final remote = await _remoteFiles(api);
      if (Files.supported) {
        for (final MapEntry(key: sub, value: prefix) in _folders.entries) {
          if (sub == 'books' && !data.settings.syncBooks) continue;
          for (final name in await Files.list(sub)) {
            final remoteName = '$prefix$name';
            final local = await Files.size(sub, name);
            if (remote[remoteName]?.size == '$local') continue;
            final bytes = await Files.read(sub, name);
            if (bytes != null) await _put(api, remote, remoteName, bytes);
          }
        }
      }
      data.settings.lastSync = DateTime.now().millisecondsSinceEpoch;
      await _put(
        api,
        remote,
        _dataName,
        utf8.encode(jsonEncode(data.toJson())),
      );
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

  /// Downloads the saved copy and its files. Returns null if there is none.
  Future<AppData?> restore({bool prompt = false}) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final api = await _api(prompt: prompt);
      if (api == null) throw StateError('not signed in');
      final remote = await _remoteFiles(api);
      final dataFile = remote[_dataName];
      if (dataFile == null) return null;
      final data = AppData.fromJson(
        jsonDecode(utf8.decode(await _get(api, dataFile.id!))),
      );
      if (Files.supported) {
        for (final f in remote.values) {
          for (final MapEntry(key: sub, value: prefix) in _folders.entries) {
            if (!f.name!.startsWith(prefix)) continue;
            final name = f.name!.substring(prefix.length);
            if (await Files.exists(sub, name)) continue;
            await Files.write(sub, name, await _get(api, f.id!));
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

  /// Backs up a little while after the last change, while signed in.
  void backupSoon(AppData data) {
    if (data.settings.googleEmail == null || kIsWeb) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 20), () => backup(data));
  }
}
