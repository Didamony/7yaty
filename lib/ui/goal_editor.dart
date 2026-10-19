import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/i18n.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/prayer.dart';
import 'widgets.dart';

Future<void> openGoalEditor(
  BuildContext context, {
  Goal? goal,
  Level? level,
  DateTime? day,
  String? parentId,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          GoalEditor(goal: goal, level: level, day: day, parentId: parentId),
    ),
  );
}

String defaultPeriodKey(Level level, DateTime day) => switch (level) {
  Level.year => '${day.year}',
  Level.month => dkey(day).substring(0, 7),
  Level.week => dkey(weekStart(day)),
  Level.day => dkey(day),
};

class GoalEditor extends StatefulWidget {
  const GoalEditor({super.key, this.goal, this.level, this.day, this.parentId});

  final Goal? goal;
  final Level? level;
  final DateTime? day;
  final String? parentId;

  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> {
  late final TextEditingController _title;
  late Goal _g;
  bool get _isNew => widget.goal == null;

  @override
  void initState() {
    super.initState();
    final store = context.store;
    final src = widget.goal;
    final parent = store.data.goal(widget.parentId);
    final level =
        src?.level ??
        widget.level ??
        (parent == null ? Level.day : Level.values[parent.level.index + 1]);
    var day = widget.day ?? today();
    if (parent != null && src == null) {
      final (ps, pe) = parent.period;
      if (day.isBefore(ps) || day.isAfter(pe)) day = ps;
    }
    _g = src != null
        ? Goal.fromJson(src.toJson())
        : Goal(
            id: newId(),
            title: '',
            level: level,
            periodKey: defaultPeriodKey(level, day),
            parentId: parent?.id,
            repeat: parent != null && level == Level.day
                ? Repeat.daily
                : Repeat.none,
            createdKey: dkey(today()),
          );
    _title = TextEditingController(text: _g.title);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  List<Goal> _possibleParents(AppData data) => data.goals
      .where(
        (g) =>
            g.level.index < _g.level.index &&
            g.id != _g.id &&
            !data.descendants(_g.id).any((d) => d.id == g.id),
      )
      .toList();

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      toast(context, tr('اكتب اسم الهدف'));
      return;
    }
    _g.title = title;
    if (_g.repeat == Repeat.weekdays && _g.weekdays.isEmpty) {
      _g.repeat = Repeat.daily;
    }
    await context.store.update((d) {
      final i = d.goals.indexWhere((x) => x.id == _g.id);
      if (i >= 0) {
        d.goals[i] = _g;
      } else {
        d.goals.add(_g);
      }
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final data = context.store.data;
    final kids = data.descendants(_g.id).length;
    final ok = await confirm(
      context,
      kids == 0
          ? tr('تمسح الهدف ده؟')
          : tr('تمسح الهدف ده و{n} هدف تحته؟', {'n': kids}),
      ok: tr('امسحه'),
    );
    if (!ok || !mounted) return;
    await context.store.update((d) => d.deleteGoal(_g.id));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.store.data;
    final p = context.pal;
    final parents = _possibleParents(data);
    final city = data.settings.city;
    final preview = PrayerTimes.goalTime(_g, today(), city);

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: _isNew ? tr('هدف جديد') : tr('تعديل الهدف'),
            leading: IconButton(
              tooltip: tr('إغلاق'),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Color(0xFFF6F1E7)),
            ),
            actions: [
              if (!_isNew)
                HeaderIconButton(
                  icon: Icons.delete_outline,
                  tooltip: tr('امسح'),
                  onPressed: _delete,
                ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GoldLabel(tr('الهدف')),
                const SizedBox(height: 6),
                TextField(
                  controller: _title,
                  autofocus: _isNew,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: tr('مثلًا: قراءة صفحتين من القرآن'),
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GoldLabel(tr('المستوى')),
                      const SizedBox(height: 8),
                      Pills<Level>(
                        values: Level.values,
                        selected: _g.level,
                        label: levelName,
                        onSelected: (l) => setState(() {
                          _g
                            ..level = l
                            ..periodKey = defaultPeriodKey(l, today());
                          final parent = data.goal(_g.parentId);
                          if (parent != null && parent.level.index >= l.index) {
                            _g.parentId = null;
                          }
                        }),
                      ),
                      const SizedBox(height: 10),
                      _PeriodPicker(goal: _g, onChanged: () => setState(() {})),
                      if (_g.level != Level.year) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String?>(
                          initialValue: parents.any((g) => g.id == _g.parentId)
                              ? _g.parentId
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: tr('تابع لهدف أكبر'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(tr('لا، هدف مستقل')),
                            ),
                            for (final g in parents)
                              DropdownMenuItem(
                                value: g.id,
                                child: Text(
                                  '${levelName(g.level)} · ${g.title}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _g.parentId = v),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_g.isDaily) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GoldLabel(tr('التكرار')),
                        const SizedBox(height: 8),
                        Pills<Repeat>(
                          values: Repeat.values,
                          selected: _g.repeat,
                          label: (r) => switch (r) {
                            Repeat.none => tr('مرة واحدة'),
                            Repeat.daily => tr('كل يوم'),
                            Repeat.weekdays => tr('أيام محددة'),
                          },
                          onSelected: (r) => setState(() => _g.repeat = r),
                        ),
                        if (_g.repeat == Repeat.weekdays) ...[
                          const SizedBox(height: 8),
                          _WeekdayPicker(
                            selected: _g.weekdays,
                            onChanged: () => setState(() {}),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GoldLabel(tr('الوقت')),
                        const SizedBox(height: 8),
                        Pills<TimeMode>(
                          values: TimeMode.values,
                          selected: _g.timeMode,
                          label: (m) => switch (m) {
                            TimeMode.none => tr('من غير وقت'),
                            TimeMode.clock => tr('ساعة محددة'),
                            TimeMode.prayer => tr('مربوط بصلاة'),
                          },
                          onSelected: (m) => setState(() => _g.timeMode = m),
                        ),
                        if (_g.timeMode == TimeMode.clock) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final m = await pickMinutesOfDay(
                                context,
                                _g.clockMin,
                              );
                              if (m != null) setState(() => _g.clockMin = m);
                            },
                            icon: const Icon(Icons.schedule),
                            label: Text(fmtMinutes(_g.clockMin)),
                          ),
                        ],
                        if (_g.timeMode == TimeMode.prayer) ...[
                          const SizedBox(height: 8),
                          Pills<bool>(
                            values: const [true, false],
                            selected: _g.before,
                            label: (b) => b ? tr('قبل') : tr('بعد'),
                            onSelected: (b) => setState(() => _g.before = b),
                          ),
                          const SizedBox(height: 6),
                          Pills<Prayer>(
                            values: Prayer.values,
                            selected: _g.prayer,
                            label: prayerName,
                            onSelected: (v) => setState(() => _g.prayer = v),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(tr('بفرق')),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Pills<int>(
                                  values: const [0, 5, 10, 15, 30, 60],
                                  selected: _g.offsetMin,
                                  label: minutesLabel,
                                  onSelected: (v) =>
                                      setState(() => _g.offsetMin = v),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (preview != null) ...[
                          const SizedBox(height: 8),
                          HintBox(
                            _g.timeMode == TimeMode.prayer
                                ? tr(
                                    'النهارده هينبّهك {t} · الميعاد بيتحرك لوحده مع {p}',
                                    {
                                      't': fmtTime(preview),
                                      'p': prayerName(_g.prayer),
                                    },
                                  )
                                : tr('هينبّهك كل يوم {t}', {
                                    't': fmtTime(preview),
                                  }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GoldLabel(tr('لو فاتني')),
                        const SizedBox(height: 8),
                        Pills<OnMiss>(
                          values: OnMiss.values,
                          selected: _g.onMiss,
                          label: (m) => switch (m) {
                            OnMiss.ask => tr('اسألني (يظهر بالأحمر)'),
                            OnMiss.qada => tr('يتسجّل قضاء'),
                            OnMiss.carry => tr('رحّله لليوم اللي بعده'),
                          },
                          onSelected: (m) => setState(() => _g.onMiss = m),
                        ),
                      ],
                    ),
                  ),
                  if (_g.repeat != Repeat.none) ...[
                    const SizedBox(height: 12),
                    SectionCard(
                      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _g.grace,
                        onChanged: (v) => setState(() => _g.grace = v),
                        title: Text(
                          tr('يوم رحمة في الأسبوع'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Muted(
                          tr('لو فوّت يوم واحد في الأسبوع، السلسلة مش هتتكسر'),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                FilledButton(onPressed: _save, child: Text(tr('حفظ الهدف'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.goal, required this.onChanged});

  final Goal goal;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final now = today();
    switch (goal.level) {
      case Level.year:
        return Pills<String>(
          values: ['${now.year}', '${now.year + 1}'],
          selected: goal.periodKey,
          label: n,
          onSelected: (v) {
            goal.periodKey = v;
            onChanged();
          },
        );
      case Level.month:
        final months = [
          for (var i = -1; i < 12; i++)
            dkey(DateTime(now.year, now.month + i, 1)).substring(0, 7),
        ];
        return DropdownButtonFormField<String>(
          initialValue: months.contains(goal.periodKey)
              ? goal.periodKey
              : months[1],
          decoration: InputDecoration(labelText: tr('الشهر')),
          items: [
            for (final m in months)
              DropdownMenuItem(
                value: m,
                child: Text(fmtMonth(parseKey('$m-01'))),
              ),
          ],
          onChanged: (v) {
            goal.periodKey = v!;
            onChanged();
          },
        );
      case Level.week:
        final weeks = [
          for (var i = -1; i < 9; i++) dkey(addDays(weekStart(now), 7 * i)),
        ];
        return DropdownButtonFormField<String>(
          initialValue: weeks.contains(goal.periodKey)
              ? goal.periodKey
              : weeks[1],
          decoration: InputDecoration(labelText: tr('الأسبوع')),
          items: [
            for (final w in weeks)
              DropdownMenuItem(
                value: w,
                child: Text(
                  tr('من {a} لـ {b}', {
                    'a': fmtDayMonth(parseKey(w)),
                    'b': fmtDayMonth(addDays(parseKey(w), 6)),
                  }),
                ),
              ),
          ],
          onChanged: (v) {
            goal.periodKey = v!;
            onChanged();
          },
        );
      case Level.day:
        final d = parseKey(goal.periodKey);
        return OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: d,
              firstDate: addDays(now, -365),
              lastDate: addDays(now, 3650),
            );
            if (picked != null) {
              goal.periodKey = dkey(picked);
              onChanged();
            }
          },
          icon: const Icon(Icons.event),
          label: Text(
            goal.repeat == Repeat.none
                ? fmtDateShort(d)
                : tr('يبدأ {d}', {'d': fmtDateShort(d)}),
          ),
        );
    }
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});

  final List<int> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    const order = [6, 7, 1, 2, 3, 4, 5];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final w in order)
          FilterChip(
            label: Text(weekdayName(w)),
            selected: selected.contains(w),
            showCheckmark: false,
            selectedColor: p.primary,
            labelStyle: TextStyle(
              color: selected.contains(w) ? p.onPrimary : p.ink,
              fontSize: 13,
            ),
            onSelected: (on) {
              on ? selected.add(w) : selected.remove(w);
              onChanged();
            },
          ),
      ],
    );
  }
}
