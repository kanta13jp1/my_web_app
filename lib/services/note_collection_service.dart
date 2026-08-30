import 'package:supabase_flutter/supabase_flutter.dart';

enum NoteCollectionType {
  space,
  stack,
  notebook;

  String get databaseValue => name;

  String get label => switch (this) {
        NoteCollectionType.space => 'Space',
        NoteCollectionType.stack => 'スタック',
        NoteCollectionType.notebook => 'ノートブック',
      };

  static NoteCollectionType fromDatabase(String value) => switch (value) {
        'space' => NoteCollectionType.space,
        'stack' => NoteCollectionType.stack,
        'notebook' => NoteCollectionType.notebook,
        _ => throw FormatException('Unsupported note collection type: $value'),
      };
}

class NoteCollectionRecord {
  const NoteCollectionRecord({
    required this.id,
    required this.type,
    required this.name,
    required this.sourceSystem,
    required this.noteCount,
    required this.sortOrder,
    required this.isDefault,
    required this.isPinned,
    this.parentId,
    this.description = '',
  });

  final int id;
  final int? parentId;
  final NoteCollectionType type;
  final String name;
  final String description;
  final String sourceSystem;
  final int noteCount;
  final int sortOrder;
  final bool isDefault;
  final bool isPinned;

  bool get isImported => sourceSystem == 'evernote';

  factory NoteCollectionRecord.fromJson(
    Map<String, dynamic> json, {
    required int noteCount,
  }) {
    final id = int.tryParse(json['id']?.toString() ?? '');
    if (id == null) {
      throw StateError('Collection id is missing.');
    }
    return NoteCollectionRecord(
      id: id,
      parentId: int.tryParse(json['parent_id']?.toString() ?? ''),
      type: NoteCollectionType.fromDatabase(
        json['collection_type']?.toString() ?? '',
      ),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sourceSystem: json['source_system']?.toString() ?? 'native',
      noteCount: noteCount,
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
      isDefault: json['is_default'] == true,
      isPinned: json['is_pinned'] == true,
    );
  }
}

class NoteCollectionSnapshot {
  const NoteCollectionSnapshot({
    required this.collections,
    required this.evernoteSourceDeleted,
  });

  final List<NoteCollectionRecord> collections;
  final bool evernoteSourceDeleted;

  Map<int?, List<NoteCollectionRecord>> get collectionsByParent {
    final result = <int?, List<NoteCollectionRecord>>{};
    for (final collection in collections) {
      result
          .putIfAbsent(collection.parentId, () => <NoteCollectionRecord>[])
          .add(collection);
    }
    for (final children in result.values) {
      children.sort(compareCollections);
    }
    return result;
  }

  static int compareCollections(
    NoteCollectionRecord left,
    NoteCollectionRecord right,
  ) {
    if (left.isPinned != right.isPinned) return left.isPinned ? -1 : 1;
    final order = left.sortOrder.compareTo(right.sortOrder);
    if (order != 0) return order;
    final type = left.type.index.compareTo(right.type.index);
    if (type != 0) return type;
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  bool isLocked(NoteCollectionRecord collection) =>
      collection.isImported && !evernoteSourceDeleted;

  Set<int> descendantIds(int rootId) {
    final children = collectionsByParent;
    final result = <int>{};
    final pending = <int>[rootId];
    while (pending.isNotEmpty) {
      final parentId = pending.removeLast();
      for (final child in children[parentId] ?? const <NoteCollectionRecord>[]) {
        if (result.add(child.id)) pending.add(child.id);
      }
    }
    return result;
  }

  List<NoteCollectionRecord> validParentsFor(
    NoteCollectionRecord collection,
  ) {
    if (collection.type != NoteCollectionType.notebook) {
      return const <NoteCollectionRecord>[];
    }
    final excluded = <int>{collection.id, ...descendantIds(collection.id)};
    return collections
        .where(
          (candidate) =>
              !excluded.contains(candidate.id) &&
              (candidate.type == NoteCollectionType.space ||
                  candidate.type == NoteCollectionType.stack),
        )
        .toList(growable: false)
      ..sort(compareCollections);
  }
}

abstract class NoteCollectionDataSource {
  Future<NoteCollectionSnapshot> load();

  Future<void> createCollection({
    required NoteCollectionType type,
    required String name,
    int? parentId,
    String description,
  });

  Future<void> updateCollection({
    required int id,
    required String name,
    required String description,
  });

  Future<void> moveCollection({required int id, int? parentId});

  Future<void> setDefaultNotebook(int id);

  Future<void> setPinned({required int id, required bool pinned});

  Future<void> setSortOrder({required int id, required int sortOrder});

  Future<void> deleteCollection(int id);
}

class SupabaseNoteCollectionDataSource implements NoteCollectionDataSource {
  SupabaseNoteCollectionDataSource(this._client);

  static const int _pageSize = 500;
  static const String _collectionColumns =
      'id,parent_id,collection_type,name,description,source_system,'
      'sort_order,is_default,is_pinned';

  final SupabaseClient _client;

