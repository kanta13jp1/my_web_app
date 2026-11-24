import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'sensitive_log_masker.dart';

typedef AppLoggerErrorReporter = void Function(
  String message, {
  dynamic error,
  StackTrace? stackTrace,
});

typedef AppLoggerSink = void Function(
  String level,
  dynamic message, {
  dynamic error,
  StackTrace? stackTrace,
});

/// アプリケーション全体で使用するロガー (#2732 機密情報自動マスク対応)。
///
/// 使用例:
/// ```dart
/// AppLogger.info('情報メッセージ');
/// AppLogger.error('エラーメッセージ', error: e, stackTrace: st);
/// ```
class AppLogger {
  static AppLoggerErrorReporter? _errorReporter;
  static AppLoggerSink? _logSinkForTesting;

  static final Logger _logger = Logger(
    filter: SensitiveLogFilter(),
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void setErrorReporter(AppLoggerErrorReporter? reporter) {
    _errorReporter = reporter;
  }

  /// テスト時にマスク済みログ出力を検証するためのシンクを設定する。
  @visibleForTesting
  static void setLogSinkForTesting(AppLoggerSink? sink) {
    _logSinkForTesting = sink;
  }

  /// デバッグレベルのログ（開発時のみ）
  static void debug(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    final safeMessage = SensitiveLogMasker.maskValue(message);
    final safeError =
        error == null ? null : SensitiveLogMasker.maskValue(error);
    _logger.d(safeMessage, error: safeError, stackTrace: stackTrace);
    _logSinkForTesting?.call(
      'debug',
      safeMessage,
      error: safeError,
      stackTrace: stackTrace,
    );
  }

  /// 情報レベルのログ
  static void info(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    final safeMessage = SensitiveLogMasker.maskValue(message);
    final safeError =
        error == null ? null : SensitiveLogMasker.maskValue(error);
    _logger.i(safeMessage, error: safeError, stackTrace: stackTrace);
    _logSinkForTesting?.call(
      'info',
      safeMessage,
      error: safeError,
      stackTrace: stackTrace,
    );
  }

  /// 警告レベルのログ
  static void warning(
    dynamic message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final safeMessage = SensitiveLogMasker.maskValue(message);
    final safeError =
        error == null ? null : SensitiveLogMasker.maskValue(error);
    _logger.w(safeMessage, error: safeError, stackTrace: stackTrace);
    _logSinkForTesting?.call(
      'warning',
      safeMessage,
      error: safeError,
      stackTrace: stackTrace,
    );
  }

  /// エラーレベルのログ（マスク済み内容を自動でエラー報告EFにも送信）
  static void error(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    final safeMessage = SensitiveLogMasker.maskValue(message);
    final safeError =
        error == null ? null : SensitiveLogMasker.maskValue(error);
    _logger.e(safeMessage, error: safeError, stackTrace: stackTrace);
    _logSinkForTesting?.call(
      'error',
      safeMessage,
      error: safeError,
      stackTrace: stackTrace,
    );
    _errorReporter?.call(
      safeMessage.toString(),
      error: safeError,
      stackTrace: stackTrace,
    );
  }

  /// トレースレベルのログ（詳細なデバッグ用）
  static void trace(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    final safeMessage = SensitiveLogMasker.maskValue(message);
    final safeError =
        error == null ? null : SensitiveLogMasker.maskValue(error);
    _logger.t(safeMessage, error: safeError, stackTrace: stackTrace);
    _logSinkForTesting?.call(
      'trace',
      safeMessage,
      error: safeError,
      stackTrace: stackTrace,
    );
  }
}
