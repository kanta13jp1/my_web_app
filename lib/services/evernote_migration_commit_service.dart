import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'direct_storage_upload_service.dart';
import 'evernote_enex_parser.dart';
import 'evernote_enml_markdown_converter.dart';
import 'evernote_migration_ledger_service.dart';
import 'evernote_storage_stream_service.dart';
import 'evernote_tus_resume_store.dart';
import 'evernote_tus_upload_service.dart';
import 'import_service.dart';

const String evernoteArchiveBucket = 'evernote-migration-archives';
const String evernoteAttachmentBucket = 'attachments';
const int evernoteMigrationMaxObjectBytes = 100 * 1024 * 1024;

typedef EvernoteMigrationTransferProgressCallback = void Function(
  EvernoteMigrationTransferProgress progress,
);

enum EvernoteMigrationTransferState {
  preparing,
  uploading,
  resuming,
  verifying,
  completed,
  failed;

  String get label {
    switch (this) {
      case EvernoteMigrationTransferState.preparing:
        return 'Preparing';
      case EvernoteMigrationTransferState.uploading:
        return 'Uploading';
      case EvernoteMigrationTransferState.resuming:
        return 'Resuming';
      case EvernoteMigrationTransferState.verifying:
        return 'Verifying';
      case EvernoteMigrationTransferState.completed:
        return 'Completed';
      case EvernoteMigrationTransferState.failed:
        return 'Failed';
    }
  }
}

class EvernoteMigrationTransferProgress {
  const EvernoteMigrationTransferProgress({
    required this.state,
    required this.stageLabel,
    required this.objectIndex,
    required this.objectCount,
    required this.transferredBytes,
    required this.totalBytes,
  });

  final EvernoteMigrationTransferState state;
  final String stageLabel;
  final int objectIndex;
  final int objectCount;
  final int transferredBytes;
  final int totalBytes;

  double get fraction {
    if (totalBytes <= 0) return 0;
    return (transferredBytes / totalBytes).clamp(0.0, 1.0).toDouble();
  }

  int get percent => (fraction * 100).round();
}

class EvernoteMigrationSourceContext {
  const EvernoteMigrationSourceContext({
    required this.notebookName,
    this.stackName,
    this.spaceName,
  });

  final String notebookName;
  final String? stackName;
  final String? spaceName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'notebook_name': notebookName.trim(),
        'stack_name': _trimmedOrNull(stackName),
        'space_name': _trimmedOrNull(spaceName),
      };
}

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
    required this.notebookCollectionId,
    required this.attachments,
    required this.taskSourceSha256,
    required this.taskReminderSourceSha256,
    required this.noteReminderSourceSha256,
  });

  final int noteId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final int? notebookCollectionId;
  final List<EvernoteCommittedAttachmentSnapshot> attachments;
  final List<String> taskSourceSha256;
  final List<String> taskReminderSourceSha256;
  final String? noteReminderSourceSha256;
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
    void Function(int uploadedBytes, int totalBytes)? onProgress,
  });

  Future<Uint8List> downloadBinary({
    required String bucketId,
    required String path,
  });

  Stream<List<int>> downloadStream({
    required String bucketId,
    required String path,
  });

  Future<void> uploadStream({
    required String bucketId,
    required String path,
    required Stream<List<int>> source,
    required int totalBytes,
    required String contentType,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
  });

  Future<void> copyObject({
    required String bucketId,
    required String sourcePath,
    required String destinationPath,
  });

  Future<bool> objectExists({
    required String bucketId,
    required String path,
  });
}

