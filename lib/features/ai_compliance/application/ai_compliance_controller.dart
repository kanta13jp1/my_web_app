import 'package:flutter/foundation.dart';

import '../domain/ai_compliance_models.dart';

/// Immutable UI state for AI model compliance & security verification (#2763).
class AiComplianceState {
  const AiComplianceState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.records = const <AiComplianceRecord>[],
    this.summary = const AiComplianceSummary.empty(),
    this.selectedRecordId,
    this.statusFilter = 'all',
    this.lastGuardResult,
    this.errorMessage,
    this.noticeMessage,
  });

  final bool isLoading;
  final bool isSubmitting;
  final List<AiComplianceRecord> records;
  final AiComplianceSummary summary;
  final String? selectedRecordId;
  final String statusFilter;
  final AiComplianceGuardResult? lastGuardResult;
  final String? errorMessage;
  final String? noticeMessage;

  AiComplianceRecord? get selectedRecord {
    if (records.isEmpty) {
      return null;
    }
    if (selectedRecordId != null) {
      for (final rec in records) {
        if (rec.id == selectedRecordId) {
          return rec;
        }
      }
    }
    return records.first;
  }

  AiComplianceState copyWith({
    final bool? isLoading,
    final bool? isSubmitting,
    final List<AiComplianceRecord>? records,
    final AiComplianceSummary? summary,
    final String? selectedRecordId,
    final bool clearSelected = false,
    final String? statusFilter,
    final AiComplianceGuardResult? lastGuardResult,
    final bool clearGuard = false,
    final String? errorMessage,
    final bool clearError = false,
    final String? noticeMessage,
    final bool clearNotice = false,
  }) {
    return AiComplianceState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      records: records ?? this.records,
      summary: summary ?? this.summary,
      selectedRecordId:
          clearSelected ? null : (selectedRecordId ?? this.selectedRecordId),
      statusFilter: statusFilter ?? this.statusFilter,
      lastGuardResult:
          clearGuard ? null : (lastGuardResult ?? this.lastGuardResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      noticeMessage: clearNotice ? null : (noticeMessage ?? this.noticeMessage),
    );
  }
}

/// Controller coordinating compliance review, human approval, and API guard.
class AiComplianceController extends ChangeNotifier {
  AiComplianceController({
    required final AiComplianceRepository repository,
    final AiComplianceState? initialState,
  })  : _repository = repository,
        _state = initialState ?? const AiComplianceState();

  final AiComplianceRepository _repository;
  AiComplianceState _state;
  bool _disposed = false;

  AiComplianceState get state => _state;

  void _emit(final AiComplianceState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadRecords() async {
    _emit(
      _state.copyWith(
        isLoading: true,
        clearError: true,
      ),
    );
    try {
      final result = await _repository.listRecords(
        statusFilter: _state.statusFilter == 'all' ? null : _state.statusFilter,
      );
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isLoading: false,
          records: result.records,
          summary: result.summary,
          selectedRecordId: result.records.isEmpty
              ? null
              : (_state.selectedRecordId ?? result.records.first.id),
          clearSelected: result.records.isEmpty,
        ),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void selectRecord(final String id) {
    _emit(
      _state.copyWith(
        selectedRecordId: id,
        clearGuard: true,
        clearNotice: true,
      ),
    );
  }

  Future<void> setStatusFilter(final String filter) async {
    _emit(_state.copyWith(statusFilter: filter, clearGuard: true));
    await loadRecords();
  }

  Future<void> seedDefaults() async {
    _emit(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final res = await _repository.seedDefaults();
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          records: res.records,
          summary: res.summary,
          selectedRecordId:
              res.records.isNotEmpty ? res.records.first.id : null,
          clearSelected: res.records.isEmpty,
          noticeMessage: '評価対象候補を登録しました（「承認済」になるまでAPI呼び出しはシステムで遮断されます）。',
        ),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<bool> submitReviewRequest({
    required final String providerKey,
    required final String modelId,
    required final String providerName,
    final String? termsUrl,
    final String? reviewNotes,
  }) async {
    if (providerKey.trim().isEmpty || modelId.trim().isEmpty) {
      _emit(
        _state.copyWith(
          errorMessage: 'プロバイダーキーとモデルIDの両方を入力してください。',
        ),
      );
      return false;
    }
    _emit(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearNotice: true,
        clearGuard: true,
      ),
    );
    try {
      final res = await _repository.submitReview(
        providerKey: providerKey,
        modelId: modelId,
        providerName:
            providerName.trim().isEmpty ? providerKey.trim() : providerName,
        termsUrl: termsUrl,
        reviewNotes: reviewNotes,
      );
      if (_disposed) {
        return false;
      }
      final created = res.highlightedRecord;
      final issueLabel = created?.githubIssueNumber != null
          ? '（GitHub確認タスク #${created!.githubIssueNumber} 起票済み）'
          : '（ステータス: 検証中 / GitHub連携状態: ${created?.issueDispatchStatus ?? 'none'}）';
      _emit(
        _state.copyWith(
          isSubmitting: false,
          records: res.records,
          summary: res.summary,
          selectedRecordId: created?.id ??
              (res.records.isNotEmpty ? res.records.first.id : null),
          noticeMessage: '検証リクエストを起票しました$issueLabel',
        ),
      );
      return true;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
      return false;
    }
  }

  Future<void> updateChecklistFlag({
    required final String recordId,
    required final ComplianceChecklistState nextChecklist,
  }) async {
    _emit(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearNotice: true,
        clearGuard: true,
      ),
    );
    try {
      final res = await _repository.updateChecklist(
        id: recordId,
        checklist: nextChecklist,
      );
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          records: res.records,
          summary: res.summary,
          selectedRecordId: recordId,
          noticeMessage: '確認チェックリストを更新しました。',
        ),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<bool> approveSelected({
    required final String reviewerName,
    required final bool humanConfirmed,
    final String? approvalNote,
  }) async {
    final selected = _state.selectedRecord;
    if (selected == null) {
      _emit(_state.copyWith(errorMessage: '承認対象のモデルを選択してください。'));
      return false;
    }
    if (!humanConfirmed) {
      _emit(
        _state.copyWith(
          errorMessage: 'システムでの自動承認は禁止されています。人間の担当者確認チェックを入れてください。',
        ),
      );
      return false;
    }
    if (reviewerName.trim().isEmpty) {
      _emit(_state.copyWith(errorMessage: '承認担当者名を入力してください。'));
      return false;
    }
    if (!selected.checklist.allComplete) {
      _emit(
        _state.copyWith(
          errorMessage: 'セキュリティ基準・利用規約の全4項目のチェックを完了してから承認してください。',
        ),
      );
      return false;
    }

    _emit(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final res = await _repository.approveEntry(
        id: selected.id,
        reviewerName: reviewerName,
        humanConfirmed: humanConfirmed,
        approvalNote: approvalNote,
      );
      if (_disposed) {
        return false;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          records: res.records,
          summary: res.summary,
          selectedRecordId: selected.id,
          noticeMessage:
              '${selected.providerName} (${selected.modelId}) を担当者 $reviewerName により「承認済」へ確定しました。',
        ),
      );
      return true;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
      return false;
    }
  }

  Future<void> testInvokeGuard() async {
    final selected = _state.selectedRecord;
    if (selected == null) {
      _emit(_state.copyWith(errorMessage: 'API呼出ガード検証対象を選択してください。'));
      return;
    }
    _emit(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearGuard: true,
      ),
    );
    try {
      final guard = await _repository.checkInvokeGuard(id: selected.id);
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          lastGuardResult: guard,
        ),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
