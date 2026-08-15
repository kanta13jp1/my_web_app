import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_version.dart';

class VersionCheckService {
  static const Duration _pollInterval = Duration(minutes: 30);

  /// checkNow の最小間隔。Flutter Web ではフォーカス取得のたびに
  /// AppLifecycleState.resumed が来る (DevTools やタブの往復含む) ため、
  /// 時間ベースで抑制しないとフォーカス往復がそのままリクエスト数になる。
  /// バックグラウンド復帰後のデプロイ検知は最大この時間だけ遅れるトレードオフ。
  static const Duration _minCheckGap = Duration(minutes: 5);

  Timer? _timer;
  VoidCallback? _onOutdated;
  bool _checking = false;
  DateTime? _lastCheckedAt;

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

  /// 最新バージョンを一度だけ確認し、現在より新しければ [onOutdated] を呼ぶ。
  ///
  /// [onOutdated] を省略すると [startPolling] で登録したコールバックを使う。
  /// アプリ起動直後や前面復帰時に呼び、デプロイ直後に開いた場合や旧バンドルが
  /// HTTP キャッシュから配信された場合 (= 起動時点で既に古い) を即座に検知する。
  /// 30 分間隔のポーリングを待たずに更新を促せる。
  Future<void> checkNow([VoidCallback? onOutdated]) async {
    if (!kIsWeb || AppVersion.isDev) return;
    final callback = onOutdated ?? _onOutdated;
    if (callback == null || _checking) return;
    final now = DateTime.now();
    if (!shouldCheck(now)) return;
    _checking = true;
    _lastCheckedAt = now;
    try {
      final latest = await fetchLatestVersion();
      if (latest != null && isOutdated(AppVersion.value, latest)) {
        callback();
      }
    } finally {
      _checking = false;
    }
  }

  /// [checkNow] の時間ベース cooldown 判定。前回チェックから
  /// [_minCheckGap] 未満なら false (フォーカス往復による連続発火を抑制)。
  @visibleForTesting
  bool shouldCheck(DateTime now) {
    final last = _lastCheckedAt;
    return last == null || now.difference(last) >= _minCheckGap;
  }

  /// テスト用: 前回チェック時刻を注入する。
  @visibleForTesting
  void debugSetLastCheckedAt(DateTime? value) => _lastCheckedAt = value;

  void startPolling(VoidCallback onOutdated) {
    if (!kIsWeb) return;
    _onOutdated = onOutdated;
    // 起動直後に一度確認 (デプロイ直後に開いた / 旧バンドルが配信された場合を即検知)。
    unawaited(checkNow(onOutdated));
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(checkNow()));
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _onOutdated = null;
  }
}
