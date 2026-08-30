import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_enex_parser.dart';
import 'package:my_web_app/services/evernote_migration_commit_service.dart';
import 'package:my_web_app/services/evernote_migration_ledger_service.dart';
import 'package:my_web_app/services/import_service.dart';

const _sourceContext = EvernoteMigrationSourceContext(
  notebookName: 'Notebook A',
  stackName: 'Stack A',
  spaceName: 'Space A',
);

void main() {
  group('EvernoteMigrationCommitService', () {
    test('archives, atomically commits, and hash-verifies a batch', () async {
      final fixture = _fixture();
      final storage = _FakeStorageGateway();
      final database = _FakeDatabaseGateway();
      final service = EvernoteMigrationCommitService(
        ledger: _FakeLedgerGateway(),
        storage: storage,
        database: database,
      );
      final transferProgress = <EvernoteMigrationTransferProgress>[];

      final result = await service.commit(
        userId: _userId,
        exportBytes: fixture.bytes,
        preview: fixture.preview,
        sourceContext: _sourceContext,
        onTransferProgress: transferProgress.add,
      );

      expect(result.batchId, 41);
      expect(result.importedNoteCount, 1);
      expect(result.verifiedNoteCount, 1);
      expect(result.resourceCount, 1);
      expect(result.archiveSha256, fixture.export.exportSha256);
      expect(storage.objects, hasLength(2));
      expect(
        storage.objects.keys,
        contains(
          '$evernoteArchiveBucket/'
          '$_userId/evernote/${fixture.export.exportSha256}/source.enex',
        ),
      );
      expect(
        storage.objects.keys.every((path) => !path.contains('Fixture title')),
        isTrue,
      );
      expect(database.commitCalls, hasLength(1));
      expect(database.committedContents, hasLength(1));
      expect(
        database.committedMetadata.single['source_context'],
        <String, dynamic>{
          'notebook_name': 'Notebook A',
          'stack_name': 'Stack A',
          'space_name': 'Space A',
        },
      );
      final committedTasks =
          database.committedMetadata.single['tasks'] as List<dynamic>;
      final committedReminder =
          database.committedMetadata.single['note_reminder'];
      expect(committedTasks, hasLength(1));
      expect(
        Map<String, dynamic>.from(
          committedTasks.single as Map,
        )['source_sha256'],
        hasLength(64),
      );
      expect(
        Map<String, dynamic>.from(committedReminder as Map)['source_sha256'],
        hasLength(64),
      );
      expect(database.committedContents.single, contains('(attachment:'));
      expect(
        database.committedContents.single,
        isNot(contains('evernote-resource:')),
      );
      expect(database.verifyCalls, hasLength(1));
      expect(
        database.verifyCalls.single.values.every((value) => value),
        isTrue,
      );
      expect(transferProgress, isNotEmpty);
      expect(transferProgress.first.transferredBytes, 0);
      expect(transferProgress.last.percent, 100);
      expect(
        transferProgress.last.state,
        EvernoteMigrationTransferState.completed,
      );
      expect(transferProgress.last.objectIndex, 2);
      expect(transferProgress.last.objectCount, 2);
      final transferredByteSamples = transferProgress
          .map((progress) => progress.transferredBytes)
          .toList(growable: false);
      expect(
        transferredByteSamples,
        orderedEquals(<int>[...transferredByteSamples]..sort()),
      );
    });

    test('streams a staged archive and releases each note after verification',
        () async {
      final fixture = _fixture();
      final storage = _FakeStorageGateway();
      final database = _FakeDatabaseGateway();
      final service = EvernoteMigrationCommitService(
        ledger: _FakeLedgerGateway(),
        storage: storage,
        database: database,
      );
      final archivePath = '$_userId/evernote/'
          '${fixture.export.exportSha256}/source.enex';
      storage.objects['$evernoteArchiveBucket/$archivePath'] =
          Uint8List.fromList(fixture.bytes);
      final transferProgress = <EvernoteMigrationTransferProgress>[];

      final result = await service.commitFromArchive(
        userId: _userId,
        archiveBytes: fixture.bytes.length,
        preview: fixture.preview,
        sourceContext: _sourceContext,
        onTransferProgress: transferProgress.add,
      );

      expect(result.importedNoteCount, 1);
      expect(result.verifiedNoteCount, 1);
      expect(result.resourceCount, 1);
      expect(result.archiveSha256, fixture.export.exportSha256);
      expect(storage.objects, hasLength(2));
      expect(database.commitCalls, hasLength(1));
      expect(database.verifyCalls, hasLength(1));
      expect(database.committedMetadata.single['streaming_commit'], isTrue);
      expect(transferProgress.first.stageLabel, 'Recovery archive');
      expect(
        transferProgress.first.state,
        EvernoteMigrationTransferState.completed,
      );
      expect(transferProgress.last.percent, 100);
      expect(transferProgress.last.objectIndex, 2);
      expect(transferProgress.last.objectCount, 2);
    });

    test('streamed commit rejects a preview that differs from cloud archive',
        () async {
      final fixture = _fixture();
      final storage = _FakeStorageGateway();
      final database = _FakeDatabaseGateway();
      final service = EvernoteMigrationCommitService(
        ledger: _FakeLedgerGateway(),
        storage: storage,
        database: database,
      );
      final archivePath = '$_userId/evernote/'
          '${fixture.export.exportSha256}/source.enex';
      storage.objects['$evernoteArchiveBucket/$archivePath'] =
          Uint8List.fromList(fixture.bytes);
      final original = fixture.preview.notes.single;
      final mismatchedPreview = ImportPreviewResult(
        sourceType: fixture.preview.sourceType,
        sourceLabel: fixture.preview.sourceLabel,
        fileName: fixture.preview.fileName,
        notes: <ImportedNoteDraft>[
          ImportedNoteDraft(
            title: '${original.title} changed',
            content: '${original.content} changed',
            source: original.source,
            tags: original.tags,
            sourceId: original.sourceId,
            sourceCreatedAt: original.sourceCreatedAt,
            sourceUpdatedAt: original.sourceUpdatedAt,
            sourceContentSha256: original.sourceContentSha256,
            sourceResourceCount: original.sourceResourceCount,
          ),
        ],
        previewMode: 'local-streaming',
        sourceExportSha256: fixture.preview.sourceExportSha256,
        resourceCount: fixture.preview.resourceCount,
      );

      await expectLater(
        service.commitFromArchive(
          userId: _userId,
          archiveBytes: fixture.bytes.length,
          preview: mismatchedPreview,
          sourceContext: _sourceContext,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('no longer matches'),
          ),
        ),
      );
      expect(database.commitCalls, isEmpty);
      expect(database.verifyCalls, isEmpty);
    });

    test('blocks commit when the source notebook name is missing', () async {
      final fixture = _fixture();
      final storage = _FakeStorageGateway();
      final database = _FakeDatabaseGateway();
      final service = EvernoteMigrationCommitService(
        ledger: _FakeLedgerGateway(),
        storage: storage,
        database: database,
      );

      await expectLater(
        service.commit(
          userId: _userId,
          exportBytes: fixture.bytes,
          preview: fixture.preview,
          sourceContext: const EvernoteMigrationSourceContext(
            notebookName: '   ',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(storage.objects, isEmpty);
      expect(database.commitCalls, isEmpty);
    });

    test('reuses deterministic objects only after their hashes match',
        () async {
      final fixture = _fixture();
      final storage = _FakeStorageGateway();
      final database = _FakeDatabaseGateway();
      final service = EvernoteMigrationCommitService(
        ledger: _FakeLedgerGateway(),
        storage: storage,
        database: database,
      );

      await service.commit(
        userId: _userId,
        exportBytes: fixture.bytes,
        preview: fixture.preview,
        sourceContext: _sourceContext,
      );
      storage.rejectDuplicateUploads = true;

      final retried = await service.commit(
        userId: _userId,
        exportBytes: fixture.bytes,
        preview: fixture.preview,
        sourceContext: _sourceContext,
      );

      expect(retried.verifiedNoteCount, 1);
      expect(storage.objects, hasLength(2));
      expect(database.commitCalls, hasLength(2));
    });

    test('blocks verification when the committed note has no notebook',
        () async {
      final fixture = _fixture();
      final storage = _FakeStorageGateway();
      final database = _FakeDatabaseGateway(notebookCollectionId: null);
      final service = EvernoteMigrationCommitService(
        ledger: _FakeLedgerGateway(),
        storage: storage,
        database: database,
      );

      await expectLater(
        service.commit(
          userId: _userId,
          exportBytes: fixture.bytes,
          preview: fixture.preview,
          sourceContext: _sourceContext,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('hierarchy'),
          ),
        ),
      );
      expect(database.verifyCalls, isEmpty);
    });

    test('blocks verification when a committed Task hash mismatches', () async {
      final fixture = _fixture();
      final storage = _FakeStorageGateway();
      final database = _FakeDatabaseGateway(corruptTaskHashes: true);
      final service = EvernoteMigrationCommitService(
        ledger: _FakeLedgerGateway(),
        storage: storage,
        database: database,
      );

      await expectLater(
        service.commit(
          userId: _userId,
          exportBytes: fixture.bytes,
          preview: fixture.preview,
          sourceContext: _sourceContext,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('task_hashes'),
          ),
        ),
      );
      expect(database.verifyCalls, isEmpty);
    });

    test('does not commit database rows when a stored hash mismatches',
        () async {
      final fixture = _fixture();
      final storage = _FakeStorageGateway(
        corruptDownloadsContaining: 'source.enex',
      );
      final database = _FakeDatabaseGateway();
      final service = EvernoteMigrationCommitService(
        ledger: _FakeLedgerGateway(),
        storage: storage,
        database: database,
      );
      final transferProgress = <EvernoteMigrationTransferProgress>[];

      await expectLater(
        service.commit(
          userId: _userId,
          exportBytes: fixture.bytes,
          preview: fixture.preview,
          sourceContext: _sourceContext,
          onTransferProgress: transferProgress.add,
        ),
        throwsA(isA<StateError>()),
      );
      expect(database.commitCalls, isEmpty);
      expect(database.verifyCalls, isEmpty);
      expect(
        transferProgress.last.state,
        EvernoteMigrationTransferState.failed,
      );
    });
  });
}

