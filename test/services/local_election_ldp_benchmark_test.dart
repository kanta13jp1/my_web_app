import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
