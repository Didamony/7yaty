import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves the tour's screenshots to diagnostics/tour/.
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final f = File('diagnostics/tour/$name.png');
    await f.create(recursive: true);
    await f.writeAsBytes(bytes);
    return true;
  },
);
