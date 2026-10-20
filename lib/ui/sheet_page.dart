import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/i18n.dart';
import '../data/store.dart';
import 'widgets.dart';

/// The monthly sheet: a month laid out like a calendar, with a short note
/// on any day ("شغل", "إجازة"…). It is kept apart from goals.
class SheetPage extends StatefulWidget {
  const SheetPage({super.key});

  @override
  State<SheetPage> createState() => _SheetPageState();
}

class _SheetPageState extends State<SheetPage> {
  DateTime _month = monthStart(today());

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  Future<void> _edit(DateTime day) async {
    final store = context.store;
    final key = dkey(day);
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _NoteEditor(day: day, initial: store.data.sheet[key] ?? ''),
    );
    if (text == null) return;
    await store.update((d) {
      if (text.trim().isEmpty) {
        d.sheet.remove(key);
      } else {
        d.sheet[key] = text.trim();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppStore>().data;
    final p = context.pal;
    final first = weekStart(_month);
    final last = monthEnd(_month);
    final weeks = (last.difference(first).inDays ~/ 7) + 1;
    final notes = [
      for (final d in daysInRange(_month, last))
        if (data.sheet[dkey(d)] != null) (d, data.sheet[dkey(d)]!),
    ];
    const light = Color(0xFFF6F1E7);

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: tr('الشيت الشهري'),
            leading: const BackButton(color: light),
            bottom: Row(
              children: [
                IconButton(
                  tooltip: tr('الشهر اللي قبله'),
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left, color: light),
                ),
                Expanded(
                  child: Text(
                    '${fmtMonthName(_month)}  ${n(_month.year)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: light,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr('الشهر اللي بعده'),
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right, color: light),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 32),
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            weekdayName(addDays(first, i).weekday),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: p.goldText,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                for (var w = 0; w < weeks; w++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: _DayCell(
                              day: addDays(first, w * 7 + i),
                              inMonth:
                                  addDays(first, w * 7 + i).month ==
                                  _month.month,
                              note: data.sheet[dkey(addDays(first, w * 7 + i))],
                              onTap: () => _edit(addDays(first, w * 7 + i)),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                Muted(tr('دوس على أي يوم عشان تكتب أو تعدّل الملاحظة بتاعته.')),
                const SizedBox(height: 16),
                if (notes.isNotEmpty)
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GoldLabel(tr('ملاحظات الشهر')),
                        for (final (d, note) in notes)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(note),
                            leading: SizedBox(
                              width: 92,
                              child: Text(
                                fmtDateShort(d),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: sameDay(d, today())
                                      ? p.primary
                                      : p.muted,
                                  fontWeight: sameDay(d, today())
                                      ? FontWeight.w700
                                      : null,
                                ),
                              ),
                            ),
                            trailing: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: p.muted,
                            ),
                            onTap: () => _edit(d),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.note,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final isToday = sameDay(day, today());
    final has = note != null;
    return Opacity(
      opacity: inMonth ? 1 : 0.35,
      child: Material(
        color: has ? p.hint : p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isToday ? p.primary : p.line,
            width: isToday ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: inMonth ? onTap : null,
          child: SizedBox(
            height: 74,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    n(day.day),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isToday ? p.primary : p.goldText,
                    ),
                  ),
                  if (has)
                    Expanded(
                      child: Text(
                        note!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, height: 1.3),
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

/// Bottom sheet to write a day's note; pops the new text, or null.
class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.day, required this.initial});

  final DateTime day;
  final String initial;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            fmtDateLong(widget.day),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: p.goldText,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: tr('مثلًا: شغل، إجازة، ميعاد الدكتور ٥ م'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.initial.isNotEmpty)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, ''),
                  style: TextButton.styleFrom(foregroundColor: p.red),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(tr('امسح')),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, _text.text),
                icon: const Icon(Icons.check),
                label: Text(tr('حفظ')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
