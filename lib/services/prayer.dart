import 'package:adhan/adhan.dart' as adhan;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/dates.dart';
import '../data/models.dart';

/// Prayer times for Egyptian cities by the Egyptian General Authority of
/// Survey method, returned in Cairo local time (daylight saving included).
class PrayerTimes {
  static bool _ready = false;
  static late tz.Location cairo;

  static void init() {
    if (_ready) return;
    tzdata.initializeTimeZones();
    cairo = tz.getLocation('Africa/Cairo');
    tz.setLocalLocation(cairo);
    _ready = true;
  }

  static final _cache = <String, Map<Prayer, DateTime>>{};

  static Map<Prayer, DateTime> forDay(DateTime day, int cityIndex) {
    init();
    final key = '${dkey(day)}#$cityIndex';
    return _cache.putIfAbsent(key, () {
      final city = cities[cityIndex.clamp(0, cities.length - 1)];
      final params = adhan.CalculationMethod.egyptian.getParameters()
        ..madhab = adhan.Madhab.shafi;
      final t = adhan.PrayerTimes.utc(
        adhan.Coordinates(city.lat, city.lng),
        adhan.DateComponents(day.year, day.month, day.day),
        params,
      );
      DateTime local(DateTime utc) {
        final c = tz.TZDateTime.from(utc, cairo);
        return DateTime(c.year, c.month, c.day, c.hour, c.minute);
      }

      return {
        Prayer.fajr: local(t.fajr),
        Prayer.dhuhr: local(t.dhuhr),
        Prayer.asr: local(t.asr),
        Prayer.maghrib: local(t.maghrib),
        Prayer.isha: local(t.isha),
      };
    });
  }

  /// The next prayer at or after [now], possibly tomorrow's Fajr.
  static (Prayer, DateTime) next(DateTime now, int cityIndex) {
    final times = forDay(now, cityIndex);
    for (final p in Prayer.values) {
      if (times[p]!.isAfter(now)) return (p, times[p]!);
    }
    return (Prayer.fajr, forDay(addDays(now, 1), cityIndex)[Prayer.fajr]!);
  }

  /// When a goal is due on [day], or null if it has no time.
  static DateTime? goalTime(Goal g, DateTime day, int cityIndex) {
    final d = dayOnly(day);
    switch (g.timeMode) {
      case TimeMode.none:
        return null;
      case TimeMode.clock:
        return d.add(Duration(minutes: g.clockMin));
      case TimeMode.prayer:
        final p = forDay(d, cityIndex)[g.prayer]!;
        return p.add(Duration(minutes: g.before ? -g.offsetMin : g.offsetMin));
    }
  }
}
