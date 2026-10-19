import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:idb_shim/idb_browser.dart';

/// The web build keeps files in the browser's IndexedDB, keyed `sub/name`.
/// A home-screen web app on iPhone keeps this storage like a normal app.
class Files {
  static const supported = true;
  static const _store = 'files';
  static Database? _db;

  /// Images kept in memory so the background can be drawn synchronously.
  static final _media = <String, Uint8List>{};

  static Future<void> init() async {
    try {
      _db = await idbFactoryBrowser.open(
        'hayati_files',
        version: 1,
        onUpgradeNeeded: (e) => e.database.createObjectStore(_store),
      );
      for (final name in await list('media')) {
        final bytes = await read('media', name);
        if (bytes != null) _media[name] = bytes;
      }
    } catch (e) {
      debugPrint('hayati: browser storage unavailable: $e');
    }
  }

  static String path(String sub, String name) => '$sub/$name';

  static Future<void> ensure(String sub) async {}

  static ObjectStore _open(String mode) =>
      _db!.transaction(_store, mode).objectStore(_store);

  static Future<void> write(String sub, String name, List<int> bytes) async {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    await _open(idbModeReadWrite).put(data, path(sub, name));
    if (sub == 'media') _media[name] = data;
  }

  static Future<void> copyIn(String sub, String name, String from) async =>
      throw UnsupportedError('copyIn');

  static Future<Uint8List?> read(String sub, String name) async {
    final v = await _open(idbModeReadOnly).getObject(path(sub, name));
    return v is Uint8List ? v : null;
  }

  static Future<bool> exists(String sub, String name) async =>
      (await _open(idbModeReadOnly).getObject(path(sub, name))) != null;

  static Future<int> size(String sub, String name) async =>
      (await read(sub, name))?.length ?? 0;

  static Future<void> delete(String sub, String name) async {
    await _open(idbModeReadWrite).delete(path(sub, name));
    if (sub == 'media') _media.remove(name);
  }

  static Future<List<String>> list(String sub) async {
    final keys = await _open(idbModeReadOnly).getAllKeys();
    return [
      for (final k in keys)
        if (k is String && k.startsWith('$sub/')) k.substring(sub.length + 1),
    ];
  }

  static ImageProvider? image(String? bg) {
    if (bg == null) return null;
    if (bg.startsWith('data:')) {
      return MemoryImage(base64Decode(bg.substring(bg.indexOf(',') + 1)));
    }
    final bytes = _media[bg];
    return bytes == null ? null : MemoryImage(bytes);
  }
}
