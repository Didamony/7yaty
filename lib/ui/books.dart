import 'package:epubx/epubx.dart' as epub;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/files.dart';
import 'widgets.dart';

String unitName(Book b) => b.kind == BookKind.pdf ? tr('صفحة') : tr('جزء');

/// EPUB chapters flattened into reading sections, with the top-level
/// chapters marked as chapter starts.
(List<String> titles, List<String> html, List<Chapter> chapters) flattenEpub(
  epub.EpubBook book,
) {
  final titles = <String>[];
  final html = <String>[];
  final chapters = <Chapter>[];
  void walk(List<epub.EpubChapter> list, bool top) {
    for (final c in list) {
      if (top) chapters.add(Chapter(c.Title ?? '', titles.length + 1));
      titles.add(c.Title ?? '');
      html.add(c.HtmlContent ?? '');
      walk(c.SubChapters ?? [], false);
    }
  }

  walk(book.Chapters ?? [], true);
  return (titles, html, chapters);
}

class BooksPage extends StatelessWidget {
  const BooksPage({super.key});

  Future<void> _add(BuildContext context) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub'],
    );
    if (picked == null || !context.mounted) return;
    final ext = (picked.extension ?? '').toLowerCase();
    if (ext != 'pdf' && ext != 'epub') {
      toast(context, tr('الملف لازم يكون PDF أو EPUB'));
      return;
    }
    final id = newId();
    final file = '$id.$ext';
    try {
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await picked.xFile.readAsBytes();
        await Files.write('books', file, bytes);
      } else {
        await Files.ensure('books');
        await picked.xFile.saveTo(Files.path('books', file));
      }
      late Book book;
      var title = picked.name.replaceAll(
        RegExp(r'\.(pdf|epub)$', caseSensitive: false),
        '',
      );
      if (ext == 'pdf') {
        final doc = bytes != null
            ? await PdfDocument.openData(bytes)
            : await PdfDocument.openFile(Files.path('books', file));
        book = Book(
          id: id,
          title: title,
          file: file,
          kind: BookKind.pdf,
          total: doc.pagesCount,
        );
        await doc.close();
      } else {
        final e = await epub.EpubReader.readBook(
          (await Files.read('books', file))!.toList(),
        );
        final (titles, _, chapters) = flattenEpub(e);
        if ((e.Title ?? '').trim().isNotEmpty) title = e.Title!.trim();
        book = Book(
          id: id,
          title: title,
          file: file,
          kind: BookKind.epub,
          total: titles.length,
          chapters: chapters,
        );
      }
      book.planStartKey = dkey(today());
      if (!context.mounted) return;
      await context.store.update((d) => d.books.add(book));
      if (context.mounted) await openPlan(context, book);
    } catch (e) {
      await Files.delete('books', file);
      if (context.mounted) toast(context, tr('مش قادر أفتح الملف ده'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppStore>().data;
    final p = context.pal;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: tr('كتبي'),
            leading: const BackButton(color: Color(0xFFF6F1E7)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (data.books.isEmpty)
                  EmptyNote(
                    tr(
                      'نزّل أي كتاب PDF أو EPUB وضيفه هنا، وحياتي يقسّم القراية على الأيام.',
                    ),
                  ),
                for (final b in data.books) ...[
                  _BookCard(book: b),
                  const SizedBox(height: 14),
                ],
                OutlinedButton.icon(
                  onPressed: () => _add(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    side: BorderSide(color: p.chip, width: 2),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(tr('أضف كتاب (PDF أو EPUB)')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Container(
    width: 92,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF0F5257),
      borderRadius: const BorderRadiusDirectional.only(
        topStart: Radius.circular(8),
        bottomStart: Radius.circular(8),
        topEnd: Radius.circular(14),
        bottomEnd: Radius.circular(14),
      ),
      border: Border.all(color: const Color(0xFFB08D3C), width: 2),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Rosette(size: 36, color: Color(0xFFD4B26A)),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: kDisplay,
            fontSize: 12,
            color: Color(0xFFF6F1E7),
          ),
        ),
      ],
    ),
  );
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final now = DateTime.now();
    final chapter = book.chapterAt(book.current.clamp(1, book.total));
    final perDay = book.perDay(now);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Cover(book.title),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Muted(
                        [
                          book.kind == BookKind.pdf ? 'PDF' : 'EPUB',
                          tr('{n} {u}', {'n': book.total, 'u': unitName(book)}),
                          if (book.chapterCount > 0)
                            tr('{n} فصل', {'n': book.chapterCount}),
                        ].join(' · '),
                      ),
                      Muted(
                        book.current == 0
                            ? tr('لسه ما بدأتش')
                            : [
                                tr('وصلت {u} {n}', {
                                  'u': unitName(book),
                                  'n': book.current,
                                }),
                                if (chapter != null && chapter.title.isNotEmpty)
                                  chapter.title,
                              ].join(' · '),
                      ),
                      const SizedBox(height: 8),
                      Bar(book.progress, label: book.title),
                      const SizedBox(height: 4),
                      Text(
                        pct(book.progress),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HintBox(
            tr('النهارده: {r} من {t} {u}', {
              'r': book.readToday(now).clamp(0, perDay),
              't': perDay,
              'u': unitName(book),
            }),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => openReader(context, book),
            child: Text(
              book.current == 0
                  ? tr('ابدأ القراية')
                  : tr('كمّل القراية من {u} {n}', {
                      'u': unitName(book),
                      'n': (book.current + 1).clamp(1, book.total),
                    }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => openPlan(context, book),
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(tr('خطة القراية')),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: p.redText),
                onPressed: () async {
                  if (!await confirm(
                    context,
                    tr('تمسح الكتاب ده؟'),
                    ok: tr('امسحه'),
                  )) {
                    return;
                  }
                  if (!context.mounted) return;
                  await Files.delete('books', book.file);
                  if (!context.mounted) return;
                  await context.store.update((d) {
                    if (book.goalId != null) d.deleteGoal(book.goalId!);
                    d.books.removeWhere((b) => b.id == book.id);
                  });
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(tr('امسح')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> openPlan(BuildContext context, Book book) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => ChangeNotifierProvider.value(
    value: context.read<AppStore>(),
    child: _PlanSheet(book: book),
  ),
);

class _PlanSheet extends StatefulWidget {
  const _PlanSheet({required this.book});

  final Book book;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  late PlanMode _mode = widget.book.planMode;
  late int _value = widget.book.planValue;
  late int _chapters = widget.book.chapterCount;
  TimeMode _time = TimeMode.prayer;
  Prayer _prayer = Prayer.isha;
  int _clock = 21 * 60;

  @override
  void initState() {
    super.initState();
    final g = context.store.data.goal(widget.book.goalId);
    if (g != null) {
      _time = g.timeMode;
      _prayer = g.prayer;
      _clock = g.clockMin;
    }
  }

  List<int> get _options => switch (_mode) {
    PlanMode.finishInDays => [14, 30, 60, 90],
    PlanMode.chaptersPerWeek => [1, 2, 3, 5],
    PlanMode.unitsPerDay =>
      widget.book.kind == BookKind.pdf ? [5, 10, 20, 30] : [1, 2, 3, 5],
  };

  String _optionLabel(int v) => switch (_mode) {
    PlanMode.finishInDays => switch (v) {
      14 => tr('أسبوعين'),
      30 => tr('شهر'),
      60 => tr('شهرين'),
      _ => tr('{n} شهور', {'n': v ~/ 30}),
    },
    PlanMode.chaptersPerWeek => tr('{n} فصل', {'n': v}),
    PlanMode.unitsPerDay => tr('{n} {u}', {'n': v, 'u': unitName(widget.book)}),
  };

  Book _preview() {
    final b = Book.fromJson(widget.book.toJson())
      ..planMode = _mode
      ..planValue = _value
      ..planStartKey = dkey(today());
    if (_mode == PlanMode.chaptersPerWeek && b.chapterCount == 0) {
      b.chapters = [
        for (var i = 0; i < _chapters.clamp(1, b.total); i++)
          Chapter('', 1 + (i * b.total / _chapters.clamp(1, b.total)).floor()),
      ];
    }
    return b;
  }

  Future<void> _save() async {
    final preview = _preview();
    await context.store.update((d) {
      final b = d.book(widget.book.id)!;
      b
        ..planMode = preview.planMode
        ..planValue = preview.planValue
        ..planStartKey = preview.planStartKey
        ..chapters = preview.chapters;
      var g = d.goal(b.goalId);
      if (g == null) {
        g = Goal(
          id: newId(),
          title: b.title,
          level: Level.day,
          periodKey: dkey(today()),
          repeat: Repeat.daily,
          bookId: b.id,
          createdKey: dkey(today()),
        );
        d.goals.add(g);
        b.goalId = g.id;
      }
      g
        ..timeMode = _time
        ..prayer = _prayer
        ..before = false
        ..offsetMin = 0
        ..clockMin = _clock;
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final b = _preview();
    final now = DateTime.now();
    final perDay = b.perDay(now);
    final daysLeft = perDay == 0 ? 0 : ((b.total - b.current) / perDay).ceil();
    final perWeekChapters = b.chapterCount == 0
        ? null
        : (perDay * 7 / (b.total / b.chapterCount)).toStringAsFixed(1);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('خطة القراية · {t}', {'t': widget.book.title}),
              style: const TextStyle(
                fontFamily: kDisplay,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Pills<PlanMode>(
              values: PlanMode.values,
              selected: _mode,
              label: (m) => switch (m) {
                PlanMode.finishInDays => tr('خلّصه في مدة'),
                PlanMode.chaptersPerWeek => tr('فصول في الأسبوع'),
                PlanMode.unitsPerDay =>
                  widget.book.kind == BookKind.pdf
                      ? tr('صفحات في اليوم')
                      : tr('أجزاء في اليوم'),
              },
              onSelected: (m) => setState(() {
                _mode = m;
                _value = _options[1];
              }),
            ),
            const SizedBox(height: 8),
            Pills<int>(
              values: _options,
              selected: _options.contains(_value) ? _value : null,
              label: _optionLabel,
              onSelected: (v) => setState(() => _value = v),
            ),
            if (_mode == PlanMode.chaptersPerWeek &&
                widget.book.chapterCount == 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Muted(
                      tr('الملف ده مفيهوش فهرس فصول. الكتاب فيه كام فصل؟'),
                      size: 13,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(
                      () => _chapters = (_chapters - 1).clamp(1, 500),
                    ),
                    icon: const Icon(Icons.remove),
                  ),
                  Text(n(_chapters == 0 ? 1 : _chapters)),
                  IconButton(
                    onPressed: () => setState(
                      () => _chapters = (_chapters + 1).clamp(1, 500),
                    ),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(n(perDay), tr('{u} في اليوم', {'u': unitName(b)})),
                const SizedBox(width: 6),
                _Stat(
                  perWeekChapters == null ? '—' : n(perWeekChapters),
                  tr('فصول في الأسبوع'),
                ),
                const SizedBox(width: 6),
                _Stat(tr('{n} يوم', {'n': daysLeft}), tr('متبقي')),
              ],
            ),
            const SizedBox(height: 12),
            GoldLabel(tr('ميعاد القراية')),
            const SizedBox(height: 6),
            Pills<String>(
              values: [
                for (final pr in Prayer.values) 'p:${pr.name}',
                'clock',
                'none',
              ],
              selected: _time == TimeMode.prayer
                  ? 'p:${_prayer.name}'
                  : _time == TimeMode.clock
                  ? 'clock'
                  : 'none',
              label: (v) => v == 'clock'
                  ? fmtMinutes(_clock)
                  : v == 'none'
                  ? tr('من غير ميعاد')
                  : tr('بعد {p}', {
                      'p': prayerName(Prayer.values.byName(v.substring(2))),
                    }),
              onSelected: (v) async {
                if (v == 'clock') {
                  final m = await pickMinutesOfDay(context, _clock);
                  if (m != null) {
                    setState(() {
                      _time = TimeMode.clock;
                      _clock = m;
                    });
                  }
                } else if (v == 'none') {
                  setState(() => _time = TimeMode.none);
                } else {
                  setState(() {
                    _time = TimeMode.prayer;
                    _prayer = Prayer.values.byName(v.substring(2));
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            HintBox(
              tr(
                'هيتعمل هدف يومي لوحده "اقرأ {n} {u}"، ويتعلّم عليه صح أول ما توصل للمطلوب في القارئ.',
                {'n': perDay, 'u': unitName(b)},
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _save, child: Text(tr('حفظ الخطة'))),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value, label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: context.pal.muted),
          ),
        ],
      ),
    ),
  );
}

Future<void> openReader(BuildContext context, Book book) async {
  if (!Files.supported || !await Files.exists('books', book.file)) {
    if (context.mounted) {
      toast(context, tr('ملف الكتاب مش موجود على الجهاز ده'));
    }
    return;
  }
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ReaderPage(bookId: book.id)),
  );
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.bookId});

  final String bookId;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  PdfController? _pdf;
  PageController? _pages;
  List<String> _titles = [];
  List<String> _html = [];
  bool _loading = true;

  Book get _book => context.store.data.book(widget.bookId)!;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final b = _book;
    final start = b.current.clamp(1, b.total);
    if (b.kind == BookKind.pdf) {
      _pdf = PdfController(
        document: kIsWeb
            ? PdfDocument.openData(Files.read('books', b.file).then((v) => v!))
            : PdfDocument.openFile(Files.path('books', b.file)),
        initialPage: start,
      );
    } else {
      final bytes = await Files.read('books', b.file);
      final e = await epub.EpubReader.readBook(bytes!.toList());
      final (titles, html, _) = flattenEpub(e);
      _titles = titles;
      _html = html;
      _pages = PageController(initialPage: start - 1);
      if (b.current == 0) _onUnit(1);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onUnit(int unit) {
    context.store.update((d) => d.updateReading(_book, unit, DateTime.now()));
  }

  @override
  void dispose() {
    _pdf?.dispose();
    _pages?.dispose();
    super.dispose();
  }

  static String _plain(String html) => html
      .replaceAll(
        RegExp(r'<(br|/p|/div|/h\d)[^>]*>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppStore>().data.book(widget.bookId)!;
    final now = DateTime.now();
    final p = context.pal;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.header,
        foregroundColor: const Color(0xFFF6F1E7),
        title: Text(b.title, style: const TextStyle(fontSize: 16)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tr('{u} {c} من {t} · النهارده {r}/{d}', {
                'u': unitName(b),
                'c': b.current,
                't': b.total,
                'r': b.readToday(now).clamp(0, b.perDay(now)),
                'd': b.perDay(now),
              }),
              style: const TextStyle(color: Color(0xFFD4B26A), fontSize: 13),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : b.kind == BookKind.pdf
          ? PdfView(
              controller: _pdf!,
              onPageChanged: _onUnit,
              onDocumentLoaded: (_) => _onUnit(_pdf!.page),
            )
          : PageView.builder(
              controller: _pages,
              itemCount: _html.length,
              onPageChanged: (i) => _onUnit(i + 1),
              itemBuilder: (_, i) => ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_titles[i].isNotEmpty)
                    Text(
                      _titles[i],
                      style: const TextStyle(
                        fontFamily: kDisplay,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _plain(_html[i]),
                    style: const TextStyle(fontSize: 17, height: 1.9),
                  ),
                ],
              ),
            ),
    );
  }
}
