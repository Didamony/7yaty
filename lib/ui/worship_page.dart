import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/adhkar.dart';
import '../data/quran.dart';
import '../data/store.dart';
import 'adhkar_page.dart';
import 'books.dart';
import 'quran_page.dart';
import 'tasbih_page.dart';
import 'widgets.dart';

class WorshipPage extends StatelessWidget {
  const WorshipPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppStore>().data;
    final w = data.worship;
    final p = context.pal;
    final resume = w.markSurah ?? (w.lastSurah > 0 ? w.lastSurah : null);
    final hour = DateTime.now().hour;
    // Morning adhkar until the afternoon, evening adhkar after that.
    final suggested = adhkarCategories[hour >= 4 && hour < 15 ? 0 : 1];

    return Column(
      children: [
        OrnateHeader(title: tr('عباداتي')),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BigCard(
                icon: Icons.menu_book,
                title: tr('المصحف'),
                subtitle: tr('١١٤ سورة · بالرسم العثماني'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuranIndexPage()),
                ),
                footer: resume == null
                    ? null
                    : FutureBuilder<List<Surah>>(
                        future: Quran.load(),
                        builder: (_, snap) => snap.hasData
                            ? TextButton.icon(
                                onPressed: () => openSurah(
                                  context,
                                  resume,
                                  ayah: w.markSurah == resume
                                      ? w.markAyah
                                      : null,
                                ),
                                icon: const Icon(Icons.bookmark_outline),
                                label: Text(
                                  w.markSurah == resume && w.markAyah != null
                                      ? tr('كمّل: سورة {s} · آية {a}', {
                                          's': snap.data![resume - 1].name,
                                          'a': w.markAyah!,
                                        })
                                      : tr('كمّل: سورة {s}', {
                                          's': snap.data![resume - 1].name,
                                        }),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
              ),
              const SizedBox(height: 12),
              _BigCard(
                icon: Icons.wb_twilight,
                title: tr('الأذكار'),
                subtitle: tr('الصباح والمساء وبعد الصلاة والنوم'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdhkarIndexPage()),
                ),
                footer: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in adhkarCategories.take(2))
                      ActionChip(
                        avatar: Icon(
                          adhkarDoneToday(data, c.id)
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: adhkarDoneToday(data, c.id)
                              ? p.green
                              : p.muted,
                        ),
                        label: Text(c.title),
                        side: c == suggested
                            ? BorderSide(color: p.gold, width: 1.5)
                            : null,
                        onPressed: () => openAdhkar(context, c),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _BigCard(
                icon: Icons.auto_stories,
                title: tr('كتبي'),
                subtitle: data.books.isEmpty
                    ? tr('ضيف كتاب PDF أو EPUB واقسم قرايته على الأيام')
                    : tr('{n} كتاب', {'n': data.books.length}),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BooksPage()),
                ),
                footer: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(tr('أضف كتاب')),
                      onPressed: () => addBook(context),
                    ),
                    for (final b in data.books.take(3))
                      ActionChip(
                        avatar: const Icon(Icons.menu_book_outlined, size: 18),
                        label: Text('${b.title} · ${pct(b.progress)}'),
                        onPressed: () => openReader(context, b),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _BigCard(
                icon: Icons.blur_circular,
                title: tr('السبحة'),
                subtitle: tr('خشب، كهرمان، لؤلؤ، زمرد، أو عداد رقمي'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TasbihPage()),
                ),
                footer: w.totals.isEmpty
                    ? null
                    : Muted(
                        tr('سبّحت لحد دلوقتي {n} مرة', {
                          'n': w.totals.values.fold<int>(0, (a, b) => a + b),
                        }),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigCard extends StatelessWidget {
  const _BigCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.footer,
  });

  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.gold.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: p.header,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.gold, width: 1.5),
                    ),
                    child: Icon(icon, color: p.gold, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: kDisplay,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Muted(subtitle, size: 13),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: p.muted),
                ],
              ),
              if (footer != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: footer,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
