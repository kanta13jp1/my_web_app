import '../../models/election_intelligence.dart';
import '../dpj_official_endorsements.dart';

/// Provides one resolved official-endorsement snapshot to every consumer.
///
/// Compare official source dates before using an Edge Function snapshot.
/// Fetch time does not make an older PDF newer than the bundled PDF.
class OfficialEndorsementRepository {
  const OfficialEndorsementRepository();

  OfficialEndorsementSnapshot resolve(
    ElectionIntelligenceSnapshot? intelligence,
  ) {
    final live = intelligence?.officialEndorsements;
    if (live != null && live.hasData) {
      final liveDate = _sourceDate(live.sourceAsOf);
      final bundledDate = _sourceDate(fallbackSnapshot.sourceAsOf);
      if (liveDate != null &&
          (bundledDate == null || !liveDate.isBefore(bundledDate))) {
        return live;
      }
    }
    return fallbackSnapshot;
  }

  DateTime? _sourceDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.utc(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day
        ? parsed
        : null;
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
