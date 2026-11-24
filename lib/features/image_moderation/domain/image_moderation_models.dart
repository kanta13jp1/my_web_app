import 'package:flutter/foundation.dart';

/// 画像モデレーション判定ステータス (#2644).
enum ImageModerationStatus {
  pending('pending', '解析待ち'),
  approved('approved', '承認済み'),
  flagged('flagged', '要確認フラグ'),
  hidden('hidden', '自動非表示');

  const ImageModerationStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ImageModerationStatus fromWire(String? raw) {
    for (final status in ImageModerationStatus.values) {
      if (status.wireValue == raw) {
        return status;
      }
    }
    return ImageModerationStatus.pending;
  }
}

/// ViT モデレーション・自動タグ付けされた画像レコード (#2644).
@immutable
class ModeratedImageAsset {
  const ModeratedImageAsset({
    required this.id,
    required this.storageBucket,
    required this.storagePath,
    required this.tags,
    required this.safetyScore,
    required this.moderationStatus,
    required this.isHidden,
    required this.externalTransferConsented,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String storageBucket;
  final String storagePath;
  final List<String> tags;
  final double safetyScore;
  final ImageModerationStatus moderationStatus;
  final bool isHidden;
  final bool externalTransferConsented;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isRestricted =>
      isHidden ||
      moderationStatus == ImageModerationStatus.hidden ||
      moderationStatus == ImageModerationStatus.flagged;

  ModeratedImageAsset copyWith({
    String? id,
    List<String>? tags,
    double? safetyScore,
    ImageModerationStatus? moderationStatus,
    bool? isHidden,
    bool? externalTransferConsented,
    DateTime? updatedAt,
  }) {
    return ModeratedImageAsset(
      id: id ?? this.id,
      storageBucket: storageBucket,
      storagePath: storagePath,
      tags: tags ?? this.tags,
      safetyScore: safetyScore ?? this.safetyScore,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      isHidden: isHidden ?? this.isHidden,
      externalTransferConsented:
          externalTransferConsented ?? this.externalTransferConsented,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toInsertPayload({required String userId}) {
    return <String, Object?>{
      'user_id': userId,
      'storage_bucket': storageBucket,
      'storage_path': storagePath,
      'tags': tags,
      'safety_score': double.parse(safetyScore.toStringAsFixed(4)),
      'moderation_status': ImageModerationStatus.pending.wireValue,
      'is_hidden': false,
      'external_transfer_consented': externalTransferConsented,
    };
  }

  static ModeratedImageAsset fromSupabaseRow(Map<String, Object?> row) {
    final rawScore = row['safety_score'];
    final double score;
    if (rawScore is num && rawScore.isFinite) {
      score = rawScore.toDouble().clamp(0.0, 1.0);
    } else {
      score = 1.0;
    }

    final rawTags = row['tags'];
    final parsedTags = <String>[];
    if (rawTags is List<Object?>) {
      for (final item in rawTags) {
        if (item is String && item.trim().isNotEmpty) {
          parsedTags.add(item.trim().toLowerCase());
        }
      }
    }

    return ModeratedImageAsset(
      id: (row['id'] as String?) ?? '',
      storageBucket: (row['storage_bucket'] as String?) ?? 'user-uploads',
      storagePath: (row['storage_path'] as String?) ?? '',
      tags: List<String>.unmodifiable(parsedTags),
      safetyScore: score,
      moderationStatus: ImageModerationStatus.fromWire(
        row['moderation_status'] as String?,
      ),
      isHidden: (row['is_hidden'] as bool?) ?? false,
      externalTransferConsented:
          (row['external_transfer_consented'] as bool?) ?? false,
      createdAt: _parseDateTime(row['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDateTime(row['updated_at']) ?? DateTime.now().toUtc(),
    );
  }
}

/// ローカルパス検証・自動タグ生成・閾値判定 (#2644).
class LocalImageModerationAnalyzer {
  static const List<String> _allowedExtensions = <String>[
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
  ];
  static const Set<String> _recognizedTags = <String>{
    'receipt',
    'invoice',
    'document',
    'portrait',
    'landscape',
    'food',
    'product',
    'chart',
  };
  static const Set<String> _unsafeTerms = <String>{
    'nsfw',
    'explicit',
    'malware',
    'violence',
    'abuse',
  };

  static String validateRelativeImagePath(String rawPath) {
    final path = rawPath.trim();
    if (path.isEmpty ||
        path.length > 300 ||
        path.startsWith('/') ||
        path.contains('\\') ||
        path.contains('..')) {
      throw const FormatException('安全な相対画像パスを入力してください（.. や先頭/は不可）。');
    }
    final lower = path.toLowerCase();
    final validExt = _allowedExtensions.any(lower.endsWith);
    if (!validExt) {
      throw const FormatException(
        '対応画像拡張子（.png/.jpg/.jpeg/.webp/.gif）のみ登録可能です。',
      );
    }
    return path;
  }

  static ModeratedImageAsset prepareUploadDraft({
    required String storageBucket,
    required String storagePath,
    required bool externalTransferConsented,
    DateTime? now,
  }) {
    final safePath = validateRelativeImagePath(storagePath);
    final pathParts = safePath
        .toLowerCase()
        .split(RegExp(r'[/._-]+'))
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

    final tags = <String>[];
    for (final part in pathParts) {
      if (_recognizedTags.contains(part) && !tags.contains(part)) {
        tags.add(part);
      }
    }
    if (tags.isEmpty) {
      tags.add('uploaded-image');
    }

    final hasUnsafe = pathParts.any(_unsafeTerms.contains);
    final double score = hasUnsafe ? 0.22 : 0.96;
    final ImageModerationStatus status = hasUnsafe
        ? ImageModerationStatus.hidden
        : ImageModerationStatus.approved;
    final timestamp = (now ?? DateTime.now()).toUtc();

    return ModeratedImageAsset(
      id: 'local-${timestamp.millisecondsSinceEpoch}',
      storageBucket:
          storageBucket.trim().isEmpty ? 'user-uploads' : storageBucket.trim(),
      storagePath: safePath,
      tags: List<String>.unmodifiable(tags),
      safetyScore: score,
      moderationStatus: status,
      isHidden: hasUnsafe,
      externalTransferConsented: externalTransferConsented,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}

/// 画像モデレーション永続化・検索契約 (#2644).
abstract interface class ImageModerationRepository {
  Future<List<ModeratedImageAsset>> fetchAssets();
  Future<ModeratedImageAsset> registerUploadedImage(
    ModeratedImageAsset draft,
  );
}

DateTime? _parseDateTime(Object? raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw.trim());
  }
  return null;
}
