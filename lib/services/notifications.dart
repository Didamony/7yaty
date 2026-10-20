import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/dates.dart';
import '../core/i18n.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'prayer.dart';

/// Runs when a notification button is pressed while the app is closed.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationAction(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  final data = await AppData.load();
  if (data.applyNotificationAction(r.payload, r.actionId)) {
    await data.save();
  }
}

/// Built with the adhan recordings in `android/app/src/main/res/raw`
/// (`adhan.mp3`, and `adhan_fajr.mp3` for Fajr); see the Android workflow.
const _hasAdhan = bool.fromEnvironment('ADHAN');

/// Schedules every reminder the app gives: prayers, the evening review with
/// buttons per goal, goal times and appointments. Everything is rebuilt from
/// the saved data whenever it changes, a few days ahead.
class Notifier {
  Notifier._();

  static final instance = Notifier._();
  static const _daysAhead = 4;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Timer? _debounce;
  void Function(String? payload, String? action)? onAction;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android ||
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> init() async {
    if (!supported || _ready) return;
    PrayerTimes.init();
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings(
          '@drawable/ic_stat_hayati',
        ),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              'goal',
              actions: [
                DarwinNotificationAction.plain('done', tr('تم ✓')),
                DarwinNotificationAction.plain('missed', tr('ما اتعملش')),
                DarwinNotificationAction.plain('carry', tr('رحّله لبكرة')),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (r) =>
          onAction?.call(r.payload, r.actionId),
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationAction,
    );
    _ready = true;
  }

  Future<void> requestPermissions() async {
    if (!supported) return;
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    if (await android?.canScheduleExactNotifications() == false) {
      await android?.requestExactAlarmsPermission();
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Rebuilds the schedule shortly after the last change.
  void scheduleSoon(AppData data) {
    if (!supported) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => reschedule(data));
  }

  Future<void> reschedule(AppData data) async {
    if (!supported) return;
    await init();
    await _plugin.cancelAll();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? true;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = DateTime.now();
    final s = data.settings;

    Future<void> at(
      DateTime when,
      String key,
      String title,
      String body,
      _Channel ch, {
      String? payload,
      bool withActions = false,
      bool adhan = false,
    }) async {
      if (!when.isAfter(now)) return;
      final scheduled = tz.TZDateTime(
        PrayerTimes.cairo,
        when.year,
        when.month,
        when.day,
        when.hour,
        when.minute,
      );
      try {
        await _plugin.zonedSchedule(
          id: _id(key),
          scheduledDate: scheduled,
          title: title,
          body: body,
          payload: payload,
          androidScheduleMode: mode,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              ch.id,
              tr(ch.name),
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(body),
              // The adhan plays as an alarm sound, so it's heard as it
              // should be; dismissing the notification stops it.
              sound: ch.sound == null
                  ? null
                  : RawResourceAndroidNotificationSound(ch.sound),
              audioAttributesUsage: adhan
                  ? AudioAttributesUsage.alarm
                  : AudioAttributesUsage.notification,
              actions: adhan
                  ? [AndroidNotificationAction('stop', tr('إيقاف الأذان'))]
                  : withActions
                  ? [
                      AndroidNotificationAction('done', tr('تم ✓')),
                      AndroidNotificationAction('missed', tr('ما اتعملش')),
                      AndroidNotificationAction('carry', tr('رحّله لبكرة')),
                    ]
                  : null,
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: withActions ? 'goal' : null,
            ),
          ),
        );
      } catch (e) {
        debugPrint('hayati: could not schedule $key: $e');
      }
    }

