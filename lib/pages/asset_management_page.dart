import 'dart:async';
import 'dart:math'; // ← ★この1行を追加してください！
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:my_web_app/models/debt_repayment_plan.dart';
import 'package:my_web_app/services/debt_repayment_planner_service.dart';

class AssetManagementPage extends StatefulWidget {
  const AssetManagementPage({super.key});

  @override
  State<AssetManagementPage> createState() => _AssetManagementPageState();
}

class _AssetManagementPageState extends State<AssetManagementPage> {
  final _supabase = Supabase.instance.client;

  // --- 今日18:00締切のためのチェックリスト ---
  final ScrollController _scrollController = ScrollController();
  final _keyStock = GlobalKey();
  final _keyFlow = GlobalKey();
  final _keySubs = GlobalKey();
  final _keyMust = GlobalKey();

  Timer? _deadlineTimer;
  DateTime _now = DateTime.now();

  // Supabaseに保存する「今日の締め」状態
  bool _assetsDone = false;
  bool _liabilitiesDone = false;
  bool _fixedCostsDone = false;
  bool _flowsDone = false;
  bool _mustTasksDone = false;
  bool _isLoadingClosing = false;

  // --- 資産・負債（ストック）用変数 ---
  Map<String, TextEditingController> _controllers = {};
  List<String> _assetTypes = ['現金'];
  Map<String, Map<String, double>> _assetData = {};
  Map<String, Map<String, double>> _effectiveAssetDataByDate = {};
  Map<String, String?> _lastUpdatedDates = {};

  // --- グラフデータ ---
  List<LineChartBarData> _lineChartBars = [];
  List<BarChartGroupData> _barChartGroups = [];
  double _maxDailyChange = 0;
  List<String> _sortedDates = [];
  bool _isStacked = true;
  bool _showDailyChange = false;

  // --- 収支（フロー）記録用変数 ---
  DateTime _selectedFlowDate = DateTime.now();
  DateTime _selectedFlowHistoryMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  String _selectedSource = '[三井住友銀行大塚支店]';
  String _selectedFlowType = '支出'; // 収入 or 支出
  final List<String> _sourceOptions = [
    '[三井住友銀行大塚支店]',
    '[PayPayカード]',
    '[auPayカード]',
    '[auかんたん決済]',
    '[アコムショッピング]',
    '[横浜銀行]',
    '[現金]',
    '[その他]',
  ];
  final TextEditingController _flowMemoController = TextEditingController();
  final TextEditingController _flowAmountController = TextEditingController();
  List<Map<String, dynamic>> _recentFlows = []; // 収支履歴

  // --- サブスク（固定費）用変数 ---
  DateTime _selectedSubscriptionHistoryMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _subscriptionsThreeMonths = [];
  bool _isLoadingSubscriptions = false;

  // --- 必須タスク用変数 ---
  List<Map<String, dynamic>> _mustTasks = [];
  bool _isLoadingTasks = false;

  // --- 返済計画用 ---
  final DebtRepaymentPlannerService _debtRepaymentPlanner =
      const DebtRepaymentPlannerService();
  bool _isGeneratingDebtPlan = false;
  String? _debtPlanMarkdown;
  DateTime? _debtPlanGeneratedAt;

