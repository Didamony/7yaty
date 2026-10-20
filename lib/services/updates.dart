import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// This build's number and where its releases are published, passed by the
/// Android workflow. 0 in local builds, which never offer updates.
const _build = int.fromEnvironment('BUILD_NUMBER');
const _repo = String.fromEnvironment(
  'DIST_REPO',
  defaultValue: 'Didamony/7yaty',
);

/// A newer Android build than the one running.
class AppUpdate {
  AppUpdate(this.build, this.url);

  final int build;

  /// Where to download its APK.
  final String url;
}

/// Looks for a newer APK among the GitHub releases, so people who
/// installed the app outside Google Play still hear about updates.
class Updates extends ChangeNotifier {
  Updates._();

  static final instance = Updates._();

  AppUpdate? available;

  /// Closed by the user until the next launch.
  bool dismissed = false;
  DateTime? _checked;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && _build > 0;

  Future<void> check() async {
    if (!supported) return;
    final now = DateTime.now();
    if (_checked != null && now.difference(_checked!).inMinutes < 30) return;
    _checked = now;
    try {
      final r = await http
          .get(
            Uri.https('api.github.com', '/repos/$_repo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final n = int.tryParse(
        RegExp(r'(\d+)$').firstMatch(j['tag_name'] ?? '')?.group(1) ?? '',
      );
      final apk = (j['assets'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .where((a) => (a['name'] as String? ?? '').endsWith('.apk'))
          .firstOrNull;
      if (n == null || n <= _build || apk == null) return;
      available = AppUpdate(n, apk['browser_download_url']);
      notifyListeners();
    } catch (e) {
      debugPrint('hayati: update check failed: $e');
    }
  }

  void dismiss() {
    dismissed = true;
    notifyListeners();
  }
}
