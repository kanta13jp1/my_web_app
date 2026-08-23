import 'dart:convert';

class TigerReviewerProfileCatalog {
  const TigerReviewerProfileCatalog({
    required this.schemaVersion,
    required this.snapshotDate,
    required this.profilesBySeat,
    required this.disclaimer,
  });

  final int schemaVersion;
  final DateTime? snapshotDate;
  final Map<int, TigerReviewerProfile> profilesBySeat;
  final String disclaimer;

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
    );
  }
}
