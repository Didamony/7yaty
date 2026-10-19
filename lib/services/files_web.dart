import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

class Files {
  static const supported = false;

  static Future<void> init() async {}

  static String path(String sub, String name) => '$sub/$name';

  static Future<void> ensure(String sub) async {}

  static Future<void> write(String sub, String name, List<int> bytes) async =>
      throw UnsupportedError('files');

  static Future<void> copyIn(String sub, String name, String from) async =>
      throw UnsupportedError('files');

  static Future<Uint8List?> read(String sub, String name) async => null;

  static Future<bool> exists(String sub, String name) async => false;

  static Future<int> size(String sub, String name) async => 0;

  static Future<void> delete(String sub, String name) async {}

  static Future<List<String>> list(String sub) async => [];

  /// On the web the background is kept inline as a `data:` URI.
  static ImageProvider? image(String? bg) {
    if (bg == null || !bg.startsWith('data:')) return null;
    return MemoryImage(base64Decode(bg.substring(bg.indexOf(',') + 1)));
  }
}
