import 'dart:convert';

import 'package:flutter/services.dart';

class Surah {
  const Surah(this.number, this.name, this.meccan, this.ayat);

  final int number;
  final String name;
  final bool meccan;
  final List<String> ayat;
}

/// The Uthmani Quran text bundled with the app (see assets/quran/README.md).
class Quran {
  static List<Surah>? _surahs;

  static const bismillah = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ';

  static Future<List<Surah>> load() async {
    if (_surahs != null) return _surahs!;
    final raw = jsonDecode(
      await rootBundle.loadString('assets/quran/quran.json'),
    ) as List;
    _surahs = [
      for (var i = 0; i < raw.length; i++)
        Surah(
          i + 1,
          raw[i][0] as String,
          raw[i][1] == 'm',
          (raw[i][2] as List).cast<String>(),
        ),
    ];
    return _surahs!;
  }

  /// Verses [from]..[to] (1-based, inclusive) of surah [surah].
  static Future<List<String>> ayat(int surah, int from, int to) async {
    final s = (await load())[surah - 1];
    return s.ayat.sublist(from - 1, to);
  }
}
