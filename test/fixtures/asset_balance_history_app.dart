import 'package:flutter/material.dart';
import 'package:my_web_app/models/asset_balance_observation.dart';
import 'package:my_web_app/widgets/asset_balance_history_control.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  final rows = [
    AssetBalanceObservation(
      id: 3,
      accountName: 'サンプル銀行',
      amount: 12000,
      recordedAt: DateTime.parse('2026-10-11T08:44:00Z'),
    ),
    AssetBalanceObservation(
      id: 2,
      accountName: 'サンプル銀行',
      amount: 12000,
      recordedAt: DateTime.parse('2026-10-10T17:18:00Z'),
    ),
    AssetBalanceObservation(
      id: 1,
      accountName: 'サンプル銀行',
      amount: -5000,
      recordedAt: DateTime.parse('2026-10-09T08:39:00Z'),
    ),
  ];
  runApp(MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('残高履歴のプレビュー')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('サンプル銀行  ¥12,000'),
            AssetBalanceHistoryControl(
              accountName: 'サンプル銀行',
              latest: rows.first,
              loadPage: (offset) async => offset == 0 ? rows : [],
            ),
          ],
        ),
      ),
    ),
  ));
}
