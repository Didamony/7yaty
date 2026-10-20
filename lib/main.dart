import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/i18n.dart';
import 'core/theme.dart';
import 'data/models.dart';
import 'data/store.dart';
import 'demo.dart';
import 'services/cloud.dart';
import 'services/files.dart';
import 'services/notifications.dart';
import 'services/prayer.dart';
import 'services/updates.dart';
import 'ui/auth_page.dart';
import 'ui/shell.dart';
import 'ui/update_banner.dart';

/// Builds with `--dart-define=DEMO=true` start with sample content, for
/// screenshots only.
const _demo = bool.fromEnvironment('DEMO');

/// Builds with `--dart-define=VIDEO=true` run animations at half speed, so
/// a screen recording at a low frame rate can be sped up smoothly.
const _video = bool.fromEnvironment('VIDEO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_video) timeDilation = 2;
  PrayerTimes.init();
  await Files.init();
  await initializeDateFormatting();
  final store = await AppStore.open();
  if (_demo && store.data.isEmpty) {
    seedDemo(store.data);
    await store.data.save();
  }
  L10n.lang = store.settings.lang;
  await Cloud.instance.init(store.settings.lang);

  final notifier = Notifier.instance;
  await notifier.init();
  notifier.onAction = (payload, action) {
    if (action != null) {
      store.update((d) => d.applyNotificationAction(payload, action));
    }
  };
  store
    ..onSaved(notifier.scheduleSoon)
    ..onSaved(Cloud.instance.backupSoon);
  notifier.scheduleSoon(store.data);
  Updates.instance.check();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: Cloud.instance),
      ],
      child: const HayatiApp(),
    ),
  );
}

class HayatiApp extends StatefulWidget {
  const HayatiApp({super.key});

  @override
  State<HayatiApp> createState() => _HayatiAppState();
}

class _HayatiAppState extends State<HayatiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final store = context.read<AppStore>();
    if (state == AppLifecycleState.resumed) {
      Updates.instance.check();
      // Notification buttons may have changed the saved data meanwhile.
      store.reload().then((_) => Notifier.instance.scheduleSoon(store.data));
    } else if (state == AppLifecycleState.paused) {
      Cloud.instance.backup(store.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>().settings;
    L10n.lang = s.lang;
    final t = activeTheme(
      s,
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
      DateTime.now(),
    );
    return MaterialApp(
      title: 'حياتي',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(t),
      locale: Locale(s.lang),
      supportedLocales: L10n.supported.map(Locale.new),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => ThemeBackground(
        theme: t,
        image: Files.image(s.themeImages[t.id]),
        strength: s.bgOpacity,
        child: Stack(
          fit: StackFit.expand,
          children: [child!, const UpdateBanner()],
        ),
      ),
      home: const AuthGate(child: Shell()),
    );
  }
}

/// Which look to use now: the dark theme in dark mode, otherwise the
/// user's fixed pick or the theme of today's weekday.
AppTheme activeTheme(Settings s, Brightness platform, DateTime now) {
  final dark =
      s.theme == 'dark' || (s.theme == 'system' && platform == Brightness.dark);
  if (dark) return AppTheme.darkTheme;
  if (s.themeChoice == 'auto') return AppTheme.forDay(now);
  return AppTheme.byId(s.themeChoice);
}

/// The theme picture behind every screen, or a soft gradient in the
/// theme's colors when no picture has been chosen.
class ThemeBackground extends StatelessWidget {
  const ThemeBackground({
    super.key,
    required this.theme,
    required this.image,
    required this.strength,
    required this.child,
  });

  final AppTheme theme;
  final ImageProvider? image;
  final double strength;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bg, p.hint],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null) ...[
            Opacity(
              opacity: strength,
              child: Image(image: image!, fit: BoxFit.cover),
            ),
            // A veil in the theme's own color keeps text readable on busy
            // pictures.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    p.bg.withValues(alpha: 0.55),
                    p.bg.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ],
          child,
        ],
      ),
    );
  }
}
