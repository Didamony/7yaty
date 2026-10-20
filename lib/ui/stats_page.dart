import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/stats.dart';
import '../data/store.dart';
import 'charts.dart';
import 'widgets.dart';

String spanName(Span s) => tr(switch (s) {
  Span.week => 'أسبوع',
  Span.month => 'شهر',
  Span.year => 'سنة',
});

String spanTitle(Span s, DateTime ref) => switch (s) {
  Span.week => tr('من {a} لـ {b}', {
    'a': fmtDayMonth(weekStart(ref)),
    'b': fmtDayMonth(addDays(weekStart(ref), 6)),
  }),
  Span.month => fmtMonth(ref),
  Span.year => n(ref.year),
};

DateTime shiftSpan(Span s, DateTime ref, int by) => switch (s) {
  Span.week => addDays(ref, 7 * by),
  Span.month => DateTime(ref.year, ref.month + by, 1),
  Span.year => DateTime(ref.year + by, ref.month, 1),
};

String goalLabel(Goal g) => '${levelName(g.level)} · ${g.title}';

/// Charts of done and not done: one task (or all) over a week, month or
/// year, or two tasks one above the other.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key, this.goalId});

  final String? goalId;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _compare = false;
  Span _span = Span.week;
  DateTime _ref = today();
  late String? _a = widget.goalId;
  String? _b;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppStore>().data;
    final p = context.pal;
    final choices =
        data.goals
            .where((g) => !(g.carriedFrom != null && g.repeat == Repeat.none))
            .toList()
          ..sort((x, y) => x.level.index.compareTo(y.level.index));
    if (_a != null && data.goal(_a) == null) _a = null;
    if (_b != null && data.goal(_b) == null) _b = null;

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: tr('الرسم البياني'),
            leading: const BackButton(color: Color(0xFFF6F1E7)),
            bottom: _Toggle(
              compare: _compare,
              onChanged: (v) => setState(() {
                _compare = v;
                if (!v) return;
                // Start with two daily tasks so there is something to see.
                final daily = [
                  ...choices.where((g) => g.isDaily && g.repeat != Repeat.none),
                  ...choices.where((g) => g.isDaily && g.repeat == Repeat.none),
                ].map((g) => g.id);
                _a ??= daily.firstOrNull;
                _b ??= daily.where((id) => id != _a).firstOrNull;
              }),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Pills<Span>(
                  values: Span.values,
                  selected: _span,
                  label: spanName,
                  onSelected: (s) => setState(() => _span = s),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      tooltip: tr('اللي قبله'),
                      onPressed: () =>
                          setState(() => _ref = shiftSpan(_span, _ref, -1)),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        spanTitle(_span, _ref),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr('اللي بعده'),
                      onPressed: () =>
                          setState(() => _ref = shiftSpan(_span, _ref, 1)),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _GoalPicker(
                  label: _compare ? tr('المهمة الأولى') : tr('المهمة'),
                  value: _a,
                  goals: choices,
                  allowAll: !_compare,
                  onChanged: (v) => setState(() => _a = v),
                ),
                const SizedBox(height: 12),
                if (!_compare) ...[
                  _ChartCard(
                    data: data,
                    goal: data.goal(_a),
                    span: _span,
                    ref: _ref,
                  ),
                  if (_a == null || !data.goal(_a)!.isDaily) ...[
                    const SizedBox(height: 12),
                    _Ranking(
                      data: data,
                      goal: data.goal(_a),
                      span: _span,
                      ref: _ref,
                    ),
                  ],
                ] else ...[
                  _GoalPicker(
                    label: tr('المهمة التانية'),
                    value: _b,
                    goals: choices,
                    allowAll: false,
                    onChanged: (v) => setState(() => _b = v),
                  ),
                  const SizedBox(height: 12),
                  if (_a == null || _b == null)
                    EmptyNote(tr('اختار مهمتين عشان تقارن بينهم.'))
                  else
                    ..._comparison(context, data),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _comparison(BuildContext context, AppData data) {
    final now = DateTime.now();
    final ga = data.goal(_a)!, gb = data.goal(_b)!;
    final ta = total(buckets(data, dailyGoalsOf(data, ga), _span, _ref, now));
    final tb = total(buckets(data, dailyGoalsOf(data, gb), _span, _ref, now));
    final ra = ta.rate, rb = tb.rate;
    String verdict;
    if (ra == null || rb == null) {
      verdict = tr('لسه مفيش أيام كفاية عشان أقارن.');
    } else if ((ra - rb).abs() < 0.05) {
      verdict = tr('مستواك قريب في الاتنين ({a} و{b}).', {
        'a': rateText(ra),
        'b': rateText(rb),
      });
    } else {
      final (better, worse, rBetter, rWorse) = ra > rb
          ? (ga, gb, ra, rb)
          : (gb, ga, rb, ra);
      verdict = tr('كنت أحسن في «{a}» ({ra}) من «{b}» ({rb}).', {
        'a': better.title,
        'ra': rateText(rBetter),
        'b': worse.title,
        'rb': rateText(rWorse),
      });
    }
    return [
      _ChartCard(data: data, goal: ga, span: _span, ref: _ref),
      const SizedBox(height: 12),
      _ChartCard(data: data, goal: gb, span: _span, ref: _ref),
      const SizedBox(height: 12),
      SectionCard(
        border: context.pal.gold,
        child: Row(
          children: [
            Rosette(size: 30, color: context.pal.gold, filled: true),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                verdict,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.compare, required this.onChanged});

  final bool compare;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget tab(bool v, String label) => Expanded(
      child: Semantics(
        selected: v == compare,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => onChanged(v),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: v == compare ? p.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: v == compare ? FontWeight.w600 : FontWeight.w400,
                color: v == compare
                    ? const Color(0xFF1F2A2E)
                    : const Color(0xFFF6F1E7),
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [tab(false, tr('مهمة')), tab(true, tr('مقارنة مهمتين'))],
      ),
    );
  }
}

class _GoalPicker extends StatelessWidget {
  const _GoalPicker({
    required this.label,
    required this.value,
    required this.goals,
    required this.allowAll,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<Goal> goals;
  final bool allowAll;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String?>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      if (allowAll) DropdownMenuItem(value: null, child: Text(tr('كل المهام'))),
      for (final g in goals)
        DropdownMenuItem(
          value: g.id,
          child: Text(goalLabel(g), overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.data,
    required this.goal,
    required this.span,
    required this.ref,
  });

  final AppData data;
  final Goal? goal;
  final Span span;
  final DateTime ref;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bs = buckets(
      data,
      dailyGoalsOf(data, goal),
      span,
      ref,
      DateTime.now(),
    );
    final t = total(bs);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal == null ? tr('كل المهام') : goal!.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: rateColor(context, t.rate),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  rateText(t.rate),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Muted(
            tr('{d} اتعمل، {m} ما اتعملش', {'d': t.done, 'm': t.missed}) +
                (t.excused > 0
                    ? '${listSep()}${tr('{n} معذور', {'n': t.excused})}'
                    : ''),
          ),
          const SizedBox(height: 12),
          if (t.done + t.missed + t.excused + t.pending == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Muted(tr('مفيش مهام يومية في الفترة دي.'), size: 13),
              ),
            )
          else
            StackedBars(
              buckets: bs,
              label: (b) => bucketLabel(span, b),
              showLabel: span == Span.month ? (i) => i % 5 == 0 : null,
            ),
          const SizedBox(height: 10),
          const ChartLegend(),
          Divider(color: p.line, height: 20),
        ],
      ),
    );
  }
}

/// The daily tasks inside the chosen scope, best to worst.
class _Ranking extends StatelessWidget {
  const _Ranking({
    required this.data,
    required this.goal,
    required this.span,
    required this.ref,
  });

  final AppData data;
  final Goal? goal;
  final Span span;
  final DateTime ref;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final rows =
        [
            for (final g in dailyGoalsOf(data, goal))
              (g, total(buckets(data, [g], span, ref, now))),
          ].where((r) => r.$2.counted > 0).toList()
          ..sort((x, y) => (y.$2.rate ?? 0).compareTo(x.$2.rate ?? 0));
    if (rows.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoldLabel(tr('كل مهمة لوحدها')),
          const SizedBox(height: 8),
          for (final (g, t) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.title,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        rateText(t.rate),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: rateColor(context, t.rate),
                          fontFamily: kBody,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: t.rate ?? 0,
                      minHeight: 8,
                      backgroundColor: context.pal.redBg,
                      color: rateColor(context, t.rate),
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
