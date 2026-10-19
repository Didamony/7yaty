import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/dates.dart';
import 'models.dart';

const _prefsKey = 'hayati.data.v1';
const _uuid = Uuid();

String newId() => _uuid.v4();

String occKey(String goalId, DateTime d) => '$goalId|${dkey(d)}';

/// Everything the user owns, as one JSON document. It is plain data so the
/// notification action handler can load, change and save it from a
/// background isolate without the UI.
class AppData {
  AppData();

  List<Goal> goals = [];

  /// Status of daily occurrences, keyed by [occKey]. See [Occ].
  Map<String, String> occ = {};

  /// Qada occurrences the user scheduled for a given day.
  Map<String, String> qadaPlan = {};
  List<Appointment> appointments = [];
  Map<String, JournalEntry> journal = {};
  List<Book> books = [];
  Settings settings = Settings();
  Worship worship = Worship();
  int updatedAt = 0;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'goals': goals.map((g) => g.toJson()).toList(),
    'occ': occ,
    'qadaPlan': qadaPlan,
    'appointments': appointments.map((a) => a.toJson()).toList(),
    'journal': journal.map((k, v) => MapEntry(k, v.toJson())),
    'books': books.map((b) => b.toJson()).toList(),
    'settings': settings.toJson(),
    'worship': worship.toJson(),
    'updatedAt': updatedAt,
  };

  factory AppData.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String k) => ((j[k] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return AppData()
      ..goals = list('goals').map(Goal.fromJson).toList()
      ..occ = Map<String, String>.from(j['occ'] ?? {})
      ..qadaPlan = Map<String, String>.from(j['qadaPlan'] ?? {})
      ..appointments = list('appointments').map(Appointment.fromJson).toList()
      ..journal = ((j['journal'] as Map?) ?? {}).map(
        (k, v) => MapEntry(
          k as String,
          JournalEntry.fromJson(Map<String, dynamic>.from(v)),
        ),
      )
      ..books = list('books').map(Book.fromJson).toList()
      ..worship = Worship.fromJson(
        Map<String, dynamic>.from(j['worship'] ?? {}),
      )
      ..settings = Settings.fromJson(
        Map<String, dynamic>.from(j['settings'] ?? {}),
      )
      ..updatedAt = j['updatedAt'] ?? 0;
  }

  static Future<AppData> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return AppData();
    try {
      return AppData.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('hayati: could not read saved data: $e');
      return AppData();
    }
  }

  Future<void> save() async {
    updatedAt = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toJson()));
  }

  bool get isEmpty =>
      goals.isEmpty && appointments.isEmpty && journal.isEmpty && books.isEmpty;

  // ---------------------------------------------------------------- goals

  Goal? goal(String? id) {
    if (id == null) return null;
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  Book? book(String? id) {
    if (id == null) return null;
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  List<Goal> children(String? parentId) =>
      goals.where((g) => g.parentId == parentId).toList();

  List<Goal> descendants(String id) {
    final out = <Goal>[];
    for (final c in children(id)) {
      out
        ..add(c)
        ..addAll(descendants(c.id));
    }
    return out;
  }

  /// Ancestors from the direct parent upwards.
  List<Goal> ancestors(Goal g) {
    final out = <Goal>[];
    var p = goal(g.parentId);
    while (p != null && out.length < 10) {
      out.add(p);
      p = goal(p.parentId);
    }
    return out;
  }

  String? status(Goal g, DateTime d) => occ[occKey(g.id, d)];

  bool occursOn(Goal g, DateTime d) {
    if (!g.isDaily) return false;
    final day = dayOnly(d);
    final start = parseKey(g.periodKey);
    if (day.isBefore(start)) return false;
    final parent = goal(g.parentId);
    if (parent != null && !parent.isDaily) {
      final (ps, pe) = parent.period;
      if (day.isBefore(ps) || day.isAfter(pe)) return false;
    }
    switch (g.repeat) {
      case Repeat.none:
        return sameDay(day, start);
      case Repeat.daily:
        return true;
      case Repeat.weekdays:
        return g.weekdays.contains(day.weekday);
    }
  }

  /// Daily goals to show on [d], skipping ones carried away or dismissed.
  List<Goal> goalsOn(DateTime d) => goals
      .where(
        (g) =>
            occursOn(g, d) &&
            status(g, d) != Occ.carried &&
            status(g, d) != Occ.dismissed &&
            status(g, d) != Occ.qada,
      )
      .toList();

  /// Past occurrences the user still has to decide about (shown in red).
  List<(Goal, DateTime)> pendingMisses() {
    final out = <(Goal, DateTime)>[];
    occ.forEach((k, v) {
      if (v != Occ.missed) return;
      final (g, d) = _split(k);
      if (g != null) out.add((g, d));
    });
    out.sort((a, b) => b.$2.compareTo(a.$2));
    return out;
  }

  List<(Goal, DateTime, String?)> qadaList() {
    final out = <(Goal, DateTime, String?)>[];
    occ.forEach((k, v) {
      if (v != Occ.qada) return;
      final (g, d) = _split(k);
      if (g != null) out.add((g, d, qadaPlan[k]));
    });
    out.sort((a, b) => a.$2.compareTo(b.$2));
    return out;
  }

  List<(Goal, DateTime)> qadaPlannedOn(DateTime day) => [
    for (final (g, d, plan) in qadaList())
      if (plan == dkey(day)) (g, d),
  ];

  (Goal?, DateTime) _split(String key) {
    final i = key.lastIndexOf('|');
    return (goal(key.substring(0, i)), parseKey(key.substring(i + 1)));
  }

  bool _graceUsed(Goal g, DateTime d) {
    final ws = weekStart(d);
    for (var i = 0; i < 7; i++) {
      if (occ[occKey(g.id, addDays(ws, i))] == Occ.grace) return true;
    }
    return false;
  }

  /// Settles occurrences from the last two weeks that ended unchecked:
  /// a grace day if one is left this week, otherwise the goal's miss rule.
  bool settleMisses(DateTime now) {
    final t = dayOnly(now);
    var changed = false;
    for (final g in List.of(goals)) {
      if (!g.isDaily) continue;
      final created = parseKey(g.createdKey);
      for (var i = 14; i >= 1; i--) {
        final d = addDays(t, -i);
        if (d.isBefore(created) || !occursOn(g, d)) continue;
        if (occ.containsKey(occKey(g.id, d))) continue;
        changed = true;
        if (g.grace && !_graceUsed(g, d)) {
          occ[occKey(g.id, d)] = Occ.grace;
        } else {
          applyMiss(g, d, now);
        }
      }
    }
    return changed;
  }

  /// "Not done" for [g] on [d], following its miss rule.
  void applyMiss(Goal g, DateTime d, DateTime now) {
    switch (g.onMiss) {
      case OnMiss.qada:
        occ[occKey(g.id, d)] = Occ.qada;
      case OnMiss.carry:
        carry(g, d, dayOnly(now));
      case OnMiss.ask:
        occ[occKey(g.id, d)] = Occ.missed;
    }
  }

  void setDone(Goal g, DateTime d, bool done) {
    final k = occKey(g.id, d);
    if (done) {
      occ[k] = Occ.done;
    } else {
      occ.remove(k);
    }
  }

  /// Moves an occurrence to [to] (today unless given). A one-off goal moves
  /// itself; a repeating goal gets a one-off copy for that day.
  void carry(Goal g, DateTime d, DateTime to) {
    final t = dkey(to);
    if (g.repeat == Repeat.none) {
      occ.remove(occKey(g.id, d));
      g
        ..carriedFrom ??= dkey(d)
        ..periodKey = t;
      return;
    }
    occ[occKey(g.id, d)] = Occ.carried;
    goals.add(
      Goal(
        id: newId(),
        title: g.title,
        level: Level.day,
        periodKey: t,
        parentId: g.parentId,
        timeMode: g.timeMode,
        clockMin: g.clockMin,
        prayer: g.prayer,
        before: g.before,
        offsetMin: g.offsetMin,
        onMiss: OnMiss.ask,
        bookId: g.bookId,
        carriedFrom: dkey(d),
        createdKey: t,
      ),
    );
  }

  /// "Delete it" on a red item: a one-off goal goes away entirely, a
  /// repeating goal only loses that day.
  void dismiss(Goal g, DateTime d) {
    if (g.repeat == Repeat.none) {
      deleteGoal(g.id);
    } else {
      occ[occKey(g.id, d)] = Occ.dismissed;
    }
  }

  void toQada(Goal g, DateTime d) => occ[occKey(g.id, d)] = Occ.qada;

  void payQada(Goal g, DateTime d) {
    final k = occKey(g.id, d);
    occ[k] = Occ.qadaPaid;
    qadaPlan.remove(k);
  }

  void planQada(Goal g, DateTime d, DateTime on) =>
      qadaPlan[occKey(g.id, d)] = dkey(on);

  void deleteGoal(String id) {
    final ids = {id, ...descendants(id).map((g) => g.id)};
    goals.removeWhere((g) => ids.contains(g.id));
    occ.removeWhere((k, _) => ids.contains(k.substring(0, k.lastIndexOf('|'))));
    qadaPlan.removeWhere(
      (k, _) => ids.contains(k.substring(0, k.lastIndexOf('|'))),
    );
    for (final b in books) {
      if (ids.contains(b.goalId)) b.goalId = null;
    }
  }

  /// Consecutive days the goal was kept, counting back from today (today
  /// counts only once it is checked).
  int streak(Goal g, DateTime now) {
    var d = dayOnly(now);
    if (!Occ.keepsStreak.contains(status(g, d))) d = addDays(d, -1);
    final created = parseKey(g.createdKey);
    var n = 0;
    for (var i = 0; i < 1000 && !d.isBefore(created); i++, d = addDays(d, -1)) {
      if (!occursOn(g, d)) continue;
      if (!Occ.keepsStreak.contains(status(g, d))) break;
      n++;
    }
    return n;
  }

  /// Done and expected daily occurrences under [g] across its whole period.
  (int, int) tally(Goal g) {
    if (g.isDaily) {
      if (g.repeat == Repeat.none) {
        return (
          Occ.counts.contains(status(g, parseKey(g.periodKey))) ? 1 : 0,
          1,
        );
      }
      final parent = goal(g.parentId);
      if (parent == null || parent.isDaily) return (0, 0);
      final (ps, pe) = parent.period;
      var done = 0, total = 0;
      for (final d in daysInRange(ps, pe)) {
        if (!occursOn(g, d)) continue;
        total++;
        if (Occ.counts.contains(status(g, d))) done++;
      }
      return (done, total);
    }
    final kids = children(g.id);
    if (kids.isEmpty) return (g.manualDone ? 1 : 0, 1);
    var done = 0, total = 0;
    for (final c in kids) {
      final (cd, ct) = tally(c);
      done += cd;
      total += ct;
    }
    return (done, total);
  }

  double progress(Goal g) {
    final (d, t) = tally(g);
    return t == 0 ? 0 : d / t;
  }

  // ---------------------------------------------------------------- books

  /// Records reading position and checks off today's reading goal once the
  /// day's share is read.
  void updateReading(Book b, int unit, DateTime now) {
    final t = dkey(now);
    if (b.dayKey != t) {
      b
        ..dayKey = t
        ..dayStartUnit = b.current;
    }
    b.current = unit.clamp(0, b.total);
    final g = goal(b.goalId);
    if (g != null && occursOn(g, now)) {
      final reached = b.readToday(now) >= b.perDay(now) || b.current >= b.total;
      if (reached) setDone(g, now, true);
    }
  }

  // --------------------------------------------- notification action entry

  /// Applies a button press from a goal notification. Payload format:
  /// `goal|<goalId>|<yyyy-MM-dd>`.
  bool applyNotificationAction(String? payload, String? action) {
    if (payload == null || !payload.startsWith('goal|')) return false;
    final parts = payload.split('|');
    if (parts.length < 3) return false;
    final g = goal(parts[1]);
    if (g == null) return false;
    final d = parseKey(parts[2]);
    final now = DateTime.now();
    switch (action) {
      case 'done':
        setDone(g, d, true);
      case 'missed':
        applyMiss(g, d, now);
      case 'carry':
        carry(g, d, addDays(dayOnly(now), 1));
      default:
        return false;
    }
    return true;
  }
}

/// The app-wide state holder the UI listens to.
class AppStore extends ChangeNotifier {
  AppStore(this.data);

  AppData data;
  final _savedListeners = <void Function(AppData)>[];
  Timer? _dayTimer;

  Settings get settings => data.settings;

  /// Redraws listeners for an unsaved, in-progress change (a slider drag).
  void touch() => notifyListeners();

  static Future<AppStore> open() async {
    final store = AppStore(await AppData.load());
    if (store.data.settleMisses(DateTime.now())) await store.data.save();
    store._scheduleMidnight();
    return store;
  }

  void onSaved(void Function(AppData) listener) =>
      _savedListeners.add(listener);

  /// Applies [change], saves, and tells listeners (UI, notifications, sync).
  Future<void> update(void Function(AppData d) change) async {
    change(data);
    notifyListeners();
    await data.save();
    for (final l in _savedListeners) {
      l(data);
    }
  }

  /// Re-reads saved data, e.g. after a notification button changed it.
  Future<void> reload() async {
    data = await AppData.load();
    if (data.settleMisses(DateTime.now())) await data.save();
    notifyListeners();
  }

  Future<void> replaceAll(AppData fresh) async {
    data = fresh;
    data.settleMisses(DateTime.now());
    notifyListeners();
    await data.save();
    for (final l in _savedListeners) {
      l(data);
    }
  }

  void _scheduleMidnight() {
    _dayTimer?.cancel();
    final now = DateTime.now();
    final next = addDays(dayOnly(now), 1).add(const Duration(seconds: 5));
    _dayTimer = Timer(next.difference(now), () {
      if (data.settleMisses(DateTime.now())) {
        data.save();
      }
      notifyListeners();
      _scheduleMidnight();
    });
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    super.dispose();
  }
}
