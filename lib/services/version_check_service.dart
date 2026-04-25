import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_version.dart';

class VersionCheckService {
  static const Duration _pollInterval = Duration(minutes: 30);
  Timer? _timer;

  Future<String?> fetchLatestVersion() async {
    final uri = Uri.parse(
      '/version.json?t=${DateTime.now().millisecondsSinceEpoch}',
    );
    try {
      final resp = await http.get(
        uri,
        headers: {'Cache-Control': 'no-cache'},
      );
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return json['version'] as String?;
    } catch (_) {
      return null;
    }
  }

  bool isOutdated(String current, String latest) {
    final curParts = current.split('.').map(int.tryParse).toList();
    final latParts = latest.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final c = i < curParts.length ? (curParts[i] ?? 0) : 0;
      final l = i < latParts.length ? (latParts[i] ?? 0) : 0;
      if (c != l) return c < l;
    }
    return false;
  }

  void startPolling(VoidCallback onOutdated) {
    if (!kIsWeb) return;
    _timer = Timer.periodic(_pollInterval, (_) async {
      final latest = await fetchLatestVersion();
      if (latest != null &&
          !AppVersion.isDev &&
          isOutdated(AppVersion.value, latest)) {
        onOutdated();
      }
    });
  }

  void dispose() => _timer?.cancel();
}
