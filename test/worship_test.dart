import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/data/adhkar.dart';

void main() {
  final quran =
      jsonDecode(File('assets/quran/quran.json').readAsStringSync()) as List;

  test('the bundled Quran is complete', () {
    expect(quran.length, 114);
    final verses = quran.fold<int>(0, (n, s) => n + (s[2] as List).length);
    expect(verses, 6236);
    expect(quran[0][0], 'الفاتحة');
    expect((quran[1][2] as List).length, 286);
  });

  test('every Quran passage in the adhkar exists', () {
    for (final c in adhkarCategories) {
      for (final d in c.items) {
        expect(d.text != null || d.quran != null, isTrue);
        final q = d.quran;
        if (q == null) continue;
        final (surah, from, to) = q;
        final count = (quran[surah - 1][2] as List).length;
        expect(from >= 1 && from <= to && to <= count, isTrue,
            reason: '${c.title}: $surah:$from-$to');
      }
    }
  });
}
