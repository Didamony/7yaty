import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/stats.dart';
import '../data/store.dart';
import '../services/notifications.dart';
import '../services/prayer.dart';
import 'charts.dart';
import 'goal_editor.dart';
import 'stats_page.dart';
import 'widgets.dart';

/// Opens the plan table at the level of [goal]: a year shows its 12
/// months, a month its weeks, a week its 7 days. With no goal, this year
/// for all tasks.
Future<void> openGoalPlan(BuildContext context, {Goal? goal}) {
  final Widget page;
  if (goal == null) {
    page = PlanYearPage(year: today().year);
  } else {
    final (start, _) = goal.period;
    page = switch (goal.level) {
      Level.year => PlanYearPage(goal: goal, year: start.year),
      Level.month => PlanMonthPage(goal: goal, month: start),
      Level.week => PlanWeekPage(goal: goal, week: start),
      Level.day => PlanWeekPage(goal: goal, week: weekStart(today())),
    };
  }
  return Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

String _scopeTitle(Goal? g) => g == null ? tr('كل المهام') : g.title;

class _PlanScaffold extends StatelessWidget {
  const _PlanScaffold({
    required this.goal,
    required this.title,
    required this.children,
    this.year,
    this.onPrev,
    this.onNext,
  });

  final Goal? goal;
  final String title;
  final List<Widget> children;

  /// Shown before the scope, for titles that leave the year out.
  final int? year;
  final VoidCallback? onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: title,
            subtitle: year == null
                ? _scopeTitle(goal)
                : '${n(year!)} · ${_scopeTitle(goal)}',
            leading: const BackButton(color: Color(0xFFF6F1E7)),
            actions: [
              if (onPrev != null)
                HeaderIconButton(
                  icon: Icons.chevron_left,
                  tooltip: tr('اللي قبله'),
                  onPressed: onPrev,
                ),
              if (onNext != null)
                HeaderIconButton(
                  icon: Icons.chevron_right,
                  tooltip: tr('اللي بعده'),
                  onPressed: onNext,
                ),
              HeaderIconButton(
                icon: Icons.bar_chart,
                tooltip: tr('الرسم البياني'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StatsPage(goalId: goal?.id),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tile with a period's completion and the goals set for it.
class _PeriodTile extends StatelessWidget {
  const _PeriodTile({
    required this.title,
    required this.tally,
    required this.goals,
    required this.onTap,
    this.current = false,
  });

  final String title;
  final Tally tally;
  final List<Goal> goals;
  final VoidCallback onTap;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final color = rateColor(context, tally.rate);
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: current ? p.primary : p.line,
          width: current ? 2.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    rateText(tally.rate),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tally.rate == null ? p.muted : color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: tally.rate ?? 0,
                  minHeight: 6,
                  backgroundColor: p.line,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Muted(
                tr('{d} اتعمل، {m} ما اتعملش', {
                  'd': tally.done,
                  'm': tally.missed,
                }),
                size: 11,
              ),
              for (final g in goals.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Rosette(size: 10, color: p.gold),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          g.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              if (goals.length > 3)
                Muted(tr('و{n} كمان', {'n': goals.length - 3}), size: 11),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalChips extends StatelessWidget {
  const _GoalChips({required this.title, required this.goals});

  final String title;
  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoldLabel(title),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in goals)
                ActionChip(
                  avatar: Icon(
                    g.manualDone ? Icons.check_circle : Icons.flag_outlined,
                    size: 18,
                    color: g.manualDone
                        ? context.pal.green
                        : context.pal.goldText,
                  ),
                  label: Text(g.title),
                  onPressed: () => openGoalEditor(context, goal: g),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlanYearPage extends StatefulWidget {
  const PlanYearPage({super.key, this.goal, required this.year});

  final Goal? goal;
  final int year;

  @override
  State<PlanYearPage> createState() => _PlanYearPageState();
}

class _PlanYearPageState extends State<PlanYearPage> {
  late int _year = widget.year;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppStore>().data;
    final goal = widget.goal;
    final daily = dailyGoalsOf(data, goal);
    final now = DateTime.now();
    final months = buckets(data, daily, Span.year, DateTime(_year), now);
    final yearGoals = goalsInPeriod(
      data,
      goal,
      Level.year,
      DateTime(_year),
      DateTime(_year, 12, 31),
    ).where((g) => g.id != goal?.id).toList();
    return _PlanScaffold(
      goal: goal,
      title: n(_year),
      onPrev: goal == null ? () => setState(() => _year--) : null,
      onNext: goal == null ? () => setState(() => _year++) : null,
      children: [
        _GoalChips(title: tr('أهداف السنة'), goals: yearGoals),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.72,
          children: [
            for (final m in months)
              _PeriodTile(
                title: fmtMonthName(m.from),
                tally: m.tally,
                current: m.from.year == now.year && m.from.month == now.month,
                goals: goalsInPeriod(data, goal, Level.month, m.from, m.to),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlanMonthPage(goal: goal, month: m.from),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class PlanMonthPage extends StatefulWidget {
  const PlanMonthPage({super.key, this.goal, required this.month});

  final Goal? goal;
  final DateTime month;

  @override
  State<PlanMonthPage> createState() => _PlanMonthPageState();
}

class _PlanMonthPageState extends State<PlanMonthPage> {
  late DateTime _month = monthStart(widget.month);

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppStore>().data;
    final goal = widget.goal;
    final daily = dailyGoalsOf(data, goal);
    final now = DateTime.now();
    final end = monthEnd(_month);
    final fixed = goal?.level == Level.month;
    return _PlanScaffold(
      goal: goal,
      title: fmtMonthName(_month),
      year: _month.year,
      onPrev: fixed
          ? null
          : () => setState(
              () => _month = DateTime(_month.year, _month.month - 1),
            ),
      onNext: fixed
          ? null
          : () => setState(
              () => _month = DateTime(_month.year, _month.month + 1),
            ),
      children: [
        _GoalChips(
          title: tr('أهداف الشهر'),
          goals: goalsInPeriod(
            data,
            goal,
            Level.month,
            _month,
            end,
          ).where((g) => g.id != goal?.id).toList(),
        ),
        for (final (i, w) in weeksOfMonth(_month).indexed) ...[
          _PeriodTile(
            title:
                '${tr('الأسبوع {n}', {'n': i + 1})} · ${tr('من {a} لـ {b}', {'a': fmtDayMonth(w), 'b': fmtDayMonth(addDays(w, 6))})}',
            // Only the days of this month count toward the month's weeks.
            tally: tallyRange(
              data,
              daily,
              w.isBefore(_month) ? _month : w,
              addDays(w, 6).isAfter(end) ? end : addDays(w, 6),
              now,
            ),
            current: sameDay(w, weekStart(now)),
            goals: goalsInPeriod(data, goal, Level.week, w, addDays(w, 6)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlanWeekPage(goal: goal, week: w),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class PlanWeekPage extends StatefulWidget {
  const PlanWeekPage({super.key, this.goal, required this.week});

  final Goal? goal;
  final DateTime week;

  @override
  State<PlanWeekPage> createState() => _PlanWeekPageState();
}

class _PlanWeekPageState extends State<PlanWeekPage> {
  late DateTime _week = weekStart(widget.week);

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppStore>().data;
    final goal = widget.goal;
    final daily = dailyGoalsOf(data, goal);
    final now = DateTime.now();
    final p = context.pal;
    final fixed = goal?.level == Level.week;
    return _PlanScaffold(
      goal: goal,
      title: '${fmtDayMonth(_week)} – ${fmtDayMonth(addDays(_week, 6))}',
      year: _week.year,
      onPrev: fixed ? null : () => setState(() => _week = addDays(_week, -7)),
      onNext: fixed ? null : () => setState(() => _week = addDays(_week, 7)),
      children: [
        _GoalChips(
          title: tr('أهداف الأسبوع'),
          goals: goalsInPeriod(
            data,
            goal,
            Level.week,
            _week,
            addDays(_week, 6),
          ).where((g) => g.id != goal?.id).toList(),
        ),
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final day = addDays(_week, i);
              final tasks = daily.where((g) => data.occursOn(g, day)).toList();
              final t = tallyRange(data, daily, day, day, now);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: p.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: sameDay(day, now) ? p.primary : p.line,
                      width: sameDay(day, now) ? 2.5 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlanDayPage(goal: goal, day: day),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fmtDateShort(day),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                rateText(t.rate),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: rateColor(context, t.rate),
                                ),
                              ),
                            ],
                          ),
                          if (tasks.isEmpty)
                            Muted(tr('مفيش مهام'))
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final g in tasks)
                                    _StatusChip(goal: g, day: day),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// A task with its state on a day, colored like the charts.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.goal, required this.day});

  final Goal goal;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppStore>().data;
    final p = context.pal;
    final st = data.status(goal, day);
    final past = day.isBefore(today());
    final (Color bg, Color fg, IconData icon) = switch (st) {
      Occ.done || Occ.qadaPaid => (p.greenBg, p.greenText, Icons.check),
      Occ.missed || Occ.qada => (p.redBg, p.redText, Icons.close),
      Occ.grace ||
      Occ.carried ||
      Occ.dismissed => (p.hint, p.goldText, Icons.remove),
      _ =>
        past
            ? (p.redBg, p.redText, Icons.close)
            : (p.bg, p.muted, Icons.schedule),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            goalTitle(data, goal, day),
            style: TextStyle(fontSize: 12, color: fg),
          ),
        ],
      ),
    );
  }
}

/// One day in eight blocks of three hours, each with its tasks.
class PlanDayPage extends StatefulWidget {
  const PlanDayPage({super.key, this.goal, required this.day});

  final Goal? goal;
  final DateTime day;

  @override
  State<PlanDayPage> createState() => _PlanDayPageState();
}

class _PlanDayPageState extends State<PlanDayPage> {
  late DateTime _day = dayOnly(widget.day);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final data = store.data;
    final goal = widget.goal;
    final p = context.pal;
    final tasks = dailyGoalsOf(
      data,
      goal,
    ).where((g) => data.occursOn(g, _day)).toList();
    final untimed = <Goal>[];
    final blocks = List.generate(8, (_) => <(Goal, DateTime)>[]);
    for (final g in tasks) {
      final at = PrayerTimes.goalTime(g, _day, data.settings.city);
      if (at == null) {
        untimed.add(g);
      } else {
        blocks[(at.hour ~/ 3).clamp(0, 7)].add((g, at));
      }
    }
    for (final b in blocks) {
      b.sort((x, y) => x.$2.compareTo(y.$2));
    }
    final nowBlock = sameDay(_day, today()) ? DateTime.now().hour ~/ 3 : -1;

    Widget taskRow(Goal g, DateTime? at) {
      final done = data.status(g, _day) == Occ.done;
      return CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: done,
        onChanged: _day.isAfter(today())
            ? null
            : (v) => store.update((d) => d.setDone(g, _day, v ?? false)),
        title: Text(goalTitle(data, g, _day)),
        subtitle: at == null ? null : Text(fmtTime(at)),
      );
    }

    return _PlanScaffold(
      goal: goal,
      title: fmtDateShort(_day),
      onPrev: () => setState(() => _day = addDays(_day, -1)),
      onNext: () => setState(() => _day = addDays(_day, 1)),
      children: [
        if (tasks.isEmpty) EmptyNote(tr('مفيش مهام في اليوم ده.')),
        if (untimed.isNotEmpty) ...[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GoldLabel(tr('من غير وقت')),
                for (final g in untimed) taskRow(g, null),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        for (var b = 0; b < 8; b++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: blocks[b].isEmpty
                    ? p.card.withValues(alpha: 0.6)
                    : p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: b == nowBlock ? p.primary : p.line,
                  width: b == nowBlock ? 2.5 : 1,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        '${fmtMinutes(b * 180)} – ${fmtMinutes((b * 180 + 180) % 1440)}',
                        style: TextStyle(
                          fontFamily: kBody,
                          fontWeight: FontWeight.w600,
                          color: p.goldText,
                        ),
                      ),
                      const Spacer(),
                      if (blocks[b].isEmpty) Muted(tr('فاضي'), size: 12),
                    ],
                  ),
                  for (final (g, at) in blocks[b]) taskRow(g, at),
                  if (blocks[b].isEmpty) const SizedBox(height: 4),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
