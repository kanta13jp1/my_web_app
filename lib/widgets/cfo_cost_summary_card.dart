import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/cfo_cost_ledger.dart';
import '../services/cfo_cost_ledger_service.dart';

class CfoCostSummaryCard extends StatefulWidget {
  const CfoCostSummaryCard({super.key, this.service, this.onOpenLedger});

  final CfoCostLedgerService? service;
  final VoidCallback? onOpenLedger;

  @override
  State<CfoCostSummaryCard> createState() => _CfoCostSummaryCardState();
}

class _CfoCostSummaryCardState extends State<CfoCostSummaryCard> {
  late final CfoCostLedgerService _service =
      widget.service ?? CfoCostLedgerService();
  late Future<CfoCostLedgerSnapshot> _future;
  final _yenFormat = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _future = _service.loadMonth();
  }

  Future<void> refresh() async {
    setState(() {
      _future = _service.loadMonth();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CfoCostLedgerSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.warning_amber_outlined),
              title: const Text('CFOコスト台帳を読み込めません'),
              subtitle: Text('${snapshot.error}'),
              trailing: IconButton(
                tooltip: '再読み込み',
                icon: const Icon(Icons.refresh),
                onPressed: refresh,
              ),
            ),
          );
        }
        final summary = snapshot.data?.summary ??
            CfoCostLedgerService.summarize(
              entries: const <CfoCostEntry>[],
              month: cfoLedgerMonth(DateTime.now()),
              budgetJpy: 0,
            );
        return _buildSummary(context, summary);
      },
    );
  }

  Widget _buildSummary(BuildContext context, CfoMonthlyCostSummary summary) {
    final remaining = summary.budgetRemainingJpy;
    final usage = summary.budgetUsageRatio.clamp(0.0, 1.0);
    final statusColor = summary.isOverBudget
        ? const Color(0xFFB91C1C)
        : const Color(0xFF15803D);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: Color(0xFF166534),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '当月コスト台帳',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text('${summary.month} / ${summary.entries.length}件'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '台帳を開く',
                  onPressed: widget.onOpenLedger,
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _chip('総支出', summary.totalCostJpy),
                _chip('固定費', summary.fixedCostJpy),
                _chip('変動費', summary.variableCostJpy),
                _chip('予算差分', remaining, color: statusColor),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: usage,
              minHeight: 8,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 8),
            Text(
              summary.hasBudget
                  ? summary.isOverBudget
                      ? '予算超過です。固定費・ツール費・広告費を優先レビューします。'
                      : '予算内です。次の支出判断に使えます。'
                  : '月次予算を設定すると予算差分を表示します。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, int amount, {Color? color}) {
    return Chip(
      label: Text('$label ${_yenFormat.format(amount)}'),
      avatar: Icon(Icons.payments_outlined, size: 18, color: color),
    );
  }
}
