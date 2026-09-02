import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'direct_storage_upload_service.dart';
import 'evernote_enex_parser.dart';
import 'evernote_migration_ledger_service.dart';
import 'import_service.dart';

const String evernoteArchiveBucket = 'evernote-migration-archives';
const String evernoteAttachmentBucket = 'attachments';
const int evernoteMigrationMaxObjectBytes = 100 * 1024 * 1024;

class EvernoteMigrationResourceManifest {
  const EvernoteMigrationResourceManifest({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.fileType,
    required this.mimeType,
    required this.contentSha256,
    required this.sourceMetadata,
  });

  final String fileName;
  final String filePath;
  final int fileSize;
  final String fileType;
  final String mimeType;
  final String contentSha256;
  final Map<String, dynamic> sourceMetadata;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'file_name': fileName,
        'file_path': filePath,
        'file_size': fileSize,
        'file_type': fileType,
        'mime_type': mimeType,
        'content_sha256': contentSha256,
        'source_metadata': sourceMetadata,
      };
}

class EvernoteCommittedAttachmentSnapshot {
  const EvernoteCommittedAttachmentSnapshot({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.mimeType,
    required this.contentSha256,
  });

  final String fileName;
  final String filePath;
  final int fileSize;
  final String mimeType;
  final String contentSha256;

  factory EvernoteCommittedAttachmentSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    return EvernoteCommittedAttachmentSnapshot(
      fileName: json['file_name']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      fileSize: _asInt(json['file_size']),
      mimeType: json['mime_type']?.toString() ?? '',
      contentSha256: json['content_sha256']?.toString() ?? '',
    );
  }
}

class EvernoteCommittedNoteSnapshot {
  const EvernoteCommittedNoteSnapshot({
    required this.noteId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.attachments,
  });

  final int noteId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final List<EvernoteCommittedAttachmentSnapshot> attachments;
}

class EvernoteMigrationCommitResult {
  const EvernoteMigrationCommitResult({
    required this.batchId,
    required this.importedNoteCount,
    required this.verifiedNoteCount,
    required this.resourceCount,
    required this.archiveSha256,
    required this.noteIds,
  });

  final int batchId;
  final int importedNoteCount;
  final int verifiedNoteCount;
  final int resourceCount;
  final String archiveSha256;
  final List<int> noteIds;
}

abstract class EvernoteMigrationLedgerGateway {
  Future<EvernoteMigrationBatch> recordPreview({
    required String userId,
    required ImportPreviewResult preview,
  });
}

class SupabaseEvernoteMigrationLedgerGateway
    implements EvernoteMigrationLedgerGateway {
  SupabaseEvernoteMigrationLedgerGateway(SupabaseClient client)
      : _ledger = EvernoteMigrationLedgerService(client: client);

  final EvernoteMigrationLedgerService _ledger;

  @override
  Future<EvernoteMigrationBatch> recordPreview({
    required String userId,
    required ImportPreviewResult preview,
  }) {
    return _ledger.recordPreview(userId: userId, preview: preview);
  }
}

abstract class EvernoteMigrationStorageGateway {
  Future<void> uploadBinary({
    required String bucketId,
    required String path,
    required Uint8List bytes,
    required String contentType,
  });

  Future<Uint8List> downloadBinary({
    required String bucketId,
    required String path,
  });
}

class SupabaseEvernoteMigrationStorageGateway
    implements EvernoteMigrationStorageGateway {
  SupabaseEvernoteMigrationStorageGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<void> uploadBinary({
    required String bucketId,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _client.storage.from(bucketId).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );
  }

  @override
  Future<Uint8List> downloadBinary({
    required String bucketId,
    required String path,
  }) {
    return _client.storage.from(bucketId).download(path);
  }
}

abstract class EvernoteMigrationDatabaseGateway {
  Future<int> commitNote({
    required int batchId,
    required String sourceItemKey,
    required EvernoteEnexNote note,
    required Map<String, dynamic> sourceMetadata,
    required List<EvernoteMigrationResourceManifest> resources,
    required String archivePath,
  });

  Future<EvernoteCommittedNoteSnapshot> loadCommittedNote({
    required int noteId,
  });

  Future<void> markNoteVerified({
    required int batchId,
    required String sourceItemKey,
    required Map<String, bool> checks,
  });
}

