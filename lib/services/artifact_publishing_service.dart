import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/artifact_publishing.dart';
import 'supabase_client_provider.dart';

abstract interface class ArtifactPublishingGateway {
  Future<bool> isCurrentUserAdmin();

  Future<List<ArtifactCandidate>> fetchCandidates();

  Future<void> transitionStage({
    required String candidateId,
    required ArtifactStage expectedStage,
    required ArtifactStage targetStage,
    String? rejectionReason,
    String? humanContributionSummary,
    String? productId,
    int? intendedPriceJpy,
    String? proposedStoragePath,
  });

  Future<void> reviewCheck({
    required String candidateId,
    required String checkKey,
    required ArtifactCheckStatus status,
    String? evidenceSummary,
  });
}

class ArtifactPublishingService implements ArtifactPublishingGateway {
  ArtifactPublishingService({SupabaseClient? client})
      : _client = client ?? supabase;

  final SupabaseClient _client;

  static const _candidateColumns =
      'id, title, artifact_sha256, mime_type, file_size_bytes, artifact_kind, '
      'stage, product_id, intended_price_jpy, proposed_storage_bucket, '
      'proposed_storage_path, human_contribution_summary, rejection_reason, '
      'updated_at, artifact_checks(check_key, check_kind, is_hard_gate, status, '
      'evidence_summary), artifact_provenance(source_tool), '
      'shop_products(id, name_ja, is_active)';

  @override
  Future<bool> isCurrentUserAdmin() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final profile = await _client
        .from('user_profiles')
        .select('is_admin')
        .eq('user_id', userId)
        .maybeSingle();
    return profile?['is_admin'] == true;
  }

  @override
  Future<List<ArtifactCandidate>> fetchCandidates() async {
    final rows = await _client
        .from('artifact_candidates')
        .select(_candidateColumns)
        .order('updated_at', ascending: false)
        .limit(100);
    return (rows as List<dynamic>)
        .map(
          (raw) =>
              ArtifactCandidate.fromRow(Map<String, dynamic>.from(raw as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<void> transitionStage({
    required String candidateId,
    required ArtifactStage expectedStage,
    required ArtifactStage targetStage,
    String? rejectionReason,
    String? humanContributionSummary,
    String? productId,
    int? intendedPriceJpy,
    String? proposedStoragePath,
  }) async {
    final result = await _client
        .from('artifact_candidates')
        .update({
          'stage': targetStage.databaseValue,
          if (targetStage == ArtifactStage.rejected)
            'rejection_reason': rejectionReason,
          if (targetStage == ArtifactStage.approved)
            'human_contribution_summary': humanContributionSummary?.trim(),
          if (targetStage == ArtifactStage.staged) ...{
            'product_id': productId?.trim(),
            'intended_price_jpy': intendedPriceJpy,
            'proposed_storage_bucket': 'product-downloads',
            'proposed_storage_path': proposedStoragePath?.trim(),
          },
        })
        .eq('id', candidateId)
        .eq('stage', expectedStage.databaseValue)
        .select('id')
        .maybeSingle();
    if (result == null) {
      throw const ArtifactPublishingException('候補が別の操作で更新されました。再読み込みしてください。');
    }
  }

  @override
  Future<void> reviewCheck({
    required String candidateId,
    required String checkKey,
    required ArtifactCheckStatus status,
    String? evidenceSummary,
  }) async {
    final result = await _client
        .from('artifact_checks')
        .update({
          'status': status.databaseValue,
          'evidence_summary': status == ArtifactCheckStatus.pending
              ? null
              : evidenceSummary?.trim(),
        })
        .eq('candidate_id', candidateId)
        .eq('check_key', checkKey)
        .select('id')
        .maybeSingle();
    if (result == null) {
      throw const ArtifactPublishingException('検査結果が別の操作で更新されました。再読み込みしてください。');
    }
  }
}

class ArtifactPublishingException implements Exception {
  const ArtifactPublishingException(this.message);

  final String message;

  @override
  String toString() => message;
}
