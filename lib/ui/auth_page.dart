import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/cloud.dart';
import 'admin_page.dart';
import 'widgets.dart';

/// Shows [child] only to a signed-in account with a confirmed email, after
/// its saved data is on this device. Builds without a Firebase project
/// skip all of this.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// The account whose data has been brought onto this device.
  String? _attached;
  String? _attaching;

  /// The signed-in account's access, once loaded.
  Access? _access;
  String? _loadingAccess;
  bool _accessFailed = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Notices the end of the trial while the app is open.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _access != null && !_access!.paid) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _loadAccess(String uid) async {
    if (_loadingAccess == uid) return;
    _loadingAccess = uid;
    try {
      final a = await Cloud.instance.loadAccess();
      if (mounted) {
        setState(() {
          _access = a;
          _accessFailed = false;
        });
      }
    } catch (e) {
      debugPrint('hayati: could not load access: $e');
      if (mounted) setState(() => _accessFailed = true);
    } finally {
      _loadingAccess = null;
    }
  }

  /// Checks again, after the admin activated the account.
  Future<void> refreshAccess() async {
    final uid = Cloud.instance.user?.uid;
    if (uid == null) return;
    await _loadAccess(uid);
  }

  Future<void> _attach(String uid) async {
    if (_attaching == uid) return;
    _attaching = uid;
    try {
      await Cloud.instance
          .attach(context.store, _askKeepLocal)
          .timeout(const Duration(minutes: 3));
    } catch (e) {
      // Offline or a cloud error: open the app anyway; it saves later.
      debugPrint('hayati: could not sync on sign-in: $e');
    }
    if (mounted) setState(() => _attached = uid);
  }

  Future<bool> _askKeepLocal(DateTime saved) async {
    final keep = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(tr('في بيانات على الموبايل وفي حسابك')),
        content: Text(
          tr(
            'حسابك فيه بيانات محفوظة من {d}، والموبايل ده عليه بيانات اتكتبت قبل ما تدخل. تحب تاخد أنهي؟',
            {'d': fmtDateLong(saved)},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('اللي على الموبايل')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('اللي في حسابي')),
          ),
        ],
      ),
    );
    return keep ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    if (!cloud.enabled) return widget.child;
    final user = cloud.user;
    if (user == null) {
      _attached = _attaching = null;
      _access = null;
      cloud.allowed = false;
      return const AuthPage();
    }
    if (!cloud.verified) return const VerifyPage();
    if (cloud.isAdmin) {
      // The owner's account only runs the control panel.
      cloud.allowed = false;
      return const AdminPage();
    }
    {
      final access = _access;
      if (access == null || access.uid != user.uid) {
        if (_accessFailed) {
          return _Retry(
            onRetry: () {
              setState(() => _accessFailed = false);
              _loadAccess(user.uid);
            },
          );
        }
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadAccess(user.uid),
        );
        return _Waiting(tr('بنجهّز بياناتك…'));
      }
      if (!access.allowed(DateTime.now())) {
        cloud.allowed = false;
        return PaywallPage(onCheck: refreshAccess);
      }
    }
    cloud.allowed = true;
    if (_attached != user.uid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _attach(user.uid));
      return _Waiting(tr('بنجهّز بياناتك…'));
    }
    final access = _access;
    if (access == null || access.paid) return widget.child;
    return Stack(
      children: [
        widget.child,
        _TrialBadge(
          end: access.trialEnd!,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaywallPage(onCheck: refreshAccess, trial: true),
            ),
          ),
        ),
      ],
    );
  }
}

/// How much of the free trial is left, over the app.
class _TrialBadge extends StatelessWidget {
  const _TrialBadge({required this.end, required this.onTap});

