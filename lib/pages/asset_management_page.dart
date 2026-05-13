// ignore_for_file: require_trailing_commas

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'package:my_web_app/utils/js_interop_vm_stub.dart';
import 'dart:math'; // ← ★この1行を追加してください！

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/debt_repayment_plan.dart';
import 'package:my_web_app/models/kgi_csf_kpi.dart';
import 'package:my_web_app/services/asset_liability_history_service.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_waste_training_ai_service.dart';
import 'package:my_web_app/services/asset_watchlist_service.dart';
import 'package:my_web_app/services/debt_lockdown_service.dart';
import 'package:my_web_app/services/debt_repayment_planner_service.dart';
import 'package:my_web_app/services/smbc_csv_import_service.dart';
import 'package:my_web_app/services/waste_tracking_service.dart';
import 'package:my_web_app/utils/web_image_downloader.dart';
import 'package:my_web_app/widgets/kgi_csf_kpi_panel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

enum AssetManagementInitialFocus {
  overview,
  assets,
  flow,
  subscriptions,
  mustTasks,
}

enum AssetDebtPlannerMode {
  ask,
  code,
}

class AssetManagementPage extends StatefulWidget {
  final AssetManagementInitialFocus initialFocus;
  final bool emphasizeMonthlyFlow;
  final AssetWatchlistService watchlistService;
  final String? entryLabel;
  final String? entryDescription;

  const AssetManagementPage({
    super.key,
    this.initialFocus = AssetManagementInitialFocus.overview,
    this.emphasizeMonthlyFlow = false,
    this.watchlistService = const AssetWatchlistService(),
    this.entryLabel,
    this.entryDescription,
  });

  @override
  State<AssetManagementPage> createState() => _AssetManagementPageState();
}

class _AssetManagementPageState extends State<AssetManagementPage> {
  static const String _bankSheetId =
      '1WZlHr6YWG8ZbT9r-wXtYPEdPT5E4b47PSpNSNl8A1MM';
  static const String _smbcSheetGid = '0';
  static const List<String> _jibunCandidateSheetGids = <String>[
    '0',
  ];

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
  bool _isFetchingSmbc = false;
  bool _isFetchingJibun = false;
  bool _isImportingSmbcCsv = false;

  // --- 資産・負債（ストック）用変数 ---
  Map<String, TextEditingController> _controllers = {};
  List<String> _assetTypes = ['現金'];
  Map<String, Map<String, double>> _assetData = {};
  Map<String, Map<String, double>> _effectiveAssetDataByDate = {};
  Map<String, String?> _lastUpdatedDates = {};
  Map<String, AssetWatchlistEntry> _watchlistByType = {};
  final Map<String, GlobalKey> _assetRowKeys = <String, GlobalKey>{};
  Map<String, double> _monthlyPaymentOverrides = <String, double>{};
  Set<String> _monthlyPaidAccountNames = <String>{};
  Map<String, String> _paymentSourceAccountIds = <String, String>{};
  Map<String, String> _defaultPaymentSourceAccountIds = <String, String>{};
  List<AssetLiabilityIncomePlan> _monthlyIncomePlans =
      <AssetLiabilityIncomePlan>[];
  List<AssetLiabilityRecurringIncomeTemplate> _recurringIncomeTemplates =
      <AssetLiabilityRecurringIncomeTemplate>[];
  List<AssetLiabilityMonthlySnapshot> _monthlySnapshots =
      <AssetLiabilityMonthlySnapshot>[];
  String? _loadedAssetLiabilityMonthKey;
  bool _isSavingAssetLiabilitySnapshot = false;
  final Map<String, TextEditingController> _monthlyPaymentControllers =
      <String, TextEditingController>{};

  // --- グラフデータ ---
  List<LineChartBarData> _lineChartBars = [];
  List<BarChartGroupData> _barChartGroups = [];
  double _maxDailyChange = 0;
  List<String> _sortedDates = [];
  bool _isStacked = true;
  bool _showDailyChange = false;

  // --- 収支（フロー）記録用変数 ---
  // 収支の支払元選択肢: DB の過去履歴から自動追加（初期デフォルトにマージ）
  List<String> _sourceOptions = [
    '[現金]',
    '[銀行口座]',
    '[クレジットカード]',
    '[電子マネー]',
    '[その他]',
  ];
  DateTime _selectedFlowDate = DateTime.now();
  DateTime _selectedFlowHistoryMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  String _selectedSource = '[現金]';
  String _selectedTransferDestination = '[銀行口座]';
  String _selectedFlowType = '支出'; // 支出 / 収入 / 振替
  String? _selectedWasteCategory;
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
  final AssetLiabilityMonthlyStateStore _assetLiabilityMonthlyStateStore =
      const AssetLiabilityMonthlyStateStore();
  final AssetLiabilityPlanningService _assetLiabilityPlanner =
      const AssetLiabilityPlanningService();
  final AssetLiabilityHistoryService _assetLiabilityHistoryService =
      const AssetLiabilityHistoryService();
  final DebtLockdownService _debtLockdownService = const DebtLockdownService();
  final DebtRepaymentPlannerService _debtRepaymentPlanner =
      const DebtRepaymentPlannerService();
  final AssetWasteTrainingAiService _wasteTrainingAiService =
      AssetWasteTrainingAiService();
  bool _isGeneratingDebtPlan = false;
  String? _debtPlanMarkdown;
  DateTime? _debtPlanGeneratedAt;
  DebtExecutionPlan? _debtExecutionPlan;
  AssetDebtPlannerMode _debtPlannerMode = AssetDebtPlannerMode.ask;
  Set<String> _selectedDebtExecutionTaskIds = <String>{};
  bool _isApplyingDebtExecutionTasks = false;
  DebtLockdownSnapshot? _debtLockdownSnapshot;
  bool _isLoadingDebtLockdown = false;
  double? _debtLockdownLoadedForDebt;
  Future<AssetWasteTrainingAiReview>? _wasteTrainingAiReviewFuture;
  String? _wasteTrainingAiReviewKey;

  final List<Color> _colors = [
    const Color(0xFF6366F1),
    const Color(0xFF0D9488),
    const Color(0xFFB91C1C),
    const Color(0xFFFF6B35),
    const Color(0xFF6366F1),
    const Color(0xFF0D9488),
    const Color(0xFFEC4899),
    const Color(0xFFFFC107),
    const Color(0xFF0D9488),
    const Color(0xFF795548),
  ];

  static const double _compactWidthBreakpoint = 420;
  static const List<String> _flowTypeOptions = ['支出', '収入', '振替'];
  static const String _smbcCsvSource = '[三井住友銀行]';
  static final RegExp _flowImportMarkerPattern =
      RegExp(r'\s*\[import:smbc:[^\]]+\]\s*$');
  static final RegExp _smbcImportKeyPattern =
      RegExp(r'\[import:(smbc:[^\]]+)\]\s*$');
  bool get _isCompact =>
      MediaQuery.sizeOf(context).width < _compactWidthBreakpoint;

