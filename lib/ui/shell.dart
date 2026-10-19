import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/notifications.dart';
import 'appointments.dart';
import 'goals.dart';
import 'journal.dart';
import 'today.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstRun());
  }

  /// Asks for notification permission once, on the first launch.
  Future<void> _firstRun() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('hayati.askedPermissions') ?? false) return;
    await prefs.setBool('hayati.askedPermissions', true);
    await Notifier.instance.requestPermissions();
  }

  void go(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          TodayPage(onOpenGoals: () => go(1)),
          const GoalsPage(),
          const AppointmentsPage(),
          const JournalPage(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: p.card,
          indicatorColor: p.primary.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => TextStyle(
              fontFamily: kBody,
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: s.contains(WidgetState.selected) ? p.primary : p.muted,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? p.primary : p.muted,
            ),
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.line)),
          ),
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: go,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.wb_sunny_outlined),
                label: tr('اليوم'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.track_changes),
                label: tr('أهدافي'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.schedule),
                label: tr('المواعيد'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                label: tr('يومياتي'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
