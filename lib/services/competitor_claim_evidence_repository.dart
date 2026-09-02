import 'package:my_web_app/models/competitor_claim_evidence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CompetitorClaimEvidenceRepository {
  Future<List<CompetitorClaimEvidence>> fetchForCompetitor(String competitorId);
}

class SupabaseCompetitorClaimEvidenceRepository
    implements CompetitorClaimEvidenceRepository {
  SupabaseCompetitorClaimEvidenceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CompetitorClaimEvidence>> fetchForCompetitor(
    String competitorId,
  ) async {
    final normalizedId = competitorId.trim().toLowerCase();
    if (normalizedId.isEmpty) {
      return const <CompetitorClaimEvidence>[];
    }

    final rows = await _client
        .from('competitor_claim_evidence')
        .select(
          'competitor_id,claim_key,claim_type,claim_text,source_url,verified_at',
        )
        .eq('competitor_id', normalizedId)
        .order('claim_type')
        .order('claim_key');

    final evidence = <CompetitorClaimEvidence>[];
    for (final row in rows) {
      final parsed = CompetitorClaimEvidence.tryFromJson(
        Map<String, dynamic>.from(row),
      );
      if (parsed != null && parsed.competitorId == normalizedId) {
        evidence.add(parsed);
      }
    }
    return List<CompetitorClaimEvidence>.unmodifiable(evidence);
  }
}
