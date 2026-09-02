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
