import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/dpj_official_endorsements.dart';
import 'package:my_web_app/data/dpj_prefecture_announced_targets.dart';

void main() {
  test('党公式の公認掲載は32都道府県で重複なく構造化されている', () {
    expect(dpjOfficialEndorsements, hasLength(32));
    final prefectures =
        dpjOfficialEndorsements.map((item) => item.prefecture).toSet();
    expect(prefectures, hasLength(32));
    expect(dpjOfficialEndorsementPrefectureCount, 32);
  });

  test('神奈川の最新公認掲載は39件で現職・新人の内訳を持つ', () {
    final endorsement = dpjOfficialEndorsementFor('神奈川');
    expect(endorsement, isNotNull);
    expect(endorsement!.totalCount, 39);
    expect(endorsement.incumbentCount, 11);
    expect(endorsement.newcomerCount, 28);
    expect(endorsement.formerCount, 0);
    expect(endorsement.breakdownLabel, '現職11 / 新人28');
  });

  test('公認掲載の全国集計は現元新の内訳と一致する', () {
    expect(dpjOfficialEndorsementTotal, 217);
    expect(dpjOfficialEndorsementIncumbentTotal, 102);
    expect(dpjOfficialEndorsementNewcomerTotal, 106);
    expect(dpjOfficialEndorsementFormerTotal, 9);
    expect(
      dpjOfficialEndorsementIncumbentTotal +
          dpjOfficialEndorsementNewcomerTotal +
          dpjOfficialEndorsementFormerTotal,
      dpjOfficialEndorsementTotal,
    );
  });

  test('全都道府県の現元新内訳は公認掲載件数と一致する', () {
    for (final endorsement in dpjOfficialEndorsements) {
      expect(endorsement.totalCount, greaterThan(0));
      expect(
        endorsement.incumbentCount +
            endorsement.newcomerCount +
            endorsement.formerCount,
        endorsement.totalCount,
        reason: endorsement.prefecture,
      );
    }
  });

  test('党公式一覧の基準日と推薦除外件数が最新値になっている', () {
    expect(dpjLocalElectionOfficialListAsOf, '2026-08-05');
    expect(dpjOfficialRecommendationEntryCount, 9);
  });
}