class SupabaseEvernoteMigrationStorageGateway
    implements EvernoteMigrationStorageGateway {
  SupabaseEvernoteMigrationStorageGateway(
    this._client, {
    EvernoteTusResumeStore? resumeStore,
  }) : _resumeStore = resumeStore ?? SharedPreferencesEvernoteTusResumeStore();

  final SupabaseClient _client;
  final EvernoteTusResumeStore _resumeStore;
  final Map<String, Uri> _resumableUploadUrls = <String, Uri>{};

  @override
  Future<void> uploadBinary({
    required String bucketId,
    required String path,
    required Uint8List bytes,
    required String contentType,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
  }) async {
    if (bytes.length > evernoteTusRecommendedThresholdBytes) {
      await _uploadResumable(
        bucketId: bucketId,
        path: path,
        bytes: bytes,
        contentType: contentType,
        onProgress: onProgress,
      );
      return;
    }
    onProgress?.call(0, bytes.length);
    await _client.storage.from(bucketId).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );
    onProgress?.call(bytes.length, bytes.length);
  }

  Future<void> _uploadResumable({
    required String bucketId,
    required String path,
    required Uint8List bytes,
    required String contentType,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
  }) async {
    await _uploadResumableStream(
      bucketId: bucketId,
      path: path,
      source: _memoryBoundedByteStream(bytes),
      totalBytes: bytes.length,
      contentType: contentType,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> uploadStream({
    required String bucketId,
    required String path,
    required Stream<List<int>> source,
    required int totalBytes,
    required String contentType,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
  }) async {
    if (totalBytes <= 0 || totalBytes > evernoteMigrationMaxObjectBytes) {
      throw StateError(
        'The streamed Evernote object must be between 1 byte and '
        '$evernoteMigrationMaxObjectBytes bytes.',
      );
    }
    await _uploadResumableStream(
      bucketId: bucketId,
      path: path,
      source: source,
      totalBytes: totalBytes,
      contentType: contentType,
      onProgress: onProgress,
    );
  }

  Future<void> _uploadResumableStream({
    required String bucketId,
    required String path,
    required Stream<List<int>> source,
    required int totalBytes,
    required String contentType,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null || session.accessToken.trim().isEmpty) {
      throw StateError('Sign in again before uploading the Evernote batch.');
    }
    final endpoint = EvernoteTusUploadService.endpointForSupabaseUrl(
      _client.storage.url,
    );
    final uploadKey = '$bucketId/$path';
    final persistedUploadUrl = _resumableUploadUrls[uploadKey] ??
        await _loadResumeUrl(
          endpoint: endpoint,
          bucketId: bucketId,
          path: path,
        );
    final transport = http.Client();
    try {
      final uploader = EvernoteTusUploadService(client: transport);
      await uploader.upload(
        endpoint: endpoint,
        accessToken: session.accessToken,
        source: source,
        totalBytes: totalBytes,
        bucketId: bucketId,
        objectPath: path,
        contentType: contentType,
        previousUploadUrl: persistedUploadUrl,
        onUploadUrl: (uploadUrl) async {
          _resumableUploadUrls[uploadKey] = uploadUrl;
          await _saveResumeUrl(
            endpoint: endpoint,
            bucketId: bucketId,
            path: path,
            uploadUrl: uploadUrl,
          );
        },
        onProgress: onProgress,
      );
      _resumableUploadUrls.remove(uploadKey);
      await _removeResumeUrl(bucketId: bucketId, path: path);
    } finally {
      transport.close();
    }
  }

  Future<Uri?> _loadResumeUrl({
    required Uri endpoint,
    required String bucketId,
    required String path,
  }) async {
    try {
      return await _resumeStore.load(
        endpoint: endpoint,
        bucketId: bucketId,
        objectPath: path,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveResumeUrl({
    required Uri endpoint,
    required String bucketId,
    required String path,
    required Uri uploadUrl,
  }) async {
    try {
      await _resumeStore.save(
        endpoint: endpoint,
        bucketId: bucketId,
        objectPath: path,
        uploadUrl: uploadUrl,
      );
    } catch (_) {
      // Browser storage may be unavailable. The active upload can still finish.
    }
  }

  Future<void> _removeResumeUrl({
    required String bucketId,
    required String path,
  }) async {
    try {
      await _resumeStore.remove(bucketId: bucketId, objectPath: path);
    } catch (_) {
      // An expired URL is safely rejected on the next attempt.
    }
  }

  @override
  Future<Uint8List> downloadBinary({
    required String bucketId,
    required String path,
  }) {
    return _client.storage.from(bucketId).download(path);
  }

  @override
  Stream<List<int>> downloadStream({
    required String bucketId,
    required String path,
  }) async* {
    final session = _client.auth.currentSession;
    if (session == null || session.accessToken.trim().isEmpty) {
      throw StateError('Sign in again before reading the Evernote batch.');
    }
    final transport = http.Client();
    try {
      final service = EvernoteStorageStreamService(client: transport);
      yield* service.download(
        storageBaseUrl: Uri.parse(_client.storage.url),
        headers: <String, String>{
          ..._client.storage.headers,
          'Authorization': 'Bearer ${session.accessToken}',
        },
        bucketId: bucketId,
        objectPath: path,
      );
    } finally {
      transport.close();
    }
  }

  @override
  Future<void> copyObject({
    required String bucketId,
    required String sourcePath,
    required String destinationPath,
  }) async {
    await _client.storage.from(bucketId).copy(sourcePath, destinationPath);
  }

  @override
  Future<bool> objectExists({
    required String bucketId,
    required String path,
  }) async {
    final segments = path.split('/');
    if (segments.isEmpty ||
        segments.any((segment) => segment.isEmpty || segment == '..')) {
      throw ArgumentError.value(path, 'path', 'Invalid Storage object path.');
    }
    final fileName = segments.removeLast();
    final folder = segments.join('/');
    final objects = await _client.storage.from(bucketId).list(
          path: folder,
          searchOptions: SearchOptions(limit: 100, search: fileName),
        );
    return objects.any((object) => object.name == fileName);
  }
}

abstract class EvernoteMigrationDatabaseGateway {
  Future<int> commitNote({
    required int batchId,
    required String sourceItemKey,
    required EvernoteEnexNote note,
    required String content,
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
    required String content,
    required Map<String, dynamic> sourceMetadata,
    required List<EvernoteMigrationResourceManifest> resources,
    required String archivePath,
  }) async {
    final response = await _client.rpc(
      'evernote_commit_note_with_features',
      params: <String, dynamic>{
        'p_batch_id': batchId,
        'p_source_item_key': sourceItemKey,
        'p_title': note.title,
        'p_content': content,
        'p_source_created_at': note.createdAt?.toUtc().toIso8601String(),
        'p_source_updated_at': note.updatedAt?.toUtc().toIso8601String(),
        'p_tags': note.tags,
        'p_source_enml': note.enml,
        'p_source_metadata': sourceMetadata,
        'p_tasks': sourceMetadata['tasks'] ?? const <dynamic>[],
        'p_note_reminder': sourceMetadata['note_reminder'],
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
        .select(
          'id,title,content,created_at,updated_at,tags,'
          'notebook_collection_id',
        )
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
    final taskResponse = await _client
        .from('note_tasks')
        .select('source_sha256')
        .eq('note_id', noteId)
        .eq('source_system', 'evernote')
        .order('source_sha256');
    final taskReminderResponse = await _client
        .from('note_task_reminders')
        .select('source_sha256')
        .eq('note_id', noteId)
        .eq('source_system', 'evernote')
        .order('source_sha256');
    final noteReminderResponse = await _client
        .from('note_reminders')
        .select('source_sha256')
        .eq('note_id', noteId)
        .eq('source_system', 'evernote')
        .limit(1);
    final taskSourceSha256 = taskResponse
        .map(
          (row) =>
              Map<String, dynamic>.from(row)['source_sha256']?.toString() ?? '',
        )
        .toList(growable: false);
    final taskReminderSourceSha256 = taskReminderResponse
        .map(
          (row) =>
              Map<String, dynamic>.from(row)['source_sha256']?.toString() ?? '',
        )
        .toList(growable: false);
    final noteReminderSourceSha256 = noteReminderResponse.isEmpty
        ? null
        : Map<String, dynamic>.from(noteReminderResponse.first)['source_sha256']
            ?.toString();
    return EvernoteCommittedNoteSnapshot(
      noteId: _asInt(noteJson['id']),
      title: noteJson['title']?.toString() ?? '',
      content: noteJson['content']?.toString() ?? '',
      createdAt: _asDateTime(noteJson['created_at']),
      updatedAt: _asDateTime(noteJson['updated_at']),
      tags: (noteJson['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(growable: false),
      notebookCollectionId: noteJson['notebook_collection_id'] == null
          ? null
          : _asInt(noteJson['notebook_collection_id']),
      attachments: attachments,
      taskSourceSha256: taskSourceSha256,
      taskReminderSourceSha256: taskReminderSourceSha256,
      noteReminderSourceSha256: noteReminderSourceSha256,
    );
  }

  @override
  Future<void> markNoteVerified({
    required int batchId,
    required String sourceItemKey,
    required Map<String, bool> checks,
  }) async {
    await _client.rpc(
      'evernote_verify_note_with_features',
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
    required EvernoteMigrationSourceContext sourceContext,
    EvernoteMigrationTransferProgressCallback? onTransferProgress,
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
    final notebookName = sourceContext.notebookName.trim();
    if (notebookName.isEmpty || notebookName.length > 200) {
      throw ArgumentError.value(
        sourceContext.notebookName,
        'sourceContext.notebookName',
        'Evernote notebook name must contain 1 to 200 characters.',
      );
    }
    for (final entry in <String, String?>{
      'sourceContext.stackName': sourceContext.stackName,
      'sourceContext.spaceName': sourceContext.spaceName,
    }.entries) {
      if ((entry.value?.trim().length ?? 0) > 200) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Evernote hierarchy names must not exceed 200 characters.',
        );
      }
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

    final transferObjectCount = 1 + export.resourceCount;
    final transferTotalBytes = exportBytes.length +
        export.notes.fold<int>(
          0,
          (noteTotal, note) =>
              noteTotal +
              note.resources.fold<int>(
                0,
                (resourceTotal, resource) =>
                    resourceTotal + resource.data.length,
              ),
        );
    var transferredBytes = 0;
    var transferObjectIndex = 0;

    Future<void> transferObject({
      required String stageLabel,
      required String bucketId,
      required String path,
      required Uint8List bytes,
      required String contentType,
      required String expectedSha256,
    }) async {
      transferObjectIndex += 1;
      final objectStartBytes = transferredBytes;
      onTransferProgress?.call(
        EvernoteMigrationTransferProgress(
          state: EvernoteMigrationTransferState.preparing,
          stageLabel: stageLabel,
          objectIndex: transferObjectIndex,
          objectCount: transferObjectCount,
          transferredBytes: objectStartBytes,
          totalBytes: transferTotalBytes,
        ),
      );
      var lastObjectBytes = 0;
      var observedObjectProgress = false;
      try {
        await _ensureVerifiedObject(
          bucketId: bucketId,
          path: path,
          bytes: bytes,
          contentType: contentType,
          expectedSha256: expectedSha256,
          onProgress: (objectBytes, objectTotalBytes) {
            final isFirstProgress = !observedObjectProgress;
            observedObjectProgress = true;
            final boundedObjectBytes =
                objectBytes.clamp(0, objectTotalBytes).toInt();
            lastObjectBytes = boundedObjectBytes;
            final state = boundedObjectBytes >= objectTotalBytes
                ? EvernoteMigrationTransferState.verifying
                : isFirstProgress && boundedObjectBytes > 0
                    ? EvernoteMigrationTransferState.resuming
                    : EvernoteMigrationTransferState.uploading;
            onTransferProgress?.call(
              EvernoteMigrationTransferProgress(
                state: state,
                stageLabel: stageLabel,
                objectIndex: transferObjectIndex,
                objectCount: transferObjectCount,
                transferredBytes: objectStartBytes + boundedObjectBytes,
                totalBytes: transferTotalBytes,
              ),
            );
          },
        );
      } catch (_) {
        onTransferProgress?.call(
          EvernoteMigrationTransferProgress(
            state: EvernoteMigrationTransferState.failed,
            stageLabel: stageLabel,
            objectIndex: transferObjectIndex,
            objectCount: transferObjectCount,
            transferredBytes: objectStartBytes + lastObjectBytes,
            totalBytes: transferTotalBytes,
          ),
        );
        rethrow;
      }
      transferredBytes = objectStartBytes + bytes.length;
      onTransferProgress?.call(
        EvernoteMigrationTransferProgress(
          state: EvernoteMigrationTransferState.completed,
          stageLabel: stageLabel,
          objectIndex: transferObjectIndex,
          objectCount: transferObjectCount,
          transferredBytes: transferredBytes,
          totalBytes: transferTotalBytes,
        ),
      );
    }

    final batch = await ledger.recordPreview(
      userId: ownerId,
      preview: preview,
    );
    final archivePath = '$ownerId/evernote/${export.exportSha256}/source.enex';
    await transferObject(
      stageLabel: 'Recovery archive',
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
      final resourceUrlsByHash = <String, String>{};
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
        final sourceHash = resource.evernoteHash?.trim().toLowerCase();
        if (sourceHash != null && sourceHash.isNotEmpty) {
          resourceUrlsByHash[sourceHash] = _attachmentMarkdownUrl(path);
        }
        await transferObject(
          stageLabel: 'Attachment',
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

      final editableContent = EvernoteEnmlMarkdownConverter.resolveResourceUrls(
        note.markdownText,
        resourceUrlsByHash,
      );
      if (editableContent.contains('$evernoteResourceScheme:')) {
        throw StateError(
          'One or more Evernote attachment positions could not be resolved.',
        );
      }

      final noteId = await database.commitNote(
        batchId: batch.id,
        sourceItemKey: sourceItemKey,
        note: note,
        content: editableContent,
        sourceMetadata: <String, dynamic>{
          'source_guid': note.sourceGuid,
          'content_sha256': note.contentSha256,
          'attributes': note.attributes,
          'has_encrypted_text': note.enml.toLowerCase().contains('<en-crypt'),
          'links': note.links,
          'tasks': _evernoteTaskPayloads(note),
          'note_reminder': _evernoteNoteReminderPayload(note),
          'raw_note_xml_sha256':
              sha256.convert(utf8.encode(note.rawXml)).toString(),
          'archive_path': archivePath,
          'source_export_file_name': preview.fileName,
          'source_context': sourceContext.toJson(),
        },
        resources: manifests,
        archivePath: archivePath,
      );
      committed.add(
        _CommittedEvernoteNote(
          note: note,
          sourceItemKey: sourceItemKey,
          noteId: noteId,
          content: editableContent,
          resources: manifests,
        ),
      );
    }

    final archivedSha256 = await _hashStoredObject(
      bucketId: evernoteArchiveBucket,
      path: archivePath,
      expectedBytes: exportBytes.length,
    );
    final archiveVerified = archivedSha256 == export.exportSha256;
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

  /// Commits an ENEX archive that was already streamed to private Storage.
  ///
  /// The archive is parsed twice. The first pass verifies the immutable source
  /// and calculates bounded transfer totals before any database mutation. The
  /// second pass uploads and verifies one note's resources, commits that note,
  /// and releases the note subtree before reading the next one.
  Future<EvernoteMigrationCommitResult> commitFromArchive({
    required String userId,
    required int archiveBytes,
    required ImportPreviewResult preview,
    required EvernoteMigrationSourceContext sourceContext,
    EvernoteMigrationTransferProgressCallback? onTransferProgress,
  }) async {
    final ownerId = userId.trim();
    if (ownerId.isEmpty || ownerId.contains('/') || ownerId.contains(r'\')) {
      throw ArgumentError.value(userId, 'userId', 'Invalid owner id.');
    }
    if (archiveBytes <= 0 || archiveBytes > evernoteMigrationMaxObjectBytes) {
      throw StateError(
        'The ENEX archive must be between 1 byte and '
        '$evernoteMigrationMaxObjectBytes bytes.',
      );
    }
    if (preview.sourceType != 'evernote') {
      throw ArgumentError('An Evernote preview is required.');
    }
    if (preview.commitBlockedReason != null) {
      throw StateError(preview.commitBlockedReason!);
    }
    final exportSha256 = preview.sourceExportSha256?.trim().toLowerCase();
    if (exportSha256 == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(exportSha256)) {
      throw StateError('The Evernote preview SHA-256 is unavailable.');
    }
    final notebookName = sourceContext.notebookName.trim();
    if (notebookName.isEmpty || notebookName.length > 200) {
      throw ArgumentError.value(
        sourceContext.notebookName,
        'sourceContext.notebookName',
        'Evernote notebook name must contain 1 to 200 characters.',
      );
    }
    for (final entry in <String, String?>{
      'sourceContext.stackName': sourceContext.stackName,
      'sourceContext.spaceName': sourceContext.spaceName,
    }.entries) {
      if ((entry.value?.trim().length ?? 0) > 200) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Evernote hierarchy names must not exceed 200 characters.',
        );
      }
    }

    final expectedBySourceId = <String, ImportedNoteDraft>{};
    for (final draft in preview.notes) {
      final sourceId = draft.sourceId?.trim();
      if (sourceId == null || sourceId.isEmpty) {
        throw StateError('Every streamed Evernote preview note needs an id.');
      }
      if (expectedBySourceId.containsKey(sourceId)) {
        throw StateError('The Evernote preview contains duplicate note ids.');
      }
      expectedBySourceId[sourceId] = draft;
    }

    final archivePath = '$ownerId/evernote/$exportSha256/source.enex';
    var resourceBytes = 0;
    final auditedSourceIds = <String>{};
    final audit = await _parser.parseStream(
      storage.downloadStream(
        bucketId: evernoteArchiveBucket,
        path: archivePath,
      ),
      totalBytes: archiveBytes,
      onNote: (note) {
        if (!auditedSourceIds.add(note.sourceId)) {
          throw StateError('The ENEX archive contains duplicate note ids.');
        }
        final expected = expectedBySourceId[note.sourceId];
        if (expected == null || !_matchesPreview(note, expected)) {
          throw StateError('The cloud ENEX no longer matches its preview.');
        }
        for (final resource in note.resources) {
          if (resource.data.isEmpty ||
              resource.data.length > evernoteMigrationMaxObjectBytes) {
            throw StateError(
              'Every attachment must contain data and be no larger than '
              '$evernoteMigrationMaxObjectBytes bytes.',
            );
          }
          resourceBytes += resource.data.length;
        }
      },
    );
    if (audit.exportSha256 != exportSha256 ||
        audit.noteCount != preview.notes.length ||
        audit.resourceCount != preview.resourceCount ||
        audit.warnings.isNotEmpty ||
        auditedSourceIds.length != expectedBySourceId.length) {
      throw StateError('The cloud ENEX archive audit did not match preview.');
    }

    final batch = await ledger.recordPreview(
      userId: ownerId,
      preview: preview,
    );
    final transferObjectCount = 1 + audit.resourceCount;
    final transferTotalBytes = archiveBytes + resourceBytes;
    var transferObjectIndex = 1;
    var transferredBytes = archiveBytes;
    onTransferProgress?.call(
      EvernoteMigrationTransferProgress(
        state: EvernoteMigrationTransferState.completed,
        stageLabel: 'Recovery archive',
        objectIndex: transferObjectIndex,
        objectCount: transferObjectCount,
        transferredBytes: transferredBytes,
        totalBytes: transferTotalBytes,
      ),
    );

    final noteIds = <int>[];
    final committedSourceIds = <String>{};
    var importedCount = 0;
    var verifiedCount = 0;

    Future<void> transferResource({
      required String path,
      required Uint8List bytes,
      required String contentType,
      required String expectedSha256,
    }) async {
      transferObjectIndex += 1;
      final objectStartBytes = transferredBytes;
      var lastObjectBytes = 0;
      var observedObjectProgress = false;
      onTransferProgress?.call(
        EvernoteMigrationTransferProgress(
          state: EvernoteMigrationTransferState.preparing,
          stageLabel: 'Attachment',
          objectIndex: transferObjectIndex,
          objectCount: transferObjectCount,
          transferredBytes: objectStartBytes,
          totalBytes: transferTotalBytes,
        ),
      );
      try {
        await _ensureVerifiedObject(
          bucketId: evernoteAttachmentBucket,
          path: path,
          bytes: bytes,
          contentType: contentType,
          expectedSha256: expectedSha256,
          onProgress: (objectBytes, objectTotalBytes) {
            final isFirstProgress = !observedObjectProgress;
            observedObjectProgress = true;
            final boundedObjectBytes =
                objectBytes.clamp(0, objectTotalBytes).toInt();
            lastObjectBytes = boundedObjectBytes;
            final state = boundedObjectBytes >= objectTotalBytes
                ? EvernoteMigrationTransferState.verifying
                : isFirstProgress && boundedObjectBytes > 0
                    ? EvernoteMigrationTransferState.resuming
                    : EvernoteMigrationTransferState.uploading;
            onTransferProgress?.call(
              EvernoteMigrationTransferProgress(
                state: state,
                stageLabel: 'Attachment',
                objectIndex: transferObjectIndex,
                objectCount: transferObjectCount,
                transferredBytes: objectStartBytes + boundedObjectBytes,
                totalBytes: transferTotalBytes,
              ),
            );
          },
        );
      } catch (_) {
        onTransferProgress?.call(
          EvernoteMigrationTransferProgress(
            state: EvernoteMigrationTransferState.failed,
            stageLabel: 'Attachment',
            objectIndex: transferObjectIndex,
            objectCount: transferObjectCount,
            transferredBytes: objectStartBytes + lastObjectBytes,
            totalBytes: transferTotalBytes,
          ),
        );
        rethrow;
      }
      transferredBytes = objectStartBytes + bytes.length;
      onTransferProgress?.call(
        EvernoteMigrationTransferProgress(
          state: EvernoteMigrationTransferState.completed,
          stageLabel: 'Attachment',
          objectIndex: transferObjectIndex,
          objectCount: transferObjectCount,
          transferredBytes: transferredBytes,
          totalBytes: transferTotalBytes,
        ),
      );
    }

    final committedSummary = await _parser.parseStream(
      storage.downloadStream(
        bucketId: evernoteArchiveBucket,
        path: archivePath,
      ),
      totalBytes: archiveBytes,
      onNote: (note) async {
        if (!committedSourceIds.add(note.sourceId)) {
          throw StateError('The ENEX archive contains duplicate note ids.');
        }
        final expected = expectedBySourceId[note.sourceId];
        if (expected == null || !_matchesPreview(note, expected)) {
          throw StateError('The cloud ENEX changed during commit.');
        }

        final sourceItemKey = 'id:${note.sourceId}';
        final notePathToken = sha256
            .convert(utf8.encode(note.sourceId))
            .toString()
            .substring(0, 32);
        final manifests = <EvernoteMigrationResourceManifest>[];
        final resourceUrlsByHash = <String, String>{};
        for (var resourceIndex = 0;
            resourceIndex < note.resources.length;
            resourceIndex += 1) {
          final resource = note.resources[resourceIndex];
          final fileName = _resourceFileName(resource, resourceIndex);
          final path = '$ownerId/evernote/$exportSha256/'
              '$notePathToken/'
              '${resourceIndex.toString().padLeft(4, '0')}-'
              '${resource.dataSha256}-$fileName';
          final mimeType = resource.mimeType.trim().isEmpty
              ? 'application/octet-stream'
              : resource.mimeType.trim();
          final sourceHash = resource.evernoteHash?.trim().toLowerCase();
          if (sourceHash != null && sourceHash.isNotEmpty) {
            resourceUrlsByHash[sourceHash] = _attachmentMarkdownUrl(path);
          }
          await transferResource(
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

        final editableContent =
            EvernoteEnmlMarkdownConverter.resolveResourceUrls(
          note.markdownText,
          resourceUrlsByHash,
        );
        if (editableContent.contains('$evernoteResourceScheme:')) {
          throw StateError(
            'One or more Evernote attachment positions could not be resolved.',
          );
        }
        final noteId = await database.commitNote(
          batchId: batch.id,
          sourceItemKey: sourceItemKey,
          note: note,
          content: editableContent,
          sourceMetadata: <String, dynamic>{
            'source_guid': note.sourceGuid,
            'content_sha256': note.contentSha256,
            'attributes': note.attributes,
            'has_encrypted_text': note.enml.toLowerCase().contains('<en-crypt'),
            'links': note.links,
            'tasks': _evernoteTaskPayloads(note),
            'note_reminder': _evernoteNoteReminderPayload(note),
            'raw_note_xml_sha256':
                sha256.convert(utf8.encode(note.rawXml)).toString(),
            'archive_path': archivePath,
            'source_export_file_name': preview.fileName,
            'source_context': sourceContext.toJson(),
            'streaming_commit': true,
          },
          resources: manifests,
          archivePath: archivePath,
        );
        final committed = _CommittedEvernoteNote(
          note: note,
          sourceItemKey: sourceItemKey,
          noteId: noteId,
          content: editableContent,
          resources: manifests,
        );
        await _verifyCommittedNote(
          batchId: batch.id,
          committed: committed,
          archiveVerified: true,
        );
        noteIds.add(noteId);
        importedCount += 1;
        verifiedCount += 1;
      },
    );

    if (committedSummary.exportSha256 != exportSha256 ||
        committedSummary.noteCount != audit.noteCount ||
        committedSummary.resourceCount != audit.resourceCount ||
        committedSummary.warnings.isNotEmpty ||
        committedSourceIds.length != expectedBySourceId.length ||
        transferredBytes != transferTotalBytes) {
      throw StateError('The streamed Evernote commit did not fully verify.');
    }

    return EvernoteMigrationCommitResult(
      batchId: batch.id,
      importedNoteCount: importedCount,
      verifiedNoteCount: verifiedCount,
      resourceCount: audit.resourceCount,
      archiveSha256: exportSha256,
      noteIds: List<int>.unmodifiable(noteIds),
    );
  }

  bool _matchesPreview(EvernoteEnexNote note, ImportedNoteDraft expected) {
    return expected.source == 'evernote' &&
        expected.sourceId == note.sourceId &&
        expected.title == note.title &&
        expected.sourceContentSha256 == note.contentSha256 &&
        expected.sourceResourceCount == note.resources.length &&
        _sameStrings(expected.tags, note.tags) &&
        _samePreviewInstant(expected.sourceCreatedAt, note.createdAt) &&
        _samePreviewInstant(expected.sourceUpdatedAt, note.updatedAt);
  }

  bool _samePreviewInstant(DateTime? left, DateTime? right) {
    if (left == null || right == null) return left == right;
    return left.toUtc().microsecondsSinceEpoch ==
        right.toUtc().microsecondsSinceEpoch;
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
        snapshot.content == committed.content;
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
        final storedSha256 = await _hashStoredObject(
          bucketId: evernoteAttachmentBucket,
          path: attachment.filePath,
          expectedBytes: expected.fileSize,
        );
        if (storedSha256 != expected.contentSha256) {
          resourceHashesMatch = false;
          break;
        }
      }
    }

    final expectedTaskPayloads = _evernoteTaskPayloads(note);
    final expectedTaskHashes = expectedTaskPayloads
        .map((task) => task['source_sha256']?.toString() ?? '')
        .toList(growable: false);
    final expectedTaskReminderHashes = expectedTaskPayloads
        .expand(
          (task) =>
              (task['reminders'] as List<dynamic>? ?? const <dynamic>[]).map(
            (reminder) =>
                Map<String, dynamic>.from(
                  reminder as Map,
                )['source_sha256']
                    ?.toString() ??
                '',
          ),
        )
        .toList(growable: false);
    final expectedNoteReminderHash =
        _evernoteNoteReminderPayload(note)?['source_sha256']?.toString();
    final taskCountMatches =
        snapshot.taskSourceSha256.length == expectedTaskHashes.length;
    final taskHashesMatch = taskCountMatches &&
        _sameStringSets(snapshot.taskSourceSha256, expectedTaskHashes);
    final taskReminderHashesMatch = snapshot.taskReminderSourceSha256.length ==
            expectedTaskReminderHashes.length &&
        _sameStringSets(
          snapshot.taskReminderSourceSha256,
          expectedTaskReminderHashes,
        );
    final noteReminderHashMatches =
        snapshot.noteReminderSourceSha256 == expectedNoteReminderHash;

    final checks = <String, bool>{
      'archive_sha256': archiveVerified,
      'note_content': contentMatches,
      'timestamps': timestampsMatch,
      'tags': tagsMatch,
      'resource_count': resourceCountMatches,
      'resource_sha256': resourceHashesMatch,
      'hierarchy': (snapshot.notebookCollectionId ?? 0) > 0,
      'task_count': taskCountMatches,
      'task_hashes': taskHashesMatch,
      'task_reminder_hashes': taskReminderHashesMatch,
      'note_reminder_hash': noteReminderHashMatches,
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
    void Function(int uploadedBytes, int totalBytes)? onProgress,
  }) async {
    Object? uploadError;
    StackTrace? uploadStackTrace;
    try {
      await storage.uploadBinary(
        bucketId: bucketId,
        path: path,
        bytes: bytes,
        contentType: contentType,
        onProgress: onProgress,
      );
    } catch (error, stackTrace) {
      // A deterministic path may already exist after a prior successful or
      // interrupted attempt. The subsequent download/hash check decides
      // whether it is safe to reuse; unrelated upload failures are rethrown.
      uploadError = error;
      uploadStackTrace = stackTrace;
    }

    try {
      final storedSha256 = await _hashStoredObject(
        bucketId: bucketId,
        path: path,
        expectedBytes: bytes.length,
      );
      if (storedSha256 != expectedSha256) {
        throw StateError('Stored object hash mismatch for $bucketId/$path.');
      }
    } catch (_) {
      if (uploadError != null) {
        Error.throwWithStackTrace(uploadError, uploadStackTrace!);
      }
      rethrow;
    }
  }

  Future<String> _hashStoredObject({
    required String bucketId,
    required String path,
    required int expectedBytes,
  }) async {
    final output = _EvernoteCommitDigestSink();
    final input = sha256.startChunkedConversion(output);
    var processedBytes = 0;
    await for (final part in storage.downloadStream(
      bucketId: bucketId,
      path: path,
    )) {
      if (part.isEmpty) continue;
      processedBytes += part.length;
      if (processedBytes > expectedBytes) {
        throw StateError('Stored object is larger than expected.');
      }
      input.add(part);
    }
    input.close();
    if (processedBytes != expectedBytes) {
      throw StateError('Stored object size does not match.');
    }
    return output.value.toString();
  }

  String _resourceFileName(EvernoteEnexResource resource, int index) {
    final candidate = resource.fileName?.trim().isNotEmpty == true
        ? resource.fileName!.trim()
        : 'resource-${index.toString().padLeft(4, '0')}';
    return DirectStorageUploadService.sanitizeFileName(candidate);
  }

  String _attachmentMarkdownUrl(String path) {
    return 'attachment:${Uri.encodeComponent(path)}';
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

  bool _sameStringSets(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    final sortedLeft = <String>[...left]..sort();
    final sortedRight = <String>[...right]..sort();
    return _sameStrings(sortedLeft, sortedRight);
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

List<Map<String, dynamic>> _evernoteTaskPayloads(EvernoteEnexNote note) {
  return note.tasks.map((task) {
    final payload = Map<String, dynamic>.from(task.toJson());
    payload['reminders'] = task.reminders
        .map(
          (reminder) => _evernoteSourcePayload(reminder.toJson()),
        )
        .toList(growable: false);
    return _evernoteSourcePayload(payload);
  }).toList(growable: false);
}

Map<String, dynamic>? _evernoteNoteReminderPayload(EvernoteEnexNote note) {
  final reminder = note.noteReminder;
  if (reminder == null) return null;
  return _evernoteSourcePayload(reminder.toJson());
}

Map<String, dynamic> _evernoteSourcePayload(Map<String, dynamic> source) {
  final payload = Map<String, dynamic>.from(source)..remove('source_sha256');
  return <String, dynamic>{
    ...payload,
    'source_sha256':
        sha256.convert(utf8.encode(jsonEncode(payload))).toString(),
  };
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class _CommittedEvernoteNote {
  const _CommittedEvernoteNote({
    required this.note,
    required this.sourceItemKey,
    required this.noteId,
    required this.content,
    required this.resources,
  });

  final EvernoteEnexNote note;
  final String sourceItemKey;
  final int noteId;
  final String content;
  final List<EvernoteMigrationResourceManifest> resources;
}

class _EvernoteCommitDigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value {
    final digest = _value;
    if (digest == null) {
      throw StateError('The stored object digest is not available.');
    }
    return digest;
  }

  @override
  void add(Digest data) {
    if (_value != null) {
      throw StateError('The stored object digest was already completed.');
    }
    _value = data;
  }

  @override
  void close() {
    if (_value == null) {
      throw StateError('The stored object digest was not completed.');
    }
  }
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

Stream<List<int>> _memoryBoundedByteStream(Uint8List bytes) async* {
  const readChunkBytes = 1024 * 1024;
  for (var offset = 0; offset < bytes.length; offset += readChunkBytes) {
    final end = offset + readChunkBytes > bytes.length
        ? bytes.length
        : offset + readChunkBytes;
    yield Uint8List.sublistView(bytes, offset, end);
  }
}

DateTime _asDateTime(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw StateError('Expected a valid Evernote migration timestamp.');
  }
  return parsed.toUtc();
}
