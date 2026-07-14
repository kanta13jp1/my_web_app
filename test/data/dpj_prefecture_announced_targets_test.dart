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
}
