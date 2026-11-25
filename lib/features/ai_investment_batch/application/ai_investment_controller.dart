import 'package:flutter/foundation.dart';

import '../domain/ai_investment_models.dart';

/// Immutable UI state for 2026Q2 AI investment monitoring (#2761).
class AiInvestmentState {
  const AiInvestmentState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.records = const <AiInvestmentRecord>[],
    this.summary = const AiInvestmentSummary.empty(),
    this.selectedRecordId,
    this.statusFilter = 'all',
    this.searchQuery = '',
    this.errorMessage,
    this.noticeMessage,
  });

  final bool isLoading;
  final bool isSubmitting;
  final List<AiInvestmentRecord> records;
  final AiInvestmentSummary summary;
  final String? selectedRecordId;
  final String statusFilter;
  final String searchQuery;
  final String? errorMessage;
  final String? noticeMessage;

  AiInvestmentRecord? get selectedRecord {
    if (records.isEmpty) {
      return null;
    }
    if (selectedRecordId != null) {
      for (final record in records) {
        if (record.id == selectedRecordId) {
          return record;
        }
      }
    }
    return records.first;
  }

  AiInvestmentState copyWith({
    final bool? isLoading,
    final bool? isSubmitting,
    final List<AiInvestmentRecord>? records,
    final AiInvestmentSummary? summary,
    final String? selectedRecordId,
    final bool clearSelected = false,
    final String? statusFilter,
    final String? searchQuery,
    final String? errorMessage,
    final bool clearError = false,
    final String? noticeMessage,
    final bool clearNotice = false,
  }) {
    return AiInvestmentState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      records: records ?? this.records,
      summary: summary ?? this.summary,
      selectedRecordId:
          clearSelected ? null : (selectedRecordId ?? this.selectedRecordId),
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      noticeMessage: clearNotice ? null : (noticeMessage ?? this.noticeMessage),
    );
  }
}

/// Controller coordinating list/detail/ingest/verification flows (#2761).
class AiInvestmentController extends ChangeNotifier {
  AiInvestmentController({
    required final AiInvestmentRepository repository,
    final AiInvestmentState? initialState,
  })  : _repository = repository,
        _state = initialState ?? const AiInvestmentState();

  final AiInvestmentRepository _repository;
  AiInvestmentState _state;
  bool _disposed = false;

  AiInvestmentState get state => _state;

  void _emit(final AiInvestmentState next) {
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

  Future<void> loadRecords({final String? searchQuery}) async {
    final nextQuery = searchQuery ?? _state.searchQuery;
    _emit(
      _state.copyWith(
        isLoading: true,
        searchQuery: nextQuery,
        clearError: true,
      ),
    );
    try {
      final result = await _repository.listRecords(
        verificationStatus:
            _state.statusFilter == 'all' ? null : _state.statusFilter,
        query: nextQuery.trim().isEmpty ? null : nextQuery.trim(),
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

  void selectRecord(final String recordId) {
    _emit(_state.copyWith(selectedRecordId: recordId, clearNotice: true));
  }

  Future<void> setStatusFilter(final String filter) async {
    _emit(_state.copyWith(statusFilter: filter, clearNotice: true));
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
      final result = await _repository.seedDefaults();
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          records: result.records,
          summary: result.summary,
          selectedRecordId:
              result.records.isNotEmpty ? result.records.first.id : null,
          clearSelected: result.records.isEmpty,
          noticeMessage: 'テンプレート項目を読み込みました（初期状態はすべて「要検証」です）。',
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

  Future<bool> ingestRawPayload({
    required final String rawPayload,
    final String? sourceName,
  }) async {
    final trimmed = rawPayload.trim();
    if (trimmed.isEmpty) {
      _emit(
        _state.copyWith(
          errorMessage: '取込データ（JSON または RSS/Atom XML）を入力してください。',
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
      final res = await _repository.ingestPayload(
        rawPayload: trimmed,
        sourceName: sourceName,
      );
      if (_disposed) {
        return false;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          records: res.records,
          summary: res.summary,
          selectedRecordId:
              res.records.isNotEmpty ? res.records.first.id : null,
          clearSelected: res.records.isEmpty,
          noticeMessage:
              '新規 ${res.ingestedCount}件を取込（重複スキップ ${res.skippedDuplicates}件、初期ステータス: 要検証）。',
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

  Future<bool> verifySelected({
    required final InvestmentVerificationStatus decision,
    required final String note,
  }) async {
    final selected = _state.selectedRecord;
    if (selected == null) {
      _emit(_state.copyWith(errorMessage: '検証対象のレコードを選択してください。'));
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
      final result = await _repository.verifyEntry(
        id: selected.id,
        decision: decision,
        verificationNote: note,
      );
      if (_disposed) {
        return false;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          records: result.records,
          summary: result.summary,
          selectedRecordId: selected.id,
          noticeMessage:
              '${selected.companyName} の検証ステータスを「${decision.labelJa}」に更新しました。',
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
}
