// lib/utils/error_reporter.dart
//
// Flutter エラー → Sentry + submit-feedback EF への自動報告
//
// 仕組み:
//   1. FlutterError.onError   … Flutterフレームワークエラー
//   2. PlatformDispatcher.onError … 未捕捉 Dart ランタイムエラー
//   3. AppLogger.error 経由  … 明示的に記録されたエラー
//   4. SENTRY_DSN dart-define … 本番Sentryプロジェクトへ送信
//
// 保護策:
//   - ログイン済みユーザーのみ送信
//   - セッション内で同一エラー（先頭120文字）は重複送信しない
//   - セッション内の最大送信数: 10件
//   - 報告中の再帰ループを防ぐフラグ

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SentryCaptureCallback = FutureOr<void> Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

typedef SupabaseTelemetryCallback = FutureOr<void> Function(
  Map<String, Object?> payload,
);

class ErrorReporterDiagnosticSnapshot {
  const ErrorReporterDiagnosticSnapshot({
    required this.sentryEnabled,
    required this.handlersInstalled,
    required this.reportedCount,
    required this.suppressedDuplicateCount,
    required this.suppressedThrottleCount,
    required this.uniqueFingerprints,
    required this.platform,
  });

  final bool sentryEnabled;
  final bool handlersInstalled;
  final int reportedCount;
  final int suppressedDuplicateCount;
  final int suppressedThrottleCount;
  final int uniqueFingerprints;
  final String platform;
}

class ErrorReporter {
  ErrorReporter._();
  static final ErrorReporter instance = ErrorReporter._();

  static const int _maxPerSession = 10;
  static const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const String _sentryEnvironment =
      String.fromEnvironment('SENTRY_ENVIRONMENT');
  static const String _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');
  static const bool _sentryDebug = bool.fromEnvironment('SENTRY_DEBUG');
  static const int _sentryTracesSampleRatePercent = int.fromEnvironment(
    'SENTRY_TRACES_SAMPLE_RATE_PERCENT',
  );

  final Set<String> _seen = {};
  int _count = 0;
  int _suppressedDuplicateCount = 0;
  int _suppressedThrottleCount = 0;
  bool _isReporting = false;
  bool _handlersInstalled = false;
  bool _sentryEnabled = false;
  SentryCaptureCallback? _testSentrySink;
  SupabaseTelemetryCallback? _testSupabaseSink;
  bool _testAuthenticatedOverride = false;

  // ignore: unused_field
  FlutterExceptionHandler? _previousFlutterHandler;
  ErrorCallback? _previousPlatformHandler;
  StreamSubscription<dynamic>? _authSubscription;

  bool get sentryEnabled => _sentryEnabled;

  ErrorReporterDiagnosticSnapshot diagnosticSnapshot() {
    return ErrorReporterDiagnosticSnapshot(
      sentryEnabled: _sentryEnabled,
      handlersInstalled: _handlersInstalled,
      reportedCount: _count,
      suppressedDuplicateCount: _suppressedDuplicateCount,
      suppressedThrottleCount: _suppressedThrottleCount,
      uniqueFingerprints: _seen.length,
      platform: kIsWeb ? 'web' : 'vm',
    );
  }

  @visibleForTesting
  void setTestSinks({
    SentryCaptureCallback? sentrySink,
    SupabaseTelemetryCallback? supabaseSink,
    bool sentryEnabled = false,
    bool authenticated = false,
  }) {
    _testSentrySink = sentrySink;
    _testSupabaseSink = supabaseSink;
    _sentryEnabled = sentryEnabled;
    _testAuthenticatedOverride = authenticated;
  }

  @visibleForTesting
  void resetForTesting() {
    _seen.clear();
    _count = 0;
    _suppressedDuplicateCount = 0;
    _suppressedThrottleCount = 0;
    _isReporting = false;
    _sentryEnabled = false;
    _testSentrySink = null;
    _testSupabaseSink = null;
    _testAuthenticatedOverride = false;
  }

