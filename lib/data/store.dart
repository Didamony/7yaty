import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/dates.dart';
import 'models.dart';

const _prefsKey = 'hayati.data.v1';

/// Notification button presses handled while the app was in the background,
/// for the running app to take in: `id|payload|action` per entry.
const _pendingKey = 'hayati.pending.actions';
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

  /// Monthly sheet: a short note per day, keyed by [dkey]. Separate from
  /// goals.
  Map<String, String> sheet = {};
  List<Book> books = [];
  Settings settings = Settings();
  Worship worship = Worship();
  int updatedAt = 0;

  /// Ids of notification button presses already applied (latest 100), so a
  /// press saved by the background handler is never applied twice.
  List<String> appliedActions = [];

  Map<String, dynamic> toJson() => {
    'v': 1,
    'goals': goals.map((g) => g.toJson()).toList(),
    'occ': occ,
    'qadaPlan': qadaPlan,
    'appointments': appointments.map((a) => a.toJson()).toList(),
    'journal': journal.map((k, v) => MapEntry(k, v.toJson())),
    'sheet': sheet,
    'books': books.map((b) => b.toJson()).toList(),
    'settings': settings.toJson(),
    'worship': worship.toJson(),
    'updatedAt': updatedAt,
    'appliedActions': appliedActions,
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
      ..sheet = Map<String, String>.from(j['sheet'] ?? {})
      ..books = list('books').map(Book.fromJson).toList()
      ..worship = Worship.fromJson(
        Map<String, dynamic>.from(j['worship'] ?? {}),
      )
      ..settings = Settings.fromJson(
        Map<String, dynamic>.from(j['settings'] ?? {}),
      )
      ..updatedAt = j['updatedAt'] ?? 0
      ..appliedActions = List<String>.from(j['appliedActions'] ?? []);
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

  /// Saves on the device. [touch] marks the data as edited now; leave it off
  /// for automatic changes (settling missed days) so they don't make this
  /// device's copy look newer than the cloud's.
  Future<void> save({bool touch = true}) async {
    if (touch) updatedAt = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toJson()));
  }

  bool get isEmpty =>
      goals.isEmpty &&
      appointments.isEmpty &&
      journal.isEmpty &&
      sheet.isEmpty &&
      books.isEmpty;

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
    if (g.repeat != Repeat.none &&
        g.untilKey != null &&
        day.isAfter(parseKey(g.untilKey!))) {
      return false;
    }
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
        if (g.onMiss == OnMiss.carry) {
          // From the evening review: to the next day, not back to today.
          final next = addDays(d, 1);
          final today = dayOnly(now);
          carry(g, d, next.isBefore(today) ? today : next);
        } else {
          applyMiss(g, d, now);
        }
      case 'carry':
        carry(g, d, addDays(dayOnly(now), 1));
      default:
        return false;
    }
    return true;
  }

  /// Applies a button press once, by its id. Returns whether it changed
  /// anything.
  bool applyActionOnce(String id, String? payload, String? action) {
    if (appliedActions.contains(id)) return false;
    appliedActions.add(id);
    if (appliedActions.length > 100) {
      appliedActions.removeRange(0, appliedActions.length - 100);
    }
    applyNotificationAction(payload, action);
    return true;
  }

  /// Called from the background notification handler, which runs apart
  /// from the app: saves the press into the stored data (for when the app
  /// isn't running) and queues it for the running app (which keeps its own
  /// copy in memory and would otherwise save over it).
  static Future<void> recordBackgroundAction(
    String? payload,
    String? action,
  ) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    final data = await load();
    if (data.applyActionOnce(id, payload, action)) await data.save();
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_pendingKey) ?? [];
    await prefs.setStringList(_pendingKey, [
      ...queue,
      '$id|${payload ?? ''}|${action ?? ''}',
    ]);
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
    if (store.data.settleMisses(DateTime.now())) {
      await store.data.save(touch: false);
    }
    store._scheduleMidnight();
    return store;
  }

  /// Takes in notification button presses made while the app was in the
  /// background. Returns whether anything changed.
  Future<bool> _absorbPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final queue = prefs.getStringList(_pendingKey) ?? [];
    if (queue.isEmpty) return false;
    var changed = false;
    for (final e in queue) {
      final parts = e.split('|');
      if (parts.length < 4) continue;
      final payload = parts.sublist(1, parts.length - 1).join('|');
      if (data.applyActionOnce(parts.first, payload, parts.last)) {
        changed = true;
      }
    }
    await prefs.remove(_pendingKey);
    return changed;
  }

  /// When the app comes back: takes in notification presses, settles days
  /// that passed, and saves only if something changed.
  Future<void> refresh() async {
    final absorbed = await _absorbPending();
    final settled = data.settleMisses(DateTime.now());
    if (!absorbed && !settled) return;
    notifyListeners();
    await data.save(touch: absorbed);
    for (final l in _savedListeners) {
      l(data);
    }
  }

  void onSaved(void Function(AppData) listener) =>
      _savedListeners.add(listener);

  /// Applies [change], saves, and tells listeners (UI, notifications, sync).
  Future<void> update(void Function(AppData d) change) async {
    change(data);
    notifyListeners();
    // Don't save over a notification press made in the background.
    if (await _absorbPending()) notifyListeners();
    await data.save();
    for (final l in _savedListeners) {
      l(data);
    }
  }

  Future<void> replaceAll(AppData fresh) async {
    data = fresh;
    data.settleMisses(DateTime.now());
    notifyListeners();
    // Keeps the restored copy's date, so it doesn't look newer than the
    // cloud's.
    await data.save(touch: false);
    for (final l in _savedListeners) {
      l(data);
    }
  }

  void _scheduleMidnight() {
    _dayTimer?.cancel();
    final now = DateTime.now();
    final next = addDays(dayOnly(now), 1).add(const Duration(seconds: 5));
    _dayTimer = Timer(next.difference(now), () {
      // A new day: redraw even if nothing needed settling.
      refresh().then((_) => notifyListeners());
      _scheduleMidnight();
    });
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    super.dispose();
  }
}
