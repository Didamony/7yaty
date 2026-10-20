import '../core/dates.dart';

enum Level { year, month, week, day }

enum Repeat { none, daily, weekdays }

enum TimeMode { none, clock, prayer }

/// What happens to a daily occurrence that was not checked off by the end
/// of its day.
enum OnMiss { ask, qada, carry }

enum Prayer { fajr, dhuhr, asr, maghrib, isha }

enum BookKind { pdf, epub }

enum PlanMode { finishInDays, chaptersPerWeek, unitsPerDay }

/// Status of one daily occurrence of a goal, stored under `goalId|yyyy-MM-dd`.
class Occ {
  static const done = 'done';
  static const grace = 'grace';
  static const missed = 'missed';
  static const qada = 'qada';
  static const qadaPaid = 'qadaPaid';
  static const carried = 'carried';
  static const dismissed = 'dismissed';

  /// Statuses that keep a streak alive.
  static const keepsStreak = {done, grace, qadaPaid};

  /// Statuses that count as accomplished for progress.
  static const counts = {done, qadaPaid};
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((e) => e.name == name, orElse: () => fallback);

class Goal {
  Goal({
    required this.id,
    required this.title,
    required this.level,
    required this.periodKey,
    this.parentId,
    this.repeat = Repeat.none,
    List<int>? weekdays,
    this.timeMode = TimeMode.none,
    this.clockMin = 8 * 60,
    this.prayer = Prayer.fajr,
    this.before = false,
    this.offsetMin = 15,
    this.onMiss = OnMiss.ask,
    this.grace = false,
    this.manualDone = false,
    this.bookId,
    this.carriedFrom,
    this.untilKey,
    required this.createdKey,
  }) : weekdays = weekdays ?? [];

  final String id;
  String title;
  Level level;

  /// year: `2026`, month: `2026-10`, week: its Saturday `2026-10-17`,
  /// day: the date of a one-off goal, or the start date of a repeating one.
  String periodKey;
  String? parentId;
  Repeat repeat;
  List<int> weekdays;
  TimeMode timeMode;
  int clockMin;
  Prayer prayer;
  bool before;
  int offsetMin;
  OnMiss onMiss;
  bool grace;

  /// Check-off for goals above the daily level that have no daily children.
  bool manualDone;
  String? bookId;
  String? carriedFrom;

  /// Last day of a repeating daily goal, or null to repeat with no end.
  String? untilKey;
  String createdKey;

  bool get isDaily => level == Level.day;

  (DateTime, DateTime) get period {
    switch (level) {
      case Level.year:
        final y = int.parse(periodKey.substring(0, 4));
        return (DateTime(y, 1, 1), DateTime(y, 12, 31));
      case Level.month:
        final m = parseKey('$periodKey-01');
        return (m, monthEnd(m));
      case Level.week:
        final s = parseKey(periodKey);
        return (s, addDays(s, 6));
      case Level.day:
        final s = parseKey(periodKey);
        if (repeat == Repeat.none) return (s, s);
        return (s, untilKey == null ? DateTime(9999) : parseKey(untilKey!));
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'level': level.name,
    'periodKey': periodKey,
    'parentId': parentId,
    'repeat': repeat.name,
    'weekdays': weekdays,
    'timeMode': timeMode.name,
    'clockMin': clockMin,
    'prayer': prayer.name,
    'before': before,
    'offsetMin': offsetMin,
    'onMiss': onMiss.name,
    'grace': grace,
    'manualDone': manualDone,
    'bookId': bookId,
    'carriedFrom': carriedFrom,
    'untilKey': untilKey,
    'createdKey': createdKey,
  };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    id: j['id'],
    title: j['title'] ?? '',
    level: _enum(Level.values, j['level'], Level.day),
    periodKey: j['periodKey'],
    parentId: j['parentId'],
    repeat: _enum(Repeat.values, j['repeat'], Repeat.none),
    weekdays: (j['weekdays'] as List?)?.cast<int>(),
    timeMode: _enum(TimeMode.values, j['timeMode'], TimeMode.none),
    clockMin: j['clockMin'] ?? 480,
    prayer: _enum(Prayer.values, j['prayer'], Prayer.fajr),
    before: j['before'] ?? false,
    offsetMin: j['offsetMin'] ?? 15,
    onMiss: _enum(OnMiss.values, j['onMiss'], OnMiss.ask),
    grace: j['grace'] ?? false,
    manualDone: j['manualDone'] ?? false,
    bookId: j['bookId'],
    carriedFrom: j['carriedFrom'],
    untilKey: j['untilKey'],
    createdKey: j['createdKey'] ?? j['periodKey'],
  );
}

class Appointment {
  Appointment({
    required this.id,
    required this.title,
    required this.dateKey,
    required this.timeMin,
    this.place = '',
    this.repeat = Repeat.none,
    List<int>? weekdays,
    List<int>? reminders,
  }) : weekdays = weekdays ?? [],
       reminders = reminders ?? [30];

