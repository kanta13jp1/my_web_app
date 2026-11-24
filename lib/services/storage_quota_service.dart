import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'direct_storage_upload_service.dart';

/// プラン別の添付ファイル容量上限 (Wave 0 ストレージ保護・ユニットエコノミクス安全弁)。
class StorageQuotaPolicy {
  const StorageQuotaPolicy._();

  static const int freeQuotaBytes = 100 * 1024 * 1024; // 100 MiB
  static const int freeSingleFileMaxBytes = 10 * 1024 * 1024; // 10 MiB

  static const int proQuotaBytes = 10 * 1024 * 1024 * 1024; // 10 GiB
  static const int paidSingleFileMaxBytes = 100 * 1024 * 1024; // 100 MiB

  static const int teamQuotaBytes = 50 * 1024 * 1024 * 1024; // 50 GiB
  static const int adminQuotaBytes = 2 * 1024 * 1024 * 1024; // 2 GiB
}

class StorageQuotaLimits {
  const StorageQuotaLimits({
    required this.planId,
    required this.quotaBytes,
    required this.maxSingleFileBytes,
    required this.isAdminBypass,
  });

  final String planId;
  final int quotaBytes;
  final int maxSingleFileBytes;
  final bool isAdminBypass;
}

class StorageQuotaStatus {
  const StorageQuotaStatus({
    required this.planId,
    required this.isAdmin,
    required this.usedBytes,
    required this.quotaBytes,
    required this.maxSingleFileBytes,
    required this.attachmentCount,
  });

  final String planId;
  final bool isAdmin;
  final int usedBytes;
  final int quotaBytes;
  final int maxSingleFileBytes;
  final int attachmentCount;

  int get remainingBytes {
    final diff = quotaBytes - usedBytes;
    return diff > 0 ? diff : 0;
  }

  double get usageFraction {
    if (quotaBytes <= 0 || usedBytes <= 0) {
      return 0;
    }
    if (usedBytes >= quotaBytes) {
      return 1;
    }
    return usedBytes / quotaBytes;
  }

  bool get isExceeded => !isAdmin && usedBytes >= quotaBytes;

  StorageQuotaEvaluation evaluateUpload({
    required final int incomingBytes,
    final int? singleFileBytes,
  }) {
    final safeIncoming = incomingBytes < 0 ? 0 : incomingBytes;
    final checkSingle = singleFileBytes ?? safeIncoming;
    final rawRemaining = quotaBytes - (usedBytes + safeIncoming);
    final remainingAfter = rawRemaining < 0
        ? 0
        : (rawRemaining > quotaBytes ? quotaBytes : rawRemaining);

    if (isAdmin) {
      if (checkSingle > StorageQuotaPolicy.paidSingleFileMaxBytes) {
        return StorageQuotaEvaluation(
          allowed: false,
          requiresUpgrade: false,
          remainingBytesAfter: remainingAfter,
          reason: '1ファイルのサイズ上限 '
              '(${formatStorageBytes(StorageQuotaPolicy.paidSingleFileMaxBytes)}) '
              'を超えています。',
          status: this,
        );
      }
      return StorageQuotaEvaluation(
        allowed: true,
        requiresUpgrade: false,
        remainingBytesAfter: remainingAfter,
        reason: '管理者アカウントは既存の大量移行データの保全を含め許可されています。',
        status: this,
      );
    }

    if (checkSingle > maxSingleFileBytes) {
      return StorageQuotaEvaluation(
        allowed: false,
        requiresUpgrade: planId == 'free',
        remainingBytesAfter: remainingBytes,
        reason: '1ファイルのサイズ上限 (${formatStorageBytes(maxSingleFileBytes)}) を'
            '超えています (${formatStorageBytes(checkSingle)})。',
        status: this,
      );
    }

    if (usedBytes + safeIncoming > quotaBytes) {
      return StorageQuotaEvaluation(
        allowed: false,
        requiresUpgrade: planId == 'free',
        remainingBytesAfter: remainingBytes,
        reason: '添付ストレージ上限 (${formatStorageBytes(quotaBytes)}) を超過します。'
            '現在 ${formatStorageBytes(usedBytes)} 使用中 / '
            '残り ${formatStorageBytes(remainingBytes)} です'
            '（今回 ${formatStorageBytes(safeIncoming)}）。',
        status: this,
      );
    }

    return StorageQuotaEvaluation(
      allowed: true,
      requiresUpgrade: false,
      remainingBytesAfter: remainingAfter,
      reason: '容量上限内です。',
      status: this,
    );
  }
}

