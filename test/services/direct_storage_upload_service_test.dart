import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/direct_storage_upload_service.dart';

void main() {
  group('DirectStorageUploadService', () {
    final fixedNow = DateTime.fromMillisecondsSinceEpoch(
      1700000000000,
      isUtc: true,
    );

    test('uploads owner-scoped bytes before inserting metadata', () async {
      final events = <String>[];
      final storage = _FakeStorageUploadGateway(events);
      final metadataStore = _FakeDirectUploadMetadataStore(events);
      final service = DirectStorageUploadService(
        storage: storage,
        metadataStore: metadataStore,
      );

      final result = await service.uploadAndInsertMetadata(
        bucketId: 'attachments',
        tableName: 'attachments',
        userId: 'user-123',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        originalFileName: '../Receipt June.PDF',
        contentType: 'application/pdf',
        ownerPathSegments: <String>['42'],
        now: fixedNow,
        metadataBuilder: (final object) {
          return <String, dynamic>{
            'note_id': 42,
            'user_id': object.userId,
            'file_name': object.originalFileName,
            'file_path': object.storagePath,
            'file_size': object.sizeBytes,
            'mime_type': object.contentType,
          };
        },
      );

      const expectedPath = 'user-123/42/1700000000000_Receipt_June.pdf';
      expect(events, <String>['upload:$expectedPath', 'metadata:attachments']);
      expect(result.bucketId, 'attachments');
      expect(result.storagePath, expectedPath);

      final upload = storage.uploads.single;
      expect(upload.bucketId, 'attachments');
      expect(upload.storagePath, expectedPath);
      expect(upload.contentType, 'application/pdf');
      expect(upload.upsert, isFalse);
      expect(upload.bytes, <int>[1, 2, 3]);

      final insert = metadataStore.inserts.single;
      expect(insert.tableName, 'attachments');
      expect(insert.values['user_id'], 'user-123');
      expect(insert.values['file_path'], expectedPath);
      expect(insert.values['file_size'], 3);
      expect(result.metadataRow['id'], 99);
    });

    test('rejects metadata that does not belong to the upload owner', () async {
      final events = <String>[];
      final storage = _FakeStorageUploadGateway(events);
      final metadataStore = _FakeDirectUploadMetadataStore(events);
      final service = DirectStorageUploadService(
        storage: storage,
        metadataStore: metadataStore,
      );

      await expectLater(
        service.uploadAndInsertMetadata(
          bucketId: 'attachments',
          tableName: 'attachments',
          userId: 'user-123',
          bytes: Uint8List.fromList(<int>[1]),
          originalFileName: 'receipt.pdf',
          contentType: 'application/pdf',
          now: fixedNow,
          metadataBuilder: (final object) {
            return <String, dynamic>{
              'user_id': 'someone-else',
              'file_path': object.storagePath,
            };
          },
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(storage.uploads, isEmpty);
      expect(metadataStore.inserts, isEmpty);
    });

    test('rejects empty uploads before touching storage', () async {
      final events = <String>[];
      final storage = _FakeStorageUploadGateway(events);
      final metadataStore = _FakeDirectUploadMetadataStore(events);
      final service = DirectStorageUploadService(
        storage: storage,
        metadataStore: metadataStore,
      );

      await expectLater(
        service.uploadAndInsertMetadata(
          bucketId: 'attachments',
          tableName: 'attachments',
          userId: 'user-123',
          bytes: Uint8List(0),
          originalFileName: 'receipt.pdf',
          contentType: 'application/pdf',
          now: fixedNow,
          metadataBuilder: (final object) {
            return <String, dynamic>{
              'user_id': object.userId,
              'file_path': object.storagePath,
            };
          },
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(storage.uploads, isEmpty);
      expect(metadataStore.inserts, isEmpty);
    });

    test('sanitizes path segments and rejects unsafe owner ids', () {
      final storagePath = DirectStorageUploadService.buildOwnerScopedPath(
        userId: 'user-123',
        ownerPathSegments: <String>['../bad folder'],
        originalFileName: r'..\..\receipt report 06.PDF',
        now: fixedNow,
      );

      expect(
        storagePath,
        'user-123/bad_folder/1700000000000_receipt_report_06.pdf',
      );
      expect(
        () => DirectStorageUploadService.buildOwnerScopedPath(
          userId: 'user/123',
          originalFileName: 'receipt.pdf',
          now: fixedNow,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

class _UploadCall {
  _UploadCall({
    required this.bucketId,
    required this.storagePath,
    required this.bytes,
    required this.contentType,
    required this.upsert,
  });

  final String bucketId;
  final String storagePath;
  final Uint8List bytes;
  final String contentType;
  final bool upsert;
}

class _MetadataInsert {
  _MetadataInsert({
    required this.tableName,
    required this.values,
  });

  final String tableName;
  final Map<String, dynamic> values;
}

class _FakeStorageUploadGateway implements DirectStorageUploadGateway {
  _FakeStorageUploadGateway(this.events);

  final List<String> events;
  final uploads = <_UploadCall>[];

  @override
  Future<void> uploadBinary({
    required final String bucketId,
    required final String storagePath,
    required final Uint8List bytes,
    required final String contentType,
    required final bool upsert,
  }) async {
    uploads.add(
      _UploadCall(
        bucketId: bucketId,
        storagePath: storagePath,
        bytes: bytes,
        contentType: contentType,
        upsert: upsert,
      ),
    );
    events.add('upload:$storagePath');
  }
}

class _FakeDirectUploadMetadataStore implements DirectUploadMetadataStore {
  _FakeDirectUploadMetadataStore(this.events);

  final List<String> events;
  final inserts = <_MetadataInsert>[];

  @override
  Future<Map<String, dynamic>> insert({
    required final String tableName,
    required final Map<String, dynamic> values,
  }) async {
    inserts.add(
      _MetadataInsert(
        tableName: tableName,
        values: values,
      ),
    );
    events.add('metadata:$tableName');
    return <String, dynamic>{
      ...values,
      'id': 99,
      'created_at': '2026-06-06T00:00:00Z',
    };
  }
}