  final String id;
  String title;
  String place;
  String dateKey;
  int timeMin;
  Repeat repeat;
  List<int> weekdays;

  /// Minutes before the appointment to remind; 0 means at the time itself.
  List<int> reminders;

  bool occursOn(DateTime d) {
    final start = parseKey(dateKey);
    if (d.isBefore(start)) return false;
    switch (repeat) {
      case Repeat.none:
        return sameDay(d, start);
      case Repeat.daily:
        return true;
      case Repeat.weekdays:
        return weekdays.contains(d.weekday);
    }
  }

  DateTime? nextOccurrence(DateTime from) {
    for (var i = 0; i < 370; i++) {
      final d = addDays(dayOnly(from), i);
      if (!occursOn(d)) continue;
      final at = d.add(Duration(minutes: timeMin));
      if (!at.isBefore(from)) return at;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'place': place,
    'dateKey': dateKey,
    'timeMin': timeMin,
    'repeat': repeat.name,
    'weekdays': weekdays,
    'reminders': reminders,
  };

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
    id: j['id'],
    title: j['title'] ?? '',
    place: j['place'] ?? '',
    dateKey: j['dateKey'],
    timeMin: j['timeMin'] ?? 0,
    repeat: _enum(Repeat.values, j['repeat'], Repeat.none),
    weekdays: (j['weekdays'] as List?)?.cast<int>(),
    reminders: (j['reminders'] as List?)?.cast<int>(),
  );
}

class Recording {
  Recording({
    required this.file,
    required this.ms,
    required this.at,
    this.frame,
  });

  /// File name inside the app's recordings folder.
  final String file;
  final int ms;
  final int at;

  /// Background picture: `builtin:<id>` or a file in the media folder.
  String? frame;

  Map<String, dynamic> toJson() => {
    'file': file,
    'ms': ms,
    'at': at,
    'frame': frame,
  };

  factory Recording.fromJson(Map<String, dynamic> j) => Recording(
    file: j['file'],
    ms: j['ms'] ?? 0,
    at: j['at'] ?? 0,
    frame: j['frame'],
  );
}

/// One written note in a day's diary.
class Note {
  Note({required this.id, this.text = '', this.frame, this.at = 0});

  final String id;
  String text;

  /// Background picture: `builtin:<id>` or a file in the media folder.
  String? frame;

  /// When it was written, in ms since epoch; 0 if unknown.
  int at;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'frame': frame,
    'at': at,
  };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
    id: j['id'] ?? '${j['at'] ?? 0}',
    text: j['text'] ?? '',
    frame: j['frame'],
    at: j['at'] ?? 0,
  );
}

class JournalEntry {
  JournalEntry({List<Note>? notes, List<Recording>? recordings, this.frame})
    : notes = notes ?? [],
      recordings = recordings ?? [];

  /// Written notes, oldest first.
  List<Note> notes;
  List<Recording> recordings;

  /// Background picked for the next note written on this day.
  String? frame;

  bool get isEmpty => notes.isEmpty && recordings.isEmpty && frame == null;

