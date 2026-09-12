import 'package:supabase_flutter/supabase_flutter.dart';

import 'import_service.dart';

class EvernoteMigrationBatch {
  final int id;
  final String userId;
  final String sourceExportSha256;
  final String sourceFileName;
  final String status;
  final int sourceNoteCount;
  final int sourceResourceCount;
  final int importedNoteCount;
  final int verifiedNoteCount;
  final int sourceDeletedNoteCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EvernoteMigrationBatch({
    required this.id,
    required this.userId,
    required this.sourceExportSha256,
    required this.sourceFileName,
    required this.status,
    required this.sourceNoteCount,
    required this.sourceResourceCount,
    required this.importedNoteCount,
    required this.verifiedNoteCount,
    required this.sourceDeletedNoteCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EvernoteMigrationBatch.fromJson(Map<String, dynamic> json) {
    return EvernoteMigrationBatch(
      id: _asInt(json['id']),
      userId: json['user_id']?.toString() ?? '',
      sourceExportSha256: json['source_export_sha256']?.toString() ?? '',
      sourceFileName: json['source_file_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'previewed',
      sourceNoteCount: _asInt(json['source_note_count']),
      sourceResourceCount: _asInt(json['source_resource_count']),
      importedNoteCount: _asInt(json['imported_note_count']),
      verifiedNoteCount: _asInt(json['verified_note_count']),
      sourceDeletedNoteCount: _asInt(json['source_deleted_note_count']),
      createdAt: _asDateTime(json['created_at']),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _asDateTime(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}

class EvernoteMigrationItem {
  const EvernoteMigrationItem({
    required this.id,
    required this.batchId,
    required this.sourceItemKey,
    required this.status,
    required this.historyStatus,
    required this.sourceHistoryVersionCount,
    required this.importedHistoryVersionCount,
    required this.verifiedHistoryVersionCount,
    this.taskStatus = 'pending',
    this.sourceTaskCount = 0,
    this.importedTaskCount = 0,
    this.verifiedTaskCount = 0,
    this.sourceTaskReminderCount = 0,
    this.importedTaskReminderCount = 0,
    this.verifiedTaskReminderCount = 0,
    this.sourceNoteReminderPresent = false,
    this.noteReminderVerified = false,
    this.sourceNoteId,
    this.targetNoteId,
    this.noteTitle,
  });

  final int id;
  final int batchId;
  final String sourceItemKey;
  final String? sourceNoteId;
  final int? targetNoteId;
  final String status;
  final String historyStatus;
  final int sourceHistoryVersionCount;
  final int importedHistoryVersionCount;
  final int verifiedHistoryVersionCount;
  final String taskStatus;
  final int sourceTaskCount;
  final int importedTaskCount;
  final int verifiedTaskCount;
  final int sourceTaskReminderCount;
  final int importedTaskReminderCount;
  final int verifiedTaskReminderCount;
  final bool sourceNoteReminderPresent;
  final bool noteReminderVerified;
  final String? noteTitle;

  bool get isImported => targetNoteId != null;

  bool get historyDeletionGatePassed =>
      historyStatus == 'verified' || historyStatus == 'reviewed_no_versions';

  bool get taskDeletionGatePassed =>
      taskStatus == 'verified' || taskStatus == 'verified_no_features';

  bool get sourceDeletionGatePassed =>
      historyDeletionGatePassed && taskDeletionGatePassed;

  String get displayTitle {
    final title = noteTitle?.trim();
    if (title != null && title.isNotEmpty) return title;
    final sourceId = sourceNoteId?.trim();
    if (sourceId != null && sourceId.isNotEmpty) return sourceId;
    return sourceItemKey;
  }

  factory EvernoteMigrationItem.fromJson(Map<String, dynamic> json) {
    final noteValue = json['notes'];
    final note = noteValue is Map
        ? Map<String, dynamic>.from(noteValue)
        : const <String, dynamic>{};
    final targetNoteId = _nullableInt(json['target_note_id']);
    return EvernoteMigrationItem(
      id: _asIntValue(json['id']),
      batchId: _asIntValue(json['batch_id']),
      sourceItemKey: json['source_item_key']?.toString() ?? '',
      sourceNoteId: _emptyStringToNull(json['source_note_id']),
      targetNoteId: targetNoteId,
      status: json['status']?.toString() ?? 'previewed',
      historyStatus: json['history_status']?.toString() ?? 'pending',
      sourceHistoryVersionCount:
          _asIntValue(json['source_history_version_count']),
      importedHistoryVersionCount:
          _asIntValue(json['imported_history_version_count']),
      verifiedHistoryVersionCount:
          _asIntValue(json['verified_history_version_count']),
      taskStatus: json['task_status']?.toString() ?? 'pending',
      sourceTaskCount: _asIntValue(json['source_task_count']),
      importedTaskCount: _asIntValue(json['imported_task_count']),
      verifiedTaskCount: _asIntValue(json['verified_task_count']),
      sourceTaskReminderCount: _asIntValue(json['source_task_reminder_count']),
      importedTaskReminderCount:
          _asIntValue(json['imported_task_reminder_count']),
      verifiedTaskReminderCount:
          _asIntValue(json['verified_task_reminder_count']),
      sourceNoteReminderPresent: json['source_note_reminder_present'] == true,
      noteReminderVerified: json['note_reminder_verified'] == true,
      noteTitle: _emptyStringToNull(note['title']),
    );
  }
}

class EvernoteMigrationProgress {
  final int batchCount;
  final int sourceNoteCount;
  final int importedNoteCount;
  final int verifiedNoteCount;
  final int sourceDeletedNoteCount;
  final int sourceResourceCount;

  const EvernoteMigrationProgress({
    required this.batchCount,
    required this.sourceNoteCount,
    required this.importedNoteCount,
    required this.verifiedNoteCount,
    required this.sourceDeletedNoteCount,
    required this.sourceResourceCount,
  });

  factory EvernoteMigrationProgress.fromBatches(
    Iterable<EvernoteMigrationBatch> batches,
  ) {
    var batchCount = 0;
    var sourceNoteCount = 0;
    var importedNoteCount = 0;
    var verifiedNoteCount = 0;
    var sourceDeletedNoteCount = 0;
    var sourceResourceCount = 0;
    for (final batch in batches) {
      batchCount += 1;
      sourceNoteCount += batch.sourceNoteCount;
      importedNoteCount += batch.importedNoteCount;
      verifiedNoteCount += batch.verifiedNoteCount;
      sourceDeletedNoteCount += batch.sourceDeletedNoteCount;
      sourceResourceCount += batch.sourceResourceCount;
    }
    return EvernoteMigrationProgress(
      batchCount: batchCount,
      sourceNoteCount: sourceNoteCount,
      importedNoteCount: importedNoteCount,
      verifiedNoteCount: verifiedNoteCount,
      sourceDeletedNoteCount: sourceDeletedNoteCount,
      sourceResourceCount: sourceResourceCount,
    );
  }

  double get overallFraction {
    if (sourceNoteCount == 0) return 0;
    final denominator = sourceNoteCount * 4;
    final completedStageUnits = sourceNoteCount +
        importedNoteCount +
        verifiedNoteCount +
        sourceDeletedNoteCount;
    return (completedStageUnits / denominator).clamp(0, 1).toDouble();
  }

  int get overallPercent => (overallFraction * 100).round();
}

class EvernoteMigrationLedgerService {
  final SupabaseClient _client;

  EvernoteMigrationLedgerService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<EvernoteMigrationBatch> recordPreview({
    required String userId,
    required ImportPreviewResult preview,
  }) async {
    final ownerId = userId.trim();
    final exportHash = preview.sourceExportSha256?.trim().toLowerCase();
    if (ownerId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User id is required.');
    }
    if (preview.sourceType != 'evernote' || exportHash == null) {
      throw ArgumentError(
        'An Evernote preview with an export SHA-256 is required.',
      );
    }

    final batchJson = await _client
        .from('evernote_migration_batches')
        .upsert(
          <String, dynamic>{
            'user_id': ownerId,
            'source_export_sha256': exportHash,
            'source_file_name': preview.fileName,
            'source_note_count': preview.notes.length,
            'source_resource_count': preview.resourceCount,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'user_id,source_export_sha256',
        )
        .select()
        .single();
    final batch = EvernoteMigrationBatch.fromJson(batchJson);

    const chunkSize = 100;
    final itemRows = <Map<String, dynamic>>[];
    for (var index = 0; index < preview.notes.length; index += 1) {
      final note = preview.notes[index];
      itemRows.add(<String, dynamic>{
        'batch_id': batch.id,
        'user_id': ownerId,
        'source_item_key': _sourceItemKey(note, index),
        'source_note_id': _emptyToNull(note.sourceId),
        'source_content_sha256': _emptyToNull(
          note.sourceContentSha256?.toLowerCase(),
        ),
        'source_resource_count': note.sourceResourceCount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    for (var offset = 0; offset < itemRows.length; offset += chunkSize) {
      final end = offset + chunkSize > itemRows.length
          ? itemRows.length
          : offset + chunkSize;
      await _client.from('evernote_migration_items').upsert(
            itemRows.sublist(offset, end),
            onConflict: 'batch_id,source_item_key',
          );
    }
    return batch;
  }

  Future<List<EvernoteMigrationBatch>> loadBatches({
    required String userId,
    int limit = 20,
  }) async {
    final ownerId = userId.trim();
    if (ownerId.isEmpty) return const <EvernoteMigrationBatch>[];
    final rows = await _client
        .from('evernote_migration_batches')
        .select()
        .eq('user_id', ownerId)
        .order('updated_at', ascending: false)
        .limit(limit.clamp(1, 100));
    return rows
        .map(
          (row) => EvernoteMigrationBatch.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }

  Future<List<EvernoteMigrationItem>> loadItems({
    required String userId,
    int limit = 200,
  }) async {
    final ownerId = userId.trim();
    if (ownerId.isEmpty) return const <EvernoteMigrationItem>[];
    final rows = await _client
        .from('evernote_migration_items')
        .select(
          'id,batch_id,source_item_key,source_note_id,target_note_id,status,'
          'history_status,source_history_version_count,'
          'imported_history_version_count,verified_history_version_count,'
          'task_status,source_task_count,imported_task_count,'
          'verified_task_count,source_task_reminder_count,'
          'imported_task_reminder_count,verified_task_reminder_count,'
          'source_note_reminder_present,note_reminder_verified,'
          'notes!evernote_migration_items_target_note_fkey(title)',
        )
        .eq('user_id', ownerId)
        .order('updated_at', ascending: false)
        .limit(limit.clamp(1, 1000));
    return rows
        .map(
          (row) => EvernoteMigrationItem.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }

  static String _sourceItemKey(ImportedNoteDraft note, int index) {
    final sourceId = note.sourceId?.trim();
    if (sourceId != null && sourceId.isNotEmpty) return 'id:$sourceId';
    final contentHash = note.sourceContentSha256?.trim().toLowerCase();
    if (contentHash != null && contentHash.isNotEmpty) {
      return 'sha256:$contentHash:$index';
    }
    return 'ordinal:$index';
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

int _asIntValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  final parsed = _asIntValue(value);
  return parsed <= 0 ? null : parsed;
}

String? _emptyStringToNull(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
