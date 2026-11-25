import 'package:flutter/foundation.dart';

import '../domain/dev_review_models.dart';

@immutable
class DevReviewTrackingState {
  const DevReviewTrackingState({
    required this.sessions,
    required this.statusFilter,
    required this.assigneeFilter,
    required this.isLoading,
    required this.isSubmitting,
    this.errorMessage,
    this.statusNotice,
    this.blockedReasons = const <String>[],
  });

  factory DevReviewTrackingState.initial() => const DevReviewTrackingState(
        sessions: <DevReviewSession>[],
        statusFilter: 'all',
        assigneeFilter: '',
        isLoading: false,
        isSubmitting: false,
      );

  final List<DevReviewSession> sessions;
  final String statusFilter;
  final String assigneeFilter;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? statusNotice;
  final List<String> blockedReasons;

  DevReviewTrackingState copyWith({
    List<DevReviewSession>? sessions,
    String? statusFilter,
    String? assigneeFilter,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? statusNotice,
    bool clearNotice = false,
    List<String>? blockedReasons,
  }) {
    return DevReviewTrackingState(
      sessions: sessions ?? this.sessions,
      statusFilter: statusFilter ?? this.statusFilter,
      assigneeFilter: assigneeFilter ?? this.assigneeFilter,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice: clearNotice ? null : (statusNotice ?? this.statusNotice),
      blockedReasons: blockedReasons ?? this.blockedReasons,
    );
  }
}

class DevReviewTrackingController extends ChangeNotifier {
  DevReviewTrackingController({
    required DevReviewTrackingRepository repository,
  }) : _repository = repository;

  final DevReviewTrackingRepository _repository;
  DevReviewTrackingState _state = DevReviewTrackingState.initial();
  bool _disposed = false;

  DevReviewTrackingState get state => _state;

  void _setState(DevReviewTrackingState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  Future<void> loadSessions({
    String? statusFilter,
    String? assigneeFilter,
  }) async {
    if (_disposed || _state.isLoading) {
      return;
    }
    final nextStatus = statusFilter ?? _state.statusFilter;
    final nextAssignee = assigneeFilter ?? _state.assigneeFilter;
    _setState(
      _state.copyWith(
        statusFilter: nextStatus,
        assigneeFilter: nextAssignee,
        isLoading: true,
        clearError: true,
      ),
    );
    try {
      final loaded = await _repository.listSessions(
        statusFilter: nextStatus,
        assigneeFilter: nextAssignee,
      );
      if (_disposed) {
        return;
      }
      _setState(
        _state.copyWith(
          sessions: loaded,
          isLoading: false,
        ),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'レビュー一覧の取得に失敗しました: $error',
        ),
      );
    }
  }

  Future<bool> createSession({
    required String title,
    required String targetType,
    required String githubRepo,
    required int targetNumber,
    required String approver,
    required String assignee,
  }) async {
    if (_disposed || _state.isSubmitting) {
      return false;
    }
    if (title.trim().isEmpty ||
        githubRepo.trim().isEmpty ||
        targetNumber <= 0) {
      _setState(
        _state.copyWith(errorMessage: 'タイトル・GitHub リポジトリ・番号を入力してください。'),
      );
      return false;
    }
    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        blockedReasons: const <String>[],
      ),
    );
    try {
      final created = await _repository.createSession(
        title: title,
        targetType: targetType,
        githubRepo: githubRepo,
        targetNumber: targetNumber,
        approver: approver,
        assignee: assignee,
      );
      if (_disposed) {
        return false;
      }
      final refreshed = await _repository.listSessions(
        statusFilter: _state.statusFilter,
        assigneeFilter: _state.assigneeFilter,
      );
      if (_disposed) {
        return false;
      }
      _setState(
        _state.copyWith(
          sessions: refreshed,
          isSubmitting: false,
          statusNotice: '「${created.title}」のチェックリストとテスト観点を生成しました。',
        ),
      );
      return true;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'レビューセッションの作成に失敗しました: $error',
        ),
      );
      return false;
    }
  }

  Future<void> updateItemStatus({
    required String sessionId,
    required String itemId,
    required DevReviewItemStatus status,
    required String assignee,
    String note = '',
  }) async {
    if (_disposed || _state.isSubmitting) {
      return;
    }
    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        blockedReasons: const <String>[],
      ),
    );
    try {
      await _repository.updateItemStatus(
        sessionId: sessionId,
        itemId: itemId,
        status: status,
        assignee: assignee,
        note: note,
      );
      if (_disposed) {
        return;
      }
      final refreshed = await _repository.listSessions(
        statusFilter: _state.statusFilter,
        assigneeFilter: _state.assigneeFilter,
      );
      if (_disposed) {
        return;
      }
      _setState(
        _state.copyWith(
          sessions: refreshed,
          isSubmitting: false,
          statusNotice: '対応ステータスを「${status.labelJa}」へ更新しました。',
        ),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'ステータス更新に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> syncGithub({
    required String sessionId,
    required String state,
    required String reviewDecision,
    bool fetchLive = false,
  }) async {
    if (_disposed || _state.isSubmitting) {
      return;
    }
    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _repository.syncGithubStatus(
        sessionId: sessionId,
        state: state,
        reviewDecision: reviewDecision,
        fetchLive: fetchLive,
      );
      if (_disposed) {
        return;
      }
      final refreshed = await _repository.listSessions(
        statusFilter: _state.statusFilter,
        assigneeFilter: _state.assigneeFilter,
      );
      if (_disposed) {
        return;
      }
      _setState(
        _state.copyWith(
          sessions: refreshed,
          isSubmitting: false,
          statusNotice: 'GitHub ステータスを同期しました。',
        ),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'GitHub 同期に失敗しました: $error',
        ),
      );
    }
  }

  Future<bool> advancePhase({
    required DevReviewSession session,
    String note = '',
  }) async {
    if (_disposed || _state.isSubmitting) {
      return false;
    }
    final nextPhase = session.currentPhase.nextPhase;
    if (nextPhase == null) {
      _setState(_state.copyWith(statusNotice: 'すでに最終公開フェーズです。'));
      return false;
    }

    final localBlocked = session.blockingReasonsForNextPhase();
    if (localBlocked.isNotEmpty) {
      _setState(
        _state.copyWith(
          blockedReasons: localBlocked,
          errorMessage: 'すべての項目が承認されるまで次フェーズ (${nextPhase.labelJa}) へ移行できません。',
        ),
      );
      return false;
    }

    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        blockedReasons: const <String>[],
      ),
    );
    try {
      final outcome = await _repository.advancePhase(
        sessionId: session.id,
        targetPhase: nextPhase,
        note: note,
      );
      if (_disposed) {
        return false;
      }
      if (outcome.blocked) {
        _setState(
          _state.copyWith(
            isSubmitting: false,
            blockedReasons: outcome.blockingReasons,
            errorMessage: '承認ゲートによりフェーズ移行がブロックされました。',
          ),
        );
        return false;
      }
      final refreshed = await _repository.listSessions(
        statusFilter: _state.statusFilter,
        assigneeFilter: _state.assigneeFilter,
      );
      if (_disposed) {
        return false;
      }
      _setState(
        _state.copyWith(
          sessions: refreshed,
          isSubmitting: false,
          blockedReasons: const <String>[],
          statusNotice: 'フェーズを「${nextPhase.labelJa}」へ移行しました。',
        ),
      );
      return true;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'フェーズ移行処理に失敗しました: $error',
        ),
      );
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
