import 'package:flutter/material.dart';

/// 動画翻訳ジョブの状態 (#2660).
enum VideoTranslationStatus {
  queued,
  validating,
  processing,
  done,
  rejected,
  error,
  dryRun;

  /// DB / API 文字列から安全に状態へ変換する。
  static VideoTranslationStatus fromWire(final String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'queued':
        return VideoTranslationStatus.queued;
      case 'validating':
        return VideoTranslationStatus.validating;
      case 'processing':
        return VideoTranslationStatus.processing;
      case 'done':
        return VideoTranslationStatus.done;
      case 'rejected':
        return VideoTranslationStatus.rejected;
      case 'dry_run':
        return VideoTranslationStatus.dryRun;
      default:
        return VideoTranslationStatus.error;
    }
  }

  /// Supabase / CLI 互換の wire 文字列。
  String get wireValue {
    switch (this) {
      case VideoTranslationStatus.queued:
        return 'queued';
      case VideoTranslationStatus.validating:
        return 'validating';
      case VideoTranslationStatus.processing:
        return 'processing';
      case VideoTranslationStatus.done:
        return 'done';
      case VideoTranslationStatus.rejected:
        return 'rejected';
      case VideoTranslationStatus.error:
        return 'error';
      case VideoTranslationStatus.dryRun:
        return 'dry_run';
    }
  }

  /// 再生可能な完了状態かどうか。
  bool get isPlayable => this == VideoTranslationStatus.done;
}

/// D-ID Video Translate が受け付ける言語コードと D-ID API 言語名の定義 (#2660).
const Map<String, String> didSupportedLanguageMap = <String, String>{
  'ja': 'Japanese',
  'en': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
  'ko': 'Korean',
  'zh': 'Chinese',
  'ar': 'Arabic',
  'hi': 'Hindi',
};

/// BCP-47 言語コードを正規化し、D-ID API の言語名へ変換する。
String? resolveDidLanguageName(final String languageCode) {
  final String normalized =
      languageCode.trim().toLowerCase().replaceAll('_', '-');
  if (normalized.isEmpty) {
    return null;
  }
  final String base = normalized.split('-').first;
  return didSupportedLanguageMap[base];
}

/// 個別の多言語動画翻訳トラック (#2660).
@immutable
class VideoTranslationTrack {
  const VideoTranslationTrack({
    required this.id,
    required this.sourceVideoId,
    required this.sourceVideoUrl,
    required this.languageCode,
    required this.didLanguageName,
    required this.status,
    required this.durationSeconds,
    required this.maxDurationCapSeconds,
    required this.estimatedCostUsd,
    required this.maxCostCapUsd,
    required this.createdAt,
    this.providerJobId,
    this.resultUrl,
    this.subtitlesUrl,
    this.thumbnailUrl,
    this.aiProvenanceDisclosure = 'AI 生成・リップシンク翻訳動画',
    this.resultExpiresAt,
    this.errorReason,
    this.metadata = const <String, Object?>{},
  });

  factory VideoTranslationTrack.fromMap(final Map<String, Object?> row) {
    final String code =
        (row['language_code']?.toString() ?? 'en').trim().toLowerCase();
    return VideoTranslationTrack(
      id: (row['id']?.toString() ?? '').trim(),
      sourceVideoId: (row['source_video_id']?.toString() ?? '').trim(),
      sourceVideoUrl: (row['source_video_url']?.toString() ?? '').trim(),
      languageCode: code,
      didLanguageName: (row['did_language_name']?.toString() ??
              resolveDidLanguageName(code) ??
              'English')
          .trim(),
      status: VideoTranslationStatus.fromWire(
        row['status']?.toString() ?? 'queued',
      ),
      durationSeconds: (row['duration_seconds'] as num?)?.toDouble() ?? 0.0,
      maxDurationCapSeconds:
          (row['max_duration_cap_seconds'] as num?)?.toInt() ?? 120,
      estimatedCostUsd: (row['estimated_cost_usd'] as num?)?.toDouble() ?? 0.0,
      maxCostCapUsd: (row['max_cost_cap_usd'] as num?)?.toDouble() ?? 5.0,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      providerJobId: row['provider_job_id']?.toString(),
      resultUrl: row['result_url']?.toString(),
      subtitlesUrl: row['subtitles_url']?.toString(),
      thumbnailUrl: row['thumbnail_url']?.toString(),
      aiProvenanceDisclosure:
          (row['ai_provenance_disclosure']?.toString() ?? 'AI 生成・リップシンク翻訳動画')
              .trim(),
      resultExpiresAt:
          DateTime.tryParse(row['result_expires_at']?.toString() ?? ''),
      errorReason: row['error_reason']?.toString(),
      metadata: row['metadata'] is Map
          ? Map<String, Object?>.from(row['metadata'] as Map)
          : const <String, Object?>{},
    );
  }

