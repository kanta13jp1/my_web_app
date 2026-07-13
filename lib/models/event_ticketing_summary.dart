/// イベントチケット販売モデル。
///
/// `social-commerce-hub` の `event.list` (`{success, events: [hub_data 行]}`)
/// を解析する純データモデル。実フィールドは `metadata.title` / `metadata.date`
/// / `metadata.capacity` / `metadata.sold`。旧実装は flat キー読みで名称捏造 +
/// 不存在キー `tickets_remaining` により**全イベント「残 0 枚」**表示だった。
/// 残数は `capacity - sold` から算出する (capacity 未設定は「捏造 0」に
/// しない — null を返し表示側で「定員未設定」)。
library;

import 'hub_data_parsing.dart';

class EventTicketingSummary {
  const EventTicketingSummary({
    required this.title,
    required this.date,
    required this.venue,
    required this.capacity,
    required this.sold,
  });

  final String title;
  final String date;
  final String venue;

  /// 定員 (EF 未設定なら null — 0 と区別する)。
  final num? capacity;
  final num sold;

  /// 残チケット数。定員未設定なら null (0 枚と偽らない)。
  num? get remaining {
    final cap = capacity;
    if (cap == null) return null;
    final rest = cap - sold;
    return rest < 0 ? 0 : rest;
  }

  /// 一覧 trailing 用ラベル。
  String get remainingLabel {
    final rest = remaining;
    return rest == null ? '定員未設定' : '残 ${rest.toInt()}枚';
  }

  factory EventTicketingSummary.fromMap(Map<String, dynamic> raw) {
    final rawCapacity = hubField(raw, 'capacity');
    return EventTicketingSummary(
      title: hubString(hubField(raw, 'title')),
      date: hubString(hubField(raw, 'date')),
      venue: hubString(hubField(raw, 'venue')),
      capacity: rawCapacity == null ? null : hubNum(rawCapacity),
      sold: hubNum(hubField(raw, 'sold')),
    );
  }

  static List<EventTicketingSummary> listFromResponse(dynamic data) =>
      hubRowsFromResponse(data, 'events')
          .map(EventTicketingSummary.fromMap)
          .toList();
}
