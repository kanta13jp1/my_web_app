import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_cloud_stage_service.dart';
import 'package:my_web_app/services/evernote_migration_commit_service.dart';
import 'package:my_web_app/services/gamification_service.dart';
import 'package:my_web_app/services/import_service.dart';

void main() {
  late _FakeStageStorage storage;
  late EvernoteCloudStageService service;

  setUp(() {
    storage = _FakeStageStorage();
    service = EvernoteCloudStageService(
      storage: storage,
      importService: ImportService(GamificationService()),
    );
  });

  test(
    'stages one-use stream and verifies content-addressed archive',
    () async {
      final bytes = Uint8List.fromList(utf8.encode(_fixture));
      final states = <EvernoteCloudStageState>[];

      final result = await service.stage(
        userId: 'owner-1',
        fileName: 'Private Notebook.enex',
        source: _chunked(bytes, 7),
        totalBytes: bytes.length,
        onProgress: (progress) => states.add(progress.state),
      );

      final exportHash = sha256.convert(bytes).toString();
      final fileNameHash = sha256
          .convert(utf8.encode('Private Notebook.enex'))
          .toString()
          .substring(0, 32);
      expect(result.preview.notes, hasLength(1));
      expect(result.preview.resourceCount, 1);
      expect(result.preview.sourceExportSha256, exportHash);
      expect(
        result.stagingPath,
        'owner-1/evernote/incoming/'
        'v2-${bytes.length}-$exportHash-$fileNameHash.enex',
      );
      expect(result.stagingPath, isNot(contains('Private Notebook')));
      expect(
        result.archivePath,
        'owner-1/evernote/$exportHash/source.enex',
      );
      expect(
        storage.objects['$evernoteArchiveBucket/${result.archivePath}'],
        bytes,
      );
      expect(
        states,
        containsAllInOrder(<EvernoteCloudStageState>[
          EvernoteCloudStageState.preparing,
          EvernoteCloudStageState.uploading,
          EvernoteCloudStageState.parsing,
          EvernoteCloudStageState.copying,
          EvernoteCloudStageState.verifying,
          EvernoteCloudStageState.completed,
        ]),
      );
    },
  );

  test(
    'reuses verified staging and archive objects after duplicate errors',
    () async {
      final bytes = Uint8List.fromList(utf8.encode(_fixture));
      final first = await service.stage(
        userId: 'owner-1',
        fileName: 'batch.enex',
        source: _chunked(bytes, 11),
        totalBytes: bytes.length,
      );
      storage.rejectExisting = true;

      final second = await service.stage(
        userId: 'owner-1',
        fileName: 'batch.enex',
        source: _chunked(bytes, 13),
        totalBytes: bytes.length,
      );

      expect(second.stagingPath, first.stagingPath);
      expect(second.archivePath, first.archivePath);
      expect(
        second.preview.sourceExportSha256,
        first.preview.sourceExportSha256,
      );
    },
  );

  test('isolates a single history revision in its own archive namespace',
      () async {
    final bytes = Uint8List.fromList(utf8.encode(_fixture));

    final result = await service.stage(
      userId: 'owner-1',
      fileName: 'history-version.enex',
      source: _chunked(bytes, 9),
      totalBytes: bytes.length,
      historyRevision: true,
    );

    final exportHash = sha256.convert(bytes).toString();
    expect(
      result.stagingPath,
      startsWith('owner-1/evernote-history/incoming/'),
    );
    expect(
      result.archivePath,
      'owner-1/evernote-history/$exportHash/source.enex',
    );
    expect(result.preview.notes, hasLength(1));
  });

  test('rejects a history ENEX containing multiple revisions', () async {
    final multiNoteFixture = _fixture.replaceFirst(
      '</en-export>',
      '$_secondHistoryNote\n</en-export>',
    );
    final bytes = Uint8List.fromList(utf8.encode(multiNoteFixture));

    await expectLater(
      service.stage(
        userId: 'owner-1',
        fileName: 'history-version.enex',
        source: _chunked(bytes, 9),
        totalBytes: bytes.length,
        historyRevision: true,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('exactly one'),
        ),
      ),
    );
  });

  test('rejects same-prefix same-size staging collisions', () async {
    final firstBytes = Uint8List.fromList(utf8.encode(_largeFixture('A')));
    final secondBytes = Uint8List.fromList(utf8.encode(_largeFixture('B')));
    expect(firstBytes.length, secondBytes.length);

    await service.stage(
      userId: 'owner-1',
      fileName: 'same-name.enex',
      source: _chunked(firstBytes, 64 * 1024),
      totalBytes: firstBytes.length,
    );

    await expectLater(
      service.stage(
        userId: 'owner-1',
        fileName: 'same-name.enex',
        source: _chunked(secondBytes, 64 * 1024),
        totalBytes: secondBytes.length,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('does not match the resumable staging object'),
        ),
      ),
    );
  });

  test('rejects a corrupted server-side archive copy', () async {
    final bytes = Uint8List.fromList(utf8.encode(_fixture));
    storage.corruptCopies = true;

    await expectLater(
      service.stage(
        userId: 'owner-1',
        fileName: 'batch.enex',
        source: _chunked(bytes, 17),
        totalBytes: bytes.length,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('larger than expected'),
        ),
      ),
    );
  });

  test('rejects a stream shorter than its declared size before upload',
      () async {
    final bytes = Uint8List.fromList(utf8.encode(_fixture));

    await expectLater(
      service.stage(
        userId: 'owner-1',
        fileName: 'batch.enex',
        source: _chunked(bytes, 19),
        totalBytes: bytes.length + 1,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ended before its declared size'),
        ),
      ),
    );
    expect(storage.objects, isEmpty);
  });
}