  final String id;
  final String sourceVideoId;
  final String sourceVideoUrl;
  final String languageCode;
  final String didLanguageName;
  final VideoTranslationStatus status;
  final double durationSeconds;
  final int maxDurationCapSeconds;
  final double estimatedCostUsd;
  final double maxCostCapUsd;
  final DateTime createdAt;
  final String? providerJobId;
  final String? resultUrl;
  final String? subtitlesUrl;
  final String? thumbnailUrl;
  final String aiProvenanceDisclosure;
  final DateTime? resultExpiresAt;
  final String? errorReason;
  final Map<String, Object?> metadata;

  /// D-ID 生成動画 URL（24 時間有効）が現在利用可能かどうか。
  bool isResultActiveAt(final DateTime nowUtc) {
    if (!status.isPlayable || resultUrl == null || resultUrl!.trim().isEmpty) {
      return false;
    }
    if (resultExpiresAt == null) {
      return true;
    }
    return nowUtc.isBefore(resultExpiresAt!);
  }
}

/// 言語解決の理由 (#2660).
enum MultilingualMatchReason {
  userPreference,
  exactLocale,
  baseLanguage,
  fallbackLanguage,
  firstAvailable,
  none,
}

/// 解決された再生トラックとフォールバック結果 (#2660).
@immutable
class ResolvedMultilingualPlayback {
  const ResolvedMultilingualPlayback({
    required this.resolvedLanguageCode,
    required this.reason,
    this.track,
  });

  final String resolvedLanguageCode;
  final MultilingualMatchReason reason;
  final VideoTranslationTrack? track;
}

/// `Locale` を正規化済み小文字タグへ変換する。
String normalizeLocaleTag(final Locale locale) {
  final String lang = locale.languageCode.trim().toLowerCase();
  final String? country = locale.countryCode?.trim().toLowerCase();
  if (country == null || country.isEmpty) {
    return lang;
  }
  return '$lang-$country';
}

/// ユーザー明示設定・ブラウザ/端末 `Locale`・フォールバック順で最適トラックを解決する。
ResolvedMultilingualPlayback resolveBestLocalizedTrack({
  required final List<VideoTranslationTrack> tracks,
  required final Locale deviceLocale,
  final String? preferredLanguageCode,
  final String fallbackLanguageCode = 'en',
  final DateTime? nowUtc,
}) {
  if (tracks.isEmpty) {
    return ResolvedMultilingualPlayback(
      resolvedLanguageCode: normalizeLocaleTag(deviceLocale),
      reason: MultilingualMatchReason.none,
    );
  }

  final DateTime evalNow = (nowUtc ?? DateTime.now()).toUtc();
  final List<VideoTranslationTrack> playable = tracks
      .where((final VideoTranslationTrack t) => t.isResultActiveAt(evalNow))
      .toList();
  final List<VideoTranslationTrack> pool =
      playable.isNotEmpty ? playable : tracks;

  VideoTranslationTrack? findByTag(final String rawTag) {
    final String normalized = rawTag.trim().toLowerCase().replaceAll('_', '-');
    if (normalized.isEmpty) {
      return null;
    }
    for (final VideoTranslationTrack t in pool) {
      if (t.languageCode.toLowerCase() == normalized) {
        return t;
      }
    }
    final String base = normalized.split('-').first;
    for (final VideoTranslationTrack t in pool) {
      if (t.languageCode.toLowerCase().split('-').first == base) {
        return t;
      }
    }
    return null;
  }

  if (preferredLanguageCode != null &&
      preferredLanguageCode.trim().isNotEmpty) {
    final VideoTranslationTrack? prefMatch = findByTag(preferredLanguageCode);
    if (prefMatch != null) {
      return ResolvedMultilingualPlayback(
        resolvedLanguageCode: prefMatch.languageCode,
        reason: MultilingualMatchReason.userPreference,
        track: prefMatch,
      );
    }
  }

  final String fullDeviceTag = normalizeLocaleTag(deviceLocale);
  for (final VideoTranslationTrack t in pool) {
    if (t.languageCode.toLowerCase() == fullDeviceTag) {
      return ResolvedMultilingualPlayback(
        resolvedLanguageCode: t.languageCode,
        reason: MultilingualMatchReason.exactLocale,
        track: t,
      );
    }
  }

  final String deviceBase = deviceLocale.languageCode.trim().toLowerCase();
  for (final VideoTranslationTrack t in pool) {
    if (t.languageCode.toLowerCase().split('-').first == deviceBase) {
      return ResolvedMultilingualPlayback(
        resolvedLanguageCode: t.languageCode,
        reason: MultilingualMatchReason.baseLanguage,
        track: t,
      );
    }
  }

  final VideoTranslationTrack? fallbackMatch =
      findByTag(fallbackLanguageCode) ?? findByTag('ja');
  if (fallbackMatch != null) {
    return ResolvedMultilingualPlayback(
      resolvedLanguageCode: fallbackMatch.languageCode,
      reason: MultilingualMatchReason.fallbackLanguage,
      track: fallbackMatch,
    );
  }

  final VideoTranslationTrack first = pool.first;
  return ResolvedMultilingualPlayback(
    resolvedLanguageCode: first.languageCode,
    reason: MultilingualMatchReason.firstAvailable,
    track: first,
  );
}