  Map<String, dynamic> toJson() => {
    'notes': notes.map((x) => x.toJson()).toList(),
    'recordings': recordings.map((r) => r.toJson()).toList(),
    'frame': frame,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> j) {
    final notes = ((j['notes'] as List?) ?? [])
        .map((e) => Note.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    // Older data had one text per day.
    final text = (j['text'] as String?) ?? '';
    if (j['notes'] == null && text.trim().isNotEmpty) {
      notes.add(Note(id: 'first', text: text, frame: j['frame']));
    }
    return JournalEntry(
      notes: notes,
      recordings: ((j['recordings'] as List?) ?? [])
          .map((e) => Recording.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      frame: j['frame'],
    );
  }

  /// Whether [frame] is used by this day's notes, recordings or next note.
  bool usesFrame(String frame) =>
      this.frame == frame ||
      notes.any((x) => x.frame == frame) ||
      recordings.any((r) => r.frame == frame);
}

class Chapter {
  Chapter(this.title, this.start);

  final String title;

  /// First unit (page for PDF, section for EPUB) of the chapter, 1-based.
  final int start;

  Map<String, dynamic> toJson() => {'title': title, 'start': start};

  factory Chapter.fromJson(Map<String, dynamic> j) =>
      Chapter(j['title'] ?? '', j['start'] ?? 1);
}

class Book {
  Book({
    required this.id,
    required this.title,
    required this.file,
    required this.kind,
    required this.total,
    List<Chapter>? chapters,
    this.current = 0,
    this.planMode = PlanMode.finishInDays,
    this.planValue = 30,
    this.planStartKey,
    this.dayKey,
    this.dayStartUnit = 0,
    this.goalId,
  }) : chapters = chapters ?? [];

  final String id;
  String title;

  /// File name inside the app's books folder.
  final String file;
  final BookKind kind;

  /// Pages for a PDF, sections for an EPUB.
  int total;
  List<Chapter> chapters;

  /// Units finished so far (the last unit reached).
  int current;
  PlanMode planMode;
  int planValue;
  String? planStartKey;

  /// Where reading stood when [dayKey] began, so today's progress is known.
  String? dayKey;
  int dayStartUnit;
  String? goalId;

  int get chapterCount => chapters.isEmpty ? 0 : chapters.length;

  double get progress => total == 0 ? 0 : (current / total).clamp(0, 1);

  int startOfToday(DateTime now) =>
      dayKey == dkey(now) ? dayStartUnit : current;

  int remainingDays(DateTime now) {
    if (planMode != PlanMode.finishInDays) return 0;
    final start = parseKey(planStartKey ?? dkey(now));
    final end = addDays(start, planValue);
    return daysBetween(dayOnly(now), end).clamp(1, 100000);
  }

  /// Units to read today under the current plan.
  int perDay(DateTime now) {
    final remaining = (total - startOfToday(now)).clamp(0, total);
    switch (planMode) {
      case PlanMode.finishInDays:
        return (remaining / remainingDays(now)).ceil();
      case PlanMode.chaptersPerWeek:
        final chapters = chapterCount == 0 ? 1 : chapterCount;
        final perChapter = total / chapters;
        return (planValue * perChapter / 7).ceil().clamp(1, total);
      case PlanMode.unitsPerDay:
        return planValue.clamp(1, total);
    }
  }

  int readToday(DateTime now) => current - startOfToday(now);

  Chapter? chapterAt(int unit) {
    Chapter? found;
    for (final c in chapters) {
      if (c.start <= unit) found = c;
    }
    return found;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'file': file,
    'kind': kind.name,
    'total': total,
    'chapters': chapters.map((c) => c.toJson()).toList(),
    'current': current,
    'planMode': planMode.name,
    'planValue': planValue,
    'planStartKey': planStartKey,
    'dayKey': dayKey,
    'dayStartUnit': dayStartUnit,
    'goalId': goalId,
  };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
    id: j['id'],
    title: j['title'] ?? '',
    file: j['file'],
    kind: _enum(BookKind.values, j['kind'], BookKind.pdf),
    total: j['total'] ?? 0,
    chapters: ((j['chapters'] as List?) ?? [])
        .map((e) => Chapter.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    current: j['current'] ?? 0,
    planMode: _enum(PlanMode.values, j['planMode'], PlanMode.finishInDays),
    planValue: j['planValue'] ?? 30,
    planStartKey: j['planStartKey'],
    dayKey: j['dayKey'],
    dayStartUnit: j['dayStartUnit'] ?? 0,
    goalId: j['goalId'],
  );
}

class City {
  const City(this.key, this.lat, this.lng);

  final String key;
  final double lat;
  final double lng;
}

const cities = [
  City('القاهرة', 30.0444, 31.2357),
  City('الجيزة', 30.0131, 31.2089),
  City('الإسكندرية', 31.2001, 29.9187),
  City('المنصورة', 31.0409, 31.3785),
  City('طنطا', 30.7865, 31.0004),
  City('الزقازيق', 30.5877, 31.5020),
  City('بورسعيد', 31.2653, 32.3019),
  City('السويس', 29.9668, 32.5498),
  City('الإسماعيلية', 30.5965, 32.2715),
  City('أسيوط', 27.1783, 31.1859),
  City('المنيا', 28.1099, 30.7503),
  City('سوهاج', 26.5591, 31.6957),
  City('الأقصر', 25.6872, 32.6396),
  City('أسوان', 24.0889, 32.8998),
];

class Settings {
  Settings({
    this.theme = 'system',
    this.lang = 'ar',
    this.reviewMin = 20 * 60,
    Map<String, int>? prayerBefore,
    this.adhanAtTime = true,
    this.city = 0,
    this.themeChoice = 'auto',
    Map<String, String>? themeImages,
    this.bgOpacity = 0.6,
    this.syncBooks = true,
    this.lastSync,
  }) : prayerBefore =
           prayerBefore ?? {for (final p in Prayer.values) p.name: 10},
       themeImages = themeImages ?? {};

  String theme;
  String lang;
  int reviewMin;
  Map<String, int> prayerBefore;
  bool adhanAtTime;
  int city;

  /// `auto` (a theme per weekday) or a fixed theme id.
  String themeChoice;

  /// The user's picture for each theme id: a file name in the media folder.
  Map<String, String> themeImages;

  /// How strongly the theme picture shows behind the screens.
  double bgOpacity;
  bool syncBooks;
  int? lastSync;

  Map<String, dynamic> toJson() => {
    'theme': theme,
    'lang': lang,
    'reviewMin': reviewMin,
    'prayerBefore': prayerBefore,
    'adhanAtTime': adhanAtTime,
    'city': city,
    'themeChoice': themeChoice,
    'themeImages': themeImages,
    'bgOpacity': bgOpacity,
    'syncBooks': syncBooks,
    'lastSync': lastSync,
  };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    theme: j['theme'] ?? 'system',
    lang: j['lang'] ?? 'ar',
    reviewMin: j['reviewMin'] ?? 1200,
    prayerBefore: (j['prayerBefore'] as Map?)?.cast<String, int>(),
    adhanAtTime: j['adhanAtTime'] ?? true,
    city: j['city'] ?? 0,
    themeChoice: j['themeChoice'] ?? 'auto',
    themeImages: (j['themeImages'] as Map?)?.cast<String, String>(),
    bgOpacity: (j['bgOpacity'] ?? 0.6).toDouble(),
    syncBooks: j['syncBooks'] ?? true,
    lastSync: j['lastSync'],
  );
}

/// Quran, adhkar and tasbih state.
class Worship {
  Worship({
    this.lastSurah = 0,
    this.markSurah,
    this.markAyah,
    this.fontSize = 26,
    this.tasbihStyle = 'wood',
    this.dhikr = 0,
    this.target = 33,
    this.vibrate = true,
    List<String>? customDhikr,
    Map<String, int>? totals,
    Map<String, List<String>>? adhkarDone,
    this.adhkarReminders = true,
  }) : customDhikr = customDhikr ?? [],
       totals = totals ?? {},
       adhkarDone = adhkarDone ?? {};

