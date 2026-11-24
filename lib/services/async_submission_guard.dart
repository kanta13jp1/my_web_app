import 'package:flutter/foundation.dart';

/// 非同期送信の進行状態。
enum AsyncSubmissionPhase {
  idle,
  submitting,
  succeeded,
  failed,
}

/// 非同期送信の実行結果種別。
enum AsyncSubmissionOutcomeStatus {
  succeeded,
  failed,
  ignored,
}

/// 送信ガード付きの非同期処理結果。
@immutable
class AsyncSubmissionOutcome<T> {
  const AsyncSubmissionOutcome._({
    required this.status,
    this.data,
    this.message,
  });

  const AsyncSubmissionOutcome.succeeded({T? data, String? message})
      : this._(
          status: AsyncSubmissionOutcomeStatus.succeeded,
          data: data,
          message: message,
        );

  const AsyncSubmissionOutcome.failed({required String message})
      : this._(
          status: AsyncSubmissionOutcomeStatus.failed,
          message: message,
        );

  const AsyncSubmissionOutcome.ignored()
      : this._(
          status: AsyncSubmissionOutcomeStatus.ignored,
          message: '送信処理が進行中のため重複送信をブロックしました。',
        );

  final AsyncSubmissionOutcomeStatus status;
  final T? data;
  final String? message;

  bool get isSucceeded => status == AsyncSubmissionOutcomeStatus.succeeded;
  bool get isFailed => status == AsyncSubmissionOutcomeStatus.failed;
  bool get isIgnored => status == AsyncSubmissionOutcomeStatus.ignored;
}

/// 非同期通信待機中の重複送信を同期ロックで防止し、UI状態・フィードバックを管理するガード (#2726)。
class AsyncSubmissionGuard extends ChangeNotifier {
  AsyncSubmissionPhase _phase = AsyncSubmissionPhase.idle;
  String? _errorMessage;
  String? _successMessage;
  int _ignoredDuplicateAttempts = 0;

  AsyncSubmissionPhase get phase => _phase;
  bool get isSubmitting => _phase == AsyncSubmissionPhase.submitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  int get ignoredDuplicateAttempts => _ignoredDuplicateAttempts;

  static String defaultErrorFormatter(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length).trim();
    }
    return text.isNotEmpty ? text : '通信エラーが発生しました。時間をおいて再度お試しください。';
  }

  /// [action] を排他実行する。既に実行中なら即座に `ignored` を返す。
  Future<AsyncSubmissionOutcome<T>> run<T>({
    required Future<T> Function() action,
    String? successMessage,
    String Function(Object error)? errorFormatter,
  }) async {
    if (_phase == AsyncSubmissionPhase.submitting) {
      _ignoredDuplicateAttempts += 1;
      notifyListeners();
      return const AsyncSubmissionOutcome.ignored();
    }

    _phase = AsyncSubmissionPhase.submitting;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final result = await action();
      _phase = AsyncSubmissionPhase.succeeded;
      _successMessage = successMessage;
      notifyListeners();
      return AsyncSubmissionOutcome<T>.succeeded(
        data: result,
        message: successMessage,
      );
    } catch (e) {
      final formatted = (errorFormatter ?? defaultErrorFormatter)(e);
      _phase = AsyncSubmissionPhase.failed;
      _errorMessage = formatted;
      notifyListeners();
      return AsyncSubmissionOutcome<T>.failed(message: formatted);
    }
  }

  void reset() {
    if (_phase == AsyncSubmissionPhase.submitting) {
      return;
    }
    _phase = AsyncSubmissionPhase.idle;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