  @override
  Future<NoteCollectionSnapshot> load() async {
    final userId = _requireUserId();
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _fetchPaged(
        table: 'note_collections',
        columns: _collectionColumns,
        userId: userId,
      ),
      _fetchPaged(
        table: 'notes',
        columns: 'id,notebook_collection_id',
        userId: userId,
        activeNotesOnly: true,
      ),
      _fetchPaged(
        table: 'evernote_migration_items',
        columns: 'status',
        userId: userId,
      ),
    ]);

    final parentById = <int, int?>{};
    for (final row in results[0]) {
      final id = int.tryParse(row['id']?.toString() ?? '');
      if (id != null) {
        parentById[id] =
            int.tryParse(row['parent_id']?.toString() ?? '');
      }
    }
    final noteCounts = <int, int>{};
    for (final row in results[1]) {
      var collectionId =
          int.tryParse(row['notebook_collection_id']?.toString() ?? '');
      final visited = <int>{};
      while (collectionId != null && visited.add(collectionId)) {
        noteCounts.update(
          collectionId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        collectionId = parentById[collectionId];
      }
    }
    final collections = results[0]
        .map(
          (row) => NoteCollectionRecord.fromJson(
            row,
            noteCount:
                noteCounts[int.tryParse(row['id']?.toString() ?? '')] ?? 0,
          ),
        )
        .toList(growable: false);
    final hasImported =
        collections.any((collection) => collection.isImported);
    final statuses = results[2]
        .map((row) => row['status']?.toString() ?? '')
        .toList(growable: false);
    final sourceDeleted = hasImported &&
        statuses.isNotEmpty &&
        statuses.every((status) => status == 'source_deleted');

    return NoteCollectionSnapshot(
      collections: List<NoteCollectionRecord>.unmodifiable(collections),
      evernoteSourceDeleted: sourceDeleted,
    );
  }

  @override
  Future<void> createCollection({
    required NoteCollectionType type,
    required String name,
    int? parentId,
    String description = '',
  }) async {
    if (type != NoteCollectionType.notebook && parentId != null) {
      throw ArgumentError('Spaces and stacks are root collections.');
    }
    final userId = _requireUserId();
    await _client.from('note_collections').insert(<String, dynamic>{
      'user_id': userId,
      'collection_type': type.databaseValue,
      'parent_id': parentId,
      'name': _validName(name),
      'description': _validDescription(description),
      'source_system': 'native',
    });
  }

  @override
  Future<void> updateCollection({
    required int id,
    required String name,
    required String description,
  }) async {
    final userId = _requireUserId();
    await _client.from('note_collections').update(<String, dynamic>{
      'name': _validName(name),
      'description': _validDescription(description),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('user_id', userId);
  }

  @override
  Future<void> moveCollection({required int id, int? parentId}) async {
    if (id == parentId) {
      throw ArgumentError('A collection cannot be its own parent.');
    }
    final userId = _requireUserId();
    await _client.from('note_collections').update(<String, dynamic>{
      'parent_id': parentId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('user_id', userId);
  }

  @override
  Future<void> setDefaultNotebook(int id) async {
    await _client.rpc(
      'set_default_note_collection',
      params: <String, dynamic>{'p_collection_id': id},
    );
  }

  @override
  Future<void> setPinned({required int id, required bool pinned}) async {
    final userId = _requireUserId();
    await _client.from('note_collections').update(<String, dynamic>{
      'is_pinned': pinned,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('user_id', userId);
  }

  @override
  Future<void> setSortOrder({
    required int id,
    required int sortOrder,
  }) async {
    if (sortOrder < 0) throw ArgumentError('Sort order cannot be negative.');
    final userId = _requireUserId();
    await _client.from('note_collections').update(<String, dynamic>{
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('user_id', userId);
  }

  @override
  Future<void> deleteCollection(int id) async {
    await _client.rpc(
      'delete_note_collection',
      params: <String, dynamic>{'p_collection_id': id},
    );
  }

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.trim().isEmpty) {
      throw StateError('Sign in before managing note collections.');
    }
    return id;
  }

  String _validName(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.length > 200) {
      throw ArgumentError('Names must contain 1 to 200 characters.');
    }
    return value;
  }

  String _validDescription(String raw) {
    final value = raw.trim();
    if (value.length > 2000) {
      throw ArgumentError('Descriptions cannot exceed 2000 characters.');
    }
    return value;
  }

  Future<List<Map<String, dynamic>>> _fetchPaged({
    required String table,
    required String columns,
    required String userId,
    bool activeNotesOnly = false,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (var from = 0;; from += _pageSize) {
      final List<Map<String, dynamic>> page;
      if (activeNotesOnly) {
        final response = await _client
            .from(table)
            .select(columns)
            .eq('user_id', userId)
            .eq('is_archived', false)
            .range(from, from + _pageSize - 1);
        page = List<Map<String, dynamic>>.from(response);
      } else {
        final response = await _client
            .from(table)
            .select(columns)
            .eq('user_id', userId)
            .range(from, from + _pageSize - 1);
        page = List<Map<String, dynamic>>.from(response);
      }
      result.addAll(page);
      if (page.length < _pageSize) break;
    }
    return result;
  }
}
