import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/direct_storage_upload_service.dart';
import 'package:my_web_app/services/storage_quota_service.dart';

class _InMemoryQuotaRepository implements StorageQuotaRepository {
  _InMemoryQuotaRepository(this.status);

  final StorageQuotaStatus status;

  @override
  Future<StorageQuotaStatus> loadStatus({required final String userId}) async {
    return status;
  }
}

class _SpyUploadGateway implements DirectStorageUploadGateway {
  int uploadCallCount = 0;

  @override
  Future<void> uploadBinary({
    required final String bucketId,
    required final String storagePath,
    required final Uint8List bytes,
    required final String contentType,
    required final bool upsert,
  }) async {
    uploadCallCount += 1;
  }
}

class _SpyMetadataStore implements DirectUploadMetadataStore {
  int insertCallCount = 0;

  @override
  Future<Map<String, dynamic>> insert({
    required final String tableName,
    required final Map<String, dynamic> values,
  }) async {
    insertCallCount += 1;
    return <String, dynamic>{'id': 1, ...values};
  }
}

void main() {
  group('StorageQuotaService', () {
    test('resolveLimits maps plans and admin bypass accurately', () {
      final freeLimits = StorageQuotaService.resolveLimits(
        subscriptionPlan: null,
        isAdmin: false,
      );
      expect(freeLimits.planId, 'free');
      expect(freeLimits.quotaBytes, StorageQuotaPolicy.freeQuotaBytes);
      expect(
        freeLimits.maxSingleFileBytes,
        StorageQuotaPolicy.freeSingleFileMaxBytes,
      );
      expect(freeLimits.isAdminBypass, isFalse);

      final proLimits = StorageQuotaService.resolveLimits(
        subscriptionPlan: 'personal_pro',
        isAdmin: false,
      );
      expect(proLimits.planId, 'pro');
      expect(proLimits.quotaBytes, StorageQuotaPolicy.proQuotaBytes);
      expect(
        proLimits.maxSingleFileBytes,
        StorageQuotaPolicy.paidSingleFileMaxBytes,
      );

      final teamLimits = StorageQuotaService.resolveLimits(
        subscriptionPlan: 'business',
        isAdmin: false,
      );
      expect(teamLimits.planId, 'team');
      expect(teamLimits.quotaBytes, StorageQuotaPolicy.teamQuotaBytes);

      final adminLimits = StorageQuotaService.resolveLimits(
        subscriptionPlan: 'free',
        isAdmin: true,
      );
      expect(adminLimits.planId, 'admin');
      expect(adminLimits.isAdminBypass, isTrue);

      final roleAdminLimits = StorageQuotaService.resolveLimits(
        subscriptionPlan: 'free',
        isAdmin: false,
        role: 'admin',
      );
      expect(roleAdminLimits.planId, 'admin');
      expect(roleAdminLimits.isAdminBypass, isTrue);
    });

    test('evaluateUpload enforces free total quota and single file cap', () {
      const status = StorageQuotaStatus(
        planId: 'free',
        isAdmin: false,
        usedBytes: 95 * 1024 * 1024,
        quotaBytes: StorageQuotaPolicy.freeQuotaBytes,
        maxSingleFileBytes: StorageQuotaPolicy.freeSingleFileMaxBytes,
        attachmentCount: 4,
      );

      final ok = status.evaluateUpload(incomingBytes: 4 * 1024 * 1024);
      expect(ok.allowed, isTrue);
      expect(ok.requiresUpgrade, isFalse);
      expect(ok.remainingBytesAfter, 1 * 1024 * 1024);

      final overflow = status.evaluateUpload(incomingBytes: 6 * 1024 * 1024);
      expect(overflow.allowed, isFalse);
      expect(overflow.requiresUpgrade, isTrue);
      expect(overflow.reason, contains('上限'));

      final singleTooLarge = status.evaluateUpload(
        incomingBytes: 2 * 1024 * 1024,
        singleFileBytes: 11 * 1024 * 1024,
      );
      expect(singleTooLarge.allowed, isFalse);
      expect(singleTooLarge.requiresUpgrade, isTrue);
      expect(singleTooLarge.reason, contains('1ファイルのサイズ上限'));
    });

    test('evaluateUpload allows pro multi-GB quota and admin bypass', () {
      const proStatus = StorageQuotaStatus(
        planId: 'pro',
        isAdmin: false,
        usedBytes: 2 * 1024 * 1024 * 1024,
        quotaBytes: StorageQuotaPolicy.proQuotaBytes,
        maxSingleFileBytes: StorageQuotaPolicy.paidSingleFileMaxBytes,
        attachmentCount: 25,
      );
      final proEval = proStatus.evaluateUpload(
        incomingBytes: 3 * 1024 * 1024 * 1024,
        singleFileBytes: 50 * 1024 * 1024,
      );
      expect(proEval.allowed, isTrue);

      const adminStatus = StorageQuotaStatus(
        planId: 'admin',
        isAdmin: true,
        usedBytes: 250 * 1024 * 1024,
        quotaBytes: StorageQuotaPolicy.adminQuotaBytes,
        maxSingleFileBytes: StorageQuotaPolicy.paidSingleFileMaxBytes,
        attachmentCount: 381,
      );
      final adminEval = adminStatus.evaluateUpload(
        incomingBytes: 2 * 1024 * 1024 * 1024,
        singleFileBytes: 20 * 1024 * 1024,
      );
      expect(adminEval.allowed, isTrue);

      final adminSingleOverflow = adminStatus.evaluateUpload(
        incomingBytes: 120 * 1024 * 1024,
        singleFileBytes: 101 * 1024 * 1024,
      );
      expect(adminSingleOverflow.allowed, isFalse);
    });

    test(
      'DirectStorageUploadService blocks before storage and metadata writes',
      () async {
        final storage = _SpyUploadGateway();
        final metadata = _SpyMetadataStore();
        final service = DirectStorageUploadService(
          storage: storage,
          metadataStore: metadata,
          quotaService: StorageQuotaService(
            repository: _InMemoryQuotaRepository(
              const StorageQuotaStatus(
                planId: 'free',
                isAdmin: false,
                usedBytes: 100 * 1024 * 1024,
                quotaBytes: StorageQuotaPolicy.freeQuotaBytes,
                maxSingleFileBytes: StorageQuotaPolicy.freeSingleFileMaxBytes,
                attachmentCount: 10,
              ),
            ),
          ),
        );

        await expectLater(
          service.uploadAndInsertMetadata(
            bucketId: 'attachments',
            tableName: 'attachments',
            userId: 'user-free-1',
            bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
            originalFileName: 'receipt.png',
            contentType: 'image/png',
            metadataBuilder: (final object) => <String, dynamic>{
              'user_id': object.userId,
              'file_path': object.storagePath,
            },
          ),
          throwsA(isA<StorageQuotaException>()),
        );

        expect(storage.uploadCallCount, 0);
        expect(metadata.insertCallCount, 0);
      },
    );

    test('ExternalPresignedStorageGateway sends PUT and checks HTTP status',
        () async {
      final capturedRequests = <http.Request>[];
      final okGateway = ExternalPresignedStorageGateway(
        resolveUploadUrl: ({
          required final String bucketId,
          required final String storagePath,
          required final String contentType,
          required final int contentLength,
        }) async {
          return Uri.parse(
            'https://r2.example.invalid/$bucketId/$storagePath?sig=ok',
          );
        },
        httpClient: MockClient((final request) async {
          capturedRequests.add(request);
          return http.Response('', 200, request: request);
        }),
      );

      await okGateway.uploadBinary(
        bucketId: 'attachments',
        storagePath: 'user-1/note-1/photo.png',
        bytes: Uint8List.fromList(const <int>[10, 20, 30]),
        contentType: 'image/png',
        upsert: false,
      );

      expect(capturedRequests, hasLength(1));
      expect(capturedRequests.single.method, 'PUT');
      expect(
        capturedRequests.single.url.toString(),
        'https://r2.example.invalid/attachments/user-1/note-1/photo.png?sig=ok',
      );
      expect(
        capturedRequests.single.headers['Content-Type'],
        contains('image/png'),
      );
      expect(capturedRequests.single.bodyBytes, const <int>[10, 20, 30]);

      final failingGateway = ExternalPresignedStorageGateway(
        resolveUploadUrl: ({
          required final String bucketId,
          required final String storagePath,
          required final String contentType,
          required final int contentLength,
        }) async =>
            Uri.parse('https://r2.example.invalid/fail'),
        httpClient: MockClient((final request) async {
          return http.Response('Forbidden', 403, request: request);
        }),
      );

      await expectLater(
        failingGateway.uploadBinary(
          bucketId: 'attachments',
          storagePath: 'user-1/fail.png',
          bytes: Uint8List.fromList(const <int>[1]),
          contentType: 'image/png',
          upsert: false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('formatStorageBytes renders human-readable sizes', () {
      expect(formatStorageBytes(0), '0 B');
      expect(formatStorageBytes(512), '512 B');
      expect(formatStorageBytes(1536), '1.5 KB');
      expect(formatStorageBytes(12 * 1024 * 1024 + 512 * 1024), '12.5 MB');
      expect(
        formatStorageBytes(1536 * 1024 * 1024),
        '1.50 GB',
      );
    });
  });
}
