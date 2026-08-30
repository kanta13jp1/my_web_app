import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

enum NoteShortcutTargetType {
  note,
  notebook,
  stack,
  tag,
  savedSearch;

  String get databaseValue => switch (this) {
        NoteShortcutTargetType.note => 'note',
        NoteShortcutTargetType.notebook => 'notebook',
        NoteShortcutTargetType.stack => 'stack',
        NoteShortcutTargetType.tag => 'tag',
        NoteShortcutTargetType.savedSearch => 'saved_search',
      };

  String get label => switch (this) {
        NoteShortcutTargetType.note => 'ノート',
        NoteShortcutTargetType.notebook => 'ノートブック',
        NoteShortcutTargetType.stack => 'スタック',
        NoteShortcutTargetType.tag => 'タグ',
        NoteShortcutTargetType.savedSearch => '保存済み検索',
      };

  static NoteShortcutTargetType fromDatabase(String value) => switch (value) {
        'note' => NoteShortcutTargetType.note,
        'notebook' => NoteShortcutTargetType.notebook,
        'stack' => NoteShortcutTargetType.stack,
        'tag' => NoteShortcutTargetType.tag,
        'saved_search' => NoteShortcutTargetType.savedSearch,
        _ => throw FormatException('Unsupported shortcut target: $value'),
      };
}

class NoteSavedSearch {
  const NoteSavedSearch({
    required this.id,
    required this.name,
    required this.query,
    required this.sourceSystem,
    this.sourceKey,
    this.verifiedAt,
  });

  final String id;
  final String name;
  final String query;
  final String sourceSystem;
  final String? sourceKey;
  final DateTime? verifiedAt;

  bool get isImported => sourceSystem == 'evernote';

  factory NoteSavedSearch.fromJson(Map<String, dynamic> json) {
    return NoteSavedSearch(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      query: json['query']?.toString() ?? '',
      sourceSystem: json['source_system']?.toString() ?? 'native',
      sourceKey: _emptyToNull(json['source_key']),
      verifiedAt: _asDateTime(json['verified_at']),
    );
  }
}

class NoteShortcut {
  const NoteShortcut({
    required this.id,
    required this.position,
    required this.targetType,
    required this.label,
    required this.sourceSystem,
    this.targetNoteId,
    this.targetCollectionId,
    this.targetTag,
    this.targetSavedSearchId,
    this.sourceTargetKey,
    this.sourceKey,
    this.verifiedAt,
  });

  final String id;
  final int position;
  final NoteShortcutTargetType targetType;
  final String label;
  final String sourceSystem;
  final int? targetNoteId;
  final int? targetCollectionId;
  final String? targetTag;
  final String? targetSavedSearchId;
  final String? sourceTargetKey;
  final String? sourceKey;
  final DateTime? verifiedAt;

  bool get isImported => sourceSystem == 'evernote';

  bool get isResolved => switch (targetType) {
        NoteShortcutTargetType.note => targetNoteId != null,
        NoteShortcutTargetType.notebook ||
        NoteShortcutTargetType.stack =>
          targetCollectionId != null,
        NoteShortcutTargetType.tag => targetTag != null,
        NoteShortcutTargetType.savedSearch => targetSavedSearchId != null,
      };

  factory NoteShortcut.fromJson(Map<String, dynamic> json) {
    return NoteShortcut(
      id: json['id']?.toString() ?? '',
      position: _asInt(json['position']),
      targetType: NoteShortcutTargetType.fromDatabase(
        json['target_type']?.toString() ?? '',
      ),
      label: json['target_label']?.toString() ?? '',
      sourceSystem: json['source_system']?.toString() ?? 'native',
      targetNoteId: _asOptionalInt(json['target_note_id']),
      targetCollectionId: _asOptionalInt(json['target_collection_id']),
      targetTag: _emptyToNull(json['target_tag']),
      targetSavedSearchId: _emptyToNull(json['target_saved_search_id']),
      sourceTargetKey: _emptyToNull(json['source_target_key']),
      sourceKey: _emptyToNull(json['source_key']),
      verifiedAt: _asDateTime(json['verified_at']),
    );
  }
}

class EvernoteNavigationMigrationState {
  const EvernoteNavigationMigrationState({
    required this.status,
    required this.savedSearchCount,
    required this.verifiedSavedSearchCount,
    required this.shortcutCount,
    required this.verifiedShortcutCount,
    this.sourceSnapshotSha256,
    this.verifiedAt,
  });

