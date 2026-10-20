import '../core/dates.dart';
import 'models.dart';
import 'store.dart';

/// Done and not-done counts of daily occurrences in a span of days.
class Tally {
  int done = 0;

  /// Missed, put to qada, or left unchecked on a past day.
  int missed = 0;

  /// Grace days, carried or dismissed occurrences: neither done nor missed.
  int excused = 0;

  /// Today's unchecked and future occurrences.
  int pending = 0;

  int get counted => done + missed;

  /// Share done of what could be judged, or null if nothing could.
  double? get rate => counted == 0 ? null : done / counted;

  void add(Tally o) {
    done += o.done;
    missed += o.missed;
    excused += o.excused;
    pending += o.pending;
  }
}

enum Span { week, month, year }

/// A labelled part of a span: a day, or a month for a year.
class Bucket {
  Bucket(this.from, this.to, this.tally);

  final DateTime from;
  final DateTime to;
  final Tally tally;
}

/// Daily goals that make up [g]: itself if daily, else every daily goal
/// under it. With no goal, every daily goal.
List<Goal> dailyGoalsOf(AppData d, Goal? g) {
  if (g == null) return d.goals.where((x) => x.isDaily).toList();
  if (g.isDaily) return [g];
  return d.descendants(g.id).where((x) => x.isDaily).toList();
}

Tally tallyRange(
  AppData d,
  List<Goal> goals,
  DateTime from,
  DateTime to,
  DateTime now,
) {
  final t = Tally();
  final today = dayOnly(now);
  for (final day in daysInRange(from, to)) {
    for (final g in goals) {
      if (!d.occursOn(g, day)) continue;
      if (day.isBefore(parseKey(g.createdKey))) continue;
      switch (d.status(g, day)) {
        case Occ.done || Occ.qadaPaid:
          t.done++;
        case Occ.missed || Occ.qada:
          t.missed++;
        case Occ.grace || Occ.carried || Occ.dismissed:
          t.excused++;
        default:
          day.isBefore(today) ? t.missed++ : t.pending++;
      }
    }
  }
  return t;
}

/// The span containing [ref], split into days (week, month) or months
/// (year).
List<Bucket> buckets(
  AppData d,
  List<Goal> goals,
  Span span,
  DateTime ref,
  DateTime now,
) {
  switch (span) {
    case Span.week:
      final s = weekStart(ref);
      return [
        for (var i = 0; i < 7; i++)
          Bucket(
            addDays(s, i),
            addDays(s, i),
            tallyRange(d, goals, addDays(s, i), addDays(s, i), now),
          ),
      ];
    case Span.month:
      return [
        for (final day in daysInRange(monthStart(ref), monthEnd(ref)))
          Bucket(day, day, tallyRange(d, goals, day, day, now)),
      ];
    case Span.year:
      return [
        for (var m = 1; m <= 12; m++)
          Bucket(
            DateTime(ref.year, m, 1),
            monthEnd(DateTime(ref.year, m, 1)),
            tallyRange(
              d,
              goals,
              DateTime(ref.year, m, 1),
              monthEnd(DateTime(ref.year, m, 1)),
              now,
            ),
          ),
      ];
  }
}

Tally total(Iterable<Bucket> bs) {
  final t = Tally();
  for (final b in bs) {
    t.add(b.tally);
  }
  return t;
}

/// The Saturday-started weeks that touch [month].
List<DateTime> weeksOfMonth(DateTime month) {
  final out = <DateTime>[];
  for (
    var w = weekStart(monthStart(month));
    !w.isAfter(monthEnd(month));
    w = addDays(w, 7)
  ) {
    out.add(w);
  }
  return out;
}

/// Goals of [level] under [root] (or all) whose period overlaps from..to.
List<Goal> goalsInPeriod(
  AppData d,
  Goal? root,
  Level level,
  DateTime from,
  DateTime to,
) {
  final pool = root == null ? d.goals : [root, ...d.descendants(root.id)];
  return pool.where((g) {
    if (g.level != level) return false;
    final (s, e) = g.period;
    return !s.isAfter(to) && !e.isBefore(from);
  }).toList();
}
