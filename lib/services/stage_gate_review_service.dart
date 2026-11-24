import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum StageGateStage {
  intake('intake', 'インテーク'),
  design('design', '設計審査'),
  implementation('implementation', '実装'),
  verification('verification', '検証ゲート'),
  release('release', 'リリース判定');

  const StageGateStage(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static StageGateStage parse(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase() ?? '';
    for (final stage in values) {
      if (stage.wireValue == normalized) return stage;
    }
    return StageGateStage.intake;
  }

  StageGateStage? get nextStage {
    final idx = index;
    if (idx + 1 >= values.length) return null;
    return values[idx + 1];
  }
}

enum StageGateDecision {
  pending('pending', '審査待ち'),
  approved('approved', '承認'),
  changesRequested('changes_requested', '差し戻し'),
  rejected('rejected', '却下');

  const StageGateDecision(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static StageGateDecision parse(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase() ?? '';
    for (final decision in values) {
      if (decision.wireValue == normalized) return decision;
    }
    return StageGateDecision.pending;
  }
}

@immutable
class StageGateReview {
  const StageGateReview({
    required this.id,
    required this.sourceType,
    required this.sourceRef,
    required this.title,
    required this.currentStage,
    required this.targetStage,
    required this.status,
    required this.feedback,
    this.submittedBy = '',
    this.decidedBy,
    this.createdAt,
  });

  final String id;
  final String sourceType;
  final String sourceRef;
  final String title;
  final StageGateStage currentStage;
  final StageGateStage targetStage;
  final StageGateDecision status;
  final String feedback;
  final String submittedBy;
  final String? decidedBy;
  final DateTime? createdAt;

  factory StageGateReview.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at']?.toString().trim();
    return StageGateReview(
      id: json['id']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? 'wbs_task',
      sourceRef: json['source_ref']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      currentStage: StageGateStage.parse(json['current_stage']),
      targetStage: StageGateStage.parse(json['target_stage']),
      status: StageGateDecision.parse(json['status']),
      feedback: json['feedback']?.toString() ?? '',
      submittedBy: json['submitted_by']?.toString() ?? '',
      decidedBy: json['decided_by']?.toString(),
      createdAt: createdRaw == null || createdRaw.isEmpty
          ? null
          : DateTime.tryParse(createdRaw),
    );
  }
}

@immutable
class StageGateHistoryEntry {
  const StageGateHistoryEntry({
    required this.id,
    required this.reviewId,
    required this.fromStage,
    required this.toStage,
    required this.decision,
    required this.feedback,
    this.createdAt,
  });

  final String id;
  final String reviewId;
  final StageGateStage fromStage;
  final StageGateStage toStage;
  final String decision;
  final String feedback;
  final DateTime? createdAt;

  factory StageGateHistoryEntry.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at']?.toString().trim();
    return StageGateHistoryEntry(
      id: json['id']?.toString() ?? '',
      reviewId: json['review_id']?.toString() ?? '',
      fromStage: StageGateStage.parse(json['from_stage']),
      toStage: StageGateStage.parse(json['to_stage']),
      decision: json['decision']?.toString() ?? 'submitted',
      feedback: json['feedback']?.toString() ?? '',
      createdAt: createdRaw == null || createdRaw.isEmpty
          ? null
          : DateTime.tryParse(createdRaw),
    );
  }
}

@immutable
class StageGateOverview {
  const StageGateOverview({
    required this.isAdmin,
    required this.reviews,
    required this.history,
  });

  final bool isAdmin;
  final List<StageGateReview> reviews;
  final List<StageGateHistoryEntry> history;
}

abstract class StageGateReviewRepository {
  Future<StageGateOverview> listReviews({
    StageGateDecision? statusFilter,
    int limit = 30,
  });

  Future<StageGateReview> submitTransition({
    required String sourceType,
    required String sourceRef,
    required String title,
    required StageGateStage currentStage,
    required StageGateStage targetStage,
    String feedback = '',
  });

  Future<StageGateReview> decideReview({
    required String reviewId,
    required StageGateDecision decision,
    required String feedback,
  });
}

typedef StageGateClientResolver = SupabaseClient Function();

class SupabaseStageGateReviewRepository implements StageGateReviewRepository {
  SupabaseStageGateReviewRepository({StageGateClientResolver? clientResolver})
      : _clientResolver = clientResolver ?? _defaultClientResolver;

  final StageGateClientResolver _clientResolver;

  static SupabaseClient _defaultClientResolver() => Supabase.instance.client;

  static Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  @override
  Future<StageGateOverview> listReviews({
    StageGateDecision? statusFilter,
    int limit = 30,
  }) async {
    final res = await _clientResolver().functions.invoke(
      'core-hub',
      body: <String, dynamic>{
        'action': 'stage_gate.list',
        if (statusFilter != null) 'status': statusFilter.wireValue,
        'limit': limit,
      },
    );
    final map = _asMap(res.data);
    final rawReviews = map['reviews'];
    final rawHistory = map['history'];
    final reviews = rawReviews is List
        ? rawReviews
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (item) => StageGateReview.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : const <StageGateReview>[];
    final history = rawHistory is List
        ? rawHistory
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (item) => StageGateHistoryEntry.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : const <StageGateHistoryEntry>[];
    return StageGateOverview(
      isAdmin: map['is_admin'] == true,
      reviews: reviews,
      history: history,
    );
  }

  @override
  Future<StageGateReview> submitTransition({
    required String sourceType,
    required String sourceRef,
    required String title,
    required StageGateStage currentStage,
    required StageGateStage targetStage,
    String feedback = '',
  }) async {
    final res = await _clientResolver().functions.invoke(
      'core-hub',
      body: <String, dynamic>{
        'action': 'stage_gate.submit',
        'source_type': sourceType,
        'source_ref': sourceRef.trim(),
        'title': title.trim(),
        'current_stage': currentStage.wireValue,
        'target_stage': targetStage.wireValue,
        'feedback': feedback.trim(),
      },
    );
    final map = _asMap(res.data);
    final rawReview = map['review'];
    if (rawReview is Map) {
      return StageGateReview.fromJson(Map<String, dynamic>.from(rawReview));
    }
    throw StateError('ステージゲート申請レスポンスが不正です');
  }

  @override
  Future<StageGateReview> decideReview({
    required String reviewId,
    required StageGateDecision decision,
    required String feedback,
  }) async {
    final res = await _clientResolver().functions.invoke(
      'core-hub',
      body: <String, dynamic>{
        'action': 'stage_gate.decide',
        'review_id': reviewId,
        'decision': decision.wireValue,
        'feedback': feedback.trim(),
      },
    );
    final map = _asMap(res.data);
    final rawReview = map['review'];
    if (rawReview is Map) {
      return StageGateReview.fromJson(Map<String, dynamic>.from(rawReview));
    }
    throw StateError('ステージゲート判定レスポンスが不正です');
  }
}
