import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hayati/core/theme.dart';
import 'package:hayati/data/store.dart';
import 'package:hayati/ui/journal.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('typing in the diary shows the save button', (t) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting();
    final store = AppStore(AppData());
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          theme: buildTheme(AppTheme.forDay(DateTime(2026, 11, 27))),
          home: const Scaffold(body: JournalPage()),
        ),
      ),
    );
    await t.pump();
    final box = find.descendant(
      of: find.byType(JournalPage),
      matching: find.byType(TextField),
    );
    expect(box, findsWidgets);
    await t.enterText(box.first, 'تجربة');
    await t.pump();
    expect(find.text('حفظ'), findsOneWidget);
    await t.tap(find.text('حفظ'));
    await t.pump();
    expect(store.data.journal.values.single.notes.single.text, 'تجربة');
  });
}
