// Walks through every screen of the app on a real device, with the demo
// data (run with --dart-define=DEMO=true), failing on any error and
// keeping a screenshot of each screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/main.dart' as app;
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'tour of the app',
    timeout: const Timeout(Duration(minutes: 10)),
    (t) async {
      app.main();
      // The app has running timers and animations, so don't wait to settle.
      Future<void> wait([int ms = 1500]) async {
        for (var i = 0; i < ms ~/ 100; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }

      var shot = 0;
      Future<void> snap(String name) async {
        await wait(600);
        await binding.takeScreenshot(
          '${(++shot).toString().padLeft(2, '0')}-$name',
        );
      }

      Future<void> tab(String label) async {
        await t.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await wait();
      }

      /// Waits up to 15 s for [f] to be on screen (the device is slow).
      Future<void> until(Finder f) async {
        for (var i = 0; i < 150 && f.evaluate().isEmpty; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> open(Finder f) async {
        await until(f);
        // Off screen in a scrolled list: look up, then down.
        final list = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        for (final dy in [-400.0, 400.0]) {
          if (f.evaluate().isNotEmpty || list.evaluate().isEmpty) break;
          try {
            await t.scrollUntilVisible(
              f,
              dy,
              scrollable: list.first,
              maxScrolls: 15,
            );
          } catch (_) {}
        }
        if (f.evaluate().isEmpty) {
          final shown = find
              .byType(Text)
              .evaluate()
              .map((e) => (e.widget as Text).data)
              .whereType<String>()
              .take(40)
              .join(' | ');
          await binding.takeScreenshot('missing-${++shot}');
          fail('Not on screen: $f\nShown: $shown');
        }
        await t.ensureVisible(f.first);
        await wait(400);
        await t.tap(f.first);
        await wait();
      }

      /// Back to the previous screen, as the system back button does.
      Future<void> back() async {
        await t.state<NavigatorState>(find.byType(Navigator).first).maybePop();
        await wait(1500);
      }

      await wait(6000);
      await binding.convertFlutterSurfaceToImage();
      await wait();
      expect(find.byType(NavigationBar), findsOneWidget);
      await snap('today');

      await tab('أهدافي');
      await snap('goals');
      await open(find.text('الرسم البياني'));
      await snap('charts');
      await back();
      await open(find.text('جدول السنة'));
      await snap('year-plan');
      await back();
      await open(find.text('الشيت الشهري'));
      await snap('sheet');
      await back();
      await open(find.text('كتبي'));
      await snap('books');
      await back();

      await tab('المواعيد');
      await snap('appointments');

      await tab('عباداتي');
      await snap('worship');
      await open(find.text('المصحف'));
      await open(find.text('سورة الفاتحة'));
      await snap('quran');
      await back();
      await back();
      await open(find.text('أذكار الصباح'));
      await snap('adhkar');
      await back();
      await open(find.text('السبحة'));
      await t.tapAt(t.getCenter(find.byType(Scaffold).last));
      await wait();
      await snap('tasbih');
      await back();

      await tab('يومياتي');
      // Saving a note is covered by test/journal_save_test.dart.
      await snap('journal');

      await tab('اليوم');
      await open(find.byTooltip('الإعدادات'));
      await snap('settings');
      await back();
    },
  );
}
