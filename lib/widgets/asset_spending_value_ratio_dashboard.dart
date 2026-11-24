import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/asset_spending_value_classification_service.dart';

/// 支出の「消費・浪費・投資」割合と設定目安 (70:5:25) を比較表示するダッシュボード (#1368)。
class AssetSpendingValueRatioDashboard extends StatelessWidget {
  const AssetSpendingValueRatioDashboard({
    super.key,
    required this.report,
    required this.onReclassifyEntry,
    required this.onAddCustomEntries,
    this.onRemoveCustomEntry,
  });

  final SpendingValueRatioReport report;
  final void Function(String fingerprint, SpendingValueCategory category)
      onReclassifyEntry;
  final void Function(List<AssetSpendingValueCustomEntry> entries)
      onAddCustomEntries;
  final void Function(String customEntryId)? onRemoveCustomEntry;

  static Color _colorForCategory(SpendingValueCategory category) {
    switch (category) {
      case SpendingValueCategory.consumption:
        return const Color(0xFF2563EB);
      case SpendingValueCategory.waste:
        return const Color(0xFFDC2626);
      case SpendingValueCategory.investment:
        return const Color(0xFF059669);
      case SpendingValueCategory.needsReview:
        return const Color(0xFFD97706);
    }
  }

  String _formatYen(double amount) {
    final fmt = NumberFormat('#,##0', 'ja_JP');
    return '¥${fmt.format(amount.round())}';
  }

