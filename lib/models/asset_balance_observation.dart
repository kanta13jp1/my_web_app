import 'package:intl/intl.dart';

/// A saved balance row. Reading or displaying it never changes financial data.
class AssetBalanceObservation {
  const AssetBalanceObservation({
    required this.accountName,
    required this.amount,
    required this.recordedAt,
    this.id,
  });

  factory AssetBalanceObservation.fromRow(Map<String, dynamic> row) {
    return AssetBalanceObservation(
      id: (row['id'] as num?)?.toInt(),
      accountName: row['title'] as String,
      amount: (row['amount'] as num).toDouble(),
      recordedAt: DateTime.parse(row['created_at'] as String),
    );
  }

  final int? id;
  final String accountName;
  final double amount;
  final DateTime recordedAt;

  /// Japan's offset is fixed; do not depend on the browser or CI time zone.
  String get timestampLabel {
    final japanTime = recordedAt.toUtc().add(const Duration(hours: 9));
    return '${DateFormat('yyyy-MM-dd HH:mm').format(japanTime)} JST';
  }

  static int newestFirst(
    AssetBalanceObservation left,
    AssetBalanceObservation right,
  ) {
    final time = right.recordedAt.compareTo(left.recordedAt);
    return time != 0 ? time : (right.id ?? 0).compareTo(left.id ?? 0);
  }
}
