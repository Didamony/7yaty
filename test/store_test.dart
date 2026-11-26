import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/dates.dart';
import 'package:hayati/data/models.dart';
import 'package:hayati/data/store.dart';
import 'package:hayati/services/prayer.dart';
import 'package:shared_preferences/shared_preferences.dart';

Goal daily(
  String id,
  DateTime start, {
  OnMiss onMiss = OnMiss.ask,
  bool grace = false,
  String? parent,
}) => Goal(
  id: id,
  title: id,
  level: Level.day,
  periodKey: dkey(start),
  repeat: Repeat.daily,
  onMiss: onMiss,
  grace: grace,
  parentId: parent,
  createdKey: dkey(start),
);

void main() {
  // A Thursday, so the Saturday-based week started two days earlier.
  final now = DateTime(2026, 10, 22, 21);
  final t = dayOnly(now);

  test('week starts on Saturday', () {
    expect(weekStart(t), DateTime(2026, 10, 17));
    expect(weekStart(DateTime(2026, 10, 17)), DateTime(2026, 10, 17));
    expect(daysBetween(DateTime(2026, 10, 25), DateTime(2026, 11, 2)), 8);
  });

  test('unchecked days follow the goal miss rule', () {
    final d = AppData()
      ..goals.addAll([
        daily('ask', addDays(t, -2)),
        daily('qada', addDays(t, -2), onMiss: OnMiss.qada),
      ]);
    d.setDone(d.goal('ask')!, addDays(t, -2), true);
    expect(d.settleMisses(now), isTrue);
    expect(d.status(d.goal('ask')!, addDays(t, -1)), Occ.missed);
    expect(d.status(d.goal('qada')!, addDays(t, -1)), Occ.qada);
    expect(d.status(d.goal('qada')!, addDays(t, -2)), Occ.qada);
    expect(d.pendingMisses().length, 1);
    expect(d.qadaList().length, 2);
    expect(d.settleMisses(now), isFalse, reason: 'already settled');
  });

  test('one grace day per week keeps the streak', () {
    final g = daily('g', addDays(t, -10), grace: true, onMiss: OnMiss.qada);
    final d = AppData()..goals.add(g);
    for (var i = 1; i <= 10; i++) {
      if (i != 2 && i != 3) d.setDone(g, addDays(t, -i), true);
    }
    d.settleMisses(now);
    // Two misses in the same week: the first becomes grace, the second qada.
    expect(d.status(g, addDays(t, -3)), Occ.grace);
    expect(d.status(g, addDays(t, -2)), Occ.qada);
    expect(d.streak(g, now), 1);
    d.payQada(g, addDays(t, -2));
    expect(d.streak(g, now), 10);
    d.setDone(g, t, true);
    expect(d.streak(g, now), 11);
  });

  test('carrying moves one-off goals and copies repeating ones', () {
    final once = Goal(
      id: 'once',
      title: 'once',
      level: Level.day,
      periodKey: dkey(addDays(t, -1)),
      createdKey: dkey(addDays(t, -1)),
    );
    final rep = daily('rep', addDays(t, -3));
    final d = AppData()..goals.addAll([once, rep]);
    d.settleMisses(now);
    d.carry(once, addDays(t, -1), t);
    expect(once.periodKey, dkey(t));
    expect(d.goalsOn(t).map((g) => g.id), contains('once'));
    d.carry(rep, addDays(t, -1), t);
    expect(d.status(rep, addDays(t, -1)), Occ.carried);
    expect(d.goalsOn(t).where((g) => g.carriedFrom != null).length, 2);
  });

  test('notification buttons update saved data', () {
    // Button presses act on the real clock, like the background handler.
    final t = today();
    final g = daily('n', t, onMiss: OnMiss.qada);
    final d = AppData()..goals.add(g);
    expect(d.applyNotificationAction('goal|n|${dkey(t)}', 'done'), isTrue);
    expect(d.status(g, t), Occ.done);
    expect(d.applyNotificationAction('goal|n|${dkey(t)}', 'missed'), isTrue);
    expect(d.status(g, t), Occ.qada);
    expect(d.applyNotificationAction('goal|n|${dkey(t)}', 'carry'), isTrue);
    expect(d.goalsOn(addDays(t, 1)).length, 2);
    expect(d.applyNotificationAction('other', 'done'), isFalse);
  });

  test('progress rolls up from daily goals to the year', () {
    final year = Goal(
      id: 'y',
      title: 'y',
      level: Level.year,
      periodKey: '2026',
      createdKey: '2026-01-01',
    );
    final week = Goal(
      id: 'w',
      title: 'w',
      level: Level.week,
      periodKey: dkey(weekStart(t)),
      parentId: 'y',
      createdKey: dkey(weekStart(t)),
    );
    final g = daily('d', weekStart(t), parent: 'w');
    final d = AppData()..goals.addAll([year, week, g]);
    expect(d.occursOn(g, addDays(weekStart(t), 6)), isTrue);
    expect(d.occursOn(g, addDays(weekStart(t), 7)), isFalse);
    expect(d.tally(year), (0, 7));
    d.setDone(g, t, true);
    d.setDone(g, addDays(t, -1), true);
    expect(d.tally(year), (2, 7));
    expect(d.progress(week), closeTo(2 / 7, 1e-9));
  });

  test('reading plan and auto check-off', () {
    final b = Book(
      id: 'b',
      title: 'b',
      file: 'b.pdf',
      kind: BookKind.pdf,
      total: 300,
      planValue: 30,
      planStartKey: dkey(t),
    );
    final g = daily('r', t)..bookId = 'b';
    b.goalId = 'r';
    final d = AppData()
      ..books.add(b)
      ..goals.add(g);
    expect(b.perDay(now), 10);
    d.updateReading(b, 6, now);
    expect(d.status(g, t), isNull);
    d.updateReading(b, 10, now);
    expect(d.status(g, t), Occ.done);
    expect(b.readToday(now), 10);
  });

  test('JSON round trip keeps everything', () {
    final d = AppData()
      ..goals.add(daily('a', t, grace: true))
      ..appointments.add(
        Appointment(id: 'x', title: 'x', dateKey: dkey(t), timeMin: 420),
      )
      ..journal[dkey(t)] = JournalEntry(
        notes: [Note(id: 'n', text: 'hi', frame: 'builtin:arch', at: 5)],
        recordings: [Recording(file: 'r.m4a', ms: 1000, at: 1)],
      )
      ..sheet[dkey(t)] = 'شغل'
      ..settings.lang = 'de';
    d.setDone(d.goals.first, t, true);
    final back = AppData.fromJson(d.toJson());
    expect(back.sheet[dkey(t)], 'شغل');
    expect(back.toJson(), d.toJson());
  });

  test('a diary day from before notes keeps its text as the first note', () {
    final e = JournalEntry.fromJson({'text': 'old day', 'frame': 'a.jpg'});
    expect(e.notes.single.text, 'old day');
    expect(e.notes.single.frame, 'a.jpg');
    expect(e.usesFrame('a.jpg'), isTrue);
    final back = JournalEntry.fromJson(e.toJson());
    expect(back.notes.single.text, 'old day');
  });

  test('Cairo prayer times are in a sane order and range', () {
    PrayerTimes.init();
    final times = PrayerTimes.forDay(DateTime(2026, 10, 19), 0);
    final list = Prayer.values.map((p) => times[p]!).toList();
    for (var i = 1; i < list.length; i++) {
      expect(list[i].isAfter(list[i - 1]), isTrue);
    }
    // Egypt is on daylight saving time until the end of October.
    expect(times[Prayer.fajr]!.hour, inInclusiveRange(4, 5));
    expect(times[Prayer.dhuhr]!.hour, 12);
    expect(times[Prayer.maghrib]!.hour, inInclusiveRange(17, 18));
  });

  test(
    'a notification press in the background survives the app saving',
    () async {
      final t = dayOnly(DateTime.now());
      final g = daily('bg', addDays(t, -3));
      SharedPreferences.setMockInitialValues({});
      final first = AppData()..goals.add(g);
      await first.save();
      final store = await AppStore.open();

      // The background handler marks today done while the app is running.
      await AppData.recordBackgroundAction('goal|bg|${dkey(t)}', 'done');
      expect(store.data.status(store.data.goal('bg')!, t), isNot(Occ.done));

      // Any save in the app takes it in instead of writing over it.
      await store.update((d) => d.sheet[dkey(t)] = 'x');
      expect(store.data.status(store.data.goal('bg')!, t), Occ.done);
      final saved = await AppData.load();
      expect(saved.status(saved.goal('bg')!, t), Occ.done);

      // Taken in once only.
      final goals = store.data.goals.length;
      await AppData.recordBackgroundAction('goal|bg|${dkey(t)}', 'carry');
      await store.refresh();
      await store.refresh();
      expect(store.data.goals.length, goals + 1);
    },
  );

  test('settling missed days does not make the data look edited', () async {
    final t = dayOnly(DateTime.now());
    SharedPreferences.setMockInitialValues({});
    final d = AppData()..goals.add(daily('s', addDays(t, -3)));
    await d.save();
    final edited = (await AppData.load()).updatedAt;
    final store = await AppStore.open();
    expect(
      store.data.status(store.data.goal('s')!, addDays(t, -1)),
      Occ.missed,
    );
    expect((await AppData.load()).updatedAt, edited);
  });

  test("'not done' on today's review carries to tomorrow", () {
    final t = dayOnly(DateTime.now());
    final g = daily('c', addDays(t, -3), onMiss: OnMiss.carry);
    final d = AppData()..goals.add(g);
    d.applyNotificationAction('goal|c|${dkey(t)}', 'missed');
    expect(d.status(g, t), Occ.carried);
    final copy = d.goals.firstWhere((x) => x.carriedFrom == dkey(t));
    expect(copy.periodKey, dkey(addDays(t, 1)));
  });
}
