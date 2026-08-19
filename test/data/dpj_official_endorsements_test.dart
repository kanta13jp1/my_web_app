import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/dpj_official_endorsements.dart';

void main() {
  test('党公式の公認掲載は36都道府県で重複なく構造化されている', () {
    expect(dpjOfficialEndorsements, hasLength(36));
    final prefectures =
        dpjOfficialEndorsements.map((item) => item.prefecture).toSet();
    expect(prefectures, hasLength(36));
    expect(dpjOfficialEndorsementPrefectureCount, 36);
  });

  test('8月19日更新で長野・和歌山・鳥取が掲載されている', () {
    expect(dpjOfficialEndorsementFor('長野県')?.newcomerCount, 2);
    expect(dpjOfficialEndorsementFor('和歌山県')?.newcomerCount, 1);
    expect(dpjOfficialEndorsementFor('鳥取県')?.newcomerCount, 1);
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
    expect(dpjOfficialEndorsementTotal, 264);
    expect(dpjOfficialEndorsementIncumbentTotal, 115);
    expect(dpjOfficialEndorsementNewcomerTotal, 139);
    expect(dpjOfficialEndorsementFormerTotal, 10);
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
    expect(dpjOfficialEndorsementSourceUrl, startsWith('https://'));
    expect(dpjOfficialEndorsementSourceUrl, contains('new-kokumin.jp'));
    expect(dpjOfficialEndorsementSourceAsOf, '2026-08-19');
    expect(DateTime.tryParse(dpjOfficialEndorsementSourceAsOf), isNotNull);
    expect(dpjOfficialRecommendationEntryCount, 9);
  });
}
