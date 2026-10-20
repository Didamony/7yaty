import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/theme.dart';
import 'package:hayati/services/updates.dart';
import 'package:hayati/ui/update_banner.dart';

void main() {
  testWidgets('a newer build shows the update bar until closed', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(AppTheme.forDay(DateTime(2026, 10, 20))),
        home: const Scaffold(body: Stack(children: [UpdateBanner()])),
      ),
    );
    expect(find.text('حدّث'), findsNothing);
    Updates.instance.available = AppUpdate(99, 'https://example.com/a.apk');
    Updates.instance.dismiss();
    Updates.instance.dismissed = false;
    await t.pump();
    expect(find.text('فيه تحديث جديد'), findsOneWidget);
    expect(find.text('حدّث'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    await t.pump();
    expect(find.text('حدّث'), findsNothing);
  });
}
