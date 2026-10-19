import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/strings.dart';

void main() {
  test('every Arabic string passed to tr() has en, fr and de translations', () {
    final pattern = RegExp(r"tr\(\s*'((?:[^'\\]|\\.)*)'");
    final missing = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in pattern.allMatches(f.readAsStringSync())) {
        final key = m.group(1)!.replaceAll(r"\'", "'");
        for (final lang in ['en', 'fr', 'de']) {
          if (translations[lang]?[key] == null) missing.add('$lang: $key');
        }
      }
    }
    expect(missing, isEmpty);
  });
}
