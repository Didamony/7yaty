import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../services/cloud.dart';
import 'widgets.dart';

/// For the admin only: who signed up, who paid, activating accounts, and
/// the payment details shown to users.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _price = TextEditingController();
  final _instapay = TextEditingController();
  final _link = TextEditingController();
  final _whatsapp = TextEditingController();
  final _search = TextEditingController();
  List<Access>? _accounts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_price, _instapay, _link, _whatsapp, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final info = await Cloud.instance.loadPayInfo();
      final accounts = await Cloud.instance.recentAccounts();
      if (!mounted) return;
      setState(() {
        _price.text = info.price;
        _instapay.text = info.instapay;
        _link.text = info.link;
        _whatsapp.text = info.whatsapp;
        _accounts = accounts;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _savePay() async {
    try {
      await Cloud.instance.savePayInfo(
        PayInfo(
          price: _price.text.trim(),
          instapay: _instapay.text.trim(),
          link: _link.text.trim(),
          whatsapp: _whatsapp.text.trim(),
        ),
      );
      if (mounted) toast(context, tr('اتحفظ'));
    } catch (e) {
      if (mounted) toast(context, tr('الحفظ ما نجحش'));
    }
  }

  Future<void> _setPaid(Access a, bool paid) async {
    final ok = await confirm(
      context,
      paid
          ? tr('تفعّل {e} مدى الحياة؟', {'e': a.email ?? a.uid})
          : tr('تلغي تفعيل {e}؟', {'e': a.email ?? a.uid}),
      ok: paid ? tr('فعّل') : tr('الغي'),
    );
    if (!ok) return;
    try {
      await Cloud.instance.setPaid(a.uid, paid);
      await _load();
      if (mounted) toast(context, paid ? tr('اتفعّل') : tr('اتلغى التفعيل'));
    } catch (e) {
      if (mounted) toast(context, tr('حصلت مشكلة، جرّب تاني'));
    }
  }

  Future<void> _activateByEmail() async {
    final email = _search.text.trim();
    if (email.isEmpty) return;
    final a = await Cloud.instance.findAccount(email);
    if (!mounted) return;
    if (a == null) {
      toast(context, tr('مفيش حساب بالإيميل ده'));
      return;
    }
    if (a.paid) {
      toast(context, tr('الحساب ده متفعّل بالفعل'));
      return;
    }
    await _setPaid(a, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final now = DateTime.now();
    final q = _search.text.trim().toLowerCase();
    final accounts = (_accounts ?? [])
        .where((a) => q.isEmpty || (a.email ?? '').contains(q))
        .toList();
    final paid = (_accounts ?? []).where((a) => a.paid).length;

    Widget field(TextEditingController c, String label, {String? hint}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: c,
            decoration: InputDecoration(labelText: label, hintText: hint),
          ),
        );

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: tr('لوحة التفعيل'),
            subtitle: _accounts == null
                ? null
                : tr('{n} حساب · {p} مدفوع', {
                    'n': _accounts!.length,
                    'p': paid,
                  }),
            leading: const BackButton(color: Color(0xFFF6F1E7)),
            actions: [
              HeaderIconButton(
                icon: Icons.refresh,
                tooltip: tr('حدّث'),
                onPressed: _load,
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    HintBox(tr('حصلت مشكلة، جرّب تاني')),
                    const SizedBox(height: 12),
                  ],
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GoldLabel(tr('فعّل حساب')),
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
                  GoldLabel(tr('الحسابات')),
                  const SizedBox(height: 6),
                  if (_accounts == null)
                    const Center(child: CircularProgressIndicator())
                  else if (accounts.isEmpty)
                    Muted(tr('مفيش حسابات'))
                  else
                    for (final a in accounts)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            a.email ?? a.uid,
                            textDirection: TextDirection.ltr,
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
                                  onPressed: () => _setPaid(a, false),
                                  child: Text(tr('الغي')),
                                )
                              : FilledButton(
                                  onPressed: () => _setPaid(a, true),
                                  child: Text(tr('فعّل')),
                                ),
                        ),
                      ),
                  const SizedBox(height: 14),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GoldLabel(tr('بيانات الدفع اللي بتظهر للناس')),
                        const SizedBox(height: 8),
                        field(_price, tr('السعر'), hint: tr('مثلًا: ٣٠٠ جنيه')),
                        field(
                          _instapay,
                          tr('عنوان InstaPay أو رقمه'),
                          hint: 'name@instapay',
                        ),
                        field(
                          _link,
                          tr('لينك الدفع بـ InstaPay (لو عندك)'),
                          hint: 'https://ipn.eg/S/...',
                        ),
                        field(
                          _whatsapp,
                          tr('رقم الواتساب اللي يبعتولك عليه'),
                          hint: '2010xxxxxxxx',
                        ),
                        FilledButton(
                          onPressed: _savePay,
                          child: Text(tr('احفظ')),
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