  /// Last surah opened (1-based, 0 = none) and the reader's own bookmark.
  int lastSurah;
  int? markSurah;
  int? markAyah;
  double fontSize;

  /// wood | amber | pearl | emerald | digital
  String tasbihStyle;
  int dhikr;

  /// Count per round; 0 = open count, -1 = after-prayer 33/33/34.
  int target;
  bool vibrate;
  List<String> customDhikr;

  /// Lifetime count per dhikr text.
  Map<String, int> totals;

  /// Adhkar categories finished, per day.
  Map<String, List<String>> adhkarDone;
  bool adhkarReminders;

  Map<String, dynamic> toJson() => {
    'lastSurah': lastSurah,
    'markSurah': markSurah,
    'markAyah': markAyah,
    'fontSize': fontSize,
    'tasbihStyle': tasbihStyle,
    'dhikr': dhikr,
    'target': target,
    'vibrate': vibrate,
    'customDhikr': customDhikr,
    'totals': totals,
    'adhkarDone': adhkarDone,
    'adhkarReminders': adhkarReminders,
  };

  factory Worship.fromJson(Map<String, dynamic> j) => Worship(
    lastSurah: j['lastSurah'] ?? 0,
    markSurah: j['markSurah'],
    markAyah: j['markAyah'],
    fontSize: (j['fontSize'] ?? 26).toDouble(),
    tasbihStyle: j['tasbihStyle'] ?? 'wood',
    dhikr: j['dhikr'] ?? 0,
    target: j['target'] ?? 33,
    vibrate: j['vibrate'] ?? true,
    customDhikr: (j['customDhikr'] as List?)?.cast<String>(),
    totals: (j['totals'] as Map?)?.cast<String, int>(),
    adhkarDone: (j['adhkarDone'] as Map?)?.map(
      (k, v) => MapEntry(k as String, (v as List).cast<String>()),
    ),
    adhkarReminders: j['adhkarReminders'] ?? true,
  );
}
