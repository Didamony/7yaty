import 'package:intl/intl.dart';

import '../data/models.dart';
import 'strings.dart';

/// The app is written with its Arabic text inline: `tr('أهدافي')`. The other
/// languages look that text up in [translations]; anything missing falls
/// back to Arabic.
class L10n {
  static String lang = 'ar';

  static const supported = ['ar', 'en', 'fr', 'de'];

  static const names = {
    'ar': 'العربية',
    'en': 'English',
    'fr': 'Français',
    'de': 'Deutsch',
  };

  static bool get rtl => lang == 'ar';
}

String tr(String ar, [Map<String, Object>? args]) {
  var s = L10n.lang == 'ar' ? ar : (translations[L10n.lang]?[ar] ?? ar);
  args?.forEach((k, v) => s = s.replaceAll('{$k}', v is num ? n(v) : '$v'));
  return s;
}

const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

/// Numbers in Arabic-Indic digits when the app is in Arabic.
String n(Object v) {
  final s = v is double ? v.toStringAsFixed(0) : '$v';
  if (L10n.lang != 'ar') return s;
  return s.replaceAllMapped(
    RegExp(r'[0-9]'),
    (m) => _arabicDigits[int.parse(m[0]!)],
  );
}

String pct(double v) {
  final x = (v * 100).round();
  return L10n.lang == 'ar' ? '${n(x)}٪' : '$x%';
}

String fmtMinutes(int minutes) =>
    fmtTime(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));

String fmtTime(DateTime t) {
  switch (L10n.lang) {
    case 'ar':
      final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
      return n(
        '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'ص' : 'م'}',
      );
    case 'en':
      return DateFormat.jm('en').format(t);
    default:
      return DateFormat.Hm(L10n.lang).format(t);
  }
}

String _locale() => L10n.lang;

/// "الاثنين، ١٩ أكتوبر ٢٠٢٦"
String fmtDateLong(DateTime d) => n(DateFormat.yMMMMEEEEd(_locale()).format(d));

/// "الاثنين ١٩ أكتوبر"
String fmtDateShort(DateTime d) => n(DateFormat.MMMMEEEEd(_locale()).format(d));

String fmtMonth(DateTime d) => n(DateFormat.yMMMM(_locale()).format(d));

String fmtDayMonth(DateTime d) => n(DateFormat.MMMd(_locale()).format(d));

String weekdayShort(int weekday) =>
    tr(const ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'][weekday - 1]);

String weekdayName(int weekday) => tr(
  const [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ][weekday - 1],
);

String prayerName(Prayer p) => tr(
  const {
    Prayer.fajr: 'الفجر',
    Prayer.dhuhr: 'الظهر',
    Prayer.asr: 'العصر',
    Prayer.maghrib: 'المغرب',
    Prayer.isha: 'العشاء',
  }[p]!,
);

String levelName(Level l) => tr(
  const {
    Level.year: 'سنوي',
    Level.month: 'شهري',
    Level.week: 'أسبوعي',
    Level.day: 'يومي',
  }[l]!,
);

String cityName(int i) => tr(cities[i].key);

/// "بعد ٤٢ د" or "بعد ٤ س ٥٤ د".
String inDuration(int mins) => mins < 60
    ? tr('بعد {n} د', {'n': mins})
    : tr('بعد {h} س {m} د', {'h': mins ~/ 60, 'm': mins % 60});

String minutesLabel(int m) {
  if (m == 0) return tr('في الميعاد');
  if (m % 60 == 0) {
    final h = m ~/ 60;
    return h == 1 ? tr('ساعة') : tr('{n} ساعات', {'n': h});
  }
  return tr('{n} د', {'n': m});
}
