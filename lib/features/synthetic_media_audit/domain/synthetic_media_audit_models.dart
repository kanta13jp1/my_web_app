import 'package:flutter/foundation.dart';

/// 合成メディア動画のモデレーション状態 (#2661).
enum SyntheticMediaModerationStatus {
  pending('pending', '承認待ち'),
  approved('approved', '公開承認済み'),
  rejected('rejected', '差し戻し / 却下');

  const SyntheticMediaModerationStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static SyntheticMediaModerationStatus fromWire(final String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final SyntheticMediaModerationStatus status in values) {
      if (status.wireValue == normalized) {
        return status;
      }
    }
    return SyntheticMediaModerationStatus.pending;
  }
}

/// 著作権・肖像権同意の検証状態 (#2661).
enum ConsentVerificationStatus {
  pending('pending', '未検証'),
  verified('verified', '同意確認済み'),
  rejected('rejected', '同意不可 / 否認');

  const ConsentVerificationStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ConsentVerificationStatus fromWire(final String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final ConsentVerificationStatus status in values) {
      if (status.wireValue == normalized) {
        return status;
      }
    }
    return ConsentVerificationStatus.pending;
  }
}

/// Track-and-Trace 来歴検証プロバイダ (#2661).
enum TrackAndTraceProvider {
  none('none', '未設定'),
  c2pa('c2pa', 'C2PA Content Credentials'),
  digitalWatermark('digital_watermark', 'Digital Watermark'),
  custom('custom', 'カスタム来歴署名');

  const TrackAndTraceProvider(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static TrackAndTraceProvider fromWire(final String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final TrackAndTraceProvider provider in values) {
      if (provider.wireValue == normalized) {
        return provider;
      }
    }
    return TrackAndTraceProvider.none;
  }
}

/// 合成メディア倫理監査対象の動画レコード (#2661).
@immutable
class SyntheticMediaVideo {
  const SyntheticMediaVideo({
    required this.id,
    required this.userId,
    required this.title,
    required this.videoUrl,
    required this.sourceProvider,
    required this.copyrightConsentStatus,
    required this.likenessConsentStatus,
    required this.commercialWatermarkPresent,
    required this.celebrityLikenessCleared,
    required this.trackAndTraceProvider,
    required this.moderationStatus,
    required this.isApproved,
    required this.createdAt,
    required this.updatedAt,
    this.trackAndTraceId,
    this.trackAndTraceMetadata = const <String, String>{},
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
  });