  @override
  void initState() {
    super.initState();
    _loadDataFromSupabase();
    _loadAssetLiabilityMonthlyState();
    _loadWatchlistEntries();
    _fetchRecentFlows();
    _fetchSubscriptions();
    _fetchMustTasks();
    _deadlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final previousMonthKey =
          AssetLiabilityMonthlyStateStore.formatMonthKey(_now);
      final nextNow = DateTime.now();
      final nextMonthKey =
          AssetLiabilityMonthlyStateStore.formatMonthKey(nextNow);
      setState(() => _now = nextNow);
      if (nextMonthKey != previousMonthKey &&
          nextMonthKey != _loadedAssetLiabilityMonthKey) {
        unawaited(_loadAssetLiabilityMonthlyState());
      }
    });
    _fetchTodayClosing();
    _loadSourceOptionsFromDb();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToInitialFocus();
    });
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    _monthlyPaymentControllers.forEach((_, controller) => controller.dispose());
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

  void _scrollToInitialFocus() {
    switch (widget.initialFocus) {
      case AssetManagementInitialFocus.overview:
        return;
      case AssetManagementInitialFocus.assets:
        _scrollTo(_keyStock);
        return;
      case AssetManagementInitialFocus.flow:
        _scrollTo(_keyFlow);
        return;
      case AssetManagementInitialFocus.subscriptions:
        _scrollTo(_keySubs);
        return;
      case AssetManagementInitialFocus.mustTasks:
        _scrollTo(_keyMust);
        return;
    }
  }

  bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  String _monthKey(DateTime monthStart) =>
      DateFormat('yyyy-MM').format(_monthStart(monthStart));

  String _flowMonthLabel(DateTime month) =>
      DateFormat('yyyy/MM').format(_monthStart(month));

  String get _defaultFlowSource =>
      _sourceOptions.contains('[その他]') ? '[その他]' : _sourceOptions.last;

  String _stripFlowImportMarker(String description) =>
      description.replaceFirst(_flowImportMarkerPattern, '').trim();

  String? _extractSmbcImportKey(String description) {
    final match = _smbcImportKeyPattern.firstMatch(description.trim());
    return match?.group(1);
  }

  String _withFlowImportMarker(String description, String importKey) =>
      '${description.trim()} [import:$importKey]';

  String _sourceLabel(String source) =>
      source.replaceAll('[', '').replaceAll(']', '').trim();

  List<String> _transferDestinationOptions(
    String source, {
    String? include,
  }) {
    final options = [
      for (final item in _sourceOptions)
        if (item != source) item,
    ];
    if (include != null &&
        include.isNotEmpty &&
        include != source &&
        !options.contains(include)) {
      options.add(include);
    }
    if (options.isEmpty) {
      options.add(source);
    }
    return options;
  }

  String _resolvedTransferDestination(
    String source, {
    String? preferred,
  }) {
    if (preferred != null && preferred.isNotEmpty && preferred != source) {
      return preferred;
    }
    final options = _transferDestinationOptions(source, include: preferred);
    return options.first;
  }

  bool _isIncomeActionType(String actionType) => actionType == 'conquer';

  bool _isExpenseActionType(String actionType) => actionType == 'expense';

  bool _isTransferActionType(String actionType) => actionType == 'transfer';

  bool get _isExpenseFlowSelected => _selectedFlowType == '支出';

  String _flowAmountPrefix(String actionType) {
    if (_isIncomeActionType(actionType)) return '+';
    if (_isTransferActionType(actionType)) return '↔';
    return '-';
  }

  IconData _flowActionIcon(String actionType) {
    if (_isIncomeActionType(actionType)) return Icons.add_circle;
    if (_isTransferActionType(actionType)) return Icons.swap_horiz;
    return Icons.remove_circle;
  }

  Color _flowActionColor(String actionType) {
    if (_isIncomeActionType(actionType)) return const Color(0xFF0D9488);
    if (_isTransferActionType(actionType)) return const Color(0xFF6366F1);
    return const Color(0xFFB91C1C);
  }

  void _updateSelectedFlowType(String label) {
    setState(() {
      _selectedFlowType = label;
      if (label == '振替') {
        _selectedTransferDestination = _resolvedTransferDestination(
          _selectedSource,
          preferred: _selectedTransferDestination,
        );
      }
      if (label != '支出') {
        _selectedWasteCategory = null;
      }
    });
  }

  void _updateSelectedSource(String source) {
    setState(() {
      _selectedSource = source;
      if (_selectedFlowType == '振替') {
        _selectedTransferDestination = _resolvedTransferDestination(
          source,
          preferred: _selectedTransferDestination,
        );
      }
    });
  }

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

  AssetWasteTrainingSnapshot _buildWasteTrainingSnapshot() {
    final currentMonth = _monthStart(_now);
    final flows = _flowsForMonth(currentMonth);
    var totalExpense = 0;
    var wasteExpense = 0;
    var expenseEntryCount = 0;
    var wasteEntryCount = 0;
    final wasteDateKeys = <String>{};

    for (final item in flows) {
      final actionType = item['action_type']?.toString() ?? '';
      if (!_isExpenseActionType(actionType)) {
        continue;
      }
      final amount = ((item['amount'] as num?)?.toDouble() ?? 0).abs().round();
      totalExpense += amount;
      expenseEntryCount += 1;

      final description = item['description']?.toString() ?? '';
      final parsed = _parseFlowDescription(description, actionType: actionType);
      if (parsed.wasteCategory == null) {
        continue;
      }

      wasteExpense += amount;
      wasteEntryCount += 1;
      final occurredAt = DateTime.tryParse(
        item['occurred_at']?.toString() ?? '',
      )?.toLocal();
      if (occurredAt != null) {
        wasteDateKeys.add(_dateOnly(occurredAt));
      }
    }

    final elapsedDays = _isSameMonth(currentMonth, _now)
        ? _now.day
        : DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final lockdown = _debtLockdownSnapshot;
    return AssetWasteTrainingSnapshot(
      month: currentMonth,
      monitoredAt: _now,
      totalExpense: totalExpense,
      wasteExpense: wasteExpense,
      expenseEntryCount: expenseEntryCount,
      wasteEntryCount: wasteEntryCount,
      noWasteDays: max(0, elapsedDays - wasteDateKeys.length),
      elapsedDays: max(1, elapsedDays),
      ruleCompletedCount: lockdown?.completedRuleCount ?? 0,
      ruleTargetCount:
          lockdown?.rules.length ?? DebtLockdownService.builtinRules.length,
      todayViolationCount: lockdown?.todayViolations.length ?? 0,
      compliantStreakDays: lockdown?.currentCompliantStreakDays ?? 0,
      lockdownActive: lockdown?.isActive ?? false,
    );
  }

  KgiCsfKpiPlan _buildWasteTrainingPlan(
    AssetWasteTrainingSnapshot snapshot,
  ) {
    final zeroWasteTarget = max(1, snapshot.elapsedDays);
    final ruleTarget = max(1, snapshot.ruleTargetCount);
    final violationClear = snapshot.todayViolationCount == 0 ? 1 : 0;
    return KgiCsfKpiPlan(
      domain: '資産管理 / 浪費抑制トレーニング',
      kgi: '浪費しない力を鍛え、判断力と純資産を高める',
      actualLabel: '${snapshot.disciplineScore}点',
      targetLabel: '100点',
      progress: snapshot.trainingProgress,
      metrics: <KgiCsfKpiMetric>[
        KgiCsfKpiMetric.number(
          csf: '欲望を記録で可視化する',
          kpi: '今月の浪費ゼロ日',
          actual: snapshot.noWasteDays,
          target: zeroWasteTarget,
          unit: '日',
        ),
        KgiCsfKpiMetric.number(
          csf: '目的外支出を即時に減らす',
          kpi: '非浪費支出率',
          actual: snapshot.wasteControlScore,
          target: 100,
          unit: '点',
        ),
        KgiCsfKpiMetric.number(
          csf: '毎日レビューして改善する',
          kpi: 'ロックダウン日課達成',
          actual: snapshot.ruleCompletedCount,
          target: ruleTarget,
          unit: '件',
        ),
        KgiCsfKpiMetric.number(
          csf: '逸脱をその日のうちに戻す',
          kpi: '本日の違反ゼロ',
          actual: violationClear,
          target: 1,
          unit: '日',
        ),
      ],
    );
  }

  Future<AssetWasteTrainingAiReview> _wasteTrainingReviewFor(
    AssetWasteTrainingSnapshot snapshot,
  ) {
    final key = snapshot.cacheKey;
    final current = _wasteTrainingAiReviewFuture;
    if (current == null || _wasteTrainingAiReviewKey != key) {
      _wasteTrainingAiReviewKey = key;
      _wasteTrainingAiReviewFuture =
          _wasteTrainingAiService.generateReview(snapshot);
    }
    return _wasteTrainingAiReviewFuture!;
  }

  String _wasteTrainingNextAction(AssetWasteTrainingSnapshot snapshot) {
    if (snapshot.todayViolationCount > 0) {
      return '今日の逸脱を1件ずつ見直し、次に同じ刺激が来たときの代替行動を1つだけ決めてください。';
    }
    if (snapshot.wasteEntryCount > 0) {
      return '今月の浪費カテゴリを見て、最も金額が大きい1カテゴリだけを翌7日間の禁止ルールにしてください。';
    }
    if (!snapshot.lockdownActive) {
      return '浪費抑制を毎日の訓練にするため、借金ロックダウンを有効化して日課チェックを開始してください。';
    }
    if (snapshot.ruleCompletedCount < snapshot.ruleTargetCount) {
      return '今日のロックダウン日課を未達成の項目から1つだけ終わらせ、明日の判断力を先に守ってください。';
    }
    return '浪費ゼロの判断が続いています。次は固定費かサブスクを1件見直して、訓練成果を純資産へ移してください。';
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

  Map<String, double> _latestSnapshotForDisplay() {
    final dateKeys = <String>{
      ..._assetData.keys,
      ..._effectiveAssetDataByDate.keys,
    }.toList()
      ..sort();
    if (dateKeys.isEmpty) return {};

    final latestDate = dateKeys.last;
    final snapshot = _effectiveAssetDataByDate[latestDate] ??
        _assetData[latestDate] ??
        const <String, double>{};
    return Map<String, double>.from(snapshot);
  }

  Future<void> _loadAssetLiabilityMonthlyState() async {
    try {
      final targetMonth = _now;
      final monthKey =
          AssetLiabilityMonthlyStateStore.formatMonthKey(targetMonth);
      final state =
          await _assetLiabilityMonthlyStateStore.loadMonth(targetMonth);
      final defaultSources =
          await _assetLiabilityMonthlyStateStore.loadDefaultPaymentSources();
      final templates =
          await _assetLiabilityMonthlyStateStore.loadRecurringIncomeTemplates();
      final monthlySnapshots =
          await _assetLiabilityMonthlyStateStore.loadMonthlySnapshots();
      final incomePlansWithTemplates =
          AssetLiabilityMonthlyStateStore.applyRecurringIncomeTemplates(
        month: targetMonth,
        templates: templates,
        existingPlans: state.incomePlans,
      );
      final generatedTemplatePlans =
          incomePlansWithTemplates.length != state.incomePlans.length;
      if (!mounted) return;
      setState(() {
        _monthlyPaymentOverrides = Map<String, double>.from(
          state.paymentOverrides,
        );
        _monthlyPaidAccountNames = Set<String>.from(state.paidAccountNames);
        _paymentSourceAccountIds = Map<String, String>.from(
          state.paymentSourceAccountIds,
        );
        _defaultPaymentSourceAccountIds = Map<String, String>.from(
          defaultSources,
        );
        _monthlyIncomePlans = List<AssetLiabilityIncomePlan>.from(
          incomePlansWithTemplates,
        );
        _recurringIncomeTemplates =
            List<AssetLiabilityRecurringIncomeTemplate>.from(templates);
        _monthlySnapshots =
            List<AssetLiabilityMonthlySnapshot>.from(monthlySnapshots);
        _loadedAssetLiabilityMonthKey = monthKey;
        _syncMonthlyPaymentControllers();
      });
      if (generatedTemplatePlans) {
        unawaited(_saveAssetLiabilityMonthlyState());
      }
    } catch (e) {
      debugPrint('Error loading asset liability monthly state: $e');
    }
  }

  Future<void> _saveAssetLiabilityMonthlyState() async {
    try {
      await _assetLiabilityMonthlyStateStore.saveMonth(
        month: _now,
        state: AssetLiabilityMonthlyState(
          paymentOverrides: Map<String, double>.from(_monthlyPaymentOverrides),
          paidAccountNames: Set<String>.from(_monthlyPaidAccountNames),
          paymentSourceAccountIds: Map<String, String>.from(
            _paymentSourceAccountIds,
          ),
          incomePlans: List<AssetLiabilityIncomePlan>.from(
            _monthlyIncomePlans,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error saving asset liability monthly state: $e');
    }
  }

  Future<void> _saveCurrentAssetLiabilitySnapshot(
    AssetLiabilityWorkbook workbook,
  ) async {
    setState(() {
      _isSavingAssetLiabilitySnapshot = true;
    });
    try {
      final monthKey = AssetLiabilityMonthlyStateStore.formatMonthKey(_now);
      final snapshot = _assetLiabilityHistoryService.buildSnapshot(
        monthKey: monthKey,
        workbook: workbook,
        savedAt: DateTime.now(),
      );
      await _assetLiabilityMonthlyStateStore.saveMonthlySnapshot(snapshot);
      final snapshots =
          await _assetLiabilityMonthlyStateStore.loadMonthlySnapshots();
      if (!mounted) return;
      setState(() {
        _monthlySnapshots = List<AssetLiabilityMonthlySnapshot>.from(snapshots);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$monthKey のスナップショットを保存しました')),
      );
    } catch (e) {
      debugPrint('Error saving asset liability monthly snapshot: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('スナップショット保存に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAssetLiabilitySnapshot = false;
        });
      }
    }
  }

  void _downloadAssetLiabilityCsvBundle(AssetLiabilityWorkbook workbook) {
    final bundle = _assetLiabilityHistoryService.buildCsvExportBundle(
      monthlySnapshots: _monthlySnapshots,
      workbook: workbook,
    );
    final monthKey = AssetLiabilityMonthlyStateStore.formatMonthKey(_now);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    downloadCsvFile(
      bundle.monthlyHistoryCsv,
      'asset_liability_monthly_history_${monthKey}_$stamp.csv',
    );
    downloadCsvFile(
      bundle.paymentScheduleCsv,
      'asset_liability_payment_schedule_${monthKey}_$stamp.csv',
    );
    downloadCsvFile(
      bundle.incomePlansCsv,
      'asset_liability_income_plans_${monthKey}_$stamp.csv',
    );
    downloadCsvFile(
      bundle.accountCashflowCsv,
      'asset_liability_account_cashflow_${monthKey}_$stamp.csv',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('資産/負債ボードのCSV 4種類を出力しました')),
    );
  }

  void _scheduleAssetLiabilityStateIdMigration(
    AssetLiabilityWorkbook workbook,
  ) {
    final legacyKeyToAccountId = <String, String>{};
    for (final row in workbook.debtMasterRows) {
      legacyKeyToAccountId[row.name] = row.id;
      legacyKeyToAccountId[row.name.trim()] = row.id;
    }
    final migrated = AssetLiabilityMonthlyStateStore.migrateLegacyKeys(
      state: AssetLiabilityMonthlyState(
        paymentOverrides: Map<String, double>.from(_monthlyPaymentOverrides),
        paidAccountNames: Set<String>.from(_monthlyPaidAccountNames),
        paymentSourceAccountIds: Map<String, String>.from(
          _paymentSourceAccountIds,
        ),
        incomePlans: List<AssetLiabilityIncomePlan>.from(_monthlyIncomePlans),
      ),
      legacyKeyToAccountId: legacyKeyToAccountId,
    );
    final migratedDefaultSources = _migrateStringMapKeysAndValues(
      _defaultPaymentSourceAccountIds,
      legacyKeyToAccountId,
    );
    if (_sameDoubleMap(
          _monthlyPaymentOverrides,
          migrated.paymentOverrides,
        ) &&
        _sameStringSet(
          _monthlyPaidAccountNames,
          migrated.paidAccountNames,
        ) &&
        _sameStringMap(
          _paymentSourceAccountIds,
          migrated.paymentSourceAccountIds,
        ) &&
        _sameStringMap(
          _defaultPaymentSourceAccountIds,
          migratedDefaultSources,
        )) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _monthlyPaymentOverrides = Map<String, double>.from(
          migrated.paymentOverrides,
        );
        _monthlyPaidAccountNames = Set<String>.from(migrated.paidAccountNames);
        _paymentSourceAccountIds = Map<String, String>.from(
          migrated.paymentSourceAccountIds,
        );
        _defaultPaymentSourceAccountIds = Map<String, String>.from(
          migratedDefaultSources,
        );
        _syncMonthlyPaymentControllers();
      });
      unawaited(_saveAssetLiabilityMonthlyState());
      unawaited(_saveDefaultPaymentSources());
    });
  }

  Map<String, String> _migrateStringMapKeysAndValues(
    Map<String, String> source,
    Map<String, String> legacyKeyToAccountId,
  ) {
    final migrated = <String, String>{};
    for (final entry in source.entries) {
      final key = legacyKeyToAccountId[entry.key] ?? entry.key;
      final value = legacyKeyToAccountId[entry.value] ?? entry.value;
      migrated[key] = value;
    }
    return migrated;
  }

  bool _sameDoubleMap(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  bool _sameStringSet(Set<String> a, Set<String> b) {
    if (a.length != b.length) {
      return false;
    }
    return a.containsAll(b);
  }

  bool _sameStringMap(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  void _syncMonthlyPaymentControllers() {
    for (final entry in _monthlyPaymentControllers.entries) {
      final hasOverride = _monthlyPaymentOverrides.containsKey(entry.key);
      final amount = _monthlyPaymentOverrides[entry.key];
      final text =
          hasOverride && amount != null ? amount.round().toString() : '';
      if (entry.value.text != text) {
        entry.value.text = text;
      }
    }
  }

  TextEditingController _monthlyPaymentControllerFor(
    AssetLiabilityDebtRow row,
  ) {
    return _monthlyPaymentControllers.putIfAbsent(
      row.id,
      () => TextEditingController(
        text: row.manualPaymentAmount == null
            ? ''
            : row.manualPaymentAmount!.round().toString(),
      ),
    );
  }

  void _updateMonthlyPaymentOverride(String accountId, String rawValue) {
    final normalized = rawValue.replaceAll(',', '').trim();
    final amount = normalized.isEmpty ? null : double.tryParse(normalized);
    setState(() {
      if (amount == null || amount < 0) {
        _monthlyPaymentOverrides.remove(accountId);
      } else {
        _monthlyPaymentOverrides[accountId] = amount;
      }
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  void _clearMonthlyPaymentOverride(String accountId) {
    _monthlyPaymentControllers[accountId]?.clear();
    setState(() {
      _monthlyPaymentOverrides.remove(accountId);
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  void _toggleMonthlyPaymentPaid(String accountId, bool paid) {
    setState(() {
      if (paid) {
        _monthlyPaidAccountNames.add(accountId);
      } else {
        _monthlyPaidAccountNames.remove(accountId);
      }
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  void _updatePaymentSourceAccount(
      String liabilityId, String? sourceAccountId) {
    setState(() {
      if (sourceAccountId == null || sourceAccountId.isEmpty) {
        _paymentSourceAccountIds.remove(liabilityId);
      } else {
        _paymentSourceAccountIds[liabilityId] = sourceAccountId;
      }
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  Future<void> _saveDefaultPaymentSources() async {
    try {
      await _assetLiabilityMonthlyStateStore.saveDefaultPaymentSources(
        Map<String, String>.from(_defaultPaymentSourceAccountIds),
      );
    } catch (e) {
      debugPrint('Error saving asset liability default sources: $e');
    }
  }

  Future<void> _saveRecurringIncomeTemplates() async {
    try {
      await _assetLiabilityMonthlyStateStore.saveRecurringIncomeTemplates(
        List<AssetLiabilityRecurringIncomeTemplate>.from(
          _recurringIncomeTemplates,
        ),
      );
    } catch (e) {
      debugPrint('Error saving recurring income templates: $e');
    }
  }

  void _updateDefaultPaymentSourceAccount(
    String liabilityId,
    String? sourceAccountId,
  ) {
    setState(() {
      if (sourceAccountId == null || sourceAccountId.isEmpty) {
        _defaultPaymentSourceAccountIds.remove(liabilityId);
      } else {
        _defaultPaymentSourceAccountIds[liabilityId] = sourceAccountId;
      }
    });
    unawaited(_saveDefaultPaymentSources());
  }

  Future<void> _copyPreviousMonthSettings() async {
    final copied =
        await _assetLiabilityMonthlyStateStore.copyPreviousMonthToMonth(_now);
    final incomePlansWithTemplates =
        AssetLiabilityMonthlyStateStore.applyRecurringIncomeTemplates(
      month: _now,
      templates: _recurringIncomeTemplates,
      existingPlans: copied.incomePlans,
    );

    if (!mounted) return;
    setState(() {
      _monthlyPaymentOverrides = Map<String, double>.from(
        copied.paymentOverrides,
      );
      _monthlyPaidAccountNames = <String>{};
      _paymentSourceAccountIds = Map<String, String>.from(
        copied.paymentSourceAccountIds,
      );
      _monthlyIncomePlans = incomePlansWithTemplates;
      _syncMonthlyPaymentControllers();
    });
    unawaited(_saveAssetLiabilityMonthlyState());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('前月設定をコピーしました。支払済み・入金済み状態はコピーしていません。'),
      ),
    );
  }

  String _generatedPlanIdForTemplate(
    AssetLiabilityRecurringIncomeTemplate template,
    DateTime month,
  ) {
    return 'recurring_${template.id}_${AssetLiabilityMonthlyStateStore.formatMonthKey(month)}';
  }

  AssetLiabilityIncomePlan _incomePlanForTemplate(
    AssetLiabilityRecurringIncomeTemplate template,
    DateTime month, {
    bool received = false,
  }) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return AssetLiabilityIncomePlan(
      id: _generatedPlanIdForTemplate(template, month),
      date: DateTime(
        month.year,
        month.month,
        min(template.dayOfMonth.clamp(1, 31).toInt(), lastDay),
      ),
      name: template.name,
      amount: template.amount,
      destinationAccountId: template.destinationAccountId,
      destinationAccountName: template.destinationAccountName,
      received: received,
    );
  }

  void _toggleIncomeReceived(String incomeId, bool received) {
    setState(() {
      _monthlyIncomePlans = [
        for (final plan in _monthlyIncomePlans)
          plan.id == incomeId
              ? AssetLiabilityIncomePlan(
                  id: plan.id,
                  date: plan.date,
                  name: plan.name,
                  amount: plan.amount,
                  destinationAccountId: plan.destinationAccountId,
                  destinationAccountName: plan.destinationAccountName,
                  received: received,
                )
              : plan,
      ];
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  void _deleteIncomePlan(String incomeId) {
    setState(() {
      _monthlyIncomePlans = _monthlyIncomePlans
          .where((plan) => plan.id != incomeId)
          .toList(growable: false);
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  void _deleteRecurringIncomeTemplate(String templateId) {
    final currentMonthKey =
        AssetLiabilityMonthlyStateStore.formatMonthKey(_now);
    setState(() {
      _recurringIncomeTemplates = _recurringIncomeTemplates
          .where((template) => template.id != templateId)
          .toList(growable: false);
      _monthlyIncomePlans = _monthlyIncomePlans
          .where(
            (plan) => plan.id != 'recurring_${templateId}_$currentMonthKey',
          )
          .toList(growable: false);
    });
    unawaited(_saveRecurringIncomeTemplates());
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  Future<void> _showIncomePlanDialog(
    AssetLiabilityWorkbook workbook, {
    AssetLiabilityIncomePlan? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.round().toString(),
    );
    var selectedDate = existing?.date ?? _now;
    var selectedDestinationId = existing?.destinationAccountId;
    var received = existing?.received ?? false;
    final destinationOptions = _paymentSourceAccountOptions(workbook);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? '収入予定を追加' : '収入予定を編集'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('日付'),
                      subtitle:
                          Text(DateFormat('yyyy/MM/dd').format(selectedDate)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(_now.year, _now.month, 1),
                          lastDate: DateTime(_now.year, _now.month + 1, 0),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '名称'),
                    ),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                      ],
                      decoration: const InputDecoration(labelText: '金額'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDestinationId ?? '',
                      decoration: const InputDecoration(labelText: '入金先口座'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('未設定'),
                        ),
                        for (final account in destinationOptions)
                          DropdownMenuItem<String>(
                            value: account.id,
                            child: Text(account.name),
                          ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedDestinationId =
                              value == null || value.isEmpty ? null : value;
                        });
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: received,
                      onChanged: (value) {
                        setDialogState(() => received = value ?? false);
                      },
                      title: const Text('入金済み'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(
                      amountController.text.replaceAll(',', '').trim(),
                    );
                    if (name.isEmpty || amount == null || amount <= 0) {
                      return;
                    }
                    String? destinationName;
                    for (final account in destinationOptions) {
                      if (account.id == selectedDestinationId) {
                        destinationName = account.name;
                        break;
                      }
                    }
                    final plan = AssetLiabilityIncomePlan(
                      id: existing?.id ??
                          'income_${DateTime.now().microsecondsSinceEpoch}',
                      date: selectedDate,
                      name: name,
                      amount: amount,
                      destinationAccountId: selectedDestinationId,
                      destinationAccountName: destinationName,
                      received: received,
                    );
                    setState(() {
                      _monthlyIncomePlans = [
                        for (final current in _monthlyIncomePlans)
                          if (current.id != plan.id) current,
                        plan,
                      ]..sort((a, b) => a.date.compareTo(b.date));
                    });
                    unawaited(_saveAssetLiabilityMonthlyState());
                    Navigator.of(context).pop();
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    amountController.dispose();
  }

  Future<void> _showRecurringIncomeTemplateDialog(
    AssetLiabilityWorkbook workbook, {
    AssetLiabilityRecurringIncomeTemplate? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.round().toString(),
    );
    final dayController = TextEditingController(
      text: existing == null ? '' : existing.dayOfMonth.toString(),
    );
    var selectedDestinationId = existing?.destinationAccountId;
    final destinationOptions = _paymentSourceAccountOptions(workbook);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? '定期収入を追加' : '定期収入を編集'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '名称'),
                    ),
                    TextField(
                      controller: dayController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(labelText: '毎月の日付'),
                    ),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                      ],
                      decoration: const InputDecoration(labelText: '金額'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDestinationId ?? '',
                      decoration: const InputDecoration(labelText: '入金先口座'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('未設定'),
                        ),
                        for (final account in destinationOptions)
                          DropdownMenuItem<String>(
                            value: account.id,
                            child: Text(account.name),
                          ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedDestinationId =
                              value == null || value.isEmpty ? null : value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final day = int.tryParse(dayController.text.trim());
                    final amount = double.tryParse(
                      amountController.text.replaceAll(',', '').trim(),
                    );
                    if (name.isEmpty ||
                        day == null ||
                        day < 1 ||
                        amount == null ||
                        amount <= 0) {
                      return;
                    }
                    String? destinationName;
                    for (final account in destinationOptions) {
                      if (account.id == selectedDestinationId) {
                        destinationName = account.name;
                        break;
                      }
                    }
                    final template = AssetLiabilityRecurringIncomeTemplate(
                      id: existing?.id ??
                          'income_template_${DateTime.now().microsecondsSinceEpoch}',
                      dayOfMonth: day.clamp(1, 31).toInt(),
                      name: name,
                      amount: amount,
                      destinationAccountId: selectedDestinationId,
                      destinationAccountName: destinationName,
                    );
                    final generatedId =
                        _generatedPlanIdForTemplate(template, _now);
                    final previousGeneratedPlan =
                        _monthlyIncomePlans.where((plan) {
                      return plan.id == generatedId;
                    }).toList();
                    final generatedPlan = _incomePlanForTemplate(
                      template,
                      _now,
                      received: previousGeneratedPlan.isNotEmpty
                          ? previousGeneratedPlan.first.received
                          : false,
                    );
                    setState(() {
                      _recurringIncomeTemplates = [
                        for (final current in _recurringIncomeTemplates)
                          if (current.id != template.id) current,
                        template,
                      ]..sort((a, b) {
                          final day = a.dayOfMonth.compareTo(b.dayOfMonth);
                          if (day != 0) {
                            return day;
                          }
                          return a.name.compareTo(b.name);
                        });
                      _monthlyIncomePlans = [
                        for (final current in _monthlyIncomePlans)
                          if (current.id != generatedId) current,
                        generatedPlan,
                      ]..sort((a, b) => a.date.compareTo(b.date));
                    });
                    unawaited(_saveRecurringIncomeTemplates());
                    unawaited(_saveAssetLiabilityMonthlyState());
                    Navigator.of(context).pop();
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    amountController.dispose();
    dayController.dispose();
  }

  List<AssetLiabilityAccount> _paymentSourceAccountOptions(
    AssetLiabilityWorkbook workbook,
  ) {
    return workbook.accounts
        .where(
          (account) =>
              account.balance > 0 &&
              (account.kind == AssetLiabilityAccountKind.cash ||
                  account.kind == AssetLiabilityAccountKind.deposit),
        )
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
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

  void _ensureDebtLockdownSnapshotLoaded(double remainingDebt) {
    final loadedForDebt = _debtLockdownLoadedForDebt;
    if (_isLoadingDebtLockdown) {
      return;
    }
    if (loadedForDebt != null && (loadedForDebt - remainingDebt).abs() < 1) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLoadingDebtLockdown) {
        return;
      }
      final latestLoadedDebt = _debtLockdownLoadedForDebt;
      if (latestLoadedDebt != null &&
          (latestLoadedDebt - remainingDebt).abs() < 1) {
        return;
      }
      _loadDebtLockdownSnapshot(remainingDebt);
    });
  }

  Future<void> _loadDebtLockdownSnapshot(double remainingDebt) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingDebtLockdown = true;
    });

    try {
      final snapshot = await _debtLockdownService.loadSnapshot(
        remainingDebt: remainingDebt,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _debtLockdownSnapshot = snapshot;
        _debtLockdownLoadedForDebt = remainingDebt;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDebtLockdown = false;
        });
      }
    }
  }

  Future<void> _setDebtLockdownEnabled(
    bool enabled,
    double remainingDebt,
  ) async {
    final snapshot = await _debtLockdownService.setEnabled(
      enabled,
      remainingDebt: remainingDebt,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _debtLockdownSnapshot = snapshot;
      _debtLockdownLoadedForDebt = remainingDebt;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled ? '完済までの収監モードを開始しました' : '完済までの収監モードを中断しました',
        ),
      ),
    );
  }

  Future<void> _toggleDebtLockdownRule(
    String ruleId,
    bool completed,
    double remainingDebt,
  ) async {
    final snapshot = await _debtLockdownService.toggleRule(
      ruleId,
      completed,
      remainingDebt: remainingDebt,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _debtLockdownSnapshot = snapshot;
      _debtLockdownLoadedForDebt = remainingDebt;
    });
  }

  Future<void> _recordDebtLockdownViolation({
    required String category,
    required String note,
    required double amount,
    required double remainingDebt,
  }) async {
    final snapshot = await _debtLockdownService.recordViolation(
      category: category,
      note: note,
      amount: amount,
      remainingDebt: remainingDebt,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _debtLockdownSnapshot = snapshot;
      _debtLockdownLoadedForDebt = remainingDebt;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('違反を記録しました')),
    );
  }

  Future<void> _showDebtLockdownViolationDialog(double remainingDebt) async {
    final categories = DebtLockdownService.violationCategories;
    var selectedCategory = categories.first;
    final noteController = TextEditingController();
    final amountController = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('収監モード違反を記録'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: '違反カテゴリ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '何が起きたか',
                      hintText: '例: 飲み会でハイボールを2杯飲んだ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '浪費額（任意）',
                      hintText: '0',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('記録'),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true) {
        return;
      }

      final note = noteController.text.trim();
      if (note.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('違反内容を入力してください')),
        );
        return;
      }

      final amount =
          double.tryParse(amountController.text.replaceAll(',', '').trim()) ??
              0;
      await _recordDebtLockdownViolation(
        category: selectedCategory,
        note: note,
        amount: amount,
        remainingDebt: remainingDebt,
      );
    } finally {
      noteController.dispose();
      amountController.dispose();
    }
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
      final executionPlan = _debtRepaymentPlanner.buildExecutionPlan(
        input: input,
        result: result,
      );

      if (!mounted) return;
      setState(() {
        _debtPlanMarkdown = result.markdown;
        _debtExecutionPlan = executionPlan;
        _selectedDebtExecutionTaskIds =
            executionPlan.tasks.map((task) => task.id).toSet();
        _debtPlannerMode = AssetDebtPlannerMode.ask;
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

  List<DebtExecutionTask> get _selectedDebtExecutionTasks {
    final plan = _debtExecutionPlan;
    if (plan == null) return const <DebtExecutionTask>[];
    return plan.tasks
        .where((task) => _selectedDebtExecutionTaskIds.contains(task.id))
        .toList(growable: false);
  }

  void _toggleDebtExecutionTask(String taskId, bool selected) {
    setState(() {
      if (selected) {
        _selectedDebtExecutionTaskIds.add(taskId);
      } else {
        _selectedDebtExecutionTaskIds.remove(taskId);
      }
    });
  }

  void _selectAllDebtExecutionTasks() {
    final plan = _debtExecutionPlan;
    if (plan == null) return;
    setState(() {
      _selectedDebtExecutionTaskIds = plan.tasks.map((task) => task.id).toSet();
    });
  }

  void _clearDebtExecutionTaskSelection() {
    setState(() {
      _selectedDebtExecutionTaskIds = <String>{};
    });
  }

  String _mustTaskSignatureFromMap(Map<String, dynamic> task) {
    final title = (task['title'] ?? '').toString().trim().toLowerCase();
    final deadline =
        DateTime.tryParse(task['deadline']?.toString() ?? '')?.toLocal();
    final deadlineKey =
        deadline == null ? '' : DateFormat('yyyy-MM-dd').format(deadline);
    return '$title|$deadlineKey';
  }

  String _mustTaskSignatureFromExecutionTask(DebtExecutionTask task) {
    final deadlineKey = DateFormat('yyyy-MM-dd').format(task.dueDate);
    return '${task.title.trim().toLowerCase()}|$deadlineKey';
  }

  bool _isExecutionTaskAlreadyAdded(DebtExecutionTask task) {
    final signature = _mustTaskSignatureFromExecutionTask(task);
    return _mustTasks.any(
      (item) => _mustTaskSignatureFromMap(item) == signature,
    );
  }

  Future<void> _applyDebtExecutionTasksToMustTasks() async {
    final selectedTasks = _selectedDebtExecutionTasks;
    if (selectedTasks.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('追加する Code タスクを選択してください')),
      );
      return;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログイン後に Code タスクを追加できます')),
      );
      return;
    }

    final existingSignatures =
        _mustTasks.map(_mustTaskSignatureFromMap).toSet();
    final rows = <Map<String, dynamic>>[];
    final insertedIds = <String>[];
    var skippedCount = 0;

    for (final task in selectedTasks) {
      final signature = _mustTaskSignatureFromExecutionTask(task);
      if (existingSignatures.contains(signature)) {
        skippedCount++;
        continue;
      }
      existingSignatures.add(signature);
      rows.add({
        'user_id': userId,
        'title': task.title,
        'deadline': task.dueDate.toUtc().toIso8601String(),
        'is_completed': false,
      });
      insertedIds.add(task.id);
    }

    if (rows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('選択した Code タスクはすでに必須タスクへ追加済みです')),
      );
      return;
    }

    setState(() => _isApplyingDebtExecutionTasks = true);
    try {
      await _supabase.from('must_tasks').insert(rows);
      await _fetchMustTasks();
      await _fetchTodayClosing();

      if (!mounted) return;
      setState(() {
        _selectedDebtExecutionTaskIds.removeAll(insertedIds);
      });
      _scrollTo(_keyMust);
      final suffix = skippedCount > 0 ? '（重複 $skippedCount 件を除外）' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Code タスクを ${rows.length} 件追加しました$suffix'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code タスクの追加に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplyingDebtExecutionTasks = false);
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
    int totalTransfer = 0;
    for (final f in currentMonthFlows) {
      final amt = (f['amount'] as num?)?.toInt() ?? 0;
      if (f['action_type'] == 'conquer') totalIncome += amt;
      if (f['action_type'] == 'expense') totalExpense += amt;
      if (f['action_type'] == 'transfer') totalTransfer += amt;
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
    buf.writeln('- 振替合計: ¥${NumberFormat('#,###').format(totalTransfer)}');
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

  Uri _bankSheetCsvUri(String gid) {
    return Uri.https(
      'docs.google.com',
      '/spreadsheets/d/$_bankSheetId/export',
      <String, String>{
        'format': 'csv',
        'gid': gid,
      },
    );
  }

  Future<List<List<String>>> _fetchBankSheetRows(String gid) async {
    final response = await http.get(_bankSheetCsvUri(gid));
    if (response.statusCode != 200) {
      throw Exception('Googleシート取得 HTTP ${response.statusCode}');
    }
    final csvData = utf8.decode(response.bodyBytes);
    return _parseCsvRows(csvData);
  }

  List<List<String>> _parseCsvRows(String csvData) {
    return const LineSplitter()
        .convert(csvData)
        .map(_parseCsvLine)
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList();
  }

  List<String> _parseCsvLine(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }

  double? _parseSheetAmount(String value) {
    final normalized = value
        .trim()
        .replaceAll(',', '')
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll('円', '')
        .replaceAll('−', '-')
        .replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  double? _extractSmbcBalance(List<List<String>> rows) {
    for (final row in rows) {
      if (row.length >= 6 &&
          RegExp(r'^\d{4}/\d{1,2}/\d{1,2}$').hasMatch(row[1].trim())) {
        final balance = _parseSheetAmount(row[5]);
        if (balance != null) {
          return balance;
        }
      }
    }
    return null;
  }

  double? _extractJibunBalance(List<List<String>> rows) {
    for (final row in rows) {
      if (row.length >= 5 &&
          RegExp(r'^\d{4}年\d{1,2}月\d{1,2}日$').hasMatch(row[0].trim())) {
        final balance = _parseSheetAmount(row[4]);
        if (balance != null) {
          return balance;
        }
      }
    }
    return null;
  }

  void _applyFetchedAssetBalance({
    required String assetName,
    required double balance,
  }) {
    if (!_assetTypes.contains(assetName)) {
      _assetTypes.add(assetName);
      _initControllers();
      _updateLastUpdatedDates();
      _sortAssetTypes();
    }
    _controllers[assetName]?.text = balance.toStringAsFixed(0);
  }

  void _showSheetFetchResult({
    required String assetName,
    required double balance,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$assetNameの残高をシートから取得しました: ¥${NumberFormat('#,###').format(balance.round())}',
        ),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _fetchSmbcDataFromSheet() async {
    setState(() => _isFetchingSmbc = true);
    try {
      final rows = await _fetchBankSheetRows(_smbcSheetGid);
      final balance = _extractSmbcBalance(rows);
      if (balance == null) {
        throw Exception('三井住友銀行の残高データが見つかりませんでした');
      }
      const smbcName = '三井住友銀行';
      setState(() {
        _applyFetchedAssetBalance(assetName: smbcName, balance: balance);
      });
      if (mounted) {
        _showSheetFetchResult(
          assetName: smbcName,
          balance: balance,
          color: const Color(0xFF047857),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データ取得に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingSmbc = false);
      }
    }
  }

  Future<void> _fetchJibunDataFromSheet() async {
    setState(() => _isFetchingJibun = true);
    try {
      double? balance;
      for (final gid in _jibunCandidateSheetGids) {
        final rows = await _fetchBankSheetRows(gid);
        balance = _extractJibunBalance(rows);
        if (balance != null) {
          break;
        }
      }
      final resolvedBalance = balance;
      if (resolvedBalance == null) {
        throw Exception(
          'じぶん銀行の残高行が見つかりませんでした。GoogleシートのGIDまたは日付/残高列を確認してください',
        );
      }
      const jibunName = 'じぶん銀行';
      setState(() {
        _applyFetchedAssetBalance(
          assetName: jibunName,
          balance: resolvedBalance,
        );
      });
      if (mounted) {
        _showSheetFetchResult(
          assetName: jibunName,
          balance: resolvedBalance,
          color: const Color(0xFFEA580C),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データ取得に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingJibun = false);
      }
    }
  }

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

  GlobalKey _assetRowKeyForType(String type) {
    return _assetRowKeys.putIfAbsent(
      type,
      () => GlobalKey(debugLabel: 'asset_row_$type'),
    );
  }

  void _setWatchlistEntries(List<AssetWatchlistEntry> entries) {
    _watchlistByType = <String, AssetWatchlistEntry>{
      for (final entry in entries) entry.assetType: entry,
    };
  }

  List<AssetWatchlistEntry> get _visibleWatchlistEntries {
    final entries = _watchlistByType.values
        .where((entry) => _assetTypes.contains(entry.assetType))
        .toList();
    entries.sort((a, b) {
      final groupCompare =
          a.group.toLowerCase().compareTo(b.group.toLowerCase());
      if (groupCompare != 0) {
        if (a.group.isEmpty) return 1;
        if (b.group.isEmpty) return -1;
        return groupCompare;
      }
      return a.assetType.toLowerCase().compareTo(b.assetType.toLowerCase());
    });
    return entries;
  }

  Future<void> _loadWatchlistEntries() async {
    final entries = await widget.watchlistService.loadEntries();
    if (!mounted) return;
    setState(() {
      _setWatchlistEntries(entries);
    });
  }

  void _jumpToAssetType(String type) {
    final key = _assetRowKeys[type];
    if (key == null || key.currentContext == null) {
      _scrollTo(_keyStock);
      return;
    }
    _scrollTo(key);
  }

  Future<void> _showWatchlistDialog(String type) async {
    final existing = _watchlistByType[type];
    final groupController = TextEditingController(text: existing?.group ?? '');
    final memoController = TextEditingController(text: existing?.memo ?? '');

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(existing == null ? 'Add To Watchlist' : 'Edit Watchlist'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: groupController,
                  decoration: const InputDecoration(
                    labelText: 'Group',
                    hintText: 'invest / debt / this week',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: memoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Memo',
                    hintText: 'Why this item matters now',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  final entries =
                      await widget.watchlistService.removeEntry(type);
                  if (!mounted) return;
                  setState(() {
                    _setWatchlistEntries(entries);
                  });
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Removed $type from watchlist')),
                  );
                },
                child: const Text('Remove'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final entries = await widget.watchlistService.saveEntry(
                  AssetWatchlistEntry(
                    assetType: type,
                    group: groupController.text,
                    memo: memoController.text,
                    addedAt: existing?.addedAt ?? DateTime.now(),
                  ),
                );
                if (!mounted) return;
                setState(() {
                  _setWatchlistEntries(entries);
                });
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Updated watchlist for $type')),
                );
              },
              child: Text(existing == null ? 'Save' : 'Update'),
            ),
          ],
        ),
      );
    } finally {
      groupController.dispose();
      memoController.dispose();
    }
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
          backgroundColor: const Color(0xFF047857),
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
                final watchlistEntries =
                    await widget.watchlistService.removeEntry(type);
                await _supabase
                    .from('cfo_assets')
                    .delete()
                    .eq('user_id', userId)
                    .eq('title', type)
                    .select();
                setState(() {
                  _setWatchlistEntries(watchlistEntries);
                  _assetTypes.remove(type);
                  _assetRowKeys.remove(type);
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
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C)),
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
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
    await _supabase.from('subscriptions').delete().eq('id', id).select();
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
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C)),
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
  /// DB の過去 subscriptions から payment_source を取得してデフォルト選択肢にマージ
  /// (Win版#115: wealth_struggles に payment_source 列は存在しない。
  ///  支払先の蓄積は subscriptions.payment_source 側のみ)
  Future<void> _loadSourceOptionsFromDb() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _supabase
          .from('subscriptions')
          .select('payment_source')
          .eq('user_id', userId)
          .not('payment_source', 'is', null)
          .limit(200);
      final sources = <String>{};
      for (final row in data) {
        final src = row['payment_source']?.toString().trim() ?? '';
        if (src.isNotEmpty) sources.add(src);
      }
      if (!mounted) return;
      final defaults = _sourceOptions.toList();
      for (final s in sources) {
        if (!defaults.contains(s)) defaults.add(s);
      }
      setState(() => _sourceOptions = defaults);
    } catch (e) {
      debugPrint('_loadSourceOptionsFromDb error: $e');
    }
  }

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

  Future<void> _pickAndImportSmbcCsv() async {
    if (_isImportingSmbcCsv) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isImportingSmbcCsv = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('CSVデータを読み込めませんでした');
      }

      final text = _decodeSmbcCsvBytes(bytes);
      final parsed = const SmbcCsvImportService().parse(text);
      if (parsed.transactions.isEmpty) {
        throw Exception('登録できる三井住友銀行の入出金明細が見つかりませんでした');
      }

      final knownImportKeys = <String>{};
      for (final flow in _recentFlows) {
        final key =
            _extractSmbcImportKey(flow['description']?.toString() ?? '');
        if (key != null) {
          knownImportKeys.add(key);
        }
      }
      final records = <Map<String, dynamic>>[];
      var duplicateCount = 0;

      for (final transaction in parsed.transactions) {
        if (knownImportKeys.contains(transaction.importKey)) {
          duplicateCount += 1;
          continue;
        }
        knownImportKeys.add(transaction.importKey);
        final flowType = transaction.isDeposit ? '収入' : '支出';
        records.add({
          'user_id': userId,
          'action_type': transaction.actionType,
          'amount': transaction.amount,
          'description': _withFlowImportMarker(
            _composeFlowDescription(
              flowType: flowType,
              source: _smbcCsvSource,
              memo: transaction.displayMemo,
            ),
            transaction.importKey,
          ),
          'occurred_at': transaction.date.toUtc().toIso8601String(),
        });
      }

      for (var i = 0; i < records.length; i += 200) {
        final chunk = records.sublist(i, min(i + 200, records.length));
        await _supabase.from('wealth_struggles').insert(chunk);
      }

      final latestDate = parsed.latestDate;
      final latestBalance = parsed.latestBalance;
      if (mounted) {
        setState(() {
          if (!_sourceOptions.contains(_smbcCsvSource)) {
            _sourceOptions = [..._sourceOptions, _smbcCsvSource];
          }
          if (latestDate != null) {
            _selectedFlowHistoryMonth = _monthStart(latestDate);
          }
          if (latestBalance != null) {
            _applyFetchedAssetBalance(
              assetName: '三井住友銀行',
              balance: latestBalance.toDouble(),
            );
          }
        });
      }

      await _fetchRecentFlows();
      await _fetchTodayClosing();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '三井住友CSVを取り込みました: ${records.length}件登録 / '
            '$duplicateCount件重複スキップ / ${parsed.skippedRows}行スキップ',
          ),
          backgroundColor: const Color(0xFF047857),
        ),
      );
    } catch (e) {
      debugPrint('Error importing SMBC CSV: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('三井住友CSVの取込に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImportingSmbcCsv = false);
      }
    }
  }

  String _decodeSmbcCsvBytes(Uint8List bytes) {
    try {
      final text = utf8.decode(bytes);
      if (_looksLikeSmbcCsv(text)) return text;
    } catch (_) {
      // SMBC exports are commonly CP932/Shift_JIS. Fall through to TextDecoder.
    }

    try {
      final text = web.TextDecoder('shift_jis').decode(bytes.toJS);
      if (_looksLikeSmbcCsv(text)) return text;
    } catch (e) {
      debugPrint('Shift_JIS decode failed: $e');
    }

    final malformed = utf8.decode(bytes, allowMalformed: true);
    if (_looksLikeSmbcCsv(malformed)) return malformed;
    throw const FormatException('三井住友銀行CSVの列名を判定できませんでした');
  }

  bool _looksLikeSmbcCsv(String text) =>
      text.contains('年月日') &&
      text.contains('お引出し') &&
      text.contains('お預入れ') &&
      text.contains('お取り扱い内容');

  String _composeFlowDescription({
    required String flowType,
    required String source,
    required String memo,
    String? destination,
    String? wasteCategory,
  }) {
    final normalizedSource = source.trim();
    final normalizedMemo = memo.trim();
    final String description;
    if (flowType == '振替') {
      final normalizedDestination = (destination ?? '').trim();
      final route = '$normalizedSource -> $normalizedDestination';
      if (normalizedMemo.isEmpty) {
        return route;
      }
      return '$route $normalizedMemo';
    }
    if (normalizedMemo.isEmpty) {
      description = normalizedSource;
    } else {
      description = '$normalizedSource $normalizedMemo';
    }
    if (flowType != '支出') {
      return description;
    }
    return WasteTrackingService.attachWasteCategory(description, wasteCategory);
  }

  ({
    String source,
    String destination,
    String memo,
    String? wasteCategory,
    bool isTransfer,
  }) _parseFlowDescription(
    String description, {
    String? actionType,
  }) {
    final normalizedDescription = _stripFlowImportMarker(description.trim());
    final isExpense = _isExpenseActionType(actionType ?? '');
    final wasteCategory = isExpense
        ? WasteTrackingService.extractWasteCategory(normalizedDescription)
        : null;
    final normalized = isExpense
        ? WasteTrackingService.stripWasteMarker(normalizedDescription)
        : normalizedDescription;
    if (_isTransferActionType(actionType ?? '')) {
      final transferMatch =
          RegExp(r'^(\[[^\]]+\])\s*->\s*(\[[^\]]+\])(?:\s+(.*))?$')
              .firstMatch(normalized);
      if (transferMatch != null) {
        return (
          source: transferMatch.group(1)?.trim() ?? '',
          destination: transferMatch.group(2)?.trim() ?? '',
          memo: transferMatch.group(3)?.trim() ?? '',
          wasteCategory: wasteCategory,
          isTransfer: true,
        );
      }
    }

    final match = RegExp(r'^(\[[^\]]+\])\s*(.*)$').firstMatch(normalized);
    if (match != null) {
      return (
        source: match.group(1)?.trim() ?? '',
        destination: '',
        memo: match.group(2)?.trim() ?? '',
        wasteCategory: wasteCategory,
        isTransfer: _isTransferActionType(actionType ?? ''),
      );
    }

    return (
      source: '',
      destination: '',
      memo: normalized,
      wasteCategory: wasteCategory,
      isTransfer: _isTransferActionType(actionType ?? ''),
    );
  }

  String _flowDisplayTitle(Map<String, dynamic> flow) {
    final actionType = flow['action_type']?.toString() ?? '';
    final parsed = _parseFlowDescription(
      flow['description']?.toString() ?? '',
      actionType: actionType,
    );
    if (parsed.isTransfer) {
      final fromLabel = _sourceLabel(parsed.source);
      final toLabel = _sourceLabel(parsed.destination);
      final routeParts =
          [fromLabel, toLabel].where((part) => part.trim().isNotEmpty).toList();
      final routeLabel = routeParts.join(' → ');
      if (routeLabel.isEmpty) {
        return parsed.memo;
      }
      if (parsed.memo.isEmpty) {
        return routeLabel;
      }
      return '$routeLabel ・ ${parsed.memo}';
    }

    final sourceLabel = _sourceLabel(parsed.source);
    if (sourceLabel.isEmpty) {
      return parsed.memo;
    }
    if (parsed.memo.isEmpty) {
      return sourceLabel;
    }
    return '$sourceLabel ・ ${parsed.memo}';
  }

  String _flowLabelToActionType(String label) {
    switch (label) {
      case '収入':
        return 'conquer';
      case '振替':
        return 'transfer';
      default:
        return 'expense';
    }
  }

  String _actionTypeToFlowLabel(String actionType) {
    switch (actionType) {
      case 'conquer':
        return '収入';
      case 'transfer':
        return '振替';
      default:
        return '支出';
    }
  }

  Future<void> _recordFlow() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final memo = _flowMemoController.text.trim();
    final amountStr = _flowAmountController.text.replaceAll(',', '');
    final amount = int.tryParse(amountStr);
    final isTransfer = _selectedFlowType == '振替';

    if (amount == null || amount <= 0 || (!isTransfer && memo.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTransfer ? '振替先と金額(1円以上)を正しく入力してください' : '内容と金額(1円以上)を正しく入力してください',
          ),
        ),
      );
      return;
    }

    if (isTransfer && _selectedSource == _selectedTransferDestination) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('振替元と振替先は別の口座を選択してください')),
      );
      return;
    }

    final actionType = _flowLabelToActionType(_selectedFlowType);

    try {
      await _supabase.from('wealth_struggles').insert({
        'user_id': userId,
        'action_type': actionType,
        'amount': amount,
        'description': _composeFlowDescription(
          flowType: _selectedFlowType,
          source: _selectedSource,
          destination: isTransfer ? _selectedTransferDestination : null,
          memo: memo,
          wasteCategory: _isExpenseFlowSelected ? _selectedWasteCategory : null,
        ),
        'occurred_at': _selectedFlowDate.toUtc().toIso8601String(),
      });

      _flowMemoController.clear();
      _flowAmountController.clear();
      if (mounted) {
        setState(() {
          _selectedFlowHistoryMonth = _monthStart(_selectedFlowDate);
          _selectedWasteCategory = null;
        });
      }
      await _fetchRecentFlows();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTransfer ? '振替を記録しました' : '収支を記録しました',
            ),
            backgroundColor: Theme.of(context).colorScheme.onSurface,
          ),
        );
      }
      await _fetchTodayClosing();
    } catch (e) {
      debugPrint('Error recording flow: $e');
    }
  }

  Future<void> _editFlow(Map<String, dynamic> flow) async {
    final flowId = flow['id']?.toString();
    if (flowId == null || flowId.isEmpty) return;

    final currentActionType = flow['action_type']?.toString() ?? 'expense';
    final parsed = _parseFlowDescription(
      flow['description']?.toString() ?? '',
      actionType: currentActionType,
    );
    final availableSources = [..._sourceOptions];
    if (parsed.source.isNotEmpty && !availableSources.contains(parsed.source)) {
      availableSources.add(parsed.source);
    }
    if (parsed.destination.isNotEmpty &&
        !availableSources.contains(parsed.destination)) {
      availableSources.add(parsed.destination);
    }

    final memoController = TextEditingController(text: parsed.memo);
    final amountController = TextEditingController(
      text: ((flow['amount'] as num?)?.toInt() ?? 0).toString(),
    );
    var selectedSource =
        parsed.source.isNotEmpty ? parsed.source : _defaultFlowSource;
    if (!availableSources.contains(selectedSource)) {
      availableSources.add(selectedSource);
    }
    var selectedType = _actionTypeToFlowLabel(currentActionType);
    var selectedDestination = _resolvedTransferDestination(
      selectedSource,
      preferred: parsed.destination,
    );
    String? selectedWasteCategory = parsed.wasteCategory;
    var selectedDate =
        DateTime.tryParse(flow['occurred_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now();

    try {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('収支記録を編集'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: '種別',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _flowTypeOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedType = value;
                        if (value == '振替') {
                          selectedDestination = _resolvedTransferDestination(
                            selectedSource,
                            preferred: selectedDestination,
                          );
                        }
                        if (value != '支出') {
                          selectedWasteCategory = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime.now(),
                      );
                      if (picked == null) return;
                      setDialogState(() => selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '日付',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('yyyy/MM/dd').format(selectedDate)),
                          const Icon(Icons.calendar_today, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSource,
                    decoration: InputDecoration(
                      labelText: selectedType == '振替' ? '振替元' : '入出金元',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: availableSources
                        .map(
                          (source) => DropdownMenuItem(
                            value: source,
                            child: Text(
                              source.replaceAll('[', '').replaceAll(']', ''),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedSource = value;
                        if (selectedType == '振替') {
                          selectedDestination = _resolvedTransferDestination(
                            value,
                            preferred: selectedDestination,
                          );
                        }
                      });
                    },
                  ),
                  if (selectedType == '振替') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDestination,
                      decoration: const InputDecoration(
                        labelText: '振替先',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _transferDestinationOptions(
                        selectedSource,
                        include: selectedDestination,
                      )
                          .map(
                            (source) => DropdownMenuItem(
                              value: source,
                              child: Text(_sourceLabel(source)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedDestination = value);
                      },
                    ),
                  ],
                  if (selectedType == '支出') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedWasteCategory,
                      decoration: const InputDecoration(
                        labelText: '浪費カテゴリ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('分類なし'),
                        ),
                        ...WasteTrackingService.categoryLabels.map(
                          (label) => DropdownMenuItem<String?>(
                            value: label,
                            child: Text(label),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedWasteCategory =
                              WasteTrackingService.normalizeCategory(value);
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: memoController,
                    decoration: InputDecoration(
                      labelText: selectedType == '振替' ? 'メモ（任意）' : '内容',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '金額 (円)',
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
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      );

      if (shouldSave != true) return;

      final memo = memoController.text.trim();
      final amount = int.tryParse(amountController.text.replaceAll(',', ''));
      final isTransfer = selectedType == '振替';
      if (amount == null || amount <= 0 || (!isTransfer && memo.isEmpty)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTransfer ? '振替先と金額を正しく入力してください' : '内容と金額を正しく入力してください',
            ),
          ),
        );
        return;
      }
      if (isTransfer && selectedSource == selectedDestination) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('振替元と振替先は別の口座を選択してください')),
        );
        return;
      }

      await _supabase.from('wealth_struggles').update({
        'action_type': _flowLabelToActionType(selectedType),
        'amount': amount,
        'description': _composeFlowDescription(
          flowType: selectedType,
          source: selectedSource,
          destination: isTransfer ? selectedDestination : null,
          memo: memo,
          wasteCategory: selectedType == '支出' ? selectedWasteCategory : null,
        ),
        'occurred_at': selectedDate.toUtc().toIso8601String(),
      }).eq('id', flowId);

      if (mounted) {
        setState(() {
          _selectedFlowHistoryMonth = _monthStart(selectedDate);
        });
      }

      await _fetchRecentFlows();
      await _fetchTodayClosing();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTransfer ? '振替記録を更新しました' : '収支記録を更新しました',
          ),
          backgroundColor: Theme.of(context).colorScheme.onSurface,
        ),
      );
    } catch (e) {
      debugPrint('Error editing flow: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('収支記録の更新に失敗しました: $e')),
      );
    } finally {
      memoController.dispose();
      amountController.dispose();
    }
  }

  // ==========================================
  // 5. 必須タスクの記録と把握
  // ==========================================
  Future<bool> _confirmDeleteFlow(Map<String, dynamic> flow) async {
    final actionType = flow['action_type']?.toString() ?? 'expense';
    final parsed = _parseFlowDescription(
      flow['description']?.toString() ?? '',
      actionType: actionType,
    );
    final title = _flowDisplayTitle(flow).trim().isNotEmpty
        ? _flowDisplayTitle(flow)
        : (parsed.memo.isNotEmpty ? parsed.memo : 'この収支記録');
    final amount = (flow['amount'] as num?)?.toInt() ?? 0;
    final date = DateTime.tryParse(
          flow['occurred_at']?.toString() ?? '',
        )?.toLocal() ??
        DateTime.now();
    final typeLabel = _actionTypeToFlowLabel(actionType);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text(
          '${DateFormat('yyyy/MM/dd').format(date)} の$typeLabel「$title」（¥${NumberFormat('#,###').format(amount)}）を削除しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除',
                style: TextStyle(
                  color: Color(0xFFB91C1C),
                  height: 1.5,
                )),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _deleteFlow(Map<String, dynamic> flow) async {
    final userId = _supabase.auth.currentUser?.id;
    final flowId = flow['id']?.toString();
    if (userId == null || flowId == null || flowId.isEmpty) return;

    final shouldDelete = await _confirmDeleteFlow(flow);
    if (!shouldDelete) return;

    try {
      await _supabase
          .from('wealth_struggles')
          .delete()
          .eq('id', flowId)
          .eq('user_id', userId)
          .select();

      await _fetchRecentFlows();
      await _fetchTodayClosing();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('収支記録を削除しました'),
          backgroundColor: Theme.of(context).colorScheme.onSurface,
        ),
      );
    } catch (e) {
      debugPrint('Error deleting flow: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('収支記録の削除に失敗しました: $e')),
      );
    }
  }

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
                      border: Border.all(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      if (!mounted) return;
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
        SnackBar(
            content: Text('支払日の更新に失敗: $e'),
            backgroundColor: const Color(0xFFB91C1C)),
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
      final color =
          diff >= 0 ? const Color(0xFF0D9488) : const Color(0xFFB91C1C);
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
      backgroundColor: const Color(0xFF64748B),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if ((widget.entryLabel?.trim().isNotEmpty ?? false) ||
                (widget.entryDescription?.trim().isNotEmpty ?? false)) ...[
              _buildUnifiedEntryBanner(),
              const SizedBox(height: 16),
            ],
            _buildMonthlyFlowFirstCard(),
            const SizedBox(height: 16),
            _buildMonthlyFlowPrimaryActionBar(),
            const SizedBox(height: 16),
            _buildWasteTrainingAiCard(),
            const SizedBox(height: 24),
            _buildDeadlineChecklistCard(), // 締切チェックリスト
            const SizedBox(height: 16),
            _buildThreeMonthOverviewCard(), // 3ヶ月俯瞰
            const SizedBox(height: 16),
            _buildDebtPlannerCard(), // 借金返済プラン
            const SizedBox(height: 16),
            _buildAssetLiabilityWorkbookBoard(),
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

  Widget _buildUnifiedEntryBanner() {
    final label = widget.entryLabel?.trim();
    final description = widget.entryDescription?.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.merge_type,
              color: Color(0xFF0F766E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'お金まわりの操作は資産管理に統合しました',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        height: 1.4,
                      ),
                    ),
                    if (label != null && label.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF115E59),
                            height: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF134E4A),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------
  // 各カードUIコンポーネント
  // -------------------------

  Widget _buildMonthlyFlowFirstCard() {
    final currentMonth = DateTime(_now.year, _now.month, 1);
    final monthLabel = _flowMonthLabel(currentMonth);
    final flows = _flowsForMonth(currentMonth);
    var totalIncome = 0;
    var totalExpense = 0;

    for (final item in flows) {
      final amount = (item['amount'] as num?)?.toInt() ?? 0;
      final actionType = item['action_type'] as String? ?? '';
      if (actionType == 'conquer') {
        totalIncome += amount;
      } else if (actionType == 'expense') {
        totalExpense += amount;
      }
    }

    final net = totalIncome - totalExpense;
    final statusText = flows.isEmpty
        ? 'まだ今月の収支が未記録です。まず収入と支出を入れて全体像を把握してください。'
        : '今月の収支差額は ${NumberFormat('#,###').format(net.abs())}円 ${net >= 0 ? '黒字' : '赤字'} です。まずここを基準に残りの判断を進めます。';

    return Card(
      key: const Key('asset_monthly_flow_priority_card'),
      elevation: widget.emphasizeMonthlyFlow ? 6 : 3,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: widget.emphasizeMonthlyFlow
              ? const Color(0xFF2DD4BF)
              : const Color(0xFFCCFBF1),
          width: widget.emphasizeMonthlyFlow ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$monthLabelの収支を最優先で把握',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildFlowPriorityMetric(
                  label: '収入',
                  value: '¥${NumberFormat('#,###').format(totalIncome)}',
                  color: const Color(0xFF0F766E),
                ),
                _buildFlowPriorityMetric(
                  label: '支出',
                  value: '¥${NumberFormat('#,###').format(totalExpense)}',
                  color: const Color(0xFFB91C1C),
                ),
                _buildFlowPriorityMetric(
                  label: '差額',
                  value:
                      '${net >= 0 ? '+' : '-'}¥${NumberFormat('#,###').format(net.abs())}',
                  color: net >= 0
                      ? const Color(0xFF065F46)
                      : const Color(0xFF7F1D1D),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyFlowPrimaryActionBar() {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        key: const Key('asset_monthly_flow_priority_button'),
        onPressed: () => _scrollTo(_keyFlow),
        icon: const Icon(Icons.arrow_downward),
        label: const Text('今月の収支入力へ進む'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildWasteTrainingAiCard() {
    final training = _buildWasteTrainingSnapshot();
    final plan = _buildWasteTrainingPlan(training);
    final reviewFuture = _wasteTrainingReviewFor(training);
    final wasteRatioLabel = '${(training.wasteRatio * 100).round()}%';

    return Card(
      key: const Key('asset_waste_training_ai_card'),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFCCFBF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_alt_outlined,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI浪費抑制トレーニング',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'お金を浪費しないことは、欲望を観察し、判断力と自己制御を鍛える能力開発トレーニングです。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            KgiCsfKpiPanel(
              plan: plan,
              accentColor: const Color(0xFF0F766E),
              initiallyExpanded: true,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOverviewStatChip(
                  label: '浪費額',
                  value: _formatYen(training.wasteExpense),
                  color: const Color(0xFFB91C1C),
                ),
                _buildOverviewStatChip(
                  label: '浪費比率',
                  value: wasteRatioLabel,
                  color: const Color(0xFFF97316),
                ),
                _buildOverviewStatChip(
                  label: '浪費ゼロ日',
                  value: '${training.noWasteDays}/${training.elapsedDays}日',
                  color: const Color(0xFF0F766E),
                ),
                _buildOverviewStatChip(
                  label: '日課達成',
                  value:
                      '${training.ruleCompletedCount}/${training.ruleTargetCount}件',
                  color: const Color(0xFF2563EB),
                ),
                _buildOverviewStatChip(
                  label: '連続達成',
                  value: '${training.compliantStreakDays}日',
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<AssetWasteTrainingAiReview>(
              future: reviewFuture,
              builder: (context, snapshot) {
                final review = snapshot.data;
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting &&
                        review == null;
                return _buildWasteTrainingReviewBox(
                  review: review,
                  isLoading: isLoading,
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.trending_up,
                    color: Color(0xFF0F766E),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _wasteTrainingNextAction(training),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF134E4A),
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteTrainingReviewBox({
    required AssetWasteTrainingAiReview? review,
    required bool isLoading,
  }) {
    final source = review?.source ?? 'ai-hub provider.chat';
    final summary = review?.summary ?? 'AIが現在の支出・浪費・日課達成を分析しています。';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  review?.isFallback == true
                      ? Icons.auto_awesome_motion_outlined
                      : Icons.auto_awesome,
                  size: 18,
                  color: isDark
                      ? const Color(0xFF3D5AFE)
                      : const Color(0xFF2563EB),
                ),
              const SizedBox(width: 8),
              Text(
                'AI現状分析',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                source,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? const Color(0xFFB0B0B0)
                      : const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF334155),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowPriorityMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 108),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

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
                const Icon(Icons.flag, color: Color(0xFFFF6B35)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '本日18:00までに必ず完了（①〜⑤）',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                height: 1.5,
              ),
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
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
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.5,
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
        color: const Color(0xFF64748B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _monthLabelWithRole(month),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '純資産: ${netWorth == null ? "未記録" : _formatYen(netWorth)}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
            ),
          ),
          Text(
            '固定費: ${_formatYen(fixedCost)}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
            ),
          ),
          Text(
            'タスク: $completedTasks/$totalTasks 完了',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
            ),
          ),
          Text(
            '未完了: $pendingTasks',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
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
        ? ((currentNet - prevNet) >= 0
            ? const Color(0xFF0D9488)
            : const Color(0xFFB91C1C))
        : const Color(0xFF9CA3AF);

    final fixedDiff =
        (fixedCostByMonth[currentKey] ?? 0) - (fixedCostByMonth[prevKey] ?? 0);
    final fixedDiffColor =
        fixedDiff <= 0 ? const Color(0xFF0D9488) : const Color(0xFFB91C1C);

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
                Icon(Icons.view_timeline, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text(
                  '3ヶ月俯瞰（先月・今月・来月）',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '口座残高・固定費・必須タスクを3ヶ月単位で比較します。',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5,
              ),
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
                  color: const Color(0xFF6366F1),
                ),
                _buildOverviewStatChip(
                  label: '来月タスク件数',
                  value: '${nextTask['total'] ?? 0}件',
                  color: const Color(0xFFFF6B35),
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
    _ensureDebtLockdownSnapshotLoaded(totalDebt);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Text(
                  '借金返済プラン',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '負債データをもとに、返済優先順位と3ヶ月アクションを自動生成します。',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOverviewStatChip(
                  label: '負債件数',
                  value: '${liabilities.length}件',
                  color: const Color(0xFFB91C1C),
                ),
                _buildOverviewStatChip(
                  label: '負債合計',
                  value: _formatYen(totalDebt),
                  color: const Color(0xFFFF6B35),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDebtLockdownPanel(totalDebt),
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
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ],
            if (_debtPlanMarkdown != null && _debtExecutionPlan != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDebtPlannerModeChip(
                    mode: AssetDebtPlannerMode.ask,
                    label: 'Ask',
                    icon: Icons.chat_bubble_outline,
                  ),
                  _buildDebtPlannerModeChip(
                    mode: AssetDebtPlannerMode.code,
                    label: 'Code',
                    icon: Icons.code,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _debtPlannerMode == AssetDebtPlannerMode.ask
                    ? 'Ask は返済プランを読むモードです。'
                    : 'Code は返済プランを must tasks に反映するモードです。',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_isGeneratingDebtPlan)
              const Center(child: CircularProgressIndicator())
            else if (_debtPlanMarkdown == null)
              Text(
                'まだ返済プランは作成されていません。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              )
            else
              _debtPlannerMode == AssetDebtPlannerMode.ask
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: MarkdownBody(
                        data: _debtPlanMarkdown!,
                        selectable: true,
                      ),
                    )
                  : _buildDebtCodeModePanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtLockdownPanel(double remainingDebt) {
    final snapshot = _debtLockdownSnapshot;
    final isReleased = remainingDebt <= 0;
    final isEnabled = snapshot?.isActive == true && !isReleased;
    final rules = snapshot?.rules ?? DebtLockdownService.builtinRules;
    final completedRuleIds = snapshot?.completedRuleIds ?? const <String>{};
    final todayViolations =
        snapshot?.todayViolations ?? const <DebtLockdownViolation>[];
    final recentViolations =
        snapshot?.recentViolations ?? const <DebtLockdownViolation>[];
    final statusLabel = isReleased
        ? '釈放'
        : isEnabled
            ? '収監中'
            : '未開始';
    final statusColor = isReleased
        ? const Color(0xFF0D9488)
        : isEnabled
            ? const Color(0xFFB91C1C)
            : const Color(0xFF475569);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReleased ? const Color(0xFFF0FDFA) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReleased ? const Color(0xFF99F6E4) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReleased ? Icons.lock_open : Icons.lock_outline,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '完済までの収監モード',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isReleased
                ? '借金は完済済みです。収監モードは解除されました。'
                : '借金がゼロになるまでは、生活を最小化し、返済以外の逃避と浪費を止める前提で毎日を管理します。',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          if (_isLoadingDebtLockdown && snapshot == null) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 3),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildOverviewStatChip(
                label: '状態',
                value: statusLabel,
                color: statusColor,
              ),
              _buildOverviewStatChip(
                label: '本日違反',
                value: '${todayViolations.length}件',
                color: todayViolations.isEmpty
                    ? const Color(0xFF0D9488)
                    : const Color(0xFFB91C1C),
              ),
              _buildOverviewStatChip(
                label: '連続遵守',
                value: '${snapshot?.currentCompliantStreakDays ?? 0}日',
                color: const Color(0xFF6366F1),
              ),
              _buildOverviewStatChip(
                label: '日課達成',
                value: '${completedRuleIds.length}/${rules.length}',
                color: const Color(0xFF7C3AED),
              ),
            ],
          ),
          if (snapshot?.startedAt != null && !isReleased) ...[
            const SizedBox(height: 8),
            Text(
              '開始日: ${DateFormat('yyyy/MM/dd').format(snapshot!.startedAt!)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: isReleased
                          ? null
                          : () => _setDebtLockdownEnabled(
                              !isEnabled, remainingDebt),
                      icon: Icon(isEnabled ? Icons.pause_circle : Icons.shield),
                      label: Text(isEnabled ? '収監モードを中断' : '収監モードを開始'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: isEnabled
                          ? () =>
                              _showDebtLockdownViolationDialog(remainingDebt)
                          : null,
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('違反を記録'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isReleased
                            ? null
                            : () => _setDebtLockdownEnabled(
                                  !isEnabled,
                                  remainingDebt,
                                ),
                        icon: Icon(
                          isEnabled ? Icons.pause_circle : Icons.shield,
                        ),
                        label: Text(isEnabled ? '収監モードを中断' : '収監モードを開始'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: isEnabled
                          ? () =>
                              _showDebtLockdownViolationDialog(remainingDebt)
                          : null,
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('違反を記録'),
                    ),
                  ],
                ),
          const SizedBox(height: 12),
          const Text(
            '本日の規律',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          ...rules.map((rule) {
            final checked = completedRuleIds.contains(rule.id);
            return CheckboxListTile(
              key: Key('debt_lockdown_rule_${rule.id}'),
              dense: true,
              value: checked,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                rule.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              subtitle: Text(rule.description),
              onChanged: isEnabled
                  ? (value) => _toggleDebtLockdownRule(
                        rule.id,
                        value ?? false,
                        remainingDebt,
                      )
                  : null,
            );
          }),
          const SizedBox(height: 8),
          const Text(
            '最近の違反',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          if (recentViolations.isEmpty)
            Text(
              isEnabled
                  ? 'まだ違反記録はありません。今日も浪費と逃避を止めて返済だけに集中します。'
                  : '収監モードを開始すると、ここに違反ログが溜まります。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5,
              ),
            )
          else
            ...recentViolations.take(3).map((violation) {
              final amountLabel = violation.amount > 0
                  ? ' / ${_formatYen(violation.amount)}'
                  : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${DateFormat('MM/dd HH:mm').format(violation.createdAt)}  ${violation.category}$amountLabel  ${violation.note}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  IconData _debtExecutionTaskIcon(DebtExecutionTaskKind kind) {
    switch (kind) {
      case DebtExecutionTaskKind.focus:
        return Icons.my_location;
      case DebtExecutionTaskKind.budget:
        return Icons.account_balance_wallet_outlined;
      case DebtExecutionTaskKind.fixedCost:
        return Icons.content_cut;
      case DebtExecutionTaskKind.payment:
        return Icons.payments_outlined;
      case DebtExecutionTaskKind.milestone:
        return Icons.flag_outlined;
      case DebtExecutionTaskKind.review:
        return Icons.refresh_rounded;
    }
  }

  Color _debtExecutionTaskColor(DebtExecutionTaskKind kind) {
    switch (kind) {
      case DebtExecutionTaskKind.focus:
        return const Color(0xFF7C3AED);
      case DebtExecutionTaskKind.budget:
        return const Color(0xFFB91C1C);
      case DebtExecutionTaskKind.fixedCost:
        return const Color(0xFFC05621);
      case DebtExecutionTaskKind.payment:
        return const Color(0xFF0F766E);
      case DebtExecutionTaskKind.milestone:
        return const Color(0xFF1D4ED8);
      case DebtExecutionTaskKind.review:
        return const Color(0xFF0F766E);
    }
  }

  Widget _buildDebtPlannerModeChip({
    required AssetDebtPlannerMode mode,
    required String label,
    required IconData icon,
  }) {
    final selected = _debtPlannerMode == mode;
    return ChoiceChip(
      key: Key('asset_debt_planner_mode_${mode.name}'),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _debtPlannerMode = mode;
        });
      },
      avatar: Icon(
        icon,
        size: 16,
        color: selected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      selectedColor: const Color(0xFF7C3AED),
      labelStyle: TextStyle(
        color:
            selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
        height: 1.5,
      ),
      label: Text(label),
    );
  }

  Widget _buildDebtCodeModePanel() {
    final plan = _debtExecutionPlan;
    if (plan == null) {
      return Text(
        'Code モード用の実行タスクはまだありません。',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      );
    }

    final selectedCount = _selectedDebtExecutionTasks.length;

    return Container(
      key: const Key('asset_debt_code_mode_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A0A4E).withValues(alpha: 0.63)
            : const Color(0xFFF6F3FF),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.code, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Codex-style Code モード',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            plan.summary,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...plan.tasks.map((task) {
            final selected = _selectedDebtExecutionTaskIds.contains(task.id);
            final alreadyAdded = _isExecutionTaskAlreadyAdded(task);
            final color = _debtExecutionTaskColor(task.kind);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: CheckboxListTile(
                key: Key('asset_debt_code_task_${task.id}'),
                value: selected,
                onChanged: alreadyAdded
                    ? null
                    : (value) =>
                        _toggleDebtExecutionTask(task.id, value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                secondary: Icon(
                  _debtExecutionTaskIcon(task.kind),
                  color: color,
                ),
                title: Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(task.detail),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '期限: ${DateFormat('yyyy/MM/dd').format(task.dueDate)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                              height: 1.5,
                            ),
                          ),
                        ),
                        if (alreadyAdded)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '既存タスクあり',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          _isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _selectAllDebtExecutionTasks,
                      icon: const Icon(Icons.done_all),
                      label: const Text('全選択'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _clearDebtExecutionTaskSelection,
                      icon: const Icon(Icons.remove_done),
                      label: const Text('選択解除'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const Key('asset_debt_code_apply_button'),
                      onPressed: _isApplyingDebtExecutionTasks
                          ? null
                          : _applyDebtExecutionTasksToMustTasks,
                      icon: _isApplyingDebtExecutionTasks
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.playlist_add_check_circle_outlined),
                      label: Text('必須タスクへ追加 ($selectedCount)'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectAllDebtExecutionTasks,
                        icon: const Icon(Icons.done_all),
                        label: const Text('全選択'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearDebtExecutionTaskSelection,
                        icon: const Icon(
                          Icons.remove_done,
                        ),
                        label: const Text(
                          '選択解除',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        key: const Key('asset_debt_code_apply_button'),
                        onPressed: _isApplyingDebtExecutionTasks
                            ? null
                            : _applyDebtExecutionTasksToMustTasks,
                        icon: _isApplyingDebtExecutionTasks
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.playlist_add_check_circle_outlined),
                        label: Text(
                          '必須タスクへ追加 ($selectedCount)',
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildAssetLiabilityWorkbookBoard() {
    final latestSnapshot = _latestSnapshotForDisplay();
    if (latestSnapshot.isEmpty) {
      return const SizedBox.shrink();
    }

    final workbook = _assetLiabilityPlanner.buildWorkbook(
      latestSnapshot: latestSnapshot,
      baseDate: _now,
      monthlyPaymentOverrides: _monthlyPaymentOverrides,
      paidAccountNames: _monthlyPaidAccountNames,
      paymentSourceAccountIds: _paymentSourceAccountIds,
      defaultPaymentSourceAccountIds: _defaultPaymentSourceAccountIds,
      incomePlans: _monthlyIncomePlans,
      includeDefaultFixedPayments: true,
    );
    _scheduleAssetLiabilityStateIdMigration(workbook);
    final warningColor = workbook.cashAfterScheduledPayments < 0
        ? const Color(0xFFB91C1C)
        : const Color(0xFF0D9488);

    return Card(
      key: const Key('asset_liability_workbook_board'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.table_chart_outlined,
                  color: Color(0xFF0F766E),
                ),
                SizedBox(width: 8),
                Text(
                  '資産/負債 管理ボード',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'プラス=資産、マイナス=負債として、残高・支払日・今月支払予定額を分けて確認します。',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOverviewStatChip(
                  label: '手元現金',
                  value: _formatManagementYen(workbook.cashLikeTotal),
                  color: const Color(0xFF0D9488),
                ),
                _buildOverviewStatChip(
                  label: '証券',
                  value: _formatManagementYen(workbook.securitiesTotal),
                  color: const Color(0xFF2563EB),
                ),
                _buildOverviewStatChip(
                  label: '資産合計',
                  value: _formatManagementYen(workbook.positiveAssetTotal),
                  color: const Color(0xFF0D9488),
                ),
                _buildOverviewStatChip(
                  label: '負債合計',
                  value: _formatManagementYen(workbook.liabilityTotal),
                  color: const Color(0xFFB91C1C),
                ),
                _buildOverviewStatChip(
                  label: '純資産',
                  value: _formatManagementYen(workbook.netWorth),
                  color: workbook.netWorth < 0
                      ? const Color(0xFFB91C1C)
                      : const Color(0xFF0D9488),
                ),
                _buildOverviewStatChip(
                  label: '負債倍率',
                  value: workbook.debtToAssetRatio.isInfinite
                      ? '算出不可'
                      : '${workbook.debtToAssetRatio.toStringAsFixed(1)}倍',
                  color: const Color(0xFFFF6B35),
                ),
                _buildOverviewStatChip(
                  label: '推定最低支払額',
                  value: _formatManagementYen(
                    workbook.monthlyMinimumPaymentEstimateTotal,
                  ),
                  color: const Color(0xFF7C3AED),
                ),
                _buildOverviewStatChip(
                  label: '今月支払予定額',
                  value: _formatManagementYen(
                    workbook.monthlyScheduledPaymentTotal,
                  ),
                  color: const Color(0xFF4F46E5),
                ),
                _buildOverviewStatChip(
                  label: '未払い予定額',
                  value: _formatManagementYen(
                    workbook.monthlyUnpaidPaymentTotal,
                  ),
                  color: const Color(0xFFD97706),
                ),
                _buildOverviewStatChip(
                  label: '未入金予定額',
                  value: _formatManagementYen(
                    workbook.monthlyUnreceivedIncomeTotal,
                  ),
                  color: const Color(0xFF0D9488),
                ),
                _buildOverviewStatChip(
                  label: '支払後手元',
                  value: _formatManagementYen(
                    workbook.cashAfterScheduledPayments,
                  ),
                  color: warningColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildAssetWorkbookEstimateNotice(workbook),
            if (workbook.hasOverduePayments) ...[
              const SizedBox(height: 8),
              _buildAssetWorkbookOverdueWarning(workbook),
            ],
            const SizedBox(height: 12),
            _buildAssetWorkbookWarning(workbook),
            const SizedBox(height: 16),
            _buildAssetWorkbookPaymentList(workbook),
            const SizedBox(height: 16),
            _buildIncomePlanSection(workbook),
            const SizedBox(height: 16),
            _buildAssetCashflowTable(workbook),
            const SizedBox(height: 16),
            _buildAccountCashflowSection(workbook),
            const SizedBox(height: 16),
            _buildMonthlySnapshotSection(workbook),
            const SizedBox(height: 16),
            _buildTransferSuggestionSection(workbook),
            const SizedBox(height: 16),
            _buildAssetWorkbookDebtTable(workbook),
            const SizedBox(height: 16),
            _buildAssetWorkbookPriorityList(workbook),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetWorkbookEstimateNotice(AssetLiabilityWorkbook workbook) {
    final hasManual = workbook.manualPaymentCount > 0;
    final status = hasManual
        ? '実額 ${workbook.manualPaymentCount}件 / 推定 ${workbook.estimatedPaymentCount}件'
        : '全件が推定値';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 20,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '推定最低支払額は参考値です。実際の請求額とは異なる場合があります。請求確定後は手入力値を優先してください。$status',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetWorkbookOverdueWarning(AssetLiabilityWorkbook workbook) {
    final overdueRows = workbook.overdueCashflowRows;
    final overdueTotal = overdueRows.fold<double>(
      0,
      (sum, row) => sum + row.paymentAmount,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFB91C1C).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.priority_high_rounded,
            size: 20,
            color: Color(0xFFB91C1C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '期限超過の未払いが${overdueRows.length}件あります。対象: ${overdueRows.map((row) => row.accountName).join('、')} / 合計 ${_formatManagementYen(overdueTotal)}',
              style: const TextStyle(
                color: Color(0xFF7F1D1D),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetWorkbookWarning(AssetLiabilityWorkbook workbook) {
    final isShort = workbook.cashAfterScheduledPayments < 0;
    final color = isShort ? const Color(0xFFB91C1C) : const Color(0xFF0D9488);
    final background =
        isShort ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
    final title = isShort ? '今月支払予定額ベースで手元資金が不足' : '今月支払予定額は手元資金内';
    final detail = isShort
        ? '不足見込: ${_formatManagementYen(workbook.cashAfterScheduledPayments.abs())}'
        : '支払後手元見込: ${_formatManagementYen(workbook.cashAfterScheduledPayments)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            isShort ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                Text(
                  '$detail / 上位4件の負債割合: ${_formatManagementPercent(workbook.topFourDebtShare)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetWorkbookPaymentList(AssetLiabilityWorkbook workbook) {
    if (workbook.paymentDayRisks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '支払日別リスク',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          ...workbook.paymentDayRisks.map(_buildPaymentRiskRow),
        ],
      ),
    );
  }

  Widget _buildPaymentRiskRow(AssetLiabilityPaymentDayRisk risk) {
    final color = risk.isToday
        ? const Color(0xFFFF6B35)
        : risk.isPast
            ? const Color(0xFF64748B)
            : const Color(0xFFB91C1C);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${risk.paymentDay}日',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  risk.accountNames.join('、'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                Text(
                  '${_paymentRiskStatusLabel(risk)} / 残高 ${_formatManagementYen(risk.balanceTotal)} / 支払予定 ${_formatManagementYen(risk.scheduledPaymentTotal)}（${_paymentRiskPaymentSourceLabel(risk)}） / 推定最低支払額 ${_formatManagementYen(risk.minimumPaymentEstimateTotal)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomePlanSection(AssetLiabilityWorkbook workbook) {
    final plans = workbook.incomePlans;
    final unassignedPlans = workbook.unassignedDestinationIncomePlans;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '収入予定',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _copyPreviousMonthSettings,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('前月コピー'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _showRecurringIncomeTemplateDialog(workbook),
                    icon: const Icon(Icons.event_repeat_outlined),
                    label: const Text('定期収入'),
                  ),
                  TextButton.icon(
                    onPressed: () => _showIncomePlanDialog(workbook),
                    icon: const Icon(Icons.add),
                    label: const Text('追加'),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '入金済み・支払済みにした項目は、現在の口座残高に反映済みとして扱います。まだ残高を更新していない場合はチェックしないでください。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (unassignedPlans.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildUnassignedIncomeWarning(unassignedPlans),
          ],
          if (_recurringIncomeTemplates.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildRecurringIncomeTemplateList(workbook),
          ],
          const SizedBox(height: 8),
          if (plans.isEmpty)
            Text(
              '今月の収入予定は未登録です。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('日付'), numeric: true),
                  DataColumn(label: Text('名称')),
                  DataColumn(label: Text('金額'), numeric: true),
                  DataColumn(label: Text('入金先口座')),
                  DataColumn(label: Text('入金済み')),
                  DataColumn(label: Text('操作')),
                ],
                rows: [
                  for (final plan in plans)
                    DataRow(
                      cells: [
                        DataCell(Text(DateFormat('M/d').format(plan.date))),
                        DataCell(Text(plan.name)),
                        DataCell(Text(_formatManagementYen(plan.amount))),
                        DataCell(Text(plan.destinationAccountName ?? '未設定')),
                        DataCell(
                          Checkbox(
                            value: plan.received,
                            onChanged: (value) => _toggleIncomeReceived(
                              plan.id,
                              value ?? false,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '編集',
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _showIncomePlanDialog(
                                  workbook,
                                  existing: plan,
                                ),
                              ),
                              IconButton(
                                tooltip: '削除',
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => _deleteIncomePlan(plan.id),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnassignedIncomeWarning(
    List<AssetLiabilityIncomePlan> plans,
  ) {
    final names = plans.map((plan) => plan.name).join('、');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '入金先口座未設定の収入予定があります。全体資金繰りには反映しますが、口座別資金繰りには反映されません。対象: $names',
        style: const TextStyle(
          color: Color(0xFF92400E),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildRecurringIncomeTemplateList(
    AssetLiabilityWorkbook workbook,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final template in _recurringIncomeTemplates)
          InputChip(
            avatar: const Icon(Icons.event_repeat_outlined, size: 18),
            label: Text(
              '${template.dayOfMonth}日 ${template.name} ${_formatManagementYen(template.amount)}',
            ),
            onPressed: () => _showRecurringIncomeTemplateDialog(
              workbook,
              existing: template,
            ),
            onDeleted: () => _deleteRecurringIncomeTemplate(template.id),
          ),
      ],
    );
  }

  Widget _buildAssetCashflowTable(AssetLiabilityWorkbook workbook) {
    if (workbook.cashflowRows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '支払日順 資金繰り',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '入金済み・支払済みにした項目は、現在の口座残高に反映済みとして扱います。まだ残高を更新していない場合はチェックしないでください。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 56,
            columns: const [
              DataColumn(label: Text('支払日'), numeric: true),
              DataColumn(label: Text('支払先')),
              DataColumn(label: Text('支払原資口座')),
              DataColumn(label: Text('支払予定額'), numeric: true),
              DataColumn(label: Text('区分')),
              DataColumn(label: Text('支払済み')),
              DataColumn(label: Text('支払後手元'), numeric: true),
              DataColumn(label: Text('危険度')),
            ],
            rows: [
              for (final row in workbook.cashflowRows)
                DataRow(
                  cells: [
                    DataCell(Text('${row.paymentDay}日')),
                    DataCell(Text(row.accountName)),
                    DataCell(
                      row.isPayment
                          ? _buildPaymentSourceDropdown(row, workbook)
                          : Text(row.destinationAccountName ?? '未設定'),
                    ),
                    DataCell(Text(_formatManagementYen(row.paymentAmount))),
                    DataCell(Text(_cashflowKindLabel(row))),
                    DataCell(_buildPaymentProgressChip(row)),
                    DataCell(Text(_formatManagementYen(row.cashAfterPayment))),
                    DataCell(_buildCashflowStatusChip(row)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSourceDropdown(
    AssetLiabilityCashflowRow row,
    AssetLiabilityWorkbook workbook,
  ) {
    final options = _paymentSourceAccountOptions(workbook);
    final monthlySelected = _paymentSourceAccountIds[row.accountId];
    final defaultSelected = _defaultPaymentSourceAccountIds[row.accountId];
    final selected = monthlySelected ?? defaultSelected;
    final validSelected =
        selected != null && options.any((account) => account.id == selected);
    final isDefaultSelected =
        validSelected && defaultSelected != null && defaultSelected == selected;
    return SizedBox(
      width: 300,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: DropdownButton<String>(
              value: validSelected ? selected : '',
              isExpanded: true,
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('未設定'),
                ),
                for (final account in options)
                  DropdownMenuItem<String>(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: (value) => _updatePaymentSourceAccount(
                row.accountId,
                value == null || value.isEmpty ? null : value,
              ),
            ),
          ),
          Tooltip(
            message: isDefaultSelected ? 'デフォルトを解除' : 'この口座をデフォルトにする',
            child: IconButton(
              icon: Icon(
                isDefaultSelected ? Icons.push_pin : Icons.push_pin_outlined,
                size: 18,
              ),
              color: isDefaultSelected ? const Color(0xFF0D9488) : null,
              onPressed: validSelected
                  ? () => _updateDefaultPaymentSourceAccount(
                        row.accountId,
                        isDefaultSelected ? null : selected,
                      )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashRiskChip(AssetLiabilityCashRiskLevel riskLevel) {
    final color = _cashRiskColor(riskLevel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _cashRiskLabel(riskLevel),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildPaymentProgressChip(AssetLiabilityCashflowRow row) {
    final reflected = row.isIncome ? row.received : row.paid;
    final label = reflected
        ? '反映済み'
        : row.overdue
            ? (row.isIncome ? '入金遅れ' : '期限超過')
            : (row.isIncome ? '入金待ち' : '未払い');
    final color = reflected
        ? const Color(0xFF0D9488)
        : row.overdue
            ? const Color(0xFFB91C1C)
            : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildCashflowStatusChip(AssetLiabilityCashflowRow row) {
    if (row.overdue) {
      return _buildTextStatusChip(
        label: row.isIncome ? '入金遅れ' : '期限超過',
        color: const Color(0xFFB91C1C),
      );
    }
    return _buildCashRiskChip(row.riskLevel);
  }

  String _cashflowKindLabel(AssetLiabilityCashflowRow row) {
    if (row.isIncome) {
      return '入金';
    }
    return row.paymentAmountEstimated ? '推定' : '実額';
  }

  Widget _buildTextStatusChip({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildAccountCashflowSection(AssetLiabilityWorkbook workbook) {
    final summaries = workbook.accountCashflowSummaries;
    if (summaries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '口座別資金繰り',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 56,
            columns: const [
              DataColumn(label: Text('口座')),
              DataColumn(label: Text('現在残高'), numeric: true),
              DataColumn(label: Text('今後の支払い'), numeric: true),
              DataColumn(label: Text('今後の入金'), numeric: true),
              DataColumn(label: Text('支払後残高'), numeric: true),
              DataColumn(label: Text('判定')),
            ],
            rows: [
              for (final summary in summaries)
                DataRow(
                  cells: [
                    DataCell(Text(summary.accountName)),
                    DataCell(
                        Text(_formatManagementYen(summary.currentBalance))),
                    DataCell(
                      Text(_formatManagementYen(summary.upcomingPayments)),
                    ),
                    DataCell(
                        Text(_formatManagementYen(summary.upcomingIncome))),
                    DataCell(
                      Text(_formatManagementYen(summary.projectedBalance)),
                    ),
                    DataCell(_buildCashRiskChip(summary.riskLevel)),
                  ],
                ),
            ],
          ),
        ),
        if (workbook.hasAccountShortage) ...[
          const SizedBox(height: 8),
          _buildAccountShortageWarning(workbook),
        ],
      ],
    );
  }

  Widget _buildAccountShortageWarning(AssetLiabilityWorkbook workbook) {
    final details = workbook.shortAccountSummaries
        .map(
          (summary) =>
              '${summary.accountName}: ${_formatManagementYen(summary.shortfall)}不足',
        )
        .join(' / ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFB91C1C).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '口座別に見ると不足があります。$details',
        style: const TextStyle(
          color: Color(0xFF7F1D1D),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildMonthlySnapshotSection(AssetLiabilityWorkbook workbook) {
    final comparisons = _assetLiabilityHistoryService.compareSnapshots(
      _monthlySnapshots,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '月次履歴（保存時点）',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: _isSavingAssetLiabilitySnapshot
                        ? null
                        : () => _saveCurrentAssetLiabilitySnapshot(workbook),
                    icon: _isSavingAssetLiabilitySnapshot
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('スナップショット保存'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _downloadAssetLiabilityCsvBundle(workbook),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('CSV出力'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '保存値は月末確定ではなく保存時点の値です。月次履歴・支払予定・収入予定・口座別資金繰りをCSV出力できます。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          if (comparisons.isEmpty)
            Text(
              'まだ月次スナップショットはありません。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('月')),
                  DataColumn(label: Text('資産合計'), numeric: true),
                  DataColumn(label: Text('前月比'), numeric: true),
                  DataColumn(label: Text('負債合計'), numeric: true),
                  DataColumn(label: Text('前月比'), numeric: true),
                  DataColumn(label: Text('純資産'), numeric: true),
                  DataColumn(label: Text('前月比'), numeric: true),
                  DataColumn(label: Text('手元現金'), numeric: true),
                  DataColumn(label: Text('前月比'), numeric: true),
                  DataColumn(label: Text('支払予定'), numeric: true),
                  DataColumn(label: Text('実支払済み'), numeric: true),
                  DataColumn(label: Text('未払い'), numeric: true),
                  DataColumn(label: Text('期限超過'), numeric: true),
                ],
                rows: [
                  for (final comparison in comparisons)
                    DataRow(
                      cells: [
                        DataCell(Text(comparison.snapshot.monthKey)),
                        DataCell(
                          Text(
                            _formatManagementYen(
                              comparison.snapshot.positiveAssetTotal,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatManagementDeltaYen(
                              comparison.positiveAssetDelta,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatManagementYen(
                              comparison.snapshot.liabilityTotal,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatManagementDeltaYen(
                              comparison.liabilityDelta,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatManagementYen(
                              comparison.snapshot.netWorth,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatManagementDeltaYen(comparison.netWorthDelta),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatManagementYen(
                              comparison.snapshot.cashLikeTotal,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatManagementDeltaYen(comparison.cashLikeDelta),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatManagementYen(
                              comparison.snapshot.monthlyScheduledPaymentTotal,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatManagementYen(
                              comparison.snapshot.monthlyPaidPaymentTotal,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatManagementYen(
                              comparison.snapshot.monthlyUnpaidPaymentTotal,
                            ),
                          ),
                        ),
                        DataCell(
                          Text('${comparison.snapshot.overduePaymentCount}件'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransferSuggestionSection(AssetLiabilityWorkbook workbook) {
    if (workbook.transferSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF0D9488).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '口座間移動の提案',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'この提案は不足額ベースの簡易提案です。実際の引落順、手数料、入金予定は確認してください。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          for (final suggestion in workbook.transferSuggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${suggestion.fromAccountName}から${suggestion.toAccountName}へ ${_formatManagementYen(suggestion.amount)} 移動すると、${suggestion.neededBy == null ? '今月の支払い' : DateFormat('M/d').format(suggestion.neededBy!)}を安全に通過しやすくなります。',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssetWorkbookDebtTable(AssetLiabilityWorkbook workbook) {
    if (workbook.debtMasterRows.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = workbook.debtMasterRows.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '負債マスタ（残高順）',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 76,
            columns: const [
              DataColumn(label: Text('項目')),
              DataColumn(label: Text('種別')),
              DataColumn(label: Text('残高'), numeric: true),
              DataColumn(label: Text('支払日'), numeric: true),
              DataColumn(label: Text('推定最低支払額'), numeric: true),
              DataColumn(label: Text('今月支払予定額'), numeric: true),
              DataColumn(label: Text('区分')),
              DataColumn(label: Text('支払済み')),
              DataColumn(label: Text('年利'), numeric: true),
              DataColumn(label: Text('月利息'), numeric: true),
              DataColumn(label: Text('負債割合'), numeric: true),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text(row.name)),
                    DataCell(Text(_assetKindLabel(row.kind))),
                    DataCell(Text(_formatManagementYen(row.balance))),
                    DataCell(
                      Text(
                        row.paymentDay == null ? '未設定' : '${row.paymentDay}日',
                      ),
                    ),
                    DataCell(
                      Text(_formatManagementYen(row.minimumPaymentEstimate)),
                    ),
                    DataCell(_buildMonthlyPaymentInput(row)),
                    DataCell(_buildPaymentAmountSourceChip(row)),
                    DataCell(_buildPaidCheckbox(row)),
                    DataCell(Text(_formatManagementPercent(row.annualRate))),
                    DataCell(
                      Text(
                        _formatManagementYen(row.monthlyInterestEstimate),
                      ),
                    ),
                    DataCell(
                        Text(_formatManagementPercent(row.liabilityShare))),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyPaymentInput(AssetLiabilityDebtRow row) {
    final controller = _monthlyPaymentControllerFor(row);
    return SizedBox(
      width: 150,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
        ],
        onChanged: (value) => _updateMonthlyPaymentOverride(row.id, value),
        decoration: InputDecoration(
          isDense: true,
          hintText: _formatManagementYen(row.minimumPaymentEstimate),
          helperText: row.paymentAmountEstimated ? '未入力時は推定' : '実額を優先',
          suffixIcon: row.paymentAmountEstimated
              ? null
              : IconButton(
                  tooltip: '手入力値をクリア',
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => _clearMonthlyPaymentOverride(row.id),
                ),
        ),
      ),
    );
  }

  Widget _buildPaymentAmountSourceChip(AssetLiabilityDebtRow row) {
    final isEstimated = row.paymentAmountEstimated;
    final color =
        isEstimated ? const Color(0xFFD97706) : const Color(0xFF0D9488);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isEstimated ? '推定' : '実額',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildPaidCheckbox(AssetLiabilityDebtRow row) {
    return Checkbox(
      value: row.paid,
      onChanged: (value) => _toggleMonthlyPaymentPaid(row.id, value ?? false),
    );
  }

  Widget _buildAssetWorkbookPriorityList(AssetLiabilityWorkbook workbook) {
    final rows = workbook.repaymentPriorityRows.take(4).toList();
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '返済優先（推定金利順）',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < rows.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}.',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${rows[index].name} / ${_formatManagementYen(rows[index].balance)} / 年利 ${_formatManagementPercent(rows[index].annualRate)} / ${rows[index].priorityLabel}',
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            '今月支払予定額が未入力のものは、契約条件ベースの推定最低支払額で表示しています。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _paymentRiskStatusLabel(AssetLiabilityPaymentDayRisk risk) {
    if (risk.isToday) return '今日';
    if (risk.isPast) return '通過済み';
    return '今月これから';
  }

  String _paymentRiskPaymentSourceLabel(AssetLiabilityPaymentDayRisk risk) {
    if (!risk.hasEstimatedPayments) {
      return '全て実額';
    }
    if (!risk.hasManualPayments) {
      return '全て推定';
    }
    return '実額 ${risk.manualPaymentCount}件 / 推定 ${risk.estimatedPaymentCount}件';
  }

  String _cashRiskLabel(AssetLiabilityCashRiskLevel riskLevel) {
    switch (riskLevel) {
      case AssetLiabilityCashRiskLevel.short:
        return '資金ショート';
      case AssetLiabilityCashRiskLevel.caution:
        return '要注意';
      case AssetLiabilityCashRiskLevel.watch:
        return '警戒';
      case AssetLiabilityCashRiskLevel.normal:
        return '通常';
    }
  }

  Color _cashRiskColor(AssetLiabilityCashRiskLevel riskLevel) {
    switch (riskLevel) {
      case AssetLiabilityCashRiskLevel.short:
        return const Color(0xFFB91C1C);
      case AssetLiabilityCashRiskLevel.caution:
        return const Color(0xFFFF6B35);
      case AssetLiabilityCashRiskLevel.watch:
        return const Color(0xFFD97706);
      case AssetLiabilityCashRiskLevel.normal:
        return const Color(0xFF0D9488);
    }
  }

  String _assetKindLabel(AssetLiabilityAccountKind kind) {
    switch (kind) {
      case AssetLiabilityAccountKind.cash:
        return '現金';
      case AssetLiabilityAccountKind.deposit:
        return '現金預金';
      case AssetLiabilityAccountKind.securities:
        return '証券';
      case AssetLiabilityAccountKind.cardLoan:
        return 'カードローン';
      case AssetLiabilityAccountKind.shoppingDebt:
        return 'ショッピング債務';
      case AssetLiabilityAccountKind.creditCard:
        return 'クレカ';
      case AssetLiabilityAccountKind.utility:
        return '通信/公共料金';
      case AssetLiabilityAccountKind.otherAsset:
        return 'その他資産';
      case AssetLiabilityAccountKind.otherLiability:
        return 'その他負債';
    }
  }

  String _formatManagementYen(num value) {
    final sign = value < 0 ? '-' : '';
    return '$sign¥${NumberFormat('#,###').format(value.abs().round())}';
  }

  String _formatManagementDeltaYen(num? value) {
    if (value == null) {
      return '前月データなし';
    }
    if (value == 0) {
      return '±¥0';
    }
    final sign = value > 0 ? '+' : '-';
    return '$sign¥${NumberFormat('#,###').format(value.abs().round())}';
  }

  String _formatManagementPercent(num value) {
    return '${(value * 100).toStringAsFixed(1)}%';
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
                Icon(
                  Icons.account_balance,
                  color: Color(0xFF0D9488),
                ),
                SizedBox(
                  width: 8,
                ),
                Text(
                  '①資産・②負債の全容把握',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            const Text(
              '現金、銀行口座、クレカの未払い(マイナス入力)をすべて記録せよ。',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildAssetWatchlistSection(),
            const SizedBox(height: 16),
            ..._assetTypes.map((type) => _buildAssetInputRow(type)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _showAddAssetDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('項目を追加'),
                ),
                TextButton.icon(
                  onPressed: _isFetchingSmbc ? null : _fetchSmbcDataFromSheet,
                  icon: _isFetchingSmbc
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download,
                          color: Color(0xFF0D9488)),
                  label: const Text('三井住友から取得'),
                ),
                TextButton.icon(
                  onPressed: _isFetchingJibun ? null : _fetchJibunDataFromSheet,
                  icon: _isFetchingJibun
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download,
                          color: Color(0xFFea580c)),
                  label: const Text('じぶん銀行から取得'),
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
                  backgroundColor: const Color(0xFF065F46),
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
    final watchlistEntry = _watchlistByType[type];

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
        key: _assetRowKeyForType(type),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (watchlistEntry != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildWatchlistMetaChip(
                    icon: Icons.star,
                    label: watchlistEntry.group.isEmpty
                        ? 'Watching'
                        : 'Watch: ${watchlistEntry.group}',
                    iconColor: const Color(0xFF92400E),
                  ),
                  if (watchlistEntry.memo.isNotEmpty)
                    _buildWatchlistMetaChip(
                      icon: Icons.sticky_note_2_outlined,
                      label: watchlistEntry.memo,
                    ),
                ],
              ),
            ),
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
                        fillColor:
                            isUpdatedToday ? const Color(0xFF64748B) : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: watchlistEntry == null
                              ? 'Add to watchlist'
                              : 'Edit watchlist',
                          onPressed: () => _showWatchlistDialog(type),
                          icon: Icon(
                            watchlistEntry == null
                                ? Icons.star_border
                                : Icons.star,
                            color: watchlistEntry == null
                                ? const Color(0xFF64748B)
                                : const Color(0xFF92400E),
                          ),
                        ),
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
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF047857),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(isUpdatedToday ? '済' : '記録'),
                        ),
                        if (type != '現金')
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFF9CA3AF),
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
                          fillColor:
                              isUpdatedToday ? const Color(0xFF64748B) : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: watchlistEntry == null
                          ? 'Add to watchlist'
                          : 'Edit watchlist',
                      onPressed: () => _showWatchlistDialog(type),
                      icon: Icon(
                        watchlistEntry == null ? Icons.star_border : Icons.star,
                        color: watchlistEntry == null
                            ? const Color(0xFF64748B)
                            : const Color(0xFF92400E),
                      ),
                    ),
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
                        backgroundColor: isUpdatedToday
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF047857),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isUpdatedToday ? '済' : '記録'),
                    ),
                    if (type != '現金')
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFF9CA3AF),
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
                    color: isLiability
                        ? const Color(0xFFF87171)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '現在: ¥${NumberFormat('#,###').format(lastAmount)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isLiability
                          ? const Color(0xFF64748B)
                          : const Color(0xFF047857),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${lastDate == todayStr ? "本日更新" : "最終更新: $lastDate"})',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  if (canQuickUpdate) ...[
                    const SizedBox(width: 8),
                    const Text(
                      '昨日と同額なら「同額」で更新',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        height: 1.5,
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
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWatchlistMetaChip({
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? const Color(0xFF334155)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetWatchlistSection() {
    final entries = _visibleWatchlistEntries;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF64748B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFF92400E)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Watchlist',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              Text(
                '${entries.length} item(s)',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Keep important assets or liabilities pinned with a short memo.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFEF3C7)),
              ),
              child: const Text(
                'Use the star button on any asset row to add it here.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            )
          else
            ...entries.map((entry) {
              final lastDate = _lastUpdatedDates[entry.assetType];
              double? lastAmount;
              if (lastDate != null) {
                lastAmount = _assetData[lastDate]?[entry.assetType];
              }
              final isLiability = (lastAmount ?? 0) < 0;
              final amountColor = isLiability
                  ? const Color(0xFF64748B)
                  : const Color(0xFF047857);

              return Container(
                key: Key('asset_watchlist_item_${entry.assetType}'),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFEF3C7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getIconForAsset(entry.assetType),
                          color: amountColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.assetType,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Jump to row',
                          onPressed: () => _jumpToAssetType(entry.assetType),
                          icon: const Icon(Icons.vertical_align_bottom),
                        ),
                        IconButton(
                          tooltip: 'Edit watchlist',
                          onPressed: () =>
                              _showWatchlistDialog(entry.assetType),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (entry.group.isNotEmpty)
                          _buildWatchlistMetaChip(
                            icon: Icons.folder_open_outlined,
                            label: entry.group,
                            iconColor: const Color(0xFF92400E),
                          ),
                        if (lastAmount != null)
                          _buildWatchlistMetaChip(
                            icon: isLiability
                                ? Icons.trending_down
                                : Icons.trending_up,
                            label:
                                'Latest ${NumberFormat('#,###').format(lastAmount)}',
                            iconColor: amountColor,
                          ),
                        if (lastDate != null)
                          _buildWatchlistMetaChip(
                            icon: Icons.schedule,
                            label: 'Updated $lastDate',
                          ),
                      ],
                    ),
                    if (entry.memo.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        entry.memo,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                  color: Color(0xFF0D9488),
                  fontWeight: FontWeight.bold,
                  height: 1.5,
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
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('純資産:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  )),
              Text(
                '¥${NumberFormat('#,###').format(totalAssets + totalLiabilities)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ④ 今月の支出と収入
  // ignore: unused_element
  Widget _buildFlowCardLegacy() {
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
                Icon(Icons.receipt_long, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text(
                  '④収支の記録',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            Text(
              'お金の流れをすべてリスト化する。表示中: $visibleMonthLabel（過去月に切替可）',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
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
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.6,
                              ),
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
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('MM/dd').format(_selectedFlowDate)),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: const Color(0xFF64748B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF475569).withValues(alpha: 0.12)),
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
                                color: Color(0xFF9CA3AF),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              visibleMonthLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                height: 1.5,
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
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.6,
                              ),
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
                    backgroundColor: const Color(0xFF64748B),
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
                color: const Color(0xFF64748B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$visibleMonthLabel 収入',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '¥${NumberFormat('#,###').format(totalIncome)}',
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '$visibleMonthLabel 支出',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '¥${NumberFormat('#,###').format(totalExpense)}',
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('収支差額',
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.5,
                          )),
                      Text(
                        '¥${NumberFormat('#,###').format(totalIncome - totalExpense)}',
                        style: TextStyle(
                          color: (totalIncome - totalExpense) >= 0
                              ? const Color(0xFF065F46)
                              : const Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
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
                        onTap: () => _editFlow(item),
                        leading: Icon(
                          isIncome ? Icons.add_circle : Icons.remove_circle,
                          color: isIncome
                              ? const Color(0xFF0D9488)
                              : const Color(0xFFB91C1C),
                          size: 20,
                        ),
                        title: Text(desc,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.6,
                            )),
                        subtitle: Text(
                          '${DateFormat('MM/dd').format(date)} ・ タップで編集',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isIncome ? '+' : '-'}¥${NumberFormat('#,###').format(amount)}',
                              style: TextStyle(
                                color: isIncome
                                    ? const Color(0xFF0D9488)
                                    : const Color(0xFFB91C1C),
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: '編集',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: const Color(0xFF64748B),
                              onPressed: () => _editFlow(item),
                            ),
                            IconButton(
                              tooltip: '削除',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: const Color(0xFFF87171),
                              onPressed: () => _deleteFlow(item),
                            ),
                          ],
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
  Widget _buildFlowCard() {
    final visibleFlows = _flowsForMonth(_selectedFlowHistoryMonth);
    final visibleMonthLabel = _flowMonthLabel(_selectedFlowHistoryMonth);
    final canMoveForward = !_isSameMonth(
      _selectedFlowHistoryMonth,
      DateTime.now(),
    );
    final isTransferSelected = _selectedFlowType == '振替';
    final transferOptions = _transferDestinationOptions(
      _selectedSource,
      include: _selectedTransferDestination,
    );
    int totalIncome = 0;
    int totalExpense = 0;
    int totalTransfer = 0;

    for (final item in visibleFlows) {
      final amount = (item['amount'] as num?)?.toInt() ?? 0;
      final actionType = item['action_type'] as String? ?? '';
      if (_isIncomeActionType(actionType)) totalIncome += amount;
      if (_isExpenseActionType(actionType)) totalExpense += amount;
      if (_isTransferActionType(actionType)) totalTransfer += amount;
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
                Icon(Icons.receipt_long, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text(
                  '④収支の記録',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            Text(
              'お金の流れをすべてリスト化する。収入・支出に加えて口座間の振替も記録できます。表示中: $visibleMonthLabel（過去月に切替可）',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _isImportingSmbcCsv ? null : _pickAndImportSmbcCsv,
                icon: _isImportingSmbcCsv
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  _isImportingSmbcCsv ? '三井住友CSV取込中...' : '三井住友CSV取込',
                ),
              ),
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
                    items: _flowTypeOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _updateSelectedFlowType(value);
                      }
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
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('MM/dd').format(_selectedFlowDate)),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: const Color(0xFF64748B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF475569).withValues(alpha: 0.12)),
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
                                color: Color(0xFF9CA3AF),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              visibleMonthLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '次月',
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
                    decoration: InputDecoration(
                      labelText: isTransferSelected ? '振替元' : '入出金元',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    items: _sourceOptions
                        .map(
                          (source) => DropdownMenuItem(
                            value: source,
                            child: Text(
                              _sourceLabel(source),
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _updateSelectedSource(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: isTransferSelected
                      ? DropdownButtonFormField<String>(
                          initialValue: _selectedTransferDestination,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '振替先',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          items: transferOptions
                              .map(
                                (source) => DropdownMenuItem(
                                  value: source,
                                  child: Text(
                                    _sourceLabel(source),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(
                                () => _selectedTransferDestination = value,
                              );
                            }
                          },
                        )
                      : TextField(
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
            if (_isExpenseFlowSelected) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _selectedWasteCategory,
                decoration: const InputDecoration(
                  labelText: '浪費カテゴリ',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('分類なし'),
                  ),
                  ...WasteTrackingService.categoryLabels.map(
                    (label) => DropdownMenuItem<String?>(
                      value: label,
                      child: Text(label),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedWasteCategory =
                        WasteTrackingService.normalizeCategory(value);
                  });
                },
              ),
            ],
            if (isTransferSelected) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _flowMemoController,
                decoration: const InputDecoration(
                  labelText: 'メモ（任意）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
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
                    backgroundColor: const Color(0xFF64748B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(isTransferSelected ? '振替を追加' : '追加'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF64748B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$visibleMonthLabel 収入',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '￥${NumberFormat('#,###').format(totalIncome)}',
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '$visibleMonthLabel 支出',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '￥${NumberFormat('#,###').format(totalExpense)}',
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('収支差額',
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.5,
                          )),
                      Text(
                        '￥${NumberFormat('#,###').format(totalIncome - totalExpense)}',
                        style: TextStyle(
                          color: (totalIncome - totalExpense) >= 0
                              ? const Color(0xFF065F46)
                              : const Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (totalTransfer > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$visibleMonthLabel の振替合計: ￥${NumberFormat('#,###').format(totalTransfer)}（収支差額には含めません）',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (visibleFlows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text('$visibleMonthLabel の記録はありません')),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visibleFlows.length,
                itemBuilder: (context, index) {
                  final item = visibleFlows[index];
                  final actionType = item['action_type']?.toString() ?? '';
                  final parsed = _parseFlowDescription(
                    item['description']?.toString() ?? '',
                    actionType: actionType,
                  );
                  final amount = (item['amount'] as num?)?.toInt() ?? 0;
                  final date = DateTime.tryParse(
                        item['occurred_at']?.toString() ?? '',
                      )?.toLocal() ??
                      _selectedFlowHistoryMonth;
                  final subtitleParts = <String>[
                    DateFormat('MM/dd').format(date),
                    _actionTypeToFlowLabel(actionType),
                  ];
                  if (!parsed.isTransfer && parsed.source.isNotEmpty) {
                    subtitleParts.add(_sourceLabel(parsed.source));
                  }
                  if (parsed.wasteCategory != null) {
                    subtitleParts.add('浪費:${parsed.wasteCategory}');
                  }
                  subtitleParts.add('タップで編集');

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _editFlow(item),
                    leading: Icon(
                      _flowActionIcon(actionType),
                      color: _flowActionColor(actionType),
                      size: 20,
                    ),
                    title: Text(
                      _flowDisplayTitle(item),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                    subtitle: Text(
                      subtitleParts.join(' ・ '),
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_flowAmountPrefix(actionType)}￥${NumberFormat('#,###').format(amount)}',
                          style: TextStyle(
                            color: _flowActionColor(actionType),
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: '編集',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          color: const Color(0xFF64748B),
                          onPressed: () => _editFlow(item),
                        ),
                        IconButton(
                          tooltip: '削除',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: const Color(0xFFF87171),
                          onPressed: () => _deleteFlow(item),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 4),
            Text(
              '履歴の行をタップするか、右の編集・削除ボタンから日付・口座・内容・金額の修正や誤登録の削除ができます。振替は差額に含めず、移動履歴としてだけ残ります。',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            decoration: const BoxDecoration(
              color: Color(0xFF64748B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.credit_card_off, color: Color(0xFF991B1B)),
                          SizedBox(width: 8),
                          Text(
                            '③固定費をすべて把握',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '毎月自動で奪われる富を監視せよ。',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickSubscriptionHistoryMonth,
                        child: Text(
                          '表示中: $visibleMonthLabel',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB91C1C),
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¥${NumberFormat('#,###').format(totalCost)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF991B1B),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '未払い: ¥${NumberFormat('#,###').format(unpaidCost)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: unpaidCost > 0
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFF047857),
                          height: 1.5,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.credit_card_off,
                                color: Color(0xFF991B1B),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '③固定費をすべて把握',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '毎月自動で奪われる富を監視せよ。',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '表示月',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9CA3AF),
                              height: 1.5,
                            ),
                          ),
                          Text(
                            visibleMonthLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB91C1C),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '月額合計',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9CA3AF),
                              height: 1.5,
                            ),
                          ),
                          Text(
                            '¥${NumberFormat('#,###').format(totalCost)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '未払い: ¥${NumberFormat('#,###').format(unpaidCost)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: unpaidCost > 0
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFF047857),
                              height: 1.5,
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
                color: const Color(0xFF64748B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFB91C1C).withValues(alpha: 0.12)),
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
                                color: Color(0xFF9CA3AF),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              visibleMonthLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                height: 1.5,
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
                                    color:
                                        isPaid ? const Color(0xFF9CA3AF) : null,
                                    fontWeight: isPaid
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '¥${NumberFormat('#,###').format(item['price'])}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isPaid
                                      ? const Color(0xFF9CA3AF)
                                      : Theme.of(context).colorScheme.onSurface,
                                  height: 1.5,
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
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFFB91C1C),
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              if (src.isNotEmpty)
                                Text(
                                  '引落先: $src',
                                  style: TextStyle(
                                    color: isPaid
                                        ? const Color(0xFF9CA3AF)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    fontSize: 12,
                                    height: 1.5,
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
                                  style: TextStyle(
                                    color: Color(0xFFB91C1C),
                                    height: 1.5,
                                  ),
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
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF991B1B)),
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
                Icon(Icons.assignment_late, color: Color(0xFFFF6B35)),
                SizedBox(width: 8),
                Text(
                  '⑤今月の必須タスク',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            const Text(
              '今月中に必ず処理すべき事務手続き等を記録せよ。',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
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
                                height: 1.5,
                              ),
                            ),
                            subtitle: Text(
                              '締切: ${DateFormat('yyyy/MM/dd').format(deadline)}',
                              style: TextStyle(
                                color: isOverdue
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF9CA3AF),
                                height: 1.5,
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
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B)),
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
                        height: 1.5,
                      ),
                    ),
                    Text(
                      _showDailyChange ? '昨日の自分に勝ったか？' : '国力(富)の総量は増えているか？',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9CA3AF),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.show_chart, size: 16),
                    Switch(
                      value: _showDailyChange,
                      activeThumbColor: const Color(0xFFB91C1C),
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
                  const Text('個別',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.5,
                      )),
                  Switch(
                    value: _isStacked,
                    activeThumbColor: const Color(0xFF0D9488),
                    onChanged: (value) {
                      setState(() {
                        _isStacked = value;
                        _updateChartData();
                      });
                    },
                  ),
                  const Text('合計',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.5,
                      )),
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
        borderData: FlBorderData(
            show: true,
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant)),
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
                  color: rod.toY >= 0
                      ? Colors.lightGreenAccent
                      : const Color(0xFFB91C1C),
                  fontWeight: FontWeight.bold,
                  height: 1.5,
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
              return FlLine(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  strokeWidth: 1);
            }
            return FlLine(
                color: Theme.of(context).colorScheme.outlineVariant,
                strokeWidth: 1);
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
    const style = TextStyle(
      fontSize: 10,
      height: 1.5,
    );
    String text = '';
    if (value.toInt() < _sortedDates.length) {
      text = DateFormat('MM/dd')
          .format(DateTime.parse(_sortedDates[value.toInt()]));
    }
    return SideTitleWidget(
      meta: meta,
      child: Text(text, style: style),
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    final format = NumberFormat.compact(locale: 'ja_JP');
    return SideTitleWidget(
      meta: meta,
      space: 8,
      child: Text(format.format(value),
          style: const TextStyle(
            fontSize: 10,
            height: 1.5,
          )),
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
        const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
      if (_isStacked)
        LineTooltipItem(
          '総資産: $formattedTotal\n',
          const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            height: 1.5,
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
          TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
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
