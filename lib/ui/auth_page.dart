import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/cloud.dart';
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
      return const AuthPage();
    }
    if (!user.emailVerified) return const VerifyPage();
    if (_attached != user.uid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _attach(user.uid));
      return _Waiting(tr('بنجهّز بياناتك…'));
    }
    return widget.child;
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
