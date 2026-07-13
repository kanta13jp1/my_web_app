/// アフィリエイトリンク実績モデル。
///
/// `social-commerce-hub` の `affiliate.list_links`
/// (`{success, links: [hub_data 行]}`) を解析する純データモデル。
/// 実フィールドは `metadata.title` / `metadata.code` / `metadata.url` /
/// `metadata.clicks` / `metadata.conversions` / `metadata.commission_pct`。
/// 旧実装は誤キー (`name` / `earnings` / `status`) + EF 非返却の
/// `data['summary']` を読み、**全カード「クリック 0 / 報酬 ¥0」**だった。
/// 報酬額は EF に売上ベースが無く算出不能 — 捏造 ¥0 を出さず、
/// 実在する clicks / conversions / commission_pct を表示する。
library;

import 'hub_data_parsing.dart';

class AffiliateLinkStats {
  const AffiliateLinkStats({
    required this.title,
    required this.code,
    required this.url,
    required this.clicks,
    required this.conversions,
    required this.commissionPct,
  });

  final String title;
  final String code;
  final String url;
  final num clicks;
  final num conversions;
  final num commissionPct;

  factory AffiliateLinkStats.fromMap(Map<String, dynamic> raw) {
    return AffiliateLinkStats(
      title: hubString(hubField(raw, 'title') ?? raw['name']),
      code: hubString(hubField(raw, 'code')),
      url: hubString(hubField(raw, 'url')),
      clicks: hubNum(hubField(raw, 'clicks')),
      conversions: hubNum(hubField(raw, 'conversions')),
      commissionPct: hubNum(hubField(raw, 'commission_pct')),
    );
  }

  static List<AffiliateLinkStats> listFromResponse(dynamic data) {
    var rows = hubRowsFromResponse(data, 'links');
    if (rows.isEmpty) rows = hubRowsFromResponse(data, 'campaigns');
    return rows.map(AffiliateLinkStats.fromMap).toList();
  }
}

/// リンク一覧から算出する集計 (EF は summary を返さない)。
class AffiliateSummary {
  const AffiliateSummary({
    required this.totalClicks,
    required this.totalConversions,
    required this.linkCount,
  });

  final num totalClicks;
  final num totalConversions;
  final int linkCount;

  factory AffiliateSummary.fromLinks(List<AffiliateLinkStats> links) {
    return AffiliateSummary(
      totalClicks: links.fold<num>(0, (sum, l) => sum + l.clicks),
      totalConversions: links.fold<num>(0, (sum, l) => sum + l.conversions),
      linkCount: links.length,
    );
  }
}
