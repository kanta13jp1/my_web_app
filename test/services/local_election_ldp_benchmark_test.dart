import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_plan.dart';
import 'package:my_web_app/services/local_election_plan_service.dart';
import 'package:my_web_app/services/local_election_ldp_benchmark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parse は正の値だけ残し出典メタデータを読む', () {
    final bench = LocalElectionLdpBenchmark.parse(
      jsonEncode({
        'source': 'https://www.soumu.go.jp/example',
        'sourceLabel': '総務省 所属党派別人員調',
        'basis': '届出党派 自民 の地方議員合計',
        'asOf': '2025-12-31',
        'prefectures': {'東京': 362, '沖縄': 50, '欠損': 0, '不正': 'x'},
      }),
    );
    expect(bench.hasData, isTrue);
    expect(bench.membersByPrefecture['東京'], 362);
    expect(bench.membersByPrefecture['沖縄'], 50);
    expect(bench.membersByPrefecture.containsKey('欠損'), isFalse);
    expect(bench.membersByPrefecture.containsKey('不正'), isFalse);
    expect(bench.source, 'https://www.soumu.go.jp/example');
    expect(bench.asOf, '2025-12-31');
  });

  test('不正JSON・prefectures欠損は空を返す', () {
    expect(LocalElectionLdpBenchmark.parse('not json').hasData, isFalse);
    expect(LocalElectionLdpBenchmark.parse('[]').hasData, isFalse);
    expect(
      LocalElectionLdpBenchmark.parse(jsonEncode({'source': 'x'})).hasData,
      isFalse,
    );
  });

  test('バンドルされた自民アセットは47県・全て正の値・出典付き', () async {
    final raw =
        await rootBundle.loadString(LocalElectionLdpBenchmark.assetPath);
    final bench = LocalElectionLdpBenchmark.parse(raw);
    expect(bench.membersByPrefecture.length, 47);
    expect(
      bench.membersByPrefecture.values.every((v) => v > 0),
      isTrue,
    );
    // 出典・基準日・集計基準が必ず付いている(捏造防止)。
    expect(bench.source, contains('soumu.go.jp'));
    expect(bench.asOf, isNotEmpty);
    expect(bench.basis, isNotEmpty);
    // 主要県のスポットチェック(総務省 令和7年12月31日現在の届出党派集計)。
    expect(bench.membersByPrefecture['東京'], 362);
    expect(bench.membersByPrefecture['神奈川'], 173);
    expect(bench.membersByPrefecture['岩手'], 18);
  });

  test('アセットのキーは正規化後に全47県プランと突合できる', () async {
    final raw =
        await rootBundle.loadString(LocalElectionLdpBenchmark.assetPath);
    final bench = LocalElectionLdpBenchmark.parse(raw);
    // 素のキーでも、総務省形式(青森県/東京都)でも、正規化すれば
    // プラン側の県名と1件残らず一致すること。片方しか一致しないと
    // 「掲載 1/47」が正しい値のように出る沈黙した誤りになる。
    final planPrefectures = const LocalElectionPlanService()
        .buildDefaultPlan()
        .prefectures
        .map((item) => item.prefecture)
        .toSet();
    expect(planPrefectures.length, 47);

    final normalizedAssetKeys = bench.membersByPrefecture.keys
        .map(LocalElectionPlanDashboard.normalizePrefectureKey)
        .toSet();
    expect(normalizedAssetKeys.length, 47);
    expect(
      normalizedAssetKeys.difference(planPrefectures),
      isEmpty,
      reason: 'アセットにプラン外の県名がある',
    );
    expect(
      planPrefectures.difference(normalizedAssetKeys),
      isEmpty,
      reason: 'プランの県がアセットに無い(自民データ欠落)',
    );
  });

  test('総務省形式のフルネームキーでも全47県に適用される', () {
    // 将来アセットを総務省の正式名で再生成しても、正規化により
    // 全県へ反映されること (北海道だけ一致する退行を防ぐ)。
    final plan = const LocalElectionPlanService().buildDefaultPlan();
    final fullNameBenchmark = <String, int>{
      for (final item in plan.prefectures)
        item.prefecture == '北海道' ? '北海道' : '${item.prefecture}県': 7,
    };
    final applied = plan.withLdpLocalMembers(fullNameBenchmark);
    expect(applied.ldpComparisonPrefectureCount, 47);
    expect(applied.totalLdpLocalMembers, 47 * 7);
  });
}
