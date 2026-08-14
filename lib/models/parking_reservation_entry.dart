/// 駐車場予約モデル。
///
/// `lifestyle-hub` の `parking.list` (`{success, reservations: [hub_data 行]}`)
/// を解析する純データモデル。実フィールドは `metadata.lot_id` /
/// `metadata.spot` / `metadata.start_time` / `metadata.end_time` /
/// `metadata.plate` / `metadata.fee`。旧実装は誤キー (`spot_name` /
/// `reserved_at` / `status` — いずれも不存在) を読み、全行が
/// 「スポット N / 予約済み」の捏造表示だった。
library;

import 'hub_data_parsing.dart';

class ParkingReservationEntry {
  const ParkingReservationEntry({
    required this.lotId,
    required this.spot,
    required this.startTime,
    required this.endTime,
    required this.plate,
    required this.fee,
    required this.createdAt,
  });

  final String lotId;
  final String spot;
  final String startTime;
  final String endTime;
  final String plate;

  /// 料金 (未設定なら null — ¥0 と偽らない)。
  final num? fee;
  final String createdAt;

  /// 一覧タイトル: 'スポット spot (lot)' / どちらも無ければ空文字。
  String get spotLabel {
    if (spot.isNotEmpty && lotId.isNotEmpty) return '$spot ($lotId)';
    if (spot.isNotEmpty) return spot;
    return lotId;
  }

  /// 'start 〜 end' の時間帯ラベル (整形は表示側)。
  String get timeRangeLabel {
    if (startTime.isEmpty && endTime.isEmpty) return '';
    return '${hubFormatTimestamp(startTime)} 〜 ${hubFormatTimestamp(endTime)}';
  }

  factory ParkingReservationEntry.fromMap(Map<String, dynamic> raw) {
    final rawFee = hubField(raw, 'fee');
    return ParkingReservationEntry(
      lotId: hubString(hubField(raw, 'lot_id')),
      spot: hubString(hubField(raw, 'spot') ?? raw['spot_name']),
      startTime: hubString(hubField(raw, 'start_time') ?? raw['reserved_at']),
      endTime: hubString(hubField(raw, 'end_time')),
      plate: hubString(hubField(raw, 'plate')),
      fee: rawFee == null ? null : hubNum(rawFee),
      createdAt: hubString(raw['created_at']),
    );
  }

  static List<ParkingReservationEntry> listFromResponse(dynamic data) =>
      hubRowsFromResponse(data, 'reservations')
          .map(ParkingReservationEntry.fromMap)
          .toList();
}