  final DateTime end;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final left = end.difference(DateTime.now());
    final mins = left.inMinutes.clamp(0, 9999);
    return Positioned(
      left: 12,
      bottom: 96 + MediaQuery.paddingOf(context).bottom,
      child: Material(
        color: p.red,
        shape: const StadiumBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              tr('تجربة · فاضل {t} · فعّل', {
                't': mins >= 60
                    ? tr('{h} س {m} د', {'h': mins ~/ 60, 'm': mins % 60})
                    : tr('{n} د', {'n': mins}),
              }),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    children: [
      Text(
        tr('مفيش إنترنت، اتأكد من النت وجرّب تاني'),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 14),
      FilledButton(onPressed: onRetry, child: Text(tr('جرّب تاني'))),
      TextButton(
        onPressed: () => Cloud.instance.signOut(context.store.data),
        child: Text(tr('خروج')),
      ),
    ],
  );
}

/// Shown when the free trial is over (or opened from the trial badge):
/// how to pay with InstaPay, then a form whose details reach the owner's
/// panel and WhatsApp.
class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key, required this.onCheck, this.trial = false});

  final Future<void> Function() onCheck;

  /// Opened during the trial, so it can be closed.
  final bool trial;

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  PayInfo? _info;
  PayRequest? _request;
  bool _editing = false;
  bool _sending = false;
  bool _checking = false;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _from = TextEditingController();
  final _amount = TextEditingController();
  final _ref = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _from, _amount, _ref]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    PayInfo info;
    PayRequest? req;
    try {
      info = await Cloud.instance.loadPayInfo();
      req = await Cloud.instance.myRequest();
    } catch (_) {
      info = PayInfo();
    }
    if (!mounted) return;
    setState(() {
      _info = info;
      _request = req;
      if (_amount.text.isEmpty) _amount.text = info.price;
      if (req != null) {
        _name.text = req.name;
        _from.text = req.from;
        _amount.text = req.amount;
        _ref.text = req.ref;
      }
    });
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) toast(context, tr('اتنسخ'));
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) toast(context, tr('ما قدرتش أفتح اللينك'));
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final user = Cloud.instance.user!;
    setState(() => _sending = true);
    try {
      final r = PayRequest(
        uid: user.uid,
        email: user.email ?? '',
        name: _name.text.trim(),
        from: _from.text.trim(),
        amount: _amount.text.trim(),
        ref: _ref.text.trim(),
        code: activationCode(user.uid),
      );
      await Cloud.instance.sendRequest(r);
      if (!mounted) return;
      setState(() {
        _request = r;
        _editing = false;
      });
    } catch (e) {
      if (mounted) toast(context, tr('حصلت مشكلة، جرّب تاني'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    await widget.onCheck();
    if (!mounted) return;
    setState(() => _checking = false);
    if (widget.trial) {
      Navigator.of(context).maybePop();
    } else {
      // Still here: not activated yet; maybe the request was answered.
      await _load();
      if (mounted) toast(context, tr('لسه ما اتفعّلش'));
    }
  }

  Widget _copyRow(String label, String value, {bool big = false}) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
    decoration: BoxDecoration(
      color: context.pal.hint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Muted(label, size: 11),
              Text(
                value,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: big ? 20 : 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: big ? 1.5 : 0,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: tr('انسخ'),
          onPressed: () => _copy(value),
          icon: const Icon(Icons.copy),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final info = _info;
    final req = _request;
    final uid = Cloud.instance.user?.uid ?? '';
    final pending = req != null && req.status == 'pending' && !_editing;

    Widget field(
      TextEditingController c,
      String label, {
      String? hint,
      bool ltr = false,
      bool required = true,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        textDirection: ltr ? TextDirection.ltr : null,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: (v) =>
            required && v!.trim().isEmpty ? tr('الخانة دي مطلوبة') : null,
      ),
    );

    return _AuthScaffold(
      children: [
        if (widget.trial)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              tooltip: tr('رجوع'),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close),
            ),
          ),
        Icon(Icons.workspace_premium_outlined, size: 52, color: p.goldText),
        const SizedBox(height: 8),
        Text(
          widget.trial ? tr('فعّل حياتي') : tr('فترة التجربة خلصت'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kDisplay,
            fontSize: 24,
            color: p.goldText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'ادفع مرة واحدة بس، والتطبيق يفضل مفتوح ليك على طول، وكل حاجة تتحفظ في حسابك.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.7),
        ),
        const SizedBox(height: 14),
        if (info == null)
          const Center(child: CircularProgressIndicator())
        else if (pending) ...[
          Icon(Icons.mark_email_read_outlined, size: 40, color: p.green),
          const SizedBox(height: 6),
          Text(
            tr('طلبك وصل'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'هنراجع التحويل ونفعّل حسابك في أقرب وقت. أول ما يتفعّل دوس الزرار اللي تحت.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.7),
          ),
          TextButton(
            onPressed: () => setState(() => _editing = true),
            child: Text(tr('عدّل البيانات')),
          ),
        ] else ...[
          if (req?.status == 'rejected') ...[
            HintBox(
              tr(
                'البيانات اللي بعتها ما اتطابقتش مع أي تحويل. راجعها وابعتها تاني.',
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (info.price.isNotEmpty)
            Text(
              tr('السعر: {p}', {'p': info.price}),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 12),
          GoldLabel(tr('١. حوّل المبلغ على InstaPay')),
          _copyRow(tr('حوّل لـ'), info.instapay),
          if (info.link.isNotEmpty) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => _open(info.link),
              icon: const Icon(Icons.open_in_new),
              label: Text(tr('ادفع بلينك InstaPay')),
            ),
          ],
          const SizedBox(height: 14),
          GoldLabel(tr('٢. اكتب الكود ده في سبب التحويل')),
          _copyRow(tr('كود حسابك'), activationCode(uid), big: true),
          const SizedBox(height: 14),
          GoldLabel(tr('٣. بعد التحويل اكتب بياناته هنا')),
          const SizedBox(height: 8),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field(_name, tr('اسمك زي ما ظاهر في InstaPay')),
                field(
                  _from,
                  tr('حوّلت من (رقم الموبايل أو عنوان InstaPay)'),
                  ltr: true,
                ),
                field(_amount, tr('المبلغ اللي حوّلته')),
                field(_ref, tr('رقم العملية من إيصال InstaPay'), ltr: true),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: _sending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(Icons.verified_outlined),
            label: Text(tr('أكّد الدفع')),
          ),
        ],
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: _checking ? null : _check,
          child: Text(tr('اتفعّلت؟ دوس هنا')),
        ),
        if (!widget.trial)
          TextButton(
            onPressed: () => Cloud.instance.signOut(context.store.data),
            child: Text(tr('خروج')),
          ),
      ],
    );
  }
}

