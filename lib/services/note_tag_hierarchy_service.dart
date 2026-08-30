import 'package:supabase_flutter/supabase_flutter.dart';

class NoteTagRecord {
  const NoteTagRecord({
    required this.id,
    required this.name,
    required this.sourceSystem,
    required this.noteCount,
    this.parentId,
  });

  final int id;
  final int? parentId;
  final String name;
  final String sourceSystem;
  final int noteCount;

  bool get isImported => sourceSystem == 'evernote';

  factory NoteTagRecord.fromJson(
    Map<String, dynamic> json, {
    required int noteCount,
  }) {
    final id = int.tryParse(json['id']?.toString() ?? '');
    if (id == null) {
      throw StateError('Tag id is missing.');
    }
    return NoteTagRecord(
      id: id,
      parentId: int.tryParse(json['parent_id']?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      sourceSystem: json['source_system']?.toString() ?? 'native',
      noteCount: noteCount,
    );
  }
}

class NoteTagHierarchySnapshot {
  const NoteTagHierarchySnapshot({
    required this.tags,
    required this.noteIdsByTagId,
    required this.evernoteSourceDeleted,
  });

  final List<NoteTagRecord> tags;
  final Map<int, Set<int>> noteIdsByTagId;
  final bool evernoteSourceDeleted;

  Map<int?, List<NoteTagRecord>> get tagsByParent {
    final result = <int?, List<NoteTagRecord>>{};
    for (final tag in tags) {
      result.putIfAbsent(tag.parentId, () => <NoteTagRecord>[]).add(tag);
    }
    for (final children in result.values) {
      children.sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
    }
    return result;
  }

  Set<int> descendantIds(int rootId, {bool includeRoot = true}) {
    final children = <int, List<int>>{};
    for (final tag in tags) {
      final parentId = tag.parentId;
      if (parentId != null) {
        children.putIfAbsent(parentId, () => <int>[]).add(tag.id);
      }
    }
    final result = <int>{if (includeRoot) rootId};
    final pending = <int>[rootId];
    while (pending.isNotEmpty) {
      final parent = pending.removeLast();
      for (final child in children[parent] ?? const <int>[]) {
        if (result.add(child)) pending.add(child);
      }
    }
    return result;
  }

  Set<int> noteIdsForTag(int tagId, {required bool includeDescendants}) {
    final tagIds = includeDescendants
        ? descendantIds(tagId)
        : <int>{tagId};
    return <int>{
      for (final id in tagIds) ...noteIdsByTagId[id] ?? const <int>{},
    };
  }

  bool isLocked(NoteTagRecord tag) =>
      tag.isImported && !evernoteSourceDeleted;
}

abstract class NoteTagHierarchyDataSource {
  Future<NoteTagHierarchySnapshot> load();
  Future<void> createTag({required String name, int? parentId});
  Future<void> renameTag({required int id, required String name});
  Future<void> moveTag({required int id, int? parentId});
  Future<void> deleteTag(int id);
}

class SupabaseNoteTagHierarchyDataSource
    implements NoteTagHierarchyDataSource {
  SupabaseNoteTagHierarchyDataSource(this._client);

  static const int _pageSize = 500;
  final SupabaseClient _client;

  @override
  Future<NoteTagHierarchySnapshot> load() async {
    final userId = _requireUserId();
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _fetchPaged(
        table: 'note_tags',
        columns: 'id,parent_id,name,source_system',
        userId: userId,
      ),
      _fetchPaged(
        table: 'note_tag_assignments',
        columns: 'note_id,tag_id',
        userId: userId,
      ),
    ]);
    final noteIdsByTagId = <int, Set<int>>{};
    for (final row in results[1]) {
      final noteId = int.tryParse(row['note_id']?.toString() ?? '');
      final tagId = int.tryParse(row['tag_id']?.toString() ?? '');
      if (noteId != null && tagId != null) {
        noteIdsByTagId.putIfAbsent(tagId, () => <int>{}).add(noteId);
      }
    }
    final migrationRows = await _client
        .from('evernote_tag_migrations')
        .select('status')
        .eq('user_id', userId)
        .limit(1);
    final sourceDeleted = migrationRows.isNotEmpty &&
        Map<String, dynamic>.from(migrationRows.first)['status'] ==
            'source_deleted';
    final tags = results[0]
        .map(
          (row) => NoteTagRecord.fromJson(
            row,
            noteCount: noteIdsByTagId[
                    int.tryParse(row['id']?.toString() ?? '')]?.length ??
                0,
          ),
        )
        .toList(growable: false);
    return NoteTagHierarchySnapshot(
      tags: List<NoteTagRecord>.unmodifiable(tags),
      noteIdsByTagId: Map<int, Set<int>>.unmodifiable(
        noteIdsByTagId.map(
          (key, value) => MapEntry(key, Set<int>.unmodifiable(value)),
        ),
      ),
      evernoteSourceDeleted: sourceDeleted,
    );
  }

  @override
  Future<void> createTag({required String name, int? parentId}) async {
    final userId = _requireUserId();
    await _client.from('note_tags').insert(<String, dynamic>{
      'user_id': userId,
      'parent_id': parentId,
      'name': _validName(name),
    });
  }

  @override
  Future<void> renameTag({required int id, required String name}) async {
    await _client.from('note_tags').update(<String, dynamic>{
      'name': _validName(name),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  @override
  Future<void> moveTag({required int id, int? parentId}) async {
    if (id == parentId) {
      throw ArgumentError('A tag cannot be its own parent.');
    }
    await _client.from('note_tags').update(<String, dynamic>{
      'parent_id': parentId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  @override
  Future<void> deleteTag(int id) async {
    await _client.from('note_tags').delete().eq('id', id);
  }

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.trim().isEmpty) {
      throw StateError('Sign in before managing tags.');
    }
    return id;
  }

  String _validName(String raw) {
    final name = raw.trim();
    if (name.isEmpty || name.length > 200) {
      throw ArgumentError('Tag names must contain 1 to 200 characters.');
    }
    return name;
  }

  Future<List<Map<String, dynamic>>> _fetchPaged({
    required String table,
    required String columns,
    required String userId,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (var from = 0;; from += _pageSize) {
      final response = await _client
          .from(table)
          .select(columns)
          .eq('user_id', userId)
          .range(from, from + _pageSize - 1);
      final page = List<Map<String, dynamic>>.from(response);
      result.addAll(page);
      if (page.length < _pageSize) break;
    }
    return result;
  }
}