  final List<Color> _colors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.brown,
  ];

  static const double _compactWidthBreakpoint = 420;
  bool get _isCompact =>
      MediaQuery.sizeOf(context).width < _compactWidthBreakpoint;

  @override
  void initState() {
    super.initState();
    _loadDataFromSupabase();
    _fetchRecentFlows();
    _fetchSubscriptions();
    _fetchMustTasks();
    _deadlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _fetchTodayClosing();
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    _flowMemoController.dispose();
    _flowAmountController.dispose();
    _deadlineTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _paymentSourceCandidates() {
    // _assetTypes の順序を維持しつつ重複排除
    final ordered = <String>[];

    void add(String s) {
      final t = s.trim();
      if (t.isEmpty) return;
      if (!ordered.contains(t)) ordered.add(t);
    }

    for (final t in _assetTypes) {
      add(t);
    }

    // 先頭に「未設定」、末尾に「その他」
    return ['（未設定）', ...ordered, 'その他'];
  }

  String _dateOnly(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _todayDateKey() => _dateOnly(DateTime.now());

  String _yesterdayDateKey() =>
      _dateOnly(DateTime.now().subtract(const Duration(days: 1)));

  DateTime _monthStart(DateTime dt) => DateTime(dt.year, dt.month, 1);

  bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  String _monthKey(DateTime monthStart) =>
      DateFormat('yyyy-MM').format(_monthStart(monthStart));

  String _flowMonthLabel(DateTime month) =>
      DateFormat('yyyy/MM').format(_monthStart(month));

  List<Map<String, dynamic>> _flowsForMonth(DateTime month) {
    final target = _monthStart(month);
    return _recentFlows.where((flow) {
      final occurredAtRaw = flow['occurred_at']?.toString();
      if (occurredAtRaw == null || occurredAtRaw.isEmpty) {
        return false;
      }
      final occurredAt = DateTime.tryParse(occurredAtRaw)?.toLocal();
      if (occurredAt == null) {
        return false;
      }
      return occurredAt.year == target.year && occurredAt.month == target.month;
    }).toList();
  }

  Future<void> _pickFlowHistoryMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedFlowHistoryMonth,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: '表示する月を選択',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedFlowHistoryMonth = _monthStart(picked);
    });
  }

  void _shiftFlowHistoryMonth(int delta) {
    final currentMonth = _monthStart(DateTime.now());
    final next = DateTime(
      _selectedFlowHistoryMonth.year,
      _selectedFlowHistoryMonth.month + delta,
      1,
    );
    if (next.isAfter(currentMonth)) {
      return;
    }
    setState(() {
      _selectedFlowHistoryMonth = _monthStart(next);
    });
  }

  List<Map<String, dynamic>> _subscriptionsForMonth(DateTime month) {
    final target = _monthStart(month);
    return _subscriptionsThreeMonths.where((subscription) {
      final dueDateRaw = subscription['due_date']?.toString();
      if (dueDateRaw == null || dueDateRaw.isEmpty) {
        return false;
      }
      final dueDate = DateTime.tryParse(dueDateRaw);
      if (dueDate == null) {
        return false;
      }
      return dueDate.year == target.year && dueDate.month == target.month;
    }).toList();
  }

  Future<void> _pickSubscriptionHistoryMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedSubscriptionHistoryMonth,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: '固定費の表示月を選択',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedSubscriptionHistoryMonth = _monthStart(picked);
    });
  }

  void _shiftSubscriptionHistoryMonth(int delta) {
    final next = DateTime(
      _selectedSubscriptionHistoryMonth.year,
      _selectedSubscriptionHistoryMonth.month + delta,
      1,
    );
    final minMonth = DateTime(2020, 1, 1);
    final maxMonth = DateTime(DateTime.now().year + 5, 12, 1);
    if (next.isBefore(minMonth) || next.isAfter(maxMonth)) {
      return;
    }
    setState(() {
      _selectedSubscriptionHistoryMonth = _monthStart(next);
    });
  }

  List<DateTime> _overviewMonthStarts() {
    final current = _monthStart(DateTime.now());
    return [
      DateTime(current.year, current.month - 1, 1),
      current,
      DateTime(current.year, current.month + 1, 1),
    ];
  }

  String _monthLabelWithRole(DateTime monthStart) {
    final current = _monthStart(DateTime.now());
    final prev = DateTime(current.year, current.month - 1, 1);
    final next = DateTime(current.year, current.month + 1, 1);
    final monthLabel = DateFormat('yyyy/MM').format(monthStart);

    if (_isSameMonth(monthStart, prev)) return '先月 ($monthLabel)';
    if (_isSameMonth(monthStart, current)) return '今月 ($monthLabel)';
    if (_isSameMonth(monthStart, next)) return '来月 ($monthLabel)';
    return monthLabel;
  }

  String _formatYen(num value) =>
      '¥${NumberFormat('#,###').format(value.round())}';

  String _formatSignedYen(num value) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign¥${NumberFormat('#,###').format(value.abs().round())}';
  }

  Map<String, double?> _netWorthByOverviewMonth(List<DateTime> months) {
    final result = <String, double?>{
      for (final month in months) _monthKey(month): null,
    };
    if (_sortedDates.isEmpty) return result;

    for (final month in months) {
      final monthEnd = DateTime(month.year, month.month + 1, 0);
      final monthEndKey = DateFormat('yyyy-MM-dd').format(monthEnd);
      String? latestDateKey;

      for (final dateKey in _sortedDates) {
        if (dateKey.compareTo(monthEndKey) <= 0) {
          latestDateKey = dateKey;
        } else {
          break;
        }
      }

      if (latestDateKey == null) continue;
      final snapshot = _effectiveAssetDataByDate[latestDateKey] ??
          _assetData[latestDateKey] ??
          {};
      double total = 0;
      snapshot.forEach((_, value) => total += value);
      result[_monthKey(month)] = total;
    }

    return result;
  }

  Map<String, int> _fixedCostByOverviewMonth(List<DateTime> months) {
    final totals = <String, int>{
      for (final month in months) _monthKey(month): 0,
    };

    for (final sub in _subscriptionsThreeMonths) {
      final dueStr = sub['due_date']?.toString();
      if (dueStr == null || dueStr.isEmpty) continue;
      final dueDate = DateTime.tryParse(dueStr);
      if (dueDate == null) continue;
      final key = _monthKey(DateTime(dueDate.year, dueDate.month, 1));
      if (!totals.containsKey(key)) continue;
      totals[key] = (totals[key] ?? 0) + ((sub['price'] as num?)?.toInt() ?? 0);
    }

    return totals;
  }

  Map<String, Map<String, int>> _taskStatsByOverviewMonth(
    List<DateTime> months,
  ) {
    final stats = <String, Map<String, int>>{
      for (final month in months)
        _monthKey(month): {
          'total': 0,
          'completed': 0,
          'pending': 0,
        },
    };

    for (final task in _mustTasks) {
      final deadlineStr = task['deadline']?.toString();
      if (deadlineStr == null || deadlineStr.isEmpty) continue;
      final deadline = DateTime.tryParse(deadlineStr)?.toLocal();
      if (deadline == null) continue;

      final key = _monthKey(DateTime(deadline.year, deadline.month, 1));
      final bucket = stats[key];
      if (bucket == null) continue;

      bucket['total'] = (bucket['total'] ?? 0) + 1;
      final isCompleted = (task['is_completed'] as bool?) == true;
      if (isCompleted) {
        bucket['completed'] = (bucket['completed'] ?? 0) + 1;
      } else {
        bucket['pending'] = (bucket['pending'] ?? 0) + 1;
      }
    }

    return stats;
  }

  void _ensureEffectiveSnapshotsReady() {
    if (_effectiveAssetDataByDate.isEmpty && _assetData.isNotEmpty) {
      _updateChartData();
    }
  }

  Map<String, double> _latestSnapshotForPlanning() {
    _ensureEffectiveSnapshotsReady();
    if (_sortedDates.isEmpty) return {};

    final latestDate = _sortedDates.last;
    final snapshot = _effectiveAssetDataByDate[latestDate] ??
        _assetData[latestDate] ??
        const <String, double>{};
    return Map<String, double>.from(snapshot);
  }

  List<Map<String, dynamic>> _liabilitiesFromSnapshot(
    Map<String, double> snapshot,
  ) {
    final liabilities = snapshot.entries
        .where((e) => e.value < 0)
        .map(
          (e) => <String, dynamic>{
            'name': e.key,
            'balance': e.value.abs(),
          },
        )
        .toList();

    liabilities.sort(
      (a, b) => (b['balance'] as double).compareTo(a['balance'] as double),
    );
    return liabilities;
  }

  Future<void> _showDebtPlanDialog() async {
    final monthlyBudgetController = TextEditingController();
    final extraBudgetController = TextEditingController(text: '0');
    final targetMonthsController = TextEditingController(text: '12');
    final memoController = TextEditingController();
    String strategyKey = DebtRepaymentStrategy.snowball.name;

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('借金返済プラン作成'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: strategyKey,
                    decoration: const InputDecoration(
                      labelText: '返済方針',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'snowball',
                        child: Text('少額優先（スノーボール）'),
                      ),
                      DropdownMenuItem(
                        value: 'avalanche',
                        child: Text('高金利優先（アバランチ）'),
                      ),
                      DropdownMenuItem(
                        value: 'hybrid',
                        child: Text('ハイブリッド（高金利×少額）'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() => strategyKey = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: monthlyBudgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '毎月の返済予算（円）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: extraBudgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '臨時返済予算（円）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: targetMonthsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '目標完済期間（月）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: memoController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '補足（任意）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('作成'),
              ),
            ],
          ),
        ),
      );

      if (ok != true) return;

      final monthlyBudget = int.tryParse(
            monthlyBudgetController.text.replaceAll(',', '').trim(),
          ) ??
          0;
      final extraBudget =
          int.tryParse(extraBudgetController.text.replaceAll(',', '').trim()) ??
              0;
      final targetMonths = int.tryParse(
            targetMonthsController.text.replaceAll(',', '').trim(),
          ) ??
          12;
      final userMemo = memoController.text.trim();

      if (monthlyBudget <= 0 || targetMonths <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('返済予算と目標期間を正しく入力してください')),
        );
        return;
      }

      await _generateDebtRepaymentPlan(
        strategyKey: strategyKey,
        monthlyBudget: monthlyBudget,
        extraBudget: extraBudget,
        targetMonths: targetMonths,
        userMemo: userMemo,
      );
    } finally {
      monthlyBudgetController.dispose();
      extraBudgetController.dispose();
      targetMonthsController.dispose();
      memoController.dispose();
    }
  }

  DebtRepaymentStrategy _strategyFromKey(String strategyKey) {
    for (final strategy in DebtRepaymentStrategy.values) {
      if (strategy.name == strategyKey) return strategy;
    }
    return DebtRepaymentStrategy.snowball;
  }

  Future<void> _generateDebtRepaymentPlan({
    required String strategyKey,
    required int monthlyBudget,
    required int extraBudget,
    required int targetMonths,
    required String userMemo,
  }) async {
    final snapshot = _latestSnapshotForPlanning();
    final liabilities = _liabilitiesFromSnapshot(snapshot);
    if (liabilities.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('負債データがありません。まず負債を記録してください。')),
      );
      return;
    }

    final currentMonthFlows = _flowsForMonth(DateTime.now());
    int monthlyIncome = 0;
    int monthlyExpense = 0;
    for (final f in currentMonthFlows) {
      final amt = (f['amount'] as num?)?.toInt() ?? 0;
      if (f['action_type'] == 'conquer') monthlyIncome += amt;
      if (f['action_type'] == 'expense') monthlyExpense += amt;
    }

    final currentFixedCost = _subscriptions.fold<int>(
      0,
      (sum, s) => sum + ((s['price'] as num?)?.toInt() ?? 0),
    );
    final netWorth = snapshot.values.fold<double>(0, (sum, v) => sum + v);
    final strategy = _strategyFromKey(strategyKey);
    final inputDebts = liabilities
        .map((l) {
          final name = l['name']?.toString() ?? '';
          final balance = (l['balance'] as num?)?.toDouble() ?? 0;
          return _debtRepaymentPlanner.normalizeDebt(
            name: name,
            balance: balance,
          );
        })
        .where((d) => d.name.isNotEmpty && d.balance > 0)
        .toList();

    if (inputDebts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('返済対象の負債データを作成できませんでした')),
      );
      return;
    }

    final input = DebtRepaymentPlanInput(
      debts: inputDebts,
      strategy: strategy,
      monthlyBudget: monthlyBudget,
      extraBudget: extraBudget,
      targetMonths: targetMonths,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      fixedCost: currentFixedCost,
      netWorth: netWorth,
      note: userMemo,
      baseMonth: _monthStart(DateTime.now()),
    );

    setState(() => _isGeneratingDebtPlan = true);
    try {
      final result = _debtRepaymentPlanner.generatePlan(input: input);

      if (!mounted) return;
      setState(() {
        _debtPlanMarkdown = result.markdown;
        _debtPlanGeneratedAt = DateTime.now();
      });
      final warningCount = result.warnings.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            warningCount == 0
                ? '返済計画を作成しました'
                : '返済計画を作成しました（注意点 $warningCount 件）',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('返済計画の作成に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingDebtPlan = false);
      }
    }
  }

  DateTime _deadlineToday() => DateTime(_now.year, _now.month, _now.day, 18, 0);

  String _remainingToDeadlineText() {
    final diff = _deadlineToday().difference(_now);
    if (diff.isNegative) return '⚠️ 締切(18:00)を過ぎています';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    return '締切まで ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double _progress() {
    int done = 0;
    if (_assetsDone) done++;
    if (_liabilitiesDone) done++;
    if (_fixedCostsDone) done++;
    if (_flowsDone) done++;
    if (_mustTasksDone) done++;
    return done / 5.0;
  }

  Future<void> _fetchTodayClosing() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoadingClosing = true);
    final todayStr = _dateOnly(DateTime.now());

    try {
      final rows = await _supabase
          .from('cfo_daily_closings')
          .select()
          .eq('user_id', userId)
          .eq('date', todayStr)
          .limit(1);

      if (!mounted) return;

      if (rows.isNotEmpty) {
        final r = rows.first;
        setState(() {
          _assetsDone = r['assets_done'] == true;
          _liabilitiesDone = r['liabilities_done'] == true;
          _fixedCostsDone = r['fixed_costs_done'] == true;
          _flowsDone = r['flows_done'] == true;
          _mustTasksDone = r['must_tasks_done'] == true;
          _isLoadingClosing = false;
        });
      } else {
        setState(() {
          _assetsDone = false;
          _liabilitiesDone = false;
          _fixedCostsDone = false;
          _flowsDone = false;
          _mustTasksDone = false;
          _isLoadingClosing = false;
        });
      }
    } catch (e) {
      debugPrint('fetch closing error: $e');
      if (!mounted) return;
      setState(() => _isLoadingClosing = false);
    }
  }

  Future<void> _upsertTodayClosing() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final todayStr = _dateOnly(DateTime.now());

    try {
      await _supabase.from('cfo_daily_closings').upsert(
        {
          'user_id': userId,
          'date': todayStr,
          'assets_done': _assetsDone,
          'liabilities_done': _liabilitiesDone,
          'fixed_costs_done': _fixedCostsDone,
          'flows_done': _flowsDone,
          'must_tasks_done': _mustTasksDone,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,date',
      );
    } catch (e) {
      debugPrint('upsert closing error: $e');
    }
  }

  Future<void> _toggleClosing(String key, bool value) async {
    setState(() {
      switch (key) {
        case 'assets':
          _assetsDone = value;
          break;
        case 'liabilities':
          _liabilitiesDone = value;
          break;
        case 'fixed':
          _fixedCostsDone = value;
          break;
        case 'flows':
          _flowsDone = value;
          break;
        case 'must':
          _mustTasksDone = value;
          break;
      }
    });
    await _upsertTodayClosing();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  Future<void> _autoCheckFromData() async {
    final todayStr = _dateOnly(DateTime.now());

    // NOTE: Closing checks intentionally use raw inputs recorded today.
    // Do not use display-complemented values here.
    final todayStock = _assetData[todayStr] ?? {};
    final allTypesFilledToday = _assetTypes.isNotEmpty &&
        _assetTypes.every((t) => todayStock.containsKey(t));

    final hasAnyPositive = todayStock.values.any((v) => v >= 0);
    final hasAnyNegative = todayStock.values.any((v) => v < 0);

    final subsOk = _subscriptions.isNotEmpty;

    final currentMonthFlows = _flowsForMonth(DateTime.now());
    final incomeCount =
        currentMonthFlows.where((r) => r['action_type'] == 'conquer').length;
    final expenseCount =
        currentMonthFlows.where((r) => r['action_type'] == 'expense').length;
    final flowsOk = (incomeCount + expenseCount) > 0;

    final now = DateTime.now();
    final mustThisMonth = _mustTasks.where((t) {
      final d = DateTime.parse(t['deadline']).toLocal();
      return d.year == now.year && d.month == now.month;
    }).toList();
    final mustOk = mustThisMonth.isNotEmpty;

    setState(() {
      if (allTypesFilledToday && hasAnyPositive) _assetsDone = true;
      if (allTypesFilledToday && hasAnyNegative) _liabilitiesDone = true;
      if (subsOk) _fixedCostsDone = true;
      if (flowsOk) _flowsDone = true;
      if (mustOk) _mustTasksDone = true;
    });

    await _upsertTodayClosing();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('自動チェックを反映しました（不足があれば手動でONできます）')),
    );
  }

  Future<void> _copyDailySummary() async {
    if (_effectiveAssetDataByDate.isEmpty) {
      _updateChartData();
    }

    final now = DateTime.now();
    final todayStr = _dateOnly(now);

    String? snapshotDate;
    if (_assetData.containsKey(todayStr)) {
      snapshotDate = todayStr;
    } else if (_sortedDates.isNotEmpty) {
      snapshotDate = _sortedDates.last;
    }

    double totalAssets = 0;
    double totalLiabilities = 0;

    final Map<String, double> snap = snapshotDate != null
        ? Map<String, double>.from(
            _effectiveAssetDataByDate[snapshotDate] ??
                _assetData[snapshotDate] ??
                const <String, double>{},
          )
        : <String, double>{};
    snap.forEach((_, v) {
      if (v >= 0) totalAssets += v;
      if (v < 0) totalLiabilities += v;
    });

    int totalFixed = 0;
    for (final s in _subscriptions) {
      totalFixed += (s['price'] as num?)?.toInt() ?? 0;
    }

    final currentMonthFlows = _flowsForMonth(now);
    int totalIncome = 0;
    int totalExpense = 0;
    for (final f in currentMonthFlows) {
      final amt = (f['amount'] as num?)?.toInt() ?? 0;
      if (f['action_type'] == 'conquer') totalIncome += amt;
      if (f['action_type'] == 'expense') totalExpense += amt;
    }

    final monthLabel = '${now.year}/${now.month.toString().padLeft(2, '0')}';
    final mustThisMonth = _mustTasks.where((t) {
      final d = DateTime.parse(t['deadline']).toLocal();
      return d.year == now.year && d.month == now.month;
    }).toList()
      ..sort(
        (a, b) => (a['deadline'] as String).compareTo(b['deadline'] as String),
      );

    final done = [
      _assetsDone,
      _liabilitiesDone,
      _fixedCostsDone,
      _flowsDone,
      _mustTasksDone,
    ].where((x) => x).length;

    final buf = StringBuffer();
    buf.writeln('## 本日18:00 CFO締め（$todayStr）');
    buf.writeln('- 進捗: **$done/5 完了**');
    buf.writeln('- ①資産: ${_assetsDone ? "✅" : "⬜️"}');
    buf.writeln('- ②負債: ${_liabilitiesDone ? "✅" : "⬜️"}');
    buf.writeln('- ③固定費: ${_fixedCostsDone ? "✅" : "⬜️"}');
    buf.writeln('- ④収支: ${_flowsDone ? "✅" : "⬜️"}');
    buf.writeln('- ⑤必須タスク: ${_mustTasksDone ? "✅" : "⬜️"}');
    buf.writeln('');

    buf.writeln('### ①② ストック（スナップショット: ${snapshotDate ?? "未記録"}）');
    buf.writeln('- 総資産: ¥${NumberFormat('#,###').format(totalAssets)}');
    buf.writeln('- 総負債: ¥${NumberFormat('#,###').format(totalLiabilities)}');
    buf.writeln(
      '- 純資産: ¥${NumberFormat('#,###').format(totalAssets + totalLiabilities)}',
    );
    if (snap.isNotEmpty) {
      buf.writeln('- 内訳:');
      final entries = snap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in entries) {
        buf.writeln('  - ${e.key}: ¥${NumberFormat('#,###').format(e.value)}');
      }
    }
    buf.writeln('');

    buf.writeln('### ③ 固定費（$monthLabel）');
    buf.writeln('- 月額合計: ¥${NumberFormat('#,###').format(totalFixed)}');
    if (_subscriptions.isNotEmpty) {
      for (final s in _subscriptions) {
        buf.writeln(
          '  - ${s["service_name"]}: ¥${NumberFormat('#,###').format(s["price"])}',
        );
      }
    } else {
      buf.writeln('  - （未登録）');
    }
    buf.writeln('');

    buf.writeln('### ④ 収支（$monthLabel）');
    buf.writeln('- 収入合計: ¥${NumberFormat('#,###').format(totalIncome)}');
    buf.writeln('- 支出合計: ¥${NumberFormat('#,###').format(totalExpense)}');
    buf.writeln(
      '- 差額: ¥${NumberFormat('#,###').format(totalIncome - totalExpense)}',
    );
    buf.writeln('');

    buf.writeln('### ⑤ 必須タスク（$monthLabel）');
    if (mustThisMonth.isEmpty) {
      buf.writeln('- （未登録）');
    } else {
      for (final t in mustThisMonth) {
        final d = DateTime.parse(t['deadline']).toLocal();
        final done = (t['is_completed'] as bool?) == true;
        buf.writeln(
          '- ${done ? "✅" : "⬜️"} ${t["title"]}（締切 ${DateFormat('MM/dd').format(d)}）',
        );
      }
    }

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('サマリーをコピーしました（投稿用）')),
    );
  }

  // ==========================================
  // 1 & 2. 資産・負債の記録（ストック）
  // ==========================================
  Future<void> _loadDataFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _supabase
          .from('cfo_assets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      final Map<String, Map<String, double>> loadedData = {};
      final Set<String> loadedTypes = {'現金'};
      for (var item in data) {
        final DateTime createdAt = DateTime.parse(item['created_at']).toLocal();
        final String dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
        final String title = item['title'];
        final double amount = (item['amount'] as num).toDouble();
        loadedTypes.add(title);
        if (!loadedData.containsKey(dateKey)) {
          loadedData[dateKey] = {};
        }
        loadedData[dateKey]![title] = amount;
      }
      if (mounted) {
        setState(() {
          _assetTypes = loadedTypes.toList();
          _assetData = loadedData;
          _updateLastUpdatedDates();
          _sortAssetTypes(); // ★ ここで降順ソート
          _initControllers();
          _updateChartData();
        });
      }
    } catch (e) {
      debugPrint('Error loading assets: $e');
    }
  }

  // ★ 資産項目を金額の降順（資産→負債）で並び替える
  void _sortAssetTypes() {
    _assetTypes.sort((a, b) {
      final lastDateA = _lastUpdatedDates[a];
      final lastDateB = _lastUpdatedDates[b];

      // データがないものは -infinity として一番下へ
      final amountA = lastDateA != null
          ? (_assetData[lastDateA]?[a] ?? -double.infinity)
          : -double.infinity;
      final amountB = lastDateB != null
          ? (_assetData[lastDateB]?[b] ?? -double.infinity)
          : -double.infinity;

      // 降順（大きい順）
      return amountB.compareTo(amountA);
    });
  }

  void _initControllers() {
    final newControllers = <String, TextEditingController>{};
    for (var type in _assetTypes) {
      if (_controllers.containsKey(type)) {
        newControllers[type] = _controllers[type]!;
      } else {
        newControllers[type] = TextEditingController();
      }
    }
    _controllers = newControllers;
  }

  void _updateLastUpdatedDates() {
    _lastUpdatedDates = {};
    final sortedDates = _assetData.keys.toList()..sort();
    for (var type in _assetTypes) {
      String? lastDate;
      for (var date in sortedDates.reversed) {
        if (_assetData[date]?.containsKey(type) ?? false) {
          lastDate = date;
          break;
        }
      }
      _lastUpdatedDates[type] = lastDate;
    }
  }

  void _toggleMinusForType(String type) {
    final controller = _controllers[type];
    if (controller == null) return;

    final current = controller.text.trim();
    if (current.isEmpty) {
      controller.text = '-';
    } else if (current.startsWith('-')) {
      controller.text = current.substring(1);
    } else {
      controller.text = '-$current';
    }

    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
  }

  Future<void> _recordAssetAmountForToday(
    String type,
    double amount, {
    bool clearController = true,
    String? successMessage,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final today = _todayDateKey();
    try {
      await _supabase.from('cfo_assets').insert({
        'user_id': userId,
        'title': type,
        'amount': amount,
        'created_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        if (!_assetData.containsKey(today)) _assetData[today] = {};
        _assetData[today]![type] = amount;
        _updateLastUpdatedDates();
        _sortAssetTypes();
        _updateChartData();
      });

      if (clearController) {
        _controllers[type]?.clear();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage ?? '✅ $type を記録しました'),
          backgroundColor: Colors.green[700],
        ),
      );
      await _fetchTodayClosing();
    } catch (e) {
      debugPrint('Error saving $type: $e');
    }
  }

  Future<void> _quickUpdateAssetData(String type) async {
    final today = _todayDateKey();
    final lastDate = _lastUpdatedDates[type];
    if (lastDate == null ||
        lastDate == today ||
        lastDate != _yesterdayDateKey()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type は昨日の記録がある場合のみ簡易更新できます')),
      );
      return;
    }

    final lastAmount = _assetData[lastDate]?[type];
    if (lastAmount == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type の前回残高が見つかりません')),
      );
      return;
    }

    await _recordAssetAmountForToday(
      type,
      lastAmount,
      successMessage: '✅ $type を昨日と同額で簡易更新しました',
    );
  }

  Future<void> _saveSingleAssetData(String type) async {
    final controller = _controllers[type];
    if (controller == null || controller.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$type の金額を入力してください')));
      return;
    }

    final cleanText = controller.text.replaceAll(',', '');
    final parsedAmount = double.tryParse(cleanText);
    if (parsedAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type の金額形式が不正です')),
      );
      return;
    }
    final double amount = parsedAmount;
    await _recordAssetAmountForToday(type, amount);
  }

  Future<void> _saveAssetData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final Map<String, double> todayData = {};
    bool hasData = false;
    final List<String> invalidTypes = [];

    _controllers.forEach((assetType, controller) {
      if (controller.text.isNotEmpty) {
        final cleanText = controller.text.replaceAll(',', '');
        final parsedAmount = double.tryParse(cleanText);
        if (parsedAmount == null) {
          invalidTypes.add(assetType);
          return;
        }
        final double amount = parsedAmount;
        todayData[assetType] = amount;
        hasData = true;
      }
    });

    if (invalidTypes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('金額形式を確認してください: ${invalidTypes.join(', ')}')),
      );
      return;
    }

    if (!hasData) return;

    try {
      for (var entry in todayData.entries) {
        await _supabase.from('cfo_assets').insert({
          'user_id': userId,
          'title': entry.key,
          'amount': entry.value,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      setState(() {
        if (!_assetData.containsKey(today)) _assetData[today] = {};
        _assetData[today]!.addAll(todayData);
        _updateLastUpdatedDates();
        _sortAssetTypes(); // ★ 一括更新後にも並び替え
        _updateChartData();
      });
      _controllers.forEach((_, controller) => controller.clear());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('資産・負債を一括記録しました。')));
      }
      await _fetchTodayClosing();
    } catch (e) {
      debugPrint('Error saving assets: $e');
    }
  }

  void _showAddAssetDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('項目を追加'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '資産・負債名 (例: 住宅ローン)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty &&
                  !_assetTypes.contains(controller.text)) {
                setState(() {
                  _assetTypes.add(controller.text);
                  _initControllers();
                  _updateLastUpdatedDates();
                  _sortAssetTypes(); // ★ 追加時にも並び替え
                });
              }
              Navigator.pop(context);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  void _showRemoveAssetDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「$type」を削除'),
        content: const Text('この項目を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = _supabase.auth.currentUser?.id;
              if (userId != null) {
                await _supabase
                    .from('cfo_assets')
                    .delete()
                    .eq('user_id', userId)
                    .eq('title', type);
                setState(() {
                  _assetTypes.remove(type);
                  _controllers.remove(type)?.dispose();
                  _assetData.forEach((date, assets) {
                    assets.remove(type);
                  });
                  _initControllers();
                  _updateLastUpdatedDates();
                  _sortAssetTypes(); // ★ 削除時にも並び替え
                  _updateChartData();
                });
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. 固定費の記録（サブスク）
  // ==========================================
  Future<void> _fetchSubscriptions() async {
    setState(() => _isLoadingSubscriptions = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _subscriptions = [];
          _subscriptionsThreeMonths = [];
          _isLoadingSubscriptions = false;
        });
        return;
      }

      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month, 1);

      final data = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .order('due_date', ascending: true)
          .order('price', ascending: false);

      final allSubscriptions = List<Map<String, dynamic>>.from(data);
      final currentMonthKey = _monthKey(currentMonth);
      final currentMonthOnly = allSubscriptions.where((row) {
        final dueStr = row['due_date']?.toString();
        if (dueStr == null || dueStr.isEmpty) return false;
        final dueDate = DateTime.tryParse(dueStr);
        if (dueDate == null) return false;
        return _monthKey(DateTime(dueDate.year, dueDate.month, 1)) ==
            currentMonthKey;
      }).toList();

      if (!mounted) return;
      setState(() {
        _subscriptions = currentMonthOnly;
        _subscriptionsThreeMonths = allSubscriptions;
        _isLoadingSubscriptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _subscriptions = [];
        _subscriptionsThreeMonths = [];
        _isLoadingSubscriptions = false;
      });
    }
  }

  Future<void> _addSubscription() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    DateTime dueDate = DateTime.now();
    bool isPaid = false;
    final candidates = _paymentSourceCandidates();
    String paymentSource = candidates.first; // （未設定）
    final customPaymentSourceController = TextEditingController();

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('固定費を追加'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: '名称 (例: モビット, 家賃)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: '金額 (円)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime(DateTime.now().year - 1, 1, 1),
                        lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                      );
                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '支払日: ${DateFormat('yyyy/M/d(E)', 'ja_JP').format(dueDate)}',
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: paymentSource,
                    decoration: const InputDecoration(
                      labelText: '引落先（資産・負債から選択）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: candidates
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() => paymentSource = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  if (paymentSource == 'その他')
                    TextField(
                      controller: customPaymentSourceController,
                      decoration: const InputDecoration(
                        labelText: '引落先（自由入力）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isPaid,
                    onChanged: (v) => setDialogState(() => isPaid = v ?? false),
                    title: const Text('支払い済みにする'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final userId = _supabase.auth.currentUser?.id;
                    if (userId == null) return;

                    final name = nameController.text.trim();
                    final price =
                        int.tryParse(priceController.text.trim()) ?? 0;
                    if (name.isEmpty || price <= 0) return;

                    final dueDateStr = DateFormat('yyyy-MM-dd').format(dueDate);
                    final sourceText = paymentSource == '（未設定）'
                        ? null
                        : (paymentSource == 'その他'
                            ? customPaymentSourceController.text.trim()
                            : paymentSource);

                    await _supabase.from('subscriptions').insert({
                      'user_id': userId,
                      'service_name': name,
                      'price': price,
                      'due_date': dueDateStr,
                      'is_paid': isPaid,
                      'payment_source':
                          (sourceText == null || sourceText.isEmpty)
                              ? null
                              : sourceText,
                    });

                    if (mounted) {
                      setState(() {
                        _selectedSubscriptionHistoryMonth =
                            _monthStart(dueDate);
                      });
                    }
                    if (context.mounted) Navigator.pop(context);
                    await _fetchSubscriptions();
                    await _fetchTodayClosing();
                  },
                  child: const Text('追加'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      nameController.dispose();
      priceController.dispose();
      customPaymentSourceController.dispose();
    }
  }

  Future<void> _deleteSubscription(String id) async {
    await _supabase.from('subscriptions').delete().eq('id', id);
    _fetchSubscriptions();
    await _fetchTodayClosing();
  }

  Future<bool> _confirmDeleteSubscription({String serviceName = ''}) async {
    final targetName = serviceName.trim();
    final targetLabel = targetName.isEmpty ? 'この固定費' : '「$targetName」';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('$targetLabelを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _toggleSubscriptionPaid(String id, bool current) async {
    try {
      await _supabase
          .from('subscriptions')
          .update({'is_paid': !current}).eq('id', id);
      await _fetchSubscriptions();
      await _fetchTodayClosing();
    } catch (e) {
      debugPrint('toggle paid error: $e');
    }
  }

  // ==========================================
  // 4. 今月の支出と収入の記録（フロー）
  // ==========================================
  Future<void> _fetchRecentFlows() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _supabase
          .from('wealth_struggles')
          .select()
          .eq('user_id', userId)
          .order('occurred_at', ascending: false);

      if (mounted) {
        setState(() {
          _recentFlows = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching flows: $e');
    }
  }

  Future<void> _recordFlow() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final memo = _flowMemoController.text.trim();
    final amountStr = _flowAmountController.text.replaceAll(',', '');
    final amount = int.tryParse(amountStr);

    if (amount == null || amount <= 0 || memo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内容と金額(1円以上)を正しく入力してください')),
      );
      return;
    }

    final actionType = _selectedFlowType == '収入' ? 'conquer' : 'expense';

    try {
      await _supabase.from('wealth_struggles').insert({
        'user_id': userId,
        'action_type': actionType,
        'amount': amount,
        'description': '$_selectedSource $memo',
        'occurred_at': _selectedFlowDate.toUtc().toIso8601String(),
      });

      _flowMemoController.clear();
      _flowAmountController.clear();
      if (mounted) {
        setState(() {
          _selectedFlowHistoryMonth = _monthStart(_selectedFlowDate);
        });
      }
      await _fetchRecentFlows();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('収支を記録しました'),
            backgroundColor: Colors.black87,
          ),
        );
      }
      await _fetchTodayClosing();
    } catch (e) {
      debugPrint('Error recording flow: $e');
    }
  }

  // ==========================================
  // 5. 必須タスクの記録と把握
  // ==========================================
  Future<void> _fetchMustTasks() async {
    setState(() => _isLoadingTasks = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('must_tasks')
          .select()
          .eq('user_id', userId)
          .order('deadline', ascending: true);

      if (mounted) {
        setState(() {
          _mustTasks = List<Map<String, dynamic>>.from(data);
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mustTasks = [];
          _isLoadingTasks = false;
        });
      }
    }
  }

  Future<void> _addMustTask() async {
    final titleController = TextEditingController();
    DateTime selectedDeadline = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('必須タスクを追加'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration:
                      const InputDecoration(labelText: 'タスク内容 (例: 確定申告)'),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDeadline,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDeadline = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '締切: ${DateFormat('yyyy/MM/dd').format(selectedDeadline)}',
                        ),
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;
                  final userId = _supabase.auth.currentUser?.id;
                  if (userId != null) {
                    try {
                      await _supabase.from('must_tasks').insert({
                        'user_id': userId,
                        'title': title,
                        'deadline': selectedDeadline.toUtc().toIso8601String(),
                        'is_completed': false,
                      });
                      if (context.mounted) Navigator.pop(context);
                      _fetchMustTasks();
                    } catch (e) {
                      debugPrint('Error adding task: $e');
                      setState(() {
                        _mustTasks.add({
                          'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
                          'title': title,
                          'deadline':
                              selectedDeadline.toUtc().toIso8601String(),
                          'is_completed': false,
                        });
                      });
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );
    await _fetchTodayClosing();
  }

  Future<void> _toggleTaskStatus(String id, bool currentStatus) async {
    try {
      await _supabase
          .from('must_tasks')
          .update({'is_completed': !currentStatus}).eq('id', id);
      _fetchMustTasks();
    } catch (e) {
      setState(() {
        final index = _mustTasks.indexWhere((t) => t['id'] == id);
        if (index != -1) _mustTasks[index]['is_completed'] = !currentStatus;
      });
    }
    await _fetchTodayClosing();
  }

  Future<void> _editSubscriptionDueDate(Map<String, dynamic> item) async {
    final String id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;

    // due_date は "YYYY-MM-DD" が来る想定
    final dueStr = item['due_date'] as String?;
    DateTime initial = DateTime.now();
    if (dueStr != null && dueStr.isNotEmpty) {
      final parsed = DateTime.tryParse(dueStr);
      if (parsed != null) {
        // 日付だけに丸める（タイムゾーン事故防止）
        initial = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 1, 1, 1),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );

    if (picked == null) return;

    final dueDateStr = DateFormat('yyyy-MM-dd').format(picked);

    try {
      await _supabase
          .from('subscriptions')
          .update({'due_date': dueDateStr}).eq('id', id);

      await _fetchSubscriptions();
      await _fetchTodayClosing();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('支払日を更新しました: $dueDateStr')),
      );
    } catch (e) {
      debugPrint('edit due_date error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('支払日の更新に失敗: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _editSubscriptionPaymentSource(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final candidates = _paymentSourceCandidates();

    final current = (item['payment_source']?.toString() ?? '').trim();
    String selected = current.isEmpty
        ? '（未設定）'
        : (candidates.contains(current) ? current : 'その他');

    final custom =
        TextEditingController(text: selected == 'その他' ? current : '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('引落先を編集'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: '引落先（資産・負債から選択）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: candidates
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setDialogState(() => selected = v);
                },
              ),
              const SizedBox(height: 8),
              if (selected == 'その他')
                TextField(
                  controller: custom,
                  decoration: const InputDecoration(
                    labelText: '引落先（自由入力）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) {
      custom.dispose();
      return;
    }

    final sourceText = selected == '（未設定）'
        ? null
        : (selected == 'その他' ? custom.text.trim() : selected);

    custom.dispose();

    try {
      await _supabase.from('subscriptions').update({
        'payment_source':
            (sourceText == null || sourceText.isEmpty) ? null : sourceText,
      }).eq('id', id);

      await _fetchSubscriptions();
      await _fetchTodayClosing();
    } catch (e) {
      debugPrint('edit payment_source error: $e');
    }
  }

  // ==========================================
  // グラフ描画ロジック
  // ==========================================
  void _updateChartData() {
    // NOTE: Builds UI-only complemented snapshots for charts/tooltips.
    // Never mutate _assetData here; it is the source of truth persisted to Supabase.
    _sortedDates = _assetData.keys.toList()..sort();
    _effectiveAssetDataByDate = {};
    if (_sortedDates.isEmpty) {
      _lineChartBars = [];
      _barChartGroups = [];
      return;
    }
    final Map<String, List<FlSpot>> spotsData = {
      for (var type in _assetTypes) type: [],
    };
    final lastKnownValues = <String, double>{
      for (var type in _assetTypes) type: 0,
    };
    final initializedTypes = <String>{};
    final dailyTotals = <double>[];

    for (int i = 0; i < _sortedDates.length; i++) {
      final String date = _sortedDates[i];
      final rawOnDate = _assetData[date] ?? const <String, double>{};
      final snapshotOnDate = <String, double>{};
      double currentDayTotal = 0;
      double cumulativeValue = 0;

      for (var type in _assetTypes) {
        if (rawOnDate.containsKey(type)) {
          lastKnownValues[type] = rawOnDate[type]!;
          initializedTypes.add(type);
        }
        final double value = initializedTypes.contains(type)
            ? (lastKnownValues[type] ?? 0.0)
            : 0.0;
        snapshotOnDate[type] = value;
        currentDayTotal += value;
        if (_isStacked) {
          cumulativeValue += value;
          spotsData[type]!.add(FlSpot(i.toDouble(), cumulativeValue));
        } else {
          spotsData[type]!.add(FlSpot(i.toDouble(), value));
        }
      }
      _effectiveAssetDataByDate[date] = snapshotOnDate;
      dailyTotals.add(currentDayTotal);
    }

    _lineChartBars = _assetTypes
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final type = entry.value;
          final color = _colors[index % _colors.length];
          final spots = spotsData[type] ?? [];
          if (spots.isEmpty) return null;
          return LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: _isStacked,
              color: color.withValues(alpha: 0.5),
            ),
          );
        })
        .whereType<LineChartBarData>()
        .toList();

    if (_isStacked) _lineChartBars = _lineChartBars.reversed.toList();

    _barChartGroups = [];
    _maxDailyChange = 0;
    for (int i = 0; i < dailyTotals.length; i++) {
      double diff = 0;
      if (i > 0) diff = dailyTotals[i] - dailyTotals[i - 1];
      if (diff.abs() > _maxDailyChange) _maxDailyChange = diff.abs();
      final color = diff >= 0 ? Colors.green : Colors.red;
      _barChartGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: diff,
              color: color,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }
    if (_maxDailyChange == 0) _maxDailyChange = 1000;
    _maxDailyChange *= 1.2;
  }

  // ==========================================
  // UI構築 (エラーが起きていた箇所)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final isCompact = _isCompact;
    return Scaffold(
      appBar: AppBar(
        title: const Text('資産管理闘争'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.blueGrey[50],
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDeadlineChecklistCard(), // 締切チェックリスト
            const SizedBox(height: 16),
            _buildThreeMonthOverviewCard(), // 3ヶ月俯瞰
            const SizedBox(height: 16),
            _buildDebtPlannerCard(), // 借金返済プラン
            const SizedBox(height: 16),
            Container(
              key: _keyStock,
              child: _buildAssetLiabilityCard(),
            ), // ①②資産負債
            const SizedBox(height: 24),
            Container(key: _keyFlow, child: _buildFlowCard()), // ④収支
            const SizedBox(height: 24),
            Container(key: _keySubs, child: _buildSubscriptionCard()), // ③固定費
            const SizedBox(height: 24),
            Container(key: _keyMust, child: _buildMustTasksCard()), // ⑤必須タスク
            const SizedBox(height: 24),
            _buildChartCard(), // グラフ
          ],
        ),
      ),
    );
  }

  // -------------------------
  // 各カードUIコンポーネント
  // -------------------------

  Widget _buildDeadlineChecklistCard() {
    final remainText = _remainingToDeadlineText();
    final p = _progress();
    final isCompact = _isCompact;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.deepOrange),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '本日18:00までに必ず完了（①〜⑤）',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isLoadingClosing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              remainText,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: p,
              minHeight: 10,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 8),
            Text(
              '${(p * 100).toInt()}% 完了',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _assetsDone,
              onChanged: (v) => _toggleClosing('assets', v ?? false),
              title: const Text('① 全資産額を記録して把握'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: () => _scrollTo(_keyStock),
                tooltip: '資産・負債へ移動',
              ),
            ),
            CheckboxListTile(
              value: _liabilitiesDone,
              onChanged: (v) => _toggleClosing('liabilities', v ?? false),
              title: const Text('② 全負債額を記録して把握'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: () => _scrollTo(_keyStock),
                tooltip: '資産・負債へ移動',
              ),
            ),
            CheckboxListTile(
              value: _fixedCostsDone,
              onChanged: (v) => _toggleClosing('fixed', v ?? false),
              title: const Text('③ 今月の固定費をすべて記録して把握'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: () => _scrollTo(_keySubs),
                tooltip: '固定費へ移動',
              ),
            ),
            CheckboxListTile(
              value: _flowsDone,
              onChanged: (v) => _toggleClosing('flows', v ?? false),
              title: const Text('④ 今月の支出と収入をすべて記録して把握'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: () => _scrollTo(_keyFlow),
                tooltip: '収支へ移動',
              ),
            ),
            CheckboxListTile(
              value: _mustTasksDone,
              onChanged: (v) => _toggleClosing('must', v ?? false),
              title: const Text('⑤ 今月の必須タスクをすべて記録して把握'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: () => _scrollTo(_keyMust),
                tooltip: '必須タスクへ移動',
              ),
            ),
            const SizedBox(height: 8),
            isCompact
                ? Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _autoCheckFromData,
                          icon: const Icon(Icons.auto_fix_high),
                          label: const Text('記録状況から自動チェック'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _copyDailySummary,
                          icon: const Icon(Icons.copy),
                          label: const Text('提出用サマリーをコピー'),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _autoCheckFromData,
                          icon: const Icon(Icons.auto_fix_high),
                          label: const Text('記録状況から自動チェック'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _copyDailySummary,
                          icon: const Icon(Icons.copy),
                          label: const Text('提出用サマリーをコピー'),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeMonthOverviewTile({
    required DateTime month,
    required double? netWorth,
    required int fixedCost,
    required int totalTasks,
    required int completedTasks,
    required int pendingTasks,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _monthLabelWithRole(month),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '純資産: ${netWorth == null ? "未記録" : _formatYen(netWorth)}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '固定費: ${_formatYen(fixedCost)}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            'タスク: $completedTasks/$totalTasks 完了',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '未完了: $pendingTasks',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeMonthOverviewCard() {
    final months = _overviewMonthStarts();
    final monthKeys = months.map(_monthKey).toList();
    final netWorthByMonth = _netWorthByOverviewMonth(months);
    final fixedCostByMonth = _fixedCostByOverviewMonth(months);
    final taskStatsByMonth = _taskStatsByOverviewMonth(months);

    final prevKey = monthKeys[0];
    final currentKey = monthKeys[1];
    final nextKey = monthKeys[2];

    final prevNet = netWorthByMonth[prevKey];
    final currentNet = netWorthByMonth[currentKey];
    final netDiffText = (prevNet != null && currentNet != null)
        ? _formatSignedYen(currentNet - prevNet)
        : 'データ不足';
    final netDiffColor = (prevNet != null && currentNet != null)
        ? ((currentNet - prevNet) >= 0 ? Colors.green : Colors.red)
        : Colors.grey;

    final fixedDiff =
        (fixedCostByMonth[currentKey] ?? 0) - (fixedCostByMonth[prevKey] ?? 0);
    final fixedDiffColor = fixedDiff <= 0 ? Colors.green : Colors.red;

    final currentTask = taskStatsByMonth[currentKey] ??
        {
          'total': 0,
          'completed': 0,
          'pending': 0,
        };
    final nextTask = taskStatsByMonth[nextKey] ??
        {
          'total': 0,
          'completed': 0,
          'pending': 0,
        };

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.view_timeline, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  '3ヶ月俯瞰（先月・今月・来月）',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '口座残高・固定費・必須タスクを3ヶ月単位で比較します。',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            _isCompact
                ? Column(
                    children: [
                      for (int i = 0; i < months.length; i++) ...[
                        _buildThreeMonthOverviewTile(
                          month: months[i],
                          netWorth: netWorthByMonth[monthKeys[i]],
                          fixedCost: fixedCostByMonth[monthKeys[i]] ?? 0,
                          totalTasks:
                              taskStatsByMonth[monthKeys[i]]?['total'] ?? 0,
                          completedTasks:
                              taskStatsByMonth[monthKeys[i]]?['completed'] ?? 0,
                          pendingTasks:
                              taskStatsByMonth[monthKeys[i]]?['pending'] ?? 0,
                        ),
                        if (i != months.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      for (int i = 0; i < months.length; i++) ...[
                        Expanded(
                          child: _buildThreeMonthOverviewTile(
                            month: months[i],
                            netWorth: netWorthByMonth[monthKeys[i]],
                            fixedCost: fixedCostByMonth[monthKeys[i]] ?? 0,
                            totalTasks:
                                taskStatsByMonth[monthKeys[i]]?['total'] ?? 0,
                            completedTasks: taskStatsByMonth[monthKeys[i]]
                                    ?['completed'] ??
                                0,
                            pendingTasks:
                                taskStatsByMonth[monthKeys[i]]?['pending'] ?? 0,
                          ),
                        ),
                        if (i != months.length - 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOverviewStatChip(
                  label: '純資産 先月比',
                  value: netDiffText,
                  color: netDiffColor,
                ),
                _buildOverviewStatChip(
                  label: '固定費 先月比',
                  value: _formatSignedYen(fixedDiff),
                  color: fixedDiffColor,
                ),
                _buildOverviewStatChip(
                  label: '今月タスク進捗',
                  value:
                      '${currentTask['completed'] ?? 0}/${currentTask['total'] ?? 0}',
                  color: Colors.blue,
                ),
                _buildOverviewStatChip(
                  label: '来月タスク件数',
                  value: '${nextTask['total'] ?? 0}件',
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 借金返済プランカード
  Widget _buildDebtPlannerCard() {
    final latestSnapshot = _sortedDates.isEmpty
        ? const <String, double>{}
        : (_effectiveAssetDataByDate[_sortedDates.last] ??
            _assetData[_sortedDates.last] ??
            const <String, double>{});

    final liabilities = latestSnapshot.entries
        .where((e) => e.value < 0)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final totalDebt =
        liabilities.fold<double>(0, (sum, e) => sum + e.value.abs());

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text(
                  '借金返済プラン',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '負債データをもとに、返済優先順位と3ヶ月アクションを自動生成します。',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOverviewStatChip(
                  label: '負債件数',
                  value: '${liabilities.length}件',
                  color: Colors.red,
                ),
                _buildOverviewStatChip(
                  label: '負債合計',
                  value: _formatYen(totalDebt),
                  color: Colors.deepOrange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            _isGeneratingDebtPlan ? null : _showDebtPlanDialog,
                        icon: _isGeneratingDebtPlan
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(
                          _isGeneratingDebtPlan ? '返済プラン作成中...' : '返済プランを作成',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _debtPlanMarkdown == null
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _debtPlanMarkdown!),
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('返済プランをコピーしました'),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.copy),
                        label: const Text('プランをコピー'),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isGeneratingDebtPlan
                              ? null
                              : _showDebtPlanDialog,
                          icon: _isGeneratingDebtPlan
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.play_arrow),
                          label: Text(
                            _isGeneratingDebtPlan ? '返済プラン作成中...' : '返済プランを作成',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _debtPlanMarkdown == null
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _debtPlanMarkdown!),
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('返済プランをコピーしました'),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.copy),
                        label: const Text('プランをコピー'),
                      ),
                    ],
                  ),
            if (_debtPlanGeneratedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '生成日時: ${DateFormat('yyyy/MM/dd HH:mm').format(_debtPlanGeneratedAt!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 12),
            if (_isGeneratingDebtPlan)
              const Center(child: CircularProgressIndicator())
            else if (_debtPlanMarkdown == null)
              Text(
                'まだ返済プランは作成されていません。',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MarkdownBody(
                  data: _debtPlanMarkdown!,
                  selectable: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ①資産 ②負債 の入力カード
  Widget _buildAssetLiabilityCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  '①資産・②負債の全容把握',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Text(
              '現金、銀行口座、クレカの未払い(マイナス入力)をすべて記録せよ。',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ..._assetTypes.map((type) => _buildAssetInputRow(type)),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _showAddAssetDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('項目を追加'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveAssetData,
                icon: const Icon(Icons.done_all),
                label: const Text('全体状況を保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegendCard(), // 内訳表示
          ],
        ),
      ),
    );
  }

  Widget _buildAssetInputRow(String type) {
    final todayStr = _todayDateKey();
    final isUpdatedToday = _lastUpdatedDates[type] == todayStr;
    final isCompact = _isCompact;

    // 最新残高を取得
    final lastDate = _lastUpdatedDates[type];
    double? lastAmount;
    if (lastDate != null) {
      lastAmount = _assetData[lastDate]?[type];
    }
    final isLiability = (lastAmount ?? 0) < 0;
    final canQuickUpdate = lastAmount != null &&
        !isUpdatedToday &&
        lastDate == _yesterdayDateKey();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isCompact
              ? Column(
                  children: [
                    TextField(
                      controller: _controllers[type],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: type,
                        hintText: '負債はマイナス(-)をつける',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: '符号切替',
                          onPressed: () => _toggleMinusForType(type),
                          icon: const Icon(Icons.exposure_neg_1),
                        ),
                        isDense: true,
                        filled: isUpdatedToday,
                        fillColor: isUpdatedToday ? Colors.green[50] : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (canQuickUpdate) ...[
                          OutlinedButton.icon(
                            onPressed: () => _quickUpdateAssetData(type),
                            icon:
                                const Icon(Icons.history_toggle_off, size: 16),
                            label: const Text('同額'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton(
                          onPressed: () => _saveSingleAssetData(type),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isUpdatedToday
                                ? Colors.grey
                                : Colors.green[700],
                            foregroundColor: Colors.white,
                          ),
                          child: Text(isUpdatedToday ? '済' : '記録'),
                        ),
                        if (type != '現金')
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.grey,
                            ),
                            onPressed: () => _showRemoveAssetDialog(type),
                          ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controllers[type],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: type,
                          hintText: '負債はマイナス(-)をつける',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: '符号切替',
                            onPressed: () => _toggleMinusForType(type),
                            icon: const Icon(Icons.exposure_neg_1),
                          ),
                          isDense: true,
                          filled: isUpdatedToday,
                          fillColor: isUpdatedToday ? Colors.green[50] : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (canQuickUpdate) ...[
                      OutlinedButton.icon(
                        onPressed: () => _quickUpdateAssetData(type),
                        icon: const Icon(Icons.history_toggle_off, size: 16),
                        label: const Text('同額'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton(
                      onPressed: () => _saveSingleAssetData(type),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isUpdatedToday ? Colors.grey : Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isUpdatedToday ? '済' : '記録'),
                    ),
                    if (type != '現金')
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                        ),
                        onPressed: () => _showRemoveAssetDialog(type),
                      ),
                  ],
                ),
          if (lastAmount != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 3),
              child: Row(
                children: [
                  Icon(
                    _getIconForAsset(type),
                    size: 11,
                    color: isLiability ? Colors.red[400] : Colors.green[600],
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '現在: ¥${NumberFormat('#,###').format(lastAmount)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isLiability ? Colors.red[600] : Colors.green[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${lastDate == todayStr ? "本日更新" : "最終更新: $lastDate"})',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                  if (canQuickUpdate) ...[
                    const SizedBox(width: 8),
                    Text(
                      '昨日と同額なら「同額」で更新',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.blueGrey[600],
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 3),
              child: Text(
                '未記録',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendCard() {
    if (_sortedDates.isEmpty) return const SizedBox.shrink();
    final latestDate = _sortedDates.last;
    final latestData =
        _effectiveAssetDataByDate[latestDate] ?? _assetData[latestDate] ?? {};
    double totalAssets = 0;
    double totalLiabilities = 0;

    latestData.forEach((key, value) {
      if (value >= 0) {
        totalAssets += value;
      } else {
        totalLiabilities += value;
      }
    });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('総資産:'),
              Text(
                '¥${NumberFormat('#,###').format(totalAssets)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('総負債:'),
              Text(
                '¥${NumberFormat('#,###').format(totalLiabilities)}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('純資産:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '¥${NumberFormat('#,###').format(totalAssets + totalLiabilities)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ④ 今月の支出と収入
  Widget _buildFlowCard() {
    final visibleFlows = _flowsForMonth(_selectedFlowHistoryMonth);
    final visibleMonthLabel = _flowMonthLabel(_selectedFlowHistoryMonth);
    final canMoveForward = !_isSameMonth(
      _selectedFlowHistoryMonth,
      DateTime.now(),
    );
    int totalIncome = 0;
    int totalExpense = 0;

    for (var item in visibleFlows) {
      final amount = (item['amount'] as num?)?.toInt() ?? 0;
      final actionType = item['action_type'] as String? ?? '';
      if (actionType == 'conquer') totalIncome += amount; // 収入
      if (actionType == 'expense') totalExpense += amount; // 支出
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '④収支の記録',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              'お金の流れをすべてリスト化する。表示中: $visibleMonthLabel（過去月に切替可）',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedFlowType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: ['支出', '収入']
                        .map(
                          (String val) => DropdownMenuItem(
                            value: val,
                            child: Text(
                              val,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFlowType = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedFlowDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _selectedFlowDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('MM/dd').format(_selectedFlowDate)),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.blueGrey.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '前月',
                    onPressed: () => _shiftFlowHistoryMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _pickFlowHistoryMonth,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            const Text(
                              '履歴表示月',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              visibleMonthLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '翌月',
                    onPressed:
                        canMoveForward ? () => _shiftFlowHistoryMonth(1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSource,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: _sourceOptions
                        .map(
                          (String source) => DropdownMenuItem(
                            value: source,
                            child: Text(
                              source.replaceAll('[', '').replaceAll(']', ''),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSource = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _flowMemoController,
                    decoration: const InputDecoration(
                      labelText: '内容',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _flowAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '金額 (円)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _recordFlow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('追加'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$visibleMonthLabel 収入',
                        style: const TextStyle(fontSize: 10),
                      ),
                      Text(
                        '¥${NumberFormat('#,###').format(totalIncome)}',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '$visibleMonthLabel 支出',
                        style: const TextStyle(fontSize: 10),
                      ),
                      Text(
                        '¥${NumberFormat('#,###').format(totalExpense)}',
                        style: TextStyle(
                          color: Colors.red[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('収支差額', style: TextStyle(fontSize: 10)),
                      Text(
                        '¥${NumberFormat('#,###').format(totalIncome - totalExpense)}',
                        style: TextStyle(
                          color: (totalIncome - totalExpense) >= 0
                              ? Colors.green[800]
                              : Colors.red[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            visibleFlows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: Text('$visibleMonthLabel の記録はありません')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleFlows.length,
                    itemBuilder: (context, index) {
                      final item = visibleFlows[index];
                      final isIncome =
                          (item['action_type'] as String?) == 'conquer';
                      final amount = (item['amount'] as num?)?.toInt() ?? 0;
                      final desc = item['description']?.toString() ?? '';
                      final date = DateTime.tryParse(
                            item['occurred_at']?.toString() ?? '',
                          )?.toLocal() ??
                          _selectedFlowHistoryMonth;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isIncome ? Icons.add_circle : Icons.remove_circle,
                          color: isIncome ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        title: Text(desc, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          DateFormat('MM/dd').format(date),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          '${isIncome ? '+' : '-'}¥${NumberFormat('#,###').format(amount)}',
                          style: TextStyle(
                            color: isIncome ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  // ③ 固定費
  Widget _buildSubscriptionCard() {
    final visibleSubscriptions = _subscriptionsForMonth(
      _selectedSubscriptionHistoryMonth,
    );
    final visibleMonthLabel =
        _flowMonthLabel(_selectedSubscriptionHistoryMonth);
    final canMoveForward = !_isSameMonth(
      _selectedSubscriptionHistoryMonth,
      DateTime(DateTime.now().year + 5, 12, 1),
    );
    int totalCost = 0;
    int unpaidCost = 0;
    final isCompact = _isCompact;
    for (final sub in visibleSubscriptions) {
      final price = (sub['price'] as num?)?.toInt() ?? 0;
      totalCost += price;
      final isPaid = (sub['is_paid'] as bool?) == true;
      if (!isPaid) unpaidCost += price;
    }
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.credit_card_off, color: Colors.red[800]),
                          const SizedBox(width: 8),
                          Text(
                            '③固定費をすべて把握',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '毎月自動で奪われる富を監視せよ。',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickSubscriptionHistoryMonth,
                        child: Text(
                          '表示中: $visibleMonthLabel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¥${NumberFormat('#,###').format(totalCost)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '未払い: ¥${NumberFormat('#,###').format(unpaidCost)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: unpaidCost > 0
                              ? Colors.red[700]
                              : Colors.green[700],
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.credit_card_off,
                                color: Colors.red[800],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '③固定費をすべて把握',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[900],
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            '毎月自動で奪われる富を監視せよ。',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '表示月',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            visibleMonthLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '月額合計',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            '¥${NumberFormat('#,###').format(totalCost)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '未払い: ¥${NumberFormat('#,###').format(unpaidCost)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: unpaidCost > 0
                                  ? Colors.red[700]
                                  : Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '前月',
                    onPressed: () => _shiftSubscriptionHistoryMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _pickSubscriptionHistoryMonth,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            const Text(
                              '固定費の表示月',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              visibleMonthLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '翌月',
                    onPressed: canMoveForward
                        ? () => _shiftSubscriptionHistoryMonth(1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
          _isLoadingSubscriptions
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : visibleSubscriptions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text('$visibleMonthLabel の固定費はありません'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleSubscriptions.length,
                      itemBuilder: (context, index) {
                        final item = visibleSubscriptions[index];
                        final due = item['due_date'] as String?;
                        final dueDate =
                            due != null ? DateTime.parse(due) : null;
                        final isPaid = (item['is_paid'] as bool?) == true;
                        final src =
                            (item['payment_source'] ?? '').toString().trim();
                        return ListTile(
                          dense: true,
                          leading: Checkbox(
                            value: isPaid,
                            onChanged: (_) =>
                                _toggleSubscriptionPaid(item['id'], isPaid),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item['service_name'] ?? '',
                                  style: TextStyle(
                                    decoration: isPaid
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isPaid ? Colors.grey : null,
                                    fontWeight: isPaid
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '¥${NumberFormat('#,###').format(item['price'])}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isPaid ? Colors.grey : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dueDate != null
                                    ? '支払日: ${DateFormat('yyyy/M/d(E)', 'ja_JP').format(dueDate)}'
                                    : '支払日: 未設定',
                                style: TextStyle(
                                  color: isPaid
                                      ? Colors.grey
                                      : Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                              if (src.isNotEmpty)
                                Text(
                                  '引落先: $src',
                                  style: TextStyle(
                                    color: isPaid
                                        ? Colors.grey
                                        : Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) async {
                              if (value == 'due') {
                                await _editSubscriptionDueDate(item);
                              } else if (value == 'source') {
                                await _editSubscriptionPaymentSource(item);
                              } else if (value == 'delete') {
                                final serviceName =
                                    (item['service_name'] ?? '').toString();
                                final shouldDelete =
                                    await _confirmDeleteSubscription(
                                  serviceName: serviceName,
                                );
                                if (!shouldDelete) return;
                                await _deleteSubscription(item['id']);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem<String>(
                                value: 'due',
                                child: Text('支払日を編集'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'source',
                                child: Text('引落先を編集'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text(
                                  '削除',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextButton.icon(
              onPressed: _addSubscription,
              icon: const Icon(Icons.add),
              label: const Text('固定費を追加'),
              style: TextButton.styleFrom(foregroundColor: Colors.red[800]),
            ),
          ),
        ],
      ),
    );
  }

  // ⑤ 必須タスク
  Widget _buildMustTasksCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_late, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  '⑤今月の必須タスク',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Text(
              '今月中に必ず処理すべき事務手続き等を記録せよ。',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _isLoadingTasks
                ? const Center(child: CircularProgressIndicator())
                : _mustTasks.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('登録されたタスクはありません')),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _mustTasks.length,
                        itemBuilder: (context, index) {
                          final task = _mustTasks[index];
                          final isCompleted =
                              (task['is_completed'] as bool?) == true;
                          final deadline =
                              DateTime.parse(task['deadline']).toLocal();
                          final isOverdue =
                              !isCompleted && deadline.isBefore(DateTime.now());

                          return CheckboxListTile(
                            value: isCompleted,
                            onChanged: (val) =>
                                _toggleTaskStatus(task['id'], isCompleted),
                            title: Text(
                              task['title'],
                              style: TextStyle(
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              '締切: ${DateFormat('yyyy/MM/dd').format(deadline)}',
                              style: TextStyle(
                                color: isOverdue ? Colors.red : Colors.grey,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          );
                        },
                      ),
            TextButton.icon(
              onPressed: _addMustTask,
              icon: const Icon(Icons.add),
              label: const Text('タスクを追加'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange[800]),
            ),
          ],
        ),
      ),
    );
  }

  // --- グラフ ---
  Widget _buildChartCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showDailyChange ? '戦果レポート (日次損益)' : '戦略マップ (資産推移)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _showDailyChange ? '昨日の自分に勝ったか？' : '国力(富)の総量は増えているか？',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.show_chart, size: 16),
                    Switch(
                      value: _showDailyChange,
                      activeThumbColor: Colors.redAccent,
                      onChanged: (value) {
                        setState(() {
                          _showDailyChange = value;
                        });
                      },
                    ),
                    const Icon(Icons.bar_chart, size: 16),
                  ],
                ),
              ],
            ),
            if (!_showDailyChange)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('個別', style: TextStyle(fontSize: 10)),
                  Switch(
                    value: _isStacked,
                    activeThumbColor: Colors.green,
                    onChanged: (value) {
                      setState(() {
                        _isStacked = value;
                        _updateChartData();
                      });
                    },
                  ),
                  const Text('合計', style: TextStyle(fontSize: 10)),
                ],
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: _lineChartBars.isEmpty && _barChartGroups.isEmpty
                  ? const Center(child: Text('戦況データなし。'))
                  : _showDailyChange
                      ? _buildDailyChangeChart()
                      : _buildAssetTrendChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetTrendChart() {
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: _getTooltipItems,
          ),
          handleBuiltInTouches: true,
        ),
        gridData: const FlGridData(show: true),
        titlesData: _buildChartTitles(),
        borderData:
            FlBorderData(show: true, border: Border.all(color: Colors.black12)),
        lineBarsData: _lineChartBars,
      ),
    );
  }

  Widget _buildDailyChangeChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _maxDailyChange,
        minY: -_maxDailyChange,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final dateIndex = group.x.toInt();
              final dateStr = dateIndex < _sortedDates.length
                  ? _sortedDates[dateIndex]
                  : '';
              final date = dateStr.isNotEmpty
                  ? DateFormat('MM/dd').format(DateTime.parse(dateStr))
                  : '';
              final val =
                  NumberFormat.simpleCurrency(locale: 'ja_JP', decimalDigits: 0)
                      .format(rod.toY);
              return BarTooltipItem(
                '$date\n$val',
                TextStyle(
                  color:
                      rod.toY >= 0 ? Colors.lightGreenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: _buildChartTitles(),
        gridData: FlGridData(
          show: true,
          checkToShowHorizontalLine: (value) => value == 0,
          getDrawingHorizontalLine: (value) {
            if (value == 0) {
              return const FlLine(color: Colors.black54, strokeWidth: 1);
            }
            return const FlLine(color: Colors.black12, strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: _barChartGroups,
      ),
    );
  }

  FlTitlesData _buildChartTitles() {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 50,
          getTitlesWidget: _leftTitleWidgets,
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: _bottomTitleWidgets,
          interval: max(1, (_sortedDates.length / 5).floor().toDouble()),
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 10);
    String text = '';
    if (value.toInt() < _sortedDates.length) {
      text = DateFormat('MM/dd')
          .format(DateTime.parse(_sortedDates[value.toInt()]));
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(text, style: style),
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    final format = NumberFormat.compact(locale: 'ja_JP');
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8,
      child: Text(format.format(value), style: const TextStyle(fontSize: 10)),
    );
  }

  List<LineTooltipItem> _getTooltipItems(List<LineBarSpot> spots) {
    final dateIndex = spots.first.spotIndex;
    if (dateIndex >= _sortedDates.length) return [];
    final date = _sortedDates[dateIndex];
    final assetsOnDate =
        _effectiveAssetDataByDate[date] ?? _assetData[date] ?? {};
    double total = 0;
    assetsOnDate.forEach((_, value) => total += value);
    final formattedDate = DateFormat('yyyy/MM/dd').format(DateTime.parse(date));
    final formattedTotal =
        NumberFormat.simpleCurrency(locale: 'ja_JP').format(total);
    final tooltips = <LineTooltipItem>[
      LineTooltipItem(
        '$formattedDate\n',
        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      if (_isStacked)
        LineTooltipItem(
          '総資産: $formattedTotal\n',
          const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
    ];
    final sortedAssets = assetsOnDate.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var entry in sortedAssets) {
      final color = _colors[_assetTypes.indexOf(entry.key) % _colors.length];
      final formattedValue =
          NumberFormat.simpleCurrency(locale: 'ja_JP').format(entry.value);
      tooltips.add(
        LineTooltipItem(
          '${entry.key}: $formattedValue',
          TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      );
    }
    return tooltips;
  }

  IconData _getIconForAsset(String type) {
    if (type.contains('現金')) return Icons.wallet;
    if (type.contains('銀行')) return Icons.account_balance;
    if (type.contains('証券')) return Icons.trending_up;
    if (type.contains('ローン') || type.contains('カード')) return Icons.credit_card;
    return Icons.monetization_on;
  }
}
