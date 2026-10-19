import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/i18n.dart';
import 'core/theme.dart';
import 'data/store.dart';
import 'demo.dart';
import 'services/drive_sync.dart';
import 'services/files.dart';
import 'services/notifications.dart';
import 'services/prayer.dart';
import 'ui/shell.dart';

/// Builds with `--dart-define=DEMO=true` start with sample content, for
/// screenshots only.
const _demo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PrayerTimes.init();
  await Files.init();
  await initializeDateFormatting();
  final store = await AppStore.open();
  if (_demo && store.data.isEmpty) {
    seedDemo(store.data);
    await store.data.save();
  }
  L10n.lang = store.settings.lang;

  final notifier = Notifier.instance;
  await notifier.init();
  notifier.onAction = (payload, action) {
    if (action != null) {
      store.update((d) => d.applyNotificationAction(payload, action));
    }
  };
  store
    ..onSaved(notifier.scheduleSoon)
    ..onSaved(DriveSync.instance.backupSoon);
  notifier.scheduleSoon(store.data);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: DriveSync.instance),
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final store = context.read<AppStore>();
    if (state == AppLifecycleState.resumed) {
      // Notification buttons may have changed the saved data meanwhile.
      store.reload().then((_) => Notifier.instance.scheduleSoon(store.data));
    } else if (state == AppLifecycleState.paused &&
        store.settings.googleEmail != null) {
      DriveSync.instance.backup(store.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>().settings;
    L10n.lang = s.lang;
    return MaterialApp(
      title: 'حياتي',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (s.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: Locale(s.lang),
      supportedLocales: L10n.supported.map(Locale.new),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        final p = Palette.of(context);
        final image = Files.image(s.bgImage);
        return ColoredBox(
          color: p.bg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                Opacity(
                  opacity: s.bgOpacity,
                  child: Image(image: image, fit: BoxFit.cover),
                ),
              child!,
            ],
          ),
        );
      },
      home: const Shell(),
    );
  }
}
