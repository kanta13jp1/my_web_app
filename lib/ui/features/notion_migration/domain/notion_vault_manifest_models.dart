class NotionVaultManifestEntry {
  const NotionVaultManifestEntry({
    required this.relativePath,
    required this.category,
    required this.migrationAction,
    required this.sizeBytes,
    required this.sourceHash,
    required this.structureMetadata,
  });

  final String relativePath;
  final String category;
  final String migrationAction;
  final int sizeBytes;
  final String sourceHash;
  final Map<String, dynamic> structureMetadata;

  bool get requiresReview => migrationAction == 'review_required';
}

class NotionVaultManifestPreview {
  const NotionVaultManifestPreview({
    required this.sourceFileName,
    required this.sourceManifestSha256,
    required this.vaultName,
    required this.schemaVersion,
    required this.fileCount,
    required this.autoStageCount,
    required this.reviewRequiredCount,
    required this.excludedCount,
    required this.credentialCandidateCount,
    required this.unresolvedWikilinkOccurrences,
    required this.entries,
  });

  final String sourceFileName;
  final String sourceManifestSha256;
  final String vaultName;
  final int schemaVersion;
  final int fileCount;
  final int autoStageCount;
  final int reviewRequiredCount;
  final int excludedCount;
  final int credentialCandidateCount;
  final int unresolvedWikilinkOccurrences;
  final List<NotionVaultManifestEntry> entries;

  int get stageableCount => autoStageCount + reviewRequiredCount;
  bool get hasSafetyWarnings =>
      reviewRequiredCount > 0 ||
      credentialCandidateCount > 0 ||
      unresolvedWikilinkOccurrences > 0;
}

class NotionVaultManifestStageSummary {
  const NotionVaultManifestStageSummary({
    required this.id,
    required this.vaultName,
    required this.sourceManifestSha256,
    required this.fileCount,
    required this.stagedEntryCount,
    required this.reviewRequiredCount,
    required this.excludedCount,
    required this.credentialCandidateCount,
    required this.unresolvedWikilinkOccurrences,
    required this.status,
    this.stagedAt,
  });

  factory NotionVaultManifestStageSummary.fromJson(Map<String, dynamic> json) {
    int count(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return NotionVaultManifestStageSummary(
      id: json['id']?.toString() ?? '',
      vaultName: json['vault_name']?.toString() ?? '',
      sourceManifestSha256: json['source_manifest_sha256']?.toString() ?? '',
      fileCount: count('file_count'),
      stagedEntryCount: count('staged_entry_count'),
      reviewRequiredCount: count('review_required_count'),
      excludedCount: count('excluded_count'),
      credentialCandidateCount: count('credential_candidate_count'),
      unresolvedWikilinkOccurrences: count('unresolved_wikilink_occurrences'),
      status: json['status']?.toString() ?? 'staging',
      stagedAt: DateTime.tryParse(json['staged_at']?.toString() ?? ''),
    );
  }

  final String id;
  final String vaultName;
  final String sourceManifestSha256;
  final int fileCount;
  final int stagedEntryCount;
  final int reviewRequiredCount;
  final int excludedCount;
  final int credentialCandidateCount;
  final int unresolvedWikilinkOccurrences;
  final String status;
  final DateTime? stagedAt;
}
