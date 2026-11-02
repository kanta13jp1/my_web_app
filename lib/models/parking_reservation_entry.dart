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

/// `parking.reserve` へ送る入力。EF 側は無検証で hub_data に保存するため、
/// 必須項目と時間帯の前後関係はここで弾く (壊れた行を一覧に残さない)。
///
/// 駐車場事業者への実予約ではなく、自分の予約内容の記録である。
class ParkingReservationDraft {
  const ParkingReservationDraft({
    required this.lotName,
    required this.start,
    required this.end,
    this.spot = '',
    this.plate = '',
    this.feeText = '',
  });

  final String lotName;
  final DateTime start;
  final DateTime end;
  final String spot;
  final String plate;

  /// 料金の入力文字列 (空なら未設定 = null で送る)。
  final String feeText;

  /// 入力エラー文言。問題なければ null。
  String? validate() {
    if (lotName.trim().isEmpty) return '駐車場名を入力してください';
    if (!end.isAfter(start)) return '終了日時は開始日時より後にしてください';
    final fee = feeText.trim();
    if (fee.isNotEmpty) {
      final parsed = int.tryParse(fee.replaceAll(',', ''));
      if (parsed == null || parsed < 0) {
        return '料金は0以上の整数(円)で入力してください';
      }
    }
    return null;
  }

  /// `lifestyle-hub` へ渡す body。時刻は UTC ISO8601 (一覧側で local 表示)。
  Map<String, dynamic> toRequestBody() {
    final fee = feeText.trim().replaceAll(',', '');
    return {
      'action': 'parking.reserve',
      'lot_id': lotName.trim(),
      'spot': spot.trim(),
      'start_time': start.toUtc().toIso8601String(),
      'end_time': end.toUtc().toIso8601String(),
      'plate': plate.trim(),
      'fee': fee.isEmpty ? null : int.parse(fee),
    };
  }
}
