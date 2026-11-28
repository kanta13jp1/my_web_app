/// Verification status for ingested AI investment records (#2761).
enum InvestmentVerificationStatus {
  needsVerification('needs_verification', '要検証'),
  verified('verified', '確認済み'),
  rejected('rejected', '却下');

  const InvestmentVerificationStatus(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static InvestmentVerificationStatus fromWire(final String? raw) {
    final normalized = (raw ?? '').trim();
    for (final value in InvestmentVerificationStatus.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return InvestmentVerificationStatus.needsVerification;
  }
}

/// Normalizes untyped JSON maps into `Map<String, Object?>`.
Map<String, Object?> normalizeAiInvestmentMap(final Object? raw) {
  if (raw is Map<Object?, Object?>) {
    final out = <String, Object?>{};
    for (final entry in raw.entries) {
      out[entry.key.toString()] = entry.value;
    }
    return out;
  }
  return <String, Object?>{};
}

/// Immutable AI company investment trend record (#2761).
class AiInvestmentRecord {
  const AiInvestmentRecord({
    required this.id,
    required this.companyName,
    required this.quarter,
    required this.roundStage,
    required this.amountDisplay,
    required this.currency,
    required this.announcedAt,
    required this.sourceName,
    required this.sourceUrl,
    required this.investors,
    required this.summary,
    required this.targetProviderCategory,
    required this.rawFormat,
    required this.dedupKey,
    required this.verificationStatus,
    required this.verificationLabel,
    required this.requiresManualVerification,
    required this.verificationNote,
    required this.isSampleTemplate,
    required this.ingestedAt,
    this.amountUsdMillions,
    this.verifiedAt,
    this.verifiedBy,
  });

  factory AiInvestmentRecord.fromMap(final Map<Object?, Object?> raw) {
    final map = normalizeAiInvestmentMap(raw);
    final status = InvestmentVerificationStatus.fromWire(
      map['verification_status']?.toString(),
    );
    final rawInvestors = map['investors'];
    final investors = <String>[];
    if (rawInvestors is List<Object?>) {
      for (final item in rawInvestors) {
        final text = (item ?? '').toString().trim();
        if (text.isNotEmpty) {
          investors.add(text);
        }
      }
    }
    final rawAmount = map['amount_usd_millions'];
    final double? amountUsdMillions =
        rawAmount is num ? rawAmount.toDouble() : null;

    return AiInvestmentRecord(
      id: (map['id'] ?? '').toString(),
      companyName: (map['company_name'] ?? '').toString(),
      quarter: (map['quarter'] ?? 'unspecified').toString(),
      roundStage: (map['round_stage'] ?? '未分類').toString(),
      amountDisplay: (map['amount_display'] ?? '金額未記載（要確認）').toString(),
      amountUsdMillions: amountUsdMillions,
      currency: (map['currency'] ?? 'USD').toString(),
      announcedAt: (map['announced_at'] ?? '').toString(),
      sourceName: (map['source_name'] ?? '').toString(),
      sourceUrl: (map['source_url'] ?? '').toString(),
      investors: investors,
      summary: (map['summary'] ?? '').toString(),
      targetProviderCategory:
          (map['target_provider_category'] ?? 'LLM / AIインフラ').toString(),
      rawFormat: (map['raw_format'] ?? 'normalized_fallback').toString(),
      dedupKey: (map['dedup_key'] ?? '').toString(),
      verificationStatus: status,
      verificationLabel:
          (map['verification_label'] ?? status.labelJa).toString(),
      requiresManualVerification: map['requires_manual_verification'] is bool
          ? map['requires_manual_verification']! as bool
          : status == InvestmentVerificationStatus.needsVerification,
      verifiedAt: map['verified_at']?.toString(),
      verifiedBy: map['verified_by']?.toString(),
      verificationNote: (map['verification_note'] ?? '').toString(),
      isSampleTemplate: map['is_sample_template'] == true,
      ingestedAt: (map['ingested_at'] ?? '').toString(),
    );
  }

  final String id;
  final String companyName;
  final String quarter;
  final String roundStage;
  final String amountDisplay;
  final double? amountUsdMillions;
  final String currency;
  final String announcedAt;
  final String sourceName;
  final String sourceUrl;
  final List<String> investors;
  final String summary;
  final String targetProviderCategory;
  final String rawFormat;
  final String dedupKey;
  final InvestmentVerificationStatus verificationStatus;
  final String verificationLabel;
  final bool requiresManualVerification;
  final String? verifiedAt;
  final String? verifiedBy;
  final String verificationNote;
  final bool isSampleTemplate;
  final String ingestedAt;

  AiInvestmentRecord copyWith({
    final InvestmentVerificationStatus? verificationStatus,
    final String? verificationLabel,
    final bool? requiresManualVerification,
    final String? verificationNote,
    final String? verifiedAt,
    final String? verifiedBy,
    final String? sourceUrl,
  }) {
    return AiInvestmentRecord(
      id: id,
      companyName: companyName,
      quarter: quarter,
      roundStage: roundStage,
      amountDisplay: amountDisplay,
      amountUsdMillions: amountUsdMillions,
      currency: currency,
      announcedAt: announcedAt,
      sourceName: sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      investors: investors,
      summary: summary,
      targetProviderCategory: targetProviderCategory,
      rawFormat: rawFormat,
      dedupKey: dedupKey,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationLabel: verificationLabel ?? this.verificationLabel,
      requiresManualVerification:
          requiresManualVerification ?? this.requiresManualVerification,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verificationNote: verificationNote ?? this.verificationNote,
      isSampleTemplate: isSampleTemplate,
      ingestedAt: ingestedAt,
    );
  }
}

/// Aggregate KPI metrics returned alongside AI investment records.
class AiInvestmentSummary {
  const AiInvestmentSummary({
    required this.total,
    required this.needsVerification,
    required this.verified,
    required this.rejected,
    required this.quarters,
  });

  const AiInvestmentSummary.empty()
      : total = 0,
        needsVerification = 0,
        verified = 0,
        rejected = 0,
        quarters = const <String>[];

  factory AiInvestmentSummary.fromMap(final Map<Object?, Object?> raw) {
    final map = normalizeAiInvestmentMap(raw);
    final rawQuarters = map['quarters'];
    final quarters = <String>[];
    if (rawQuarters is List<Object?>) {
      for (final q in rawQuarters) {
        final text = (q ?? '').toString().trim();
        if (text.isNotEmpty) {
          quarters.add(text);
        }
      }
    }
    return AiInvestmentSummary(
      total: (map['total'] as num?)?.toInt() ?? 0,
      needsVerification: (map['needs_verification'] as num?)?.toInt() ?? 0,
      verified: (map['verified'] as num?)?.toInt() ?? 0,
      rejected: (map['rejected'] as num?)?.toInt() ?? 0,
      quarters: quarters,
    );
  }

  final int total;
  final int needsVerification;
  final int verified;
  final int rejected;
  final List<String> quarters;
}

/// Combined list + summary response.
class AiInvestmentFeedResult {
  const AiInvestmentFeedResult({
    required this.records,
    required this.summary,
  });

  factory AiInvestmentFeedResult.fromPayload(final Map<Object?, Object?> raw) {
    final map = normalizeAiInvestmentMap(raw);
    final rawList = map['records'];
    final records = <AiInvestmentRecord>[];
    if (rawList is List<Object?>) {
      for (final entry in rawList) {
        if (entry is Map<Object?, Object?>) {
          records.add(AiInvestmentRecord.fromMap(entry));
        }
      }
    }
    final summaryMap = map['summary'];
    final summary = summaryMap is Map<Object?, Object?>
        ? AiInvestmentSummary.fromMap(summaryMap)
        : const AiInvestmentSummary.empty();
    return AiInvestmentFeedResult(
      records: records,
      summary: summary,
    );
  }

  final List<AiInvestmentRecord> records;
  final AiInvestmentSummary summary;
}

/// Result of `ai_investment.ingest`.
class AiInvestmentIngestResult {
  const AiInvestmentIngestResult({
    required this.ingestedCount,
    required this.skippedDuplicates,
    required this.rejectedCount,
    required this.records,
    required this.summary,
  });

  factory AiInvestmentIngestResult.fromPayload(
    final Map<Object?, Object?> raw,
  ) {
    final map = normalizeAiInvestmentMap(raw);
    final feed = AiInvestmentFeedResult.fromPayload(map);
    return AiInvestmentIngestResult(
      ingestedCount: (map['ingested_count'] as num?)?.toInt() ?? 0,
      skippedDuplicates: (map['skipped_duplicates'] as num?)?.toInt() ?? 0,
      rejectedCount: (map['rejected_count'] as num?)?.toInt() ?? 0,
      records: feed.records,
      summary: feed.summary,
    );
  }

  final int ingestedCount;
  final int skippedDuplicates;
  final int rejectedCount;
  final List<AiInvestmentRecord> records;
  final AiInvestmentSummary summary;
}

/// Repository abstraction for `app-hub` `ai_investment.*` endpoints (#2761).
abstract class AiInvestmentRepository {
  Future<AiInvestmentFeedResult> listRecords({
    final String? quarter,
    final String? verificationStatus,
    final String? query,
  });

  Future<AiInvestmentFeedResult> seedDefaults();

  Future<AiInvestmentIngestResult> ingestPayload({
    required final String rawPayload,
    final String? sourceName,
  });

  Future<AiInvestmentFeedResult> verifyEntry({
    required final String id,
    required final InvestmentVerificationStatus decision,
    required final String verificationNote,
    final String? sourceUrl,
  });
}
