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

  test('complete live snapshot with the same source date takes priority', () {
    final resolved = repository.resolve(
      _intelligenceWith(_liveSnapshot),
    );

    expect(resolved.sourceAsOf, dpjOfficialEndorsementSourceAsOf);
    expect(resolved.totalCount, 1);
    expect(resolved.prefectures.single.prefecture, '東京');
  });

  test(
      'retains the complete bundled snapshot until live prefecture rows arrive',
      () {
    const incomplete = OfficialEndorsementSnapshot(
      sourceUrl: 'https://example.com/incomplete',
      sourceAsOf: dpjOfficialEndorsementSourceAsOf,
      sourceDocumentSha256: 'incomplete',
      totalCount: 1,
      incumbentCount: 1,
      newcomerCount: 0,
      formerCount: 0,
      recommendationCount: 0,
      prefectureCount: 1,
    );

    final resolved = repository.resolve(_intelligenceWith(incomplete));

    expect(resolved.sourceAsOf, dpjOfficialEndorsementSourceAsOf);
    expect(resolved, same(repository.fallbackSnapshot));
  });

  test('rejects stale or invalid public source dates', () {
    for (final value in ['2026-10-21', '', '2026-11-31', '2026/11/4']) {
      final candidate = OfficialEndorsementSnapshot.fromJson({
        ..._liveSnapshot.toJson(),
        'sourceAsOf': value,
      });
      expect(
        repository.resolve(_intelligenceWith(candidate)),
        same(repository.fallbackSnapshot),
      );
    }
  });

  test(
      'an explicit zero stays usable; missing or invalid counts survive cache as incomplete',
      () {
    final wire = _liveSnapshot.toJson();
    final known = OfficialEndorsementSnapshot.fromJson(wire);
    expect(known.recommendationCount, 0);
    expect(repository.resolve(_intelligenceWith(known)), same(known));
    final regional = _liveSnapshot.prefectures.single.toJson();
    final missingRegional = Map<String, dynamic>.of(regional)
      ..remove('formerCount');
    final cases = [
      Map<String, dynamic>.of(wire)..remove('sourceCountsComplete'),
      Map<String, dynamic>.of(wire)..remove('recommendationCount'),
      Map<String, dynamic>.of(wire)..remove('formerCount'),
      for (final bad in [null, '0', -1, 0.5, double.infinity])
        {...wire, 'recommendationCount': bad},
      {
        ...wire,
        'prefectures': [missingRegional]
      },
    ];
    for (final candidate in cases) {
      final live = OfficialEndorsementSnapshot.fromJson(candidate);
      final cached = OfficialEndorsementSnapshot.fromJson(live.toJson());
      for (final snapshot in [live, cached]) {
        expect(snapshot.sourceCountsComplete, isFalse);
        expect(
          repository.resolve(_intelligenceWith(snapshot)),
          same(repository.fallbackSnapshot),
        );
      }
    }
  });

  test('newer complete data replaces every field together', () {
    final nextDay = DateTime.parse(dpjOfficialEndorsementSourceAsOf)
        .add(const Duration(days: 1))
        .toIso8601String()
        .split('T')
        .first;
    final candidate = OfficialEndorsementSnapshot.fromJson({
      ..._liveSnapshot.toJson(),
      'sourceAsOf': nextDay,
    });
    expect(repository.resolve(_intelligenceWith(candidate)), same(candidate));
    for (final change in [
      {'prefectures': <Map<String, dynamic>>[]},
      {'municipalCount': 2},
      {'sourceDocumentSha256': ''},
    ]) {
      final partial = OfficialEndorsementSnapshot.fromJson({
        ...candidate.toJson(),
        ...change,
      });
      expect(
        repository.resolve(_intelligenceWith(partial)),
        same(repository.fallbackSnapshot),
      );
    }
  });
}

const _liveSnapshot = OfficialEndorsementSnapshot(
  sourceUrl: 'https://example.com/live',
  sourceAsOf: dpjOfficialEndorsementSourceAsOf,
  sourceDocumentSha256: 'live-sha',
  totalCount: 1,
  incumbentCount: 1,
  newcomerCount: 0,
  formerCount: 0,
  recommendationCount: 0,
  prefectureCount: 1,
  municipalCount: 1,
  prefectures: <OfficialEndorsementPrefecture>[
    OfficialEndorsementPrefecture(
      prefecture: '東京',
      totalCount: 1,
      incumbentCount: 1,
      newcomerCount: 0,
      formerCount: 0,
      municipalCount: 1,
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