class SupabaseEvernoteMigrationDatabaseGateway
    implements EvernoteMigrationDatabaseGateway {
  SupabaseEvernoteMigrationDatabaseGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<int> commitNote({
    required int batchId,
    required String sourceItemKey,
    required EvernoteEnexNote note,
    required Map<String, dynamic> sourceMetadata,
    required List<EvernoteMigrationResourceManifest> resources,
    required String archivePath,
  }) async {
    final response = await _client.rpc(
      'evernote_commit_note',
      params: <String, dynamic>{
        'p_batch_id': batchId,
        'p_source_item_key': sourceItemKey,
        'p_title': note.title,
        'p_content': note.plainText,
        'p_source_created_at': note.createdAt?.toUtc().toIso8601String(),
        'p_source_updated_at': note.updatedAt?.toUtc().toIso8601String(),
        'p_tags': note.tags,
        'p_source_enml': note.enml,
        'p_source_metadata': sourceMetadata,
        'p_resources': resources
            .map((resource) => resource.toJson())
            .toList(growable: false),
        'p_archive_bucket': evernoteArchiveBucket,
        'p_archive_path': archivePath,
      },
    );
    final json = _asStringMap(response);
    final noteId = _asInt(json['note_id']);
    if (noteId <= 0) {
      throw StateError('Evernote commit did not return a target note id.');
    }
    return noteId;
  }

  @override
  Future<EvernoteCommittedNoteSnapshot> loadCommittedNote({
    required int noteId,
  }) async {
    final noteResponse = await _client
        .from('notes')
        .select('id,title,content,created_at,updated_at,tags')
        .eq('id', noteId)
        .single();
    final noteJson = Map<String, dynamic>.from(noteResponse);
    final attachmentResponse = await _client
        .from('attachments')
        .select(
          'file_name,file_path,file_size,mime_type,content_sha256',
        )
        .eq('note_id', noteId)
        .eq('source_system', 'evernote')
        .order('file_path');
    final attachments = attachmentResponse
        .map(
          (row) => EvernoteCommittedAttachmentSnapshot.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
    return EvernoteCommittedNoteSnapshot(
      noteId: _asInt(noteJson['id']),
      title: noteJson['title']?.toString() ?? '',
      content: noteJson['content']?.toString() ?? '',
      createdAt: _asDateTime(noteJson['created_at']),
      updatedAt: _asDateTime(noteJson['updated_at']),
      tags: (noteJson['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(growable: false),
      attachments: attachments,
    );
  }

  @override
  Future<void> markNoteVerified({
    required int batchId,
    required String sourceItemKey,
    required Map<String, bool> checks,
  }) async {
    await _client.rpc(
      'evernote_verify_note',
      params: <String, dynamic>{
        'p_batch_id': batchId,
        'p_source_item_key': sourceItemKey,
        'p_verification_checks': checks,
      },
    );
  }
}

class EvernoteMigrationCommitService {
  EvernoteMigrationCommitService({
    required this.ledger,
    required this.storage,
    required this.database,
    EvernoteEnexParser parser = const EvernoteEnexParser(),
  }) : _parser = parser;

  factory EvernoteMigrationCommitService.supabase(SupabaseClient client) {
    return EvernoteMigrationCommitService(
      ledger: SupabaseEvernoteMigrationLedgerGateway(client),
      storage: SupabaseEvernoteMigrationStorageGateway(client),
      database: SupabaseEvernoteMigrationDatabaseGateway(client),
    );
  }

  final EvernoteMigrationLedgerGateway ledger;
  final EvernoteMigrationStorageGateway storage;
  final EvernoteMigrationDatabaseGateway database;
  final EvernoteEnexParser _parser;

  Future<EvernoteMigrationCommitResult> commit({
    required String userId,
    required Uint8List exportBytes,
    required ImportPreviewResult preview,
  }) async {
    final ownerId = userId.trim();
    if (ownerId.isEmpty || ownerId.contains('/') || ownerId.contains(r'\')) {
      throw ArgumentError.value(userId, 'userId', 'Invalid owner id.');
    }
    if (exportBytes.isEmpty ||
        exportBytes.length > evernoteMigrationMaxObjectBytes) {
      throw StateError(
        'The ENEX batch must be between 1 byte and '
        '$evernoteMigrationMaxObjectBytes bytes.',
      );
    }
    if (preview.sourceType != 'evernote') {
      throw ArgumentError('An Evernote preview is required.');
    }

    final export = _parser.parseBytes(exportBytes);
    if (preview.sourceExportSha256?.toLowerCase() != export.exportSha256 ||
        preview.notes.length != export.notes.length ||
        preview.resourceCount != export.resourceCount) {
      throw StateError('The selected ENEX no longer matches its preview.');
    }
    if (export.warnings.isNotEmpty) {
      throw StateError(
        'The ENEX parser reported warnings. Commit remains blocked.',
      );
    }
    if (export.notes.any(
      (note) => note.resources.any(
        (resource) =>
            resource.data.isEmpty ||
            resource.data.length > evernoteMigrationMaxObjectBytes,
      ),
    )) {
      throw StateError(
        'Every attachment must contain data and be no larger than '
        '$evernoteMigrationMaxObjectBytes bytes.',
      );
    }

    final batch = await ledger.recordPreview(
      userId: ownerId,
      preview: preview,
    );
    final archivePath = '$ownerId/evernote/${export.exportSha256}/source.enex';
    await _ensureVerifiedObject(
      bucketId: evernoteArchiveBucket,
      path: archivePath,
      bytes: exportBytes,
      contentType: 'application/xml',
      expectedSha256: export.exportSha256,
    );

    final committed = <_CommittedEvernoteNote>[];
    for (var noteIndex = 0; noteIndex < export.notes.length; noteIndex += 1) {
      final note = export.notes[noteIndex];
      final sourceItemKey = 'id:${note.sourceId}';
      final notePathToken = sha256
          .convert(utf8.encode(note.sourceId))
          .toString()
          .substring(0, 32);
      final manifests = <EvernoteMigrationResourceManifest>[];
      for (var resourceIndex = 0;
          resourceIndex < note.resources.length;
          resourceIndex += 1) {
        final resource = note.resources[resourceIndex];
        final fileName = _resourceFileName(resource, resourceIndex);
        final path = '$ownerId/evernote/${export.exportSha256}/'
            '$notePathToken/'
            '${resourceIndex.toString().padLeft(4, '0')}-'
            '${resource.dataSha256}-$fileName';
        final mimeType = resource.mimeType.trim().isEmpty
            ? 'application/octet-stream'
            : resource.mimeType.trim();
        await _ensureVerifiedObject(
          bucketId: evernoteAttachmentBucket,
          path: path,
          bytes: resource.data,
          contentType: mimeType,
          expectedSha256: resource.dataSha256,
        );
        manifests.add(
          EvernoteMigrationResourceManifest(
            fileName: resource.fileName?.trim().isNotEmpty == true
                ? resource.fileName!.trim()
                : fileName,
            filePath: path,
            fileSize: resource.data.length,
            fileType: _fileType(mimeType),
            mimeType: mimeType,
            contentSha256: resource.dataSha256,
            sourceMetadata: <String, dynamic>{
              'resource_index': resourceIndex,
              'evernote_hash': resource.evernoteHash,
              'width': resource.width,
              'height': resource.height,
              'duration': resource.duration,
              'recognition_xml': resource.recognitionXml,
              'alternate_data': resource.alternateData,
              'attributes': resource.attributes,
              'raw_resource_xml_sha256':
                  sha256.convert(utf8.encode(resource.rawXml)).toString(),
            },
          ),
        );
      }

      final noteId = await database.commitNote(
        batchId: batch.id,
        sourceItemKey: sourceItemKey,
        note: note,
        sourceMetadata: <String, dynamic>{
          'source_guid': note.sourceGuid,
          'content_sha256': note.contentSha256,
          'attributes': note.attributes,
          'links': note.links,
          'raw_note_xml_sha256':
              sha256.convert(utf8.encode(note.rawXml)).toString(),
          'archive_path': archivePath,
        },
        resources: manifests,
        archivePath: archivePath,
      );
      committed.add(
        _CommittedEvernoteNote(
          note: note,
          sourceItemKey: sourceItemKey,
          noteId: noteId,
          resources: manifests,
        ),
      );
    }

    final archivedBytes = await storage.downloadBinary(
      bucketId: evernoteArchiveBucket,
      path: archivePath,
    );
    final archiveVerified =
        sha256.convert(archivedBytes).toString() == export.exportSha256;
    if (!archiveVerified) {
      throw StateError('The stored ENEX recovery archive hash does not match.');
    }

    var verifiedCount = 0;
    for (final committedNote in committed) {
      await _verifyCommittedNote(
        batchId: batch.id,
        committed: committedNote,
        archiveVerified: archiveVerified,
      );
      verifiedCount += 1;
    }

    return EvernoteMigrationCommitResult(
      batchId: batch.id,
      importedNoteCount: committed.length,
      verifiedNoteCount: verifiedCount,
      resourceCount: export.resourceCount,
      archiveSha256: export.exportSha256,
      noteIds: List<int>.unmodifiable(
        committed.map((entry) => entry.noteId),
      ),
    );
  }

  Future<void> _verifyCommittedNote({
    required int batchId,
    required _CommittedEvernoteNote committed,
    required bool archiveVerified,
  }) async {
    final snapshot = await database.loadCommittedNote(noteId: committed.noteId);
    final note = committed.note;
    final contentMatches = snapshot.noteId == committed.noteId &&
        snapshot.title == note.title &&
        snapshot.content == note.plainText;
    final timestampsMatch = _sameOptionalInstant(
          note.createdAt,
          snapshot.createdAt,
        ) &&
        _sameOptionalInstant(note.updatedAt, snapshot.updatedAt);
    final tagsMatch = _sameStrings(note.tags, snapshot.tags);
    final expectedByPath = <String, EvernoteMigrationResourceManifest>{
      for (final resource in committed.resources) resource.filePath: resource,
    };
    final resourceCountMatches =
        snapshot.attachments.length == committed.resources.length &&
            snapshot.attachments.every(
              (attachment) => expectedByPath.containsKey(attachment.filePath),
            );

    var resourceHashesMatch = resourceCountMatches;
    if (resourceHashesMatch) {
      for (final attachment in snapshot.attachments) {
        final expected = expectedByPath[attachment.filePath]!;
        if (attachment.fileName != expected.fileName ||
            attachment.fileSize != expected.fileSize ||
            attachment.mimeType != expected.mimeType ||
            attachment.contentSha256 != expected.contentSha256) {
          resourceHashesMatch = false;
          break;
        }
        final bytes = await storage.downloadBinary(
          bucketId: evernoteAttachmentBucket,
          path: attachment.filePath,
        );
        if (sha256.convert(bytes).toString() != expected.contentSha256) {
          resourceHashesMatch = false;
          break;
        }
      }
    }

    final checks = <String, bool>{
      'archive_sha256': archiveVerified,
      'note_content': contentMatches,
      'timestamps': timestampsMatch,
      'tags': tagsMatch,
      'resource_count': resourceCountMatches,
      'resource_sha256': resourceHashesMatch,
    };
    if (checks.values.any((passed) => !passed)) {
      final failed = checks.entries
          .where((entry) => !entry.value)
          .map((entry) => entry.key)
          .join(', ');
      throw StateError('Evernote verification failed: $failed.');
    }
    await database.markNoteVerified(
      batchId: batchId,
      sourceItemKey: committed.sourceItemKey,
      checks: checks,
    );
  }

  Future<void> _ensureVerifiedObject({
    required String bucketId,
    required String path,
    required Uint8List bytes,
    required String contentType,
    required String expectedSha256,
  }) async {
    Object? uploadError;
    StackTrace? uploadStackTrace;
    try {
      await storage.uploadBinary(
        bucketId: bucketId,
        path: path,
        bytes: bytes,
        contentType: contentType,
      );
    } catch (error, stackTrace) {
      // A deterministic path may already exist after a prior successful or
      // interrupted attempt. The subsequent download/hash check decides
      // whether it is safe to reuse; unrelated upload failures are rethrown.
      uploadError = error;
      uploadStackTrace = stackTrace;
    }

    try {
      final stored = await storage.downloadBinary(
        bucketId: bucketId,
        path: path,
      );
      if (sha256.convert(stored).toString() != expectedSha256) {
        throw StateError('Stored object hash mismatch for $bucketId/$path.');
      }
    } catch (_) {
      if (uploadError != null) {
        Error.throwWithStackTrace(uploadError, uploadStackTrace!);
      }
      rethrow;
    }
  }

  String _resourceFileName(EvernoteEnexResource resource, int index) {
    final candidate = resource.fileName?.trim().isNotEmpty == true
        ? resource.fileName!.trim()
        : 'resource-${index.toString().padLeft(4, '0')}';
    return DirectStorageUploadService.sanitizeFileName(candidate);
  }

  String _fileType(String mimeType) {
    if (mimeType.startsWith('image/')) return 'image';
    if (mimeType == 'application/pdf') return 'pdf';
    if (mimeType.startsWith('audio/')) return 'audio';
    if (mimeType.startsWith('video/')) return 'video';
    return 'other';
  }

  bool _sameOptionalInstant(DateTime? source, DateTime stored) {
    if (source == null) return true;
    return source.toUtc().microsecondsSinceEpoch ==
        stored.toUtc().microsecondsSinceEpoch;
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

class _CommittedEvernoteNote {
  const _CommittedEvernoteNote({
    required this.note,
    required this.sourceItemKey,
    required this.noteId,
    required this.resources,
  });

  final EvernoteEnexNote note;
  final String sourceItemKey;
  final int noteId;
  final List<EvernoteMigrationResourceManifest> resources;
}

Map<String, dynamic> _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw StateError('Expected a JSON object from Evernote migration RPC.');
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _asDateTime(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw StateError('Expected a valid Evernote migration timestamp.');
  }
  return parsed.toUtc();
}