  static String sanitizeMessage(String raw) {
    var sanitized = raw;
    sanitized = sanitized.replaceAll(
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
      '[REDACTED_EMAIL]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._-]+', caseSensitive: false),
      'Bearer [REDACTED]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(
        r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9._-]{8,}(?:\.[A-Za-z0-9._-]+)?',
      ),
      '[REDACTED_JWT]',
    );
    return sanitized;
  }

  static Map<String, Object?> buildTelemetryPayload({
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final rawFull = error != null ? '$message: $error' : message;
    final cleanMessage = sanitizeMessage(rawFull);
    final stackLines = stackTrace == null
        ? ''
        : sanitizeMessage(stackTrace.toString().split('\n').take(6).join('\n'));
    final content = '[自動エラー報告]\n'
        '$cleanMessage'
        '${stackLines.isNotEmpty ? '\n\n$stackLines' : ''}';
    return <String, Object?>{
      'action': 'feedback.submit',
      'category': 'bug',
      // 自動エラー報告は公開 GitHub Issue 化せず hub_data 記録のみに留める
      // (core-hub feedback.submit が source を見て Issue 化を抑止)。
      'source': 'auto_error_report',
      'message': content.substring(0, min(2000, content.length)),
    };
  }

  bool get _hasSentryDsn => isValidSentryDsn(_sentryDsn);

  @visibleForTesting
  static SentryUser buildSentryUser(String userId) {
    return SentryUser(id: userId);
  }

  static bool isValidSentryDsn(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    if (uri.host.isEmpty || uri.userInfo.isEmpty) return false;
    return uri.pathSegments.any((segment) => segment.isNotEmpty);
  }

  SupabaseClient? get _supabaseOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// `main()` の Supabase.initialize() 直後に呼ぶ。
  /// SENTRY_DSN が設定されていれば、Sentry の zone 内で appRunner を実行する。
  Future<void> install({
    required FutureOr<void> Function() appRunner,
  }) async {
    if (_handlersInstalled) {
      await appRunner();
      return;
    }

    var appRunnerStarted = false;
    Future<void> guardedAppRunner() async {
      appRunnerStarted = true;
      _sentryEnabled = true;
      _watchAuthChanges();
      _syncSentryUser();
      _installFlutterHandlers();
      await appRunner();
    }

    if (_hasSentryDsn) {
      try {
        await SentryFlutter.init(
          _configureSentry,
          appRunner: guardedAppRunner,
        );
        return;
      } catch (error) {
        _sentryEnabled = false;
        debugPrint('Sentry initialization failed: $error');
      }
    }

    if (!appRunnerStarted) {
      _installFlutterHandlers();
      await appRunner();
    }
  }

  void _configureSentry(SentryFlutterOptions options) {
    final environment = _sentryEnvironment.trim().isNotEmpty
        ? _sentryEnvironment.trim()
        : (kReleaseMode ? 'production' : 'development');
    final tracesSampleRatePercent =
        _sentryTracesSampleRatePercent.clamp(0, 100).toDouble();

    options
      ..dsn = _sentryDsn.trim()
      ..environment = environment
      ..debug = _sentryDebug
      ..sendDefaultPii = false;

    if (_sentryRelease.trim().isNotEmpty) {
      options.release = _sentryRelease.trim();
    }
    if (tracesSampleRatePercent > 0) {
      options.tracesSampleRate = tracesSampleRatePercent / 100;
    }
  }

  void _installFlutterHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;

    _previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_isIgnorableFlutterWebFocusTraversalLayoutError(
        details.exceptionAsString(),
        details.stack,
      )) {
        return;
      }
      if (_isIgnorableFlutterWebInkHoverError(
        details.exceptionAsString(),
        details.stack,
        details: details,
      )) {
        return;
      }
      _syncSentryUser();
      _previousFlutterHandler?.call(details);
      report(
        details.exceptionAsString(),
        stackTrace: details.stack,
        captureSentry: false,
      );
    };

    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (_isIgnorableFlutterWebFocusTraversalLayoutError(
        error.toString(),
        stack,
      )) {
        return true;
      }
      if (_isIgnorableFlutterWebInkHoverError(error.toString(), stack)) {
        return true;
      }
      _syncSentryUser();
      _previousPlatformHandler?.call(error, stack);
      report(
        error.toString(),
        error: error,
        stackTrace: stack,
        captureSentry: _previousPlatformHandler == null,
      );
      return false; // 既存のクラッシュハンドラを妨げない
    };
  }

  bool _isIgnorableFlutterWebInkHoverError(
    String message,
    StackTrace? stackTrace, {
    FlutterErrorDetails? details,
  }) {
    if (!kIsWeb) return false;
    if (!message.contains('Null check operator used on a null value')) {
      return false;
    }

    final stack = stackTrace?.toString() ?? '';
    final context = details?.context?.toDescription() ?? '';
    final library = details?.library ?? '';

    // Flutter Web can dispatch a delayed hover/focus callback to an
    // InkResponse after its Element has already been unmounted. In release,
    // dart2js minifies the same framework path; keep the signatures narrow.
    final hasReleaseInkStack = (stack.contains('.auU') &&
            stack.contains('.uT') &&
            stack.contains('.cgd')) ||
        (stack.contains('.avQ') &&
            stack.contains('.v_') &&
            stack.contains('.chZ')) ||
        (stack.contains('.gO') &&
            stack.contains('.gnc') &&
            stack.contains('.ge2') &&
            stack.contains('.aEM') &&
            stack.contains('.aTV') &&
            stack.contains('.asE'));

    return stack.contains('_InkResponseState') ||
        stack.contains('InkResponse') ||
        stack.contains('MouseTracker') ||
        context.contains('MouseTracker') ||
        context.contains('mouse') ||
        hasReleaseInkStack && (details == null || library.contains('widgets'));
  }

  @visibleForTesting
  bool isIgnorableFlutterWebFocusTraversalLayoutErrorForTesting(
    String message,
    StackTrace? stackTrace,
  ) {
    return _isIgnorableFlutterWebFocusTraversalLayoutError(
      message,
      stackTrace,
      isWebOverride: true,
    );
  }

  // Flutter Web can trigger focus traversal before every candidate RenderBox
  // has completed layout. The framework path is minified in release builds, so
  // match the traversal shape instead of one exact symbol suffix.
  bool _isIgnorableFlutterWebFocusTraversalLayoutError(
    String message,
    StackTrace? stackTrace, {
    bool? isWebOverride,
  }) {
    if (!(isWebOverride ?? kIsWeb)) return false;
    if (!message.contains('RenderBox was not laid out')) return false;

    final stack = stackTrace?.toString() ?? '';
    final hasDebugFocusTraversalStack =
        stack.contains('FocusTraversalPolicy') ||
            stack.contains('FocusTraversalGroup');
    final hasReleaseFocusTraversalStackV1 = stack.contains('.gN') &&
        stack.contains('.gn') &&
        stack.contains('.ge') &&
        stack.contains('Object.e') &&
        stack.contains('Object.dy') &&
        stack.contains('.ak');
    final hasReleaseFocusTraversalStackV2 = stack.contains('.gn') &&
        stack.contains('.ge') &&
        stack.contains('Object.e') &&
        stack.contains('Object.d') &&
        (stack.contains('.aF') || stack.contains('.aG')) &&
        (stack.contains('.aU') || stack.contains('.aV')) &&
        stack.contains('.at');

    return hasDebugFocusTraversalStack ||
        hasReleaseFocusTraversalStackV1 ||
        hasReleaseFocusTraversalStackV2;
  }

  /// AppLogger.error から呼ばれる (caught errors)
  void report(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool captureSentry = true,
  }) {
    if (_isReporting) return;
    _isReporting = true;
    try {
      _scheduleReport(
        message,
        error: error,
        stackTrace: stackTrace,
        captureSentry: captureSentry,
      );
    } finally {
      _isReporting = false;
    }
  }

  void _scheduleReport(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool captureSentry = true,
  }) {
    // エラーフィンガープリント（最初の120文字）
    final rawFull = error != null ? '$message: $error' : message;
    final fullMessage = sanitizeMessage(rawFull);
    final fingerprint = fullMessage.substring(0, min(120, fullMessage.length));
    if (_seen.contains(fingerprint)) {
      _suppressedDuplicateCount++;
      return;
    }
    _seen.add(fingerprint);

    if (captureSentry) {
      _captureSentryException(
        fullMessage,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final payload = buildTelemetryPayload(
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    if (_testSupabaseSink != null) {
      if (!_testAuthenticatedOverride) return;
      if (_count >= _maxPerSession) {
        _suppressedThrottleCount++;
        return;
      }
      _count++;
      try {
        _testSupabaseSink!(payload);
      } catch (_) {
        // 報告失敗は無視（無限ループ防止）
      }
      return;
    }

    // ログイン確認
    final supabase = _supabaseOrNull;
    if (supabase == null) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    // スロットリング
    if (_count >= _maxPerSession) {
      _suppressedThrottleCount++;
      return;
    }
    _count++;

    // 非同期で静かに送信
    Future.microtask(() async {
      try {
        await supabase.functions.invoke(
          'core-hub',
          body: payload,
        );
      } catch (_) {
        // 報告失敗は無視（無限ループ防止）
      }
    });
  }

  void _captureSentryException(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_sentryEnabled) return;

    if (_testSentrySink != null) {
      try {
        _testSentrySink!(
          message,
          error: error,
          stackTrace: stackTrace,
        );
      } catch (_) {
        // 報告失敗は無視
      }
      return;
    }

    _syncSentryUser();
    unawaited(
      Sentry.captureException(
        error ?? message,
        stackTrace: stackTrace,
        withScope: (scope) async {
          await scope.setTag('error_reporter.source', 'app_logger');
          await scope.setContexts('error_reporter', {'message': message});
        },
      ),
    );
  }

  void _watchAuthChanges() {
    final supabase = _supabaseOrNull;
    if (supabase == null) return;

    _authSubscription ??= supabase.auth.onAuthStateChange.listen((_) {
      _syncSentryUser();
    });
  }

  void _syncSentryUser() {
    if (!_sentryEnabled) return;

    final supabase = _supabaseOrNull;
    final user = supabase?.auth.currentUser;
    unawaited(
      Future<void>.sync(
        () => Sentry.configureScope((scope) async {
          await scope.setTag(
            'supabase.auth',
            user == null ? 'anonymous' : 'authenticated',
          );
          if (user == null) {
            await scope.setUser(null);
            return;
          }
          await scope.setUser(buildSentryUser(user.id));
        }),
      ),
    );
  }
}
