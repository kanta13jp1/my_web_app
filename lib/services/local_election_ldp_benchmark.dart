import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// 自民党(自由民主党)の都道府県別 地方議員数ベンチマーク。
///
/// 立憲(CDP)は党サイト `cdp-japan.jp/members/prefecture/` を週次スクレイプ
/// できるが、自民党は県別の地方議員一覧を自党で公開していない。そのため
/// **総務省「地方公共団体の議会の議員及び長の所属党派別人員調」** (党派別・
/// 都道府県別の公式統計、毎年12/31基準) を出典に、所属党派『自由民主党』と
/// 届け出た 都道府県議会・市区議会・町村議会 議員の合計を手動で構造化して
/// `assets/data/ldp_local_members.json` に置き、ここから読み込む。
///
/// 立憲ベンチマーク(党サイトの自己掲載リスト)とは集計方法が異なるため、
/// UI では出典・基準日・集計基準を明示すること。
class LocalElectionLdpBenchmark {
  static const String assetPath = 'assets/data/ldp_local_members.json';

  /// 読み込んだ都道府県 → 議員数マップと、出典メタデータ。
  final Map<String, int> membersByPrefecture;
  final String source;
  final String sourceLabel;
  final String basis;
  final String asOf;

  const LocalElectionLdpBenchmark({
    required this.membersByPrefecture,
    this.source = '',
    this.sourceLabel = '',
    this.basis = '',
    this.asOf = '',
  });

  static const LocalElectionLdpBenchmark empty = LocalElectionLdpBenchmark(
    membersByPrefecture: <String, int>{},
  );

  bool get hasData => membersByPrefecture.isNotEmpty;

  /// バンドルされたアセットを読み込む。欠損・不正時は空を返し、呼び出し側は
  /// seed 値へフォールバックできる。
  static Future<LocalElectionLdpBenchmark> loadFromAsset() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      return parse(raw);
    } catch (_) {
      return empty;
    }
  }

  /// ベンチマーク JSON を解析する。正の値だけを残す。テスト用に公開。
  static LocalElectionLdpBenchmark parse(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return empty;
    }
    if (decoded is! Map) {
      return empty;
    }
    final dynamic prefectures = decoded['prefectures'];
    if (prefectures is! Map) {
      return empty;
    }
    final result = <String, int>{};
    prefectures.forEach((key, value) {
      final name = key.toString().trim();
      final count = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
      if (name.isNotEmpty && count > 0) {
        result[name] = count;
      }
    });
    return LocalElectionLdpBenchmark(
      membersByPrefecture: result,
      source: (decoded['source'] as String? ?? '').trim(),
      sourceLabel: (decoded['sourceLabel'] as String? ?? '').trim(),
      basis: (decoded['basis'] as String? ?? '').trim(),
      asOf: (decoded['asOf'] as String? ?? '').trim(),
    );
  }
}