Stream<List<int>> _chunked(Uint8List bytes, int chunkSize) async* {
  for (var offset = 0; offset < bytes.length; offset += chunkSize) {
    final end =
        offset + chunkSize > bytes.length ? bytes.length : offset + chunkSize;
    yield Uint8List.sublistView(bytes, offset, end);
  }
}

class _FakeStageStorage implements EvernoteMigrationStorageGateway {
  final Map<String, Uint8List> objects = <String, Uint8List>{};
  bool rejectExisting = false;
  bool corruptCopies = false;

  @override
  Future<void> uploadBinary({
    required String bucketId,
    required String path,
    required Uint8List bytes,
    required String contentType,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
  }) async {
    final key = '$bucketId/$path';
    if (rejectExisting && objects.containsKey(key)) {
      throw StateError('Asset already exists');
    }
    onProgress?.call(0, bytes.length);
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
    var uploaded = 0;
    onProgress?.call(0, totalBytes);
    await for (final part in source) {
      builder.add(part);
      uploaded += part.length;
      onProgress?.call(uploaded, totalBytes);
    }
    final bytes = builder.takeBytes();
    if (bytes.length != totalBytes) throw StateError('Stream size mismatch');
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
    return Uint8List.fromList(bytes);
  }

  @override
  Stream<List<int>> downloadStream({
    required String bucketId,
    required String path,
  }) async* {
    final bytes = await downloadBinary(bucketId: bucketId, path: path);
    yield* _chunked(bytes, 64 * 1024);
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
    if (rejectExisting && objects.containsKey(destinationKey)) {
      throw StateError('Asset already exists');
    }
    objects[destinationKey] = corruptCopies
        ? Uint8List.fromList(<int>[...source, 0])
        : Uint8List.fromList(source);
  }

  @override
  Future<bool> objectExists({
    required String bucketId,
    required String path,
  }) async {
    return objects.containsKey('$bucketId/$path');
  }
}

const String _fixture = '''
<?xml version="1.0" encoding="UTF-8"?>
<en-export export-date="20260830T120000Z" application="Evernote" version="10">
  <note>
    <title>Cloud stage</title>
    <content><![CDATA[<en-note><div>Streamed body</div></en-note>]]></content>
    <created>20260830T110000Z</created>
    <updated>20260830T113000Z</updated>
    <tag>cloud</tag>
    <resource>
      <data encoding="base64">aGVsbG8=</data>
      <mime>text/plain</mime>
      <resource-attributes><file-name>memo.txt</file-name></resource-attributes>
    </resource>
  </note>
</en-export>
''';

const String _secondHistoryNote = '''
  <note>
    <title>Second history revision</title>
    <content><![CDATA[<en-note><div>Older body</div></en-note>]]></content>
    <created>20260829T110000Z</created>
    <updated>20260829T113000Z</updated>
  </note>
''';

String _largeFixture(String suffix) {
  final sharedBody = List<String>.filled(
    evernoteStageFingerprintBytes + 128,
    'a',
  ).join();
  return '''
<en-export>
  <note>
    <title>Collision test</title>
    <content><![CDATA[<en-note><div>$sharedBody$suffix</div></en-note>]]></content>
  </note>
</en-export>
''';
}
