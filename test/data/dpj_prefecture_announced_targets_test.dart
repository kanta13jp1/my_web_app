import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/dpj_prefecture_announced_targets.dart';

void main() {
  test('27県分の目標が掲載されている', () {
    expect(dpjPrefectureAnnouncedTargets, hasLength(27));
    final prefectures =
        dpjPrefectureAnnouncedTargets.map((item) => item.prefecture).toSet();
    expect(prefectures, hasLength(27));
  });

  test('表題は「目標当選人数」を使わない', () {
    expect(dpjAnnouncedTargetSectionTitle, isNot(contains('当選')));
    expect(dpjAnnouncedTargetSectionTitle, contains('Road to 700'));
    expect(dpjAnnouncedTargetSectionTitle, contains('擁立'));
  });

  test('注記が擁立と当選の読み替え禁止を明示する', () {
    expect(dpjAnnouncedTargetCaveat, contains('目標当選人数'));
    expect(dpjAnnouncedTargetCaveat, contains('擁立'));
  });

  test('定義確認済みは6県で、種別が正しく区別されている', () {
    final verified =
        dpjPrefectureAnnouncedTargets.where((item) => item.verified).toList();
    expect(verified, hasLength(6));
    expect(dpjAnnouncedTargetVerifiedCount, 6);

    final byPrefecture = <String, DpjPrefectureAnnouncedTarget>{
      for (final item in verified) item.prefecture: item,
    };
    expect(
      byPrefecture['神奈川']?.kind,
      DpjAnnouncedTargetKind.candidateFielding,
    );
    expect(byPrefecture['神奈川']?.minCount, 50);
    expect(
      byPrefecture['静岡']?.kind,
      DpjAnnouncedTargetKind.totalLocalMembers,
    );
    expect(byPrefecture['静岡']?.minCount, 29);
    expect(
      byPrefecture['大阪']?.kind,
      DpjAnnouncedTargetKind.candidateFielding,
    );
    expect(byPrefecture['大阪']?.minCount, 35);
    expect(
      byPrefecture['香川']?.kind,
      DpjAnnouncedTargetKind.totalLocalMembers,
    );
    expect(byPrefecture['香川']?.minCount, 56);
    expect(
      byPrefecture['福岡']?.kind,
      DpjAnnouncedTargetKind.candidateFielding,
    );
    expect(byPrefecture['福岡']?.minCount, 30);
    expect(
      byPrefecture['宮崎']?.kind,
      DpjAnnouncedTargetKind.allLocalElectionsFielding,
    );
    expect(byPrefecture['宮崎']?.minCount, 25);
  });

  test('定義未確認の数字は種別未確認として扱う', () {
    final unconfirmed = dpjPrefectureAnnouncedTargets
        .where((item) => item.kind == DpjAnnouncedTargetKind.unconfirmed)
        .toList();
    expect(unconfirmed, hasLength(21));
    expect(dpjAnnouncedTargetUnconfirmedCount, 21);
    expect(unconfirmed.every((item) => !item.verified), isTrue);
    expect(
      unconfirmed.every((item) => item.kindLabel == '種別未確認'),
      isTrue,
    );
  });

  test('北海道はレンジ表記になる', () {
    final hokkaido = dpjPrefectureAnnouncedTargets.firstWhere(
      (item) => item.prefecture == '北海道',
    );
    expect(hokkaido.isRange, isTrue);
    expect(hokkaido.countLabel, '20〜30人');
  });

  test('単一値の県は単独表記になる', () {
    final toyama = dpjPrefectureAnnouncedTargets.firstWhere(
      (item) => item.prefecture == '富山',
    );
    expect(toyama.isRange, isFalse);
    expect(toyama.countLabel, '7人');
  });

  test('第1次公認は神奈川に出典付きで構造化されている', () {
    final kanagawa = dpjPrefectureAnnouncedTargets.firstWhere(
      (item) => item.prefecture == '神奈川',
    );
    final endorsement = kanagawa.firstEndorsement;
    expect(endorsement, isNotNull);
    expect(endorsement!.totalCount, 30);
    expect(endorsement.incumbentCount, 11);
    expect(endorsement.newcomerCount, 19);
    // 現職+新人が総数と一致する(内訳の整合性)。
    expect(
      endorsement.incumbentCount + endorsement.newcomerCount,
      endorsement.totalCount,
    );
    expect(endorsement.hasBreakdown, isTrue);
    expect(endorsement.breakdownLabel, '現職11 / 新人19');
    // 捏造防止: 出典URLが必ず付いている。
    expect(endorsement.sourceUrl, isNotEmpty);
    expect(endorsement.asOf, '2026-06-25');
  });

  test('第1次公認の全国集計が県別データと一致する', () {
    expect(dpjFirstEndorsementPrefectureCount, 1);
    expect(dpjFirstEndorsementTotal, 30);
    expect(dpjFirstEndorsementIncumbentTotal, 11);
    expect(dpjFirstEndorsementNewcomerTotal, 19);
    // 集計は県別 firstEndorsement の合計と一致する。
    final manualTotal = dpjPrefectureAnnouncedTargets.fold<int>(
      0,
      (sum, item) => sum + (item.firstEndorsement?.totalCount ?? 0),
    );
    expect(dpjFirstEndorsementTotal, manualTotal);
  });

  test('第1次公認の出典を持つ県はすべて出典URLと基準日を持つ', () {
    for (final item in dpjPrefecturesWithFirstEndorsement) {
      final endorsement = item.firstEndorsement!;
      expect(endorsement.sourceUrl, isNotEmpty, reason: item.prefecture);
      expect(endorsement.asOf, isNotEmpty, reason: item.prefecture);
      // 内訳を入れる場合は現職+新人+元 <= 総数(過大内訳を防ぐ)。
      expect(
        endorsement.incumbentCount +
            endorsement.newcomerCount +
            endorsement.formerCount,
        lessThanOrEqualTo(endorsement.totalCount),
        reason: item.prefecture,
      );
    }
  });
}