/// Account screens: the logo over a card.
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 150,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: p.primary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: LatticePainter(
                            color: p.gold.withValues(alpha: 0.35),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Image.asset('assets/logo/logo_word.png'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    children: [
      const SizedBox(height: 12),
      const Center(child: CircularProgressIndicator()),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 12),
    ],
  );
}

/// What to tell the user for a failed account action.
String authMessage(Object e) => switch (Cloud.errorCode(e)) {
  'invalid-email' => tr('الإيميل مكتوب غلط'),
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' ||
  'INVALID_LOGIN_CREDENTIALS' => tr('الإيميل أو الباسورد غلط'),
  'email-already-in-use' => tr(
    'الإيميل ده عليه حساب بالفعل. ادخل بيه، ولو ناسي الباسورد رجّعه.',
  ),
  'weak-password' => tr('الباسورد ضعيف، خليه ٦ حروف أو أرقام على الأقل'),
  'too-many-requests' => tr('محاولات كتير، استنى شوية وجرّب تاني'),
  'network-request-failed' => tr('مفيش إنترنت، اتأكد من النت وجرّب تاني'),
  'user-disabled' => tr('الحساب ده متوقف'),
  'operation-not-allowed' => tr(
    'الدخول بالإيميل والباسورد مش متفعّل في Firebase. فعّله من Authentication ← Sign-in method.',
  ),
  _ => tr('حصلت مشكلة، جرّب تاني'),
};

