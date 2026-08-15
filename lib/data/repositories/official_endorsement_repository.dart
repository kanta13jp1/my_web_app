import '../../models/election_intelligence.dart';
import '../dpj_official_endorsements.dart';

/// Provides one resolved official-endorsement snapshot to every consumer.
///
/// Any non-empty Edge Function snapshot is preferred, including an early
/// summary that arrives before prefecture rows. The generated official-PDF
/// snapshot is the deterministic offline fallback.
class OfficialEndorsementRepository {
  const OfficialEndorsementRepository();

  OfficialEndorsementSnapshot resolve(
    ElectionIntelligenceSnapshot? intelligence,
  ) {
    final live = intelligence?.officialEndorsements;
    if (live != null && live.hasData) {
      return live;
    }
    return fallbackSnapshot;
  }

  OfficialEndorsementSnapshot get fallbackSnapshot =>
      const OfficialEndorsementSnapshot(
        sourceUrl: dpjOfficialEndorsementSourceUrl,
        sourceAsOf: dpjOfficialEndorsementSourceAsOf,
        sourceDocumentSha256: dpjOfficialEndorsementSourceDocumentSha256,
        totalCount: dpjOfficialEndorsementTotal,
        incumbentCount: dpjOfficialEndorsementIncumbentTotal,
        newcomerCount: dpjOfficialEndorsementNewcomerTotal,
        formerCount: dpjOfficialEndorsementFormerTotal,
        recommendationCount: dpjOfficialRecommendationEntryCount,
        prefectureCount: dpjOfficialEndorsementPrefectureCount,
        prefectures: dpjOfficialEndorsements,
      );
}
