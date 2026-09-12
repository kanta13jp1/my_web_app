import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_enex_parser.dart';
import 'package:my_web_app/services/evernote_migration_commit_service.dart';
import 'package:my_web_app/services/evernote_note_history_migration_service.dart';

void main() {
  group('EvernoteNoteHistoryMigrationService', () {
    test('reviews, streams, commits, and verifies one history revision',
        () async {
      final fixture = _historyFixture();
      final storage = _FakeStorage();
      final database = _FakeDatabase();
      final service = EvernoteNoteHistoryMigrationService(
        storage: storage,
        database: database,
      );
      final archivePath =
          '$_userId/evernote-history/${fixture.sha256}/source.enex';
      storage.objects['$evernoteArchiveBucket/$archivePath'] = fixture.bytes;

      await service.reviewInventory(
        batchId: 41,
        sourceItemKey: 'id:current-note',
        sourceVersionCount: 1,
      );
      final result = await service.migrateFromArchive(
        userId: _userId,
        batchId: 41,
        sourceItemKey: 'id:current-note',
        archiveBytes: fixture.bytes.length,
        archiveSha256: fixture.sha256,
      );

      expect(database.reviewedVersionCount, 1);
      expect(result.noteVersionId, 'version-1');
      expect(result.archiveSha256, fixture.sha256);
      expect(result.resourceCount, 1);
      expect(database.commits, 1);
      expect(database.verifications, 1);
      expect(database.lastChecks!.values.every((value) => value), isTrue);
      expect(storage.objects, hasLength(2));
      expect(
        storage.objects.keys,
        contains(
          startsWith(
            '$evernoteAttachmentBucket/$_userId/evernote-history/'
            '${fixture.sha256}/',
          ),
        ),
      );
    });

    test('rejects a multi-note ENEX before database mutation', () async {
      final fixture = _historyFixture(noteCount: 2);
      final storage = _FakeStorage();
      final database = _FakeDatabase();
      final service = EvernoteNoteHistoryMigrationService(
        storage: storage,
        database: database,
      );
      final archivePath =
          '$_userId/evernote-history/${fixture.sha256}/source.enex';
      storage.objects['$evernoteArchiveBucket/$archivePath'] = fixture.bytes;

      await expectLater(
        service.migrateFromArchive(
          userId: _userId,
          batchId: 41,
          sourceItemKey: 'id:current-note',
          archiveBytes: fixture.bytes.length,
          archiveSha256: fixture.sha256,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('exactly one'),
          ),
        ),
      );
      expect(database.commits, 0);
      expect(database.verifications, 0);
    });

    test('records an explicit no-history review without an archive', () async {
      final database = _FakeDatabase();
      final service = EvernoteNoteHistoryMigrationService(
        storage: _FakeStorage(),
        database: database,
      );

      await service.reviewInventory(
        batchId: 41,
        sourceItemKey: 'id:current-note',
        sourceVersionCount: 0,
      );

      expect(database.reviewedVersionCount, 0);
      expect(database.commits, 0);
    });
  });
}

const _userId = '00000000-0000-4000-8000-000000000001';

class _HistoryFixture {
  const _HistoryFixture({
    required this.bytes,
    required this.sha256,
  });

  final Uint8List bytes;
  final String sha256;
}

_HistoryFixture _historyFixture({int noteCount = 1}) {
  final encodedResource = base64Encode(utf8.encode('history attachment'));
  final notes = List<String>.generate(
    noteCount,
    (index) => '''
  <note>
    <guid>history-note-$index</guid>
    <title>Historical title $index</title>
    <created>20240102T030405Z</created>
    <updated>20240103T040506Z</updated>
    <tag>history</tag>
    <content><![CDATA[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note>Historical body<en-media type="text/plain" hash="fixturehash$index"/></en-note>]]></content>
    <resource>
      <data encoding="base64" hash="fixturehash$index">$encodedResource</data>
      <mime>text/plain</mime>
      <resource-attributes>
        <file-name>history-$index.txt</file-name>
      </resource-attributes>
    </resource>
  </note>''',
  ).join();
  final enex = '''<?xml version="1.0" encoding="UTF-8"?>
<en-export export-date="20260831T010000Z" application="Evernote" version="10">
$notes
</en-export>''';
  final bytes = Uint8List.fromList(utf8.encode(enex));
  return _HistoryFixture(
    bytes: bytes,
    sha256: sha256.convert(bytes).toString(),
  );
}

class _FakeStorage implements EvernoteMigrationStorageGateway {
  final Map<String, Uint8List> objects = <String, Uint8List>{};

  @override
  Future<void> uploadBinary({
    required String bucketId,
    required String path,
    required Uint8List bytes,
    required String contentType,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
  }) async {
    objects['$bucketId/$path'] = Uint8List.fromList(bytes);
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
    objects['$bucketId/$path'] = builder.takeBytes();
  }

  @override
  Future<Uint8List> downloadBinary({
    required String bucketId,
    required String path,
  }) async {
    final value = objects['$bucketId/$path'];
    if (value == null) throw StateError('Object not found');
    return Uint8List.fromList(value);
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
    objects['$bucketId/$destinationPath'] =
        await downloadBinary(bucketId: bucketId, path: sourcePath);
  }

  @override
  Future<bool> objectExists({
    required String bucketId,
    required String path,
  }) async =>
      objects.containsKey('$bucketId/$path');
}

class _FakeDatabase implements EvernoteNoteHistoryDatabaseGateway {
  int? reviewedVersionCount;
  int commits = 0;
  int verifications = 0;
  Map<String, bool>? lastChecks;
  EvernoteHistoryVersionSnapshot? snapshot;

  @override
  Future<void> markInventoryReviewed({
    required int batchId,
    required String sourceItemKey,
    required int sourceVersionCount,
  }) async {
    reviewedVersionCount = sourceVersionCount;
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
    commits += 1;
    snapshot = EvernoteHistoryVersionSnapshot(
      id: 'version-1',
      title: note.title,
      content: content,
      savedAt: savedAt,
      sourceContentSha256: note.contentSha256,
      tags: note.tags,
      attachments: resources
          .map(
            (resource) => EvernoteHistoryAttachmentSnapshot(
              filePath: resource.filePath,
              fileSize: resource.fileSize,
              mimeType: resource.mimeType,
              contentSha256: resource.contentSha256,
            ),
          )
          .toList(growable: false),
    );
    return 'version-1';
  }

  @override
  Future<EvernoteHistoryVersionSnapshot> loadVersion({
    required String noteVersionId,
  }) async =>
      snapshot!;

  @override
  Future<void> markVersionVerified({
    required int batchId,
    required String sourceItemKey,
    required String historyItemKey,
    required String archiveSha256,
    required Map<String, bool> checks,
  }) async {
    verifications += 1;
    lastChecks = Map<String, bool>.from(checks);
  }
}
