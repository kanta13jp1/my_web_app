import 'package:logger/logger.dart';

/// アプリケーション全体で使用するロガー
///
/// 使用例:
/// ```dart
/// AppLogger.info('情報メッセージ');
/// AppLogger.error('エラーメッセージ', error: e, stackTrace: st);
/// ```
class AppLogger {
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

  /// デバッグレベルのログ（開発時のみ）
  static void debug(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// 情報レベルのログ
  static void info(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// 警告レベルのログ
  static void warning(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// エラーレベルのログ
  static void error(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// トレースレベルのログ（詳細なデバッグ用）
  static void trace(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }
}
