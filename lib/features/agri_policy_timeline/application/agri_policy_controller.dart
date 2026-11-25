import 'package:flutter/foundation.dart';

import '../domain/agri_policy_models.dart';

@immutable
class AgriPolicyTimelineState {
  const AgriPolicyTimelineState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.events = const <AgriPolicyEvent>[],
    this.availableTags = kDefaultAgriKeywordTags,
    this.knowledgeEdges = const <AgriKnowledgeEdge>[],
    this.totalCount = 0,
    this.selectedTag,
    this.selectedPhase,
    this.searchQuery = '',
    this.errorMessage,
    this.statusNotice,
  });

  final bool isLoading;
  final bool isSubmitting;
  final List<AgriPolicyEvent> events;
  final List<String> availableTags;
  final List<AgriKnowledgeEdge> knowledgeEdges;
  final int totalCount;
  final String? selectedTag;
  final AgriPolicyPhase? selectedPhase;
  final String searchQuery;
  final String? errorMessage;
  final String? statusNotice;

  AgriPolicyTimelineState copyWith({
    final bool? isLoading,
    final bool? isSubmitting,
    final List<AgriPolicyEvent>? events,
    final List<String>? availableTags,
    final List<AgriKnowledgeEdge>? knowledgeEdges,
    final int? totalCount,
    final String? selectedTag,
    final bool clearSelectedTag = false,
    final AgriPolicyPhase? selectedPhase,
    final bool clearSelectedPhase = false,
    final String? searchQuery,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusNotice,
    final bool clearStatusNotice = false,
  }) {
    return AgriPolicyTimelineState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      events: events ?? this.events,
      availableTags: availableTags ?? this.availableTags,
      knowledgeEdges: knowledgeEdges ?? this.knowledgeEdges,
      totalCount: totalCount ?? this.totalCount,
      selectedTag: clearSelectedTag ? null : (selectedTag ?? this.selectedTag),
      selectedPhase:
          clearSelectedPhase ? null : (selectedPhase ?? this.selectedPhase),
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice:
          clearStatusNotice ? null : (statusNotice ?? this.statusNotice),
    );
  }
}

/// Manages agricultural policy timeline queries, tag filters & fact checks.
class AgriPolicyController extends ChangeNotifier {
  AgriPolicyController({
    required final AgriPolicyRepository repository,
  }) : _repository = repository;

  final AgriPolicyRepository _repository;
  AgriPolicyTimelineState _state = const AgriPolicyTimelineState();
  bool _disposed = false;
  int _loadEpoch = 0;

  AgriPolicyTimelineState get state => _state;

  void _emit(final AgriPolicyTimelineState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> loadTimeline({
    final String? query,
    final String? tag,
    final bool updateTag = false,
    final AgriPolicyPhase? phase,
    final bool updatePhase = false,
    final bool seedIfEmpty = true,
  }) async {
    final nextQuery = query != null ? query.trim() : _state.searchQuery;
    final nextTag = updateTag ? tag : _state.selectedTag;
    final nextPhase = updatePhase ? phase : _state.selectedPhase;
    final epoch = ++_loadEpoch;

    _emit(
      _state.copyWith(
        isLoading: true,
        searchQuery: nextQuery,
        selectedTag: nextTag,
        clearSelectedTag: updateTag && nextTag == null,
        selectedPhase: nextPhase,
        clearSelectedPhase: updatePhase && nextPhase == null,
        clearError: true,
      ),
    );

    try {
      final snapshot = await _repository.fetchTimeline(
        query: nextQuery,
        tag: nextTag,
        phase: nextPhase,
        seedIfEmpty: seedIfEmpty,
      );
      if (_disposed || epoch != _loadEpoch) return;

      _emit(
        _state.copyWith(
          isLoading: false,
          events: snapshot.events,
          availableTags: snapshot.availableTags,
          knowledgeEdges: snapshot.knowledgeEdges,
          totalCount: snapshot.totalCount,
        ),
      );
    } catch (error) {
      if (_disposed || epoch != _loadEpoch) return;
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: '農政タイムラインの読み込みに失敗しました: $error',
        ),
      );
    }
  }

  Future<bool> createEvent({
    required final String eventDate,
    required final String title,
    required final String summary,
    required final String rawTags,
    required final String rawRelatedNodes,
    required final FactCheckStatus factCheckStatus,
    required final String sourceCitation,
    required final String policyImpactNotes,
  }) async {
    final cleanDate = eventDate.trim();
    final cleanTitle = title.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cleanDate)) {
      _emit(
        _state.copyWith(
          errorMessage: '日付は YYYY-MM-DD 形式で入力してください。',
        ),
      );
      return false;
    }
    if (cleanTitle.isEmpty) {
      _emit(
        _state.copyWith(
          errorMessage: '政策イベントのタイトルを入力してください。',
        ),
      );
      return false;
    }

    _emit(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearStatusNotice: true,
      ),
    );

    try {
      final tags = rawTags
          .split(',')
          .map((final String t) => t.trim())
          .where((final String t) => t.isNotEmpty)
          .toList(growable: false);
      final nodes = rawRelatedNodes
          .split(',')
          .map((final String n) => n.trim())
          .where((final String n) => n.isNotEmpty)
          .toList(growable: false);
      final created = await _repository.createEvent(
        eventDate: cleanDate,
        title: cleanTitle,
        summary: summary.trim(),
        tags: tags,
        relatedNodes: nodes,
        factCheckStatus: factCheckStatus,
        sourceCitation: sourceCitation.trim(),
        policyImpactNotes: policyImpactNotes.trim(),
      );
      if (_disposed) return false;
      _emit(
        _state.copyWith(
          isSubmitting: false,
          statusNotice: '政策イベント「${created.title}」を記録しました。',
        ),
      );
      await loadTimeline();
      return true;
    } catch (error) {
      if (_disposed) return false;
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '政策イベントの登録に失敗しました: $error',
        ),
      );
      return false;
    }
  }

  Future<bool> updateFactCheck({
    required final String id,
    required final FactCheckStatus factCheckStatus,
    required final String sourceCitation,
    required final String policyImpactNotes,
  }) async {
    _emit(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearStatusNotice: true,
      ),
    );
    try {
      final updated = await _repository.updateFactCheck(
        id: id,
        factCheckStatus: factCheckStatus,
        sourceCitation: sourceCitation.trim(),
        policyImpactNotes: policyImpactNotes.trim(),
      );
      if (_disposed) return false;
      _emit(
        _state.copyWith(
          isSubmitting: false,
          statusNotice:
              '「${updated.title}」の事実確認ステータスを ${updated.factCheckStatus.labelJa} に更新しました。',
        ),
      );
      await loadTimeline();
      return true;
    } catch (error) {
      if (_disposed) return false;
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '事実確認メタデータの更新に失敗しました: $error',
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
