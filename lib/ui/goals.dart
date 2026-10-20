import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'books.dart';
import 'goal_editor.dart';
import 'goal_plan.dart';
import 'stats_page.dart';
import 'widgets.dart';

String periodLabel(Goal g) {
  switch (g.level) {
    case Level.year:
      return n(g.periodKey);
    case Level.month:
      return fmtMonth(parseKey('${g.periodKey}-01'));
    case Level.week:
      final s = parseKey(g.periodKey);
      return tr('من {a} لـ {b}', {
        'a': fmtDayMonth(s),
        'b': fmtDayMonth(addDays(s, 6)),
      });
    case Level.day:
      return switch (g.repeat) {
        Repeat.none => fmtDateShort(parseKey(g.periodKey)),
        Repeat.daily => tr('يتكرر كل يوم'),
        Repeat.weekdays => g.weekdays.map(weekdayName).join('، '),
      };
  }
}

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  Level? _filter;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppStore>().data;
    final p = context.pal;
    final roots = _filter == null
        ? data.goals.where((g) => data.goal(g.parentId) == null).toList()
        : data.goals.where((g) => g.level == _filter).toList();
    roots.sort((a, b) {
      final l = a.level.index.compareTo(b.level.index);
      return l != 0 ? l : b.periodKey.compareTo(a.periodKey);
    });
    // Carried copies and reading goals live on the Today screen and in Books.
    roots.removeWhere(
      (g) =>
          g.carriedFrom != null &&
          g.repeat == Repeat.none &&
          g.parentId != null,
    );

    final best = data.goals
        .where((g) => g.isDaily && g.repeat != Repeat.none)
        .fold<int>(
          0,
          (m, g) => data.streak(g, today()) > m ? data.streak(g, today()) : m,
        );
    final qada = data.qadaList().length;

    return Column(
      children: [
        OrnateHeader(
          title: tr('أهدافي'),
          bottom: _LevelTabs(
            selected: _filter,
            onChanged: (l) => setState(() => _filter = l),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MiniCard(
                      icon: Rosette(size: 26, color: p.gold, filled: true),
                      title: tr('التزامي'),
                      value: tr('{n} يوم', {'n': best}),
                      badge: qada > 0 ? tr('قضاء {n}', {'n': qada}) : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StreakPage()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniCard(
                      icon: Icon(Icons.auto_stories_outlined, color: p.gold),
                      title: tr('كتبي'),
                      value: tr('{n} كتاب', {'n': data.books.length}),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BooksPage()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniCard(
                      icon: Icon(Icons.bar_chart, color: p.gold),
                      title: tr('الرسم البياني'),
                      value: tr('عملت إيه وما عملتش إيه'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StatsPage()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniCard(
                      icon: Icon(Icons.grid_view, color: p.gold),
                      title: tr('جدول السنة'),
                      value: tr('شهور، أسابيع، أيام'),
                      onTap: () => openGoalPlan(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (roots.isEmpty) EmptyNote(tr('لسه مفيش أهداف هنا.')),
              for (final g in roots) ...[
                _GoalTree(goal: g),
                const SizedBox(height: 14),
              ],
              _NewGoalBox(),
            ],
          ),
        ),
      ],
    );
  }
}

class _LevelTabs extends StatelessWidget {
  const _LevelTabs({required this.selected, required this.onChanged});

  final Level? selected;
  final ValueChanged<Level?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <(Level?, String)>[
      (null, tr('الكل')),
      for (final l in Level.values) (l, levelName(l)),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final (l, label) in items)
            Expanded(
              child: Semantics(
                selected: l == selected,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onChanged(l),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: l == selected
                          ? context.pal.gold
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: l == selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: l == selected
                            ? const Color(0xFF1F2A2E)
                            : const Color(0xFFF6F1E7),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.badge,
  });

  final Widget icon;
  final String title, value;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.gold.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Muted(value),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: p.red,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalTree extends StatelessWidget {
  const _GoalTree({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SectionCard(
      color: p.card,
      border: p.gold.withValues(alpha: 0.5),
      child: _GoalNode(goal: goal, depth: 0),
    );
  }
}

class _GoalNode extends StatelessWidget {
  const _GoalNode({required this.goal, required this.depth});

  final Goal goal;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final data = store.data;
    final p = context.pal;
    final kids = data.children(goal.id);
    final progress = data.progress(goal);
    final top = depth == 0;
    final (done, total) = data.tally(goal);

    final header = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => openGoalEditor(context, goal: goal),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${levelName(goal.level)} · ${periodLabel(goal)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: top ? p.goldText : p.muted,
                      fontWeight: top ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  Text(
                    goal.title,
                    style: TextStyle(
                      fontSize: top ? 18 : 15,
                      fontWeight: top ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!goal.isDaily && kids.isEmpty)
              Checkbox(
                value: goal.manualDone,
                onChanged: (v) =>
                    store.update((_) => goal.manualDone = v ?? false),
              )
            else if (goal.isDaily && goal.repeat != Repeat.none)
              Text(
                n('$done/$total'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            else
              Text(
                pct(progress),
                style: TextStyle(
                  fontSize: top ? 15 : 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (!goal.isDaily) ...[
          const SizedBox(height: 6),
          Bar(progress, label: goal.title),
        ],
        if (top)
          Wrap(
            spacing: 4,
            children: [
              if (!goal.isDaily)
                TextButton.icon(
                  onPressed: () => openGoalPlan(context, goal: goal),
                  icon: const Icon(Icons.grid_view, size: 18),
                  label: Text(tr('الجدول')),
                ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StatsPage(goalId: goal.id)),
                ),
                icon: const Icon(Icons.bar_chart, size: 18),
                label: Text(tr('الرسم البياني')),
              ),
            ],
          ),
        if (goal.isDaily && goal.repeat != Repeat.none) ...[
          const SizedBox(height: 6),
          WeekStrip(goal: goal),
        ],
        if (kids.isNotEmpty || goal.level != Level.day)
          Container(
            margin: const EdgeInsetsDirectional.only(start: 6, top: 8),
            padding: const EdgeInsetsDirectional.only(start: 14),
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(
                  color: p.gold.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final k in kids) ...[
                  _GoalNode(goal: k, depth: depth + 1),
                  const SizedBox(height: 8),
                ],
                if (goal.level != Level.day)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () =>
                          openGoalEditor(context, parentId: goal.id),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        tr('قسّمه: هدف {l} تحته', {
                          'l': levelName(Level.values[goal.level.index + 1]),
                        }),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Saturday-to-Friday squares for the current week: green done, red missed,
/// gold for a grace day.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppStore>().data;
    final p = context.pal;
    final ws = weekStart(today());
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (_) {
              final d = addDays(ws, i);
              final occurs = data.occursOn(goal, d);
              final st = data.status(goal, d);
              final isToday = sameDay(d, today());
              Color? fill;
              Color text = p.muted;
              if (occurs && st != null) {
                if (Occ.counts.contains(st)) {
                  fill = p.green;
                } else if (st == Occ.grace) {
                  fill = p.gold;
                } else if (st != Occ.carried) {
                  fill = p.red;
                }
              }
              if (fill != null) text = st == Occ.grace ? p.ink : Colors.white;
              return Semantics(
                label: '${weekdayName(d.weekday)} ${st ?? ''}',
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(9),
                    border: fill == null
                        ? Border.all(
                            color: isToday ? p.primary : p.chip,
                            width: isToday ? 2 : 1,
                          )
                        : null,
                  ),
                  child: Text(
                    weekdayShort(d.weekday),
                    style: TextStyle(
                      fontSize: 12,
                      color: occurs ? text : p.muted.withValues(alpha: 0.4),
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

class _NewGoalBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.chip, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('هدف جديد — ابدأ من أي مستوى'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final l in Level.values) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(
                        fontFamily: kBody,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => openGoalEditor(context, level: l),
                    child: Text(levelName(l)),
                  ),
                ),
                if (l != Level.day) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Streaks, grace days and the qada balance.
class StreakPage extends StatelessWidget {
  const StreakPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final data = store.data;
    final p = context.pal;
    final habits =
        data.goals.where((g) => g.isDaily && g.repeat != Repeat.none).toList()
          ..sort(
            (a, b) =>
                data.streak(b, today()).compareTo(data.streak(a, today())),
          );
    final qada = data.qadaList();
    final unplanned = qada.where((q) => q.$3 == null).toList();
    final friday = addDays(today(), (DateTime.friday - today().weekday) % 7);

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: tr('التزامي'),
            leading: const BackButton(color: Color(0xFFF6F1E7)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (habits.isEmpty)
                  EmptyNote(tr('السلسلة بتظهر للأهداف اللي بتتكرر.')),
                for (final g in habits) ...[
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Rosette(size: 40, color: p.gold, filled: true),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('{n} يوم', {
                                      'n': data.streak(g, today()),
                                    }),
                                    style: TextStyle(
                                      fontFamily: kDisplay,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                  Muted(g.title),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        WeekStrip(goal: g),
                        if (g.grace) ...[
                          const SizedBox(height: 8),
                          HintBox(
                            tr(
                              'يوم الرحمة شغال: يوم واحد في الأسبوع يفوتك من غير ما السلسلة تتكسر.',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr('رصيد القضاء'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: qada.isEmpty ? p.green : p.red,
                            child: Text(
                              n(qada.length),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (qada.isEmpty)
                        Muted(tr('مفيش قضاء عليك. ما شاء الله!'), size: 14),
                      for (final (g, d, plan) in qada) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: p.hint,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: p.gold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Muted(
                                      plan == null
                                          ? tr('فاتك {d}', {
                                              'd': fmtDateShort(d),
                                            })
                                          : tr('فاتك {d} · متحط يوم {p}', {
                                              'd': fmtDayMonth(d),
                                              'p': fmtDateShort(parseKey(plan)),
                                            }),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    store.update((x) => x.payQada(g, d)),
                                child: Text(tr('اقضِه')),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (unplanned.isNotEmpty) ...[
                        HintBox(
                          sameDay(friday, today())
                              ? tr('النهارده الجمعة، تحب تقضيهم النهارده؟')
                              : tr('تحب تحطهم يوم الجمعة {d}؟', {
                                  'd': fmtDayMonth(friday),
                                }),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => store.update((x) {
                            for (final (g, d, _) in unplanned) {
                              x.planQada(g, d, friday);
                            }
                          }),
                          child: Text(tr('حطّهم يوم الجمعة')),
                        ),
                      ],
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
