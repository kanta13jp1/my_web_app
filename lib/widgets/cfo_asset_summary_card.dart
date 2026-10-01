import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/department_finance_summary.dart';
import '../view_models/cfo_asset_summary_view_model.dart';

class CfoAssetSummaryCard extends StatelessWidget {
  CfoAssetSummaryCard({
    required this.viewModel,
    required this.onOpenDetails,
    super.key,
  });

  final CfoAssetSummaryViewModel viewModel;
  final VoidCallback onOpenDetails;

  final NumberFormat _yenFormat = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedBuilder(
          animation: viewModel,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildBody(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final monthKey = viewModel.summary?.monthKey;
    return Row(
      children: <Widget>[
        const CircleAvatar(
          backgroundColor: Color(0xFFDCFCE7),
          child: Icon(Icons.account_balance_outlined, color: Color(0xFF166534)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '資産サマリ',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(monthKey == null ? '当月の財務状況' : _monthLabel(monthKey)),
            ],
          ),
        ),
        IconButton(
          tooltip: '資産管理を開く',
          onPressed: onOpenDetails,
          icon: const Icon(Icons.open_in_new),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (viewModel.isLoading && viewModel.summary == null) {
      return Semantics(
        label: '資産サマリを読み込み中',
        child: const LinearProgressIndicator(),
      );
    }
    final errorMessage = viewModel.errorMessage;
    if (errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(errorMessage),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: viewModel.isLoading ? null : viewModel.load,
            icon: const Icon(Icons.refresh),
            label: const Text('再読み込み'),
          ),
        ],
      );
    }
    final summary = viewModel.summary;
    if (summary == null) {
      return const Text('資産サマリはまだありません。');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final columns = constraints.maxWidth >= 880
                ? 4
                : constraints.maxWidth >= 480
                    ? 2
                    : 1;
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: <Widget>[
                _metricTile(
                  context,
                  width: tileWidth,
                  label: '純資産',
                  value: _money(
                    summary.netAssets,
                    summary.netAssetsAvailability,
                  ),
                  availability: summary.netAssetsAvailability,
                ),
                _metricTile(
                  context,
                  width: tileWidth,
                  label: '当月キャッシュフロー',
                  value: _money(
                    summary.currentMonthCashflow,
                    summary.currentMonthCashflowAvailability,
                  ),
                  availability: summary.currentMonthCashflowAvailability,
                ),
                _metricTile(
                  context,
                  width: tileWidth,
                  label: '投資評価額',
                  value: _money(
                    summary.investmentValuation,
                    summary.investmentValuationAvailability,
                  ),
                  availability: summary.investmentValuationAvailability,
                ),
                _metricTile(
                  context,
                  width: tileWidth,
                  label: '未確認の異常',
                  value: summary.anomalyCountAvailability ==
                          FinanceMetricAvailability.notRecorded
                      ? '未記録'
                      : '${summary.anomalyCount}件',
                  availability: summary.anomalyCountAvailability,
                ),
              ],
            );
          },
        ),
        if (viewModel.isLoading) ...<Widget>[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onOpenDetails,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('資産管理の詳細を見る'),
          ),
        ),
      ],
    );
  }

  Widget _metricTile(
    BuildContext context, {
    required double width,
    required String label,
    required String value,
    required FinanceMetricAvailability availability,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (availability == FinanceMetricAvailability.partial) ...<Widget>[
            const SizedBox(height: 4),
            Text('一部のみ反映', style: Theme.of(context).textTheme.labelSmall),
          ],
        ],
      ),
    );
  }

  String _money(num? value, FinanceMetricAvailability availability) {
    if (value == null ||
        availability == FinanceMetricAvailability.notRecorded) {
      return '未記録';
    }
    return _yenFormat.format(value);
  }

  String _monthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    return '${parts[0]}年${parts[1]}月';
  }
}
