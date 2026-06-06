import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

typedef DirectUploadMetadataBuilder = Map<String, dynamic> Function(
  DirectStorageUploadObject object,
);

class DirectStorageUploadObject {
  DirectStorageUploadObject({
    required this.bucketId,
    required this.userId,
    required this.storagePath,
    required this.originalFileName,
    required this.contentType,
    required this.sizeBytes,
  });

  final String bucketId;
  final String userId;
  final String storagePath;
  final String originalFileName;
  final String contentType;
  final int sizeBytes;
}

class DirectStorageUploadResult {
  DirectStorageUploadResult({
    required this.object,
    required this.metadataRow,
  });

  final DirectStorageUploadObject object;
  final Map<String, dynamic> metadataRow;

  String get bucketId => object.bucketId;
  String get storagePath => object.storagePath;
}

abstract class DirectStorageUploadGateway {
  Future<void> uploadBinary({
    required final String bucketId,
    required final String storagePath,
    required final Uint8List bytes,
    required final String contentType,
    required final bool upsert,
  });
}

abstract class DirectUploadMetadataStore {
  Future<Map<String, dynamic>> insert({
    required final String tableName,
    required final Map<String, dynamic> values,
  });
}

class SupabaseDirectStorageUploadGateway implements DirectStorageUploadGateway {
  SupabaseDirectStorageUploadGateway(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<void> uploadBinary({
    required final String bucketId,
    required final String storagePath,
    required final Uint8List bytes,
    required final String contentType,
    required final bool upsert,
  }) async {
    await _supabase.storage.from(bucketId).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: upsert,
          ),
        );
  }
}

class SupabaseDirectUploadMetadataStore implements DirectUploadMetadataStore {
  SupabaseDirectUploadMetadataStore(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<Map<String, dynamic>> insert({
    required final String tableName,
    required final Map<String, dynamic> values,
  }) async {
    final response =
        await _supabase.from(tableName).insert(values).select().single();
    return Map<String, dynamic>.from(response as Map);
  }
}

class DirectStorageUploadService {
  DirectStorageUploadService({
    required this.storage,
    required this.metadataStore,
  });

  factory DirectStorageUploadService.supabase(final SupabaseClient client) {
    return DirectStorageUploadService(
      storage: SupabaseDirectStorageUploadGateway(client),
      metadataStore: SupabaseDirectUploadMetadataStore(client),
    );
  }

  final DirectStorageUploadGateway storage;
  final DirectUploadMetadataStore metadataStore;

  Future<DirectStorageUploadResult> uploadAndInsertMetadata({
    required final String bucketId,
    required final String tableName,
    required final String userId,
    required final Uint8List bytes,
    required final String originalFileName,
    required final String contentType,
    required final DirectUploadMetadataBuilder metadataBuilder,
    final Iterable<String> ownerPathSegments = const <String>[],
    final DateTime? now,
    final bool upsert = false,
    final bool enforceUserIdColumn = true,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes.length, 'bytes', 'must not be empty');
    }

    final ownerId = _validateOwnerId(userId);
    final storagePath = buildOwnerScopedPath(
      userId: ownerId,
      originalFileName: originalFileName,
      ownerPathSegments: ownerPathSegments,
      now: now,
    );
    final object = DirectStorageUploadObject(
      bucketId: bucketId,
      userId: ownerId,
      storagePath: storagePath,
      originalFileName: originalFileName,
      contentType: contentType,
      sizeBytes: bytes.length,
    );
    final metadataValues = metadataBuilder(object);
    if (enforceUserIdColumn && metadataValues['user_id'] != ownerId) {
      throw ArgumentError.value(
        metadataValues['user_id'],
        'metadataBuilder',
        'must set user_id to the authenticated owner id',
      );
    }

    await storage.uploadBinary(
      bucketId: bucketId,
      storagePath: storagePath,
      bytes: bytes,
      contentType: contentType,
      upsert: upsert,
    );
    final metadataRow = await metadataStore.insert(
      tableName: tableName,
      values: metadataValues,
    );

    return DirectStorageUploadResult(
      object: object,
      metadataRow: metadataRow,
    );
  }

  static String buildOwnerScopedPath({
    required final String userId,
    required final String originalFileName,
    final Iterable<String> ownerPathSegments = const <String>[],
    final DateTime? now,
  }) {
    final ownerId = _validateOwnerId(userId);
    final safeFileName = sanitizeFileName(originalFileName);
    final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final segments = <String>[
      ownerId,
      ...ownerPathSegments.map(sanitizePathSegment),
      '${timestamp}_$safeFileName',
    ];

    return segments.join('/');
  }

  static String sanitizeFileName(final String fileName) {
    final baseName = _lastPathComponent(fileName);
    final lastDot = baseName.lastIndexOf('.');
    final nameWithoutExtension =
        lastDot > 0 ? baseName.substring(0, lastDot) : baseName;
    final rawExtension = lastDot > 0 ? baseName.substring(lastDot + 1) : '';
    final safeName = _sanitizeToken(nameWithoutExtension, fallback: 'file');
    final safeExtension =
        rawExtension.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();

    if (safeExtension.isEmpty) {
      return safeName;
    }
    return '$safeName.$safeExtension';
  }

  static String sanitizePathSegment(final String value) {
    return _sanitizeToken(value, fallback: 'segment');
  }

  static String _validateOwnerId(final String userId) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty || trimmed.contains('/') || trimmed.contains('\\')) {
      throw ArgumentError.value(
        userId,
        'userId',
        'must be a non-empty owner id without path separators',
      );
    }
    return trimmed;
  }

  static String _lastPathComponent(final String value) {
    final normalized = value.replaceAll('\\', '/');
    final parts = normalized
        .split('/')
        .where((final part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '';
    }
    return parts.last;
  }

  static String _sanitizeToken(
    final String value, {
    required final String fallback,
  }) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '_')
        .replaceAll(RegExp(r'[^\w\-.]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[_.-]+|[_.-]+$'), '');

    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      return fallback;
    }
    return sanitized;
  }
}
