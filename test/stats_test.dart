import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/dates.dart';
import 'package:hayati/data/models.dart';
import 'package:hayati/data/stats.dart';
import 'package:hayati/data/store.dart';

void main() {
  // Thursday 22 October 2026, evening.
  final now = DateTime(2026, 10, 22, 21);
  final t = dayOnly(now);

  Goal daily(String id, {String? parent, DateTime? start}) => Goal(
    id: id,
    title: id,
    level: Level.day,
    periodKey: dkey(start ?? DateTime(2026, 10, 1)),
    repeat: Repeat.daily,
    parentId: parent,
    createdKey: dkey(start ?? DateTime(2026, 10, 1)),
  );

  test('a week counts done, missed, excused and pending days', () {
    final g = daily('a');
    final d = AppData()..goals.add(g);
    final ws = weekStart(t); // Saturday 17th
    d.setDone(g, ws, true); // Sat done
    d.occ[occKey('a', addDays(ws, 1))] = Occ.grace; // Sun excused
    d.occ[occKey('a', addDays(ws, 2))] = Occ.qada; // Mon missed
    // Tue, Wed unchecked in the past -> missed; Thu today -> pending;
    // Fri future -> pending.
    final bs = buckets(d, [g], Span.week, t, now);
    expect(bs.length, 7);
    final sum = total(bs);
    expect(sum.done, 1);
    expect(sum.excused, 1);
    expect(sum.missed, 3);
    expect(sum.pending, 2);
    expect(sum.rate, closeTo(0.25, 1e-9));
  });

  test('a year has twelve months and ignores days before the goal began', () {
    final g = daily('b', start: DateTime(2026, 10, 20));
    final d = AppData()..goals.add(g);
    d.setDone(g, DateTime(2026, 10, 20), true);
    final bs = buckets(d, [g], Span.year, t, now);
    expect(bs.length, 12);
    expect(bs[8].tally.counted, 0); // September
    expect(bs[9].tally.done, 1); // October
    expect(bs[9].tally.missed, 1); // the 21st
  });

  test('a yearly goal is measured by the daily goals under it', () {
    final y = Goal(
      id: 'y',
      title: 'y',
      level: Level.year,
      periodKey: '2026',
      createdKey: '2026-01-01',
    );
    final m = Goal(
      id: 'm',
      title: 'm',
      level: Level.month,
      periodKey: '2026-10',
      parentId: 'y',
      createdKey: '2026-10-01',
    );
    final g = daily('c', parent: 'm');
    final other = daily('x');
    final d = AppData()..goals.addAll([y, m, g, other]);
    expect(dailyGoalsOf(d, y).map((e) => e.id), ['c']);
    expect(dailyGoalsOf(d, null).length, 2);
    expect(
      goalsInPeriod(
        d,
        y,
        Level.month,
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 31),
      ).map((e) => e.id),
      ['m'],
    );
    expect(
      goalsInPeriod(
        d,
        y,
        Level.month,
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 30),
      ),
      isEmpty,
    );
  });

  test('weeks of a month start on Saturday and cover it', () {
    final ws = weeksOfMonth(DateTime(2026, 10, 1));
    expect(ws.first, DateTime(2026, 9, 26));
    expect(addDays(ws.last, 6).isBefore(DateTime(2026, 10, 31)), isFalse);
    expect(ws.length, 6);
  });

  test('a daily task planned for one month stops at its end', () {
    final g = daily('m')..untilKey = dkey(DateTime(2026, 10, 31));
    final d = AppData()..goals.add(g);
    expect(d.occursOn(g, DateTime(2026, 10, 31)), isTrue);
    expect(d.occursOn(g, DateTime(2026, 11, 1)), isFalse);
    expect(g.period.$2, DateTime(2026, 10, 31));
    final back = Goal.fromJson(g.toJson());
    expect(back.untilKey, '2026-10-31');
  });
}
