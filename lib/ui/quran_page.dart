import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/quran.dart';
import '../data/store.dart';
import 'widgets.dart';

const kQuran = 'Quran';

const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

/// Verse numbers are always Arabic-Indic inside the mushaf.
String arabicNumber(int v) =>
    '$v'.split('').map((d) => _arabicDigits[int.parse(d)]).join();

/// The end-of-verse ornament with its number.
String ayahMark(int v) => ' ۝${arabicNumber(v)} ';

class QuranIndexPage extends StatefulWidget {
  const QuranIndexPage({super.key});

  @override
  State<QuranIndexPage> createState() => _QuranIndexPageState();
}

class _QuranIndexPageState extends State<QuranIndexPage> {
  String _query = '';

  static String _plain(String s) => s
      .replaceAll(RegExp(r'[ً-ٰٟۖ-ࣰۭ-ࣲ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  @override
  Widget build(BuildContext context) {
    final w = context.watch<AppStore>().data.worship;
    final p = context.pal;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: tr('المصحف'),
            leading: const BackButton(color: Color(0xFFF6F1E7)),
          ),
          Expanded(
            child: FutureBuilder<List<Surah>>(
              future: Quran.load(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;
                final q = _plain(_query.trim());
                final list = q.isEmpty
                    ? all
                    : all
                          .where(
                            (s) =>
                                _plain(s.name).contains(q) ||
                                '${s.number}' ==
                                    q.replaceAllMapped(
                                      RegExp('[٠-٩]'),
                                      (m) => '${_arabicDigits.indexOf(m[0]!)}',
                                    ),
                          )
                          .toList();
                final resume =
                    w.markSurah ?? (w.lastSurah > 0 ? w.lastSurah : null);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (resume != null) ...[
                      _ResumeCard(
                        surah: all[resume - 1],
                        ayah: w.markSurah == resume ? w.markAyah : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: tr('دوّر على سورة بالاسم أو الرقم'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final s in list) _SurahTile(surah: s),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.surah, this.ayah});

  final Surah surah;
  final int? ayah;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: p.header,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openSurah(context, surah.number, ayah: ayah),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.bookmark, color: p.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('كمّل القراءة'),
                      style: const TextStyle(
                        color: Color(0xD9F6F1E7),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      ayah == null
                          ? tr('سورة {s}', {'s': surah.name})
                          : tr('سورة {s} · آية {a}', {
                              's': surah.name,
                              'a': ayah!,
                            }),
                      style: const TextStyle(
                        color: Color(0xFFF6F1E7),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: p.gold),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return InkWell(
      onTap: () => openSurah(context, surah.number),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.line)),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Rosette(size: 44, color: p.gold),
                  Text(
                    n(surah.number),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.goldText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سورة ${surah.name}',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: kQuran,
                      fontSize: 20,
                      height: 1.6,
                    ),
                  ),
                  Muted(
                    '${surah.meccan ? tr('مكية') : tr('مدنية')} · ${tr('{n} آية', {'n': surah.ayat.length})}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openSurah(BuildContext context, int surah, {int? ayah}) =>
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahPage(surah: surah, initialAyah: ayah),
      ),
    );

class SurahPage extends StatefulWidget {
  const SurahPage({super.key, required this.surah, this.initialAyah});

  final int surah;
  final int? initialAyah;

  @override
  State<SurahPage> createState() => _SurahPageState();
}

class _SurahPageState extends State<SurahPage> {
  static const _chunk = 8;
  final _keys = <int, GlobalKey>{};
  final _taps = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    final store = context.store;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.update((d) => d.worship.lastSurah = widget.surah);
      if (widget.initialAyah != null) _jump();
    });
  }

  void _jump() {
    final key = _keys[(widget.initialAyah! - 1) ~/ _chunk];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    } else {
      // The text is still loading; try again next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _jump());
    }
  }

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  void _ayahMenu(Surah s, int ayah) {
    final store = context.store;
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                tr('سورة {s} · آية {a}', {'s': s.name, 'a': ayah}),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: Text(tr('علّم هنا (وقفت عند الآية دي)')),
              onTap: () {
                store.update(
                  (d) => d.worship
                    ..markSurah = s.number
                    ..markAyah = ayah,
                );
                Navigator.pop(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(tr('انسخ الآية')),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(
                    text:
                        '${s.ayat[ayah - 1]} [${s.name}: ${arabicNumber(ayah)}]',
                  ),
                );
                Navigator.pop(c);
                toast(context, tr('اتنسخت'));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final w = store.data.worship;
    final p = context.pal;
    return Scaffold(
      backgroundColor: p.bg,
      body: FutureBuilder<List<Surah>>(
        future: Quran.load(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final s = all[widget.surah - 1];
          for (final t in _taps) {
            t.dispose();
          }
          _taps.clear();
          final style = TextStyle(
            fontFamily: kQuran,
            fontSize: w.fontSize,
            height: 2.1,
            color: p.ink,
          );
          final chunks = <Widget>[];
          for (var c = 0; c * _chunk < s.ayat.length; c++) {
            final spans = <InlineSpan>[];
            for (
              var i = c * _chunk;
              i < s.ayat.length && i < (c + 1) * _chunk;
              i++
            ) {
              final ayah = i + 1;
              final marked = w.markSurah == s.number && w.markAyah == ayah;
              final tap = TapGestureRecognizer()
                ..onTap = () => _ayahMenu(s, ayah);
              _taps.add(tap);
              // Surah 1 counts the basmala as its first verse; elsewhere it is
              // shown as a header, and the text never repeats it.
              spans.add(
                TextSpan(
                  text: s.ayat[i],
                  recognizer: tap,
                  style: marked
                      ? TextStyle(
                          backgroundColor: p.gold.withValues(alpha: 0.25),
                        )
                      : null,
                ),
              );
              spans.add(
                TextSpan(
                  text: ayahMark(ayah),
                  style: TextStyle(color: p.goldText),
                ),
              );
            }
            chunks.add(
              Text.rich(
                TextSpan(children: spans),
                key: _keys.putIfAbsent(c, GlobalKey.new),
                textAlign: TextAlign.justify,
                textDirection: TextDirection.rtl,
                style: style,
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: OrnateHeader(
                  title: tr('سورة {s}', {'s': s.name}),
                  subtitle:
                      '${s.meccan ? tr('مكية') : tr('مدنية')} · ${tr('{n} آية', {'n': s.ayat.length})}',
                  leading: const BackButton(color: Color(0xFFF6F1E7)),
                  actions: [
                    HeaderIconButton(
                      icon: Icons.text_decrease,
                      tooltip: tr('صغّر الخط'),
                      onPressed: () => store.update(
                        (d) => d.worship.fontSize = (d.worship.fontSize - 2)
                            .clamp(18, 44),
                      ),
                    ),
                    HeaderIconButton(
                      icon: Icons.text_increase,
                      tooltip: tr('كبّر الخط'),
                      onPressed: () => store.update(
                        (d) => d.worship.fontSize = (d.worship.fontSize + 2)
                            .clamp(18, 44),
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                sliver: SliverList.list(
                  children: [
                    _SurahBanner(name: s.name),
                    if (s.number != 1 && s.number != 9)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          Quran.bismillah,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: style,
                        ),
                      ),
                    ...chunks,
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (s.number < 114)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SurahPage(surah: s.number + 1),
                                ),
                              ),
                              child: Text(
                                tr('السورة التالية: {s}', {
                                  's': all[s.number].name,
                                }),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The framed surah title used at the top of each surah.
class _SurahBanner extends StatelessWidget {
  const _SurahBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.gold, width: 2),
        color: p.gold.withValues(alpha: 0.08),
      ),
      child: Row(
        children: [
          Rosette(size: 26, color: p.gold),
          Expanded(
            child: Text(
              'سورة $name',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: kQuran,
                fontSize: 24,
                color: p.goldText,
              ),
            ),
          ),
          Rosette(size: 26, color: p.gold),
        ],
      ),
    );
  }
}
