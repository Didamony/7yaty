import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/notifications.dart';
import '../services/prayer.dart';
import 'books.dart';
import 'goal_editor.dart';
import 'settings.dart';
import 'widgets.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.onOpenGoals});

  final VoidCallback onOpenGoals;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  DateTime _day = today();
  late Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  bool get _isToday => sameDay(_day, today());

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final data = store.data;
    final s = store.settings;
    final p = context.pal;
    final now = DateTime.now();

    final goals = data.goalsOn(_day)
      ..sort((a, b) {
        final ta = PrayerTimes.goalTime(a, _day, s.city);
        final tb = PrayerTimes.goalTime(b, _day, s.city);
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return ta.compareTo(tb);
      });
    final qada = data.qadaPlannedOn(_day);
    final total = goals.length + qada.length;
    final done =
        goals.where((g) => data.status(g, _day) == Occ.done).length +
        qada.where((q) => data.status(q.$1, q.$2) == Occ.qadaPaid).length;
    final misses = _isToday ? data.pendingMisses() : <(Goal, DateTime)>[];
    final (nextPrayer, nextAt) = PrayerTimes.next(now, s.city);
    final mins = nextAt.difference(now).inMinutes;

    return Column(
      children: [
        OrnateHeader(
          title: tr('حياتي'),
          logo: true,
          subtitle: fmtDateLong(_day),
          actions: [
            HeaderIconButton(
              icon: Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              tooltip: tr('الوضع الداكن'),
              onPressed: () => store.update(
                (d) => d.settings.theme =
                    Theme.of(context).brightness == Brightness.dark
                    ? 'light'
                    : 'dark',
              ),
            ),
            HeaderIconButton(
              icon: Icons.settings_outlined,
              tooltip: tr('الإعدادات'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
          ],
          bottom: _NextPrayer(
            name: prayerName(nextPrayer),
            at: fmtTime(nextAt),
            inText: inDuration(mins),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
            children: [
              _DayNav(
                day: _day,
                onPrev: () => setState(() => _day = addDays(_day, -1)),
                onNext: _isToday
                    ? null
                    : () => setState(() => _day = addDays(_day, 1)),
                onToday: () => setState(() => _day = today()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Ring(done: done, total: total),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isToday ? tr('أهداف اليوم') : tr('أهداف اليوم ده'),
                          style: const TextStyle(
                            fontFamily: kDisplay,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Muted(
                          tr('مراجعة المساء الساعة {t}', {
                            't': fmtMinutes(s.reviewMin),
                          }),
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    tooltip: tr('إضافة هدف'),
                    onPressed: () =>
                        openGoalEditor(context, level: Level.day, day: _day),
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: p.gold, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (total == 0)
                EmptyNote(
                  _isToday
                      ? tr(
                          'مفيش أهداف النهارده. اضغط + وضيف أول هدف، أو قسّم هدف كبير من "أهدافي".',
                        )
                      : tr('مفيش أهداف في اليوم ده.'),
                ),
              for (final g in goals) ...[
                _GoalTile(goal: g, day: _day),
                const SizedBox(height: 8),
              ],
              for (final (g, d) in qada) ...[
                _QadaTile(goal: g, missedOn: d, day: _day),
                const SizedBox(height: 8),
              ],
              if (misses.isNotEmpty) ...[
                const StarDivider(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    tr('ما اتعملش ({n})', {'n': misses.length}),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: p.redText,
                    ),
                  ),
                ),
                for (final (g, d) in misses) ...[
                  _MissTile(goal: g, day: d),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NextPrayer extends StatelessWidget {
  const _NextPrayer({
    required this.name,
    required this.at,
    required this.inText,
  });

  final String name, at, inText;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0x1FF6F1E7),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.pal.gold.withValues(alpha: 0.6)),
    ),
    child: Row(
      children: [
        Icon(Icons.mosque_outlined, color: context.pal.gold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('الصلاة القادمة'),
                style: const TextStyle(fontSize: 12, color: Color(0xD9F6F1E7)),
              ),
              Text(
                '$name · $at',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF6F1E7),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: context.pal.gold,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            inText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2A2E),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DayNav extends StatelessWidget {
  const _DayNav({
    required this.day,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime day;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final isToday = sameDay(day, today());
    return Row(
      children: [
        IconButton(
          tooltip: tr('اليوم السابق'),
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: isToday
                ? Muted(tr('النهارده'), size: 14)
                : TextButton(
                    onPressed: onToday,
                    child: Text(
                      tr('ارجع للنهارده · {d}', {'d': fmtDayMonth(day)}),
                    ),
                  ),
          ),
        ),
        IconButton(
          tooltip: tr('اليوم التالي'),
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.done, required this.total});

  final int done, total;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      label: tr('{d} من {t} مكتملة', {'d': done, 't': total}),
      child: SizedBox.square(
        dimension: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: total == 0 ? 0 : done / total,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                backgroundColor: p.line,
                color: p.green,
              ),
            ),
            Text(
              '${n(done)}/${n(total)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

String goalWhen(AppData data, Goal g, DateTime day) {
  final t = PrayerTimes.goalTime(g, day, data.settings.city);
  if (t == null) return '';
  if (g.timeMode == TimeMode.prayer) {
    return tr(g.before ? 'قبل {p} · {t}' : 'بعد {p} · {t}', {
      'p': prayerName(g.prayer),
      't': fmtTime(t),
    });
  }
  return fmtTime(t);
}

String goalOrigin(AppData data, Goal g) {
  final chain = data.ancestors(g);
  if (chain.isEmpty) return tr('يومي فقط');
  final top = chain.last;
  return '${levelName(top.level)} › ${top.title}';
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.day});

  final Goal goal;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final data = store.data;
    final p = context.pal;
    final done = data.status(goal, day) == Occ.done;
    final when = goalWhen(data, goal, day);
    final streak = goal.repeat == Repeat.none ? 0 : data.streak(goal, day);
    final book = data.book(goal.bookId);
    final sub = [
      goalOrigin(data, goal),
      if (when.isNotEmpty) when,
      if (goal.carriedFrom != null)
        tr('مرحّل من {d}', {'d': fmtDayMonth(parseKey(goal.carriedFrom!))}),
    ].join(' · ');

    return Material(
      color: done ? p.greenBg : p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: done ? p.greenLine : p.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => book != null
            ? openReader(context, book)
            : openGoalEditor(context, goal: goal),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _CheckBox(
                checked: done,
                label: goal.title,
                onTap: () => store.update((d) => d.setDone(goal, day, !done)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goalTitle(data, goal, day),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: done ? p.greenText : p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 12,
                        color: done ? p.greenText : p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (streak >= 2)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Rosette(size: 14, color: p.gold, filled: true),
                      const SizedBox(width: 3),
                      Text(
                        n(streak),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.goldText,
                        ),
                      ),
                    ],
                  ),
                ),
              if (book != null) Icon(Icons.chevron_right, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({
    required this.checked,
    required this.label,
    required this.onTap,
  });

  final bool checked;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      checked: checked,
      label: label,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: checked ? p.green : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: checked ? p.green : p.muted,
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _QadaTile extends StatelessWidget {
  const _QadaTile({
    required this.goal,
    required this.missedOn,
    required this.day,
  });

  final Goal goal;
  final DateTime missedOn, day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = context.pal;
    final paid = store.data.status(goal, missedOn) == Occ.qadaPaid;
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: paid ? p.greenBg : p.hint,
      border: paid ? p.greenLine : p.gold.withValues(alpha: 0.5),
      child: Row(
        children: [
          _CheckBox(
            checked: paid,
            label: goal.title,
            onTap: paid
                ? () {}
                : () => store.update((d) => d.payQada(goal, missedOn)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('قضاء: {t}', {'t': goal.title}),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Muted(tr('فاتك {d}', {'d': fmtDateShort(missedOn)})),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissTile extends StatelessWidget {
  const _MissTile({required this.goal, required this.day});

  final Goal goal;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final p = context.pal;
    return SectionCard(
      color: p.redBg,
      border: p.redLine,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            goal.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: p.redText,
            ),
          ),
          Text(
            fmtDateShort(day),
            style: TextStyle(fontSize: 12, color: p.redText),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      store.update((d) => d.carry(goal, day, today())),
                  style: FilledButton.styleFrom(
                    backgroundColor: p.header,
                    foregroundColor: const Color(0xFFF6F1E7),
                  ),
                  child: Text(tr('رحّله لليوم')),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => store.update((d) => d.toQada(goal, day)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.goldText,
                    side: BorderSide(color: p.gold),
                  ),
                  child: Text(tr('قضاء')),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    if (goal.repeat != Repeat.none ||
                        await confirm(
                          context,
                          tr('تمسح الهدف ده خالص؟'),
                          ok: tr('امسحه'),
                        )) {
                      store.update((d) => d.dismiss(goal, day));
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.redText,
                    side: BorderSide(color: p.redLine),
                  ),
                  child: Text(tr('امسحه')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
