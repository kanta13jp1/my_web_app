enum CompetitorClaimType {
  summary('summary'),
  pricing('pricing'),
  feature('feature'),
  japanPresence('japan_presence'),
  other('other');

  const CompetitorClaimType(this.databaseValue);

  final String databaseValue;

  static CompetitorClaimType? tryParse(Object? value) {
    final normalized = value?.toString().trim();
    for (final type in values) {
      if (type.databaseValue == normalized) {
        return type;
      }
    }
    return null;
  }
}

class CompetitorClaimEvidence {
  const CompetitorClaimEvidence({
    required this.competitorId,
    required this.claimKey,
    required this.claimType,
    required this.claimText,
    required this.sourceUri,
    required this.verifiedAt,
  });

  final String competitorId;
  final String claimKey;
  final CompetitorClaimType claimType;
  final String claimText;
  final Uri sourceUri;
  final DateTime verifiedAt;

  static CompetitorClaimEvidence? tryFromJson(Map<String, dynamic> json) {
    final competitorId = json['competitor_id']?.toString().trim() ?? '';
    final claimKey = json['claim_key']?.toString().trim() ?? '';
    final claimType = CompetitorClaimType.tryParse(json['claim_type']);
    final claimText = json['claim_text']?.toString().trim() ?? '';
    final sourceUri = Uri.tryParse(json['source_url']?.toString().trim() ?? '');
    final verifiedAt = DateTime.tryParse(
      json['verified_at']?.toString().trim() ?? '',
    );
    final validSource = sourceUri != null &&
        (sourceUri.scheme == 'https' || sourceUri.scheme == 'http') &&
        sourceUri.host.isNotEmpty;

    if (competitorId.isEmpty ||
        claimKey.isEmpty ||
        claimType == null ||
        claimText.isEmpty ||
        !validSource ||
        verifiedAt == null) {
      return null;
    }

    return CompetitorClaimEvidence(
      competitorId: competitorId,
      claimKey: claimKey,
      claimType: claimType,
      claimText: claimText,
      sourceUri: sourceUri,
      verifiedAt: verifiedAt.toUtc(),
    );
  }
}