  @override
  Widget build(BuildContext context) {
    final buckets = <SpendingValueCategoryBucket>[
      report.consumption,
      report.waste,
      report.investment,
    ];
    final nonZeroBuckets =
        buckets.where((bucket) => bucket.amount > 0).toList(growable: false);
    final previewEntries = report.entries.take(8).toList(growable: false);

    return Card(
      key: const Key('asset_spending_value_ratio_dashboard_card'),
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFCCFBF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 520;
                final headerText = Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '消費・浪費・投資 割合比較ダッシュボード',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '設定目安（消費${report.idealConsumptionPercent.toStringAsFixed(0)}% : '
                        '浪費${report.idealWastePercent.toStringAsFixed(0)}% : '
                        '投資${report.idealInvestmentPercent.toStringAsFixed(0)}%）との差分を表示します。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
                final addBtn = OutlinedButton.icon(
                  key: const Key('spending_value_add_or_import_button'),
                  onPressed: () => _openManualAndImportDialog(context),
                  icon: const Icon(Icons.playlist_add_outlined, size: 18),
                  label: const Text('支出ラベル入力・CSV取込'),
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.donut_large_outlined,
                            color: Color(0xFF0F766E),
                          ),
                          const SizedBox(width: 10),
                          headerText,
                        ],
                      ),
                      const SizedBox(height: 10),
                      addBtn,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.donut_large_outlined,
                      color: Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 10),
                    headerText,
                    const SizedBox(width: 12),
                    addBtn,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildDeltaChip(report.consumption, invertGood: false),
                _buildDeltaChip(report.waste, invertGood: true),
                _buildDeltaChip(report.investment, invertGood: false),
                if (report.needsReviewCount > 0)
                  Container(
                    key: const Key('spending_value_needs_review_chip'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Text(
                      '要確認（未確定）: ${report.needsReviewCount}件 / ${_formatYen(report.needsReviewTotal)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (nonZeroBuckets.isEmpty)
              Container(
                key: const Key('spending_value_empty_banner'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  '確定済みの「消費・浪費・投資」データがありません。明細ラベルを確認するか、手入力・CSVから追加してください。',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 600;
                  final chart = SizedBox(
                    key: const Key('spending_value_ratio_pie_chart'),
                    height: compact ? 180 : 210,
                    width: compact ? double.infinity : 220,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: compact ? 36 : 44,
                        sections: <PieChartSectionData>[
                          for (final bucket in nonZeroBuckets)
                            PieChartSectionData(
                              color: _colorForCategory(bucket.category),
                              value: bucket.amount,
                              title:
                                  '${bucket.category.label}\n${bucket.actualPercent.round()}%',
                              radius: compact ? 62 : 70,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                  final bars = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final bucket in buckets) ...[
                        _buildBucketComparisonRow(context, bucket),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                  if (compact) {
                    return Column(
                      children: <Widget>[
                        chart,
                        const SizedBox(height: 12),
                        bars,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      chart,
                      const SizedBox(width: 18),
                      Expanded(child: bars),
                    ],
                  );
                },
              ),
            const SizedBox(height: 12),
            Container(
              key: const Key('spending_value_advice_box'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '改善に向けたアドバイス',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF14532D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final advice in report.adviceList)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '・$advice',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    '※ 70:5:25は管理上の参考設定比率であり、普遍的な最適値を保証するものではありません。'
                    '使途不明の現金引出しや残高差分は自動で浪費に確定しません。',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            if (previewEntries.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                '明細別ラベル確認・変更（ワンタップ切替）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in previewEntries)
                _buildClassifiedEntryRow(context, item),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeltaChip(
    SpendingValueCategoryBucket bucket, {
    required bool invertGood,
  }) {
    final color = _colorForCategory(bucket.category);
    final sign = bucket.deltaPercent >= 0 ? '+' : '';
    final isAlert = invertGood
        ? bucket.deltaPercent > 2.0
        : (bucket.category == SpendingValueCategory.investment
            ? bucket.deltaPercent < -2.0
            : bucket.deltaPercent > 5.0);
    return Container(
      key: Key('spending_value_delta_chip_${bucket.category.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFEF2F2) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isAlert ? const Color(0xFFEF4444) : color,
        ),
      ),
      child: Text(
        '${bucket.category.label} ${bucket.actualPercent.toStringAsFixed(1)}% '
        '(目安${bucket.idealPercent.toStringAsFixed(0)}% / 差$sign${bucket.deltaPercent.toStringAsFixed(1)}pt)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isAlert ? const Color(0xFF991B1B) : color,
        ),
      ),
    );
  }

  Widget _buildBucketComparisonRow(
    BuildContext context,
    SpendingValueCategoryBucket bucket,
  ) {
    final color = _colorForCategory(bucket.category);
    final actualFraction = (bucket.actualPercent / 100.0).clamp(0.0, 1.0);
    final idealFraction = (bucket.idealPercent / 100.0).clamp(0.0, 1.0);
    final sign = bucket.deltaAmount >= 0 ? '+' : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${bucket.category.label}: ${_formatYen(bucket.amount)} (${bucket.count}件)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            Text(
              '目安比 $sign${_formatYen(bucket.deltaAmount.abs())}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: actualFraction,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: idealFraction,
            minHeight: 4,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(
              color.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassifiedEntryRow(
    BuildContext context,
    ClassifiedSpendingEntry item,
  ) {
    final dateText = DateFormat('M/d').format(item.entry.date);
    final customId = item.customEntryId;
    final removeEntry = onRemoveCustomEntry;
    return Container(
      key: Key('spending_value_entry_${item.fingerprint}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.category == SpendingValueCategory.needsReview
              ? const Color(0xFFF59E0B)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$dateText ${item.entry.description}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatYen(item.entry.amount.abs()),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (customId != null && removeEntry != null)
                IconButton(
                  tooltip: '削除',
                  onPressed: () => removeEntry(customId),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${item.reason} (${item.entry.sourceLabel})',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final cat in SpendingValueCategory.values)
                ChoiceChip(
                  key: Key(
                    'spending_value_set_${item.fingerprint}_${cat.name}',
                  ),
                  label: Text(
                    cat.label,
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: item.category == cat,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onReclassifyEntry(item.fingerprint, cat),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openManualAndImportDialog(BuildContext context) async {
    final added = await showDialog<List<AssetSpendingValueCustomEntry>>(
      context: context,
      builder: (_) => const SpendingValueManualAndImportDialog(),
    );
    if (added != null && added.isNotEmpty) {
      onAddCustomEntries(added);
    }
  }
}

/// 支出の手動ラベル入力およびCSVインポート用ダイアログ (#1368)。
class SpendingValueManualAndImportDialog extends StatefulWidget {
  const SpendingValueManualAndImportDialog({super.key});

  @override
  State<SpendingValueManualAndImportDialog> createState() =>
      _SpendingValueManualAndImportDialogState();
}

class _SpendingValueManualAndImportDialogState
    extends State<SpendingValueManualAndImportDialog> {
  final TextEditingController _dateController = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _csvController = TextEditingController();

  SpendingValueCategory _selectedCategory = SpendingValueCategory.consumption;
  String? _errorMessage;

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _csvController.dispose();
    super.dispose();
  }

  void _submitManual() {
    final date = DateTime.tryParse(_dateController.text.trim());
    final amount = double.tryParse(
      _amountController.text.replaceAll(RegExp(r'[,¥円\s]'), '').trim(),
    );
    final desc = _descriptionController.text.trim();
    if (date == null || amount == null || amount <= 0 || desc.isEmpty) {
      setState(() {
        _errorMessage = '日付 (yyyy-MM-dd)・正の金額・内容を正しく入力してください。';
      });
      return;
    }
    final entry = AssetSpendingValueCustomEntry(
      id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
      date: date,
      amount: amount,
      description: desc,
      category: _selectedCategory,
      sourceLabel: '手入力（3分類ラベル指定）',
    );
    Navigator.of(context).pop(<AssetSpendingValueCustomEntry>[entry]);
  }

  void _submitCsv() {
    final parsed = AssetSpendingValueClassificationService.parseTaggedImportCsv(
      _csvController.text,
      idSeed: DateTime.now().millisecondsSinceEpoch,
    );
    if (parsed.isEmpty) {
      setState(() {
        _errorMessage = '有効なCSV行が見つかりません。「2026-11-20,3000,書籍代,投資」形式で入力してください。';
      });
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;
    return AlertDialog(
      key: const Key('spending_value_manual_import_dialog'),
      title: const Text('支出ラベル入力・CSV取込（消費・浪費・投資）'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (errorMessage != null) ...[
                Text(
                  errorMessage,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const Text(
                '1件をラベル付きで追加',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('spending_value_manual_date_field'),
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: '日付 (yyyy-MM-dd)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('spending_value_manual_amount_field'),
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '金額（円）',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('spending_value_manual_desc_field'),
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '摘要（例: 技術書、コンビニ、ATM手数料）',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final cat in <SpendingValueCategory>[
                    SpendingValueCategory.consumption,
                    SpendingValueCategory.waste,
                    SpendingValueCategory.investment,
                  ])
                    ChoiceChip(
                      key: Key('spending_value_manual_cat_${cat.name}'),
                      label: Text(cat.label),
                      selected: _selectedCategory == cat,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('spending_value_manual_save_button'),
                  onPressed: _submitManual,
                  child: const Text('手入力を追加'),
                ),
              ),
              const Divider(height: 24),
              const Text(
                'CSVテキストから一括インポート',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                '書式: 日付,金額,摘要,分類（分類省略時はルールで仮判定）',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('spending_value_csv_field'),
                controller: _csvController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '2026-11-20,3000,技術書,投資\n2026-11-21,220,ATM手数料,浪費',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  key: const Key('spending_value_csv_import_button'),
                  onPressed: _submitCsv,
                  child: const Text('CSVを取り込む'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
