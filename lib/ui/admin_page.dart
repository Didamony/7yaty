import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../services/cloud.dart';
import 'widgets.dart';

/// The owner's account opens on this and nothing else: payment requests,
/// activating accounts, the payment details users see, and where the
/// WhatsApp notices go.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _price = TextEditingController();
  final _instapay = TextEditingController();
  final _link = TextEditingController();
  final _phone = TextEditingController();
  final _apikey = TextEditingController();
  final _search = TextEditingController();
  Stream<List<PayRequest>> _requests = Cloud.instance.watchRequests();
  bool _retrying = false;
  List<Access>? _accounts;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_price, _instapay, _link, _phone, _apikey, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cloud = Cloud.instance;
      final pay = await cloud.loadPayInfo();
      final notify = await cloud.loadNotifyInfo();
      final accounts = await cloud.recentAccounts();
      if (!mounted) return;
      setState(() {
        _price.text = pay.price;
        _instapay.text = pay.instapay;
        _link.text = pay.link;
        _phone.text = notify.phone;
        _apikey.text = notify.apikey;
        _accounts = accounts;
        _failed = false;
        _requests = Cloud.instance.watchRequests();
      });
    } catch (e) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) toast(context, done);
    } catch (e) {
      if (mounted) toast(context, tr('حصلت مشكلة، جرّب تاني'));
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

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    bool ltr = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      textDirection: ltr ? TextDirection.ltr : null,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  Widget _requestCard(PayRequest r) {
    final p = context.pal;
    final pending = r.status == 'pending';
    Widget line(String k, String v) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Muted(k, size: 12)),
          Expanded(
            child: SelectableText(
              v,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: pending ? p.gold : p.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.email,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  switch (r.status) {
                    'approved' => tr('اتفعّل'),
                    'rejected' => tr('اترفض'),
                    _ => tr('مستني'),
                  },
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: switch (r.status) {
                      'approved' => p.greenText,
                      'rejected' => p.redText,
                      _ => p.goldText,
                    },
                  ),
                ),
              ],
            ),
            if (r.at != null)
              Muted('${fmtTime(r.at!)} · ${fmtDayMonth(r.at!)}', size: 11),
            const SizedBox(height: 6),
            line(tr('الاسم'), r.name),
            line(tr('حوّل من'), r.from),
            line(tr('المبلغ'), r.amount),
            line(tr('رقم العملية'), r.ref),
            line(tr('الكود'), r.code),
            if (pending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _approve(r.uid, r.email),
                      child: Text(tr('فعّل')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(r),
                      child: Text(tr('ارفض')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final now = DateTime.now();
    final paid = (_accounts ?? []).where((a) => a.paid).length;

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: tr('لوحة التحكم'),
            subtitle: _accounts == null
                ? Cloud.instance.user?.email
                : tr('{n} حساب · {p} مدفوع', {
                    'n': _accounts!.length,
                    'p': paid,
                  }),
            actions: [
              HeaderIconButton(
                icon: Icons.refresh,
                tooltip: tr('حدّث'),
                onPressed: _load,
              ),
              HeaderIconButton(
                icon: Icons.logout,
                tooltip: tr('تسجيل الخروج'),
                onPressed: () async {
                  if (await confirm(
                        context,
                        tr('تخرج من حسابك؟'),
                        ok: tr('خروج'),
                      ) &&
                      context.mounted) {
                    await Cloud.instance.signOut(context.store.data);
                  }
                },
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_failed) ...[
                    HintBox(tr('حصلت مشكلة، جرّب تاني')),
                    const SizedBox(height: 12),
                  ],
                  StreamBuilder<List<PayRequest>>(
                    stream: _requests,
                    builder: (context, snap) {
                      // Right after the email is confirmed the first listen
                      // can be refused; try again shortly.
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
                      final done = all
                          .where((r) => r.status != 'pending')
                          .take(20);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GoldLabel(
                            tr('طلبات الدفع ({n} مستني)', {
                              'n': pending.length,
                            }),
                          ),
                          const SizedBox(height: 6),
                          if (!snap.hasData && !snap.hasError)
                            const Center(child: CircularProgressIndicator())
                          else if (pending.isEmpty)
                            Muted(tr('مفيش طلبات مستنية دلوقتي.')),
                          for (final r in pending) _requestCard(r),
                          if (done.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(tr('طلبات خلصت')),
                              children: [for (final r in done) _requestCard(r)],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GoldLabel(tr('فعّل حساب بالإيميل')),
                        const SizedBox(height: 8),
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
                  ),
                  const SizedBox(height: 14),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: GoldLabel(tr('الحسابات')),
                    children: [
                      if (_accounts == null)
                        const Center(child: CircularProgressIndicator())
                      else if (_accounts!.isEmpty)
                        Muted(tr('مفيش حسابات'))
                      else
                        for (final a in _accounts!.where(
                          (a) =>
                              _search.text.isEmpty ||
                              (a.email ?? '').contains(
                                _search.text.trim().toLowerCase(),
                              ),
                        ))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              a.email ?? a.uid,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              a.paid
                                  ? tr('مدفوع')
                                  : a.inTrial(now)
                                  ? tr('في التجربة')
                                  : tr('التجربة خلصت · ما دفعش'),
                              style: TextStyle(
                                color: a.paid
                                    ? p.greenText
                                    : a.inTrial(now)
                                    ? p.goldText
                                    : p.redText,
                              ),
                            ),
                            trailing: a.paid
                                ? TextButton(
                                    onPressed: () => _unpay(a),
                                    child: Text(tr('الغي')),
                                  )
                                : FilledButton(
                                    onPressed: () =>
                                        _approve(a.uid, a.email ?? a.uid),
                                    child: Text(tr('فعّل')),
                                  ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GoldLabel(tr('بيانات الدفع اللي بتظهر للناس')),
                        const SizedBox(height: 8),
                        _field(
                          _price,
                          tr('السعر'),
                          hint: tr('مثلًا: ٣٠٠ جنيه'),
                        ),
                        _field(
                          _instapay,
                          tr('عنوان InstaPay'),
                          hint: defaultInstapay,
                          ltr: true,
                        ),
                        _field(
                          _link,
                          tr('لينك الدفع بـ InstaPay (لو عندك)'),
                          hint: 'https://ipn.eg/S/...',
                          ltr: true,
                        ),
                        FilledButton(
                          onPressed: () => _run(
                            () => Cloud.instance.savePayInfo(
                              PayInfo(
                                price: _price.text.trim(),
                                instapay: _instapay.text.trim(),
                                link: _link.text.trim(),
                              ),
                            ),
                            tr('اتحفظ'),
                          ),
                          child: Text(tr('احفظ')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GoldLabel(tr('رسايل الواتساب ليك')),
                        const SizedBox(height: 4),
                        Muted(
                          tr(
                            'كل طلب دفع بيوصلك رسالة واتساب لوحده. رقمك مش بيظهر لحد.',
                          ),
                          size: 12,
                        ),
                        const SizedBox(height: 8),
                        _field(
                          _phone,
                          tr('رقم الواتساب بتاعك بكود الدولة'),
                          hint: '+2010xxxxxxxx',
                          ltr: true,
                        ),
                        _field(
                          _apikey,
                          tr('مفتاح CallMeBot (apikey)'),
                          ltr: true,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _run(
                                  () => Cloud.instance.saveNotifyInfo(
                                    NotifyInfo(
                                      phone: _phone.text.trim(),
                                      apikey: _apikey.text.trim(),
                                    ),
                                  ),
                                  tr('اتحفظ'),
                                ),
                                child: Text(tr('احفظ')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final ok = await Cloud.instance.notifyOwner(
                                    tr('🔔 حياتي: رسالة تجربة من لوحة التحكم'),
                                    info: NotifyInfo(
                                      phone: _phone.text.trim(),
                                      apikey: _apikey.text.trim(),
                                    ),
                                  );
                                  if (context.mounted) {
                                    toast(
                                      context,
                                      ok
                                          ? tr('اتبعتت، شوف الواتساب')
                                          : tr(
                                              'ما اتبعتتش، راجع الرقم والمفتاح',
                                            ),
                                    );
                                  }
                                },
                                child: Text(tr('ابعت رسالة تجربة')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