  final String status;
  final int savedSearchCount;
  final int verifiedSavedSearchCount;
  final int shortcutCount;
  final int verifiedShortcutCount;
  final String? sourceSnapshotSha256;
  final DateTime? verifiedAt;

  bool get isVerified => status == 'verified' || status == 'source_deleted';

  factory EvernoteNavigationMigrationState.fromJson(
    Map<String, dynamic> json,
  ) {
    return EvernoteNavigationMigrationState(
      status: json['status']?.toString() ?? 'pending',
      savedSearchCount: _asInt(json['source_saved_search_count']),
      verifiedSavedSearchCount:
          _asInt(json['verified_saved_search_count']),
      shortcutCount: _asInt(json['source_shortcut_count']),
      verifiedShortcutCount: _asInt(json['verified_shortcut_count']),
      sourceSnapshotSha256:
          _emptyToNull(json['source_snapshot_sha256']),
      verifiedAt: _asDateTime(json['verified_at']),
    );
  }
}

class NoteNavigationSnapshot {
  const NoteNavigationSnapshot({
    required this.savedSearches,
    required this.shortcuts,
    this.migrationState,
  });

  final List<NoteSavedSearch> savedSearches;
  final List<NoteShortcut> shortcuts;
  final EvernoteNavigationMigrationState? migrationState;
}

class NoteShortcutDraft {
  const NoteShortcutDraft({
    required this.targetType,
    required this.label,
    this.targetNoteId,
    this.targetCollectionId,
    this.targetTag,
    this.targetSavedSearchId,
  });

  final NoteShortcutTargetType targetType;
  final String label;
  final int? targetNoteId;
  final int? targetCollectionId;
  final String? targetTag;
  final String? targetSavedSearchId;
}

abstract class NoteNavigationRepository {
  Future<NoteNavigationSnapshot> load();

  Future<void> createSavedSearch({
    required String name,
    required String query,
  });

  Future<void> updateSavedSearch({
    required NoteSavedSearch savedSearch,
    required String name,
    required String query,
  });

  Future<void> deleteSavedSearch(NoteSavedSearch savedSearch);

  Future<void> createShortcut(NoteShortcutDraft draft);

  Future<void> moveShortcut({
    required NoteShortcut shortcut,
    required int position,
  });

  Future<void> deleteShortcut(NoteShortcut shortcut);

  Future<EvernoteNavigationMigrationState> importEvernoteInventory(
    String manifestJson,
  );

  Future<EvernoteNavigationMigrationState> verifyEvernoteInventory();
}

class SupabaseNoteNavigationRepository implements NoteNavigationRepository {
  SupabaseNoteNavigationRepository(this._client);

  final SupabaseClient _client;

  static const _savedSearchColumns =
      'id,user_id,name,query,source_system,source_key,verified_at,'
      'created_at,updated_at';
  static const _shortcutColumns =
      'id,user_id,position,target_type,target_note_id,target_collection_id,'
      'target_tag,target_saved_search_id,target_label,source_target_key,'
      'source_system,source_key,verified_at,created_at,updated_at';
  static const _migrationColumns =
      'user_id,status,source_snapshot_sha256,source_saved_search_count,'
      'verified_saved_search_count,source_shortcut_count,'
      'verified_shortcut_count,verified_at';

  @override
  Future<NoteNavigationSnapshot> load() async {
    final results = await Future.wait<dynamic>([
      _loadPagedRows(
        table: 'note_saved_searches',
        columns: _savedSearchColumns,
        orderColumn: 'updated_at',
        ascending: false,
      ),
      _loadPagedRows(
        table: 'note_shortcuts',
        columns: _shortcutColumns,
        orderColumn: 'position',
      ),
      _client
          .from('evernote_navigation_migrations')
          .select(_migrationColumns)
          .maybeSingle(),
    ]);
    final searches = (results[0] as List<Map<String, dynamic>>)
        .map(NoteSavedSearch.fromJson)
        .toList(growable: false);
    final shortcuts = (results[1] as List<Map<String, dynamic>>)
        .map(NoteShortcut.fromJson)
        .toList(growable: false);
    final stateRow = results[2] as Map<String, dynamic>?;
    return NoteNavigationSnapshot(
      savedSearches: searches,
      shortcuts: shortcuts,
      migrationState: stateRow == null
          ? null
          : EvernoteNavigationMigrationState.fromJson(stateRow),
    );
  }

