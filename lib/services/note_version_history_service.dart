import 'package:supabase_flutter/supabase_flutter.dart';

/// Cursor values stay in database precision, including microseconds on the web.
class NoteVersionCursor {
  NoteVersionCursor({required this.id, required this.savedAt}) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const FormatException('Invalid history identifier');
    }
    if (savedAt != null &&
        (!RegExp(
              r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$',
            ).hasMatch(savedAt!) ||
            DateTime.tryParse(savedAt!) == null)) {
      throw const FormatException('Invalid history timestamp');
    }
  }

  final String id;
  final String? savedAt;

  String get olderFilter {
    final timestamp = savedAt;
    if (timestamp == null) {
      return 'and(saved_at.is.null,id.lt.$id)';
    }
    return 'saved_at.lt.$timestamp,'
        'and(saved_at.eq.$timestamp,id.lt.$id),saved_at.is.null';
  }
}

class NoteVersionSummary {
  NoteVersionSummary({
    required this.cursor,
    required this.title,
    required this.sourceSystem,
    required this.sourceVerified,
  });

  factory NoteVersionSummary.fromJson(Map<String, dynamic> row) =>
      NoteVersionSummary(
        cursor: NoteVersionCursor(
          id: row['id'] as String,
          savedAt: row['saved_at'] as String?,
        ),
        title: row['title'] as String? ?? '',
        sourceSystem: row['source_system'] as String? ?? 'native',
        sourceVerified: row['source_verified_at'] != null,
      );

  final NoteVersionCursor cursor;
  final String title;
  final String sourceSystem;
  final bool sourceVerified;

  String get id => cursor.id;
  bool get isEvernote => sourceSystem == 'evernote';
  String get displayTitle => title.isEmpty ? '無題' : title;
  DateTime? get savedAt =>
      cursor.savedAt == null ? null : DateTime.tryParse(cursor.savedAt!);
}

class NoteVersionAttachment {
  const NoteVersionAttachment({
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
  });

  final String fileName;
  final String mimeType;
  final int fileSize;
}

class NoteVersionDetail {
  NoteVersionDetail({
    required this.summary,
    required this.content,
    Iterable<String> tags = const [],
    Iterable<NoteVersionAttachment> attachments = const [],
  })  : tags = List.unmodifiable(tags),
        attachments = List.unmodifiable(attachments);

  final NoteVersionSummary summary;
  final String content;
  final List<String> tags;
  final List<NoteVersionAttachment> attachments;
}

class NoteVersionPage {
  NoteVersionPage({
    required Iterable<NoteVersionSummary> items,
    required this.hasMore,
  }) : items = List.unmodifiable(items);

  final List<NoteVersionSummary> items;
  final bool hasMore;
}

abstract interface class NoteVersionHistoryRepository {
  Future<NoteVersionPage> loadPage(
    String noteId, {
    NoteVersionCursor? before,
  });

  Future<NoteVersionDetail> loadDetail(String noteId, String versionId);
}

/// Read-only access through existing owner-scoped RLS. No privileged key/RPC.
class SupabaseNoteVersionHistoryRepository
    implements NoteVersionHistoryRepository {
  SupabaseNoteVersionHistoryRepository(this._client);

  static const pageSize = 30;
  static const summaryColumns =
      'id,title,saved_at,source_system,source_verified_at';
  final SupabaseClient _client;

  String _owner() {
    final owner = _client.auth.currentUser?.id;
    if (owner == null) throw StateError('Login is required');
    return owner;
  }

  void _checkOwner(String owner) {
    if (_owner() != owner) throw StateError('Session changed');
  }

  @override
  Future<NoteVersionPage> loadPage(
    String noteId, {
    NoteVersionCursor? before,
  }) async {
    final owner = _owner();
    var query = _client
        .from('note_versions')
        .select(summaryColumns)
        .eq('note_id', noteId)
        .eq('user_id', owner);
    if (before != null) query = query.or(before.olderFilter);
    final rows = await query
        .order('saved_at', ascending: false, nullsFirst: false)
        .order('id', ascending: false)
        .limit(pageSize + 1);
    _checkOwner(owner);
    return NoteVersionPage(
      items: rows.take(pageSize).map(NoteVersionSummary.fromJson),
      hasMore: rows.length > pageSize,
    );
  }

  @override
  Future<NoteVersionDetail> loadDetail(
    String noteId,
    String versionId,
  ) async {
    final owner = _owner();
    final row = await _client
        .from('note_versions')
        .select('$summaryColumns,content,source_tags')
        .eq('note_id', noteId)
        .eq('user_id', owner)
        .eq('id', versionId)
        .single();
    _checkOwner(owner);
    final summary = NoteVersionSummary.fromJson(row);
    final attachments = <NoteVersionAttachment>[];
    if (summary.isEvernote) {
      // Attachment metadata is paged too: a revision may have > 1,000 files.
      int? afterId;
      while (true) {
        var query = _client
            .from('evernote_note_history_attachments')
            .select('id,file_name,mime_type,file_size')
            .eq('note_id', noteId)
            .eq('user_id', owner)
            .eq('note_version_id', versionId);
        if (afterId != null) query = query.gt('id', afterId);
        final rows = await query.order('id', ascending: true).limit(100);
        _checkOwner(owner);
        for (final attachment in rows) {
          attachments.add(
            NoteVersionAttachment(
              fileName: attachment['file_name'] as String,
              mimeType: attachment['mime_type'] as String,
              fileSize: (attachment['file_size'] as num).toInt(),
            ),
          );
        }
        if (rows.length < 100) break;
        final nextId = (rows.last['id'] as num).toInt();
        if (afterId != null && nextId <= afterId) {
          throw StateError('History attachment cursor did not advance');
        }
        afterId = nextId;
      }
    }
    return NoteVersionDetail(
      summary: summary,
      content: row['content'] as String? ?? '',
      tags: (row['source_tags'] as List? ?? const []).cast<String>(),
      attachments: attachments,
    );
  }
}
