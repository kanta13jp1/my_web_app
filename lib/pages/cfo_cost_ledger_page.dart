import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/cfo_cost_ledger.dart';
import '../services/cfo_cost_ledger_service.dart';

class CfoCostLedgerPage extends StatefulWidget {
  const CfoCostLedgerPage({super.key});

  @override
  State<CfoCostLedgerPage> createState() => _CfoCostLedgerPageState();
}

class _CfoCostLedgerPageState extends State<CfoCostLedgerPage> {
  final _service = CfoCostLedgerService();
  final _yenFormat = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );

  late String _selectedMonth;
  CfoCostLedgerSnapshot? _snapshot;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  final _itemController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _budgetController = TextEditingController();
  String _category = 'operations';
  CfoCostType _costType = CfoCostType.variable;
  DateTime _incurredOn = DateTime.now();

  static const _categories = <String, String>{
    'operations': '運営費',
    'tools': 'AI/ツール',
    'marketing': '広告・販促',
    'infrastructure': 'インフラ',
    'legal': '法務・管理',
    'travel': '交通・外出',
    'other': 'その他',
  };

  @override
  void initState() {
    super.initState();
    _selectedMonth = cfoLedgerMonth(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final snapshot = await _service.loadMonth(month: _selectedMonth);
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        if (snapshot.budget != null) {
          _budgetController.text = snapshot.budget!.budgetJpy.toString();
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = '$error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveBudget() async {
    final budget = _parseAmount(_budgetController.text);
    if (budget == null) {
      _showSnack('予算額を数字で入力してください', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _service.setMonthlyBudget(month: _selectedMonth, budgetJpy: budget);
      await _load();
      _showSnack('月次予算を保存しました');
    } catch (error) {
      _showSnack('予算保存に失敗しました: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _addCostEntry() async {
    final item = _itemController.text.trim();
    final amount = _parseAmount(_amountController.text);
    if (item.isEmpty || amount == null) {
      _showSnack('コスト項目と金額を入力してください', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _service.addEntry(
        CfoCostEntryDraft(
          item: item,
          category: _category,
          amountJpy: amount,
          incurredOn: _incurredOn,
          costType: _costType,
          note: _noteController.text.trim(),
        ),
      );
      _itemController.clear();
      _amountController.clear();
      _noteController.clear();
      _costType = CfoCostType.variable;
      await _load();
      _showSnack('コストを記録しました');
    } catch (error) {
      _showSnack('コスト記録に失敗しました: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  int? _parseAmount(String value) {
    final normalized = value.replaceAll(',', '').trim();
    final parsed = int.tryParse(normalized);
    if (parsed == null || parsed < 0) {
      return null;
    }
    return parsed;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _incurredOn,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _incurredOn = picked;
      _selectedMonth = cfoLedgerMonth(picked);
    });
    await _load();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFB91C1C) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CFO コスト台帳'),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
            onPressed: _isSaving ? null : _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      if (snapshot != null) _buildSummary(snapshot.summary),
                      const SizedBox(height: 12),
                      _buildBudgetForm(),
                      const SizedBox(height: 12),
                      _buildCostForm(),
                      const SizedBox(height: 12),
                      if (snapshot != null)
                        _buildEntryList(snapshot.summary.entries),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 44, color: Color(0xFFB91C1C)),
            const SizedBox(height: 12),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(CfoMonthlyCostSummary summary) {
    final usage = summary.budgetUsageRatio.clamp(0.0, 1.0);
    final remaining = summary.budgetRemainingJpy;
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
                const Icon(Icons.account_balance_wallet_outlined),
                const SizedBox(width: 8),
                Text(
                  '$_selectedMonth 月次コスト',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _summaryChip('総支出', summary.totalCostJpy),
                _summaryChip('固定費', summary.fixedCostJpy),
                _summaryChip('変動費', summary.variableCostJpy),
                _summaryChip('予算差分', remaining, color: statusColor),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: usage,
              minHeight: 10,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 8),
            Text(
              summary.hasBudget
                  ? summary.isOverBudget
                      ? '予算を ${_yenFormat.format(-remaining)} 超過しています。固定費とAI/ツール費から見直します。'
                      : '残予算は ${_yenFormat.format(remaining)} です。'
                  : '月次予算を設定すると、予算差分をCFOが即時確認できます。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, int amount, {Color? color}) {
    return Chip(
      avatar: Icon(Icons.payments_outlined, size: 18, color: color),
      label: Text('$label ${_yenFormat.format(amount)}'),
    );
  }

  Widget _buildBudgetForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '月次予算',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('cfo_monthly_budget_input'),
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '予算額 (円)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveBudget,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'コスト入力',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('cfo_cost_item_input'),
              controller: _itemController,
              decoration: const InputDecoration(
                labelText: '項目名',
                hintText: '例: Supabase Pro、広告テスト、外注レビュー',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('cfo_cost_amount_input'),
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '金額 (円)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリ',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _category = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<CfoCostType>(
              segments: const <ButtonSegment<CfoCostType>>[
                ButtonSegment<CfoCostType>(
                  value: CfoCostType.variable,
                  icon: Icon(Icons.trending_up),
                  label: Text('変動費'),
                ),
                ButtonSegment<CfoCostType>(
                  value: CfoCostType.fixed,
                  icon: Icon(Icons.lock_clock),
                  label: Text('固定費'),
                ),
              ],
              selected: <CfoCostType>{_costType},
              onSelectionChanged: (selection) {
                setState(() => _costType = selection.single);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('yyyy/MM/dd').format(_incurredOn)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'メモ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('cfo_cost_add_button'),
                onPressed: _isSaving ? null : _addCostEntry,
                icon: const Icon(Icons.add),
                label: const Text('台帳に追加'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryList(List<CfoCostEntry> entries) {
    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('当月のコスト記録はまだありません。'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '当月の明細',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...entries.map(
          (entry) => Card(
            child: ListTile(
              leading: Icon(
                entry.costType == CfoCostType.fixed
                    ? Icons.lock_clock
                    : Icons.trending_up,
              ),
              title: Text(entry.item),
              subtitle: Text(
                '${_categories[entry.category] ?? entry.category} / ${entry.costType.label}'
                '${entry.note.isEmpty ? '' : '\n${entry.note}'}',
              ),
              trailing: Text(
                _yenFormat.format(entry.amountJpy),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