const String _userId = '00000000-0000-4000-8000-000000000001';

class _Fixture {
  const _Fixture({
    required this.bytes,
    required this.export,
    required this.preview,
  });

  final Uint8List bytes;
  final EvernoteEnexExport export;
  final ImportPreviewResult preview;
}

_Fixture _fixture() {
  final resourceBytes = utf8.encode('lossless attachment');
  final encodedResource = base64Encode(resourceBytes);
  final enex = '''<?xml version="1.0" encoding="UTF-8"?>
<en-export export-date="20260823T040000Z" application="Evernote" version="10">
  <note>
    <title>Fixture title</title>
    <created>20240102T030405Z</created>
    <updated>20240203T040506Z</updated>
    <tag>migration</tag>
    <note-attributes>
      <reminder-order>1710000000000</reminder-order>
      <reminder-time>20240701T090000Z</reminder-time>
    </note-attributes>
    <task>
      <title>Structured follow up</title>
      <created>20240601T010203Z</created>
      <updated>20240602T020304Z</updated>
      <taskStatus>open</taskStatus>
      <inNote>true</inNote>
      <taskFlag>priority</taskFlag>
      <sortWeight>100</sortWeight>
      <noteLevelID>task-1</noteLevelID>
      <taskGroupNoteLevelID>group-1</taskGroupNoteLevelID>
      <dueDate>20240710T090000Z</dueDate>
      <dueDateUIOption>date_time</dueDateUIOption>
      <timeZone>Asia/Tokyo</timeZone>
      <recurrence>RRULE:FREQ=WEEKLY</recurrence>
      <repeatAfterCompletion>true</repeatAfterCompletion>
      <statusUpdated>20240602T020304Z</statusUpdated>
      <creator>owner@example.com</creator>
      <lastEditor>editor@example.com</lastEditor>
      <reminder>
        <created>20240601T010203Z</created>
        <updated>20240602T020304Z</updated>
        <noteLevelID>reminder-1</noteLevelID>
        <reminderDate>20240709T090000Z</reminderDate>
        <reminderDateUIOption>date_time</reminderDateUIOption>
        <timeZone>Asia/Tokyo</timeZone>
        <dueDateOffset>-86400000</dueDateOffset>
        <reminderStatus>active</reminderStatus>
      </reminder>
    </task>
    <content><![CDATA[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note>Hello<en-media type="text/plain" hash="fixturehash"/></en-note>]]></content>
    <resource>
      <data encoding="base64" hash="fixturehash">$encodedResource</data>
      <mime>text/plain</mime>
      <resource-attributes><file-name>fixture.txt</file-name></resource-attributes>
    </resource>
  </note>
</en-export>''';
  final bytes = Uint8List.fromList(utf8.encode(enex));
  final export = const EvernoteEnexParser().parseBytes(bytes);
  final note = export.notes.single;
  final preview = ImportPreviewResult(
    sourceType: 'evernote',
    sourceLabel: 'Evernote',
    fileName: 'batch.enex',
    notes: <ImportedNoteDraft>[
      ImportedNoteDraft(
        title: note.title,
        content: note.markdownText,
        source: 'evernote',
        tags: note.tags,
        sourceId: note.sourceId,
        sourceCreatedAt: note.createdAt,
        sourceUpdatedAt: note.updatedAt,
        sourceContentSha256: note.contentSha256,
        sourceResourceCount: note.resources.length,
        sourceMetadata: note.toImportMetadata(),
      ),
    ],
    previewMode: 'local-fallback',
    sourceExportSha256: export.exportSha256,
    resourceCount: export.resourceCount,
  );
  return _Fixture(bytes: bytes, export: export, preview: preview);
}