  factory SyntheticMediaVideo.fromSupabaseRow(final Map<String, Object?> row) {
    final Map<String, String> parsedMeta = <String, String>{};
    final Object rawMeta =
        row['track_and_trace_metadata'] ?? const <String, String>{};
    if (rawMeta is Map) {
      for (final MapEntry<Object?, Object?> entry in rawMeta.entries) {
        if (entry.key != null && entry.value != null) {
          parsedMeta[entry.key.toString()] = entry.value.toString();
        }
      }
    }

    final SyntheticMediaModerationStatus status =
        SyntheticMediaModerationStatus.fromWire(
      row['moderation_status']?.toString(),
    );
    final bool approvedFlag = (row['is_approved'] as bool?) ?? false;

    return SyntheticMediaVideo(
      id: (row['id']?.toString() ?? '').trim(),
      userId: (row['user_id']?.toString() ?? '').trim(),
      title: (row['title']?.toString() ?? '').trim(),
      videoUrl: (row['video_url']?.toString() ?? '').trim(),
      sourceProvider: (row['source_provider']?.toString() ?? 'd_id').trim(),
      copyrightConsentStatus: ConsentVerificationStatus.fromWire(
        row['copyright_consent_status']?.toString(),
      ),
      likenessConsentStatus: ConsentVerificationStatus.fromWire(
        row['likeness_consent_status']?.toString(),
      ),
      commercialWatermarkPresent:
          (row['commercial_watermark_present'] as bool?) ?? false,
      celebrityLikenessCleared:
          (row['celebrity_likeness_cleared'] as bool?) ?? false,
      trackAndTraceProvider: TrackAndTraceProvider.fromWire(
        row['track_and_trace_provider']?.toString(),
      ),
      trackAndTraceId: row['track_and_trace_id']?.toString(),
      trackAndTraceMetadata: Map<String, String>.unmodifiable(parsedMeta),
      moderationStatus: status,
      isApproved:
          approvedFlag && status == SyntheticMediaModerationStatus.approved,
      reviewedBy: row['reviewed_by']?.toString(),
      reviewedAt: DateTime.tryParse(row['reviewed_at']?.toString() ?? ''),
      reviewNote: row['review_note']?.toString(),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String userId;
  final String title;
  final String videoUrl;
  final String sourceProvider;
  final ConsentVerificationStatus copyrightConsentStatus;
  final ConsentVerificationStatus likenessConsentStatus;
  final bool commercialWatermarkPresent;
  final bool celebrityLikenessCleared;
  final TrackAndTraceProvider trackAndTraceProvider;
  final String? trackAndTraceId;
  final Map<String, String> trackAndTraceMetadata;
  final SyntheticMediaModerationStatus moderationStatus;
  final bool isApproved;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Ethics Pledge に基づく公開承認要件をすべて満たしているか。
  bool get meetsApprovalPrerequisites =>
      copyrightConsentStatus == ConsentVerificationStatus.verified &&
      likenessConsentStatus == ConsentVerificationStatus.verified &&
      celebrityLikenessCleared &&
      commercialWatermarkPresent;

  /// 不足している倫理・来歴チェック項目の一覧を返す。
  List<String> get missingApprovalRequirements {
    final List<String> missing = <String>[];
    if (copyrightConsentStatus != ConsentVerificationStatus.verified) {
      missing.add('著作権同意の確認');
    }
    if (likenessConsentStatus != ConsentVerificationStatus.verified) {
      missing.add('肖像権・音声同意の確認');
    }
    if (!celebrityLikenessCleared) {
      missing.add('著名人なりすまし排除確認');
    }
    if (!commercialWatermarkPresent) {
      missing.add('商用透かし / AI 生成表示の確認');
    }
    return missing;
  }

  SyntheticMediaVideo copyWith({
    final SyntheticMediaModerationStatus? moderationStatus,
    final bool? isApproved,
    final String? reviewedBy,
    final DateTime? reviewedAt,
    final String? reviewNote,
    final DateTime? updatedAt,
  }) {
    return SyntheticMediaVideo(
      id: id,
      userId: userId,
      title: title,
      videoUrl: videoUrl,
      sourceProvider: sourceProvider,
      copyrightConsentStatus: copyrightConsentStatus,
      likenessConsentStatus: likenessConsentStatus,
      commercialWatermarkPresent: commercialWatermarkPresent,
      celebrityLikenessCleared: celebrityLikenessCleared,
      trackAndTraceProvider: trackAndTraceProvider,
      trackAndTraceId: trackAndTraceId,
      trackAndTraceMetadata: trackAndTraceMetadata,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      isApproved: isApproved ?? this.isApproved,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNote: reviewNote ?? this.reviewNote,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 追記専用監査ログエントリ (#2661).
@immutable
class SyntheticMediaAuditLogEntry {
  const SyntheticMediaAuditLogEntry({
    required this.id,
    required this.videoId,
    required this.action,
    required this.newStatus,
    required this.createdAt,
    this.actorId,
    this.previousStatus,
    this.reason,
  });

  factory SyntheticMediaAuditLogEntry.fromSupabaseRow(
    final Map<String, Object?> row,
  ) {
    return SyntheticMediaAuditLogEntry(
      id: (row['id']?.toString() ?? '').trim(),
      videoId: (row['video_id']?.toString() ?? '').trim(),
      actorId: row['actor_id']?.toString(),
      action: (row['action']?.toString() ?? 'submitted').trim(),
      previousStatus: row['previous_status']?.toString(),
      newStatus: (row['new_status']?.toString() ?? 'pending').trim(),
      reason: row['reason']?.toString(),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String videoId;
  final String? actorId;
  final String action;
  final String? previousStatus;
  final String newStatus;
  final String? reason;
  final DateTime createdAt;
}

/// 新規合成メディア動画提出の入力と事前検証 (#2661).
@immutable
class SubmitSyntheticMediaInput {
  const SubmitSyntheticMediaInput({
    required this.title,
    required this.videoUrl,
    this.sourceProvider = 'd_id',
    this.copyrightConsentStatus = ConsentVerificationStatus.pending,
    this.likenessConsentStatus = ConsentVerificationStatus.pending,
    this.commercialWatermarkPresent = false,
    this.celebrityLikenessCleared = false,
    this.trackAndTraceProvider = TrackAndTraceProvider.none,
    this.trackAndTraceId,
    this.trackAndTraceMetadata = const <String, String>{},
  });

  final String title;
  final String videoUrl;
  final String sourceProvider;
  final ConsentVerificationStatus copyrightConsentStatus;
  final ConsentVerificationStatus likenessConsentStatus;
  final bool commercialWatermarkPresent;
  final bool celebrityLikenessCleared;
  final TrackAndTraceProvider trackAndTraceProvider;
  final String? trackAndTraceId;
  final Map<String, String> trackAndTraceMetadata;

  String? validate() {
    final String cleanTitle = title.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 200) {
      return '動画タイトルは 1〜200 文字で入力してください。';
    }
    final Uri? parsed = Uri.tryParse(videoUrl.trim());
    if (parsed == null ||
        parsed.scheme.toLowerCase() != 'https' ||
        parsed.host.isEmpty) {
      return '公開 https:// 動画 URL を指定してください。';
    }
    if (trackAndTraceProvider != TrackAndTraceProvider.none &&
        (trackAndTraceId == null || trackAndTraceId!.trim().isEmpty)) {
      return 'Track-and-Trace プロバイダ選択時は検証 ID を入力してください。';
    }
    return null;
  }
}
