import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Read-only details for differences between adjacent recorded dates.
class AssetRecordedChangeDetails extends StatelessWidget {
  const AssetRecordedChangeDetails({
    super.key,
    required this.dates,
    required this.changes,
  });

  final List<String> dates;
  final List<double> changes;

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty || dates.length != changes.length) {
      return const SizedBox.shrink();
    }
    final money = NumberFormat.currency(locale: 'ja_JP', symbol: '¥', decimalDigits: 0);
    return ExpansionTile(
      title: const Text('記録日ごとの差額を一覧で確認'),
      subtitle: const Text('初回は比較なし。利益・日次収支ではありません。'),
      children: [
        for (var i = 0; i < dates.length; i++)
          ListTile(
            title: Text(dates[i]),
            subtitle: Text(
              i == 0
                  ? '比較元なし（最初の記録）'
                  : '比較元 ${dates[i - 1]} → ${dates[i]}\n残高差 ${changes[i] > 0 ? '+' : ''}${money.format(changes[i])}',
            ),
          ),
      ],
    );
  }
}
