import 'package:file_picker/file_picker.dart';

import 'files.dart';

/// Picks any file (some Android file managers hide EPUBs behind a type
/// filter), then copies it into the app's books folder as [saveAs]. Returns
/// the original file name, or null if nothing was picked.
Future<String?> pickBookFile(String Function(String ext) saveAs) async {
  final picked = await FilePicker.pickFile(type: FileType.any);
  if (picked == null) return null;
  final ext = (picked.extension ?? '').toLowerCase();
  if (ext != 'pdf' && ext != 'epub') throw const BadBookType();
  final name = saveAs(ext);
  await Files.ensure('books');
  try {
    await picked.xFile.saveTo(Files.path('books', name));
  } catch (_) {
    // Content URIs can't always be copied as a path; read the bytes instead.
    await Files.write('books', name, await picked.readAsBytes());
  }
  return picked.name;
}

class BadBookType implements Exception {
  const BadBookType();
}
