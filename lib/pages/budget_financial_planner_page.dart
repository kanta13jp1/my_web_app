import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'asset_management_page.dart';
import '../models/budget_entry.dart';
import '../models/kgi_csf_kpi.dart';
import '../widgets/kgi_csf_kpi_panel.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 予算・財務プランナーページ (MoneyForward / Amazon Rufus 競合)
/// budget-financial-planner Edge Function + ai-assistant Edge Function と連携
/// - 月次予算設定・カテゴリ別支出管理
/// - AI節約アドバイス
/// - 将来シミュレーション
class BudgetFinancialPlannerPage extends StatefulWidget {
  const BudgetFinancialPlannerPage({super.key});

  @override
  State<BudgetFinancialPlannerPage> createState() =>
      _BudgetFinancialPlannerPageState();
}

class _BudgetFinancialPlannerPageState extends State<BudgetFinancialPlannerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  // タブ: 概要 / 予算 / AI節約 / シミュレーション
  @override
  List<String> get tabUrlSlugs => const <String>[
        'overview',
        'budget',
        'ai-savings',
        'simulation',
      ];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  bool _isLoading = false;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  // Budget data
  List<BudgetEntry> _budgets = [];
  List<BudgetEntry> _expenses = [];
  List<BudgetEntry> _incomes = [];

  // AI advice
  String? _aiAdvice;
  bool _isLoadingAi = false;

  // Simulation
  final _initialAmountCtrl = TextEditingController(text: '1000000');
  final _monthlyAddCtrl = TextEditingController(text: '30000');
  final _returnRateCtrl = TextEditingController(text: '5');
  final _yearsCtrl = TextEditingController(text: '20');
  double? _simResult;

  static const _categoryIcons = {
    'housing': Icons.home,
    'food': Icons.restaurant,
    'transportation': Icons.directions_car,
    'utilities': Icons.electrical_services,
    'insurance': Icons.security,
    'healthcare': Icons.local_hospital,
    'entertainment': Icons.movie,
    'education': Icons.school,
    'clothing': Icons.checkroom,
    'savings': Icons.savings,
    'investments': Icons.trending_up,
    'debt_repayment': Icons.credit_card,
    'subscriptions': Icons.subscriptions,
    'gifts': Icons.card_giftcard,
    'other': Icons.more_horiz,
  };

  static const _categoryLabels = {
    'housing': '住居費',
    'food': '食費',
    'transportation': '交通費',
    'utilities': '光熱費',
    'insurance': '保険',
    'healthcare': '医療',
    'entertainment': '娯楽',
    'education': '教育',
    'clothing': '衣類',
    'savings': '貯蓄',
    'investments': '投資',
    'debt_repayment': '返済',
    'subscriptions': 'サブスク',
    'gifts': 'ギフト',
    'other': 'その他',
  };

  final _fmt = NumberFormat('#,###', 'ja_JP');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _initialAmountCtrl.dispose();
    _monthlyAddCtrl.dispose();
    _returnRateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _supabase.functions.invoke(
          'social-commerce-hub',
          body: {'action': 'budget.summary', 'month': _selectedMonth},
        ),
        // 旧実装は無効 action 'get' (EF 400) で支出常に空だった。
        _supabase.functions.invoke(
          'social-commerce-hub',
          body: {
            'action': 'budget.expense_list',
            'month': _selectedMonth,
          },
        ),
        // 収入は budget.income_list (応答キーは単数 'income')。
        // 旧実装は budget.expense_list を叩き 'incomes' を読んでいた。
        _supabase.functions.invoke(
          'social-commerce-hub',
          body: {
            'action': 'budget.income_list',
            'month': _selectedMonth,
          },
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _budgets = BudgetEntry.listFromResponse(results[0].data, 'budgets');
        _expenses = BudgetEntry.listFromResponse(results[1].data, 'expenses');
        _incomes = BudgetEntry.listFromResponse(results[2].data, 'income');
      });
    } catch (e) {
      debugPrint('BudgetPage load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _totalIncome() => BudgetEntry.total(_incomes).toDouble();

  double _totalExpenses() => BudgetEntry.total(_expenses).toDouble();

  double _budgetForCategory(String cat) =>
      BudgetEntry.sumForCategory(_budgets, cat).toDouble();

  double _expenseForCategory(String cat) =>
      BudgetEntry.sumForCategory(_expenses, cat).toDouble();

  Future<void> _addBudget(String category, double amount) async {
    try {
      await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {
          'action': 'budget.set',
          'month': _selectedMonth,
          'category': category,
          'amount': amount,
        },
      );
      await _loadData();
    } catch (e) {
      debugPrint('Add budget error: $e');
    }
  }

  Future<void> _addExpense(
    String category,
    double amount,
    String description,
  ) async {
    try {
      await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {
          'action': 'budget.add_expense',
          'month': _selectedMonth,
          'category': category,
          'amount': amount,
          'description': description,
        },
      );
      await _loadData();
    } catch (e) {
      debugPrint('Add expense error: $e');
    }
  }

  Future<void> _addIncome(
    String type,
    double amount,
    String description,
  ) async {
    try {
      await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {
          'action': 'budget.add_income',
          'month': _selectedMonth,
          'type': type,
          'amount': amount,
          'description': description,
        },
      );
      await _loadData();
    } catch (e) {
      debugPrint('Add income error: $e');
    }
  }

  Future<void> _fetchAiAdvice() async {
    setState(() {
      _isLoadingAi = true;
      _aiAdvice = null;
    });
    try {
      final totalIncome = _totalIncome();
      final totalExpense = _totalExpenses();
      final balance = totalIncome - totalExpense;

      final breakdown = _categoryLabels.entries
          .map((e) {
            final spent = _expenseForCategory(e.key);
            if (spent <= 0) return null;
            return '${e.value}: ¥${_fmt.format(spent)}';
          })
          .whereType<String>()
          .join('\n');

      final prompt = '''
以下の$_selectedMonthの家計データを分析して、節約アドバイスを3点提案してください。

収入合計: ¥${_fmt.format(totalIncome)}
支出合計: ¥${_fmt.format(totalExpense)}
収支バランス: ¥${_fmt.format(balance)}

カテゴリ別支出:
$breakdown

具体的で実践的な節約提案を、優先順位をつけて3点だけ日本語で。各提案は2-3文で。
''';

      final response = await _supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'budget.chat', 'message': prompt},
      );
      final data = response.data;
      if (data is Map && data['reply'] != null) {
        if (mounted) setState(() => _aiAdvice = data['reply'] as String);
      }
    } catch (e) {
      if (mounted) setState(() => _aiAdvice = 'AI分析中にエラーが発生しました: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  void _runSimulation() {
    final principal = double.tryParse(_initialAmountCtrl.text) ?? 0;
    final monthly = double.tryParse(_monthlyAddCtrl.text) ?? 0;
    final rate = (double.tryParse(_returnRateCtrl.text) ?? 0) / 100 / 12;
    final months = (int.tryParse(_yearsCtrl.text) ?? 0) * 12;

    if (months == 0) {
      setState(() => _simResult = principal);
      return;
    }

    // Compound interest with monthly additions
    double result = principal;
    for (int i = 0; i < months; i++) {
      result = result * (1 + rate) + monthly;
    }
    setState(() => _simResult = result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('予算・財務プランナー'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: '概要'),
            Tab(icon: Icon(Icons.pie_chart), text: '予算'),
            Tab(icon: Icon(Icons.psychology), text: 'AI節約'),
            Tab(icon: Icon(Icons.show_chart), text: 'シミュレーション'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: '資産管理へ',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/asset-management'),
                  builder: (_) => const AssetManagementPage(
                    initialFocus: AssetManagementInitialFocus.flow,
                    emphasizeMonthlyFlow: true,
                    entryLabel: '予算・財務プランナー',
                    entryDescription:
                        '日々の予算管理と収支の判断は資産管理に統合しました。資産残高、固定費、借金ロックダウン、浪費抑制AIまで一つの画面で確認できます。',
                  ),
                ),
              );
            },
          ),
          // Month picker
          TextButton.icon(
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(_selectedMonth),
            onPressed: _pickMonth,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(cs),
                _buildBudgetTab(cs),
                _buildAiAdviceTab(cs),
                _buildSimulationTab(cs),
              ],
            ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () => _showAddDialog(),
      icon: const Icon(Icons.add),
      label: const Text('記録追加'),
    );
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse('$_selectedMonth-01') ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      helpText: '月を選択',
    );
    if (picked != null && mounted) {
      setState(() => _selectedMonth = DateFormat('yyyy-MM').format(picked));
      _loadData();
    }
  }

  // --- Overview Tab ---
  Widget _buildOverviewTab(ColorScheme cs) {
    final income = _totalIncome();
    final expense = _totalExpenses();
    final balance = income - expense;
    final savingsRate = income > 0 ? (balance / income * 100) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KgiCsfKpiPanel(
            plan: _buildBudgetKgiPlan(
              income: income,
              expense: expense,
              balance: balance,
              savingsRate: savingsRate,
            ),
            accentColor: cs.primary,
            initiallyExpanded: true,
          ),
          const SizedBox(height: 12),
          // KPI cards
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  '収入',
                  income,
                  cs.primaryContainer,
                  cs.onPrimaryContainer,
                  Icons.arrow_upward,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiCard(
                  '支出',
                  expense,
                  cs.errorContainer,
                  cs.onErrorContainer,
                  Icons.arrow_downward,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  '収支',
                  balance,
                  balance >= 0 ? cs.secondaryContainer : cs.errorContainer,
                  balance >= 0 ? cs.onSecondaryContainer : cs.onErrorContainer,
                  balance >= 0
                      ? Icons.account_balance_wallet
                      : Icons.warning_amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiCard(
                  '貯蓄率',
                  savingsRate,
                  cs.tertiaryContainer,
                  cs.onTertiaryContainer,
                  Icons.savings,
                  isPercent: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Top expenses
          if (_expenses.isNotEmpty) ...[
            Text(
              '支出トップ5',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._topExpenses().map(
              (e) => _expenseRow(
                e['category'] as String,
                e['total'] as double,
                expense,
                cs,
              ),
            ),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 64,
                      color: cs.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_selectedMonth のデータがありません',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('支出・収入を記録'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  KgiCsfKpiPlan _buildBudgetKgiPlan({
    required double income,
    required double expense,
    required double balance,
    required double savingsRate,
  }) {
    final spendingTarget = income <= 0 ? 0.0 : income * 0.8;
    final positiveBalance = balance > 0 ? balance : 0.0;
    final savingsProgress = savingsRate <= 0 ? 0.0 : savingsRate / 20;
    return KgiCsfKpiPlan(
      domain: '月次家計',
      kgi: '月次収支を黒字化し、貯蓄率20%を維持する',
      actualLabel:
          '収支 ${_formatBudgetAmount(balance)} / 貯蓄率 ${savingsRate.toStringAsFixed(1)}%',
      targetLabel: '黒字 / 20%',
      progress: savingsProgress.clamp(0, 1).toDouble(),
      metrics: <KgiCsfKpiMetric>[
        KgiCsfKpiMetric.number(
          csf: '収入安定化',
          kpi: '月次収入',
          actual: income,
          target: expense > 0 ? expense : 1,
          unit: '円',
        ),
        KgiCsfKpiMetric(
          csf: '支出統制',
          kpi: '支出を収入の80%以内に抑える',
          actualLabel: _formatBudgetAmount(expense),
          targetLabel: _formatBudgetAmount(spendingTarget),
          progress: expense <= 0 || spendingTarget <= 0
              ? 0
              : spendingTarget / expense,
          remainingLabel: spendingTarget >= expense
              ? '達成'
              : '超過 ${_formatBudgetAmount(expense - spendingTarget)}',
        ),
        KgiCsfKpiMetric.number(
          csf: '余剰資金創出',
          kpi: '黒字額',
          actual: positiveBalance,
          target: income <= 0 ? 1 : income * 0.2,
          unit: '円',
        ),
      ],
    );
  }

  String _formatBudgetAmount(double value) {
    final prefix = value < 0 ? '-¥' : '¥';
    return '$prefix${_fmt.format(value.abs())}';
  }

  Widget _kpiCard(
    String label,
    double value,
    Color bgColor,
    Color textColor,
    IconData icon, {
    bool isPercent = false,
  }) {
    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: textColor, size: 18),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isPercent
                  ? '${value.toStringAsFixed(1)}%'
                  : '¥${_fmt.format(value.abs())}',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _topExpenses() {
    final map = <String, double>{};
    for (final e in _expenses) {
      final cat = e.category.isNotEmpty ? e.category : 'other';
      map[cat] = (map[cat] ?? 0) + e.amount.toDouble();
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(5)
        .map((e) => {'category': e.key, 'total': e.value})
        .toList();
  }

  Widget _expenseRow(
    String category,
    double amount,
    double total,
    ColorScheme cs,
  ) {
    final ratio = total > 0 ? amount / total : 0.0;
    final label = _categoryLabels[category] ?? category;
    final icon = _categoryIcons[category] ?? Icons.more_horiz;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.7,
                      ),
                    ),
                    Text(
                      '¥${_fmt.format(amount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  backgroundColor: cs.surfaceContainerHigh,
                  color: ratio > 0.8 ? cs.error : cs.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Budget Tab ---
  Widget _buildBudgetTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '$_selectedMonth カテゴリ別予算',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ..._categoryLabels.entries.map((entry) {
          final budget = _budgetForCategory(entry.key);
          final spent = _expenseForCategory(entry.key);
          final ratio = budget > 0 ? spent / budget : 0.0;
          final over = spent > budget && budget > 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _categoryIcons[entry.key] ?? Icons.more_horiz,
                        size: 18,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (over)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '超過',
                            style: TextStyle(
                              color: cs.onErrorContainer,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () =>
                            _showSetBudgetDialog(entry.key, entry.value),
                        child: Text(
                          budget > 0 ? '¥${_fmt.format(budget)}' : '予算設定',
                          style: TextStyle(
                            fontSize: 12,
                            color: budget > 0 ? cs.onSurface : cs.primary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          backgroundColor: cs.surfaceContainerHigh,
                          color: over
                              ? cs.error
                              : ratio > 0.7
                                  ? cs.tertiary
                                  : cs.primary,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '¥${_fmt.format(spent)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: over ? cs.error : cs.onSurfaceVariant,
                          fontWeight: over ? FontWeight.bold : null,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- AI Advice Tab ---
  Widget _buildAiAdviceTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'AI節約アドバイス',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_selectedMonth の支出データをAIが分析し、節約提案を生成します。',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _expenses.isEmpty ? null : _fetchAiAdvice,
                    icon: _isLoadingAi
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_isLoadingAi ? '分析中...' : 'AI節約分析を実行'),
                  ),
                  if (_expenses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '支出データを記録してから実行してください',
                        style: TextStyle(
                          color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_aiAdvice != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: cs.tertiary),
                        const SizedBox(width: 8),
                        Text(
                          'AIからの提案',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                            height: 1.5,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _aiAdvice!));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('コピーしました')),
                              );
                            }
                          },
                          tooltip: 'コピー',
                        ),
                      ],
                    ),
                    const Divider(),
                    Text(_aiAdvice!, style: const TextStyle(height: 1.7)),
                  ],
                ),
              ),
            ),
          // Monthly summary for AI context
          if (_expenses.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('分析対象データ', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _summaryRow('収入合計', _totalIncome(), cs),
                    _summaryRow('支出合計', _totalExpenses(), cs),
                    _summaryRow(
                      '収支バランス',
                      _totalIncome() - _totalExpenses(),
                      cs,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          Text(
            '¥${_fmt.format(value.abs())}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: value < 0 ? cs.error : cs.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- Simulation Tab ---
  Widget _buildSimulationTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.show_chart, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        '資産形成シミュレーション',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: cs.onSurface,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '複利計算で将来の資産額を試算します',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _simField('初期資産額 (円)', _initialAmountCtrl, prefixText: '¥'),
                  const SizedBox(height: 12),
                  _simField('月々の積立額 (円)', _monthlyAddCtrl, prefixText: '¥'),
                  const SizedBox(height: 12),
                  _simField('年利回り (%)', _returnRateCtrl, suffixText: '%'),
                  const SizedBox(height: 12),
                  _simField('運用期間 (年)', _yearsCtrl, suffixText: '年'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _runSimulation,
                    icon: const Icon(Icons.calculate),
                    label: const Text('シミュレーション実行'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_simResult != null) ...[
            const SizedBox(height: 16),
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      '${_yearsCtrl.text}年後の資産額',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¥${_fmt.format(_simResult!.round())}',
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: cs.outline),
                    const SizedBox(height: 8),
                    _simDetailRow(
                      '元本合計',
                      (double.tryParse(_initialAmountCtrl.text) ?? 0) +
                          (double.tryParse(_monthlyAddCtrl.text) ?? 0) *
                              (int.tryParse(_yearsCtrl.text) ?? 0) *
                              12,
                      cs,
                    ),
                    _simDetailRow(
                      '利息分',
                      _simResult! -
                          ((double.tryParse(_initialAmountCtrl.text) ?? 0) +
                              (double.tryParse(_monthlyAddCtrl.text) ?? 0) *
                                  (int.tryParse(_yearsCtrl.text) ?? 0) *
                                  12),
                      cs,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '※ シミュレーションは参考値です。実際の運用成績は異なります。',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _simField(
    String label,
    TextEditingController ctrl, {
    String? prefixText,
    String? suffixText,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        suffixText: suffixText,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _simDetailRow(String label, double value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          Text(
            '¥${_fmt.format(value.round().abs())}',
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- Dialogs ---
  Future<void> _showAddDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddRecordSheet(
        onAddExpense: _addExpense,
        onAddIncome: _addIncome,
      ),
    );
    await _loadData();
  }

  Future<void> _showSetBudgetDialog(String category, String label) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label の予算設定'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '月額予算 (円)',
            prefixText: '¥',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(ctrl.text);
              if (amount != null && amount > 0) {
                Navigator.of(ctx).pop();
                _addBudget(category, amount);
              }
            },
            child: const Text('設定'),
          ),
        ],
      ),
    );
  }
}

/// 支出・収入追加ボトムシート
class _AddRecordSheet extends StatefulWidget {
  const _AddRecordSheet({
    required this.onAddExpense,
    required this.onAddIncome,
  });

  final Future<void> Function(String, double, String) onAddExpense;
  final Future<void> Function(String, double, String) onAddIncome;

  @override
  State<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<_AddRecordSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _category = 'food';
  String _incomeType = 'salary';
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isSaving = false;

  static const _categories = {
    'food': '食費',
    'housing': '住居費',
    'transportation': '交通費',
    'utilities': '光熱費',
    'entertainment': '娯楽',
    'healthcare': '医療',
    'subscriptions': 'サブスク',
    'clothing': '衣類',
    'other': 'その他',
  };

  static const _incomeTypes = {
    'salary': '給与',
    'bonus': 'ボーナス',
    'freelance': 'フリーランス',
    'investment': '投資',
    'rental': '家賃収入',
    'other': 'その他',
  };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;
    setState(() => _isSaving = true);
    if (_tab.index == 0) {
      await widget.onAddExpense(_category, amount, _descCtrl.text);
    } else {
      await widget.onAddIncome(_incomeType, amount, _descCtrl.text);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _tab,
            tabs: const [
              Tab(icon: Icon(Icons.remove_circle_outline), text: '支出'),
              Tab(icon: Icon(Icons.add_circle_outline), text: '収入'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Category dropdown
                DropdownButtonFormField<String>(
                  initialValue: _tab.index == 0 ? _category : _incomeType,
                  decoration: InputDecoration(
                    labelText: _tab.index == 0 ? 'カテゴリ' : '収入種別',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: (_tab.index == 0 ? _categories : _incomeTypes)
                      .entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      if (_tab.index == 0) {
                        _category = v;
                      } else {
                        _incomeType = v;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '金額 (円)',
                    prefixText: '¥',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'メモ (任意)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
