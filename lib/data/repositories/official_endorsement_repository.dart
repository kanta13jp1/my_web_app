import '../../models/election_intelligence.dart';
import '../dpj_official_endorsements.dart';

/// Provides one resolved official-endorsement snapshot to every consumer.
///
/// A complete Edge summary may replace the bundled PDF when its source date
/// is the same or newer. All counts, regions and provenance travel together.
class OfficialEndorsementRepository {
  const OfficialEndorsementRepository();

  OfficialEndorsementSnapshot resolve(
    ElectionIntelligenceSnapshot? intelligence,
  ) {
    final live = intelligence?.officialEndorsements;
    final fallback = fallbackSnapshot;
    if (live == null || !live.hasData) {
      return fallback;
    }
    final asOf = live.sourceAsOf;
    final date = DateTime.tryParse('${asOf}T00:00:00Z');
    if (date == null ||
        date.toIso8601String().split('T').first != asOf ||
        asOf.compareTo(fallback.sourceAsOf) < 0 ||
        !_hasCompleteBreakdown(live)) {
      return fallback;
    }
    return live;
  }

  static bool _hasCompleteBreakdown(OfficialEndorsementSnapshot snapshot) {
    if (!snapshot.sourceCountsComplete ||
        snapshot.prefectures.isEmpty ||
        snapshot.prefectures.length != snapshot.prefectureCount ||
        snapshot.sourceUrl.isEmpty ||
        snapshot.sourceDocumentSha256.isEmpty ||
        snapshot.recommendationCount < 0) {
      return false;
    }
    final names = <String>{};
    var incumbents = 0;
    var newcomers = 0;
    var former = 0;
    var prefectural = 0;
    var municipal = 0;
    for (final row in snapshot.prefectures) {
      if (row.prefecture.isEmpty ||
          !names.add(row.prefecture) ||
          row.totalCount <= 0 ||
          row.incumbentCount < 0 ||
          row.newcomerCount < 0 ||
          row.formerCount < 0 ||
          row.prefecturalCount < 0 ||
          row.municipalCount < 0 ||
          row.incumbentCount + row.newcomerCount + row.formerCount !=
              row.totalCount ||
          row.prefecturalCount + row.municipalCount != row.totalCount) {
        return false;
      }
      incumbents += row.incumbentCount;
      newcomers += row.newcomerCount;
      former += row.formerCount;
      prefectural += row.prefecturalCount;
      municipal += row.municipalCount;
    }
    return incumbents == snapshot.incumbentCount &&
        newcomers == snapshot.newcomerCount &&
        former == snapshot.formerCount &&
        prefectural == snapshot.prefecturalCount &&
        municipal == snapshot.municipalCount &&
        prefectural + municipal == snapshot.totalCount;
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
        prefecturalCount: dpjOfficialEndorsementPrefecturalTotal,
        municipalCount: dpjOfficialEndorsementMunicipalTotal,
        prefectures: dpjOfficialEndorsements,
      );
}