class StorageQuotaEvaluation {
  const StorageQuotaEvaluation({
    required this.allowed,
    required this.requiresUpgrade,
    required this.remainingBytesAfter,
    required this.reason,
    required this.status,
  });

  final bool allowed;
  final bool requiresUpgrade;
  final int remainingBytesAfter;
  final String reason;
  final StorageQuotaStatus status;
}

class StorageQuotaException implements Exception {
  const StorageQuotaException(
    this.message, {
    required this.evaluation,
  });

  final String message;
  final StorageQuotaEvaluation evaluation;

  @override
  String toString() => 'StorageQuotaException: $message';
}

abstract class StorageQuotaRepository {
  Future<StorageQuotaStatus> loadStatus({required String userId});
}

class SupabaseStorageQuotaRepository implements StorageQuotaRepository {
  SupabaseStorageQuotaRepository(this._client);

  static const int _pageSize = 500;
  final SupabaseClient _client;

  @override
  Future<StorageQuotaStatus> loadStatus({required final String userId}) async {
    final profile = await _client
        .from('user_profiles')
        .select('subscription_plan, is_admin, role')
        .eq('user_id', userId)
        .maybeSingle();

    final subscriptionPlan = profile?['subscription_plan']?.toString();
    final isAdminFlag = profile?['is_admin'] == true;
    final role = profile?['role']?.toString();
    final limits = StorageQuotaService.resolveLimits(
      subscriptionPlan: subscriptionPlan,
      isAdmin: isAdminFlag,
      role: role,
    );

    var usedBytes = 0;
    var attachmentCount = 0;
    var offset = 0;
    while (true) {
      final rows = await _client
          .from('attachments')
          .select('file_size')
          .eq('user_id', userId)
          .range(offset, offset + _pageSize - 1);

      if (rows.isEmpty) {
        break;
      }
      for (final row in rows) {
        final rawSize = row['file_size'];
        if (rawSize is int) {
          usedBytes += rawSize > 0 ? rawSize : 0;
        } else if (rawSize is num) {
          final parsed = rawSize.toInt();
          usedBytes += parsed > 0 ? parsed : 0;
        } else if (rawSize is String) {
          final parsed = int.tryParse(rawSize) ?? 0;
          usedBytes += parsed > 0 ? parsed : 0;
        }
        attachmentCount += 1;
      }
      if (rows.length < _pageSize) {
        break;
      }
      offset += _pageSize;
    }

    return StorageQuotaStatus(
      planId: limits.planId,
      isAdmin: limits.isAdminBypass,
      usedBytes: usedBytes,
      quotaBytes: limits.quotaBytes,
      maxSingleFileBytes: limits.maxSingleFileBytes,
      attachmentCount: attachmentCount,
    );
  }
}

class StorageQuotaService {
  const StorageQuotaService({
    required this.repository,
  });

  factory StorageQuotaService.supabase(final SupabaseClient client) {
    return StorageQuotaService(
      repository: SupabaseStorageQuotaRepository(client),
    );
  }

  final StorageQuotaRepository repository;

  static const int freeQuotaBytes = StorageQuotaPolicy.freeQuotaBytes;
  static const int freeSingleFileMaxBytes =
      StorageQuotaPolicy.freeSingleFileMaxBytes;
  static const int proQuotaBytes = StorageQuotaPolicy.proQuotaBytes;
  static const int paidSingleFileMaxBytes =
      StorageQuotaPolicy.paidSingleFileMaxBytes;
  static const int teamQuotaBytes = StorageQuotaPolicy.teamQuotaBytes;
  static const int adminQuotaBytes = StorageQuotaPolicy.adminQuotaBytes;