/// 新規動画翻訳キュー投入の入力データと上限検証 (#2660).
@immutable
class QueueVideoTranslationInput {
  const QueueVideoTranslationInput({
    required this.sourceVideoId,
    required this.sourceVideoUrl,
    required this.languageCode,
    required this.durationSeconds,
    this.maxDurationCapSeconds = 120,
    this.maxCostCapUsd = 5.0,
    this.rateUsdPerSecond = 0.035,
  });

  final String sourceVideoId;
  final String sourceVideoUrl;
  final String languageCode;
  final double durationSeconds;
  final int maxDurationCapSeconds;
  final double maxCostCapUsd;
  final double rateUsdPerSecond;

  double get estimatedCostUsd =>
      double.parse((durationSeconds * rateUsdPerSecond).toStringAsFixed(6));

  String? validate() {
    if (sourceVideoId.trim().isEmpty) {
      return '動画IDを入力してください。';
    }
    final Uri? parsed = Uri.tryParse(sourceVideoUrl.trim());
    if (parsed == null ||
        parsed.scheme.toLowerCase() != 'https' ||
        parsed.host.isEmpty) {
      return '公開 https:// 動画URLを指定してください。';
    }
    if (resolveDidLanguageName(languageCode) == null) {
      return 'D-ID 未対応の言語コードです: $languageCode';
    }
    if (durationSeconds <= 0) {
      return '動画尺（秒）は 0 より大きい値を指定してください。';
    }
    if (maxDurationCapSeconds <= 0 || maxDurationCapSeconds > 600) {
      return '上限尺は 1〜600 秒の範囲で設定してください。';
    }
    if (durationSeconds > maxDurationCapSeconds) {
      return '動画尺 (${durationSeconds.toStringAsFixed(1)}s) が上限 (${maxDurationCapSeconds}s) を超過しています。';
    }
    if (estimatedCostUsd > maxCostCapUsd) {
      return '概算コスト USD ${estimatedCostUsd.toStringAsFixed(4)} が上限 USD ${maxCostCapUsd.toStringAsFixed(2)} を超過しています。';
    }
    return null;
  }
}

/// 多言語翻訳サマリー集計モデル (#2660).
@immutable
class MultilingualVideoSummary {
  const MultilingualVideoSummary({
    required this.totalJobs,
    required this.doneJobs,
    required this.activeJobs,
    required this.failedJobs,
    required this.totalDurationSeconds,
    required this.totalEstimatedCostUsd,
    required this.distinctLanguages,
  });

  factory MultilingualVideoSummary.fromList(
    final List<VideoTranslationTrack> tracks,
  ) {
    int done = 0;
    int active = 0;
    int failed = 0;
    double durationSum = 0.0;
    double costSum = 0.0;
    final Set<String> langs = <String>{};

    for (final VideoTranslationTrack t in tracks) {
      if (t.status == VideoTranslationStatus.done) {
        done += 1;
      } else if (t.status == VideoTranslationStatus.queued ||
          t.status == VideoTranslationStatus.validating ||
          t.status == VideoTranslationStatus.processing) {
        active += 1;
      } else if (t.status == VideoTranslationStatus.rejected ||
          t.status == VideoTranslationStatus.error) {
        failed += 1;
      }
      durationSum += t.durationSeconds;
      costSum += t.estimatedCostUsd;
      langs.add(t.languageCode);
    }

    return MultilingualVideoSummary(
      totalJobs: tracks.length,
      doneJobs: done,
      activeJobs: active,
      failedJobs: failed,
      totalDurationSeconds: durationSum,
      totalEstimatedCostUsd: costSum,
      distinctLanguages: langs.length,
    );
  }

  final int totalJobs;
  final int doneJobs;
  final int activeJobs;
  final int failedJobs;
  final double totalDurationSeconds;
  final double totalEstimatedCostUsd;
  final int distinctLanguages;
}
