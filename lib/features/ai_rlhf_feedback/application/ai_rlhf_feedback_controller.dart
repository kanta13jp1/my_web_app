import 'package:flutter/foundation.dart';

import '../domain/ai_rlhf_feedback_models.dart';

/// RLHF フィードバック送信および GitHub Issue 起票追跡状態 (#2659).
@immutable
class AiRlhfFeedbackState {
  const AiRlhfFeedbackState({
    required this.entries,
    required this.selectedRating,
    required this.isLoading,
    required this.isSubmitting,
    this.errorMessage,
    this.statusNotice,
  });

  factory AiRlhfFeedbackState.initial() => const AiRlhfFeedbackState(
        entries: <AiRlhfFeedbackEntry>[],
        selectedRating: RlhfRatingStatus.bad,
        isLoading: false,
        isSubmitting: false,
      );

  final List<AiRlhfFeedbackEntry> entries;
  final RlhfRatingStatus selectedRating;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? statusNotice;

  int get badFeedbackCount =>
      entries.where((item) => item.ratingStatus.triggersGitHubIssue).length;

  int get dispatchedIssueCount => entries
      .where((item) => item.dispatchStatus == RlhfDispatchStatus.dispatched)
      .length;

  AiRlhfFeedbackState copyWith({
    List<AiRlhfFeedbackEntry>? entries,
    RlhfRatingStatus? selectedRating,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? statusNotice,
    bool clearNotice = false,
  }) {
    return AiRlhfFeedbackState(
      entries: entries ?? this.entries,
      selectedRating: selectedRating ?? this.selectedRating,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice: clearNotice ? null : (statusNotice ?? this.statusNotice),
    );
  }
}

/// RLHF フィードバックの登録・自動 Webhook 連携を制御する Controller (#2659).
class AiRlhfFeedbackController extends ChangeNotifier {
  AiRlhfFeedbackController({required AiRlhfFeedbackRepository repository})
      : _repository = repository,
        _state = AiRlhfFeedbackState.initial();

  final AiRlhfFeedbackRepository _repository;
  AiRlhfFeedbackState _state;
  bool _isDisposed = false;

  AiRlhfFeedbackState get state => _state;
  bool get isDisposed => _isDisposed;

  void _setState(AiRlhfFeedbackState next) {
    if (_isDisposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  void selectRating(RlhfRatingStatus rating) {
    if (_isDisposed || rating == _state.selectedRating) {
      return;
    }
    _setState(_state.copyWith(selectedRating: rating, clearError: true));
  }

  Future<void> loadFeedback() async {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final rows = await _repository.fetchRecentFeedback();
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          entries: rows,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'RLHF フィードバック履歴の読み込みに失敗しました: $error',
        ),
      );
    }
  }

  Future<void> submitFeedback({
    required String actionName,
    required String modelId,
    required String promptText,
    required String aiOutput,
    required String userComment,
    bool autoDispatchWebhook = true,
  }) async {
    if (_isDisposed || _state.isSubmitting) {
      return;
    }
    final cleanAction = actionName.trim();
    final cleanPrompt = promptText.trim();
    final cleanOutput = aiOutput.trim();
    if (cleanAction.isEmpty || cleanPrompt.isEmpty || cleanOutput.isEmpty) {
      _setState(
        _state.copyWith(
          errorMessage: 'アクション名・プロンプト・AI 出力はいずれも必須です。',
          clearNotice: true,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      var saved = await _repository.submitFeedback(
        AiRlhfFeedbackDraft(
          actionName: cleanAction,
          modelId: modelId.trim().isEmpty ? 'gemini-2.5-flash' : modelId.trim(),
          promptText: cleanPrompt,
          aiOutput: cleanOutput,
          ratingStatus: _state.selectedRating,
          userComment: userComment.trim(),
        ),
      );
      if (_isDisposed) {
        return;
      }

      var notice = '問題なしとして RLHF 履歴に記録しました。';
      if (saved.ratingStatus.triggersGitHubIssue && autoDispatchWebhook) {
        final dispatchResult = await _repository.triggerWebhookDispatch(
          feedbackId: saved.id,
        );
        if (_isDisposed) {
          return;
        }
        if (dispatchResult.issueNumber != null) {
          saved = saved.copyWith(
            dispatchStatus: RlhfDispatchStatus.dispatched,
            githubIssueNumber: dispatchResult.issueNumber,
            githubIssueUrl: dispatchResult.issueUrl,
            webhookDispatchedAt: DateTime.now().toUtc(),
          );
          notice =
              'GitHub Issue #${dispatchResult.issueNumber} (AI-Feedback) を起票しました。';
        } else {
          notice = 'Webhook 連携キューに登録しました。';
        }
      } else if (saved.ratingStatus.triggersGitHubIssue) {
        notice = 'Database Webhook による GitHub Issue 起票キューへ登録しました。';
      }

      final nextEntries = <AiRlhfFeedbackEntry>[
        saved,
        ..._state.entries.where((item) => item.id != saved.id),
      ];
      _setState(
        _state.copyWith(
          entries: List<AiRlhfFeedbackEntry>.unmodifiable(nextEntries),
          isSubmitting: false,
          clearError: true,
          statusNotice: notice,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'RLHF フィードバックの送信に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> dispatchPendingIssue({
    required String feedbackId,
    bool dryRun = false,
  }) async {
    if (_isDisposed || _state.isSubmitting) {
      return;
    }
    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final result = await _repository.triggerWebhookDispatch(
        feedbackId: feedbackId,
        dryRun: dryRun,
      );
      if (_isDisposed) {
        return;
      }
      final updated = _state.entries.map((entry) {
        if (entry.id != feedbackId) {
          return entry;
        }
        if (result.issueNumber != null) {
          return entry.copyWith(
            dispatchStatus: RlhfDispatchStatus.dispatched,
            githubIssueNumber: result.issueNumber,
            githubIssueUrl: result.issueUrl,
            webhookDispatchedAt: DateTime.now().toUtc(),
          );
        }
        return entry;
      }).toList(growable: false);

      final notice = result.dryRun
          ? 'ドライラン検証完了: AI-Feedback Issue 下書きを生成しました。'
          : (result.issueNumber != null
              ? 'GitHub Issue #${result.issueNumber} を関連付けました。'
              : '評価区分の確認が完了しました。');

      _setState(
        _state.copyWith(
          entries: updated,
          isSubmitting: false,
          clearError: true,
          statusNotice: notice,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'Webhook 再送に失敗しました: $error',
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
