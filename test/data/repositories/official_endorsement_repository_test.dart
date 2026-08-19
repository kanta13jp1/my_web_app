import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/dpj_official_endorsements.dart';
import 'package:my_web_app/data/repositories/official_endorsement_repository.dart';
import 'package:my_web_app/models/election_intelligence.dart';

void main() {
  const repository = OfficialEndorsementRepository();

  test('generated official snapshot is the deterministic offline fallback', () {
    final snapshot = repository.resolve(null);

    expect(snapshot.sourceAsOf, dpjOfficialEndorsementSourceAsOf);
    expect(snapshot.totalCount, dpjOfficialEndorsementTotal);
    expect(snapshot.prefectureCount, dpjOfficialEndorsementPrefectureCount);
    expect(snapshot.forPrefecture('佐賀県')?.newcomerCount, 1);
  });

  test('complete live snapshot takes priority over the generated fallback', () {
    final resolved = repository.resolve(
      _intelligenceWith(_liveSnapshot),
    );

    expect(resolved.sourceAsOf, '2026-08-11');
    expect(resolved.totalCount, 1);
    expect(resolved.prefectures.single.prefecture, '東京');
  });

  test('non-empty live summary takes priority before prefecture rows arrive',
      () {
    const incomplete = OfficialEndorsementSnapshot(
      sourceUrl: 'https://example.com/incomplete',
      sourceAsOf: '2026-08-11',
      sourceDocumentSha256: 'incomplete',
      totalCount: 1,
      incumbentCount: 1,
      newcomerCount: 0,
      formerCount: 0,
      recommendationCount: 0,
      prefectureCount: 1,
    );

    final resolved = repository.resolve(_intelligenceWith(incomplete));

    expect(resolved.sourceAsOf, '2026-08-11');
    expect(resolved.totalCount, 1);
    expect(resolved.prefectures, isEmpty);
  });
}

const _liveSnapshot = OfficialEndorsementSnapshot(
  sourceUrl: 'https://example.com/live',
  sourceAsOf: '2026-08-11',
  sourceDocumentSha256: 'live-sha',
  totalCount: 1,
  incumbentCount: 1,
  newcomerCount: 0,
  formerCount: 0,
  recommendationCount: 0,
  prefectureCount: 1,
  prefectures: <OfficialEndorsementPrefecture>[
    OfficialEndorsementPrefecture(
      prefecture: '東京',
      totalCount: 1,
      incumbentCount: 1,
      newcomerCount: 0,
      formerCount: 0,
    ),
  ],
);

ElectionIntelligenceSnapshot _intelligenceWith(
  OfficialEndorsementSnapshot endorsements,
) {
  return ElectionIntelligenceSnapshot(
    schemaVersion: 1,
    selectedMode: ElectionModeId.local,
    modes: const <ElectionModeOption>[],
    goals: const <ElectionGoalProgress>[],
    achievements: const <ElectionAchievement>[],
    officialEndorsements: endorsements,
  );
}
