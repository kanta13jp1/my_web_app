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
import 'package:my_web_app/models/asset_liability_sync_audit_log.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/debt_repayment_plan.dart';
import 'package:my_web_app/models/kgi_csf_kpi.dart';
import 'package:my_web_app/models/user_profile.dart';
import 'package:my_web_app/services/asset_liability_annual_rate_evidence_service.dart';
import 'package:my_web_app/services/asset_liability_card_statement_import_service.dart';
import 'package:my_web_app/services/asset_liability_csv_restore_service.dart';
import 'package:my_web_app/services/asset_liability_history_service.dart';
import 'package:my_web_app/services/asset_liability_monthly_report_service.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_payment_reminder_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_liability_repayment_simulation_service.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_management_ai_summary_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';
import 'package:my_web_app/services/asset_waste_training_ai_service.dart';
import 'package:my_web_app/services/asset_watchlist_service.dart';
import 'package:my_web_app/services/debt_lockdown_service.dart';
import 'package:my_web_app/services/debt_repayment_planner_service.dart';
import 'package:my_web_app/services/disposable_balance_asset_liability_adapter.dart';
import 'package:my_web_app/services/disposable_balance_service.dart';
import 'package:my_web_app/services/profile_service.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';
import 'package:my_web_app/services/smbc_csv_import_service.dart';
import 'package:my_web_app/services/waste_tracking_service.dart';
import 'package:my_web_app/utils/note_image_clipboard.dart';
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

enum AssetDebtPlannerMode { ask, code }

enum _CardBillingSaveScope { defaultSetting, monthlyOverride }

class AssetManagementPage extends StatefulWidget {
  final AssetManagementInitialFocus initialFocus;
  final bool emphasizeMonthlyFlow;
  final AssetWatchlistService watchlistService;
  final AssetLiabilityRepository? assetLiabilityRepository;
  final String? entryLabel;
  final String? entryDescription;

