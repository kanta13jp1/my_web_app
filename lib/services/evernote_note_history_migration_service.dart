import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'direct_storage_upload_service.dart';
import 'evernote_enex_parser.dart';
import 'evernote_enml_markdown_converter.dart';
import 'evernote_migration_commit_service.dart';

class EvernoteNoteHistoryMigrationResult {
  const EvernoteNoteHistoryMigrationResult({
    required this.noteVersionId,
    required this.archiveSha256,
    required this.resourceCount,
  });

  final String noteVersionId;
  final String archiveSha256;
  final int resourceCount;
}

class EvernoteHistoryAttachmentSnapshot {
  const EvernoteHistoryAttachmentSnapshot({
    required this.filePath,
    required this.fileSize,
    required this.mimeType,
    required this.contentSha256,
  });

  final String filePath;
  final int fileSize;
  final String mimeType;
  final String contentSha256;

  factory EvernoteHistoryAttachmentSnapshot.fromJson(
    Map<String, dynamic> json,
  ) =>
      EvernoteHistoryAttachmentSnapshot(
        filePath: json['file_path']?.toString() ?? '',
        fileSize: _asInt(json['file_size']),
        mimeType: json['mime_type']?.toString() ?? '',
        contentSha256: json['content_sha256']?.toString() ?? '',
      );
}

class EvernoteHistoryVersionSnapshot {
  const EvernoteHistoryVersionSnapshot({
    required this.id,
    required this.title,
    required this.content,
    required this.savedAt,
    required this.sourceContentSha256,
    required this.tags,
    required this.attachments,
  });

  final String id;
  final String title;
  final String content;
  final DateTime savedAt;
  final String sourceContentSha256;
  final List<String> tags;
  final List<EvernoteHistoryAttachmentSnapshot> attachments;
}

abstract class EvernoteNoteHistoryDatabaseGateway {
  Future<void> markInventoryReviewed({
    required int batchId,
    required String sourceItemKey,
    required int sourceVersionCount,
  });

  Future<String> commitVersion({
    required int batchId,
    required String sourceItemKey,
    required String historyItemKey,
    required EvernoteEnexNote note,
    required String content,
    required DateTime savedAt,
    required Map<String, dynamic> sourceMetadata,
    required List<EvernoteMigrationResourceManifest> resources,
    required String archivePath,
    required String archiveSha256,
  });

  Future<EvernoteHistoryVersionSnapshot> loadVersion({
    required String noteVersionId,
  });

  Future<void> markVersionVerified({
    required int batchId,
    required String sourceItemKey,
    required String historyItemKey,
    required String archiveSha256,
    required Map<String, bool> checks,
  });
}

