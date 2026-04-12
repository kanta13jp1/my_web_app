// lib/utils/error_reporter.dart
//
// Flutter エラー → submit-feedback EF への自動報告
//
// 仕組み:
//   1. FlutterError.onError   … Flutterフレームワークエラー
//   2. PlatformDispatcher.onError … 未捕捉 Dart ランタイムエラー
//   3. AppLogger.error 経由  … 明示的に記録されたエラー
//
// 保護策:
//   - ログイン済みユーザーのみ送信
//   - セッション内で同一エラー（先頭120文字）は重複送信しない
//   - セッション内の最大送信数: 10件
//   - 報告中の再帰ループを防ぐフラグ

import 'dart:math';

import 'package:flutter/foundation.dart';
import '../main.dart';

class ErrorReporter {
  ErrorReporter._();
  static final ErrorReporter instance = ErrorReporter._();

  static const int _maxPerSession = 10;

  final Set<String> _seen = {};
  int _count = 0;
  bool _isReporting = false;

  // ignore: unused_field
  FlutterExceptionHandler? _previousFlutterHandler;

  /// `main()` の Supabase.initialize() 直後に呼ぶ
  void install() {
    _previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _previousFlutterHandler?.call(details);
      report(
        details.exceptionAsString(),
        stackTrace: details.stack,
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      report(error.toString(), stackTrace: stack);
      return false; // 既存のクラッシュハンドラを妨げない
    };
  }

  /// AppLogger.error から呼ばれる (caught errors)
  void report(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    if (_isReporting) return;
    _isReporting = true;
    try {
      _scheduleReport(message, error: error, stackTrace: stackTrace);
    } finally {
      _isReporting = false;
    }
  }

  void _scheduleReport(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    // ログイン確認
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // スロットリング
    if (_count >= _maxPerSession) return;

    // エラーフィンガープリント（最初の120文字）
    final fullMessage = error != null ? '$message: $error' : message;
    final fingerprint = fullMessage.substring(0, min(120, fullMessage.length));
    if (_seen.contains(fingerprint)) return;
    _seen.add(fingerprint);
    _count++;

    // スタックトレース（最初の6行）
    final stackLines = stackTrace
        ?.toString()
        .split('\n')
        .take(6)
        .join('\n') ?? '';

    final content = '[自動エラー報告]\n'
        '$fullMessage'
        '${stackLines.isNotEmpty ? '\n\n$stackLines' : ''}';

    // 非同期で静かに送信
    Future.microtask(() async {
      try {
        await supabase.functions.invoke(
          'core-hub',
          body: {
            'action': 'feedback.submit',
            'category': 'bug',
            'message': content.substring(0, min(2000, content.length)),
          },
        );
      } catch (_) {
        // 報告失敗は無視（無限ループ防止）
      }
    });
  }
}
