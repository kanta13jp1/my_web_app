import 'package:flutter/foundation.dart';

import '../domain/rag_query_routing_models.dart';

@immutable
class RagQueryRoutingState {
  const RagQueryRoutingState({
    this.isLoading = false,
    this.autoReport = true,
    this.lastSubmittedQuery = '',
    this.outcome,
    this.pendingClarification,
    this.errorMessage,
    this.history = const <QueryRouteDecision>[],
  });

  final bool isLoading;
  final bool autoReport;
  final String lastSubmittedQuery;
  final QueryRouteOutcome? outcome;
  final QueryRouteDecision? pendingClarification;
  final String? errorMessage;
  final List<QueryRouteDecision> history;

  RagQueryRoutingState copyWith({
    final bool? isLoading,
    final bool? autoReport,
    final String? lastSubmittedQuery,
    final QueryRouteOutcome? outcome,
    final bool clearOutcome = false,
    final QueryRouteDecision? pendingClarification,
    final bool clearPendingClarification = false,
    final String? errorMessage,
    final bool clearError = false,
    final List<QueryRouteDecision>? history,
  }) {
    return RagQueryRoutingState(
      isLoading: isLoading ?? this.isLoading,
      autoReport: autoReport ?? this.autoReport,
      lastSubmittedQuery: lastSubmittedQuery ?? this.lastSubmittedQuery,
      outcome: clearOutcome ? null : (outcome ?? this.outcome),
      pendingClarification: clearPendingClarification
          ? null
          : (pendingClarification ?? this.pendingClarification),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      history: history ?? this.history,
    );
  }
}

/// Manages query report parsing, reformulated auto-search, and unclear halt.
class RagQueryRoutingController extends ChangeNotifier {
  RagQueryRoutingController({
    required final RagQueryRoutingRepository repository,
  }) : _repository = repository;

  final RagQueryRoutingRepository _repository;
  RagQueryRoutingState _state = const RagQueryRoutingState();
  bool _disposed = false;
  int _requestEpoch = 0;

  RagQueryRoutingState get state => _state;

  void _emit(final RagQueryRoutingState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  void setAutoReport({required final bool enabled}) {
    _emit(_state.copyWith(autoReport: enabled));
  }

  void dismissClarification() {
    _emit(_state.copyWith(clearPendingClarification: true));
  }

  /// Executes `memory.query_route`; returns `true` when search completed,
  /// `false` if halted for `unclear` clarification or rejected on error.
  Future<bool> submitQuery({
    required final String query,
    final String? queryReport,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      _emit(
        _state.copyWith(
          errorMessage: '検索クエリを入力してください。',
          clearPendingClarification: true,
        ),
      );
      return false;
    }

    final epoch = ++_requestEpoch;
    _emit(
      _state.copyWith(
        isLoading: true,
        lastSubmittedQuery: trimmedQuery,
        clearError: true,
        clearPendingClarification: true,
      ),
    );

    try {
      final result = await _repository.executeQueryRoute(
        query: trimmedQuery,
        queryReport: queryReport,
        autoReport: _state.autoReport,
      );
      if (_disposed || epoch != _requestEpoch) {
        return false;
      }

      final updatedHistory = <QueryRouteDecision>[
        result.decision,
        ..._state.history,
      ].take(10).toList(growable: false);

      if (result.clarificationRequired) {
        _emit(
          _state.copyWith(
            isLoading: false,
            outcome: result,
            pendingClarification: result.decision,
            history: updatedHistory,
          ),
        );
        return false;
      }

      _emit(
        _state.copyWith(
          isLoading: false,
          outcome: result,
          clearPendingClarification: true,
          history: updatedHistory,
        ),
      );
      return true;
    } catch (error) {
      if (_disposed || epoch != _requestEpoch) {
        return false;
      }
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'クエリルーティングに失敗しました: $error',
          clearPendingClarification: true,
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