  Future<List<Map<String, dynamic>>> _loadPagedRows({
    required String table,
    required String columns,
    required String orderColumn,
    bool ascending = true,
  }) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += pageSize) {
      final page = List<Map<String, dynamic>>.from(
        await _client
            .from(table)
            .select(columns)
            .order(orderColumn, ascending: ascending)
            .order('id')
            .range(offset, offset + pageSize - 1),
      );
      rows.addAll(page);
      if (page.length < pageSize) break;
    }
    return rows;
  }

  @override
  Future<void> createSavedSearch({
    required String name,
    required String query,
  }) async {
    final userId = _requireUserId();
    await _client.from('note_saved_searches').insert(<String, dynamic>{
      'user_id': userId,
      'name': _validatedText(name, field: '名前', maximum: 200),
      'query': _validatedText(query, field: '検索条件', maximum: 4096),
      'source_system': 'native',
    });
  }

  @override
  Future<void> updateSavedSearch({
    required NoteSavedSearch savedSearch,
    required String name,
    required String query,
  }) async {
    await _client
        .from('note_saved_searches')
        .update(<String, dynamic>{
          'name': _validatedText(name, field: '名前', maximum: 200),
          'query': _validatedText(query, field: '検索条件', maximum: 4096),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', savedSearch.id);
  }

  @override
  Future<void> deleteSavedSearch(NoteSavedSearch savedSearch) async {
    await _client.from('note_saved_searches').delete().eq('id', savedSearch.id);
  }

  @override
  Future<void> createShortcut(NoteShortcutDraft draft) async {
    final userId = _requireUserId();
    final snapshot = await load();
    final position = snapshot.shortcuts.fold<int>(
          0,
          (maximum, shortcut) =>
              shortcut.position > maximum ? shortcut.position : maximum,
        ) +
        1;
    await _client.from('note_shortcuts').insert(<String, dynamic>{
      'user_id': userId,
      'position': position,
      'target_type': draft.targetType.databaseValue,
      'target_note_id': draft.targetNoteId,
      'target_collection_id': draft.targetCollectionId,
      'target_tag': _nullableTrimmed(draft.targetTag),
      'target_saved_search_id': draft.targetSavedSearchId,
      'target_label':
          _validatedText(draft.label, field: '表示名', maximum: 200),
      'source_system': 'native',
    });
  }

  @override
  Future<void> moveShortcut({
    required NoteShortcut shortcut,
    required int position,
  }) async {
    await _client.rpc(
      'note_shortcut_move',
      params: <String, dynamic>{
        'p_shortcut_id': shortcut.id,
        'p_new_position': position,
      },
    );
  }

  @override
  Future<void> deleteShortcut(NoteShortcut shortcut) async {
    await _client.from('note_shortcuts').delete().eq('id', shortcut.id);
  }

  @override
  Future<EvernoteNavigationMigrationState> importEvernoteInventory(
    String manifestJson,
  ) async {
    final decoded = jsonDecode(manifestJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('棚卸しJSONのルートはobjectである必要があります。');
    }
    final savedSearches = decoded['saved_searches'];
    final shortcuts = decoded['shortcuts'];
    if (savedSearches is! List || shortcuts is! List) {
      throw const FormatException(
        'saved_searchesとshortcutsは配列で指定してください。',
      );
    }
    await _client.rpc(
      'evernote_commit_navigation_inventory',
      params: <String, dynamic>{
        'p_saved_searches': savedSearches,
        'p_shortcuts': shortcuts,
      },
    );
    return _reloadMigrationState();
  }

  @override
  Future<EvernoteNavigationMigrationState> verifyEvernoteInventory() async {
    await _client.rpc(
      'evernote_verify_navigation_inventory',
      params: <String, dynamic>{
        'p_verification_checks': <String, bool>{
          'saved_search_count': true,
          'saved_search_queries': true,
          'shortcut_count': true,
          'shortcut_order': true,
          'shortcut_targets': true,
        },
      },
    );
    return _reloadMigrationState();
  }

  Future<EvernoteNavigationMigrationState> _reloadMigrationState() async {
    final row = await _client
        .from('evernote_navigation_migrations')
        .select(_migrationColumns)
        .single();
    return EvernoteNavigationMigrationState.fromJson(row);
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('ログインが必要です。');
    }
    return userId;
  }
}

String _validatedText(
  String value, {
  required String field,
  required int maximum,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > maximum) {
    throw FormatException('$fieldは1〜$maximum文字で入力してください。');
  }
  return trimmed;
}

String? _nullableTrimmed(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _emptyToNull(dynamic value) => _nullableTrimmed(value?.toString());

int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

int? _asOptionalInt(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  return parsed == null || parsed <= 0 ? null : parsed;
}

DateTime? _asDateTime(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '');
