import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/i18n.dart';
import '../data/adhkar.dart';
import '../data/quran.dart';
import '../core/theme.dart';
import '../data/store.dart';
import 'quran_page.dart';
import 'widgets.dart';

bool adhkarDoneToday(AppData d, String id) =>
    d.worship.adhkarDone[dkey(today())]?.contains(id) ?? false;

class AdhkarIndexPage extends StatelessWidget {
  const AdhkarIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppStore>().data;
    final p = context.pal;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: tr('الأذكار'),
            leading: const BackButton(color: Color(0xFFF6F1E7)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final c in adhkarCategories) ...[
                  _CategoryTile(category: c, done: adhkarDoneToday(data, c.id)),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.done});

  final AdhkarCategory category;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: done ? p.greenBg : p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: done ? p.greenLine : p.gold.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openAdhkar(context, category),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Rosette(size: 30, color: p.gold, filled: done),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Muted(
                      done
                          ? tr('قريتها النهارده · تقبّل الله')
                          : tr('{n} ذكر', {'n': category.items.length}),
                    ),
                  ],
                ),
              ),
              Icon(
                done ? Icons.check_circle : Icons.chevron_right,
                color: done ? p.green : p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> openAdhkar(BuildContext context, AdhkarCategory c) =>
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdhkarPage(category: c)),
    );

class AdhkarPage extends StatefulWidget {
  const AdhkarPage({super.key, required this.category});

  final AdhkarCategory category;

  @override
  State<AdhkarPage> createState() => _AdhkarPageState();
}

class _AdhkarPageState extends State<AdhkarPage> {
  late List<int> _left = [for (final d in widget.category.items) d.count];

  int get _doneCount => _left.where((x) => x == 0).length;

  void _tap(int i) {
    if (_left[i] == 0) return;
    setState(() => _left[i]--);
    if (_left[i] == 0) {
      HapticFeedback.mediumImpact();
      if (_doneCount == _left.length) _finish();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _finish() {
    final id = widget.category.id;
    context.store.update((d) {
      final list = d.worship.adhkarDone.putIfAbsent(dkey(today()), () => []);
      if (!list.contains(id)) list.add(id);
      // Keep two weeks of history.
      final cutoff = dkey(addDays(today(), -14));
      d.worship.adhkarDone.removeWhere((k, _) => k.compareTo(cutoff) < 0);
    });
    toast(
      context,
      tr('خلصت {c} · تقبّل الله منك', {'c': widget.category.title}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final items = widget.category.items;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: widget.category.title,
            subtitle: tr('{d} من {t}', {'d': _doneCount, 't': items.length}),
            leading: const BackButton(color: Color(0xFFF6F1E7)),
            actions: [
              HeaderIconButton(
                icon: Icons.restart_alt,
                tooltip: tr('ابدأ من الأول'),
                onPressed: () =>
                    setState(() => _left = [for (final d in items) d.count]),
              ),
            ],
            bottom: Bar(
              _doneCount / items.length,
              label: widget.category.title,
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _DhikrCard(
                dhikr: items[i],
                left: _left[i],
                onTap: () => _tap(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({
    required this.dhikr,
    required this.left,
    required this.onTap,
  });

  final Dhikr dhikr;
  final int left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final size = context.watch<AppStore>().data.worship.fontSize * 0.8;
    final done = left == 0;
    final style = TextStyle(
      fontFamily: kQuran,
      fontSize: size,
      height: 2,
      color: p.ink,
    );
    final q = dhikr.quran;
    Widget body;
    if (q != null) {
      body = FutureBuilder<List<String>>(
        future: Quran.ayat(q.$1, q.$2, q.$3),
        builder: (_, snap) {
          if (!snap.hasData) return const SizedBox(height: 40);
          final text = [
            for (var i = 0; i < snap.data!.length; i++)
              '${snap.data![i]}${ayahMark(q.$2 + i)}',
          ].join();
          // Whole surahs start with the basmala, as they are recited.
          final withBasmala = q.$2 == 1 && q.$1 != 9 && q.$1 != 1;
          return Text(
            withBasmala ? '${Quran.bismillah}\n$text' : text,
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            style: style,
          );
        },
      );
    } else {
      body = Text(
        dhikr.text!,
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
        style: style,
      );
    }

    return Material(
      color: done ? p.greenBg : p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: done ? p.greenLine : p.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (dhikr.note != null) ...[
                Text(
                  dhikr.note!,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 13,
                    color: p.goldText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: done ? 0.55 : 1,
                child: body,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Muted(tr('رواه {s}', {'s': dhikr.source}))),
                  if (dhikr.count > 1 && !done)
                    Muted(tr('{n} مرات', {'n': dhikr.count})),
                  const SizedBox(width: 10),
                  Semantics(
                    label: tr('باقي {n}', {'n': left}),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? p.green : p.primary,
                      ),
                      child: done
                          ? const Icon(Icons.check, color: Colors.white)
                          : Text(
                              n(left),
                              style: TextStyle(
                                color: p.onPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
