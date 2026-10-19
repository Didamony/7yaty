import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

class Files {
  static const supported = true;
  static late String _root;

  static Future<void> init() async {
    _root = (await getApplicationDocumentsDirectory()).path;
  }

  static String path(String sub, String name) => '$_root/$sub/$name';

  static Future<void> ensure(String sub) => dir(sub);

  static Future<Directory> dir(String sub) =>
      Directory('$_root/$sub').create(recursive: true);

  static Future<void> write(String sub, String name, List<int> bytes) async {
    await dir(sub);
    await File(path(sub, name)).writeAsBytes(bytes, flush: true);
  }

  static Future<void> copyIn(String sub, String name, String from) async {
    await dir(sub);
    await File(from).copy(path(sub, name));
  }

  static Future<Uint8List?> read(String sub, String name) async {
    final f = File(path(sub, name));
    return await f.exists() ? f.readAsBytes() : null;
  }

  static Future<bool> exists(String sub, String name) =>
      File(path(sub, name)).exists();

  static Future<int> size(String sub, String name) async {
    final f = File(path(sub, name));
    return await f.exists() ? f.length() : 0;
  }

  static Future<void> delete(String sub, String name) async {
    final f = File(path(sub, name));
    if (await f.exists()) await f.delete();
  }

  static Future<List<String>> list(String sub) async {
    final d = await dir(sub);
    return d
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList();
  }

  static ImageProvider? image(String? bg) {
    if (bg == null) return null;
    final f = File(path('media', bg));
    return f.existsSync() ? FileImage(f) : null;
  }
}