    for (var i = 0; i < _daysAhead; i++) {
      final day = addDays(dayOnly(now), i);

      // Prayers.
      final times = PrayerTimes.forDay(day, s.city);
      for (final p in Prayer.values) {
        final t = times[p]!;
        final before = s.prayerBefore[p.name] ?? 10;
        if (before > 0) {
          await at(
            t.subtract(Duration(minutes: before)),
            'prayer-before|${p.name}|${dkey(day)}',
            tr('اقتربت صلاة {p}', {'p': prayerName(p)}),
            p == Prayer.fajr
                ? tr('الصلاة خير من النوم · الأذان بعد {n} دقيقة، الساعة {t}', {
                    'n': before,
                    't': fmtTime(t),
                  })
                : tr('الأذان بعد {n} دقيقة، الساعة {t}', {
                    'n': before,
                    't': fmtTime(t),
                  }),
            _Channel.prayer,
          );
        }
        if (s.adhanAtTime) {
          await at(
            t,
            'prayer-now|${p.name}|${dkey(day)}',
            tr('حان الآن موعد أذان {p}', {'p': prayerName(p)}),
            '${tr('الله أكبر، الله أكبر')} · ${cityName(s.city)}',
            !_hasAdhan
                ? _Channel.prayer
                : p == Prayer.fajr
                ? _Channel.adhanFajr
                : _Channel.adhan,
            adhan: _hasAdhan,
          );
        }
      }

      // Morning and evening adhkar, half an hour after Fajr and Asr.
      if (data.worship.adhkarReminders) {
        await at(
          times[Prayer.fajr]!.add(const Duration(minutes: 30)),
          'adhkar|morning|${dkey(day)}',
          tr('أذكار الصباح'),
          tr('افتح حياتي واقرأ أذكار الصباح'),
          _Channel.adhkar,
        );
        await at(
          times[Prayer.asr]!.add(const Duration(minutes: 30)),
          'adhkar|evening|${dkey(day)}',
          tr('أذكار المساء'),
          tr('افتح حياتي واقرأ أذكار المساء'),
          _Channel.adhkar,
        );
      }

      // Goals: at their own time, and in the evening review.
      final review = day.add(Duration(minutes: s.reviewMin));
      for (final g in data.goalsOn(day)) {
        if (data.status(g, day) == Occ.done) continue;
        final payload = 'goal|${g.id}|${dkey(day)}';
        final title = goalTitle(data, g, day);
        final due = PrayerTimes.goalTime(g, day, s.city);
        if (due != null) {
          await at(
            due,
            'goal-time|${g.id}|${dkey(day)}',
            title,
            tr('حان وقت هدفك'),
            _Channel.goals,
            payload: payload,
            withActions: true,
          );
        }
        await at(
          review,
          'goal-review|${g.id}|${dkey(day)}',
          title,
          tr('عملته النهارده؟'),
          _Channel.review,
          payload: payload,
          withActions: true,
        );
      }
      for (final (g, d) in data.qadaPlannedOn(day)) {
        await at(
          review,
          'qada-review|${g.id}|${dkey(d)}',
          tr('قضاء: {t}', {'t': g.title}),
          tr('افتح حياتي وعلّم عليه'),
          _Channel.review,
        );
      }

      // Appointments.
      for (final a in data.appointments) {
        if (!a.occursOn(day)) continue;
        final when = day.add(Duration(minutes: a.timeMin));
        for (final r in a.reminders) {
          await at(
            when.subtract(Duration(minutes: r)),
            'appt|${a.id}|${dkey(day)}|$r',
            a.title,
            [
              r == 0
                  ? tr('دلوقتي · {t}', {'t': fmtTime(when)})
                  : tr('بعد {m} · {t}', {
                      'm': minutesLabel(r),
                      't': fmtTime(when),
                    }),
              if (a.place.isNotEmpty) a.place,
            ].join(' · '),
            _Channel.appointments,
          );
        }
      }
    }
  }

  /// Stable notification id from a text key (FNV-1a, 31 bits).
  static int _id(String key) {
    var h = 0x811c9dc5;
    for (final c in key.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }
}

/// A goal's display title; reading goals say how much to read today.
String goalTitle(AppData data, Goal g, DateTime day) {
  final b = data.book(g.bookId);
  if (b == null) return g.title;
  final per = b.perDay(day);
  return b.kind == BookKind.pdf
      ? tr('اقرأ {n} صفحة · {t}', {'n': per, 't': b.title})
      : tr('اقرأ {n} جزء · {t}', {'n': per, 't': b.title});
}

enum _Channel {
  prayer('hayati_prayer', 'مواعيد الصلاة'),
  adhan('hayati_adhan', 'الأذان', sound: 'adhan'),
  adhanFajr('hayati_adhan_fajr', 'أذان الفجر', sound: 'adhan_fajr'),
  goals('hayati_goals', 'أهدافي'),
  review('hayati_review', 'مراجعة المساء'),
  appointments('hayati_appointments', 'مواعيدي'),
  adhkar('hayati_adhkar', 'الأذكار');

  const _Channel(this.id, this.name, {this.sound});

  final String id;
  final String name;

  /// A recording in `res/raw`; Android fixes a channel's sound when it is
  /// first created.
  final String? sound;
}
