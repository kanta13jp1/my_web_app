import 'package:flutter/foundation.dart';

import '../data/supabase_synthetic_media_audit_repository.dart';
import '../domain/synthetic_media_audit_models.dart';

/// 合成メディア監査画面のイミュータブル状態 (#2661).
@immutable
class SyntheticMediaAuditState {
  const SyntheticMediaAuditState({
    required this.videos,
    required this.auditLogs,
    required this.isAdmin,
    required this.selectedFilter,
    required this.isLoading,
    required this.isSubmitting,
    this.errorMessage,
  });

  factory SyntheticMediaAuditState.initial() {
    return const SyntheticMediaAuditState(
      videos: <SyntheticMediaVideo>[],
      auditLogs: <SyntheticMediaAuditLogEntry>[],
      isAdmin: false,
      selectedFilter: SyntheticMediaModerationStatus.pending,
      isLoading: false,
      isSubmitting: false,
    );
  }

  final List<SyntheticMediaVideo> videos;
  final List<SyntheticMediaAuditLogEntry> auditLogs;
  final bool isAdmin;
  final SyntheticMediaModerationStatus selectedFilter;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;

  /// 一般ユーザー向け公開フィード（承認済み動画のみ・未承認/却下は絶対に含めない）。
  List<SyntheticMediaVideo> get approvedFeedVideos => videos
      .where(
        (final SyntheticMediaVideo v) =>
            v.isApproved &&
            v.moderationStatus == SyntheticMediaModerationStatus.approved,
      )
      .toList(growable: false);

  /// 管理者向けモデレーションキュー（選択ステータス別）。
  List<SyntheticMediaVideo> get filteredModerationVideos => videos
      .where(
        (final SyntheticMediaVideo v) => v.moderationStatus == selectedFilter,
      )
      .toList(growable: false);

  int countByStatus(final SyntheticMediaModerationStatus status) => videos
      .where((final SyntheticMediaVideo v) => v.moderationStatus == status)
      .length;

  SyntheticMediaAuditState copyWith({
    final List<SyntheticMediaVideo>? videos,
    final List<SyntheticMediaAuditLogEntry>? auditLogs,
    final bool? isAdmin,
    final SyntheticMediaModerationStatus? selectedFilter,
    final bool? isLoading,
    final bool? isSubmitting,
    final String? errorMessage,
    final bool clearError = false,
  }) {
    return SyntheticMediaAuditState(
      videos: videos ?? this.videos,
      auditLogs: auditLogs ?? this.auditLogs,
      isAdmin: isAdmin ?? this.isAdmin,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// 合成メディア動画の倫理監査・承認キュー管理 Controller (#2661).
class SyntheticMediaAuditController extends ChangeNotifier {
  SyntheticMediaAuditController({
    required final SyntheticMediaAuditRepository repository,
  }) : _repository = repository;

  final SyntheticMediaAuditRepository _repository;
  SyntheticMediaAuditState _state = SyntheticMediaAuditState.initial();
  bool _isDisposed = false;

  SyntheticMediaAuditState get state => _state;
  bool get isDisposed => _isDisposed;

  void _setState(final SyntheticMediaAuditState next) {
    if (_isDisposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  /// 動画一覧・管理者権限・監査履歴を取得する。
  Future<void> loadDashboard() async {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final bool admin = await _repository.fetchIsAdmin();
      if (_isDisposed) {
        return;
      }
      final List<SyntheticMediaVideo> videos = await _repository.fetchVideos();
      if (_isDisposed) {
        return;
      }
      final List<SyntheticMediaAuditLogEntry> logs = admin
          ? await _repository.fetchAuditLogs()
          : const <SyntheticMediaAuditLogEntry>[];
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          videos: List<SyntheticMediaVideo>.unmodifiable(videos),
          auditLogs: List<SyntheticMediaAuditLogEntry>.unmodifiable(logs),
          isAdmin: admin,
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
          errorMessage: '合成メディア監査データの取得に失敗しました: $error',
        ),
      );
    }
  }

  /// 審査ステータスフィルタを切り替える（古いエラーもクリア）。
  void selectStatusFilter(final SyntheticMediaModerationStatus filter) {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(selectedFilter: filter, clearError: true));
  }

  /// 新規合成メディア動画を承認待ち (`pending`) として提出する。
  Future<bool> submitVideo(final SubmitSyntheticMediaInput input) async {
    if (_isDisposed || _state.isSubmitting) {
      return false;
    }
    final String? validationError = input.validate();
    if (validationError != null) {
      _setState(_state.copyWith(errorMessage: validationError));
      return false;
    }

    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final SyntheticMediaVideo created = await _repository.submitVideo(input);
      if (_isDisposed) {
        return false;
      }
      final List<SyntheticMediaVideo> updated = <SyntheticMediaVideo>[
        created,
        ..._state.videos
            .where((final SyntheticMediaVideo v) => v.id != created.id),
      ];
      _setState(
        _state.copyWith(
          videos: List<SyntheticMediaVideo>.unmodifiable(updated),
          isSubmitting: false,
          clearError: true,
        ),
      );
      return true;
    } catch (error) {
      if (_isDisposed) {
        return false;
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '合成メディア動画の登録に失敗しました: $error',
        ),
      );
      return false;
    }
  }

  /// 管理者による承認 / 却下を実行する（倫理要件・却下理由を事前検証）。
  Future<bool> reviewVideo({
    required final SyntheticMediaVideo target,
    required final SyntheticMediaModerationStatus decision,
    final String? reviewNote,
  }) async {
    if (_isDisposed || _state.isSubmitting) {
      return false;
    }
    if (!_state.isAdmin) {
      _setState(
        _state.copyWith(errorMessage: 'モデレーション操作には管理者権限が必要です。'),
      );
      return false;
    }
    if (decision == SyntheticMediaModerationStatus.approved &&
        !target.meetsApprovalPrerequisites) {
      _setState(
        _state.copyWith(
          errorMessage:
              '承認できません（不足: ${target.missingApprovalRequirements.join('、')}）。',
        ),
      );
      return false;
    }
    if (decision == SyntheticMediaModerationStatus.rejected &&
        (reviewNote == null || reviewNote.trim().isEmpty)) {
      _setState(
        _state.copyWith(errorMessage: '却下する場合は理由ノートの入力が必須です。'),
      );
      return false;
    }

    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final SyntheticMediaVideo updated = await _repository.reviewVideo(
        videoId: target.id,
        decision: decision,
        reviewNote: reviewNote,
      );
      if (_isDisposed) {
        return false;
      }
      final List<SyntheticMediaVideo> nextVideos = _state.videos
          .map(
            (final SyntheticMediaVideo item) =>
                item.id == updated.id ? updated : item,
          )
          .toList(growable: false);
      final List<SyntheticMediaAuditLogEntry> nextLogs =
          await _repository.fetchAuditLogs();
      if (_isDisposed) {
        return false;
      }
      _setState(
        _state.copyWith(
          videos: List<SyntheticMediaVideo>.unmodifiable(nextVideos),
          auditLogs: List<SyntheticMediaAuditLogEntry>.unmodifiable(nextLogs),
          isSubmitting: false,
          clearError: true,
        ),
      );
      return true;
    } catch (error) {
      if (_isDisposed) {
        return false;
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '審査決定の反映に失敗しました: $error',
        ),
      );
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