  const AssetManagementPage({
    super.key,
    this.initialFocus = AssetManagementInitialFocus.overview,
    this.emphasizeMonthlyFlow = false,
    this.watchlistService = const AssetWatchlistService(),
    this.assetLiabilityRepository,
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
  static const List<String> _jibunCandidateSheetGids = <String>['0'];
  static const int _salarySpendingSalaryDay = 25;
  static const List<Color> _salarySpendingChartColors = <Color>[
    Color(0xFF0F766E),
    Color(0xFF2563EB),
    Color(0xFFF97316),
    Color(0xFF9333EA),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
    Color(0xFF65A30D),
    Color(0xFF7C3AED),
    Color(0xFFB45309),
    Color(0xFF475569),
  ];

  final _supabase = Supabase.instance.client;
  final ProfileService _profileService = ProfileService();

  // --- 今日18:00締切のためのチェックリスト ---
  final ScrollController _scrollController = ScrollController();
  final ScrollController _debtMasterHorizontalScrollController =
      ScrollController();
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
  Map<String, double> _actualPaymentAmounts = <String, double>{};
  Map<String, String> _paymentDifferenceReasons = <String, String>{};
  Map<String, double> _annualRateOverrides = <String, double>{};
  Map<String, AssetLiabilityAnnualRateEvidence> _annualRateEvidences =
      <String, AssetLiabilityAnnualRateEvidence>{};
  Set<String> _monthlyPaidAccountNames = <String>{};
  Map<String, String> _paymentSourceAccountIds = <String, String>{};
  Map<String, String> _cardBillingAccountIds = <String, String>{};
  List<AssetLiabilityCardStatementLine> _cardStatementLines =
      <AssetLiabilityCardStatementLine>[];
  Map<String, String> _defaultPaymentSourceAccountIds = <String, String>{};
  Map<String, String> _defaultCardBillingAccountIds = <String, String>{};
  final Map<String, _CardBillingSaveScope> _cardBillingSaveScopes =
      <String, _CardBillingSaveScope>{};
  List<AssetLiabilityIncomePlan> _monthlyIncomePlans =
      <AssetLiabilityIncomePlan>[];
  List<AssetLiabilityTransferTask> _transferTasks =
      <AssetLiabilityTransferTask>[];
  List<AssetLiabilityRecurringIncomeTemplate> _recurringIncomeTemplates =
      <AssetLiabilityRecurringIncomeTemplate>[];
  List<AssetLiabilityMonthlySnapshot> _monthlySnapshots =
      <AssetLiabilityMonthlySnapshot>[];
  List<AssetLiabilityMonthlyReport> _monthlyReports =
      <AssetLiabilityMonthlyReport>[];
  String? _selectedMonthlyReportMonthKey;
  bool _isRefreshingMonthlyReports = false;
  String? _monthlyReportMessage;
  String? _loadedAssetLiabilityMonthKey;
  bool _isSavingAssetLiabilitySnapshot = false;
  bool _isRunningAssetLiabilitySync = false;
  bool _isPreviewingAssetLiabilitySync = false;
  bool _isResolvingAssetLiabilityConflict = false;
  AssetLiabilityManualSyncStatus _assetLiabilitySyncStatus =
      AssetLiabilityManualSyncStatus.notRun;
  DateTime? _lastAssetLiabilitySyncAt;
  String? _assetLiabilitySyncMessage;
  List<String> _assetLiabilitySyncConflicts = <String>[];
  AssetLiabilitySyncPreviewResult? _assetLiabilitySyncPreview;
  List<AssetLiabilitySyncAuditLog> _assetLiabilitySyncAuditLogs =
      <AssetLiabilitySyncAuditLog>[];
  final Map<String, TextEditingController> _monthlyPaymentControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _actualPaymentControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _paymentDifferenceReasonControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _annualRateControllers =
      <String, TextEditingController>{};
  final Set<String> _verifyingAnnualRateEvidenceAccountIds = <String>{};
  NoteImagePasteRegistration? _annualRateEvidencePasteRegistration;
  AssetLiabilityDebtRow? _annualRateEvidencePasteTargetRow;
  final TextEditingController _cardStatementImportController =
      TextEditingController();
  final TextEditingController _assetCsvRestoreController =
      TextEditingController();
  final TextEditingController _repaymentSimulationExtraPaymentController =
      TextEditingController(text: '0');
  String? _selectedCardStatementBillingAccountId;
  String? _cardStatementImportMessage;
  AssetLiabilityCsvRestorePreview? _assetCsvRestorePreview;
  String? _assetCsvRestoreMessage;
  bool _isApplyingAssetCsvRestore = false;

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
  DateTime _selectedFlowHistoryMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  String _selectedSource = '[現金]';
  String _selectedTransferDestination = '[銀行口座]';
  String _selectedFlowType = '支出'; // 支出 / 収入 / 振替
  String? _selectedWasteCategory;
  final TextEditingController _flowMemoController = TextEditingController();
  final TextEditingController _flowAmountController = TextEditingController();
  List<Map<String, dynamic>> _recentFlows = []; // 収支履歴

  // --- サブスク（固定費）用変数 ---
  DateTime _selectedSubscriptionHistoryMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _subscriptionsThreeMonths = [];
  bool _isLoadingSubscriptions = false;

  // --- 必須タスク用変数 ---
  List<Map<String, dynamic>> _mustTasks = [];
  bool _isLoadingTasks = false;

  // --- 返済計画用 ---
  late final AssetLiabilityRepository _assetLiabilityRepository;
  final AssetLiabilityPlanningService _assetLiabilityPlanner =
      const AssetLiabilityPlanningService();
  final AssetLiabilityPaymentReminderService _assetLiabilityReminderService =
      const AssetLiabilityPaymentReminderService();
  final AssetLiabilityRepaymentSimulationService
      _assetLiabilityRepaymentSimulationService =
      const AssetLiabilityRepaymentSimulationService();
  final AssetLiabilityCardStatementImportService _cardStatementImportService =
      const AssetLiabilityCardStatementImportService();
  final AssetLiabilityCsvRestoreService _assetLiabilityCsvRestoreService =
      const AssetLiabilityCsvRestoreService();
  final AssetLiabilityAnnualRateEvidenceService _annualRateEvidenceService =
      AssetLiabilityAnnualRateEvidenceService();
  final AssetLiabilityHistoryService _assetLiabilityHistoryService =
      const AssetLiabilityHistoryService();
  final AssetLiabilityMonthlyReportService _assetLiabilityMonthlyReportService =
      const AssetLiabilityMonthlyReportService();
  final AssetManagementInsightService _assetManagementInsightService =
      const AssetManagementInsightService();
  final AssetManagementAiSummaryService _assetManagementAiSummaryService =
      AssetManagementAiSummaryService();
  final SalarySpendingBreakdownService _salarySpendingBreakdownService =
      const SalarySpendingBreakdownService();
  final DisposableBalanceService _disposableBalanceService =
      const DisposableBalanceService();
  final DisposableBalanceAssetLiabilityAdapter
      _disposableBalanceAssetLiabilityAdapter =
      const DisposableBalanceAssetLiabilityAdapter();
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
  AssetLiabilityRepaymentSimulationStrategy _repaymentSimulationStrategy =
      AssetLiabilityRepaymentSimulationStrategy.interestRate;
  bool _isApplyingDebtExecutionTasks = false;
  DebtLockdownSnapshot? _debtLockdownSnapshot;
  bool _isLoadingDebtLockdown = false;
  double? _debtLockdownLoadedForDebt;
  Future<AssetWasteTrainingAiReview>? _wasteTrainingAiReviewFuture;
  String? _wasteTrainingAiReviewKey;
  bool _isGeneratingAssetManagementAiSummary = false;
  AssetManagementAiSummaryResult? _assetManagementAiSummaryResult;
  String? _assetManagementAiSummaryRequestKey;
  String? _assetManagementAiSummaryInFlightKey;
  final Set<String> _assetManagementAiSummaryAutoRequestedKeys = <String>{};
  UserProfile? _assetManagementUserProfile;
  bool _isLoadingAssetManagementUserProfile = false;
  List<Map<String, dynamic>> _payslipRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _payslipSalaryIncomes = <Map<String, dynamic>>[];
  bool _isLoadingPayslipFinance = false;
  bool _isUploadingPayslip = false;
  String? _payslipIngestionMessage;
  bool _isComputingDisposableBalance = false;
  Map<String, dynamic>? _serverDisposableBalanceResult;
  String? _disposableBalanceMessage;
  String? _disposableBalanceBreakdownKey;
  final Set<String> _developerRequestIssueSubmissionKeys = <String>{};
  final Map<String, Map<String, dynamic>> _developerRequestIssueResults =
      <String, Map<String, dynamic>>{};
  bool _isCheckingExistingDeveloperRequestIssues = false;
  String? _developerRequestExistingIssueLookupKey;
  final Map<String, Map<String, dynamic>>
      _developerRequestExistingIssueResults = <String, Map<String, dynamic>>{};

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
  static final RegExp _flowImportMarkerPattern = RegExp(
    r'\s*\[import:smbc:[^\]]+\]\s*$',
  );
  static final RegExp _flowAutoAssetDeltaMarkerPattern = RegExp(
    r'\s*\[auto_asset_delta:[^\]]+\]\s*$',
  );
  static final RegExp _smbcImportKeyPattern = RegExp(
    r'\[import:(smbc:[^\]]+)\]\s*$',
  );
  static final RegExp _autoAssetDeltaKeyPattern = RegExp(
    r'\[auto_asset_delta:([^\]]+)\]\s*$',
  );
  bool get _isCompact =>
      MediaQuery.sizeOf(context).width < _compactWidthBreakpoint;

  @override
  void initState() {
    super.initState();
    _assetLiabilityRepository = widget.assetLiabilityRepository ??
        AssetLiabilityRepositoryFactory.createDefault(
          supabaseClient: _supabase,
        );
    _loadDataFromSupabase();
    _loadAssetLiabilityMonthlyState();
    _loadWatchlistEntries();
    _loadAssetManagementUserProfile();
    _loadPayslipFinanceData();
    _fetchRecentFlows();
    _fetchSubscriptions();
    _fetchMustTasks();
    _deadlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final previousMonthKey = _assetLiabilityStateMonthKey(_now);
      final nextNow = DateTime.now();
      final nextMonthKey = _assetLiabilityStateMonthKey(nextNow);
      setState(() => _now = nextNow);
      if (nextMonthKey != previousMonthKey &&
          nextMonthKey != _loadedAssetLiabilityMonthKey) {
        unawaited(_loadAssetLiabilityMonthlyState());
      }
    });
    _fetchTodayClosing();
    _loadSourceOptionsFromDb();
    _annualRateEvidencePasteRegistration = registerNoteImagePasteListener(
      isEnabled: () =>
          mounted &&
          _annualRateEvidencePasteTargetRow != null &&
          !_verifyingAnnualRateEvidenceAccountIds.contains(
            _annualRateEvidencePasteTargetRow!.id,
          ),
      onImagePasted: _handleAnnualRateEvidencePasted,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToInitialFocus();
    });
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    _monthlyPaymentControllers.forEach((_, controller) => controller.dispose());
    _actualPaymentControllers.forEach((_, controller) => controller.dispose());
    _paymentDifferenceReasonControllers.forEach(
      (_, controller) => controller.dispose(),
    );
    _annualRateControllers.forEach((_, controller) => controller.dispose());
    _cardStatementImportController.dispose();
    _assetCsvRestoreController.dispose();
    _repaymentSimulationExtraPaymentController.dispose();
    _annualRateControllers.forEach((_, controller) => controller.dispose());
    _flowMemoController.dispose();
    _flowAmountController.dispose();
    _deadlineTimer?.cancel();
    _annualRateEvidencePasteRegistration?.dispose();
    _scrollController.dispose();
    _debtMasterHorizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAssetManagementUserProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _isLoadingAssetManagementUserProfile) {
      return;
    }
    setState(() {
      _isLoadingAssetManagementUserProfile = true;
    });
    try {
      final profile = await _profileService.getProfile(userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _assetManagementUserProfile = profile;
        _isLoadingAssetManagementUserProfile = false;
        _assetManagementAiSummaryRequestKey = null;
        _assetManagementAiSummaryResult = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAssetManagementUserProfile = false;
      });
    }
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

  DateTime _assetLiabilityStateMonth(DateTime dt) {
    return AssetLiabilityMonthlyStateStore.salaryCycleMonthFor(
      dt,
      salaryDay: _salarySpendingSalaryDay,
    );
  }

  String _assetLiabilityStateMonthKey(DateTime dt) {
    return AssetLiabilityMonthlyStateStore.formatMonthKey(
      _assetLiabilityStateMonth(dt),
    );
  }

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

  String _stripFlowMetadataMarkers(String description) {
    var result = description.trim();
    result = result.replaceFirst(_flowImportMarkerPattern, '').trim();
    result = result.replaceFirst(_flowAutoAssetDeltaMarkerPattern, '').trim();
    return result;
  }

  String? _extractSmbcImportKey(String description) {
    final match = _smbcImportKeyPattern.firstMatch(description.trim());
    return match?.group(1);
  }

  String? _extractAutoAssetDeltaKey(String description) {
    final match = _autoAssetDeltaKeyPattern.firstMatch(description.trim());
    return match?.group(1);
  }

  String _withFlowImportMarker(String description, String importKey) =>
      '${description.trim()} [import:$importKey]';

  String _withFlowAutoAssetDeltaMarker(String description, String importKey) =>
      '${description.trim()} [auto_asset_delta:$importKey]';

  String _sourceLabel(String source) =>
      source.replaceAll('[', '').replaceAll(']', '').trim();

  List<String> _transferDestinationOptions(String source, {String? include}) {
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

  String _resolvedTransferDestination(String source, {String? preferred}) {
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

  double _numberFromDynamic(Object? value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
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

  KgiCsfKpiPlan _buildWasteTrainingPlan(AssetWasteTrainingSnapshot snapshot) {
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
      _wasteTrainingAiReviewFuture = _wasteTrainingAiService.generateReview(
        snapshot,
      );
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
        _monthKey(month): {'total': 0, 'completed': 0, 'pending': 0},
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
      final targetMonth = _assetLiabilityStateMonth(_now);
      final monthKey = _assetLiabilityStateMonthKey(_now);
      final state = await _assetLiabilityRepository.loadMonth(targetMonth);
      final defaultSources =
          await _assetLiabilityRepository.loadDefaultPaymentSources();
      final defaultCardBillingAccounts =
          await _assetLiabilityRepository.loadDefaultCardBillingAccounts();
      final templates =
          await _assetLiabilityRepository.loadRecurringIncomeTemplates();
      final monthlySnapshots =
          await _assetLiabilityRepository.loadMonthlySnapshots();
      final monthlyReports = await _assetLiabilityRepository.loadMonthlyReports(
        limit: 24,
      );
      final syncAuditLogs = await _assetLiabilityRepository.loadSyncAuditLogs(
        limit: 12,
      );
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
        _actualPaymentAmounts = Map<String, double>.from(
          state.actualPaymentAmounts,
        );
        _paymentDifferenceReasons = Map<String, String>.from(
          state.paymentDifferenceReasons,
        );
        _annualRateOverrides = Map<String, double>.from(
          state.annualRateOverrides,
        );
        _annualRateEvidences =
            Map<String, AssetLiabilityAnnualRateEvidence>.from(
          state.annualRateEvidences,
        );
        _monthlyPaidAccountNames = Set<String>.from(state.paidAccountNames);
        _paymentSourceAccountIds = Map<String, String>.from(
          state.paymentSourceAccountIds,
        );
        _cardBillingAccountIds = Map<String, String>.from(
          state.cardBillingAccountIds,
        );
        _cardStatementLines = List<AssetLiabilityCardStatementLine>.from(
          state.cardStatementLines,
        );
        _defaultPaymentSourceAccountIds = Map<String, String>.from(
          defaultSources,
        );
        _defaultCardBillingAccountIds = Map<String, String>.from(
          defaultCardBillingAccounts,
        );
        _monthlyIncomePlans = List<AssetLiabilityIncomePlan>.from(
          incomePlansWithTemplates,
        );
        _transferTasks = List<AssetLiabilityTransferTask>.from(
          state.transferTasks,
        );
        _recurringIncomeTemplates =
            List<AssetLiabilityRecurringIncomeTemplate>.from(templates);
        _monthlySnapshots = List<AssetLiabilityMonthlySnapshot>.from(
          monthlySnapshots,
        );
        _monthlyReports = List<AssetLiabilityMonthlyReport>.from(
          monthlyReports,
        );
        _monthlyReportMessage = null;
        _assetLiabilitySyncAuditLogs = List<AssetLiabilitySyncAuditLog>.from(
          syncAuditLogs,
        );
        _loadedAssetLiabilityMonthKey = monthKey;
        _syncPaymentStateControllers();
      });
      if (generatedTemplatePlans) {
        unawaited(_saveAssetLiabilityMonthlyState());
      }
    } catch (e) {
      debugPrint('Error loading asset liability monthly state: $e');
    }
  }

  Future<void> _refreshAssetLiabilitySyncAuditLogs() async {
    try {
      final logs = await _assetLiabilityRepository.loadSyncAuditLogs(limit: 12);
      if (!mounted) return;
      setState(() {
        _assetLiabilitySyncAuditLogs = List<AssetLiabilitySyncAuditLog>.from(
          logs,
        );
      });
    } catch (e) {
      debugPrint('Error loading asset liability sync audit logs: $e');
    }
  }

  Future<void> _refreshMonthlyAssetReports() async {
    setState(() {
      _isRefreshingMonthlyReports = true;
      _monthlyReportMessage = null;
    });
    try {
      final reports = await _assetLiabilityRepository.loadMonthlyReports(
        limit: 24,
      );
      if (!mounted) return;
      setState(() {
        _monthlyReports = List<AssetLiabilityMonthlyReport>.from(reports);
        _monthlyReportMessage = reports.isEmpty
            ? '生成済みの月次AIレポートはありません。ローカルスナップショットは引き続き確認できます。'
            : '月次レポートを更新しました。';
      });
    } catch (e) {
      debugPrint('Error loading monthly asset reports: $e');
      if (!mounted) return;
      setState(() {
        _monthlyReportMessage = '月次レポートの更新に失敗しました: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingMonthlyReports = false;
        });
      }
    }
  }

  Future<void> _persistAssetLiabilityMonthlyState() async {
    await _assetLiabilityRepository.saveMonth(
      month: _assetLiabilityStateMonth(_now),
      state: _currentAssetLiabilityMonthlyState(),
    );
  }

  AssetLiabilityMonthlyState _currentAssetLiabilityMonthlyState() {
    return AssetLiabilityMonthlyState(
      paymentOverrides: Map<String, double>.from(_monthlyPaymentOverrides),
      actualPaymentAmounts: Map<String, double>.from(_actualPaymentAmounts),
      paymentDifferenceReasons: Map<String, String>.from(
        _paymentDifferenceReasons,
      ),
      annualRateOverrides: Map<String, double>.from(_annualRateOverrides),
      annualRateEvidences: Map<String, AssetLiabilityAnnualRateEvidence>.from(
        _annualRateEvidences,
      ),
      paidAccountNames: Set<String>.from(_monthlyPaidAccountNames),
      paymentSourceAccountIds: Map<String, String>.from(
        _paymentSourceAccountIds,
      ),
      cardBillingAccountIds: Map<String, String>.from(_cardBillingAccountIds),
      cardStatementLines: List<AssetLiabilityCardStatementLine>.from(
        _cardStatementLines,
      ),
      incomePlans: List<AssetLiabilityIncomePlan>.from(_monthlyIncomePlans),
      transferTasks: List<AssetLiabilityTransferTask>.from(_transferTasks),
    );
  }

  Future<void> _saveAssetLiabilityMonthlyState() async {
    try {
      await _persistAssetLiabilityMonthlyState();
    } catch (e) {
      debugPrint('Error saving asset liability monthly state: $e');
    }
  }

  DateTime? _parseAssetLiabilityMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return null;
    }
    return DateTime(year, month);
  }

  String _assetCsvRestoreSectionLabel(AssetLiabilityCsvRestoreSection section) {
    switch (section) {
      case AssetLiabilityCsvRestoreSection.monthlyHistory:
        return 'monthly history';
      case AssetLiabilityCsvRestoreSection.paymentSchedule:
        return 'payment schedule';
      case AssetLiabilityCsvRestoreSection.cardStatement:
        return 'card statement';
      case AssetLiabilityCsvRestoreSection.incomePlans:
        return 'income plans';
      case AssetLiabilityCsvRestoreSection.accountCashflow:
        return 'account cashflow';
      case AssetLiabilityCsvRestoreSection.unknown:
        return 'unknown';
    }
  }

  String _assetCsvRestorePreviewMessage(
    AssetLiabilityCsvRestorePreview preview,
  ) {
    final sections =
        preview.detectedSections.map(_assetCsvRestoreSectionLabel).join(', ');
    final monthText = preview.affectedMonthKeys.isEmpty
        ? '0 months'
        : preview.affectedMonthKeys.join(', ');
    return [
      'Preview: ${sections.isEmpty ? 'unknown' : sections}',
      'months: $monthText',
      'payments: ${preview.restoredPaymentCount}',
      'cards: ${preview.restoredCardStatementLineCount}',
      'income: ${preview.restoredIncomeCount}',
      'snapshots: ${preview.monthlySnapshots.length}',
      'rejected: ${preview.rejectedRows.length}',
    ].join(' / ');
  }

  void _previewAssetLiabilityCsvRestore() {
    final rawText = _assetCsvRestoreController.text.trim();
    if (rawText.isEmpty) {
      setState(() {
        _assetCsvRestorePreview = null;
        _assetCsvRestoreMessage = 'Paste an exported CSV before preview.';
      });
      return;
    }
    final preview = _assetLiabilityCsvRestoreService.previewCsvText(rawText);
    setState(() {
      _assetCsvRestorePreview = preview;
      _assetCsvRestoreMessage = _assetCsvRestorePreviewMessage(preview);
    });
  }

  Future<void> _applyAssetLiabilityCsvRestore() async {
    final preview = _assetCsvRestorePreview;
    if (preview == null || !preview.hasRestorableRows) {
      setState(() {
        _assetCsvRestoreMessage = 'Preview a restorable CSV before apply.';
      });
      return;
    }
    setState(() {
      _isApplyingAssetCsvRestore = true;
      _assetCsvRestoreMessage = 'Applying append-only restore...';
    });
    try {
      final existingStates = <String, AssetLiabilityMonthlyState>{};
      final currentMonthKey = _assetLiabilityStateMonthKey(_now);
      for (final monthKey in preview.monthlyStates.keys) {
        if (monthKey == currentMonthKey) {
          existingStates[monthKey] = _currentAssetLiabilityMonthlyState();
          continue;
        }
        final month = _parseAssetLiabilityMonthKey(monthKey);
        if (month == null) continue;
        existingStates[monthKey] = await _assetLiabilityRepository.loadMonth(
          month,
        );
      }

      final mergeResult = _assetLiabilityCsvRestoreService.mergePreview(
        preview: preview,
        existingStates: existingStates,
        existingSnapshots: _monthlySnapshots,
        policy: AssetLiabilityCsvRestoreApplyPolicy.appendOnly,
      );

      for (final monthKey in preview.monthlyStates.keys) {
        final month = _parseAssetLiabilityMonthKey(monthKey);
        final state = mergeResult.monthlyStates[monthKey];
        if (month == null || state == null) continue;
        await _assetLiabilityRepository.saveMonth(month: month, state: state);
      }

      final importedSnapshotKeys =
          preview.monthlySnapshots.map((snapshot) => snapshot.monthKey).toSet();
      for (final snapshot in mergeResult.monthlySnapshots) {
        if (!importedSnapshotKeys.contains(snapshot.monthKey)) continue;
        await _assetLiabilityRepository.saveMonthlySnapshot(snapshot);
      }

      final refreshedSnapshots =
          await _assetLiabilityRepository.loadMonthlySnapshots();
      if (!mounted) return;
      final currentState = mergeResult.monthlyStates[currentMonthKey];
      setState(() {
        if (currentState != null) {
          _monthlyPaymentOverrides = Map<String, double>.from(
            currentState.paymentOverrides,
          );
          _actualPaymentAmounts = Map<String, double>.from(
            currentState.actualPaymentAmounts,
          );
          _paymentDifferenceReasons = Map<String, String>.from(
            currentState.paymentDifferenceReasons,
          );
          _annualRateOverrides = Map<String, double>.from(
            currentState.annualRateOverrides,
          );
          _annualRateEvidences =
              Map<String, AssetLiabilityAnnualRateEvidence>.from(
            currentState.annualRateEvidences,
          );
          _monthlyPaidAccountNames = Set<String>.from(
            currentState.paidAccountNames,
          );
          _paymentSourceAccountIds = Map<String, String>.from(
            currentState.paymentSourceAccountIds,
          );
          _cardBillingAccountIds = Map<String, String>.from(
            currentState.cardBillingAccountIds,
          );
          _cardStatementLines = List<AssetLiabilityCardStatementLine>.from(
            currentState.cardStatementLines,
          );
          _monthlyIncomePlans = List<AssetLiabilityIncomePlan>.from(
            currentState.incomePlans,
          );
          _transferTasks = List<AssetLiabilityTransferTask>.from(
            currentState.transferTasks,
          );
          _syncPaymentStateControllers();
        }
        _monthlySnapshots = List<AssetLiabilityMonthlySnapshot>.from(
          refreshedSnapshots,
        );
        final warningText = mergeResult.warnings.isEmpty
            ? ''
            : ' Warnings: ${mergeResult.warnings.take(3).join(' ')}';
        _assetCsvRestoreMessage =
            'Applied append-only restore for ${preview.affectedMonthKeys.length} month(s).$warningText';
      });
    } catch (e) {
      debugPrint('Error applying asset CSV restore: $e');
      if (!mounted) return;
      setState(() {
        _assetCsvRestoreMessage = 'CSV restore failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingAssetCsvRestore = false;
        });
      }
    }
  }

  Future<void> _runAssetLiabilityManualSync() async {
    if (!_assetLiabilityRepository.supabaseSyncEnabled) {
      setState(() {
        _assetLiabilitySyncStatus = AssetLiabilityManualSyncStatus.disabled;
        _lastAssetLiabilitySyncAt = DateTime.now();
        _assetLiabilitySyncMessage = 'Supabase同期は無効です';
        _assetLiabilitySyncConflicts = <String>[];
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Supabase同期は無効です')));
      return;
    }

    setState(() {
      _isRunningAssetLiabilitySync = true;
    });
    try {
      final result = await _assetLiabilityRepository.syncMonth(
        _assetLiabilityStateMonth(_now),
      );
      if (!mounted) return;
      setState(() {
        _assetLiabilitySyncStatus = result.status;
        _lastAssetLiabilitySyncAt = result.completedAt;
        _assetLiabilitySyncMessage = result.message;
        _assetLiabilitySyncConflicts = List<String>.from(
          result.conflictTargets,
        );
      });
      if (result.isSuccess) {
        await _loadAssetLiabilityMonthlyState();
      } else {
        await _refreshAssetLiabilitySyncAuditLogs();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e) {
      debugPrint('Error running asset liability manual sync: $e');
      if (!mounted) return;
      setState(() {
        _assetLiabilitySyncStatus = AssetLiabilityManualSyncStatus.failure;
        _lastAssetLiabilitySyncAt = DateTime.now();
        _assetLiabilitySyncMessage = 'Supabase同期に失敗しました: $e';
        _assetLiabilitySyncConflicts = <String>[];
      });
      await _refreshAssetLiabilitySyncAuditLogs();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Supabase同期に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isRunningAssetLiabilitySync = false;
        });
      }
    }
  }

  Future<void> _previewAssetLiabilitySync() async {
    if (!_assetLiabilityRepository.supabaseSyncEnabled) {
      final result = AssetLiabilitySyncPreviewResult.disabled();
      setState(() {
        _assetLiabilitySyncPreview = result;
      });
      await _refreshAssetLiabilitySyncAuditLogs();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    setState(() {
      _isPreviewingAssetLiabilitySync = true;
    });
    try {
      final result = await _assetLiabilityRepository.previewSyncMonth(
        _assetLiabilityStateMonth(_now),
      );
      if (!mounted) return;
      setState(() {
        _assetLiabilitySyncPreview = result;
      });
      await _refreshAssetLiabilitySyncAuditLogs();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e) {
      debugPrint('Error previewing asset liability Supabase sync: $e');
      if (!mounted) return;
      final result = AssetLiabilitySyncPreviewResult.failure(
        message: 'Supabase同期プレビューに失敗しました: $e',
      );
      setState(() {
        _assetLiabilitySyncPreview = result;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isPreviewingAssetLiabilitySync = false;
        });
      }
    }
  }

  Future<void> _refreshAssetLiabilitySyncPreviewSilently() async {
    if (!_assetLiabilityRepository.supabaseSyncEnabled) {
      return;
    }
    try {
      final result = await _assetLiabilityRepository.previewSyncMonth(
        _assetLiabilityStateMonth(_now),
      );
      if (!mounted) return;
      setState(() {
        _assetLiabilitySyncPreview = result;
        _assetLiabilitySyncConflicts = List<String>.from(
          result.conflictTargets,
        );
      });
      await _refreshAssetLiabilitySyncAuditLogs();
    } catch (e) {
      debugPrint('Error refreshing asset liability sync preview: $e');
      await _refreshAssetLiabilitySyncAuditLogs();
    }
  }

  Future<void> _resolveAssetLiabilitySyncConflict({
    required AssetLiabilitySyncPreviewItem item,
    required AssetLiabilityConflictResolutionChoice choice,
  }) async {
    if (!_assetLiabilityRepository.supabaseSyncEnabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Supabase同期は無効です')));
      return;
    }

    if (choice == AssetLiabilityConflictResolutionChoice.supabaseWins) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Supabase側の値で上書きしますか？'),
              content: Text(
                '${item.targetName} のローカル保存をSupabase側の値で置き換えます。'
                'この操作は明示確認後のみ実行します。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Supabase優先で解決'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) {
        return;
      }
    }

    setState(() {
      _isResolvingAssetLiabilityConflict = true;
    });
    try {
      final result = await _assetLiabilityRepository.resolveSyncConflicts(
        month: _assetLiabilityStateMonth(_now),
        resolutions: <AssetLiabilityConflictResolution>[
          AssetLiabilityConflictResolution(target: item.target, choice: choice),
        ],
      );
      if (!mounted) return;
      setState(() {
        _assetLiabilitySyncStatus = result.isSuccess
            ? (result.resolvedTargets.isEmpty &&
                    result.skippedTargets.isNotEmpty
                ? AssetLiabilityManualSyncStatus.conflict
                : AssetLiabilityManualSyncStatus.success)
            : AssetLiabilityManualSyncStatus.failure;
        _lastAssetLiabilitySyncAt = result.completedAt;
        _assetLiabilitySyncMessage = result.message;
      });
      if (result.isSuccess) {
        await _loadAssetLiabilityMonthlyState();
      }
      await _refreshAssetLiabilitySyncPreviewSilently();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e) {
      debugPrint('Error resolving asset liability sync conflict: $e');
      if (!mounted) return;
      setState(() {
        _assetLiabilitySyncStatus = AssetLiabilityManualSyncStatus.failure;
        _lastAssetLiabilitySyncAt = DateTime.now();
        _assetLiabilitySyncMessage = '競合解決に失敗しました: $e';
      });
      await _refreshAssetLiabilitySyncAuditLogs();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('競合解決に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingAssetLiabilityConflict = false;
        });
      }
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
      await _assetLiabilityRepository.saveMonthlySnapshot(snapshot);
      final snapshots = await _assetLiabilityRepository.loadMonthlySnapshots();
      if (!mounted) return;
      setState(() {
        _monthlySnapshots = List<AssetLiabilityMonthlySnapshot>.from(snapshots);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$monthKey のスナップショットを保存しました')));
    } catch (e) {
      debugPrint('Error saving asset liability monthly snapshot: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('スナップショット保存に失敗しました: $e')));
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
      bundle.cardStatementCsv,
      'asset_liability_card_statement_${monthKey}_$stamp.csv',
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
      const SnackBar(
        content: Text('Asset liability CSV bundle exported (5 files)'),
      ),
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
        actualPaymentAmounts: Map<String, double>.from(_actualPaymentAmounts),
        paymentDifferenceReasons: Map<String, String>.from(
          _paymentDifferenceReasons,
        ),
        annualRateOverrides: Map<String, double>.from(_annualRateOverrides),
        annualRateEvidences: Map<String, AssetLiabilityAnnualRateEvidence>.from(
          _annualRateEvidences,
        ),
        paidAccountNames: Set<String>.from(_monthlyPaidAccountNames),
        paymentSourceAccountIds: Map<String, String>.from(
          _paymentSourceAccountIds,
        ),
        cardBillingAccountIds: Map<String, String>.from(_cardBillingAccountIds),
        cardStatementLines: List<AssetLiabilityCardStatementLine>.from(
          _cardStatementLines,
        ),
        incomePlans: List<AssetLiabilityIncomePlan>.from(_monthlyIncomePlans),
        transferTasks: List<AssetLiabilityTransferTask>.from(_transferTasks),
      ),
      legacyKeyToAccountId: legacyKeyToAccountId,
    );
    final migratedDefaultSources = _migrateStringMapKeysAndValues(
      _defaultPaymentSourceAccountIds,
      legacyKeyToAccountId,
    );
    final migratedDefaultCardBillingAccounts = _migrateStringMapKeysAndValues(
      _defaultCardBillingAccountIds,
      legacyKeyToAccountId,
    );
    if (_sameDoubleMap(_monthlyPaymentOverrides, migrated.paymentOverrides) &&
        _sameDoubleMap(_actualPaymentAmounts, migrated.actualPaymentAmounts) &&
        _sameStringMap(
          _paymentDifferenceReasons,
          migrated.paymentDifferenceReasons,
        ) &&
        _sameDoubleMap(_annualRateOverrides, migrated.annualRateOverrides) &&
        _sameAnnualRateEvidences(
          _annualRateEvidences,
          migrated.annualRateEvidences,
        ) &&
        _sameStringSet(_monthlyPaidAccountNames, migrated.paidAccountNames) &&
        _sameStringMap(
          _paymentSourceAccountIds,
          migrated.paymentSourceAccountIds,
        ) &&
        _sameStringMap(
          _cardBillingAccountIds,
          migrated.cardBillingAccountIds,
        ) &&
        _sameStringMap(
          _defaultPaymentSourceAccountIds,
          migratedDefaultSources,
        ) &&
        _sameStringMap(
          _defaultCardBillingAccountIds,
          migratedDefaultCardBillingAccounts,
        ) &&
        _sameCardStatementLines(
          _cardStatementLines,
          migrated.cardStatementLines,
        ) &&
        _sameTransferTasks(_transferTasks, migrated.transferTasks)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _monthlyPaymentOverrides = Map<String, double>.from(
          migrated.paymentOverrides,
        );
        _actualPaymentAmounts = Map<String, double>.from(
          migrated.actualPaymentAmounts,
        );
        _paymentDifferenceReasons = Map<String, String>.from(
          migrated.paymentDifferenceReasons,
        );
        _annualRateOverrides = Map<String, double>.from(
          migrated.annualRateOverrides,
        );
        _annualRateEvidences =
            Map<String, AssetLiabilityAnnualRateEvidence>.from(
          migrated.annualRateEvidences,
        );
        _monthlyPaidAccountNames = Set<String>.from(migrated.paidAccountNames);
        _paymentSourceAccountIds = Map<String, String>.from(
          migrated.paymentSourceAccountIds,
        );
        _cardBillingAccountIds = Map<String, String>.from(
          migrated.cardBillingAccountIds,
        );
        _cardStatementLines = List<AssetLiabilityCardStatementLine>.from(
          migrated.cardStatementLines,
        );
        _transferTasks = List<AssetLiabilityTransferTask>.from(
          migrated.transferTasks,
        );
        _defaultPaymentSourceAccountIds = Map<String, String>.from(
          migratedDefaultSources,
        );
        _defaultCardBillingAccountIds = Map<String, String>.from(
          migratedDefaultCardBillingAccounts,
        );
        _syncPaymentStateControllers();
      });
      unawaited(_saveAssetLiabilityMonthlyState());
      unawaited(_saveDefaultPaymentSources());
      unawaited(_saveDefaultCardBillingAccounts());
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

  bool _sameAnnualRateEvidences(
    Map<String, AssetLiabilityAnnualRateEvidence> a,
    Map<String, AssetLiabilityAnnualRateEvidence> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      final other = b[entry.key];
      final current = entry.value;
      if (other == null ||
          other.accountId != current.accountId ||
          other.fileName != current.fileName ||
          other.mimeType != current.mimeType ||
          other.submittedAt.toIso8601String() !=
              current.submittedAt.toIso8601String() ||
          other.submittedAnnualRate != current.submittedAnnualRate ||
          other.detectedAnnualRate != current.detectedAnnualRate ||
          other.status != current.status ||
          other.summary != current.summary ||
          other.source != current.source ||
          other.errorMessage != current.errorMessage) {
        return false;
      }
    }
    return true;
  }

  bool _sameCardStatementLines(
    List<AssetLiabilityCardStatementLine> a,
    List<AssetLiabilityCardStatementLine> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.billingAccountId != right.billingAccountId ||
          left.billingAccountName != right.billingAccountName ||
          left.postedAt?.toIso8601String() !=
              right.postedAt?.toIso8601String() ||
          left.description != right.description ||
          left.amount != right.amount) {
        return false;
      }
    }
    return true;
  }

  bool _sameTransferTasks(
    List<AssetLiabilityTransferTask> a,
    List<AssetLiabilityTransferTask> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.fromAccountId != right.fromAccountId ||
          left.fromAccountName != right.fromAccountName ||
          left.toAccountId != right.toAccountId ||
          left.toAccountName != right.toAccountName ||
          left.amount != right.amount ||
          left.dueDate?.toIso8601String() != right.dueDate?.toIso8601String() ||
          left.completed != right.completed ||
          left.completedAt?.toIso8601String() !=
              right.completedAt?.toIso8601String()) {
        return false;
      }
    }
    return true;
  }

  void _syncPaymentStateControllers() {
    _syncMonthlyPaymentControllers();
    _syncActualPaymentControllers();
    _syncPaymentDifferenceReasonControllers();
    _syncAnnualRateControllers();
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

  void _syncActualPaymentControllers() {
    for (final entry in _actualPaymentControllers.entries) {
      final hasAmount = _actualPaymentAmounts.containsKey(entry.key);
      final amount = _actualPaymentAmounts[entry.key];
      final text = hasAmount && amount != null ? amount.round().toString() : '';
      if (entry.value.text != text) {
        entry.value.text = text;
      }
    }
  }

  void _syncPaymentDifferenceReasonControllers() {
    for (final entry in _paymentDifferenceReasonControllers.entries) {
      final text = _paymentDifferenceReasons[entry.key] ?? '';
      if (entry.value.text != text) {
        entry.value.text = text;
      }
    }
  }

  void _syncAnnualRateControllers() {
    for (final entry in _annualRateControllers.entries) {
      final hasOverride = _annualRateOverrides.containsKey(entry.key);
      final rate = _annualRateOverrides[entry.key];
      final text = hasOverride && rate != null ? _formatRateInput(rate) : '';
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

  TextEditingController _actualPaymentControllerFor(AssetLiabilityDebtRow row) {
    return _actualPaymentControllers.putIfAbsent(
      row.id,
      () => TextEditingController(
        text: row.actualPaymentAmount == null
            ? ''
            : row.actualPaymentAmount!.round().toString(),
      ),
    );
  }

  TextEditingController _paymentDifferenceReasonControllerFor(
    AssetLiabilityDebtRow row,
  ) {
    return _paymentDifferenceReasonControllers.putIfAbsent(
      row.id,
      () => TextEditingController(text: row.paymentDifferenceReason ?? ''),
    );
  }

  TextEditingController _annualRateControllerFor(AssetLiabilityDebtRow row) {
    return _annualRateControllers.putIfAbsent(
      row.id,
      () => TextEditingController(
        text: _annualRateOverrides.containsKey(row.id)
            ? _formatRateInput(_annualRateOverrides[row.id]!)
            : '',
      ),
    );
  }

  String _formatRateInput(double rate) {
    final percent = rate * 100;
    if (percent == percent.roundToDouble()) {
      return percent.round().toString();
    }
    return percent.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
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

  void _updateActualPaymentAmount(String accountId, String rawValue) {
    final normalized = rawValue.replaceAll(',', '').trim();
    final amount = normalized.isEmpty ? null : double.tryParse(normalized);
    setState(() {
      if (amount == null || amount < 0) {
        _actualPaymentAmounts.remove(accountId);
      } else {
        _actualPaymentAmounts[accountId] = amount;
      }
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  void _updatePaymentDifferenceReason(String accountId, String rawValue) {
    final reason = rawValue.trim();
    setState(() {
      if (reason.isEmpty) {
        _paymentDifferenceReasons.remove(accountId);
      } else {
        _paymentDifferenceReasons[accountId] = reason;
      }
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  void _updateAnnualRateOverride(String accountId, String rawValue) {
    final parsed = _parseAnnualRateInput(rawValue);
    setState(() {
      if (parsed == null) {
        _annualRateOverrides.remove(accountId);
        _annualRateEvidences.remove(accountId);
      } else {
        final currentEvidence = _annualRateEvidences[accountId];
        if (currentEvidence == null ||
            !currentEvidence.matchesAnnualRate(parsed)) {
          _annualRateOverrides.remove(accountId);
        }
      }
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  double? _parseAnnualRateInput(String rawValue) {
    final normalized = rawValue.replaceAll('%', '').replaceAll(',', '').trim();
    final parsed = normalized.isEmpty ? null : double.tryParse(normalized);
    if (parsed == null || parsed < 0) {
      return null;
    }
    return parsed > 1 ? parsed / 100 : parsed;
  }

  void _clearAnnualRateOverride(String accountId) {
    _annualRateControllers[accountId]?.clear();
    setState(() {
      _annualRateOverrides.remove(accountId);
      _annualRateEvidences.remove(accountId);
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  Future<void> _submitAnnualRateEvidence(AssetLiabilityDebtRow row) async {
    final controller = _annualRateControllerFor(row);
    final rate = _parseAnnualRateInput(controller.text);
    if (rate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('年利を入力してから証跡画像を提出してください')));
      return;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) {
      return;
    }
    final mimeType = _mimeTypeForAnnualRateEvidence(file);
    await _verifyAnnualRateEvidenceBytes(
      row: row,
      rate: rate,
      bytes: bytes,
      mimeType: mimeType,
      fileName: file.name,
    );
  }

  void _startAnnualRateEvidencePaste(AssetLiabilityDebtRow row) {
    final rate = _parseAnnualRateInput(_annualRateControllerFor(row).text);
    if (rate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('年利を入力してから証跡画像を貼り付けてください')));
      return;
    }
    setState(() => _annualRateEvidencePasteTargetRow = row);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${row.name}の年利証跡を貼り付け待ちです。画面キャプチャをコピーして Ctrl+V してください。'),
      ),
    );
  }

  Future<void> _handleAnnualRateEvidencePasted(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    final row = _annualRateEvidencePasteTargetRow;
    if (row == null) {
      return;
    }
    final rate = _parseAnnualRateInput(_annualRateControllerFor(row).text);
    if (rate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('年利を入力してから証跡画像を貼り付けてください')));
      return;
    }
    if (bytes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('貼り付けた画像を読み取れませんでした')));
      return;
    }
    final normalizedFileName = fileName.trim().isEmpty
        ? 'annual-rate-evidence-paste.png'
        : fileName.trim();
    await _verifyAnnualRateEvidenceBytes(
      row: row,
      rate: rate,
      bytes: bytes,
      mimeType: mimeType.trim().isEmpty ? 'image/png' : mimeType.trim(),
      fileName: normalizedFileName,
    );
  }

  Future<void> _verifyAnnualRateEvidenceBytes({
    required AssetLiabilityDebtRow row,
    required double rate,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
  }) async {
    setState(() {
      _verifyingAnnualRateEvidenceAccountIds.add(row.id);
    });
    final evidence = await _annualRateEvidenceService.verifyEvidenceBytes(
      accountId: row.id,
      accountName: row.name,
      annualRate: rate,
      imageBytes: bytes,
      mimeType: mimeType,
      fileName: fileName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _verifyingAnnualRateEvidenceAccountIds.remove(row.id);
      if (_annualRateEvidencePasteTargetRow?.id == row.id) {
        _annualRateEvidencePasteTargetRow = null;
      }
      _annualRateEvidences[row.id] = evidence;
      if (evidence.matchesAnnualRate(rate)) {
        _annualRateOverrides[row.id] = rate;
      } else {
        _annualRateOverrides.remove(row.id);
      }
    });
    unawaited(_saveAssetLiabilityMonthlyState());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          evidence.verified
              ? 'AIが年利証跡を確認しました'
              : 'AIが年利証跡を確認できませんでした。画面キャプチャを確認してください',
        ),
      ),
    );
  }

  String _mimeTypeForAnnualRateEvidence(PlatformFile file) {
    final extension = (file.extension ?? '').toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'image/jpeg',
    };
  }

  Future<void> _toggleMonthlyPaymentPaid(
    AssetLiabilityDebtRow row,
    bool paid,
  ) async {
    final previousPaidAccountNames = Set<String>.from(_monthlyPaidAccountNames);
    final previousActualPaymentAmounts = Map<String, double>.from(
      _actualPaymentAmounts,
    );
    setState(() {
      if (paid) {
        _monthlyPaidAccountNames.add(row.id);
        _actualPaymentAmounts.putIfAbsent(
          row.id,
          () => row.scheduledPaymentAmount,
        );
        _actualPaymentControllers[row.id]?.text =
            _actualPaymentAmounts[row.id]!.round().toString();
      } else {
        _monthlyPaidAccountNames.remove(row.id);
      }
    });
    try {
      await _persistAssetLiabilityMonthlyState();
    } catch (e) {
      debugPrint('Error saving paid status: $e');
      if (!mounted) return;
      setState(() {
        _monthlyPaidAccountNames = previousPaidAccountNames;
        _actualPaymentAmounts = previousActualPaymentAmounts;
        _syncActualPaymentControllers();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('支払済み状態を保存できませんでした。')));
    }
  }

  void _updatePaymentSourceAccount(
    String liabilityId,
    String? sourceAccountId,
  ) {
    setState(() {
      if (sourceAccountId == null || sourceAccountId.isEmpty) {
        _paymentSourceAccountIds.remove(liabilityId);
      } else {
        _paymentSourceAccountIds[liabilityId] = sourceAccountId;
      }
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  void _updateCardBillingAccount(
    AssetLiabilityDebtRow row,
    String? billingAccountId,
  ) {
    final selected =
        billingAccountId ?? AssetLiabilityPlanningService.directPaymentMethodId;
    final scope = _cardBillingSaveScopeFor(row);
    setState(() {
      if (scope == _CardBillingSaveScope.defaultSetting) {
        _applyCardBillingSelection(
          target: _defaultCardBillingAccountIds,
          row: row,
          selected: selected,
        );
        _cardBillingAccountIds.remove(row.id);
      } else {
        _applyCardBillingSelection(
          target: _cardBillingAccountIds,
          row: row,
          selected: selected,
        );
      }
    });
    if (scope == _CardBillingSaveScope.defaultSetting) {
      unawaited(_saveDefaultCardBillingAccounts());
      unawaited(_saveAssetLiabilityMonthlyState());
    } else {
      unawaited(_saveAssetLiabilityMonthlyState());
    }
  }

  void _applyCardBillingSelection({
    required Map<String, String> target,
    required AssetLiabilityDebtRow row,
    required String selected,
  }) {
    if (selected == AssetLiabilityPlanningService.directPaymentMethodId) {
      if (row.includedInBillingAccount || target.containsKey(row.id)) {
        target[row.id] = AssetLiabilityPlanningService.directPaymentMethodId;
      } else {
        target.remove(row.id);
      }
    } else {
      target[row.id] = selected;
    }
  }

  _CardBillingSaveScope _cardBillingSaveScopeFor(AssetLiabilityDebtRow row) {
    return _cardBillingSaveScopes[row.id] ??
        (_cardBillingAccountIds.containsKey(row.id)
            ? _CardBillingSaveScope.monthlyOverride
            : _CardBillingSaveScope.defaultSetting);
  }

  void _updateCardBillingSaveScope(
    String liabilityId,
    _CardBillingSaveScope scope,
  ) {
    setState(() {
      _cardBillingSaveScopes[liabilityId] = scope;
    });
  }

  void _importCardStatementLines(
    AssetLiabilityWorkbook workbook,
    String? selectedBillingAccountId,
  ) {
    final billingAccountId = selectedBillingAccountId?.trim();
    if (billingAccountId == null || billingAccountId.isEmpty) {
      setState(() {
        _cardStatementImportMessage = 'Select a billing card before import.';
      });
      return;
    }
    var billingAccountName = billingAccountId;
    for (final account in workbook.accounts) {
      if (account.id == billingAccountId) {
        billingAccountName = account.name;
        break;
      }
    }
    final result = _cardStatementImportService.parse(
      rawText: _cardStatementImportController.text,
      defaultBillingAccountId: billingAccountId,
      defaultBillingAccountName: billingAccountName,
    );
    if (!result.hasAcceptedRows) {
      setState(() {
        _cardStatementImportMessage = result.hasRejectedRows
            ? 'No rows imported. First error: ${result.rejectedRows.first.reason}'
            : 'No rows imported.';
      });
      return;
    }

    final merged = <String, AssetLiabilityCardStatementLine>{
      for (final line in _cardStatementLines) line.id: line,
      for (final line in result.lines) line.id: line,
    };
    setState(() {
      _selectedCardStatementBillingAccountId = billingAccountId;
      _cardStatementLines = merged.values.toList(growable: false);
      _cardStatementImportController.clear();
      _cardStatementImportMessage = 'Imported ${result.lines.length} rows'
          '${result.rejectedRows.isEmpty ? '' : ', rejected ${result.rejectedRows.length}'}.';
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  void _clearCardStatementLines(String billingAccountId) {
    setState(() {
      _cardStatementLines = _cardStatementLines
          .where((line) => line.billingAccountId != billingAccountId)
          .toList(growable: false);
      _cardStatementImportMessage = 'Cleared imported lines for this card.';
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  Future<void> _saveDefaultPaymentSources() async {
    try {
      await _assetLiabilityRepository.saveDefaultPaymentSources(
        Map<String, String>.from(_defaultPaymentSourceAccountIds),
      );
    } catch (e) {
      debugPrint('Error saving asset liability default sources: $e');
    }
  }

  Future<void> _saveDefaultCardBillingAccounts() async {
    try {
      await _assetLiabilityRepository.saveDefaultCardBillingAccounts(
        Map<String, String>.from(_defaultCardBillingAccountIds),
      );
    } catch (e) {
      debugPrint('Error saving asset liability default card billing: $e');
    }
  }

  Future<void> _saveRecurringIncomeTemplates() async {
    try {
      await _assetLiabilityRepository.saveRecurringIncomeTemplates(
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
    final targetMonth = _assetLiabilityStateMonth(_now);
    final copied = await _assetLiabilityRepository.copyPreviousMonthToMonth(
      targetMonth,
    );
    final incomePlansWithTemplates =
        AssetLiabilityMonthlyStateStore.applyRecurringIncomeTemplates(
      month: targetMonth,
      templates: _recurringIncomeTemplates,
      existingPlans: copied.incomePlans,
    );

    if (!mounted) return;
    setState(() {
      _monthlyPaymentOverrides = Map<String, double>.from(
        copied.paymentOverrides,
      );
      _actualPaymentAmounts = <String, double>{};
      _paymentDifferenceReasons = <String, String>{};
      _monthlyPaidAccountNames = <String>{};
      _paymentSourceAccountIds = Map<String, String>.from(
        copied.paymentSourceAccountIds,
      );
      _cardBillingAccountIds = Map<String, String>.from(
        copied.cardBillingAccountIds,
      );
      _cardStatementLines = <AssetLiabilityCardStatementLine>[];
      _monthlyIncomePlans = incomePlansWithTemplates;
      _transferTasks = <AssetLiabilityTransferTask>[];
      _syncPaymentStateControllers();
    });
    unawaited(_saveAssetLiabilityMonthlyState());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('前サイクル設定をコピーしました。支払済み・入金済み状態はコピーしていません。')),
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

  int _compareTransferTasksByDueDate(
    AssetLiabilityTransferTask a,
    AssetLiabilityTransferTask b,
  ) {
    final aDue = a.dueDate;
    final bDue = b.dueDate;
    if (aDue != null && bDue != null) {
      final date = aDue.compareTo(bDue);
      if (date != 0) {
        return date;
      }
    } else if (aDue != null) {
      return -1;
    } else if (bDue != null) {
      return 1;
    }
    return a.id.compareTo(b.id);
  }

  void _createTransferTaskFromSuggestion(
    AssetLiabilityTransferSuggestion suggestion,
  ) {
    final dueDate = suggestion.neededBy == null
        ? null
        : DateTime(
            suggestion.neededBy!.year,
            suggestion.neededBy!.month,
            suggestion.neededBy!.day,
          );
    final duplicate = _transferTasks.any(
      (task) =>
          !task.completed &&
          task.fromAccountId == suggestion.fromAccountId &&
          task.toAccountId == suggestion.toAccountId &&
          task.amount == suggestion.amount &&
          task.dueDate?.toIso8601String() == dueDate?.toIso8601String(),
    );
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer task already exists.')),
      );
      return;
    }

    final now = DateTime.now();
    final nextTasks = List<AssetLiabilityTransferTask>.from(_transferTasks)
      ..add(
        AssetLiabilityTransferTask(
          id: 'transfer_${now.microsecondsSinceEpoch}',
          fromAccountId: suggestion.fromAccountId,
          fromAccountName: suggestion.fromAccountName,
          toAccountId: suggestion.toAccountId,
          toAccountName: suggestion.toAccountName,
          amount: suggestion.amount,
          dueDate: dueDate,
        ),
      )
      ..sort(_compareTransferTasksByDueDate);
    setState(() {
      _transferTasks = nextTasks;
    });
    unawaited(_saveAssetLiabilityMonthlyState());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transfer task created.')));
  }

  void _toggleTransferTaskCompleted(
    AssetLiabilityTransferTask task,
    bool completed,
  ) {
    setState(() {
      var found = false;
      final completedAt = completed ? DateTime.now() : null;
      _transferTasks = [
        for (final current in _transferTasks)
          if (current.id == task.id)
            () {
              found = true;
              return AssetLiabilityTransferTask(
                id: current.id,
                fromAccountId: current.fromAccountId,
                fromAccountName: current.fromAccountName,
                toAccountId: current.toAccountId,
                toAccountName: current.toAccountName,
                amount: current.amount,
                dueDate: current.dueDate,
                completed: completed,
                completedAt: completedAt,
              );
            }()
          else
            current,
        if (!found)
          AssetLiabilityTransferTask(
            id: task.id,
            fromAccountId: task.fromAccountId,
            fromAccountName: task.fromAccountName,
            toAccountId: task.toAccountId,
            toAccountName: task.toAccountName,
            amount: task.amount,
            dueDate: task.dueDate,
            completed: completed,
            completedAt: completedAt,
          ),
      ]..sort(_compareTransferTasksByDueDate);
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  void _deleteTransferTask(String taskId) {
    setState(() {
      _transferTasks = _transferTasks
          .where((task) => task.id != taskId)
          .toList(growable: false);
    });
    unawaited(_saveAssetLiabilityMonthlyState());
  }

  bool _isBuiltInTransferTask(AssetLiabilityTransferTask task) =>
      task.id == AssetLiabilityPlanningService.auPayCardFundingTransferTaskId;

  void _deleteRecurringIncomeTemplate(String templateId) {
    final currentMonthKey = _assetLiabilityStateMonthKey(_now);
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
                      subtitle: Text(
                        DateFormat('yyyy/MM/dd').format(selectedDate),
                      ),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                    final stateMonth = _assetLiabilityStateMonth(_now);
                    final generatedId = _generatedPlanIdForTemplate(
                      template,
                      stateMonth,
                    );
                    final previousGeneratedPlan = _monthlyIncomePlans.where((
                      plan,
                    ) {
                      return plan.id == generatedId;
                    }).toList();
                    final generatedPlan = _incomePlanForTemplate(
                      template,
                      stateMonth,
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

  List<AssetLiabilityAccount> _cardBillingAccountOptions(
    AssetLiabilityWorkbook workbook,
  ) {
    return workbook.accounts
        .where(
          (account) => account.kind == AssetLiabilityAccountKind.creditCard,
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<Map<String, dynamic>> _liabilitiesFromSnapshot(
    Map<String, double> snapshot,
  ) {
    final liabilities = snapshot.entries
        .where((e) => e.value < 0)
        .map((e) => <String, dynamic>{'name': e.key, 'balance': e.value.abs()})
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
        content: Text(enabled ? '完済までの収監モードを開始しました' : '完済までの収監モードを中断しました'),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('違反を記録しました')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('違反内容を入力してください')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('返済予算と目標期間を正しく入力してください')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('返済対象の負債データを作成できませんでした')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('返済計画の作成に失敗しました: $e')));
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
    final deadline = DateTime.tryParse(
      task['deadline']?.toString() ?? '',
    )?.toLocal();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('追加する Code タスクを選択してください')));
      return;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ログイン後に Code タスクを追加できます')));
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
        SnackBar(content: Text('Code タスクを ${rows.length} 件追加しました$suffix')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Code タスクの追加に失敗しました: $e')));
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
      await _supabase.from('cfo_daily_closings').upsert({
        'user_id': userId,
        'date': todayStr,
        'assets_done': _assetsDone,
        'liabilities_done': _liabilitiesDone,
        'fixed_costs_done': _fixedCostsDone,
        'flows_done': _flowsDone,
        'must_tasks_done': _mustTasksDone,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,date');
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('サマリーをコピーしました（投稿用）')));
  }

  // ==========================================
  // 1 & 2. 資産・負債の記録（ストック）
  // ==========================================

  Uri _bankSheetCsvUri(String gid) {
    return Uri.https(
      'docs.google.com',
      '/spreadsheets/d/$_bankSheetId/export',
      <String, String>{'format': 'csv', 'gid': gid},
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('データ取得に失敗しました: $e')));
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
        throw Exception('じぶん銀行の残高行が見つかりませんでした。GoogleシートのGIDまたは日付/残高列を確認してください');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('データ取得に失敗しました: $e')));
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
      final groupCompare = a.group.toLowerCase().compareTo(
            b.group.toLowerCase(),
          );
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
                  final entries = await widget.watchlistService.removeEntry(
                    type,
                  );
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

    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
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
    final previousDate = _lastUpdatedDates[type];
    final previousAmount =
        previousDate == null ? null : _assetData[previousDate]?[type];
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

      final autoRecorded = previousAmount == null
          ? false
          : await _autoRecordUnknownExpenseFromAssetDrop(
              assetType: type,
              dateKey: today,
              previousAmount: previousAmount,
              currentAmount: amount,
            );
      if (autoRecorded) {
        await _fetchRecentFlows();
      }

      if (clearController) {
        _controllers[type]?.clear();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            autoRecorded
                ? '✅ $type を記録し、減少分を使途不明金として自動追加しました'
                : successMessage ?? '✅ $type を記録しました',
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$type は昨日の記録がある場合のみ簡易更新できます')));
      return;
    }

    final lastAmount = _assetData[lastDate]?[type];
    if (lastAmount == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$type の前回残高が見つかりません')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$type の金額を入力してください')));
      return;
    }

    final cleanText = controller.text.replaceAll(',', '');
    final parsedAmount = double.tryParse(cleanText);
    if (parsedAmount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$type の金額形式が不正です')));
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
      final previousAmounts = <String, double?>{
        for (final entry in todayData.entries)
          entry.key: _lastUpdatedDates[entry.key] == null
              ? null
              : _assetData[_lastUpdatedDates[entry.key]]?[entry.key],
      };
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
      var autoRecordedCount = 0;
      for (final entry in todayData.entries) {
        final previousAmount = previousAmounts[entry.key];
        if (previousAmount == null) {
          continue;
        }
        final autoRecorded = await _autoRecordUnknownExpenseFromAssetDrop(
          assetType: entry.key,
          dateKey: today,
          previousAmount: previousAmount,
          currentAmount: entry.value,
        );
        if (autoRecorded) {
          autoRecordedCount += 1;
        }
      }
      if (autoRecordedCount > 0) {
        await _fetchRecentFlows();
      }
      _controllers.forEach((_, controller) => controller.clear());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              autoRecordedCount > 0
                  ? '資産・負債を一括記録し、減少分を使途不明金として$autoRecordedCount件自動追加しました。'
                  : '資産・負債を一括記録しました。',
            ),
          ),
        );
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
              backgroundColor: const Color(0xFFB91C1C),
            ),
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
                    decoration: const InputDecoration(
                      labelText: '名称 (例: モビット, 家賃)',
                    ),
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
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                        _selectedSubscriptionHistoryMonth = _monthStart(
                          dueDate,
                        );
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
              backgroundColor: const Color(0xFFB91C1C),
            ),
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

  Future<void> _loadPayslipFinanceData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _payslipRows = <Map<String, dynamic>>[];
        _payslipSalaryIncomes = <Map<String, dynamic>>[];
        _isLoadingPayslipFinance = false;
      });
      return;
    }
    if (mounted) {
      setState(() => _isLoadingPayslipFinance = true);
    }
    try {
      final payslips = await _supabase
          .from('payslips')
          .select(
            'id,pay_date,company_name,gross_amount,net_amount,confidence,review_status,source_pdf_path',
          )
          .eq('user_id', userId)
          .order('pay_date', ascending: false)
          .limit(12);
      final salaryIncomes = await _supabase
          .from('salary_incomes')
          .select('id,pay_date,amount,description,source,confidence')
          .eq('user_id', userId)
          .order('pay_date', ascending: false)
          .limit(12);
      if (!mounted) return;
      setState(() {
        _payslipRows = List<Map<String, dynamic>>.from(payslips);
        _payslipSalaryIncomes = List<Map<String, dynamic>>.from(salaryIncomes);
        _isLoadingPayslipFinance = false;
        _payslipIngestionMessage = null;
      });
    } catch (e) {
      debugPrint('Error loading payslip finance data: $e');
      if (!mounted) return;
      setState(() {
        _payslipRows = <Map<String, dynamic>>[];
        _payslipSalaryIncomes = <Map<String, dynamic>>[];
        _isLoadingPayslipFinance = false;
        _payslipIngestionMessage =
            '給与明細テーブルの準備がまだです。最新マイグレーション適用後に再読み込みしてください。';
      });
    }
  }

  Future<void> _pickAndUploadPayslipPdf() async {
    if (_isUploadingPayslip) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('給与明細PDFをアップロードする前にログインしてください。')),
      );
      return;
    }

    setState(() {
      _isUploadingPayslip = true;
      _payslipIngestionMessage = 'PDFの選択を待っています...';
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['pdf'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) {
          setState(() {
            _isUploadingPayslip = false;
            _payslipIngestionMessage = null;
          });
        }
        return;
      }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('PDFの中身が空でした。');
      }
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = _safePayslipStorageFileName(file.name);
      final storagePath = '$userId/$timestamp-$fileName';

      await _supabase.storage.from('payslips').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: <String, dynamic>{
          'action': 'payslip.parse',
          'storage_path': storagePath,
          'enable_ai_fallback': true,
          'trace_id': 'asset-payslip-upload',
        },
      );
      final data = response.data;
      final parsed = data is Map ? Map<String, dynamic>.from(data) : null;
      final status = parsed?['status']?.toString() ?? 'parsed';
      if (!mounted) return;
      setState(() {
        _payslipIngestionMessage = status == 'needs_review'
            ? '給与明細を取り込みました。信頼度が低いため確認してください。'
            : '給与明細を取り込み、給料収入へ反映しました。';
      });
      await _loadPayslipFinanceData();
      unawaited(_computeDisposableBalanceFromServer(enableAiActions: false));
    } catch (e) {
      debugPrint('Error uploading payslip PDF: $e');
      if (!mounted) return;
      setState(() {
        _payslipIngestionMessage = '給与明細のアップロードに失敗しました: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('給与明細のアップロードに失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _isUploadingPayslip = false);
      }
    }
  }

  Future<void> _computeDisposableBalanceFromServer({
    bool enableAiActions = true,
  }) async {
    if (_isComputingDisposableBalance) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() {
      _isComputingDisposableBalance = true;
      _disposableBalanceMessage = '可処分残高を計算しています...';
    });
    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: <String, dynamic>{
          'action': 'asset.disposable_balance.compute',
          'as_of_date': _dateOnly(_now),
          'salary_day': _salarySpendingSalaryDay,
          'enable_ai_actions': enableAiActions,
          'trace_id': 'asset-disposable-balance',
        },
      );
      final data = response.data;
      if (!mounted) return;
      setState(() {
        _serverDisposableBalanceResult =
            data is Map ? Map<String, dynamic>.from(data) : null;
        _disposableBalanceMessage = '可処分残高を更新しました。';
      });
    } catch (e) {
      debugPrint('Error computing disposable balance: $e');
      if (!mounted) return;
      setState(() {
        _disposableBalanceMessage = 'サーバー計算を利用できないため、端末側の概算を表示しています。';
      });
    } finally {
      if (mounted) {
        setState(() => _isComputingDisposableBalance = false);
      }
    }
  }

  String _safePayslipStorageFileName(String value) {
    const fallback = 'payslip.pdf';
    final trimmed = value.trim().isEmpty ? fallback : value.trim();
    final sanitized = trimmed
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    if (sanitized.toLowerCase().endsWith('.pdf')) {
      return sanitized;
    }
    return '$sanitized.pdf';
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
        final key = _extractSmbcImportKey(
          flow['description']?.toString() ?? '',
        );
        if (key != null) {
          knownImportKeys.add(key);
        }
      }
      final records = <Map<String, dynamic>>[];
      final classificationExpenses = <Map<String, dynamic>>[];
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
        if (!transaction.isDeposit) {
          classificationExpenses.add({
            'source': 'smbc_csv',
            'id': transaction.importKey,
            'posted_at': _dateOnly(transaction.date),
            'description': transaction.displayMemo,
            'amount': transaction.amount.abs(),
          });
        }
      }

      for (var i = 0; i < records.length; i += 200) {
        final chunk = records.sublist(i, min(i + 200, records.length));
        await _supabase.from('wealth_struggles').insert(chunk);
      }
      if (classificationExpenses.isNotEmpty) {
        unawaited(_classifyImportedExpenses(classificationExpenses));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('三井住友CSVの取込に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _isImportingSmbcCsv = false);
      }
    }
  }

  Future<void> _classifyImportedExpenses(
    List<Map<String, dynamic>> expenses,
  ) async {
    try {
      await _supabase.functions.invoke(
        'ai-hub',
        body: <String, dynamic>{
          'action': 'expense.classify',
          'source': 'smbc_csv',
          'expenses': expenses,
          'trace_id': 'asset-smbc-csv-classify',
        },
      );
    } catch (e) {
      debugPrint('Expense classification failed: $e');
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

  String _flowSourceForAssetType(String assetType) {
    final normalized = assetType.trim().isEmpty ? '口座' : assetType.trim();
    return '[$normalized]';
  }

  bool _isAutoAssetDeltaFlow(Map<String, dynamic> flow) {
    return _extractAutoAssetDeltaKey(flow['description']?.toString() ?? '') !=
        null;
  }

  String _autoAssetDeltaKey({
    required String dateKey,
    required String assetType,
    required double previousAmount,
    required double currentAmount,
  }) {
    final encodedAsset = base64Url.encode(utf8.encode(assetType.trim()));
    return [
      dateKey,
      encodedAsset,
      previousAmount.round().toString(),
      currentAmount.round().toString(),
    ].join(':');
  }

  bool _shouldAutoRecordUnknownExpenseFromAssetDrop({
    required String assetType,
    required double previousAmount,
    required double currentAmount,
  }) {
    final drop = previousAmount - currentAmount;
    if (previousAmount <= 0 || drop < 1) {
      return false;
    }
    final key = assetType.toLowerCase();
    final looksLikeInvestment = key.contains('証券') ||
        key.contains('株') ||
        key.contains('投資') ||
        key.contains('nisa') ||
        key.contains('securities') ||
        key.contains('stock') ||
        key.contains('crypto') ||
        key.contains('coincheck') ||
        key.contains('bitflyer');
    if (looksLikeInvestment) {
      return false;
    }
    return true;
  }

  Future<bool> _autoRecordUnknownExpenseFromAssetDrop({
    required String assetType,
    required String dateKey,
    required double previousAmount,
    required double currentAmount,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null ||
        !_shouldAutoRecordUnknownExpenseFromAssetDrop(
          assetType: assetType,
          previousAmount: previousAmount,
          currentAmount: currentAmount,
        )) {
      return false;
    }

    final markerKey = _autoAssetDeltaKey(
      dateKey: dateKey,
      assetType: assetType,
      previousAmount: previousAmount,
      currentAmount: currentAmount,
    );
    final alreadyExists = _recentFlows.any(
      (flow) =>
          _extractAutoAssetDeltaKey(flow['description']?.toString() ?? '') ==
          markerKey,
    );
    if (alreadyExists) {
      return false;
    }

    final amount = previousAmount - currentAmount;
    final source = _flowSourceForAssetType(assetType);
    final occurredAt = DateTime.tryParse(dateKey) ?? DateTime.now();
    await _supabase.from('wealth_struggles').insert({
      'user_id': userId,
      'action_type': 'expense',
      'amount': amount.round(),
      'description': _withFlowAutoAssetDeltaMarker(
        _composeFlowDescription(
          flowType: '支出',
          source: source,
          memo: '使途不明金（残高差分から自動記録）',
          wasteCategory: null,
        ),
        markerKey,
      ),
      'occurred_at': occurredAt.toUtc().toIso8601String(),
    });

    if (mounted && !_sourceOptions.contains(source)) {
      setState(() {
        _sourceOptions = [..._sourceOptions, source];
      });
    }
    return true;
  }

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
  }) _parseFlowDescription(String description, {String? actionType}) {
    final normalizedDescription = _stripFlowMetadataMarkers(
      description.trim(),
    );
    final isExpense = _isExpenseActionType(actionType ?? '');
    final wasteCategory = isExpense
        ? WasteTrackingService.extractWasteCategory(normalizedDescription)
        : null;
    final normalized = isExpense
        ? WasteTrackingService.stripWasteMarker(normalizedDescription)
        : normalizedDescription;
    if (_isTransferActionType(actionType ?? '')) {
      final transferMatch = RegExp(
        r'^(\[[^\]]+\])\s*->\s*(\[[^\]]+\])(?:\s+(.*))?$',
      ).firstMatch(normalized);
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
      final routeParts = [
        fromLabel,
        toLabel,
      ].where((part) => part.trim().isNotEmpty).toList();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('振替元と振替先は別の口座を選択してください')));
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
            content: Text(isTransfer ? '振替を記録しました' : '収支を記録しました'),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('振替元と振替先は別の口座を選択してください')));
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
          content: Text(isTransfer ? '振替記録を更新しました' : '収支記録を更新しました'),
          backgroundColor: Theme.of(context).colorScheme.onSurface,
        ),
      );
    } catch (e) {
      debugPrint('Error editing flow: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('収支記録の更新に失敗しました: $e')));
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
    final date =
        DateTime.tryParse(flow['occurred_at']?.toString() ?? '')?.toLocal() ??
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
            child: const Text(
              '削除',
              style: TextStyle(color: Color(0xFFB91C1C), height: 1.5),
            ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('収支記録の削除に失敗しました: $e')));
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
                  decoration: const InputDecoration(
                    labelText: 'タスク内容 (例: 確定申告)',
                  ),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('支払日を更新しました: $dueDateStr')));
    } catch (e) {
      debugPrint('edit due_date error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('支払日の更新に失敗: $e'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
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

    final custom = TextEditingController(
      text: selected == 'その他' ? current : '',
    );

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
            _buildSalarySpendingBreakdownCard(),
            const SizedBox(height: 16),
            _buildDisposableBalanceCard(),
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
            child: const Icon(Icons.merge_type, color: Color(0xFF0F766E)),
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

  SalarySpendingBreakdown _buildSalarySpendingBreakdown() {
    final expenses = <SalarySpendingEntry>[];
    final incomes = <SalaryIncomeEntry>[];
    final cardBillingMarkers = <String>{};

    bool hasIncomeEntry(DateTime date, double amount) {
      final rowKey = '${_dateOnly(date)}:${amount.round()}';
      return incomes.any(
        (entry) => '${_dateOnly(entry.date)}:${entry.amount.round()}' == rowKey,
      );
    }

    void addIncomeEntry({
      required DateTime date,
      required double amount,
      required String description,
    }) {
      if (amount <= 0 || hasIncomeEntry(date, amount)) {
        return;
      }
      incomes.add(
        SalaryIncomeEntry(
          date: date,
          amount: amount,
          description: description.trim().isEmpty ? '収入' : description.trim(),
        ),
      );
    }

    for (final line in _cardStatementLines) {
      final postedAt = line.postedAt;
      if (postedAt == null) {
        continue;
      }
      final billingName = line.billingAccountName?.trim();
      if (billingName != null && billingName.isNotEmpty) {
        cardBillingMarkers.add(billingName.toLowerCase());
      }
      cardBillingMarkers.add(line.billingAccountId.toLowerCase());
      final billingLabel = billingName != null && billingName.isNotEmpty
          ? billingName
          : line.billingAccountId;
      expenses.add(
        SalarySpendingEntry(
          date: postedAt,
          amount: line.amount,
          description: line.description,
          sourceLabel: billingLabel,
        ),
      );
    }

    for (final flow in _recentFlows) {
      final actionType = flow['action_type']?.toString() ?? '';
      if (_isTransferActionType(actionType)) {
        continue;
      }
      final occurredAt = DateTime.tryParse(
        flow['occurred_at']?.toString() ?? '',
      )?.toLocal();
      final amount = (flow['amount'] as num?)?.toDouble() ?? 0;
      if (occurredAt == null || amount <= 0) {
        continue;
      }
      final description = flow['description']?.toString() ?? '';
      final displayTitle = _flowDisplayTitle(flow);
      if (_isExpenseActionType(actionType)) {
        final lowerDescription = description.toLowerCase();
        final representedByCardDetail = cardBillingMarkers.any(
          (marker) => marker.isNotEmpty && lowerDescription.contains(marker),
        );
        if (representedByCardDetail) {
          continue;
        }
        expenses.add(
          SalarySpendingEntry(
            date: occurredAt,
            amount: amount,
            description: displayTitle.isEmpty ? description : displayTitle,
            sourceLabel: _actionTypeToFlowLabel(actionType),
          ),
        );
      } else if (_isIncomeActionType(actionType)) {
        incomes.add(
          SalaryIncomeEntry(
            date: occurredAt,
            amount: amount,
            description: displayTitle.isEmpty ? description : displayTitle,
          ),
        );
      }
    }

    for (final plan in _monthlyIncomePlans) {
      addIncomeEntry(
        date: plan.date,
        amount: plan.amount,
        description: plan.name,
      );
    }

    for (final row in _payslipSalaryIncomes) {
      final payDate = DateTime.tryParse(row['pay_date']?.toString() ?? '');
      final amount = _numberFromDynamic(row['amount']);
      if (payDate == null || amount <= 0) {
        continue;
      }
      final description = row['description']?.toString().trim() ?? '';
      addIncomeEntry(
        date: payDate,
        amount: amount,
        description: description.isEmpty ? '給与明細' : '給与明細: $description',
      );
    }

    for (final row in _payslipRows) {
      final payDate = DateTime.tryParse(row['pay_date']?.toString() ?? '');
      final amount = _numberFromDynamic(row['net_amount']);
      if (payDate == null || amount <= 0) {
        continue;
      }
      final companyName = row['company_name']?.toString().trim() ?? '';
      addIncomeEntry(
        date: payDate,
        amount: amount,
        description: companyName.isEmpty ? '給与明細' : '給与明細: $companyName',
      );
    }

    return _salarySpendingBreakdownService.build(
      referenceDate: _now,
      expenses: expenses,
      incomes: incomes,
      salaryDay: _salarySpendingSalaryDay,
    );
  }

  DisposableBalanceResult _buildDisposableBalance(
    SalarySpendingBreakdown salaryBreakdown,
  ) {
    final payslips = <DisposableBalancePayslip>[
      for (final row in _payslipRows)
        if (DateTime.tryParse(row['pay_date']?.toString() ?? '') != null)
          DisposableBalancePayslip(
            payDate: DateTime.parse(row['pay_date'].toString()),
            netAmount: _numberFromDynamic(row['net_amount']),
            companyName: row['company_name']?.toString() ?? '',
            confidence: _numberFromDynamic(row['confidence']),
          ),
    ];
    if (payslips.isEmpty && salaryBreakdown.salaryIncomeTotal > 0) {
      payslips.add(
        DisposableBalancePayslip(
          payDate: salaryBreakdown.periodStart,
          netAmount: salaryBreakdown.salaryIncomeTotal,
          companyName: '収入入力',
          confidence: 0.5,
        ),
      );
    }

    final nextPayday = _disposableBalanceService.nextPaydayFor(
      asOfDate: _now,
      salaryDay: _salarySpendingSalaryDay,
    );
    final cycleStart = _disposableBalanceService.salaryCycleStartFor(
      asOfDate: _now,
      salaryDay: _salarySpendingSalaryDay,
    );
    final cycleStartOnly = DateTime(
      cycleStart.year,
      cycleStart.month,
      cycleStart.day,
    );
    final recurringExpenses = <DisposableBalanceRecurringExpense>[];
    final recurringExpenseKeys = <String>{};
    void addRecurringExpense(DisposableBalanceRecurringExpense expense) {
      if (expense.amount <= 0) {
        return;
      }
      final normalizedName = expense.name.trim().toLowerCase();
      final key =
          '$normalizedName|${expense.dayOfMonth}|${expense.amount.round()}';
      if (!recurringExpenseKeys.add(key)) {
        return;
      }
      recurringExpenses.add(expense);
    }

    for (final row in _subscriptionsThreeMonths) {
      final dueDate = DateTime.tryParse(row['due_date']?.toString() ?? '');
      if (dueDate == null) {
        continue;
      }
      final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
      if (dueDateOnly.isBefore(cycleStartOnly) ||
          !dueDateOnly.isBefore(nextPayday)) {
        continue;
      }
      final amount = _numberFromDynamic(row['price'] ?? row['amount']);
      if (amount <= 0) {
        continue;
      }
      addRecurringExpense(
        DisposableBalanceRecurringExpense(
          name: row['name']?.toString() ?? 'サブスク',
          amount: amount,
          dayOfMonth: dueDate.day.clamp(1, 28).toInt(),
          category: 'subscription',
        ),
      );
    }

    final debts = <DisposableBalanceDebt>[];
    final latestSnapshot = _latestSnapshotForDisplay();
    if (latestSnapshot.isNotEmpty) {
      final workbook = _assetLiabilityPlanner.buildWorkbook(
        latestSnapshot: latestSnapshot,
        baseDate: _now,
        monthlyPaymentOverrides: _monthlyPaymentOverrides,
        actualPaymentAmounts: _actualPaymentAmounts,
        paymentDifferenceReasons: _paymentDifferenceReasons,
        annualRateOverrides: _annualRateOverrides,
        paidAccountNames: _monthlyPaidAccountNames,
        paymentSourceAccountIds: _paymentSourceAccountIds,
        defaultPaymentSourceAccountIds: _defaultPaymentSourceAccountIds,
        defaultCardBillingAccountIds: _defaultCardBillingAccountIds,
        cardBillingAccountIds: _cardBillingAccountIds,
        incomePlans: _monthlyIncomePlans,
        cardStatementLines: _cardStatementLines,
        transferTasks: _transferTasks,
        includeDefaultFixedPayments: true,
      );
      final assetLiabilityInputs =
          _disposableBalanceAssetLiabilityAdapter.build(
        workbook: workbook,
        cycleStart: cycleStartOnly,
        nextPayday: nextPayday,
        lastUpdatedForDebt: (row) {
          return DateTime.tryParse(_lastUpdatedDates[row.name] ?? '');
        },
      );
      for (final expense in assetLiabilityInputs.recurringExpenses) {
        addRecurringExpense(expense);
      }
      debts.addAll(assetLiabilityInputs.debts);
    }

    return _disposableBalanceService.build(
      asOfDate: _now,
      payslips: payslips,
      recurringExpenses: recurringExpenses,
      debts: debts,
      salaryDay: _salarySpendingSalaryDay,
    );
  }

  Widget _buildDisposableBalanceCard() {
    final salaryBreakdown = _buildSalarySpendingBreakdown();
    final balance = _buildDisposableBalance(salaryBreakdown);
    final serverActions =
        (_serverDisposableBalanceResult?['required_actions'] as List?)
                ?.whereType<Map>()
                .map((action) => Map<String, dynamic>.from(action))
                .toList(growable: false) ??
            const <Map<String, dynamic>>[];
    final localActions = balance.requiredActions
        .map(
          (action) => <String, dynamic>{
            'action_key': action.actionKey,
            'title': action.title,
            'instruction': action.instruction,
            'amount_impact': action.amountImpact,
          },
        )
        .toList(growable: false);
    final actions = _effectiveDisposableBalanceActions(
      balance: balance,
      serverActions: serverActions,
      localActions: localActions,
    );
    final periodLabel = '${DateFormat('yyyy/MM/dd').format(balance.asOfDate)}〜'
        '${DateFormat('yyyy/MM/dd').format(balance.nextPayday.subtract(const Duration(days: 1)))}';
    final breakdownMessage = switch (_disposableBalanceBreakdownKey) {
      'fixed' => _buildDisposableBalanceFixedBreakdown(balance),
      'debt' => _buildDisposableBalanceDebtBreakdown(balance),
      _ => null,
    };

    return Card(
      key: const Key('asset_disposable_balance_card'),
      elevation: 3,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFA7F3D0)),
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
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '給料日までの可処分残高',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$periodLabel / 残り${balance.daysRemaining}日。収入は給与明細の解析結果を優先します。支出未入力時は上限目安です。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
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
                  value: _formatYen(balance.income),
                  color: const Color(0xFF0F766E),
                ),
                _buildFlowPriorityMetric(
                  label: '固定費',
                  value: '-${_formatYen(balance.fixedTotal)}',
                  color: const Color(0xFFB45309),
                  isSelected: _disposableBalanceBreakdownKey == 'fixed',
                  onHoverStart: () => _setDisposableBalanceBreakdown('fixed'),
                  onHoverEnd: () => _clearDisposableBalanceBreakdown('fixed'),
                ),
                _buildFlowPriorityMetric(
                  label: '返済',
                  value: '-${_formatYen(balance.debtTotal)}',
                  color: const Color(0xFFB91C1C),
                  isSelected: _disposableBalanceBreakdownKey == 'debt',
                  onHoverStart: () => _setDisposableBalanceBreakdown('debt'),
                  onHoverEnd: () => _clearDisposableBalanceBreakdown('debt'),
                ),
                _buildFlowPriorityMetric(
                  label: '返済元金',
                  value: '-${_formatYen(balance.debtPrincipalTotal)}',
                  color: const Color(0xFF7C2D12),
                  isSelected: _disposableBalanceBreakdownKey == 'debt',
                  onHoverStart: () => _setDisposableBalanceBreakdown('debt'),
                  onHoverEnd: () => _clearDisposableBalanceBreakdown('debt'),
                ),
                _buildFlowPriorityMetric(
                  label: '金利',
                  value: '-${_formatYen(balance.debtInterestTotal)}',
                  color: const Color(0xFF9F1239),
                  isSelected: _disposableBalanceBreakdownKey == 'debt',
                  onHoverStart: () => _setDisposableBalanceBreakdown('debt'),
                  onHoverEnd: () => _clearDisposableBalanceBreakdown('debt'),
                ),
                _buildFlowPriorityMetric(
                  label: '借金減少ライン',
                  value: _formatSignedYen(balance.debtReductionSpendingLimit),
                  color: balance.debtReductionSpendingLimit >= 0
                      ? const Color(0xFF065F46)
                      : const Color(0xFF7F1D1D),
                ),
                _buildFlowPriorityMetric(
                  label: '1日あたり',
                  value: _formatSignedYen(balance.dailyPace),
                  color: const Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _disposableBalanceReviewText(salaryBreakdown, balance),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (breakdownMessage != null) ...[
              const SizedBox(height: 10),
              _buildDisposableBalanceBreakdownPanel(breakdownMessage),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      _isUploadingPayslip ? null : _pickAndUploadPayslipPdf,
                  icon: _isUploadingPayslip
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: const Text('給与明細PDFをアップロード'),
                ),
                OutlinedButton.icon(
                  onPressed: _isComputingDisposableBalance
                      ? null
                      : () => _computeDisposableBalanceFromServer(),
                  icon: _isComputingDisposableBalance
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: const Text('AI提案を更新'),
                ),
              ],
            ),
            if (_isLoadingPayslipFinance ||
                _payslipIngestionMessage != null ||
                _disposableBalanceMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _isLoadingPayslipFinance
                    ? '給与明細データを読み込んでいます...'
                    : (_payslipIngestionMessage ??
                        _disposableBalanceMessage ??
                        ''),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (actions.isEmpty)
              Text(
                '必要なアクションはありません。今の支出ペースを維持しましょう。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < actions.take(3).length; i++)
                    _buildDisposableBalanceActionRow(
                      index: i + 1,
                      action: actions[i],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _disposableBalanceReviewText(
    SalarySpendingBreakdown salaryBreakdown,
    DisposableBalanceResult balance,
  ) {
    final formula = '計算: ${_formatYen(balance.income)} - '
        '${_formatYen(balance.fixedTotal)} - ${_formatYen(balance.debtTotal)} = '
        '${_formatSignedYen(balance.debtReductionSpendingLimit)}。';
    final debtSplit =
        '返済${_formatYen(balance.debtTotal)}の内訳は、元金${_formatYen(balance.debtPrincipalTotal)} / 金利${_formatYen(balance.debtInterestTotal)}です。';
    final String debtGuard;
    if (balance.debtTotal <= 0) {
      debtGuard = '今月の返済予定はありません。新規借入をしなければ債務残高は増えません。';
    } else if (balance.debtPrincipalTotal <= 0) {
      debtGuard = '今月の返済は元金減少が見込めないため、残高を減らすには追加返済か金利条件の見直しが必要です。';
    } else if (balance.debtReductionSpendingLimit >= 0) {
      debtGuard =
          'この借金減少ライン以内に使用額を抑えると、新規借入なしで元金${_formatYen(balance.debtPrincipalTotal)}分だけ先月より債務総額が減る見込みです。';
    } else {
      debtGuard = '固定費と返済で給与を超えているため、このままでは債務残高を増やさない運用ができません。支出削減か入金追加が必要です。';
    }
    if (salaryBreakdown.expenseEntryCount == 0) {
      return '$formula $debtSplit $debtGuard 給与日後の支出明細が未入力のため、これは「使ってよい確定額」ではなく給与ベースの上限目安です。銀行・カード明細を取り込むと実額に近づきます。';
    }
    return '$formula $debtSplit $debtGuard 給与日後の記録済み支出は${_formatYen(salaryBreakdown.totalExpense)}です。未取り込み支出がある場合は、この目安からさらに差し引いてください。';
  }

  String _buildDisposableBalanceFixedBreakdown(
      DisposableBalanceResult balance) {
    final rows = List<DisposableBalanceRecurringExpense>.from(
      balance.recurringExpenses,
    )..sort((a, b) {
        final day = a.dayOfMonth.compareTo(b.dayOfMonth);
        if (day != 0) return day;
        return b.amount.compareTo(a.amount);
      });
    return _buildDisposableBalanceBreakdownText(
      title: '固定費内訳',
      totalLabel: '固定費合計',
      total: balance.fixedTotal,
      lines: [
        for (final row in rows)
          '${row.dayOfMonth}日 ${row.name.trim().isEmpty ? '固定費' : row.name.trim()} ${_formatYen(row.amount)}',
      ],
    );
  }

  String _buildDisposableBalanceDebtBreakdown(DisposableBalanceResult balance) {
    final rows = List<DisposableBalanceDebt>.from(balance.debts)
      ..sort((a, b) {
        final day = (a.dayOfMonth ?? 99).compareTo(b.dayOfMonth ?? 99);
        if (day != 0) return day;
        return b.monthlyPayment.compareTo(a.monthlyPayment);
      });
    return _buildDisposableBalanceBreakdownText(
      title: '返済内訳',
      totalLabel: '返済合計',
      total: balance.debtTotal,
      lines: [
        for (final row in rows)
          '${row.dayOfMonth == null ? '' : '${row.dayOfMonth}日 '}'
              '${row.name.trim().isEmpty ? '返済' : row.name.trim()} ${_formatYen(row.monthlyPayment)}'
              ' / 元金 ${_formatYen(_disposableBalanceService.principalPaymentFor(row))}'
              ' / 金利 ${_formatYen(_disposableBalanceService.interestPaymentFor(row))}'
              '${row.principal > 0 ? ' / 残高 ${_formatYen(row.principal)}' : ''}',
        '元金合計 ${_formatYen(balance.debtPrincipalTotal)}',
        '金利合計 ${_formatYen(balance.debtInterestTotal)}',
      ],
    );
  }

  String _buildDisposableBalanceBreakdownText({
    required String title,
    required String totalLabel,
    required double total,
    required List<String> lines,
  }) {
    return <String>[
      title,
      if (lines.isEmpty) '対象なし' else ...lines,
      '$totalLabel ${_formatYen(total)}',
    ].join('\n');
  }

  void _setDisposableBalanceBreakdown(String key) {
    if (_disposableBalanceBreakdownKey == key) {
      return;
    }
    setState(() => _disposableBalanceBreakdownKey = key);
  }

  void _clearDisposableBalanceBreakdown(String key) {
    if (_disposableBalanceBreakdownKey != key) {
      return;
    }
    setState(() => _disposableBalanceBreakdownKey = null);
  }

  Widget _buildDisposableBalanceBreakdownPanel(String message) {
    final lines = message.split('\n');
    final title = lines.isEmpty ? '内訳' : lines.first;
    final detailLines =
        lines.length <= 1 ? const <String>[] : lines.skip(1).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF047857),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          for (final line in detailLines)
            Text(
              line,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF0F172A),
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDisposableBalanceActionRow({
    required int index,
    required Map<String, dynamic> action,
  }) {
    final actionKey =
        (action['action_key'] ?? action['actionKey'])?.toString().trim() ?? '';
    final rawTitle = action['title']?.toString().trim() ?? '';
    final rawInstruction = action['instruction']?.toString().trim() ?? '';
    final impact = _numberFromDynamic(action['amount_impact']);
    final title = _localizedDisposableActionTitle(actionKey, rawTitle);
    final instruction = _localizedDisposableActionInstruction(
      actionKey,
      rawTitle,
      rawInstruction,
      impact,
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: const Color(0xFF0F766E),
            child: Text(
              '$index',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'おすすめアクション' : title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                if (instruction.isNotEmpty)
                  Text(
                    instruction,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (impact > 0)
                  Text(
                    '効果目安: ${_formatYen(impact)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F766E),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _effectiveDisposableBalanceActions({
    required DisposableBalanceResult balance,
    required List<Map<String, dynamic>> serverActions,
    required List<Map<String, dynamic>> localActions,
  }) {
    final source = serverActions.isNotEmpty ? serverActions : localActions;
    return source.where((action) {
      final actionKey =
          (action['action_key'] ?? action['actionKey'])?.toString() ?? '';
      if (actionKey == 'upload_current_payslip' && balance.income > 0) {
        return false;
      }
      if (actionKey == 'add_recurring_expenses' && balance.fixedTotal > 0) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  String _localizedDisposableActionTitle(String actionKey, String rawTitle) {
    if (actionKey == 'upload_current_payslip') {
      return '今月の給与明細が未登録です';
    }
    if (actionKey == 'add_recurring_expenses') {
      return '固定費が未登録です';
    }
    if (actionKey.startsWith('refresh_debt_')) {
      final staleDebtName = _englishStaleDebtName(rawTitle);
      if (staleDebtName != null && staleDebtName.isNotEmpty) {
        return '$staleDebtNameの残高が古くなっています';
      }
      return rawTitle.isEmpty ? '借入残高を更新してください' : rawTitle;
    }
    if (actionKey.startsWith('cancel_duplicate_')) {
      final group = actionKey.substring('cancel_duplicate_'.length);
      return '${_duplicateSubscriptionLabel(group)}サブスクが重複しています';
    }
    return rawTitle;
  }

  String _localizedDisposableActionInstruction(
    String actionKey,
    String rawTitle,
    String rawInstruction,
    double impact,
  ) {
    if (actionKey == 'upload_current_payslip') {
      return '最新の給与明細PDFをアップロードして、収入を明細データで計算してください（約10秒）。';
    }
    if (actionKey == 'add_recurring_expenses') {
      return '家賃・公共料金・サブスクを固定費として登録してください（約180秒）。';
    }
    if (actionKey.startsWith('refresh_debt_')) {
      final debtName = _englishStaleDebtName(rawTitle);
      final subject = debtName == null || debtName.isEmpty ? '借入' : debtName;
      return '返済順を決める前に、$subjectの現在残高を入力してください（約60秒）。';
    }
    if (actionKey.startsWith('cancel_duplicate_')) {
      final group = actionKey.substring('cancel_duplicate_'.length);
      final label = _duplicateSubscriptionLabel(group);
      final impactLabel =
          impact > 0 ? '毎月${_formatYen(impact)}を削減できます' : '毎月の固定費を削減できます';
      return '$labelサブスクを1つに絞ると、$impactLabel（約120秒）。';
    }
    return rawInstruction;
  }

  String? _englishStaleDebtName(String rawTitle) {
    const suffix = ' balance is stale';
    final lowerTitle = rawTitle.toLowerCase();
    if (!lowerTitle.endsWith(suffix)) {
      return null;
    }
    return rawTitle.substring(0, rawTitle.length - suffix.length).trim();
  }

  String _duplicateSubscriptionLabel(String group) {
    switch (group) {
      case 'music':
        return '音楽';
      case 'video':
        return '動画';
    }
    return group.isEmpty ? '対象' : group;
  }

  Widget _buildSalarySpendingBreakdownCard() {
    final breakdown = _buildSalarySpendingBreakdown();
    final periodLabel = '${DateFormat('M/d').format(breakdown.periodStart)}〜'
        '${DateFormat('M/d').format(breakdown.periodEndInclusive)}';
    final remaining = breakdown.remainingAfterExpense;
    final topSection = breakdown.topSection;
    final chartSections = breakdown.sections.take(8).toList(growable: false);
    SalarySpendingCategorySlice? unknownSection;
    for (final section in breakdown.sections) {
      if (section.category == '使途不明金') {
        unknownSection = section;
        break;
      }
    }

    return Card(
      key: const Key('asset_salary_spending_breakdown_card'),
      elevation: 3,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDBEAFE)),
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
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pie_chart_outline,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '前回給料の使いみち',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '給料日${breakdown.salaryDay}日基準の $periodLabel を集計。支出カテゴリ別に、前回給料が何へ消えたかを見ます。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
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
                  label: '期間支出',
                  value: _formatYen(breakdown.totalExpense),
                  color: const Color(0xFFB91C1C),
                ),
                _buildFlowPriorityMetric(
                  label: '給料収入',
                  value: breakdown.salaryIncomeTotal > 0
                      ? _formatYen(breakdown.salaryIncomeTotal)
                      : '未記録',
                  color: const Color(0xFF0F766E),
                ),
                _buildFlowPriorityMetric(
                  label: '残り目安',
                  value:
                      remaining == null ? '未計算' : _formatSignedYen(remaining),
                  color: remaining == null || remaining >= 0
                      ? const Color(0xFF065F46)
                      : const Color(0xFF7F1D1D),
                ),
                _buildFlowPriorityMetric(
                  label: '最大カテゴリ',
                  value: topSection == null
                      ? '未記録'
                      : '${topSection.category} ${(topSection.ratio * 100).round()}%',
                  color: const Color(0xFF2563EB),
                ),
                if (unknownSection != null)
                  _buildFlowPriorityMetric(
                    label: '使途不明金',
                    value: _formatYen(unknownSection.amount),
                    color: const Color(0xFFD97706),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (breakdown.sections.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  'この給与サイクルの支出がまだありません。収支入力またはカード明細取込を行うと円グラフが表示されます。',
                  style: TextStyle(color: Color(0xFF1E3A8A), height: 1.5),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  final chart = SizedBox(
                    height: compact ? 210 : 240,
                    width: compact ? double.infinity : 260,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: compact ? 42 : 50,
                        sections: [
                          for (var i = 0; i < chartSections.length; i++)
                            PieChartSectionData(
                              color: _salarySpendingChartColors[
                                  i % _salarySpendingChartColors.length],
                              value: chartSections[i].amount,
                              title:
                                  '${(chartSections[i].ratio * 100).round()}%',
                              radius: compact ? 72 : 82,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                  final legend = Column(
                    children: [
                      for (var i = 0; i < chartSections.length; i++)
                        _buildSalarySpendingLegendRow(
                          section: chartSections[i],
                          color: _salarySpendingChartColors[
                              i % _salarySpendingChartColors.length],
                        ),
                    ],
                  );
                  if (compact) {
                    return Column(
                      children: [chart, const SizedBox(height: 12), legend],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      chart,
                      const SizedBox(width: 18),
                      Expanded(child: legend),
                    ],
                  );
                },
              ),
            if (unknownSection != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFBBF24)),
                ),
                child: Text(
                  '残高差分から ${_formatYen(unknownSection.amount)} を使途不明金として自動記録しています。下の収支履歴で行をタップすると、家賃・返済・食費などへ後から分類できます。',
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _scrollTo(_keyFlow),
                icon: const Icon(Icons.add_chart),
                label: Text(
                  unknownSection == null ? '支出を追加して内訳を更新' : '使途不明金を分類して内訳を更新',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalarySpendingLegendRow({
    required SalarySpendingCategorySlice section,
    required Color color,
  }) {
    final samples = section.sampleDescriptions
        .where((sample) => sample.trim().isNotEmpty)
        .take(2)
        .join(' / ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${section.category} ${_formatYen(section.amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                Text(
                  '${(section.ratio * 100).toStringAsFixed(1)}% / ${section.entryCount}件'
                  '${samples.isEmpty ? '' : ' / $samples'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    bool isSelected = false,
    VoidCallback? onHoverStart,
    VoidCallback? onHoverEnd,
  }) {
    final metric = Container(
      constraints: const BoxConstraints(minWidth: 108),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: isSelected ? Border.all(color: color, width: 1.2) : null,
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
    if (onHoverStart == null && onHoverEnd == null) {
      return metric;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverStart?.call(),
      onExit: (_) => onHoverEnd?.call(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onHoverStart,
        child: metric,
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
              style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
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
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
          Text(
            '固定費: ${_formatYen(fixedCost)}',
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
          Text(
            'タスク: $completedTasks/$totalTasks 完了',
            style: const TextStyle(fontSize: 12, height: 1.5),
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
        {'total': 0, 'completed': 0, 'pending': 0};
    final nextTask =
        taskStatsByMonth[nextKey] ?? {'total': 0, 'completed': 0, 'pending': 0};

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
    final totalDebt = liabilities.fold<double>(
      0,
      (sum, e) => sum + e.value.abs(),
    );
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
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
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
                                !isEnabled,
                                remainingDebt,
                              ),
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
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
        ),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHigh,
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
                              Icons.playlist_add_check_circle_outlined,
                            ),
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
                        icon: const Icon(Icons.remove_done),
                        label: const Text('選択解除'),
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
                                Icons.playlist_add_check_circle_outlined,
                              ),
                        label: Text('必須タスクへ追加 ($selectedCount)'),
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
      actualPaymentAmounts: _actualPaymentAmounts,
      paymentDifferenceReasons: _paymentDifferenceReasons,
      annualRateOverrides: _annualRateOverrides,
      paidAccountNames: _monthlyPaidAccountNames,
      paymentSourceAccountIds: _paymentSourceAccountIds,
      defaultPaymentSourceAccountIds: _defaultPaymentSourceAccountIds,
      defaultCardBillingAccountIds: _defaultCardBillingAccountIds,
      cardBillingAccountIds: _cardBillingAccountIds,
      incomePlans: _monthlyIncomePlans,
      cardStatementLines: _cardStatementLines,
      transferTasks: _transferTasks,
      includeDefaultFixedPayments: true,
    );
    _scheduleAssetLiabilityStateIdMigration(workbook);
    final insightReport = _assetManagementInsightService.buildReport(
      workbook: workbook,
      userProfile: _assetManagementUserProfile,
    );
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
                Icon(Icons.table_chart_outlined, color: Color(0xFF0F766E)),
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
            _buildAssetLiabilitySyncPanel(),
            const SizedBox(height: 12),
            _buildAssetManagementAiAssistantSection(insightReport),
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
            if (workbook.debtMasterRows.any(
              (row) => row.includedInBillingAccount,
            )) ...[
              const SizedBox(height: 8),
              _buildAssetWorkbookCardBillingNotice(workbook),
            ],
            const SizedBox(height: 16),
            _buildCardBillingReviewSection(workbook),
            if (workbook.hasOverduePayments) ...[
              const SizedBox(height: 8),
              _buildAssetWorkbookOverdueWarning(workbook),
            ],
            const SizedBox(height: 12),
            _buildAssetWorkbookWarning(workbook),
            const SizedBox(height: 16),
            _buildAssetPaymentReminderPanel(workbook),
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
            _buildMonthlyReportSection(),
            const SizedBox(height: 16),
            _buildTransferSuggestionSection(workbook),
            const SizedBox(height: 16),
            _buildAssetWorkbookDebtTable(workbook),
            const SizedBox(height: 16),
            _buildAssetWorkbookPriorityList(workbook),
            const SizedBox(height: 16),
            _buildAssetRepaymentSimulationPanel(workbook),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetLiabilitySyncPanel() {
    final syncEnabled = _assetLiabilityRepository.supabaseSyncEnabled;
    final statusColor = _assetLiabilityManualSyncStatusColor(
      _assetLiabilitySyncStatus,
    );
    final lastSyncedAt = _lastAssetLiabilitySyncAt == null
        ? '未実行'
        : DateFormat(
            'yyyy/MM/dd HH:mm',
          ).format(_lastAssetLiabilitySyncAt!.toLocal());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Supabase同期',
                  style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
                ),
              ),
              FilledButton.icon(
                onPressed: syncEnabled && !_isRunningAssetLiabilitySync
                    ? _runAssetLiabilityManualSync
                    : null,
                icon: _isRunningAssetLiabilitySync
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_sync_outlined),
                label: Text(syncEnabled ? '手動同期' : '同期OFF'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: syncEnabled &&
                      !_isRunningAssetLiabilitySync &&
                      !_isPreviewingAssetLiabilitySync
                  ? _previewAssetLiabilitySync
                  : null,
              icon: _isPreviewingAssetLiabilitySync
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.manage_search_outlined),
              label: Text(syncEnabled ? '同期プレビュー' : 'プレビューOFF'),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAssetLiabilitySyncChip(
                label: 'Supabase同期',
                value: syncEnabled ? 'ON' : 'OFF',
                color: syncEnabled
                    ? const Color(0xFF0D9488)
                    : Theme.of(context).colorScheme.outline,
              ),
              _buildAssetLiabilitySyncChip(
                label: '最終同期',
                value: lastSyncedAt,
                color: const Color(0xFF2563EB),
              ),
              _buildAssetLiabilitySyncChip(
                label: '結果',
                value: _assetLiabilityManualSyncStatusLabel(
                  _assetLiabilitySyncStatus,
                ),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _assetLiabilitySyncMessage ??
                (syncEnabled
                    ? '手動同期でSupabase保存状態を確認できます。'
                    : 'Supabase同期は無効です。ローカル保存のみ使用しています。'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (_assetLiabilitySyncPreview != null) ...[
            const SizedBox(height: 8),
            _buildAssetLiabilitySyncPreviewDetails(_assetLiabilitySyncPreview!),
            if (_assetLiabilitySyncPreview!.hasConflict) ...[
              const SizedBox(height: 8),
              _buildAssetLiabilityConflictResolutionSection(
                _assetLiabilitySyncPreview!,
              ),
            ],
          ],
          const SizedBox(height: 8),
          _buildAssetLiabilitySyncAuditLogSection(syncEnabled),
          if (_assetLiabilitySyncConflicts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final target in _assetLiabilitySyncConflicts)
                  Chip(
                    avatar: const Icon(Icons.warning_amber, size: 16),
                    label: Text('競合: $target'),
                    backgroundColor: const Color(0xFFFFF7ED),
                    side: const BorderSide(color: Color(0xFFF97316)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssetLiabilitySyncAuditLogSection(bool syncEnabled) {
    final logs = _assetLiabilitySyncAuditLogs.take(8).toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Supabase同期監査ログ',
                  style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                ),
              ),
              _buildAssetLiabilitySyncChip(
                label: 'ログ',
                value: syncEnabled ? '${logs.length}件' : 'OFF',
                color: syncEnabled
                    ? const Color(0xFF2563EB)
                    : Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            syncEnabled
                ? '同期プレビュー・手動同期・競合検出・失敗をローカルに記録します。'
                : 'Supabase同期がOFFのため、同期検証ログは記録しません。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (syncEnabled && logs.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'まだ同期検証ログはありません。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
          if (syncEnabled && logs.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final log in logs) _buildAssetLiabilitySyncAuditLogTile(log),
          ],
        ],
      ),
    );
  }

  Widget _buildAssetLiabilitySyncAuditLogTile(AssetLiabilitySyncAuditLog log) {
    final color = _assetLiabilitySyncAuditLogColor(log);
    final executedAt = DateFormat(
      'MM/dd HH:mm',
    ).format(log.executedAt.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildAssetLiabilitySyncChip(
                  label: '時刻',
                  value: executedAt,
                  color: color,
                ),
                _buildAssetLiabilitySyncChip(
                  label: '種別',
                  value: _assetLiabilitySyncAuditTypeLabel(log.type),
                  color: color,
                ),
                _buildAssetLiabilitySyncChip(
                  label: '対象月',
                  value: log.monthKey,
                  color: const Color(0xFF475569),
                ),
                _buildAssetLiabilitySyncChip(
                  label: '件数',
                  value: '${log.count}件',
                  color: const Color(0xFF475569),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${log.targetDataType} / ${log.result}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (log.errorMessage != null) ...[
              const SizedBox(height: 2),
              Text(
                log.errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _assetLiabilitySyncAuditTypeLabel(AssetLiabilitySyncAuditType type) {
    switch (type) {
      case AssetLiabilitySyncAuditType.preview:
        return 'preview';
      case AssetLiabilitySyncAuditType.manualSync:
        return 'manual_sync';
      case AssetLiabilitySyncAuditType.uploadCandidate:
        return 'upload';
      case AssetLiabilitySyncAuditType.downloadCandidate:
        return 'download';
      case AssetLiabilitySyncAuditType.conflictDetected:
        return 'conflict';
      case AssetLiabilitySyncAuditType.conflictResolved:
        return 'resolved';
      case AssetLiabilitySyncAuditType.failed:
        return 'failed';
      case AssetLiabilitySyncAuditType.success:
        return 'success';
    }
  }

  Color _assetLiabilitySyncAuditLogColor(AssetLiabilitySyncAuditLog log) {
    if (log.isFailure) {
      return const Color(0xFFB91C1C);
    }
    if (log.isConflict) {
      return const Color(0xFFD97706);
    }
    if (log.type == AssetLiabilitySyncAuditType.conflictResolved) {
      return const Color(0xFF0D9488);
    }
    if (log.type == AssetLiabilitySyncAuditType.success) {
      return const Color(0xFF0D9488);
    }
    if (log.type == AssetLiabilitySyncAuditType.downloadCandidate) {
      return const Color(0xFF0D9488);
    }
    if (log.type == AssetLiabilitySyncAuditType.uploadCandidate) {
      return const Color(0xFF2563EB);
    }
    return const Color(0xFF475569);
  }

  Widget _buildAssetLiabilitySyncPreviewDetails(
    AssetLiabilitySyncPreviewResult preview,
  ) {
    final previewedAt = DateFormat(
      'yyyy/MM/dd HH:mm',
    ).format(preview.completedAt.toLocal());
    final conflictColor =
        preview.hasConflict ? const Color(0xFFD97706) : const Color(0xFF0D9488);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '同期プレビュー',
                  style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                ),
              ),
              Text(
                previewedAt,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAssetLiabilitySyncChip(
                label: '同期対象',
                value: '${preview.targetCount}件',
                color: const Color(0xFF2563EB),
              ),
              _buildAssetLiabilitySyncChip(
                label: 'ローカルあり',
                value: '${preview.localDataTargetCount}件',
                color: const Color(0xFF475569),
              ),
              _buildAssetLiabilitySyncChip(
                label: 'Supabaseあり',
                value: '${preview.remoteDataTargetCount}件',
                color: const Color(0xFF475569),
              ),
              _buildAssetLiabilitySyncChip(
                label: 'アップロード候補',
                value: '${preview.uploadCandidateCount}件',
                color: const Color(0xFF2563EB),
              ),
              _buildAssetLiabilitySyncChip(
                label: 'ダウンロード候補',
                value: '${preview.downloadCandidateCount}件',
                color: const Color(0xFF0D9488),
              ),
              _buildAssetLiabilitySyncChip(
                label: '競合',
                value: '${preview.conflictCount}件',
                color: conflictColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            preview.message,
            style: TextStyle(
              color: preview.hasConflict
                  ? const Color(0xFFD97706)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: preview.hasConflict ? FontWeight.w700 : null,
              height: 1.5,
            ),
          ),
          if (preview.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in preview.items)
                  Chip(
                    label: Text(
                      '${item.targetName}: '
                      '${_assetLiabilitySyncPreviewItemLabel(item)} '
                      '(ローカル${item.localCount} / Supabase${item.remoteCount})',
                    ),
                    backgroundColor: _assetLiabilitySyncPreviewItemColor(
                      item,
                    ).withValues(alpha: 0.10),
                    side: BorderSide(
                      color: _assetLiabilitySyncPreviewItemColor(
                        item,
                      ).withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssetLiabilityConflictResolutionSection(
    AssetLiabilitySyncPreviewResult preview,
  ) {
    final conflictItems =
        preview.items.where((item) => item.conflict).toList(growable: false);
    if (conflictItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.rule_folder_outlined,
                size: 16,
                color: Color(0xFFD97706),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '同期競合の解決',
                  style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                ),
              ),
              if (_isResolvingAssetLiabilityConflict)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ローカルとSupabaseの両方にデータがある項目は自動上書きしません。'
            'どちらを優先するか明示的に選んだ項目だけRepository経由で反映します。',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 8),
          for (final item in conflictItems) ...[
            _buildAssetLiabilityConflictResolutionTile(item),
            if (item != conflictItems.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildAssetLiabilityConflictResolutionTile(
    AssetLiabilitySyncPreviewItem item,
  ) {
    final disabled = _isResolvingAssetLiabilityConflict ||
        _isRunningAssetLiabilitySync ||
        _isPreviewingAssetLiabilitySync;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildAssetLiabilitySyncChip(
                label: '対象',
                value: item.targetName,
                color: const Color(0xFFD97706),
              ),
              _buildAssetLiabilitySyncChip(
                label: 'ローカル',
                value: '${item.localCount}件',
                color: const Color(0xFF475569),
              ),
              _buildAssetLiabilitySyncChip(
                label: 'Supabase',
                value: '${item.remoteCount}件',
                color: const Color(0xFF475569),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: disabled
                    ? null
                    : () => _resolveAssetLiabilitySyncConflict(
                          item: item,
                          choice:
                              AssetLiabilityConflictResolutionChoice.localWins,
                        ),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('ローカル優先'),
              ),
              OutlinedButton.icon(
                onPressed: disabled
                    ? null
                    : () => _resolveAssetLiabilitySyncConflict(
                          item: item,
                          choice: AssetLiabilityConflictResolutionChoice
                              .supabaseWins,
                        ),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Supabase優先'),
              ),
              TextButton.icon(
                onPressed: disabled
                    ? null
                    : () => _resolveAssetLiabilitySyncConflict(
                          item: item,
                          choice: AssetLiabilityConflictResolutionChoice.skip,
                        ),
                icon: const Icon(Icons.block_outlined),
                label: const Text('今回はスキップ'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _assetLiabilitySyncPreviewItemLabel(
    AssetLiabilitySyncPreviewItem item,
  ) {
    if (item.conflict) {
      return '競合';
    }
    if (item.uploadCandidate) {
      return 'アップロード候補';
    }
    if (item.downloadCandidate) {
      return 'ダウンロード候補';
    }
    return '差分なし';
  }

  Color _assetLiabilitySyncPreviewItemColor(
    AssetLiabilitySyncPreviewItem item,
  ) {
    if (item.conflict) {
      return const Color(0xFFD97706);
    }
    if (item.uploadCandidate) {
      return const Color(0xFF2563EB);
    }
    if (item.downloadCandidate) {
      return const Color(0xFF0D9488);
    }
    return Theme.of(context).colorScheme.outline;
  }

  Widget _buildAssetLiabilitySyncChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildAssetManagementAiAssistantSection(
    AssetManagementInsightReport report,
  ) {
    final criticalCount = report.criticalActions.length;
    final statusColor =
        criticalCount > 0 ? const Color(0xFFB91C1C) : const Color(0xFF0D9488);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: statusColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI資産管理アシスタント',
                  style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAssetLiabilitySyncChip(
                label: 'プロフィール',
                value: report.userProfile == null ? '未連携' : '連携済み',
                color: report.userProfile == null
                    ? const Color(0xFFD97706)
                    : const Color(0xFF0D9488),
              ),
              _buildAssetLiabilitySyncChip(
                label: '要対応',
                value: '${report.actionItems.length}件',
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'AIにはプロフィール、資産/負債ボードの詳細データ、現実装のソース/ドキュメント文脈を渡し、生活再建アドバイスと開発者向け改善提案を具体化します。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _buildAssetManagementAiSummaryPanel(report),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAssetManagementAvailableCard(report.todayAvailable),
              _buildAssetManagementAvailableCard(report.weekAvailable),
              _buildAssetManagementAvailableCard(report.monthAvailable),
            ],
          ),
          const SizedBox(height: 12),
          if (report.emergencyAdvices.isNotEmpty) ...[
            _buildAssetManagementEmergencyAdviceList(report.emergencyAdvices),
            const SizedBox(height: 12),
          ],
          _buildAssetManagementAssistantActionList(report.actionItems),
          if (report.movementSuggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildAssetManagementMovementSuggestionList(
              report.movementSuggestions,
            ),
          ],
          const SizedBox(height: 12),
          _buildAssetManagementDeveloperRequestList(report.developerRequests),
        ],
      ),
    );
  }

  Widget _buildAssetManagementAiSummaryPanel(
    AssetManagementInsightReport report,
  ) {
    final enabled = _assetManagementAiSummaryService.aiEnabled;
    if (enabled) {
      _requestAssetManagementAiSummaryIfNeeded(report);
    }
    final result = _assetManagementAiSummaryResult ??
        (enabled
            ? _assetManagementAiSummaryService.buildWaitingForAiResult(report)
            : _assetManagementAiSummaryService.buildDisabledResult(report));
    final color = switch (result.status) {
      AssetManagementAiSummaryStatus.aiGenerated => const Color(0xFF0D9488),
      AssetManagementAiSummaryStatus.fallback => const Color(0xFFD97706),
      AssetManagementAiSummaryStatus.disabled => const Color(0xFF475569),
    };
    final statusLabel = switch (result.status) {
      AssetManagementAiSummaryStatus.aiGenerated => 'AI要約',
      AssetManagementAiSummaryStatus.fallback => '定型要約',
      AssetManagementAiSummaryStatus.disabled => 'AI無効',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt_outlined, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.text,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (result.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              result.errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildAssetLiabilitySyncChip(
                label: 'AI',
                value: statusLabel,
                color: color,
              ),
              _buildAssetLiabilitySyncChip(
                label: 'ソース',
                value: _localizedAssetManagementAiSource(result.source),
                color: color,
              ),
              OutlinedButton.icon(
                onPressed: enabled && !_isGeneratingAssetManagementAiSummary
                    ? () => _generateAssetManagementAiSummary(
                          report,
                          force: true,
                        )
                    : null,
                icon: _isGeneratingAssetManagementAiSummary
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined, size: 16),
                label: Text(
                  enabled ? 'AI要約を更新' : 'AI要約は機能フラグで無効です',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'AIにはプロフィール、口座名、残高、支払予定、支払原資、利率、月利息、負債割合、現実装コンテキストを含む詳細ペイロードを渡します。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _localizedAssetManagementAiSource(String source) {
    return switch (source) {
      'deterministic fallback / feature flag off' => 'ルールベース要約 / AI無効',
      'deterministic fallback / ai-hub failed' => 'ルールベース要約 / AI接続失敗',
      'deterministic fallback / waiting for ai-hub' => 'ルールベース要約 / AI応答待ち',
      _ => source
          .replaceAll('deterministic fallback', 'ルールベース要約')
          .replaceAll('feature flag off', 'AI無効')
          .replaceAll('ai-hub failed', 'AI接続失敗')
          .replaceAll('waiting for ai-hub', 'AI応答待ち'),
    };
  }

  Future<void> _generateAssetManagementAiSummary(
    AssetManagementInsightReport report, {
    String? requestKey,
    bool force = false,
  }) async {
    final key = requestKey ?? _assetManagementAiSummaryKey(report);
    if (_assetManagementAiSummaryInFlightKey == key) {
      return;
    }
    if (!force &&
        _assetManagementAiSummaryAutoRequestedKeys.contains(key) &&
        _assetManagementAiSummaryRequestKey == key &&
        _assetManagementAiSummaryResult != null) {
      return;
    }
    setState(() {
      _isGeneratingAssetManagementAiSummary = true;
      _assetManagementAiSummaryInFlightKey = key;
      _assetManagementAiSummaryRequestKey = key;
    });
    final result = await _assetManagementAiSummaryService.generateSummary(
      report: report,
    );
    if (!mounted) {
      return;
    }
    if (_assetManagementAiSummaryInFlightKey != key) {
      return;
    }
    setState(() {
      _assetManagementAiSummaryResult = result;
      _isGeneratingAssetManagementAiSummary = false;
      _assetManagementAiSummaryInFlightKey = null;
      _assetManagementAiSummaryRequestKey = key;
    });
  }

  void _requestAssetManagementAiSummaryIfNeeded(
    AssetManagementInsightReport report,
  ) {
    if (!_assetManagementAiSummaryService.aiEnabled ||
        _isGeneratingAssetManagementAiSummary) {
      return;
    }
    final key = _assetManagementAiSummaryKey(report);
    if (_assetManagementAiSummaryRequestKey == key ||
        _assetManagementAiSummaryInFlightKey == key ||
        _assetManagementAiSummaryAutoRequestedKeys.contains(key)) {
      return;
    }
    _assetManagementAiSummaryRequestKey = key;
    _assetManagementAiSummaryAutoRequestedKeys.add(key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_assetManagementAiSummaryService.aiEnabled ||
          _isGeneratingAssetManagementAiSummary ||
          _assetManagementAiSummaryInFlightKey == key ||
          _assetManagementAiSummaryRequestKey != key) {
        return;
      }
      unawaited(_generateAssetManagementAiSummary(report, requestKey: key));
    });
  }

  String _assetManagementAiSummaryKey(AssetManagementInsightReport report) {
    return _assetManagementAiSummaryService.buildRequestFingerprint(report);
  }

  void _requestExistingDeveloperIssuesIfNeeded(
    List<AssetManagementDeveloperRequest> requests,
  ) {
    if (_supabase.auth.currentUser == null || requests.isEmpty) {
      return;
    }
    final payload = requests
        .map(_developerRequestExistingIssuePayload)
        .toList(growable: false);
    final lookupKey = jsonEncode(payload);
    if (_developerRequestExistingIssueLookupKey == lookupKey) {
      return;
    }
    _developerRequestExistingIssueLookupKey = lookupKey;
    _isCheckingExistingDeveloperRequestIssues = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _developerRequestExistingIssueLookupKey != lookupKey) {
        return;
      }
      unawaited(
        _loadExistingDeveloperIssues(lookupKey: lookupKey, requests: payload),
      );
    });
  }

  Map<String, String> _developerRequestExistingIssuePayload(
    AssetManagementDeveloperRequest request,
  ) {
    return <String, String>{
      'key': _developerRequestIssueKey(request),
      'title': request.title,
      'description': request.description,
    };
  }

  Future<void> _loadExistingDeveloperIssues({
    required String lookupKey,
    required List<Map<String, String>> requests,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'core-hub',
        body: {
          'action': 'feature_request.existing_issues',
          'source': 'asset_management_developer_request',
          'requests': requests,
        },
      );
      if (!mounted || _developerRequestExistingIssueLookupKey != lookupKey) {
        return;
      }
      final rawData = response.data;
      final existingByKey = <String, Map<String, dynamic>>{};
      if (rawData is Map) {
        final existingIssues = rawData['existingIssues'];
        if (existingIssues is List) {
          for (final item in existingIssues) {
            final issue = _assetManagementDynamicMap(item);
            final key = issue['key']?.toString() ?? '';
            if (key.isNotEmpty) {
              existingByKey[key] = issue;
            }
          }
        }
      }
      setState(() {
        _developerRequestExistingIssueResults
          ..clear()
          ..addAll(existingByKey);
        _isCheckingExistingDeveloperRequestIssues = false;
      });
    } catch (_) {
      if (!mounted || _developerRequestExistingIssueLookupKey != lookupKey) {
        return;
      }
      setState(() {
        _developerRequestExistingIssueResults.clear();
        _isCheckingExistingDeveloperRequestIssues = false;
      });
    }
  }

  Future<void> _submitAssetManagementDeveloperIssue(
    AssetManagementDeveloperRequest request,
  ) async {
    if (_supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GitHub Issueの発行にはログインが必要です')),
      );
      return;
    }

    final issueKey = _developerRequestIssueKey(request);
    if (_developerRequestIssueSubmissionKeys.contains(issueKey)) {
      return;
    }

    setState(() {
      _developerRequestIssueSubmissionKeys.add(issueKey);
    });

    try {
      final severityLabel = _assetManagementInsightSeverityLabel(
        request.severity,
      );
      final response = await _supabase.functions.invoke(
        'core-hub',
        body: {
          'action': 'feature_request.submit',
          'title': '[資産管理] ${request.title}',
          'description': _developerRequestIssueDescription(
            request,
            severityLabel,
          ),
          'expected_outcome':
              '資産管理画面の改善提案を開発ワークフローに乗せ、該当運用を画面上で確認・実行・監査できる状態にする。',
          'category': 'UX改善',
          'priority': _developerRequestIssuePriority(request.severity),
          'source': 'asset_management_developer_request',
          'dedupe_key': issueKey,
        },
      );

      final rawData = response.data;
      if (rawData is! Map) {
        throw const FormatException('Invalid feature request response');
      }

      final data = Map<String, dynamic>.from(rawData);
      final success = data['success'] == true;
      final partialSuccess = data['partialSuccess'] == true;
      if (!success && !partialSuccess) {
        throw Exception(data['error'] ?? 'GitHub Issueの発行に失敗しました');
      }

      if (!mounted) return;
      setState(() {
        _developerRequestIssueResults[issueKey] = data;
      });

      final githubIssue = _assetManagementDynamicMap(data['githubIssue']);
      final wbsTask = _assetManagementDynamicMap(data['wbsTask']);
      final issueUrl = githubIssue['html_url']?.toString() ?? '';
      final issueNumber = githubIssue['number']?.toString() ?? '';
      final wbsCreated = wbsTask.isNotEmpty && !wbsTask.containsKey('error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            issueUrl.isEmpty
                ? 'WBSに登録しました。GitHub Issue連携は設定確認が必要です'
                : wbsCreated
                    ? 'GitHub Issue #$issueNumber を発行してWBSに登録しました'
                    : 'GitHub Issue #$issueNumber を発行しました。'
                        'WBS連携は設定確認が必要です',
          ),
          action: issueUrl.isEmpty
              ? null
              : SnackBarAction(
                  label: '開く',
                  onPressed: () => web.window.open(issueUrl, '_blank'),
                ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GitHub Issueの発行に失敗しました: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _developerRequestIssueSubmissionKeys.remove(issueKey);
        });
      }
    }
  }

  String _developerRequestIssueKey(AssetManagementDeveloperRequest request) {
    return '${request.title}\n${request.description}\n${request.severity.name}';
  }

  String _developerRequestIssueDescription(
    AssetManagementDeveloperRequest request,
    String severityLabel,
  ) {
    final buffer = StringBuffer()
      ..writeln(request.description)
      ..writeln()
      ..writeln('発行元: 資産管理画面 > 開発者向け改善提案')
      ..writeln('重要度: $severityLabel')
      ..writeln('画面: /asset-management');
    _appendDeveloperIssueSection(buffer, '根拠データ', request.evidence);
    _appendDeveloperIssueSection(
      buffer,
      '変更候補ファイル',
      request.sourceReferences,
    );
    _appendDeveloperIssueSection(
      buffer,
      '実装手順',
      request.implementationSteps,
    );
    _appendDeveloperIssueSection(
      buffer,
      '受け入れ条件',
      request.acceptanceCriteria,
    );
    return buffer.toString().trim();
  }

  void _appendDeveloperIssueSection(
    StringBuffer buffer,
    String title,
    List<String> items,
  ) {
    if (items.isEmpty) {
      return;
    }
    buffer
      ..writeln()
      ..writeln('## $title');
    for (final item in items) {
      buffer.writeln('- $item');
    }
  }

  String _developerRequestIssuePriority(
    AssetManagementInsightSeverity severity,
  ) {
    return switch (severity) {
      AssetManagementInsightSeverity.critical => 'high',
      AssetManagementInsightSeverity.warning => 'medium',
      AssetManagementInsightSeverity.info => 'low',
    };
  }

  Map<String, dynamic> _assetManagementDynamicMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  Widget _buildAssetManagementAvailableCard(
    AssetManagementAvailableMoneyInsight insight,
  ) {
    final color = insight.availableAmount < 0
        ? const Color(0xFFB91C1C)
        : const Color(0xFF0D9488);
    final subtitle =
        '支払 ${_formatManagementYen(insight.unpaidPaymentTotal)} / 入金 ${_formatManagementYen(insight.unreceivedIncomeTotal)} / 安全残高 ${_formatManagementYen(insight.minimumSafetyBalance)}';

    return Container(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 320),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _assetManagementInsightWindowLabel(insight.window),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _formatManagementYen(insight.availableAmount),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetManagementEmergencyAdviceList(
    List<AssetManagementEmergencyAdvice> advices,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFB91C1C).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: Color(0xFFB91C1C),
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '緊急生活防衛アドバイス',
                  style: TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '水だけで耐えるなど、健康を削る判断はしないでください。支払いより先に、食費・移動費・医療など最低限の生活費を守ります。',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 8),
          for (final advice in advices.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _assetManagementInsightSeverityColor(
                      advice.severity,
                    ).withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advice.title,
                      style: TextStyle(
                        color: _assetManagementInsightSeverityColor(
                          advice.severity,
                        ),
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      advice.description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      advice.suggestedAction,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssetManagementAssistantActionList(
    List<AssetManagementInsightActionItem> actionItems,
  ) {
    if (actionItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF0D9488).withValues(alpha: 0.24),
          ),
        ),
        child: const Text(
          '今日すぐ確認すべき資金繰りアクションはありません。',
          style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'アクションアイテム',
          style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
        ),
        const SizedBox(height: 6),
        for (final item in actionItems.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildAssetManagementAssistantActionTile(item),
          ),
        if (actionItems.length > 8)
          Text(
            'ほか ${actionItems.length - 8}件',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _buildAssetManagementAssistantActionTile(
    AssetManagementInsightActionItem item,
  ) {
    final color = _assetManagementInsightSeverityColor(item.severity);
    final dueLabel = item.dueDate == null
        ? (item.paymentDay == null ? null : '${item.paymentDay}日')
        : DateFormat('M/d').format(item.dueDate!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _assetManagementInsightActionIcon(item.type),
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    _buildAssetLiabilitySyncChip(
                      label: '重要度',
                      value: _assetManagementInsightSeverityLabel(
                        item.severity,
                      ),
                      color: color,
                    ),
                    if (dueLabel != null)
                      _buildAssetLiabilitySyncChip(
                        label: '期日',
                        value: dueLabel,
                        color: const Color(0xFF475569),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.suggestedAction,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetManagementMovementSuggestionList(
    List<AssetManagementMovementSuggestion> suggestions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '口座移動/出金提案',
          style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in suggestions)
              Chip(
                avatar: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                ),
                label: Text(
                  '${suggestion.fromAccountName}から ${_formatManagementYen(suggestion.amount)}'
                  '${suggestion.toAccountName == null ? ' 出金/移動' : ' → ${suggestion.toAccountName}'}',
                ),
                backgroundColor: const Color(0xFFFFF7ED),
                side: const BorderSide(color: Color(0xFFF97316)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssetManagementDeveloperRequestList(
    List<AssetManagementDeveloperRequest> requests,
  ) {
    _requestExistingDeveloperIssuesIfNeeded(requests);
    final visibleRequests = _isCheckingExistingDeveloperRequestIssues
        ? <AssetManagementDeveloperRequest>[]
        : requests
            .where(
              (request) => !_developerRequestExistingIssueResults.containsKey(
                _developerRequestIssueKey(request),
              ),
            )
            .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '開発者向け改善提案',
          style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
        ),
        const SizedBox(height: 6),
        for (final request in visibleRequests.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    request.description,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  if (request.evidence.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildAssetManagementDeveloperRequestSection(
                      title: '根拠',
                      items: request.evidence,
                    ),
                  ],
                  if (request.sourceReferences.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildAssetManagementDeveloperRequestSection(
                      title: '変更候補',
                      items: request.sourceReferences,
                    ),
                  ],
                  if (request.acceptanceCriteria.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildAssetManagementDeveloperRequestSection(
                      title: '受け入れ条件',
                      items: request.acceptanceCriteria,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildAssetManagementDeveloperIssueControls(request),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAssetManagementDeveloperRequestSection({
    required String title,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 3),
        for (final item in items.take(4))
          Text(
            '・$item',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.45,
            ),
          ),
      ],
    );
  }

  Widget _buildAssetManagementDeveloperIssueControls(
    AssetManagementDeveloperRequest request,
  ) {
    final issueKey = _developerRequestIssueKey(request);
    final isSubmitting = _developerRequestIssueSubmissionKeys.contains(
      issueKey,
    );
    final result = _developerRequestIssueResults[issueKey];
    final githubIssue = _assetManagementDynamicMap(result?['githubIssue']);
    final wbsTask = _assetManagementDynamicMap(result?['wbsTask']);
    final issueUrl = githubIssue['html_url']?.toString() ?? '';
    final issueNumber = githubIssue['number']?.toString() ?? '';
    final hasIssue = issueUrl.isNotEmpty;
    final hasWbsTask = wbsTask.isNotEmpty && !wbsTask.containsKey('error');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: isSubmitting || hasIssue
              ? null
              : () => _submitAssetManagementDeveloperIssue(request),
          icon: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  hasIssue ? Icons.check_circle_outline : Icons.add_task,
                  size: 18,
                ),
          label: Text(
            isSubmitting
                ? 'Issue発行中'
                : hasIssue
                    ? 'Issue発行済み'
                    : result == null
                        ? 'GitHub Issue化'
                        : 'Issue再試行',
          ),
        ),
        if (hasIssue)
          TextButton.icon(
            onPressed: () => web.window.open(issueUrl, '_blank'),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text('#$issueNumberを開く'),
          )
        else if (hasWbsTask)
          const Chip(
            avatar: Icon(Icons.playlist_add_check_circle, size: 16),
            label: Text('WBS登録済み'),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  String _assetManagementInsightWindowLabel(
    AssetManagementInsightWindow window,
  ) {
    return switch (window) {
      AssetManagementInsightWindow.today => '本日使用可能額',
      AssetManagementInsightWindow.week => '今週使用可能額',
      AssetManagementInsightWindow.month => '今月使用可能額',
    };
  }

  String _assetManagementInsightSeverityLabel(
    AssetManagementInsightSeverity severity,
  ) {
    return switch (severity) {
      AssetManagementInsightSeverity.info => '確認',
      AssetManagementInsightSeverity.warning => '警戒',
      AssetManagementInsightSeverity.critical => '至急',
    };
  }

  Color _assetManagementInsightSeverityColor(
    AssetManagementInsightSeverity severity,
  ) {
    return switch (severity) {
      AssetManagementInsightSeverity.info => const Color(0xFF2563EB),
      AssetManagementInsightSeverity.warning => const Color(0xFFD97706),
      AssetManagementInsightSeverity.critical => const Color(0xFFB91C1C),
    };
  }

  IconData _assetManagementInsightActionIcon(
    AssetManagementInsightActionType type,
  ) {
    return switch (type) {
      AssetManagementInsightActionType.missingInput => Icons.edit_note_outlined,
      AssetManagementInsightActionType.missingPaymentDay =>
        Icons.event_busy_outlined,
      AssetManagementInsightActionType.missingAnnualRate =>
        Icons.percent_outlined,
      AssetManagementInsightActionType.missingPaymentSource =>
        Icons.account_balance_outlined,
      AssetManagementInsightActionType.overduePayment =>
        Icons.priority_high_rounded,
      AssetManagementInsightActionType.upcomingPayment =>
        Icons.event_available_outlined,
      AssetManagementInsightActionType.cashShortageRisk =>
        Icons.warning_amber_rounded,
      AssetManagementInsightActionType.emergencyLivingExpense =>
        Icons.health_and_safety_outlined,
      AssetManagementInsightActionType.cardBillingConfiguration =>
        Icons.credit_card_off_outlined,
      AssetManagementInsightActionType.doubleCountingRisk =>
        Icons.difference_outlined,
    };
  }

  String _assetLiabilityManualSyncStatusLabel(
    AssetLiabilityManualSyncStatus status,
  ) {
    switch (status) {
      case AssetLiabilityManualSyncStatus.notRun:
        return '未実行';
      case AssetLiabilityManualSyncStatus.disabled:
        return '無効';
      case AssetLiabilityManualSyncStatus.success:
        return '成功';
      case AssetLiabilityManualSyncStatus.failure:
        return '失敗';
      case AssetLiabilityManualSyncStatus.conflict:
        return '競合あり';
    }
  }

  Color _assetLiabilityManualSyncStatusColor(
    AssetLiabilityManualSyncStatus status,
  ) {
    switch (status) {
      case AssetLiabilityManualSyncStatus.notRun:
        return Theme.of(context).colorScheme.outline;
      case AssetLiabilityManualSyncStatus.disabled:
        return Theme.of(context).colorScheme.outline;
      case AssetLiabilityManualSyncStatus.success:
        return const Color(0xFF0D9488);
      case AssetLiabilityManualSyncStatus.failure:
        return const Color(0xFFB91C1C);
      case AssetLiabilityManualSyncStatus.conflict:
        return const Color(0xFFD97706);
    }
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
          const Icon(Icons.info_outline, size: 20, color: Color(0xFFD97706)),
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

  Widget _buildAssetWorkbookCardBillingNotice(AssetLiabilityWorkbook workbook) {
    final labels = workbook.debtMasterRows
        .where((row) => row.includedInBillingAccount)
        .map(
          (row) =>
              '${row.name}: ${row.paymentMethodLabel ?? AssetLiabilityPlanningService.cardBillingIncludedLabel}',
        )
        .join(' / ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.credit_card_outlined,
            size: 20,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${AssetLiabilityPlanningService.cardBillingNotice} $labels',
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

  Widget _buildCardBillingReviewSection(AssetLiabilityWorkbook workbook) {
    final review = workbook.cardBillingReview;
    if (workbook.debtMasterRows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'カード請求内訳レビュー',
                style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '今月の支払い方式を、直接支払い・カード請求内訳・設定確認が必要な項目に分けて確認します。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTextStatusChip(
                label: '直接支払い ${review.directPaymentItems.length}件',
                color: const Color(0xFF0D9488),
              ),
              _buildTextStatusChip(
                label: 'カード請求内訳 ${review.cardBilledItemCount}件',
                color: const Color(0xFF2563EB),
              ),
              _buildTextStatusChip(
                label: '請求先未設定 ${review.missingBillingAccountItems.length}件',
                color: review.hasMissingBillingAccounts
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFF475569),
              ),
              _buildTextStatusChip(
                label: '設定確認 ${review.needsReviewItems.length}件',
                color: review.hasNeedsReviewItems
                    ? const Color(0xFFD97706)
                    : const Color(0xFF475569),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCardBillingReviewRiskNotice(review),
          if (review.hasNeedsReviewItems) ...[
            const SizedBox(height: 8),
            _buildCardBillingReviewAlertList(review.needsReviewItems),
          ],
          const SizedBox(height: 12),
          _buildCardBillingReviewDirectPayments(review.directPaymentItems),
          const SizedBox(height: 12),
          _buildCardBillingReviewGroups(review.cardBillingGroups),
          const SizedBox(height: 12),
          _buildCardStatementReconciliationPanel(workbook),
        ],
      ),
    );
  }

  Widget _buildCardBillingReviewRiskNotice(
    AssetLiabilityCardBillingReviewData review,
  ) {
    final hasRisk = review.hasDoubleCountingRisk;
    final color = hasRisk ? const Color(0xFFB91C1C) : const Color(0xFF0D9488);
    final message = hasRisk
        ? '${AssetLiabilityPlanningService.cardBillingReviewDoubleCountRiskLabel}: '
            '${review.doubleCountingRiskItems.map((item) => item.accountName).join(' / ')}'
        : AssetLiabilityPlanningService.cardBillingReviewNoDoubleCountRiskLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            hasRisk ? Icons.warning_amber_outlined : Icons.verified_outlined,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBillingReviewAlertList(
    List<AssetLiabilityCardBillingReviewItem> items,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '設定確認が必要な項目',
            style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${item.accountName}: ${item.alerts.join(' / ')}',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardBillingReviewDirectPayments(
    List<AssetLiabilityCardBillingReviewItem> items,
  ) {
    return _buildCardBillingReviewItemTable(
      title: '直接支払い',
      items: items,
      emptyMessage: '直接支払いの項目はありません',
    );
  }

  Widget _buildCardBillingReviewGroups(
    List<AssetLiabilityCardBillingGroup> groups,
  ) {
    if (groups.isEmpty) {
      return _buildCardBillingReviewItemTable(
        title: 'カード請求に含める項目',
        items: const <AssetLiabilityCardBillingReviewItem>[],
        emptyMessage: 'カード請求に含める項目はありません',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'カード請求に含める項目',
          style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
        ),
        const SizedBox(height: 8),
        for (final group in groups) ...[
          Row(
            children: [
              const Icon(Icons.credit_card_outlined, size: 16),
              const SizedBox(width: 6),
              Text(
                '${group.billingAccountName} '
                '(${group.items.length}件 / ${_formatManagementYen(group.totalAmount)})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildCardBillingReviewItemTable(
            title: null,
            items: group.items,
            emptyMessage: '',
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildCardBillingReviewItemTable({
    required String? title,
    required List<AssetLiabilityCardBillingReviewItem> items,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, height: 1.4),
          ),
          const SizedBox(height: 6),
        ],
        if (items.isEmpty)
          Text(
            emptyMessage,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 58,
              columns: const [
                DataColumn(label: Text('支払い項目')),
                DataColumn(label: Text('金額'), numeric: true),
                DataColumn(label: Text('支払日'), numeric: true),
                DataColumn(label: Text('支払い方式')),
                DataColumn(label: Text('請求先カード')),
                DataColumn(label: Text('設定元')),
                DataColumn(label: Text('資金繰り')),
                DataColumn(label: Text('確認事項')),
              ],
              rows: [
                for (final item in items)
                  DataRow(
                    cells: [
                      DataCell(Text(item.accountName)),
                      DataCell(Text(_formatManagementYen(item.amount))),
                      DataCell(
                        Text(
                          item.paymentDay == null
                              ? '未設定'
                              : '${item.paymentDay}日',
                        ),
                      ),
                      DataCell(Text(item.paymentMethodLabel)),
                      DataCell(
                        Text(
                          item.billingAccountName ??
                              item.billingAccountId ??
                              'なし',
                        ),
                      ),
                      DataCell(
                        Text(
                          AssetLiabilityPlanningService
                              .paymentMethodSettingSourceLabel(
                            item.paymentMethodSettingSource,
                          ),
                        ),
                      ),
                      DataCell(
                        _buildTextStatusChip(
                          label: item.excludedFromDirectCashflow
                              ? AssetLiabilityPlanningService
                                  .cardBillingReviewExcludedFromDirectCashflowLabel
                              : AssetLiabilityPlanningService
                                  .cardBillingReviewDirectCashflowTargetLabel,
                          color: item.excludedFromDirectCashflow
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF0D9488),
                        ),
                      ),
                      DataCell(
                        Text(
                          item.alerts.isEmpty
                              ? '問題なし'
                              : item.alerts.join(' / '),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCardStatementReconciliationPanel(
    AssetLiabilityWorkbook workbook,
  ) {
    final reconciliation = workbook.cardStatementReconciliation;
    final cardOptions = _cardBillingAccountOptions(workbook);
    final selected = _selectedCardStatementBillingAccountId;
    final validSelected = selected != null &&
        cardOptions.any((account) => account.id == selected);
    final selectedValue = validSelected
        ? selected
        : (cardOptions.isEmpty ? null : cardOptions.first.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                reconciliation.hasNeedsReview
                    ? Icons.warning_amber_outlined
                    : Icons.receipt_long_outlined,
                color: reconciliation.hasNeedsReview
                    ? const Color(0xFFD97706)
                    : const Color(0xFF0D9488),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Card statement import and reconciliation',
                  style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
                ),
              ),
              _buildTextStatusChip(
                label: '${reconciliation.importedLineCount} lines',
                color: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Paste CSV rows as description,amount,date or billing_account_id,description,amount,date. Imported totals are checked against card billing.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButton<String>(
                  value: selectedValue,
                  isExpanded: true,
                  hint: const Text('Billing card'),
                  items: [
                    for (final account in cardOptions)
                      DropdownMenuItem<String>(
                        value: account.id,
                        child: Text(account.name),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCardStatementBillingAccountId = value;
                    });
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: cardOptions.isEmpty
                    ? null
                    : () => _importCardStatementLines(workbook, selectedValue),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Import lines'),
              ),
              OutlinedButton.icon(
                onPressed: selectedValue == null
                    ? null
                    : () => _clearCardStatementLines(selectedValue),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear card lines'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cardStatementImportController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'Netflix,1980,2026-05-10\nMobile plan,5764,2026-05-12',
            ),
          ),
          if (_cardStatementImportMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _cardStatementImportMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _buildCardStatementReconciliationTable(reconciliation),
        ],
      ),
    );
  }

  Widget _buildCardStatementReconciliationTable(
    AssetLiabilityCardStatementReconciliationData reconciliation,
  ) {
    if (reconciliation.groups.isEmpty) {
      return Text(
        'No card-billed details or statement lines to reconcile.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          height: 1.5,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 34,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 64,
        columns: const [
          DataColumn(label: Text('billing card')),
          DataColumn(label: Text('billed amount'), numeric: true),
          DataColumn(label: Text('statement total'), numeric: true),
          DataColumn(label: Text('configured total'), numeric: true),
          DataColumn(label: Text('difference'), numeric: true),
          DataColumn(label: Text('alerts')),
        ],
        rows: [
          for (final group in reconciliation.groups)
            DataRow(
              cells: [
                DataCell(Text(group.billingAccountName)),
                DataCell(Text(_formatManagementYen(group.billedAmount))),
                DataCell(Text(_formatManagementYen(group.statementLineTotal))),
                DataCell(
                  Text(_formatManagementYen(group.configuredDetailTotal)),
                ),
                DataCell(
                  Text(
                    _formatManagementYen(group.statementDifference),
                    style: TextStyle(
                      color: group.needsReview
                          ? const Color(0xFFD97706)
                          : const Color(0xFF0D9488),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  Text(group.alerts.isEmpty ? 'OK' : group.alerts.join(' / ')),
                ),
              ],
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

  Widget _buildAssetPaymentReminderPanel(AssetLiabilityWorkbook workbook) {
    final reminders = _assetLiabilityReminderService.buildCandidates(
      workbook: workbook,
      now: _now,
    );
    if (reminders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFFD97706),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '支払日前リマインダー候補',
                  style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '通知基盤が未設定でも、支払日順資金繰りに沿って前日・当日・期限超過の未払いを確認できます。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          ...reminders.map(_buildAssetPaymentReminderRow),
        ],
      ),
    );
  }

  Widget _buildAssetPaymentReminderRow(
    AssetLiabilityPaymentReminderCandidate reminder,
  ) {
    final row = reminder.cashflowRow;
    final color = _paymentReminderStatusColor(reminder);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('M/d').format(row.paymentDate),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                Text(
                  _paymentReminderStatusLabel(reminder),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                Text(
                  '${reminder.detail} / 支払予定 ${_formatManagementYen(row.paymentAmount)} / 支払後手元 ${_formatManagementYen(row.cashAfterPayment)}',
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

  Color _paymentReminderStatusColor(
    AssetLiabilityPaymentReminderCandidate reminder,
  ) {
    if (reminder.hasShortageRisk ||
        reminder.status == AssetLiabilityPaymentReminderStatus.overdue) {
      return const Color(0xFFB91C1C);
    }
    if (reminder.status == AssetLiabilityPaymentReminderStatus.dueToday) {
      return const Color(0xFFD97706);
    }
    return const Color(0xFF2563EB);
  }

  String _paymentReminderStatusLabel(
    AssetLiabilityPaymentReminderCandidate reminder,
  ) {
    return switch (reminder.status) {
      AssetLiabilityPaymentReminderStatus.overdue => '超過',
      AssetLiabilityPaymentReminderStatus.dueToday => '今日',
      AssetLiabilityPaymentReminderStatus.dueTomorrow => '明日',
    };
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
            style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                  style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
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
                    label: const Text('前サイクルコピー'),
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
                            onChanged: (value) =>
                                _toggleIncomeReceived(plan.id, value ?? false),
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
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
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

  Widget _buildUnassignedIncomeWarning(List<AssetLiabilityIncomePlan> plans) {
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

  Widget _buildRecurringIncomeTemplateList(AssetLiabilityWorkbook workbook) {
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
          style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
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
                      row.isPayment && row.isDirectCashflowTarget
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
                const DropdownMenuItem<String>(value: '', child: Text('未設定')),
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
    if (row.includedInBillingAccount) {
      return _buildTextStatusChip(
        label: AssetLiabilityPlanningService.cardBillingIncludedLabel,
        color: const Color(0xFF2563EB),
      );
    }
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
    if (row.includedInBillingAccount) {
      return _buildTextStatusChip(
        label: AssetLiabilityPlanningService.cardBillingIncludedLabel,
        color: const Color(0xFF2563EB),
      );
    }
    if (row.overdue) {
      return _buildTextStatusChip(
        label: row.isIncome ? '入金遅れ' : '期限超過',
        color: const Color(0xFFB91C1C),
      );
    }
    return _buildCashRiskChip(row.riskLevel);
  }

  String _cashflowKindLabel(AssetLiabilityCashflowRow row) {
    if (row.includedInBillingAccount) {
      return AssetLiabilityPlanningService.cardBillingIncludedLabel;
    }
    if (row.isIncome) {
      return '入金';
    }
    return row.paymentAmountEstimated ? '推定' : '実額';
  }

  Widget _buildTextStatusChip({required String label, required Color color}) {
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
          style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
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
                      Text(_formatManagementYen(summary.currentBalance)),
                    ),
                    DataCell(
                      Text(_formatManagementYen(summary.upcomingPayments)),
                    ),
                    DataCell(
                      Text(_formatManagementYen(summary.upcomingIncome)),
                    ),
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

  Widget _buildMonthlySnapshotChart(AssetLiabilityMonthlyChartData chartData) {
    final theme = Theme.of(context);
    if (!chartData.hasEnoughData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              Icons.show_chart,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'グラフ表示には2か月以上の履歴が必要です',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final allValues = [
      for (final series in chartData.series)
        for (final point in series.points) point.value,
    ];
    final minValue = allValues.reduce(min);
    final maxValue = allValues.reduce(max);
    final valueRange = maxValue - minValue;
    final padding = valueRange == 0
        ? max(maxValue.abs() * 0.1, 10000.0)
        : valueRange * 0.12;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (chartData.monthKeys.length - 1).toDouble(),
                minY: minValue - padding,
                maxY: maxValue + padding,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: value == 0
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.outlineVariant,
                    strokeWidth: value == 0 ? 1.2 : 0.8,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 62,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        space: 8,
                        child: Text(
                          _formatCompactManagementYen(value),
                          style: const TextStyle(fontSize: 10, height: 1.5),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: chartData.monthKeys.length > 8 ? 2 : 1,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if ((value - index).abs() > 0.01 ||
                            index < 0 ||
                            index >= chartData.monthKeys.length) {
                          return const SizedBox.shrink();
                        }
                        final monthKey = chartData.monthKeys[index];
                        final label = monthKey.length >= 7
                            ? monthKey.substring(5)
                            : monthKey;
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 10, height: 1.5),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        if (spot.barIndex < 0 ||
                            spot.barIndex >= chartData.series.length) {
                          return null;
                        }
                        final series = chartData.series[spot.barIndex];
                        final pointIndex = spot.x.round();
                        if (pointIndex < 0 ||
                            pointIndex >= series.points.length) {
                          return null;
                        }
                        final point = series.points[pointIndex];
                        final deltaLabel = point.deltaFromPrevious == null
                            ? ''
                            : '\n前月比 ${_formatManagementDeltaYen(point.deltaFromPrevious)}';
                        final worsenedLabel = point.worsened ? ' 悪化' : '';
                        return LineTooltipItem(
                          '${series.label} ${point.monthKey}\n'
                          '${_formatManagementYen(point.value)}'
                          '$deltaLabel$worsenedLabel',
                          TextStyle(
                            color: _monthlyChartSeriesColor(series.metric),
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                lineBarsData: [
                  for (final series in chartData.series)
                    LineChartBarData(
                      spots: [
                        for (var index = 0;
                            index < series.points.length;
                            index++)
                          FlSpot(index.toDouble(), series.points[index].value),
                      ],
                      isCurved: false,
                      color: _monthlyChartSeriesColor(series.metric),
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final point =
                              index >= 0 && index < series.points.length
                                  ? series.points[index]
                                  : null;
                          final worsened = point?.worsened ?? false;
                          final color = worsened
                              ? const Color(0xFFB91C1C)
                              : _monthlyChartSeriesColor(series.metric);
                          return FlDotCirclePainter(
                            radius: worsened ? 5 : 3,
                            color: color,
                            strokeWidth: 2,
                            strokeColor: theme.colorScheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final series in chartData.series)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _monthlyChartSeriesColor(series.metric),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      series.label,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMonthlySnapshotDeteriorationSummary(chartData),
        ],
      ),
    );
  }

  Widget _buildMonthlySnapshotDeteriorationSummary(
    AssetLiabilityMonthlyChartData chartData,
  ) {
    final theme = Theme.of(context);
    final worsenedLabels = <String>[];
    for (final series in chartData.series) {
      for (final point in series.points) {
        if (point.worsened) {
          worsenedLabels.add(
            '${point.monthKey} ${series.label} '
            '${_formatManagementDeltaYen(point.deltaFromPrevious)}',
          );
        }
      }
    }

    if (worsenedLabels.isEmpty) {
      return Text(
        '前月比が悪化している月はありません。',
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 12,
          height: 1.5,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '悪化月',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        for (final label in worsenedLabels.take(8))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        if (worsenedLabels.length > 8)
          Text(
            '+${worsenedLabels.length - 8}件',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
      ],
    );
  }

  Color _monthlyChartSeriesColor(AssetLiabilityMonthlyChartMetric metric) {
    switch (metric) {
      case AssetLiabilityMonthlyChartMetric.positiveAssetTotal:
        return const Color(0xFF0D9488);
      case AssetLiabilityMonthlyChartMetric.liabilityTotal:
        return const Color(0xFFB91C1C);
      case AssetLiabilityMonthlyChartMetric.netWorth:
        return const Color(0xFF4F46E5);
      case AssetLiabilityMonthlyChartMetric.cashLikeTotal:
        return const Color(0xFFD97706);
    }
  }

  Widget _buildAssetCsvRestorePanel() {
    final preview = _assetCsvRestorePreview;
    final theme = Theme.of(context);
    final message = _assetCsvRestoreMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        const Text(
          'CSV restore',
          style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _assetCsvRestoreController,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Exported CSV',
            hintText: 'month_key,...',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _previewAssetLiabilityCsvRestore,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Preview'),
            ),
            FilledButton.icon(
              onPressed: preview != null &&
                      preview.hasRestorableRows &&
                      !_isApplyingAssetCsvRestore
                  ? _applyAssetLiabilityCsvRestore
                  : null,
              icon: _isApplyingAssetCsvRestore
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore_outlined),
              label: const Text('Apply append-only'),
            ),
            if (message != null)
              Text(
                message,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
          ],
        ),
        if (preview != null) ...[
          const SizedBox(height: 8),
          Text(
            _assetCsvRestorePreviewMessage(preview),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (preview.rejectedRows.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              preview.rejectedRows
                  .take(3)
                  .map((row) => 'row ${row.rowNumber}: ${row.reason}')
                  .join('\n'),
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildMonthlySnapshotSection(AssetLiabilityWorkbook workbook) {
    final comparisons = _assetLiabilityHistoryService.compareSnapshots(
      _monthlySnapshots,
    );
    final chartData = _assetLiabilityHistoryService.buildMonthlyChartData(
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
                  style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
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
          _buildAssetCsvRestorePanel(),
          const SizedBox(height: 12),
          _buildMonthlySnapshotChart(chartData),
          const SizedBox(height: 12),
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
                  DataColumn(label: Text('actual paid'), numeric: true),
                  DataColumn(label: Text('planned/actual diff'), numeric: true),
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
                            _formatManagementYen(comparison.snapshot.netWorth),
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
                          Text(
                            _formatManagementYen(
                              comparison.snapshot.monthlyActualPaymentTotal,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatManagementYen(
                              comparison.snapshot.monthlyPaymentDifferenceTotal,
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

  Widget _buildMonthlyReportSection() {
    final theme = Theme.of(context);
    final reportViews = _assetLiabilityMonthlyReportService.buildReportViews(
      snapshots: _monthlySnapshots,
      reports: _monthlyReports,
    );
    AssetLiabilityMonthlyReportView? selectedReport;
    for (final view in reportViews) {
      if (view.monthKey == _selectedMonthlyReportMonthKey) {
        selectedReport = view;
        break;
      }
    }
    selectedReport ??= reportViews.isEmpty ? null : reportViews.first;
    final selectedIndex = selectedReport == null
        ? -1
        : reportViews.indexWhere(
            (view) => view.monthKey == selectedReport!.monthKey,
          );

    return Container(
      key: const Key('asset_monthly_report_section'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize_outlined, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Monthly asset reports',
                  style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
                ),
              ),
              IconButton(
                tooltip: 'Refresh monthly reports',
                onPressed: _isRefreshingMonthlyReports
                    ? null
                    : _refreshMonthlyAssetReports,
                icon: _isRefreshingMonthlyReports
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'AI summaries are read-only; KPI values come from deterministic monthly snapshots.',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (_monthlyReportMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _monthlyReportMessage!,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (reportViews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                'No monthly reports yet. Save a monthly snapshot or run the month-end report job first.',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = _isCompact || constraints.maxWidth < 760;
                final monthList = Column(
                  key: const Key('asset_monthly_report_list'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final view in reportViews)
                      _buildMonthlyReportMonthTile(
                        view: view,
                        selected: view.monthKey == selectedReport!.monthKey,
                      ),
                  ],
                );
                final detail = _buildMonthlyReportDetail(
                  selectedReport!,
                  selectedIndex: selectedIndex,
                  reportViews: reportViews,
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [monthList, const SizedBox(height: 12), detail],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 220, child: monthList),
                    const SizedBox(width: 12),
                    Expanded(child: detail),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyReportMonthTile({
    required AssetLiabilityMonthlyReportView view,
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final color =
        selected ? const Color(0xFF0D9488) : theme.colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: Key('asset_monthly_report_item_${view.monthKey}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _selectedMonthlyReportMonthKey = view.monthKey;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                selected ? const Color(0xFFECFDF5) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                view.monthKey,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? const Color(0xFF0F766E) : null,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                view.hasAiReport ? 'AI要約' : 'ローカルスナップショット',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyReportDetail(
    AssetLiabilityMonthlyReportView report, {
    required int selectedIndex,
    required List<AssetLiabilityMonthlyReportView> reportViews,
  }) {
    final theme = Theme.of(context);
    final canSelectNewer = selectedIndex > 0;
    final canSelectOlder =
        selectedIndex >= 0 && selectedIndex < reportViews.length - 1;
    return Container(
      key: const Key('asset_monthly_report_detail'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.monthKey,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
              IconButton(
                tooltip: '新しい月',
                onPressed: canSelectNewer
                    ? () => _selectMonthlyReportAt(
                          reportViews[selectedIndex - 1].monthKey,
                        )
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: '古い月',
                onPressed: canSelectOlder
                    ? () => _selectMonthlyReportAt(
                          reportViews[selectedIndex + 1].monthKey,
                        )
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMonthlyReportStatTile(
                label: '資産',
                value: _formatManagementYen(report.totalAssets),
                color: const Color(0xFF0D9488),
              ),
              _buildMonthlyReportStatTile(
                label: '負債',
                value: _formatManagementYen(report.totalLiabilities),
                color: const Color(0xFFB91C1C),
              ),
              _buildMonthlyReportStatTile(
                label: '純資産',
                value: _formatManagementYen(report.netWorth),
                color: report.netWorth < 0
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFF0D9488),
              ),
              _buildMonthlyReportStatTile(
                label: '前月比',
                value: _formatManagementDeltaYen(report.netWorthDelta),
                color: const Color(0xFF4F46E5),
              ),
              _buildMonthlyReportStatTile(
                label: '現金性資産',
                value: _formatManagementYen(report.cashLikeTotal),
                color: const Color(0xFF0891B2),
              ),
              _buildMonthlyReportStatTile(
                label: '支払予定',
                value: _formatManagementYen(
                  report.monthlyScheduledPaymentTotal,
                ),
                color: const Color(0xFF7C3AED),
              ),
              _buildMonthlyReportStatTile(
                label: '実支払',
                value: _formatManagementYen(report.monthlyActualPaymentTotal),
                color: const Color(0xFF2563EB),
              ),
              _buildMonthlyReportStatTile(
                label: '予定/実績差',
                value: _formatManagementYen(
                  report.monthlyPaymentDifferenceTotal,
                ),
                color: const Color(0xFFD97706),
              ),
              _buildMonthlyReportStatTile(
                label: '期限超過',
                value: '${report.overduePaymentCount}',
                color: const Color(0xFFB91C1C),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: report.hasAiReport
                  ? const Color(0xFFEEF2FF)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: report.hasAiReport
                    ? const Color(0xFFC7D2FE)
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.hasAiReport ? 'AI要約' : 'ルールベース要約',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  report.summary,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${report.aiModel} / ${_formatMonthlyReportGeneratedAt(report.generatedAt)}',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyReportStatTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _selectMonthlyReportAt(String monthKey) {
    setState(() {
      _selectedMonthlyReportMonthKey = monthKey;
    });
  }

  String _formatMonthlyReportGeneratedAt(DateTime? value) {
    if (value == null) {
      return 'not generated';
    }
    return DateFormat('yyyy/MM/dd HH:mm').format(value.toLocal());
  }

  Widget _buildTransferSuggestionSection(AssetLiabilityWorkbook workbook) {
    if (workbook.transferSuggestions.isEmpty &&
        workbook.transferTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeTasks = workbook.transferTasks
        .where((task) => !task.completed)
        .toList(growable: false)
      ..sort(_compareTransferTasksByDueDate);
    final completedTasks = workbook.transferTasks
        .where((task) => task.completed)
        .toList(growable: false)
      ..sort(_compareTransferTasksByDueDate);

    Widget buildTaskRow(AssetLiabilityTransferTask task) {
      final isBuiltIn = _isBuiltInTransferTask(task);
      final dueLabel = task.dueDate == null
          ? 'No due date'
          : DateFormat('M/d').format(task.dueDate!);
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.completed,
              onChanged: (value) =>
                  _toggleTransferTaskCompleted(task, value ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${task.fromAccountName} -> ${task.toAccountName} / '
                  '${_formatManagementYen(task.amount)} / $dueLabel',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    decoration:
                        task.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: isBuiltIn ? '定例振替' : '振替タスクを削除',
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: isBuiltIn ? null : () => _deleteTransferTask(task.id),
            ),
          ],
        ),
      );
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
            style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
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
          Text(
            'Pending transfer tasks are included in account-level projected '
            'balances. Completed tasks are treated as already reflected in '
            'the current balance, so they are not counted twice.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (activeTasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Open transfer tasks',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            for (final task in activeTasks) buildTaskRow(task),
          ],
          if (completedTasks.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Completed transfer tasks',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            for (final task in completedTasks) buildTaskRow(task),
          ],
          if (workbook.transferSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Suggestions',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 4),
          ],
          for (final suggestion in workbook.transferSuggestions)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.add_task, size: 16),
                label: Text(
                  'Create task: ${suggestion.fromAccountName} -> '
                  '${suggestion.toAccountName}',
                ),
                onPressed: () => _createTransferTaskFromSuggestion(suggestion),
              ),
            ),
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

    final rows = List<AssetLiabilityDebtRow>.from(workbook.debtMasterRows)
      ..sort(_compareDebtRowsByPaymentDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '負債マスタ（残高順）',
          style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
        ),
        const SizedBox(height: 8),
        const Text(
          '支払日順で表示しています。',
          style: TextStyle(fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 4),
        Text(
          '画面に収まらない場合は、表を横にスクロールして支払済み・年利・月利息まで確認できます。支払済みチェックは給料日25日基準のサイクルで保存されます。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Scrollbar(
          controller: _debtMasterHorizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _debtMasterHorizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 64,
              dataRowMaxHeight: 96,
              columns: const [
                DataColumn(label: Text('actual payment'), numeric: true),
                DataColumn(label: Text('difference'), numeric: true),
                DataColumn(label: Text('difference reason')),
                DataColumn(
                  label: Text('\u8a2d\u5b9a\u5143/\u4fdd\u5b58\u5148'),
                ),
                DataColumn(label: Text('支払い方式')),
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
                      DataCell(_buildActualPaymentInput(row)),
                      DataCell(_buildPaymentDifferenceCell(row)),
                      DataCell(_buildPaymentDifferenceReasonInput(row)),
                      DataCell(_buildPaymentMethodScopeControl(row)),
                      DataCell(_buildPaymentMethodDropdown(row, workbook)),
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
                      DataCell(_buildAnnualRateInputWithEvidence(row)),
                      DataCell(
                        Text(_formatManagementYen(row.monthlyInterestEstimate)),
                      ),
                      DataCell(
                        Text(_formatManagementPercent(row.liabilityShare)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _compareDebtRowsByPaymentDay(
    AssetLiabilityDebtRow a,
    AssetLiabilityDebtRow b,
  ) {
    final dayA = a.paymentDay ?? 99;
    final dayB = b.paymentDay ?? 99;
    final day = dayA.compareTo(dayB);
    if (day != 0) {
      return day;
    }
    final balance = b.balance.abs().compareTo(a.balance.abs());
    if (balance != 0) {
      return balance;
    }
    return a.name.compareTo(b.name);
  }

  Widget _buildPaymentMethodDropdown(
    AssetLiabilityDebtRow row,
    AssetLiabilityWorkbook workbook,
  ) {
    final cardOptions = _cardBillingAccountOptions(
      workbook,
    ).where((account) => account.id != row.id).toList(growable: false);
    final configured = _cardBillingAccountIds[row.id];
    final selected = configured ??
        (row.paymentMethod == AssetLiabilityPaymentMethod.includedInCard
            ? row.billingAccountId
            : AssetLiabilityPlanningService.directPaymentMethodId);
    final validSelected =
        selected == AssetLiabilityPlanningService.directPaymentMethodId ||
            cardOptions.any((account) => account.id == selected);

    return SizedBox(
      width: 220,
      child: DropdownButton<String>(
        value: validSelected
            ? selected
            : AssetLiabilityPlanningService.directPaymentMethodId,
        isExpanded: true,
        items: [
          const DropdownMenuItem<String>(
            value: AssetLiabilityPlanningService.directPaymentMethodId,
            child: Text(AssetLiabilityPlanningService.directPaymentLabel),
          ),
          for (final account in cardOptions)
            DropdownMenuItem<String>(
              value: account.id,
              child: Text('${account.name}請求に含む'),
            ),
        ],
        onChanged: (value) => _updateCardBillingAccount(row, value),
      ),
    );
  }

  Widget _buildPaymentMethodScopeControl(AssetLiabilityDebtRow row) {
    final selectedScope = _cardBillingSaveScopeFor(row);
    final sourceLabel =
        AssetLiabilityPlanningService.paymentMethodSettingSourceLabel(
      row.paymentMethodSettingSource,
    );

    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextStatusChip(
            label: sourceLabel,
            color: row.paymentMethodSettingSource ==
                    AssetLiabilityPaymentMethodSettingSource.monthlyOverride
                ? const Color(0xFF7C3AED)
                : const Color(0xFF475569),
          ),
          const SizedBox(height: 4),
          DropdownButton<_CardBillingSaveScope>(
            value: selectedScope,
            isExpanded: true,
            items: const [
              DropdownMenuItem<_CardBillingSaveScope>(
                value: _CardBillingSaveScope.defaultSetting,
                child: Text(
                  AssetLiabilityPlanningService.saveAsDefaultPaymentMethodLabel,
                ),
              ),
              DropdownMenuItem<_CardBillingSaveScope>(
                value: _CardBillingSaveScope.monthlyOverride,
                child: Text(
                  AssetLiabilityPlanningService.saveAsMonthlyPaymentMethodLabel,
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              _updateCardBillingSaveScope(row.id, value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyPaymentInput(AssetLiabilityDebtRow row) {
    final controller = _monthlyPaymentControllerFor(row);
    return SizedBox(
      width: 150,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
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

  Widget _buildActualPaymentInput(AssetLiabilityDebtRow row) {
    if (row.includedInBillingAccount) {
      return _buildTextStatusChip(
        label: AssetLiabilityPlanningService.cardBillingIncludedLabel,
        color: const Color(0xFF2563EB),
      );
    }
    final controller = _actualPaymentControllerFor(row);
    return SizedBox(
      width: 140,
      child: TextField(
        controller: controller,
        enabled: row.paid,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
        onChanged: (value) => _updateActualPaymentAmount(row.id, value),
        decoration: InputDecoration(
          isDense: true,
          hintText: row.paid
              ? _formatManagementYen(row.scheduledPaymentAmount)
              : 'paid only',
        ),
      ),
    );
  }

  Widget _buildPaymentDifferenceCell(AssetLiabilityDebtRow row) {
    if (row.includedInBillingAccount) {
      return const Text('-');
    }
    final difference = row.paymentDifferenceAmount;
    if (difference == null) {
      return Text(
        row.paid ? _formatManagementYen(0) : '-',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      );
    }
    final color = difference == 0
        ? const Color(0xFF64748B)
        : difference > 0
            ? const Color(0xFFDC2626)
            : const Color(0xFF0D9488);
    final prefix = difference > 0 ? '+' : '';
    return Text(
      '$prefix${_formatManagementYen(difference)}',
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
    );
  }

  Widget _buildPaymentDifferenceReasonInput(AssetLiabilityDebtRow row) {
    if (row.includedInBillingAccount) {
      return const Text('-');
    }
    final controller = _paymentDifferenceReasonControllerFor(row);
    return SizedBox(
      width: 190,
      child: TextField(
        controller: controller,
        enabled: row.paid,
        onChanged: (value) => _updatePaymentDifferenceReason(row.id, value),
        decoration: const InputDecoration(isDense: true, hintText: 'reason'),
      ),
    );
  }

  Widget _buildPaymentAmountSourceChip(AssetLiabilityDebtRow row) {
    if (row.includedInBillingAccount) {
      return _buildTextStatusChip(
        label: row.paymentMethodLabel ??
            AssetLiabilityPlanningService.cardBillingIncludedLabel,
        color: const Color(0xFF2563EB),
      );
    }
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
    if (row.includedInBillingAccount) {
      return _buildTextStatusChip(
        label: AssetLiabilityPlanningService.cardBillingIncludedLabel,
        color: const Color(0xFF2563EB),
      );
    }
    return Checkbox(
      value: row.paid,
      onChanged: (value) {
        unawaited(_toggleMonthlyPaymentPaid(row, value ?? false));
      },
    );
  }

  Widget _buildAnnualRateInputWithEvidence(AssetLiabilityDebtRow row) {
    final controller = _annualRateControllerFor(row);
    final hasOverride = _annualRateOverrides.containsKey(row.id);
    final evidence = _annualRateEvidences[row.id];
    final verified = evidence?.matchesAnnualRate(row.annualRate) ?? false;
    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,%]')),
            ],
            onChanged: (value) => _updateAnnualRateOverride(row.id, value),
            decoration: InputDecoration(
              isDense: true,
              hintText: _formatRateInput(row.annualRate),
              helperText:
                  hasOverride ? (verified ? 'AI確認済み' : '証跡確認が必要') : '年利変更は証跡必須',
              suffixText: '%',
              suffixIcon: hasOverride
                  ? IconButton(
                      tooltip: '年利上書きをクリア',
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => _clearAnnualRateOverride(row.id),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          _buildAnnualRateEvidenceCell(row),
        ],
      ),
    );
  }

  Widget _buildAnnualRateEvidenceCell(AssetLiabilityDebtRow row) {
    final evidence = _annualRateEvidences[row.id];
    final isVerifying = _verifyingAnnualRateEvidenceAccountIds.contains(row.id);
    final isPasteTarget = _annualRateEvidencePasteTargetRow?.id == row.id;
    final requestedRate =
        _parseAnnualRateInput(_annualRateControllerFor(row).text) ??
            row.annualRate;
    final verified = evidence?.matchesAnnualRate(requestedRate) ?? false;
    final color = verified
        ? const Color(0xFF0D9488)
        : evidence == null
            ? const Color(0xFFDC2626)
            : const Color(0xFFD97706);
    final label = verified
        ? 'AI証跡OK'
        : evidence == null
            ? '証跡提出'
            : '再提出';
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: isVerifying ? null : () => _submitAnnualRateEvidence(row),
          icon: isVerifying
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file, size: 14),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            visualDensity: VisualDensity.compact,
          ),
        ),
        OutlinedButton.icon(
          onPressed:
              isVerifying ? null : () => _startAnnualRateEvidencePaste(row),
          icon: const Icon(Icons.content_paste, size: 14),
          label: const Text('貼付'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isPasteTarget ? const Color(0xFF2563EB) : color,
            side: BorderSide(
              color: (isPasteTarget ? const Color(0xFF2563EB) : color)
                  .withValues(alpha: 0.5),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
        if (isPasteTarget)
          _buildTextStatusChip(
            label: 'Ctrl+V待ち',
            color: const Color(0xFF2563EB),
          ),
        if (evidence != null)
          Tooltip(
            message: evidence.summary.isEmpty
                ? evidence.fileName
                : '${evidence.fileName}\n${evidence.summary}',
            child: _buildTextStatusChip(
              label: verified ? '確認済' : '要確認',
              color: color,
            ),
          ),
      ],
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
            style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
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

  Widget _buildAssetRepaymentSimulationPanel(AssetLiabilityWorkbook workbook) {
    final extraMonthlyPayment = _parseRepaymentSimulationExtraPayment();
    final simulation =
        _assetLiabilityRepaymentSimulationService.buildComparison(
      workbook: workbook,
      extraMonthlyPayment: extraMonthlyPayment,
    );
    if (!simulation.hasEligibleDebt || simulation.plans.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedPlan = simulation.planFor(_repaymentSimulationStrategy) ??
        simulation.plans.first;
    final baselinePlan = simulation.baselinePlanFor(
      _repaymentSimulationStrategy,
    );
    final firstMonth = selectedPlan.monthSnapshots.isEmpty
        ? null
        : selectedPlan.monthSnapshots.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_outlined, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Repayment simulator',
                  style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Compare payoff timing by interest rate, smallest balance, or payment day. Uses direct unpaid liabilities only, so card-billed detail rows are not double counted.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 190,
                child: TextField(
                  controller: _repaymentSimulationExtraPaymentController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Extra / month',
                    prefixText: '¥',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              for (final strategy
                  in AssetLiabilityRepaymentSimulationStrategy.values)
                ChoiceChip(
                  selected: _repaymentSimulationStrategy == strategy,
                  label: Text(_repaymentSimulationStrategyLabel(strategy)),
                  onSelected: (_) {
                    setState(() {
                      _repaymentSimulationStrategy = strategy;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRepaymentSimulationMetric(
                label: 'Monthly budget',
                value: _formatManagementYen(selectedPlan.monthlyPaymentBudget),
              ),
              _buildRepaymentSimulationMetric(
                label: 'Payoff timing',
                value: _formatRepaymentSimulationMonths(
                  selectedPlan.estimatedPayoffMonths,
                ),
              ),
              _buildRepaymentSimulationMetric(
                label: 'Change vs base',
                value: _formatRepaymentSimulationDelta(
                  selectedPlan: selectedPlan,
                  baselinePlan: baselinePlan,
                ),
              ),
              _buildRepaymentSimulationMetric(
                label: 'Interest estimate',
                value: _formatManagementYen(
                  selectedPlan.estimatedInterestTotal,
                ),
              ),
            ],
          ),
          if (firstMonth != null) ...[
            const SizedBox(height: 10),
            Text(
              'Month 1 focus: ${firstMonth.focusDebtName ?? '-'} / payment ${_formatManagementYen(firstMonth.paymentTotal)} / interest ${_formatManagementYen(firstMonth.interestTotal)} / remaining ${_formatManagementYen(firstMonth.remainingDebt)}',
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
          const SizedBox(height: 10),
          for (final entry
              in selectedPlan.priorityRows.take(4).toList().asMap().entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key + 1}.',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${entry.value.name} / ${_formatManagementYen(entry.value.balance)} / APR ${_formatManagementPercent(entry.value.annualRate)} / day ${entry.value.paymentDay ?? '-'} / monthly ${_formatManagementYen(entry.value.monthlyPayment)}',
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          if (selectedPlan.warnings.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              selectedPlan.warnings.join(' / '),
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepaymentSimulationMetric({
    required String label,
    required String value,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, height: 1.3),
          ),
        ],
      ),
    );
  }

  double _parseRepaymentSimulationExtraPayment() {
    final normalized = _repaymentSimulationExtraPaymentController.text
        .replaceAll(',', '')
        .trim();
    return max(0.0, double.tryParse(normalized) ?? 0);
  }

  String _repaymentSimulationStrategyLabel(
    AssetLiabilityRepaymentSimulationStrategy strategy,
  ) {
    switch (strategy) {
      case AssetLiabilityRepaymentSimulationStrategy.interestRate:
        return 'APR';
      case AssetLiabilityRepaymentSimulationStrategy.smallestBalance:
        return 'Smallest';
      case AssetLiabilityRepaymentSimulationStrategy.paymentDay:
        return 'Payment day';
    }
  }

  String _formatRepaymentSimulationMonths(int? months) {
    if (months == null) return 'over 360 mo';
    if (months == 0) return '0 mo';
    return '$months mo';
  }

  String _formatRepaymentSimulationDelta({
    required AssetLiabilityRepaymentSimulationPlan selectedPlan,
    required AssetLiabilityRepaymentSimulationPlan? baselinePlan,
  }) {
    final current = selectedPlan.estimatedPayoffMonths;
    final baseline = baselinePlan?.estimatedPayoffMonths;
    if (current == null && baseline == null) return 'no payoff';
    if (current == null) return 'worse';
    if (baseline == null) return 'now payable';
    final delta = current - baseline;
    if (delta == 0) return 'same';
    if (delta < 0) return '$delta mo';
    return '+$delta mo';
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

  String _formatCompactManagementYen(num value) {
    final sign = value < 0 ? '-' : '';
    final absolute = value.abs();
    if (absolute >= 100000000) {
      return '$sign¥${(absolute / 100000000).toStringAsFixed(1)}億';
    }
    if (absolute >= 10000) {
      return '$sign¥${(absolute / 10000).toStringAsFixed(0)}万';
    }
    return '$sign¥${NumberFormat('#,###').format(absolute.round())}';
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
                Icon(Icons.account_balance, color: Color(0xFF0D9488)),
                SizedBox(width: 8),
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
                      : const Icon(
                          Icons.cloud_download,
                          color: Color(0xFF0D9488),
                        ),
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
                      : const Icon(
                          Icons.cloud_download,
                          color: Color(0xFFea580c),
                        ),
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
                            icon: const Icon(
                              Icons.history_toggle_off,
                              size: 16,
                            ),
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
                style: TextStyle(fontSize: 12, height: 1.5),
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
                        style: const TextStyle(fontSize: 12, height: 1.5),
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
              const Text(
                '純資産:',
                style: TextStyle(fontWeight: FontWeight.bold, height: 1.5),
              ),
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    items: ['支出', '収入']
                        .map(
                          (String val) => DropdownMenuItem(
                            value: val,
                            child: Text(
                              val,
                              style: const TextStyle(fontSize: 13, height: 1.6),
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('MM/dd').format(_selectedFlowDate)),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                  color: const Color(0xFF475569).withValues(alpha: 0.12),
                ),
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    items: _sourceOptions
                        .map(
                          (String source) => DropdownMenuItem(
                            value: source,
                            child: Text(
                              source.replaceAll('[', '').replaceAll(']', ''),
                              style: const TextStyle(fontSize: 13, height: 1.6),
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
                        style: const TextStyle(fontSize: 10, height: 1.5),
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
                        style: const TextStyle(fontSize: 10, height: 1.5),
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
                      const Text(
                        '収支差額',
                        style: TextStyle(fontSize: 10, height: 1.5),
                      ),
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
                        title: Text(
                          desc,
                          style: const TextStyle(fontSize: 13, height: 1.6),
                        ),
                        subtitle: Text(
                          '${DateFormat('MM/dd').format(date)} ・ タップで編集',
                          style: const TextStyle(fontSize: 11, height: 1.5),
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    items: _flowTypeOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(fontSize: 13, height: 1.6),
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('MM/dd').format(_selectedFlowDate)),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                  color: const Color(0xFF475569).withValues(alpha: 0.12),
                ),
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
                              style: const TextStyle(fontSize: 13, height: 1.6),
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
                        style: const TextStyle(fontSize: 10, height: 1.5),
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
                        style: const TextStyle(fontSize: 10, height: 1.5),
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
                      const Text(
                        '収支差額',
                        style: TextStyle(fontSize: 10, height: 1.5),
                      ),
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
                  if (_isAutoAssetDeltaFlow(item)) {
                    subtitleParts.add('残高差分から自動記録');
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
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                    subtitle: Text(
                      subtitleParts.join(' ・ '),
                      style: const TextStyle(fontSize: 11, height: 1.5),
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
    final visibleMonthLabel = _flowMonthLabel(
      _selectedSubscriptionHistoryMonth,
    );
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
                  color: const Color(0xFFB91C1C).withValues(alpha: 0.12),
                ),
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
                      child:
                          Center(child: Text('$visibleMonthLabel の固定費はありません')),
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
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
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
                foregroundColor: const Color(0xFF991B1B),
              ),
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
                          final deadline = DateTime.parse(
                            task['deadline'],
                          ).toLocal();
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
                foregroundColor: const Color(0xFF64748B),
              ),
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
                  const Text('個別', style: TextStyle(fontSize: 10, height: 1.5)),
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
                  const Text('合計', style: TextStyle(fontSize: 10, height: 1.5)),
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
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
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
              final val = NumberFormat.simpleCurrency(
                locale: 'ja_JP',
                decimalDigits: 0,
              ).format(rod.toY);
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
                strokeWidth: 1,
              );
            }
            return FlLine(
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeWidth: 1,
            );
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
    const style = TextStyle(fontSize: 10, height: 1.5);
    String text = '';
    if (value.toInt() < _sortedDates.length) {
      text = DateFormat(
        'MM/dd',
      ).format(DateTime.parse(_sortedDates[value.toInt()]));
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
      child: Text(
        format.format(value),
        style: const TextStyle(fontSize: 10, height: 1.5),
      ),
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
    final formattedTotal = NumberFormat.simpleCurrency(
      locale: 'ja_JP',
    ).format(total);
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
      final formattedValue = NumberFormat.simpleCurrency(
        locale: 'ja_JP',
      ).format(entry.value);
      tooltips.add(
        LineTooltipItem(
          '${entry.key}: $formattedValue',
          TextStyle(color: color, fontWeight: FontWeight.bold, height: 1.5),
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