class SupabaseEvernoteNoteHistoryDatabaseGateway
    implements EvernoteNoteHistoryDatabaseGateway {
  SupabaseEvernoteNoteHistoryDatabaseGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<void> markInventoryReviewed({
    required int batchId,
    required String sourceItemKey,
    required int sourceVersionCount,
  }) async {
    await _client.rpc(
      'evernote_mark_note_history_reviewed',
      params: <String, dynamic>{
        'p_batch_id': batchId,
        'p_source_item_key': sourceItemKey,
        'p_source_history_version_count': sourceVersionCount,
      },
    );
  }

  @override
  Future<String> commitVersion({
    required int batchId,
    required String sourceItemKey,
    required String historyItemKey,
    required EvernoteEnexNote note,
    required String content,
    required DateTime savedAt,
    required Map<String, dynamic> sourceMetadata,
    required List<EvernoteMigrationResourceManifest> resources,
    required String archivePath,
    required String archiveSha256,
  }) async {
    final response = await _client.rpc(
      'evernote_commit_note_history_version',
      params: <String, dynamic>{
        'p_batch_id': batchId,
        'p_source_item_key': sourceItemKey,
        'p_history_item_key': historyItemKey,
        'p_title': note.title,
        'p_content': content,
        'p_saved_at': savedAt.toUtc().toIso8601String(),
        'p_source_enml': note.enml,
        'p_tags': note.tags,
        'p_source_metadata': sourceMetadata,
        'p_resources': resources
            .map((resource) => resource.toJson())
            .toList(growable: false),
        'p_archive_bucket': evernoteArchiveBucket,
        'p_archive_path': archivePath,
        'p_source_export_sha256': archiveSha256,
        'p_source_content_sha256': note.contentSha256,
      },
    );
    final versionId =
        _asStringMap(response)['note_version_id']?.toString() ?? '';
    if (versionId.isEmpty) {
      throw StateError(
        'Evernote history commit did not return a note version id.',
      );
    }
    return versionId;
  }

  @override
  Future<EvernoteHistoryVersionSnapshot> loadVersion({
    required String noteVersionId,
  }) async {
    final response = await _client
        .from('note_versions')
        .select(
          'id,title,content,saved_at,source_content_sha256,source_tags',
        )
        .eq('id', noteVersionId)
        .single();
    final version = Map<String, dynamic>.from(response);
    final attachmentResponse = await _client
        .from('evernote_note_history_attachments')
        .select('file_path,file_size,mime_type,content_sha256')
        .eq('note_version_id', noteVersionId)
        .order('file_path');
    return EvernoteHistoryVersionSnapshot(
      id: version['id']?.toString() ?? '',
      title: version['title']?.toString() ?? '',
      content: version['content']?.toString() ?? '',
      savedAt: _asDateTime(version['saved_at']),
      sourceContentSha256: version['source_content_sha256']?.toString() ?? '',
      tags: (version['source_tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(growable: false),
      attachments: attachmentResponse
          .map(
            (row) => EvernoteHistoryAttachmentSnapshot.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<void> markVersionVerified({
    required int batchId,
    required String sourceItemKey,
    required String historyItemKey,
    required String archiveSha256,
    required Map<String, bool> checks,
  }) async {
    await _client.rpc(
      'evernote_verify_note_history_version',
      params: <String, dynamic>{
        'p_batch_id': batchId,
        'p_source_item_key': sourceItemKey,
        'p_history_item_key': historyItemKey,
        'p_source_export_sha256': archiveSha256,
        'p_verification_checks': checks,
      },
    );
  }
}

/// Migrates a separately exported Evernote history revision from private
/// Storage. A multi-note ENEX is rejected because Evernote exposes history
/// revisions one at a time.
class EvernoteNoteHistoryMigrationService {
  EvernoteNoteHistoryMigrationService({
    required this.storage,
    required this.database,
    EvernoteEnexParser parser = const EvernoteEnexParser(),
  }) : _parser = parser;

  factory EvernoteNoteHistoryMigrationService.supabase(
    SupabaseClient client,
  ) =>
      EvernoteNoteHistoryMigrationService(
        storage: SupabaseEvernoteMigrationStorageGateway(client),
        database: SupabaseEvernoteNoteHistoryDatabaseGateway(client),
      );

  final EvernoteMigrationStorageGateway storage;
  final EvernoteNoteHistoryDatabaseGateway database;
  final EvernoteEnexParser _parser;

  Future<void> reviewInventory({
    required int batchId,
    required String sourceItemKey,
    required int sourceVersionCount,
  }) async {
    if (batchId <= 0 || sourceItemKey.trim().isEmpty) {
      throw ArgumentError('A valid Evernote migration item is required.');
    }
    if (sourceVersionCount < 0) {
      throw ArgumentError.value(
        sourceVersionCount,
        'sourceVersionCount',
        'must not be negative',
      );
    }
    await database.markInventoryReviewed(
      batchId: batchId,
      sourceItemKey: sourceItemKey.trim(),
      sourceVersionCount: sourceVersionCount,
    );
  }

  Future<EvernoteNoteHistoryMigrationResult> migrateFromArchive({
    required String userId,
    required int batchId,
    required String sourceItemKey,
    required int archiveBytes,
    required String archiveSha256,
  }) async {
    final ownerId = userId.trim();
    final itemKey = sourceItemKey.trim();
    final expectedHash = archiveSha256.trim().toLowerCase();
    if (ownerId.isEmpty || ownerId.contains('/') || ownerId.contains('\\')) {
      throw ArgumentError.value(userId, 'userId', 'Invalid owner id.');
    }
    if (batchId <= 0 || itemKey.isEmpty) {
      throw ArgumentError('A valid Evernote migration item is required.');
    }
    if (archiveBytes <= 0 || archiveBytes > evernoteMigrationMaxObjectBytes) {
      throw StateError(
        'The history ENEX must be between 1 byte and '
        '$evernoteMigrationMaxObjectBytes bytes.',
      );
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedHash)) {
      throw ArgumentError.value(
        archiveSha256,
        'archiveSha256',
        'A lowercase SHA-256 is required.',
      );
    }

    final archivePath = '$ownerId/evernote-history/$expectedHash/source.enex';
    if (!await storage.objectExists(
      bucketId: evernoteArchiveBucket,
      path: archivePath,
    )) {
      throw StateError('The staged Evernote history archive is missing.');
    }

    var auditedNoteCount = 0;
    final audit = await _parser.parseStream(
      storage.downloadStream(
        bucketId: evernoteArchiveBucket,
        path: archivePath,
      ),
      totalBytes: archiveBytes,
      onNote: (note) {
        auditedNoteCount += 1;
        if (auditedNoteCount > 1) {
          throw StateError(
            'Export and migrate exactly one Evernote history revision at a time.',
          );
        }
        if (note.updatedAt == null && note.createdAt == null) {
          throw StateError(
            'The Evernote history revision has no recoverable timestamp.',
          );
        }
        for (final resource in note.resources) {
          if (resource.data.isEmpty ||
              resource.data.length > evernoteMigrationMaxObjectBytes) {
            throw StateError(
              'Every history attachment must contain data and stay within '
              'the migration object limit.',
            );
          }
        }
      },
    );
    if (audit.exportSha256 != expectedHash ||
        audit.noteCount != 1 ||
        auditedNoteCount != 1 ||
        audit.warnings.isNotEmpty) {
      throw StateError(
        'The staged Evernote history archive did not pass lossless audit.',
      );
    }

    String? versionId;
    EvernoteEnexNote? importedNote;
    String? importedContent;
    DateTime? importedSavedAt;
    String? historyItemKey;
    List<EvernoteMigrationResourceManifest>? importedResources;

    final commitSummary = await _parser.parseStream(
      storage.downloadStream(
        bucketId: evernoteArchiveBucket,
        path: archivePath,
      ),
      totalBytes: archiveBytes,
      onNote: (note) async {
        if (importedNote != null) {
          throw StateError('The history ENEX changed during migration.');
        }
        final savedAt = (note.updatedAt ?? note.createdAt)!.toUtc();
        final itemVersionKey =
            'history:${savedAt.toIso8601String()}:${note.sourceId}';
        final notePathToken = sha256
            .convert(utf8.encode(note.sourceId))
            .toString()
            .substring(0, 32);
        final manifests = <EvernoteMigrationResourceManifest>[];
        final resourceUrlsByHash = <String, String>{};

        for (var index = 0; index < note.resources.length; index += 1) {
          final resource = note.resources[index];
          final candidate = resource.fileName?.trim().isNotEmpty == true
              ? resource.fileName!.trim()
              : 'resource-${index.toString().padLeft(4, '0')}';
          final fileName =
              DirectStorageUploadService.sanitizeFileName(candidate);
          final mimeType = resource.mimeType.trim().isEmpty
              ? 'application/octet-stream'
              : resource.mimeType.trim();
          final path = '$ownerId/evernote-history/$expectedHash/'
              '$notePathToken/'
              '${index.toString().padLeft(4, '0')}-'
              '${resource.dataSha256}-$fileName';
          final sourceHash = resource.evernoteHash?.trim().toLowerCase();
          if (sourceHash != null && sourceHash.isNotEmpty) {
            resourceUrlsByHash[sourceHash] =
                'attachment:${Uri.encodeComponent(path)}';
          }
          await _ensureVerifiedObject(
            path: path,
            bytes: resource.data,
            mimeType: mimeType,
            expectedSha256: resource.dataSha256,
          );
          manifests.add(
            EvernoteMigrationResourceManifest(
              fileName: fileName,
              filePath: path,
              fileSize: resource.data.length,
              fileType: _fileType(mimeType),
              mimeType: mimeType,
              contentSha256: resource.dataSha256,
              sourceMetadata: <String, dynamic>{
                'resource_index': index,
                'evernote_hash': resource.evernoteHash,
                'recognition_xml': resource.recognitionXml,
                'alternate_data': resource.alternateData,
                'attributes': resource.attributes,
                'raw_resource_xml_sha256':
                    sha256.convert(utf8.encode(resource.rawXml)).toString(),
              },
            ),
          );
        }

        final content = EvernoteEnmlMarkdownConverter.resolveResourceUrls(
          note.markdownText,
          resourceUrlsByHash,
        );
        if (content.contains('$evernoteResourceScheme:')) {
          throw StateError(
            'A historical attachment position could not be resolved.',
          );
        }
        versionId = await database.commitVersion(
          batchId: batchId,
          sourceItemKey: itemKey,
          historyItemKey: itemVersionKey,
          note: note,
          content: content,
          savedAt: savedAt,
          sourceMetadata: <String, dynamic>{
            'source_guid': note.sourceGuid,
            'attributes': note.attributes,
            'links': note.links,
            'raw_note_xml_sha256':
                sha256.convert(utf8.encode(note.rawXml)).toString(),
            'archive_path': archivePath,
          },
          resources: manifests,
          archivePath: archivePath,
          archiveSha256: expectedHash,
        );
        importedNote = note;
        importedContent = content;
        importedSavedAt = savedAt;
        historyItemKey = itemVersionKey;
        importedResources = manifests;
      },
    );

    if (commitSummary.exportSha256 != expectedHash ||
        commitSummary.noteCount != 1 ||
        commitSummary.resourceCount != audit.resourceCount ||
        commitSummary.warnings.isNotEmpty ||
        versionId == null ||
        importedNote == null ||
        importedContent == null ||
        importedSavedAt == null ||
        historyItemKey == null ||
        importedResources == null) {
      throw StateError(
        'The Evernote history archive changed during migration.',
      );
    }

    final snapshot = await database.loadVersion(
      noteVersionId: versionId!,
    );
    final expectedByPath = <String, EvernoteMigrationResourceManifest>{
      for (final resource in importedResources!) resource.filePath: resource,
    };
    var resourceHashesMatch =
        snapshot.attachments.length == expectedByPath.length;
    if (resourceHashesMatch) {
      for (final attachment in snapshot.attachments) {
        final expected = expectedByPath[attachment.filePath];
        if (expected == null ||
            attachment.fileSize != expected.fileSize ||
            attachment.mimeType != expected.mimeType ||
            attachment.contentSha256 != expected.contentSha256 ||
            await _hashStoredObject(
                  path: attachment.filePath,
                  expectedBytes: expected.fileSize,
                ) !=
                expected.contentSha256) {
          resourceHashesMatch = false;
          break;
        }
      }
    }

    final checks = <String, bool>{
      'archive_sha256': commitSummary.exportSha256 == expectedHash,
      'content_sha256': snapshot.id == versionId &&
          snapshot.title == importedNote!.title &&
          snapshot.content == importedContent &&
          snapshot.sourceContentSha256 == importedNote!.contentSha256 &&
          _sameStrings(snapshot.tags, importedNote!.tags),
      'timestamp': snapshot.savedAt.toUtc().microsecondsSinceEpoch ==
          importedSavedAt!.microsecondsSinceEpoch,
      'resource_count':
          snapshot.attachments.length == importedResources!.length,
      'resource_sha256': resourceHashesMatch,
    };
    if (checks.values.any((passed) => !passed)) {
      final failed = checks.entries
          .where((entry) => !entry.value)
          .map((entry) => entry.key)
          .join(', ');
      throw StateError('Evernote history verification failed: $failed.');
    }

    await database.markVersionVerified(
      batchId: batchId,
      sourceItemKey: itemKey,
      historyItemKey: historyItemKey!,
      archiveSha256: expectedHash,
      checks: checks,
    );
    return EvernoteNoteHistoryMigrationResult(
      noteVersionId: versionId!,
      archiveSha256: expectedHash,
      resourceCount: importedResources!.length,
    );
  }

  Future<void> _ensureVerifiedObject({
    required String path,
    required Uint8List bytes,
    required String mimeType,
    required String expectedSha256,
  }) async {
    Object? uploadError;
    StackTrace? uploadStackTrace;
    try {
      await storage.uploadBinary(
        bucketId: evernoteAttachmentBucket,
        path: path,
        bytes: bytes,
        contentType: mimeType,
      );
    } catch (error, stackTrace) {
      uploadError = error;
      uploadStackTrace = stackTrace;
    }

    try {
      final storedSha256 = await _hashStoredObject(
        path: path,
        expectedBytes: bytes.length,
      );
      if (storedSha256 != expectedSha256) {
        throw StateError('Stored Evernote history attachment hash mismatch.');
      }
    } catch (_) {
      if (uploadError != null) {
        Error.throwWithStackTrace(uploadError, uploadStackTrace!);
      }
      rethrow;
    }
  }

  Future<String> _hashStoredObject({
    required String path,
    required int expectedBytes,
  }) async {
    final output = _HistoryDigestSink();
    final input = sha256.startChunkedConversion(output);
    var processedBytes = 0;
    await for (final chunk in storage.downloadStream(
      bucketId: evernoteAttachmentBucket,
      path: path,
    )) {
      processedBytes += chunk.length;
      if (processedBytes > expectedBytes) {
        throw StateError('Stored history attachment is larger than expected.');
      }
      input.add(chunk);
    }
    input.close();
    if (processedBytes != expectedBytes) {
      throw StateError('Stored history attachment size does not match.');
    }
    return output.value.toString();
  }

  String _fileType(String mimeType) {
    if (mimeType.startsWith('image/')) return 'image';
    if (mimeType == 'application/pdf') return 'pdf';
    if (mimeType.startsWith('audio/')) return 'audio';
    if (mimeType.startsWith('video/')) return 'video';
    return 'other';
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

class _HistoryDigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value {
    final digest = _value;
    if (digest == null) throw StateError('Digest has not completed.');
    return digest;
  }

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}

Map<String, dynamic> _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw StateError('Expected a JSON object from Evernote history RPC.');
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _asDateTime(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw StateError('Expected a valid Evernote history timestamp.');
  }
  return parsed.toUtc();
}
