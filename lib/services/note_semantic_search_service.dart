import 'package:supabase_flutter/supabase_flutter.dart';

typedef NoteSemanticSearchInvoker = Future<Object?> Function(
  Map<String, dynamic> body,
);

abstract interface class NoteSemanticSearchDataSource {
  Future<NoteSemanticSearchResponse> search(String query, {int limit = 20});

  Future<List<NoteSearchResult>> relatedNotes({
    required String noteId,
    required String title,
    required String content,
    int limit = 5,
  });

  Future<void> indexNote(String noteId);
}

class NoteSemanticSearchService implements NoteSemanticSearchDataSource {
  NoteSemanticSearchService(SupabaseClient client)
      : _invoke = ((body) async {
          final response = await client.functions.invoke('ai-hub', body: body);
          return response.data;
        });

  const NoteSemanticSearchService.withInvoker(this._invoke);

  final NoteSemanticSearchInvoker _invoke;

  @override
  Future<NoteSemanticSearchResponse> search(
    String query, {
    int limit = 20,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const NoteSemanticSearchResponse(
        results: <NoteSearchResult>[],
        searchMode: 'empty',
      );
    }

    final data = await _invoke(<String, dynamic>{
      'action': 'search.query',
      'query': normalizedQuery,
      'limit': limit.clamp(1, 30),
    });
    return NoteSemanticSearchResponse.fromJson(_asMap(data));
  }

  @override
  Future<List<NoteSearchResult>> relatedNotes({
    required String noteId,
    required String title,
    required String content,
    int limit = 5,
  }) async {
    final seed = <String>[
      title.trim(),
      content.trim(),
    ].where((part) => part.isNotEmpty).join('\n');
    if (seed.isEmpty) return const <NoteSearchResult>[];

    final query = seed.length <= 1200 ? seed : seed.substring(0, 1200);
    final response = await search(query, limit: (limit + 5).clamp(1, 30));
    final seen = <String>{noteId};
    final related = <NoteSearchResult>[];
    for (final result in response.results) {
      if (!seen.add(result.id)) continue;
      related.add(result);
      if (related.length >= limit.clamp(1, 5)) break;
    }
    return related;
  }

  @override
  Future<void> indexNote(String noteId) async {
    final data = await _invoke(<String, dynamic>{
      'action': 'search.index_note',
      'note_id': noteId,
    });
    final payload = _asMap(data);
    if (payload['success'] != true) {
      throw StateError(
        payload['error']?.toString() ?? 'Note indexing did not complete.',
      );
    }
  }
}

class NoteSemanticSearchResponse {
  const NoteSemanticSearchResponse({
    required this.results,
    required this.searchMode,
    this.explanation,
  });

  factory NoteSemanticSearchResponse.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    final results = rawResults is List
        ? rawResults
            .whereType<Map>()
            .map(
              (item) =>
                  NoteSearchResult.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false)
        : const <NoteSearchResult>[];
    return NoteSemanticSearchResponse(
      results: results,
      searchMode: json['searchMode']?.toString() ?? 'text_fallback',
      explanation: json['explanation']?.toString(),
    );
  }

  final List<NoteSearchResult> results;
  final String searchMode;
  final String? explanation;
}

class NoteSearchResult {
  const NoteSearchResult({
    required this.id,
    required this.title,
    required this.content,
    required this.score,
    required this.matchReason,
    this.createdAt,
    this.updatedAt,
    this.isPinned,
    this.isFavorite,
    this.reminderDate,
  });

  factory NoteSearchResult.fromJson(Map<String, dynamic> json) {
    final rawScore = json['search_score'];
    return NoteSearchResult(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      score: rawScore is num ? rawScore.toDouble() : 0,
      matchReason: json['match_reason']?.toString() ?? 'text',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      isPinned: json['is_pinned'] as bool?,
      isFavorite: json['is_favorite'] as bool?,
      reminderDate: json['reminder_date']?.toString(),
    );
  }

  final String id;
  final String title;
  final String content;
  final double score;
  final String matchReason;
  final String? createdAt;
  final String? updatedAt;
  final bool? isPinned;
  final bool? isFavorite;
  final String? reminderDate;

  Map<String, dynamic> toNoteRow({Map<String, dynamic>? localNote}) {
    return <String, dynamic>{
      ...?localNote,
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt ?? localNote?['created_at'] ?? updatedAt,
      'is_pinned': isPinned ?? localNote?['is_pinned'] ?? false,
      'is_favorite': isFavorite ?? localNote?['is_favorite'] ?? false,
      'reminder_date': reminderDate ?? localNote?['reminder_date'],
    };
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('The note search response was not an object.');
}
