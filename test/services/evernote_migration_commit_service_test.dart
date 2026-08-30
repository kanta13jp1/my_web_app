import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_enex_parser.dart';
import 'package:my_web_app/services/evernote_migration_commit_service.dart';
import 'package:my_web_app/services/evernote_migration_ledger_service.dart';
import 'package:my_web_app/services/import_service.dart';

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

      final result = await service.commit(
        userId: _userId,
        exportBytes: fixture.bytes,
        preview: fixture.preview,
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
      expect(database.verifyCalls, hasLength(1));
      expect(
        database.verifyCalls.single.values.every((value) => value),
        isTrue,
      );
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
      );
      storage.rejectDuplicateUploads = true;

      final retried = await service.commit(
        userId: _userId,
        exportBytes: fixture.bytes,
        preview: fixture.preview,
      );

      expect(retried.verifiedNoteCount, 1);
      expect(storage.objects, hasLength(2));
      expect(database.commitCalls, hasLength(2));
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

      await expectLater(
        service.commit(
          userId: _userId,
          exportBytes: fixture.bytes,
          preview: fixture.preview,
        ),
        throwsA(isA<StateError>()),
      );
      expect(database.commitCalls, isEmpty);
      expect(database.verifyCalls, isEmpty);
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
        content: note.plainText,
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
  }) async {
    final key = '$bucketId/$path';
    if (rejectDuplicateUploads && objects.containsKey(key)) {
      throw StateError('Asset already exists');
    }
    objects[key] = Uint8List.fromList(bytes);
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
}

class _FakeDatabaseGateway implements EvernoteMigrationDatabaseGateway {
  final List<String> commitCalls = <String>[];
  final List<Map<String, bool>> verifyCalls = <Map<String, bool>>[];
  final Map<int, EvernoteCommittedNoteSnapshot> snapshots =
      <int, EvernoteCommittedNoteSnapshot>{};

  @override
  Future<int> commitNote({
    required int batchId,
    required String sourceItemKey,
    required EvernoteEnexNote note,
    required Map<String, dynamic> sourceMetadata,
    required List<EvernoteMigrationResourceManifest> resources,
    required String archivePath,
  }) async {
    commitCalls.add(sourceItemKey);
    const noteId = 7001;
    snapshots[noteId] = EvernoteCommittedNoteSnapshot(
      noteId: noteId,
      title: note.title,
      content: note.plainText,
      createdAt: note.createdAt!,
      updatedAt: note.updatedAt!,
      tags: note.tags,
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
