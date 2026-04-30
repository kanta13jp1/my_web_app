import 'package:logger/logger.dart';

typedef AppLoggerErrorReporter = void Function(
  String message, {
  dynamic error,
  StackTrace? stackTrace,
});

/// アプリケーション全体で使用するロガー
///
/// 使用例:
/// ```dart
/// AppLogger.info('情報メッセージ');
/// AppLogger.error('エラーメッセージ', error: e, stackTrace: st);
/// ```
class AppLogger {
  static AppLoggerErrorReporter? _errorReporter;

  static final Logger _logger = Logger(
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

  /// デバッグレベルのログ（開発時のみ）
  static void debug(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// 情報レベルのログ
  static void info(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// 警告レベルのログ
  static void warning(
    dynamic message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// エラーレベルのログ（自動でエラー報告EFにも送信）
  static void error(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _errorReporter?.call(
      message.toString(),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// トレースレベルのログ（詳細なデバッグ用）
  static void trace(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }
}
