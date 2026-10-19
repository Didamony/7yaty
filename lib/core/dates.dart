/// Date helpers. All dates in the app are local calendar days keyed as
/// `yyyy-MM-dd`; the week starts on Saturday, as is usual in Egypt.
library;

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dayOnly(DateTime.now());

String dkey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseKey(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p.length > 1 ? p[1] : 1, p.length > 2 ? p[2] : 1);
}

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

DateTime weekStart(DateTime d) =>
    addDays(dayOnly(d), -((d.weekday - DateTime.saturday) % 7));

DateTime monthStart(DateTime d) => DateTime(d.year, d.month, 1);

DateTime monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Whole calendar days from [a] to [b], unaffected by daylight saving.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

Iterable<DateTime> daysInRange(DateTime from, DateTime to) sync* {
  for (var d = dayOnly(from); !d.isAfter(to); d = addDays(d, 1)) {
    yield d;
  }
}

String hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
