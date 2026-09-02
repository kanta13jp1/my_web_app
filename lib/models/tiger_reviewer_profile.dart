import 'dart:convert';

class TigerReviewerProfileCatalog {
  const TigerReviewerProfileCatalog({
    required this.schemaVersion,
    required this.snapshotDate,
    required this.profilesBySeat,
    required this.disclaimer,
    this.enrichmentRound = 0,
    this.averageProfileCompletenessPercent = 0,
    this.averageReviewReflectionPercent = 0,
    this.verifiedBirthDates = 0,
    this.nextBatchNames = const <String>[],
  });

  final int schemaVersion;
  final DateTime? snapshotDate;
  final Map<int, TigerReviewerProfile> profilesBySeat;
  final String disclaimer;
  final int enrichmentRound;
  final double averageProfileCompletenessPercent;
  final double averageReviewReflectionPercent;
  final int verifiedBirthDates;
  final List<String> nextBatchNames;

  factory TigerReviewerProfileCatalog.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Tiger reviewer profile catalog must be an object.',
      );
    }
    return TigerReviewerProfileCatalog.fromJson(decoded);
  }

  factory TigerReviewerProfileCatalog.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'];
    final enrichment = json['enrichment'] is Map
        ? Map<String, dynamic>.from(json['enrichment'] as Map)
        : const <String, dynamic>{};
    final nextBatch = enrichment['next_batch'];
    final parsed = profiles is List
        ? profiles
            .whereType<Map>()
            .map(
              (profile) => TigerReviewerProfile.fromJson(
                Map<String, dynamic>.from(profile),
              ),
            )
            .toList(growable: false)
        : const <TigerReviewerProfile>[];
    return TigerReviewerProfileCatalog(
      schemaVersion:
          json['schema_version'] is int ? json['schema_version'] as int : 0,
      snapshotDate: DateTime.tryParse(json['snapshot_date']?.toString() ?? ''),
      profilesBySeat: <int, TigerReviewerProfile>{
        for (final profile in parsed) profile.seat: profile,
      },
      disclaimer: json['disclaimer']?.toString() ?? '',
      enrichmentRound:
          enrichment['round'] is num ? (enrichment['round'] as num).toInt() : 0,
      averageProfileCompletenessPercent:
          enrichment['average_profile_completeness_percent'] is num
              ? (enrichment['average_profile_completeness_percent'] as num)
                  .toDouble()
              : 0,
      averageReviewReflectionPercent:
          enrichment['average_review_reflection_percent'] is num
              ? (enrichment['average_review_reflection_percent'] as num)
                  .toDouble()
              : 0,
      verifiedBirthDates: enrichment['verified_birth_dates'] is num
          ? (enrichment['verified_birth_dates'] as num).toInt()
          : 0,
      nextBatchNames: nextBatch is List
          ? nextBatch
              .whereType<Map>()
              .map((item) => item['name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
    );
  }
}

class TigerReviewerProfile {
  const TigerReviewerProfile({
    required this.seat,
    required this.name,
    required this.rosterStatus,
    required this.birthDate,
    required this.companyRole,
    required this.businessSummary,
    required this.businessDomains,
    required this.appearances,
    required this.investmentCount,
    required this.publicViewpointSummary,
    required this.profileUrl,
    required this.birthDateSourceUrl,
    this.evidenceLinks = const <TigerReviewerEvidenceLink>[],
    this.evidenceConfidence = 0,
    this.profileCompletenessPercent = 0,
    this.reviewReflectionPercent = 0,
    this.reviewReflectionMode = '',
    this.reviewApplicationRule = '',
    this.reviewFocusLabels = const <String>[],
    this.reviewQuestions = const <String>[],
    this.nextResearchTargets = const <String>[],
  });

  final int seat;
  final String name;
  final String rosterStatus;
  final DateTime? birthDate;
  final String companyRole;
  final String businessSummary;
  final List<String> businessDomains;
  final int appearances;
  final int investmentCount;
  final String publicViewpointSummary;
  final Uri? profileUrl;
  final Uri? birthDateSourceUrl;
  final List<TigerReviewerEvidenceLink> evidenceLinks;
  final double evidenceConfidence;
  final int profileCompletenessPercent;
  final int reviewReflectionPercent;
  final String reviewReflectionMode;
  final String reviewApplicationRule;
  final List<String> reviewFocusLabels;
  final List<String> reviewQuestions;
  final List<String> nextResearchTargets;

