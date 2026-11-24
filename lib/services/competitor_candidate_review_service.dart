import 'package:supabase_flutter/supabase_flutter.dart';

enum CandidateReviewDecision {
  pending('pending', '確認待ち'),
  approved('approved', '承認済み'),
  rejected('rejected', '却下済み');

  const CandidateReviewDecision(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CandidateReviewDecision parse(Object? raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'approved':
        return CandidateReviewDecision.approved;
      case 'rejected':
        return CandidateReviewDecision.rejected;
      case 'pending':
      default:
        return CandidateReviewDecision.pending;
    }
  }
}

class CompetitorCandidateReviewItem {
  const CompetitorCandidateReviewItem({
    required this.id,
    required this.displayName,
    required this.needsManualReview,
    required this.reviewDecision,
    required this.reviewed,
    this.category,
    this.website,
    this.sourceUrlStatusCode,
    this.sourceUrlError,
    this.rejectedReason,
    this.sourceUrlCheckedAt,
  });

  final String id;
  final String displayName;
  final String? category;
  final String? website;
  final int? sourceUrlStatusCode;
  final String? sourceUrlError;
  final bool needsManualReview;
  final CandidateReviewDecision reviewDecision;
  final bool reviewed;
  final String? rejectedReason;
  final DateTime? sourceUrlCheckedAt;

  factory CompetitorCandidateReviewItem.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['source_url_status_code'];
    final statusCode = statusRaw is num
        ? statusRaw.toInt()
        : int.tryParse(statusRaw?.toString() ?? '');
    final checkedRaw = json['source_url_checked_at']?.toString().trim();
    return CompetitorCandidateReviewItem(
      id: (json['id']?.toString() ?? '').trim(),
      displayName: (json['display_name']?.toString() ?? '').trim(),
      category: json['category']?.toString(),
      website: json['website']?.toString(),
      sourceUrlStatusCode: statusCode,
      sourceUrlError: json['source_url_error']?.toString(),
      needsManualReview: json['needs_manual_review'] == true,
      reviewDecision: CandidateReviewDecision.parse(json['review_decision']),
      reviewed: json['reviewed'] == true,
      rejectedReason: json['rejected_reason']?.toString(),
      sourceUrlCheckedAt: checkedRaw != null && checkedRaw.isNotEmpty
          ? DateTime.tryParse(checkedRaw)?.toUtc()
          : null,
    );
  }
}

abstract class CompetitorCandidateReviewRepository {
  Future<List<CompetitorCandidateReviewItem>> listCandidates({
    bool onlyManualReview = false,
    int limit = 50,
  });

  Future<CompetitorCandidateReviewItem> verifyCandidateUrl(String candidateId);

  Future<CompetitorCandidateReviewItem> submitReviewDecision({
    required String candidateId,
    required CandidateReviewDecision decision,
    String? rejectedReason,
  });
}

class SupabaseCompetitorCandidateReviewRepository
    implements CompetitorCandidateReviewRepository {
  SupabaseCompetitorCandidateReviewRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  @override
  Future<List<CompetitorCandidateReviewItem>> listCandidates({
    bool onlyManualReview = false,
    int limit = 50,
  }) async {
    final res = await _client.functions.invoke(
      'admin-hub',
      body: <String, dynamic>{
        'action': 'competitor_candidate.list',
        'only_manual_review': onlyManualReview,
        'limit': limit,
      },
    );
    final map = _asMap(res.data);
    final rows = map['candidates'];
    if (rows is! List) return const <CompetitorCandidateReviewItem>[];
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (r) => CompetitorCandidateReviewItem.fromJson(
            Map<String, dynamic>.from(r),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<CompetitorCandidateReviewItem> verifyCandidateUrl(
    String candidateId,
  ) async {
    final res = await _client.functions.invoke(
      'admin-hub',
      body: <String, dynamic>{
        'action': 'competitor_candidate.verify_url',
        'candidate_id': candidateId,
      },
    );
    final map = _asMap(res.data);
    final candidate = map['candidate'];
    if (candidate is Map) {
      return CompetitorCandidateReviewItem.fromJson(
        Map<String, dynamic>.from(candidate),
      );
    }
    throw StateError('URL 検証レスポンスを取得できませんでした');
  }

  @override
  Future<CompetitorCandidateReviewItem> submitReviewDecision({
    required String candidateId,
    required CandidateReviewDecision decision,
    String? rejectedReason,
  }) async {
    final res = await _client.functions.invoke(
      'admin-hub',
      body: <String, dynamic>{
        'action': 'competitor_candidate.review',
        'candidate_id': candidateId,
        'decision': decision.wireValue,
        if (rejectedReason != null && rejectedReason.trim().isNotEmpty)
          'rejected_reason': rejectedReason.trim(),
      },
    );
    final map = _asMap(res.data);
    final candidate = map['candidate'];
    if (candidate is Map) {
      return CompetitorCandidateReviewItem.fromJson(
        Map<String, dynamic>.from(candidate),
      );
    }
    throw StateError('レビュー保存結果を取得できませんでした');
  }
}