class _FakeLedgerGateway implements EvernoteMigrationLedgerGateway {
  @override
  Future<EvernoteMigrationBatch> recordPreview({
    required String userId,
    required ImportPreviewResult preview,
  }) async {
    final now = DateTime.utc(2026, 8, 23);
    return EvernoteMigrationBatch(
      id: 41,
      userId: userId,
      sourceExportSha256: preview.sourceExportSha256!,
      sourceFileName: preview.fileName,
      status: 'previewed',
      sourceNoteCount: preview.notes.length,
      sourceResourceCount: preview.resourceCount,
      importedNoteCount: 0,
      verifiedNoteCount: 0,
      sourceDeletedNoteCount: 0,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _FakeStorageGateway implements EvernoteMigrationStorageGateway {
  _FakeStorageGateway({this.corruptDownloadsContaining});

  final String? corruptDownloadsContaining;
  final Map<String, Uint8List> objects = <String, Uint8List>{};
  bool rejectDuplicateUploads = false;

  @override
  Future<void> uploadBinary({
    required String bucketId,
    required String path,
    required Uint8List bytes,
    required String contentType,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
  }) async {
    onProgress?.call(0, bytes.length);
    final key = '$bucketId/$path';
    if (rejectDuplicateUploads && objects.containsKey(key)) {
      throw StateError('Asset already exists');
    }
    objects[key] = Uint8List.fromList(bytes);
    onProgress?.call(bytes.length, bytes.length);
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
    final builder = BytesBuilder(copy: false);
    await for (final chunk in source) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.length != totalBytes) {
      throw StateError('Stream size mismatch');
    }
    await uploadBinary(
      bucketId: bucketId,
      path: path,
      bytes: bytes,
      contentType: contentType,
      onProgress: onProgress,
    );
  }

  @override
  Future<Uint8List> downloadBinary({
    required String bucketId,
    required String path,
  }) async {
    final bytes = objects['$bucketId/$path'];
    if (bytes == null) throw StateError('Object not found');
    if (corruptDownloadsContaining != null &&
        path.contains(corruptDownloadsContaining!)) {
      return Uint8List.fromList(<int>[...bytes, 0]);
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Stream<List<int>> downloadStream({
    required String bucketId,
    required String path,
  }) async* {
    yield await downloadBinary(bucketId: bucketId, path: path);
  }

  @override
  Future<void> copyObject({
    required String bucketId,
    required String sourcePath,
    required String destinationPath,
  }) async {
    final source = objects['$bucketId/$sourcePath'];
    if (source == null) throw StateError('Object not found');
    final destinationKey = '$bucketId/$destinationPath';
    if (rejectDuplicateUploads && objects.containsKey(destinationKey)) {
      throw StateError('Asset already exists');
    }
    objects[destinationKey] = Uint8List.fromList(source);
  }

  @override
  Future<bool> objectExists({
    required String bucketId,
    required String path,
  }) async {
    return objects.containsKey('$bucketId/$path');
  }
}

class _FakeDatabaseGateway implements EvernoteMigrationDatabaseGateway {
  _FakeDatabaseGateway({
    this.notebookCollectionId = 9901,
    this.corruptTaskHashes = false,
  });

  final int? notebookCollectionId;
  final bool corruptTaskHashes;
  final List<String> commitCalls = <String>[];
  final List<String> committedContents = <String>[];
  final List<Map<String, dynamic>> committedMetadata = <Map<String, dynamic>>[];
  final List<Map<String, bool>> verifyCalls = <Map<String, bool>>[];
  final Map<int, EvernoteCommittedNoteSnapshot> snapshots =
      <int, EvernoteCommittedNoteSnapshot>{};

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
    commitCalls.add(sourceItemKey);
    committedContents.add(content);
    committedMetadata.add(Map<String, dynamic>.from(sourceMetadata));
    const noteId = 7001;
    final taskPayloads =
        (sourceMetadata['tasks'] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList(growable: false);
    final taskHashes = taskPayloads
        .map((task) => task['source_sha256']?.toString() ?? '')
        .toList(growable: false);
    if (corruptTaskHashes && taskHashes.isNotEmpty) {
      taskHashes[0] = 'corrupt';
    }
    final taskReminderHashes = taskPayloads
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
    final noteReminder = sourceMetadata['note_reminder'];
    snapshots[noteId] = EvernoteCommittedNoteSnapshot(
      noteId: noteId,
      title: note.title,
      content: content,
      createdAt: note.createdAt!,
      updatedAt: note.updatedAt!,
      tags: note.tags,
      notebookCollectionId: notebookCollectionId,
      attachments: resources
          .map(
            (resource) => EvernoteCommittedAttachmentSnapshot(
              fileName: resource.fileName,
              filePath: resource.filePath,
              fileSize: resource.fileSize,
              mimeType: resource.mimeType,
              contentSha256: resource.contentSha256,
            ),
          )
          .toList(growable: false),
      taskSourceSha256: taskHashes,
      taskReminderSourceSha256: taskReminderHashes,
      noteReminderSourceSha256: noteReminder is Map
          ? Map<String, dynamic>.from(noteReminder)['source_sha256']?.toString()
          : null,
    );
    return noteId;
  }

  @override
  Future<EvernoteCommittedNoteSnapshot> loadCommittedNote({
    required int noteId,
  }) async {
    return snapshots[noteId]!;
  }

  @override
  Future<void> markNoteVerified({
    required int batchId,
    required String sourceItemKey,
    required Map<String, bool> checks,
  }) async {
    verifyCalls.add(Map<String, bool>.from(checks));
  }
}
