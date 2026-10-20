import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../data/store.dart';
import '../services/cloud.dart';
import 'widgets.dart';

/// The owner's account opens on this and nothing else: payment requests,
/// activating accounts, and the payment details users see.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _price = TextEditingController();
  final _instapay = TextEditingController();
  final _link = TextEditingController();
  final _search = TextEditingController();
  Stream<List<PayRequest>> _requests = Cloud.instance.watchRequests();
  bool _retrying = false;
  List<Access>? _accounts;
  PayInfo? _pay;
  bool _editingPay = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_price, _instapay, _link, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cloud = Cloud.instance;
      final pay = await cloud.loadPayInfo();
      final accounts = await cloud.recentAccounts();
      if (!mounted) return;
      setState(() {
        _pay = pay;
        _accounts = accounts;
        _failed = false;
        _requests = Cloud.instance.watchRequests();
      });
    } catch (e) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<bool> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) toast(context, done);
      return true;
    } catch (e) {
      if (mounted) toast(context, tr('حصلت مشكلة، جرّب تاني'));
      return false;
    }
  }

  Future<void> _approve(String uid, String email) async {
    if (!await confirm(
      context,
      tr('تفعّل {e} مدى الحياة؟', {'e': email}),
      ok: tr('فعّل'),
    )) {
      return;
    }
    await _run(() => Cloud.instance.approve(uid), tr('اتفعّل'));
    await _load();
  }

  Future<void> _reject(PayRequest r) async {
    if (!await confirm(
      context,
      tr('ترفض طلب {e}؟ هيظهرله يراجع بياناته ويبعتها تاني.', {'e': r.email}),
      ok: tr('ارفض'),
    )) {
      return;
    }
    await _run(() => Cloud.instance.reject(r.uid), tr('اترفض'));
  }

  Future<void> _unpay(Access a) async {
    if (!await confirm(
      context,
      tr('تلغي تفعيل {e}؟', {'e': a.email ?? a.uid}),
      ok: tr('الغي'),
    )) {
      return;
    }
    await _run(() => Cloud.instance.setPaid(a.uid, false), tr('اتلغى التفعيل'));
    await _load();
  }

  Future<void> _activateByEmail() async {
    final email = _search.text.trim();
    if (email.isEmpty) return;
    final a = await Cloud.instance.findAccount(email);
    if (!mounted) return;
    if (a == null) {
      toast(context, tr('مفيش حساب بالإيميل ده'));
    } else if (a.paid) {
      toast(context, tr('الحساب ده متفعّل بالفعل'));
    } else {
      await _approve(a.uid, a.email ?? email);
    }
  }

  void _editPay() {
    final pay = _pay ?? PayInfo();
    _price.text = pay.price;
    _instapay.text = pay.instapay;
    _link.text = pay.link;
    setState(() => _editingPay = true);
  }

  Future<void> _savePay() async {
    final pay = PayInfo(
      price: _price.text.trim(),
      instapay: _instapay.text.trim(),
      link: _link.text.trim(),
    );
    if (await _run(() => Cloud.instance.savePayInfo(pay), tr('اتحفظ')) &&
        mounted) {
      setState(() {
        _pay = PayInfo.fromJson(pay.toJson());
        _editingPay = false;
      });
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    bool ltr = false,
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      textDirection: ltr ? TextDirection.ltr : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
    ),
  );

  Widget _requestCard(PayRequest r) {
    final p = context.pal;
    final pending = r.status == 'pending';
    final color = switch (r.status) {
      'approved' => p.greenText,
      'rejected' => p.redText,
      _ => p.goldText,
    };
    Widget line(IconData icon, String k, String v) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.muted),
          const SizedBox(width: 8),
          SizedBox(width: 84, child: Muted(k, size: 12)),
          Expanded(
            child: SelectableText(
              v,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pending ? p.gold : p.line, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(r.email),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.email,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (r.at != null)
                      Muted(
                        '${fmtTime(r.at!)} · ${fmtDayMonth(r.at!)}',
                        size: 11,
                      ),
                  ],
                ),
              ),
              _Chip(switch (r.status) {
                'approved' => tr('اتفعّل'),
                'rejected' => tr('اترفض'),
                _ => tr('مستني'),
              }, color),
            ],
          ),
          const SizedBox(height: 6),
          line(Icons.person_outline, tr('الاسم'), r.name),
          line(Icons.swap_horiz, tr('حوّل من'), r.from),
          line(Icons.payments_outlined, tr('المبلغ'), r.amount),
          line(Icons.receipt_long_outlined, tr('رقم العملية'), r.ref),
          line(Icons.tag, tr('الكود'), r.code),
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _approve(r.uid, r.email),
                    icon: const Icon(Icons.verified_outlined),
                    label: Text(tr('فعّل')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(r),
                    icon: const Icon(Icons.close),
                    label: Text(tr('ارفض')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _payCard() {
    final p = context.pal;
    final pay = _pay;
    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: p.hint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: p.goldText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Muted(label, size: 12),
                Text(
                  value.isEmpty ? tr('مش متحدد') : value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: value.isEmpty ? p.muted : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return _Section(
      icon: Icons.account_balance_wallet_outlined,
      title: tr('بيانات الدفع اللي بتظهر للناس'),
      trailing: _editingPay || pay == null
          ? null
          : TextButton.icon(
              onPressed: _editPay,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(tr('تعديل')),
            ),
      children: [
        if (pay == null)
          const Center(child: CircularProgressIndicator())
        else if (!_editingPay) ...[
          row(Icons.sell_outlined, tr('السعر'), pay.price),
          row(
            Icons.account_balance_outlined,
            tr('عنوان InstaPay'),
            pay.instapay,
          ),
          if (pay.link.isNotEmpty) row(Icons.link, tr('لينك الدفع'), pay.link),
        ] else ...[
          const SizedBox(height: 4),
          _field(
            _price,
            tr('السعر'),
            hint: tr('مثلًا: ٣٠٠ جنيه'),
            icon: Icons.sell_outlined,
          ),
          _field(
            _instapay,
            tr('عنوان InstaPay'),
            hint: defaultInstapay,
            ltr: true,
            icon: Icons.account_balance_outlined,
          ),
          _field(
            _link,
            tr('لينك الدفع بـ InstaPay (لو عندك)'),
            hint: 'https://ipn.eg/S/...',
            ltr: true,
            icon: Icons.link,
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _savePay,
                  child: Text(tr('احفظ')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _editingPay = false),
                  child: Text(tr('إلغاء')),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final now = DateTime.now();
    final accounts = _accounts ?? [];
    final q = _search.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: tr('لوحة التحكم'),
            subtitle: Cloud.instance.user?.email,
            actions: [
              HeaderIconButton(
                icon: Icons.refresh,
                tooltip: tr('حدّث'),
                onPressed: _load,
              ),
              HeaderIconButton(
                icon: Icons.settings_outlined,
                tooltip: tr('الإعدادات'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OwnerSettingsPage()),
                ),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: StreamBuilder<List<PayRequest>>(
                stream: _requests,
                builder: (context, snap) {
                  // Right after the email is confirmed the first listen can
                  // be refused; try again shortly.
                  if (snap.hasError && !_retrying) {
                    _retrying = true;
                    Future.delayed(const Duration(seconds: 3), () {
                      _retrying = false;
                      if (mounted) _load();
                    });
                  }
                  final all = snap.data ?? [];
                  final pending = all
                      .where((r) => r.status == 'pending')
                      .toList();
                  final done = all.where((r) => r.status != 'pending').take(20);

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_failed) ...[
                        HintBox(tr('حصلت مشكلة، جرّب تاني')),
                        const SizedBox(height: 12),
                      ],
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.9,
                        children: [
                          _Stat(
                            icon: Icons.hourglass_top_rounded,
                            label: tr('طلبات مستنية'),
                            value: pending.length,
                            color: p.goldText,
                          ),
                          _Stat(
                            icon: Icons.verified_rounded,
                            label: tr('مدفوع'),
                            value: accounts.where((a) => a.paid).length,
                            color: p.greenText,
                          ),
                          _Stat(
                            icon: Icons.timer_outlined,
                            label: tr('في التجربة'),
                            value: accounts
                                .where((a) => !a.paid && a.inTrial(now))
                                .length,
                            color: p.primary,
                          ),
                          _Stat(
                            icon: Icons.groups_outlined,
                            label: tr('كل الحسابات'),
                            value: accounts.length,
                            color: p.ink,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SectionTitle(
                        icon: Icons.notifications_active_outlined,
                        title: tr('طلبات الدفع'),
                      ),
                      const SizedBox(height: 8),
                      if (!snap.hasData && !snap.hasError)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (pending.isEmpty)
                        _Empty(
                          icon: Icons.inbox_outlined,
                          text: tr('مفيش طلبات مستنية دلوقتي.'),
                        ),
                      for (final r in pending) _requestCard(r),
                      if (done.isNotEmpty)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          leading: Icon(Icons.history, color: p.muted),
                          title: Text(tr('طلبات خلصت')),
                          children: [for (final r in done) _requestCard(r)],
                        ),
                      const SizedBox(height: 14),
                      _Section(
                        icon: Icons.person_search_outlined,
                        title: tr('فعّل حساب بالإيميل'),
                        children: [
                          const SizedBox(height: 4),
                          TextField(
                            controller: _search,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: TextDirection.ltr,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: tr('إيميل اللي دفع'),
                              prefixIcon: const Icon(Icons.search),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _activateByEmail,
                            icon: const Icon(Icons.verified_outlined),
                            label: Text(tr('فعّل مدى الحياة')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _Section(
                        icon: Icons.groups_outlined,
                        title: tr('الحسابات'),
                        children: [
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            shape: const Border(),
                            title: Muted(
                              tr('{n} حساب · {p} مدفوع', {
                                'n': accounts.length,
                                'p': accounts.where((a) => a.paid).length,
                              }),
                            ),
                            children: [
                              if (_accounts == null)
                                const Center(child: CircularProgressIndicator())
                              else if (accounts.isEmpty)
                                Muted(tr('مفيش حسابات'))
                              else
                                for (final a in accounts.where(
                                  (a) =>
                                      q.isEmpty || (a.email ?? '').contains(q),
                                ))
                                  _AccountRow(
                                    access: a,
                                    now: now,
                                    onActivate: () =>
                                        _approve(a.uid, a.email ?? a.uid),
                                    onRemove: () => _unpay(a),
                                  ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _payCard(),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n(value),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.1,
                  ),
                ),
                Muted(label, size: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: context.pal.goldText),
      const SizedBox(width: 8),
      Expanded(child: GoldLabel(title)),
      ?trailing,
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(icon: icon, title: title, trailing: trailing),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: p.muted),
          const SizedBox(height: 6),
          Muted(text),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.email);

  final String email;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return CircleAvatar(
      radius: 18,
      backgroundColor: p.primary,
      child: Text(
        email.isEmpty ? '?' : email.substring(0, 1).toUpperCase(),
        style: TextStyle(color: p.onPrimary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.access,
    required this.now,
    required this.onActivate,
    required this.onRemove,
  });

  final Access access;
  final DateTime now;
  final VoidCallback onActivate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final a = access;
    final (label, color) = a.paid
        ? (tr('مدفوع'), p.greenText)
        : a.inTrial(now)
        ? (tr('في التجربة'), p.goldText)
        : (tr('ما دفعش'), p.redText);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _Avatar(a.email ?? ''),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.email ?? a.uid,
                  textDirection: TextDirection.ltr,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                _Chip(label, color),
              ],
            ),
          ),
          a.paid
              ? TextButton(onPressed: onRemove, child: Text(tr('الغي')))
              : FilledButton(onPressed: onActivate, child: Text(tr('فعّل'))),
        ],
      ),
    );
  }
}

/// The owner's settings: light or dark look, password and signing out.
class OwnerSettingsPage extends StatelessWidget {
  const OwnerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = context.pal;
    final email = Cloud.instance.user?.email ?? '';
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: tr('الإعدادات'),
            leading: const BackButton(color: Color(0xFFF6F1E7)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Section(
                  icon: Icons.dark_mode_outlined,
                  title: tr('المظهر'),
                  children: [
                    const SizedBox(height: 6),
                    Pills<String>(
                      values: const ['light', 'dark', 'system'],
                      selected: store.settings.theme,
                      label: (v) => switch (v) {
                        'light' => tr('فاتح'),
                        'dark' => tr('داكن'),
                        _ => tr('حسب الجهاز'),
                      },
                      onSelected: (v) =>
                          store.update((d) => d.settings.theme = v),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Section(
                  icon: Icons.manage_accounts_outlined,
                  title: tr('الحساب'),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _Avatar(email),
                      title: Text(email, textDirection: TextDirection.ltr),
                      subtitle: Muted(tr('صاحب التطبيق'), size: 12),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.lock_reset, color: p.goldText),
                      title: Text(tr('غيّر الباسورد')),
                      subtitle: Muted(
                        tr('هيوصلك على إيميلك لينك تعمل بيه باسورد جديد'),
                        size: 12,
                      ),
                      onTap: () async {
                        try {
                          await Cloud.instance.resetPassword(email);
                          if (context.mounted) {
                            toast(
                              context,
                              tr('بعتنالك على إيميلك لينك تغيّر بيه الباسورد'),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            toast(context, tr('حصلت مشكلة، جرّب تاني'));
                          }
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout, color: p.redText),
                      title: Text(
                        tr('تسجيل الخروج'),
                        style: TextStyle(color: p.redText),
                      ),
                      onTap: () async {
                        if (!await confirm(
                              context,
                              tr('تخرج من حسابك؟'),
                              ok: tr('خروج'),
                            ) ||
                            !context.mounted) {
                          return;
                        }
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        await Cloud.instance.signOut(store.data);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