  static StorageQuotaLimits resolveLimits({
    required final String? subscriptionPlan,
    required final bool isAdmin,
    final String? role,
  }) {
    final normalizedRole = (role ?? '').trim().toLowerCase();
    if (isAdmin || normalizedRole == 'admin') {
      return const StorageQuotaLimits(
        planId: 'admin',
        quotaBytes: StorageQuotaPolicy.adminQuotaBytes,
        maxSingleFileBytes: StorageQuotaPolicy.paidSingleFileMaxBytes,
        isAdminBypass: true,
      );
    }

    final normalizedPlan = (subscriptionPlan ?? 'free').trim().toLowerCase();
    switch (normalizedPlan) {
      case 'team':
      case 'business':
      case 'enterprise':
        return const StorageQuotaLimits(
          planId: 'team',
          quotaBytes: StorageQuotaPolicy.teamQuotaBytes,
          maxSingleFileBytes: StorageQuotaPolicy.paidSingleFileMaxBytes,
          isAdminBypass: false,
        );
      case 'pro':
      case 'personal_pro':
      case 'plus':
      case 'premium':
        return const StorageQuotaLimits(
          planId: 'pro',
          quotaBytes: StorageQuotaPolicy.proQuotaBytes,
          maxSingleFileBytes: StorageQuotaPolicy.paidSingleFileMaxBytes,
          isAdminBypass: false,
        );
      default:
        return const StorageQuotaLimits(
          planId: 'free',
          quotaBytes: StorageQuotaPolicy.freeQuotaBytes,
          maxSingleFileBytes: StorageQuotaPolicy.freeSingleFileMaxBytes,
          isAdminBypass: false,
        );
    }
  }

  Future<StorageQuotaStatus> loadStatus({required final String userId}) {
    return repository.loadStatus(userId: userId);
  }

  Future<StorageQuotaEvaluation> evaluateUpload({
    required final String userId,
    required final int incomingBytes,
    final int? singleFileBytes,
  }) async {
    final status = await repository.loadStatus(userId: userId);
    return status.evaluateUpload(
      incomingBytes: incomingBytes,
      singleFileBytes: singleFileBytes,
    );
  }

  Future<void> assertCanUpload({
    required final String userId,
    required final int incomingBytes,
    final int? singleFileBytes,
  }) async {
    final evaluation = await evaluateUpload(
      userId: userId,
      incomingBytes: incomingBytes,
      singleFileBytes: singleFileBytes,
    );
    if (!evaluation.allowed) {
      throw StorageQuotaException(
        evaluation.reason,
        evaluation: evaluation,
      );
    }
  }
}

typedef PresignedUploadUrlResolver = Future<Uri> Function({
  required String bucketId,
  required String storagePath,
  required String contentType,
  required int contentLength,
});

/// Cloudflare R2 等の外部 S3 互換オブジェクトストレージ (署名付き PUT URL) へ
/// 直接バイナリを転送するための [DirectStorageUploadGateway] 実装。
class ExternalPresignedStorageGateway implements DirectStorageUploadGateway {
  ExternalPresignedStorageGateway({
    required this.resolveUploadUrl,
    final http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final PresignedUploadUrlResolver resolveUploadUrl;
  final http.Client _httpClient;

  @override
  Future<void> uploadBinary({
    required final String bucketId,
    required final String storagePath,
    required final Uint8List bytes,
    required final String contentType,
    required final bool upsert,
  }) async {
    final uploadUri = await resolveUploadUrl(
      bucketId: bucketId,
      storagePath: storagePath,
      contentType: contentType,
      contentLength: bytes.length,
    );
    final response = await _httpClient.put(
      uploadUri,
      headers: <String, String>{
        'Content-Type': contentType,
      },
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'External presigned upload failed (${response.statusCode}): '
        '${response.body}',
      );
    }
  }
}

String formatStorageBytes(final int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const int kb = 1024;
  const int mb = 1024 * 1024;
  const int gb = 1024 * 1024 * 1024;
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(2)} GB';
  }
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
  if (bytes >= kb) {
    return '${(bytes / kb).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
