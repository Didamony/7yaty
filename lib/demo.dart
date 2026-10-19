import 'core/dates.dart';
import 'data/models.dart';
import 'data/store.dart';

/// Sample content for screenshots (`--dart-define=DEMO=true` builds only).
void seedDemo(AppData d) {
  // Theme pictures for screenshots, copied next to the web build by hand.
  for (final id in ['sat', 'sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'dark']) {
    d.settings.themeImages[id] = 'url:demo_themes/$id.jpg';
  }
  final t = today();
  final year = Goal(
    id: newId(),
    title: 'حفظ ٥ أجزاء من القرآن',
    level: Level.year,
    periodKey: '${t.year}',
    createdKey: dkey(DateTime(t.year, 1, 1)),
  );
  final month = Goal(
    id: newId(),
    title: 'نصف جزء عمّ',
    level: Level.month,
    periodKey: dkey(t).substring(0, 7),
    parentId: year.id,
    createdKey: dkey(monthStart(t)),
  );
  final quran = Goal(
    id: newId(),
    title: 'قراءة صفحتين من القرآن',
    level: Level.day,
    periodKey: dkey(addDays(t, -30)),
    parentId: month.id,
    repeat: Repeat.daily,
    timeMode: TimeMode.prayer,
    prayer: Prayer.fajr,
    offsetMin: 15,
    grace: true,
    onMiss: OnMiss.qada,
    createdKey: dkey(addDays(t, -30)),
  );
  final work = Goal(
    id: newId(),
    title: 'ترقية في الشغل',
    level: Level.year,
    periodKey: '${t.year}',
    createdKey: dkey(DateTime(t.year, 1, 1)),
  );
  final report = Goal(
    id: newId(),
    title: 'إنهاء تقرير الشغل',
    level: Level.day,
    periodKey: dkey(t),
    parentId: work.id,
    timeMode: TimeMode.clock,
    clockMin: 14 * 60,
    createdKey: dkey(t),
  );
  final walk = Goal(
    id: newId(),
    title: 'مشي ٣٠ دقيقة',
    level: Level.day,
    periodKey: dkey(addDays(t, -20)),
    repeat: Repeat.daily,
    timeMode: TimeMode.prayer,
    prayer: Prayer.asr,
    offsetMin: 30,
    onMiss: OnMiss.qada,
    createdKey: dkey(addDays(t, -20)),
  );
  final french = Goal(
    id: newId(),
    title: 'مذاكرة درس فرنساوي',
    level: Level.day,
    periodKey: dkey(addDays(t, -10)),
    repeat: Repeat.daily,
    createdKey: dkey(addDays(t, -10)),
  );
  final desk = Goal(
    id: newId(),
    title: 'تنظيف المكتب',
    level: Level.day,
    periodKey: dkey(addDays(t, -1)),
    createdKey: dkey(addDays(t, -1)),
  );
  d.goals.addAll([year, month, quran, work, report, walk, french, desk]);

  for (var i = 1; i <= 23; i++) {
    final day = addDays(t, -i);
    d.occ[occKey(quran.id, day)] = i == 3 ? Occ.grace : Occ.done;
  }
  for (var i = 1; i <= 20; i++) {
    d.occ[occKey(walk.id, addDays(t, -i))] = i == 1 ? Occ.qada : Occ.done;
  }
  for (var i = 1; i <= 10; i++) {
    d.occ[occKey(french.id, addDays(t, -i))] = i == 4 || i == 6
        ? Occ.qada
        : Occ.done;
  }
  d.occ[occKey(desk.id, addDays(t, -1))] = Occ.missed;
  d.occ[occKey(quran.id, t)] = Occ.done;
  d.occ[occKey(french.id, t)] = Occ.done;

  final book = Book(
    id: newId(),
    title: 'مقدمة ابن خلدون',
    file: 'demo.pdf',
    kind: BookKind.pdf,
    total: 420,
    chapters: [for (var i = 0; i < 12; i++) Chapter('', 1 + i * 35)],
    current: 84,
    planValue: 30,
    planStartKey: dkey(t),
    dayKey: dkey(t),
    dayStartUnit: 80,
  );
  final reading = Goal(
    id: newId(),
    title: book.title,
    level: Level.day,
    periodKey: dkey(t),
    repeat: Repeat.daily,
    bookId: book.id,
    timeMode: TimeMode.prayer,
    prayer: Prayer.isha,
    offsetMin: 0,
    createdKey: dkey(t),
  );
  book.goalId = reading.id;
  d.books.add(book);
  d.goals.add(reading);

  d.appointments.addAll([
    Appointment(
      id: newId(),
      title: 'الذهاب للشغل',
      place: 'المعادي',
      dateKey: dkey(addDays(t, 1)),
      timeMin: 7 * 60,
      repeat: Repeat.weekdays,
      weekdays: [6, 7, 1, 2, 3],
      reminders: [30],
    ),
    Appointment(
      id: newId(),
      title: 'دكتور الأسنان',
      dateKey: dkey(addDays(t, 3)),
      timeMin: 17 * 60 + 30,
      reminders: [60],
    ),
  ]);

  d.journal[dkey(t)] = JournalEntry(
    text: 'النهارده خلصت التقرير بدري، ومشيت بعد العصر. حاسس إن الأسبوع ده أحسن من اللي فات، بس لازم أنام بدري عشان الفجر.',
  );
  d.journal[dkey(addDays(t, -1))] = JournalEntry(text: 'يوم هادي.');
}