  String get reviewReflectionLabel => switch (reviewReflectionMode) {
        'profile_guided' => '確認済みプロフィール観点を強く反映',
        'profile_balanced' => '中立評価とプロフィール観点を併用',
        _ => '中立評価を優先',
      };

  String ageLabel(DateTime? asOf) {
    if (birthDate == null || asOf == null) return '公開情報未確認';
    var age = asOf.year - birthDate!.year;
    final birthdayPassed = asOf.month > birthDate!.month ||
        (asOf.month == birthDate!.month && asOf.day >= birthDate!.day);
    if (!birthdayPassed) age -= 1;
    return '$age歳（${asOf.year}年${asOf.month}月${asOf.day}日時点）';
  }

  factory TigerReviewerProfile.fromJson(Map<String, dynamic> json) {
    final rawDomains = json['business_domains'];
    final rawFocus = json['review_focus_dimensions'];
    final focus = rawFocus is List
        ? rawFocus
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final rawResearchTargets = json['next_research_targets'];
    final rawEvidenceLinks = json['evidence_links'];
    return TigerReviewerProfile(
      seat: json['seat'] is num ? (json['seat'] as num).toInt() : 0,
      name: json['name']?.toString() ?? '',
      rosterStatus: json['roster_status']?.toString() ?? '',
      birthDate: DateTime.tryParse(json['birth_date']?.toString() ?? ''),
      companyRole: json['company_role']?.toString() ?? '',
      businessSummary: json['business_summary']?.toString() ?? '',
      businessDomains: rawDomains is List
          ? rawDomains.map((value) => value.toString()).toList(growable: false)
          : const <String>[],
      appearances:
          json['appearances'] is num ? (json['appearances'] as num).toInt() : 0,
      investmentCount: json['investment_count'] is num
          ? (json['investment_count'] as num).toInt()
          : 0,
      publicViewpointSummary:
          json['public_viewpoint_summary']?.toString() ?? '',
      profileUrl: Uri.tryParse(json['profile_url']?.toString() ?? ''),
      birthDateSourceUrl: Uri.tryParse(
        json['birth_date_source_url']?.toString() ?? '',
      ),
      evidenceLinks: rawEvidenceLinks is List
          ? rawEvidenceLinks
              .whereType<Map>()
              .map(
                (item) => TigerReviewerEvidenceLink.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((link) => link.label.isNotEmpty && link.url.hasScheme)
              .toList(growable: false)
          : const <TigerReviewerEvidenceLink>[],
      evidenceConfidence: json['evidence_confidence'] is num
          ? (json['evidence_confidence'] as num).toDouble()
          : 0,
      profileCompletenessPercent: json['profile_completeness_percent'] is num
          ? (json['profile_completeness_percent'] as num).toInt()
          : 0,
      reviewReflectionPercent: json['review_reflection_percent'] is num
          ? (json['review_reflection_percent'] as num).toInt()
          : 0,
      reviewReflectionMode: json['review_reflection_mode']?.toString() ?? '',
      reviewApplicationRule: json['review_application_rule']?.toString() ?? '',
      reviewFocusLabels: focus
          .map((item) => item['label']?.toString() ?? '')
          .where((label) => label.isNotEmpty)
          .toList(growable: false),
      reviewQuestions: focus
          .map((item) => item['question']?.toString() ?? '')
          .where((question) => question.isNotEmpty)
          .toList(growable: false),
      nextResearchTargets: rawResearchTargets is List
          ? rawResearchTargets
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
    );
  }
}

class TigerReviewerEvidenceLink {
  const TigerReviewerEvidenceLink({required this.label, required this.url});

  final String label;
  final Uri url;

  factory TigerReviewerEvidenceLink.fromJson(Map<String, dynamic> json) {
    return TigerReviewerEvidenceLink(
      label: json['label']?.toString().trim() ?? '',
      url: Uri.tryParse(json['url']?.toString() ?? '') ?? Uri(),
    );
  }
}
