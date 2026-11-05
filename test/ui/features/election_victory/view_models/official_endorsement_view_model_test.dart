import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/dpj_official_endorsements.dart';
import 'package:my_web_app/models/election_intelligence.dart';
import 'package:my_web_app/ui/features/election_victory/view_models/official_endorsement_view_model.dart';

void main() {
  test('starts with the generated fallback snapshot', () {
    final viewModel = OfficialEndorsementViewModel();
    addTearDown(viewModel.dispose);

    expect(viewModel.snapshot.sourceAsOf, dpjOfficialEndorsementSourceAsOf);
    expect(viewModel.snapshot.totalCount, dpjOfficialEndorsementTotal);
    expect(viewModel.forPrefecture('佐賀県')?.newcomerCount, 1);
  });

  test('exposes a complete live snapshot and notifies only on value changes',
      () {
    final viewModel = OfficialEndorsementViewModel();
    addTearDown(viewModel.dispose);
    var notificationCount = 0;
    viewModel.addListener(() => notificationCount += 1);
    final intelligence = _intelligenceWith(_liveSnapshot);

    viewModel.updateFromIntelligence(intelligence);
    viewModel.updateFromIntelligence(intelligence);

    expect(notificationCount, 1);
    expect(viewModel.snapshot.sourceAsOf, _newerSourceDate);
    expect(viewModel.forPrefecture('東京都')?.incumbentCount, 1);
  });

  test('returns to fallback when the live snapshot becomes incomplete', () {
    final viewModel = OfficialEndorsementViewModel();
    addTearDown(viewModel.dispose);
    viewModel.updateFromIntelligence(_intelligenceWith(_liveSnapshot));
    var notificationCount = 0;
    viewModel.addListener(() => notificationCount += 1);

    viewModel.updateFromIntelligence(
      const ElectionIntelligenceSnapshot.localFallback(),
    );

    expect(notificationCount, 1);
    expect(viewModel.snapshot.sourceAsOf, dpjOfficialEndorsementSourceAsOf);
    expect(viewModel.snapshot.totalCount, dpjOfficialEndorsementTotal);
  });
}

final _newerSourceDate = DateTime.parse(dpjOfficialEndorsementSourceAsOf)
    .add(const Duration(days: 1))
    .toIso8601String()
    .split('T')
    .first;

final _liveSnapshot = OfficialEndorsementSnapshot(
  sourceUrl: 'https://example.com/live',
  sourceAsOf: _newerSourceDate,
  sourceDocumentSha256: 'live-sha',
  totalCount: 1,
  incumbentCount: 1,
  newcomerCount: 0,
  formerCount: 0,
  recommendationCount: 0,
  prefectureCount: 1,
  prefectures: const <OfficialEndorsementPrefecture>[
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