/// "Do you have an account?" then signing in or signing up.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _hasAccount = true;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_hasAccount) {
        await Cloud.instance.signIn(_email.text, _password.text);
      } else {
        await Cloud.instance.signUp(_email.text, _password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = authMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = TextEditingController(text: _email.text.trim());
    final send = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('نسيت الباسورد')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(
                'اكتب إيميلك، وهنبعتلك عليه رسالة فيها لينك تعمل بيه باسورد جديد.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: tr('الإيميل')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('ابعت')),
          ),
        ],
      ),
    );
    if (send != true || !mounted) return;
    try {
      await Cloud.instance.resetPassword(email.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(
            tr(
              'لو الإيميل {e} عليه حساب، هتوصلك رسالة فيها لينك تغيّر بيه الباسورد. لو مش لاقيها بص في الـ Spam.',
              {'e': email.text.trim()},
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: Text(tr('تمام')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = authMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return _AuthScaffold(
      children: [
        Text(
          tr('عندك حساب؟'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kDisplay,
            fontSize: 24,
            color: p.goldText,
          ),
        ),
        const SizedBox(height: 12),
        Pills<bool>(
          values: const [true, false],
          selected: _hasAccount,
          label: (v) => v ? tr('أيوه، عندي حساب') : tr('لأ، حساب جديد'),
          onSelected: (v) => setState(() {
            _hasAccount = v;
            _error = null;
          }),
        ),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: tr('الإيميل'),
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
                validator: (v) => RegExp(r'^\S+@\S+\.\S+$').hasMatch(v!.trim())
                    ? null
                    : tr('الإيميل مكتوب غلط'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: !_showPassword,
                autofillHints: [
                  _hasAccount
                      ? AutofillHints.password
                      : AutofillHints.newPassword,
                ],
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: tr('الباسورد'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _showPassword
                        ? tr('خبّي الباسورد')
                        : tr('اظهر الباسورد'),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (v) => v!.length < 6
                    ? tr('الباسورد ضعيف، خليه ٦ حروف أو أرقام على الأقل')
                    : null,
                onFieldSubmitted: (_) => _hasAccount ? _submit() : null,
              ),
              if (!_hasAccount) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  obscureText: !_showPassword,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: tr('اكتب الباسورد تاني'),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                      v != _password.text ? tr('الباسوردين مش زي بعض') : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: p.redText)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: _busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text(_hasAccount ? tr('دخول') : tr('اعمل الحساب')),
        ),
        if (_hasAccount)
          TextButton(onPressed: _forgot, child: Text(tr('نسيت الباسورد؟')))
        else ...[
          const SizedBox(height: 8),
          Muted(
            tr(
              'هنبعت رسالة على إيميلك تأكد بيها إنه بتاعك. كل حاجة بتكتبها هتتحفظ في حسابك، ولو مسحت التطبيق ونزّلته تاني تدخل بنفس الإيميل والباسورد وكل حاجة ترجع.',
            ),
            size: 12,
          ),
        ],
      ],
    );
  }
}

/// Waits for the user to open the confirmation link sent to their email.
class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  Timer? _poll;
  bool _busy = false;
  DateTime? _sentAt;

  @override
  void initState() {
    super.initState();
    // Notice the confirmation without a tap when the user comes back.
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => Cloud.instance.refresh().catchError((_) => false),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      final ok = await Cloud.instance.refresh();
      if (!ok && mounted) {
        toast(
          context,
          tr('لسه ما اتأكدش. افتح الرسالة ودوس على اللينك اللي فيها.'),
        );
      }
    } catch (e) {
      if (mounted) toast(context, authMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final last = _sentAt;
    if (last != null && DateTime.now().difference(last).inSeconds < 60) {
      toast(context, tr('استنى دقيقة قبل ما تبعتها تاني'));
      return;
    }
    try {
      await Cloud.instance.sendVerification();
      _sentAt = DateTime.now();
      if (mounted) toast(context, tr('بعتناها تاني'));
    } catch (e) {
      if (mounted) toast(context, authMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final email = Cloud.instance.user?.email ?? '';
    return _AuthScaffold(
      children: [
        Icon(Icons.mark_email_unread_outlined, size: 56, color: p.goldText),
        const SizedBox(height: 10),
        Text(
          tr('أكّد إيميلك'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kDisplay,
            fontSize: 24,
            color: p.goldText,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tr(
            'بعتنا رسالة على {e}. افتحها ودوس على اللينك اللي فيها، وبعدين ارجع هنا. لو مش لاقيها بص في الـ Spam.',
            {'e': email},
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.7),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _check,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(tr('أكدت، كمّل')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _resend,
          child: Text(tr('ابعت الرسالة تاني')),
        ),
        TextButton(
          onPressed: () => Cloud.instance.signOut(context.store.data),
          child: Text(tr('استخدم إيميل تاني')),
        ),
      ],
    );
  }
}
