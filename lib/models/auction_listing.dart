/// オークション出品モデル。
///
/// `social-commerce-hub` の `auction.list` (`{success, auctions: [hub_data 行]}`)
/// を解析する純データモデル。実フィールドは `metadata.title` /
/// `metadata.current_bid` / `metadata.start_price` / `metadata.ends_at`。
/// 旧実装は誤キー `current_price` / `end_at` (不存在) を読み、名称捏造 +
/// 価格・終了時刻が全行非表示だった。`description` は EF に保存されない。
library;

import 'hub_data_parsing.dart';

class AuctionListing {
  const AuctionListing({
    required this.title,
    required this.currentBid,
    required this.startPrice,
    required this.endsAt,
    required this.status,
  });

  final String title;

  /// 現在入札額 (未設定なら null)。
  final num? currentBid;
  final num? startPrice;

  /// 終了時刻 (ISO / 未設定は空文字)。
  final String endsAt;
  final String status;

  /// 表示する価格: 現在入札額 → 開始価格の順 (どちらも無ければ null)。
  num? get displayPrice => currentBid ?? startPrice;

  factory AuctionListing.fromMap(Map<String, dynamic> raw) {
    final rawBid = hubField(raw, 'current_bid') ?? raw['current_price'];
    final rawStart = hubField(raw, 'start_price');
    return AuctionListing(
      title: hubString(hubField(raw, 'title')),
      currentBid: rawBid == null ? null : hubNum(rawBid),
      startPrice: rawStart == null ? null : hubNum(rawStart),
      endsAt: hubString(hubField(raw, 'ends_at') ?? raw['end_at']),
      status: hubString(hubField(raw, 'status')),
    );
  }

  /// `auction.list` は `auctions`、旧クライアント互換で `items` も許容。
  static List<AuctionListing> listFromResponse(dynamic data) {
    var rows = hubRowsFromResponse(data, 'auctions');
    if (rows.isEmpty) rows = hubRowsFromResponse(data, 'items');
    return rows.map(AuctionListing.fromMap).toList();
  }
}
