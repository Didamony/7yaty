/// Picking a book file (PDF or EPUB) from the device.
library;

export 'pick_book_web.dart' if (dart.library.io) 'pick_book_io.dart';
