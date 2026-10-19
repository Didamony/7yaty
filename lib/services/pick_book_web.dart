import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'files.dart';

/// Opens the browser's file chooser and stores the chosen PDF or EPUB in
/// app storage as [saveAs]. The input stays in the page until a file
/// arrives, which Safari on iPhone needs to report the selection.
Future<String?> pickBookFile(String Function(String ext) saveAs) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.pdf,.epub,application/pdf,application/epub+zip'
    ..style.display = 'none';
  web.document.body!.append(input);
  final chosen = Completer<web.File?>();
  input.addEventListener(
    'change',
    ((web.Event _) {
      final files = input.files;
      chosen.complete(files != null && files.length > 0 ? files.item(0) : null);
    }).toJS,
  );
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!chosen.isCompleted) chosen.complete(null);
    }).toJS,
  );
  input.click();
  final file = await chosen.future;
  input.remove();
  if (file == null) return null;
  final ext = file.name.split('.').last.toLowerCase();
  if (ext != 'pdf' && ext != 'epub') throw const BadBookType();
  final buffer = await file.arrayBuffer().toDart;
  await Files.write('books', saveAs(ext), buffer.toDart.asUint8List());
  return file.name;
}

class BadBookType implements Exception {
  const BadBookType();
}
