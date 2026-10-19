/// Access to the app's own folders (recordings, books, background image).
/// The web build has no file system, so those features are mobile only.
library;

export 'files_web.dart' if (dart.library.io) 'files_io.dart';
