// home_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Services
import '../services/ai_service.dart';
import '../services/abstinence_guard_store.dart';
import '../services/completion_goal_service.dart';
import '../services/feature_strategy_monitor_service.dart';
import '../services/home_tool_usage_service.dart';
import '../services/personality_test_service.dart';
import '../services/theme_service.dart';
import '../services/waste_tracking_service.dart';
import '../models/feature_strategy_monitor.dart';
import '../models/kgi_csf_kpi.dart';

// Pages
import 'notifications_page.dart';
import 'abstinence_guard_page.dart';
import 'emergency_meeting_page.dart';
import 'landing_page.dart';
import 'admin_analytics_page.dart';
import 'cfo_office_page.dart';
import 'asset_management_page.dart';
import 'morning_briefing_page.dart';
import 'election_strategy_page.dart';
import 'election_victory_page.dart';
import 'settings_page.dart';
import 'stock_tasks_page.dart';
import 'mindless_task_page.dart';
import '../widgets/collapsible_home_section.dart';
import '../widgets/growth_roadmap_progress_card.dart';
import '../widgets/time_waste_guard_widget.dart';
import '../widgets/welcome_new_user_card.dart';
import '../widgets/profile_completion_banner.dart';
import '../widgets/profile_progress_card.dart';
import '../widgets/development_achievements_card.dart';
import '../widgets/edge_function_summary_card.dart';
import '../widgets/ai_university_home_card.dart';
import '../widgets/api_key_status_banner.dart';
import '../widgets/feature_strategy_monitor_panel.dart';
import '../widgets/kgi_csf_kpi_panel.dart';
import '../widgets/referral_share_card.dart';
import '../widgets/thought_interrupt_quick_widget.dart';
import 'ai_secretary_page.dart';
import 'work_menu_page.dart';
import '../data/home_tool_catalog.dart';
import 'profile_settings_page.dart';
import '../widgets/home_tier/recent_features_list.dart';
import '../widgets/home_tier/system_fixed_features_list.dart';
import '../widgets/home_tier/user_pinned_features_list.dart';
import '../widgets/home_tier/new_features_list.dart';
import '../widgets/home_tier/ai_recommended_features_list.dart';
import '../utils/feature_tap_logger.dart';

class HomePage extends StatefulWidget {
  final DateTime Function()? nowProvider;

  const HomePage({super.key, this.nowProvider});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ✅ 改善ポイント:
  // build() のたびに _fetchTotalAssets() が走るのを防ぐため Future をキャッシュする
  late Future<String> _totalAssetsFuture;
  late Future<_HomeOpsSnapshot> _opsSnapshotFuture;
  late Future<_HomeKpiOverview> _kpiOverviewFuture;
  late Future<_HomeMarketingKpiSummary> _marketingKpiFuture;
  late Future<String?> _aiNudgeFuture;
  late Future<List<String>> _recentToolIdsFuture;
  late Future<FeatureStrategyReport> _featureStrategyReportFuture;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Gemini 429 対策: グローバル排他ロック + 最小呼び出し間隔 (60秒)
  static bool _nudgeCallInProgress = false;
  static DateTime? _lastNudgeCallTime;
  _CalendarHighlightFilter _calendarHighlightFilter =
      _CalendarHighlightFilter.all;
  _KpiTrendRange _kpiTrendRange = _KpiTrendRange.oneMonth;
  _CalendarTaskPreviewFilter _calendarTaskPreviewFilter =
      _CalendarTaskPreviewFilter.all;
  DateTime? _calendarMonthAnchor;
  DateTime? _selectedCalendarDate;
  int _notifUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    final today = _startOfDay(_now());
    _calendarMonthAnchor = DateTime(today.year, today.month, 1);
    _selectedCalendarDate = today;
    _reloadHomeSignals();
    _fetchNotifUnreadCount();
  }

  Future<void> _fetchNotifUnreadCount() async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'core-hub',
        body: {'action': 'notification.list', 'filter': 'unread', 'limit': 1},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final count = (data['unreadCount'] as num?)?.toInt() ?? 0;
        if (mounted) setState(() => _notifUnreadCount = count);
      }
    } catch (_) {
      // silent
    }
  }

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  void _reloadHomeSignals() {
    _totalAssetsFuture = _fetchTotalAssets();
    _opsSnapshotFuture = _loadOpsSnapshot();
    _kpiOverviewFuture = _loadHomeKpiOverview();
    _marketingKpiFuture = _loadHomeMarketingKpiSummary();
    _aiNudgeFuture = _opsSnapshotFuture.then((snapshot) {
      final command = _resolveNextAction(snapshot);
      return _loadAiNudgeIfNeeded(command, snapshot);
    });
    _reloadRecentToolSignals();
  }

  void _reloadRecentToolSignals() {
    _recentToolIdsFuture = HomeToolUsageService.loadRecentToolIds();
    _featureStrategyReportFuture = _recentToolIdsFuture.then((recentToolIds) {
      final catalog = _buildHomeToolCatalog().map((entry) {
        return FeatureStrategyCatalogItem(
          id: entry.id,
          sectionId: entry.sectionId,
          title: entry.title,
          subtitle: entry.subtitle,
          keywords: entry.keywords,
          requiresClearDeck: entry.requiresClearDeck,
        );
      }).toList();
      final sectionNamesById = {
        for (final section in homeToolSections) section.id: section.title,
      };
      return const FeatureStrategyMonitorService().buildReport(
        catalog: catalog,
        recentToolIds: recentToolIds,
        sectionNamesById: sectionNamesById,
        monitoredAt: _now(),
      );
    });
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LandingPage()),
      );
    }
  }

  // ✅ Pull-to-Refresh 用（必要なときだけKPIを再取得）
  Future<void> _refreshKpis() async {
    setState(() {
      _reloadHomeSignals();
    });
    await _totalAssetsFuture;
    await _opsSnapshotFuture;
    await _kpiOverviewFuture;
    await _marketingKpiFuture;
    await _aiNudgeFuture;
    await _featureStrategyReportFuture;
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(_now());

  String _morningBriefingDoneKeyFor(DateTime date) =>
      'home_morning_briefing_done_${DateFormat('yyyy-MM-dd').format(date)}';

  String _balanceCheckDoneKeyFor(DateTime date) =>
      'home_balance_check_done_${DateFormat('yyyy-MM-dd').format(date)}';

  String _monthlyFlowReviewDoneKeyFor(DateTime date) =>
      'home_monthly_flow_review_done_${DateFormat('yyyy-MM').format(date)}';

  String _aiNudgeCacheKey(_HomeActionType type, _HomeOpsSnapshot snapshot) {
    final slipSeed = snapshot.abstinenceSlipDetails.take(3).join('|');
    final seed =
        '${snapshot.pendingCriticalTaskCount}|${snapshot.pendingStockTaskCount}|'
        '${snapshot.abstinenceSlipCount}|$slipSeed|'
        '${snapshot.completionGoalSnapshot.todayCompletedCount}|'
        '${snapshot.completionGoalSnapshot.yesterdayCompletedCount}';
    final encoded = base64Url.encode(utf8.encode(seed)).replaceAll('=', '');
    final token = encoded.length > 40 ? encoded.substring(0, 40) : encoded;
    return 'home_ai_nudge_${_todayKey}_${type.name}_$token';
  }

  Future<int> _fetchPendingCriticalTaskCount() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_now());
    return _fetchPendingCriticalTaskCountForDateKey(dateStr);
  }

  Future<int> _fetchPendingCriticalTaskCountForDateKey(String dateStr) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final dynamic rowsRaw = await Supabase.instance.client
          .from('mindless_tasks')
          .select('id')
          .eq('user_id', userId)
          .eq('task_date', dateStr)
          .eq('is_completed', false)
          .ilike('content', '%必須:%');
      final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];
      return rows.length;
    } catch (e) {
      debugPrint('Error fetching critical task count: $e');
      return 0;
    }
  }

  Future<Map<String, int>> _fetchPendingCriticalTaskCountMap({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return <String, int>{};

    final startKey = _statusDateKey(startDate);
    final endKey = _statusDateKey(endDate);
    try {
      final dynamic rowsRaw = await Supabase.instance.client
          .from('mindless_tasks')
          .select('task_date')
          .eq('user_id', userId)
          .eq('is_completed', false)
          .gte('task_date', startKey)
          .lte('task_date', endKey)
          .ilike('content', '%必須:%');
      final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];
      final counts = <String, int>{};
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final dateKey = row['task_date']?.toString();
        if (dateKey == null || dateKey.isEmpty) continue;
        counts.update(dateKey, (value) => value + 1, ifAbsent: () => 1);
      }
      return counts;
    } catch (e) {
      debugPrint('Error fetching critical task map: $e');
      return <String, int>{};
    }
  }

  Future<int> _fetchPendingStockTaskCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final dynamic rowsRaw = await Supabase.instance.client
          .from('someday_tasks')
          .select('id')
          .eq('user_id', userId)
          .eq('is_completed', false);
      final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];
      return rows.length;
    } catch (e) {
      debugPrint('Error fetching pending stock task count: $e');
      return 0;
    }
  }

  Future<_HomeMonthlyCashflowSummary> _loadMonthlyCashflowSummary({
    required SharedPreferences prefs,
    required DateTime month,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final monthStart = DateTime(month.year, month.month, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    final reviewDone =
        prefs.getBool(_monthlyFlowReviewDoneKeyFor(monthStart)) ?? false;

    if (userId == null) {
      return _HomeMonthlyCashflowSummary(
        month: monthStart,
        reviewDone: reviewDone,
      );
    }

    try {
      final dynamic rowsRaw = await Supabase.instance.client
          .from('wealth_struggles')
          .select('action_type,amount,occurred_at')
          .eq('user_id', userId)
          .gte('occurred_at', monthStart.toUtc().toIso8601String())
          .lt('occurred_at', nextMonth.toUtc().toIso8601String())
          .order('occurred_at', ascending: false);
      final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];

      var incomeTotal = 0;
      var expenseTotal = 0;
      var incomeCount = 0;
      var expenseCount = 0;
      DateTime? lastRecordedAt;

      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final actionType = row['action_type']?.toString() ?? '';
        final amount = (row['amount'] as num?)?.toInt() ?? 0;
        final occurredAt = DateTime.tryParse(
          row['occurred_at']?.toString() ?? '',
        )?.toLocal();
        if (occurredAt != null &&
            (lastRecordedAt == null || occurredAt.isAfter(lastRecordedAt))) {
          lastRecordedAt = occurredAt;
        }

        if (actionType == 'conquer') {
          incomeTotal += amount;
          incomeCount += 1;
        } else if (actionType == 'expense') {
          expenseTotal += amount;
          expenseCount += 1;
        }
      }

      return _HomeMonthlyCashflowSummary(
        month: monthStart,
        incomeTotal: incomeTotal,
        expenseTotal: expenseTotal,
        incomeCount: incomeCount,
        expenseCount: expenseCount,
        reviewDone: reviewDone,
        lastRecordedAt: lastRecordedAt,
      );
    } catch (e) {
      debugPrint('Error loading monthly cashflow summary: $e');
      return _HomeMonthlyCashflowSummary(
        month: monthStart,
        reviewDone: reviewDone,
      );
    }
  }

  Future<Map<String, _HomeDailyCashflowSummary>> _loadCalendarCashflowMap({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return <String, _HomeDailyCashflowSummary>{};
    }

    final normalizedStart = _startOfDay(startDate);
    final normalizedEndExclusive =
        _startOfDay(endDate).add(const Duration(days: 1));

    try {
      final dynamic rowsRaw = await Supabase.instance.client
          .from('wealth_struggles')
          .select('action_type,amount,occurred_at')
          .eq('user_id', userId)
          .gte('occurred_at', normalizedStart.toUtc().toIso8601String())
          .lt('occurred_at', normalizedEndExclusive.toUtc().toIso8601String())
          .order('occurred_at', ascending: true);
      final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];
      final result = <String, _HomeDailyCashflowSummary>{};

      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final occurredAt = DateTime.tryParse(
          row['occurred_at']?.toString() ?? '',
        )?.toLocal();
        if (occurredAt == null) continue;

        final dateKey = _statusDateKey(occurredAt);
        final current = result[dateKey] ?? const _HomeDailyCashflowSummary();
        final actionType = row['action_type']?.toString() ?? '';
        final amount = _toIntValue(row['amount']);

        result[dateKey] = switch (actionType) {
          'conquer' => current.copyWith(
              incomeTotal: current.incomeTotal + amount,
              incomeCount: current.incomeCount + 1,
            ),
          'expense' => current.copyWith(
              expenseTotal: current.expenseTotal + amount,
              expenseCount: current.expenseCount + 1,
            ),
          'transfer' => current.copyWith(
              transferTotal: current.transferTotal + amount,
              transferCount: current.transferCount + 1,
            ),
          _ => current,
        };
      }

      return result;
    } catch (e) {
      debugPrint('Error loading calendar cashflow map: $e');
      return <String, _HomeDailyCashflowSummary>{};
    }
  }

  Future<DailyCompletionGoalSnapshot> _loadDailyCompletionGoalSnapshot({
    required DateTime now,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return CompletionGoalService.buildSnapshot(
        todos: const <Map<String, dynamic>>[],
        now: now,
      );
    }

    final today = _startOfDay(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final yesterdayKey = _statusDateKey(yesterday);
    final todayKey = _statusDateKey(today);
    final yesterdayIso = yesterday.toIso8601String();
    final tomorrowIso = tomorrow.toIso8601String();
    final rowsById = <String, Map<String, dynamic>>{};

    void mergeRows(dynamic rowsRaw) {
      final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        rowsById[id] = row;
      }
    }

    try {
      final byTaskDate = await Supabase.instance.client
          .from('daily_todos')
          .select('id,is_completed,completed_at,task_date')
          .eq('user_id', userId)
          .gte('task_date', yesterdayKey)
          .lte('task_date', todayKey);
      mergeRows(byTaskDate);

      final byCompletedAt = await Supabase.instance.client
          .from('daily_todos')
          .select('id,is_completed,completed_at,task_date')
          .eq('user_id', userId)
          .gte('completed_at', yesterdayIso)
          .lt('completed_at', tomorrowIso);
      mergeRows(byCompletedAt);
    } catch (e) {
      debugPrint('Error loading completion goal snapshot: $e');
    }

    return CompletionGoalService.buildSnapshot(
      todos: rowsById.values.toList(),
      now: now,
    );
  }

  Future<Map<String, List<_HomeCalendarTask>>> _fetchHomeCalendarTaskMap({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return <String, List<_HomeCalendarTask>>{};

    final startKey = _statusDateKey(startDate);
    final endKey = _statusDateKey(endDate);
    final tasksByDate = <String, List<_HomeCalendarTask>>{};

    void appendTask(String dateKey, _HomeCalendarTask task) {
      tasksByDate.putIfAbsent(dateKey, () => <_HomeCalendarTask>[]).add(task);
    }

    try {
      final dynamic todoRowsRaw = await Supabase.instance.client
          .from('daily_todos')
          .select(
            'id,task_date,task,is_completed,is_important,category,order_index',
          )
          .eq('user_id', userId)
          .gte('task_date', startKey)
          .lte('task_date', endKey)
          .order('task_date', ascending: true)
          .order('order_index', ascending: true);
      final todoRows = todoRowsRaw is List ? todoRowsRaw : const <dynamic>[];

      for (final row in todoRows.whereType<Map<String, dynamic>>()) {
        final dateKey = row['task_date']?.toString();
        final title = (row['task'] as String? ?? '').trim();
        if (dateKey == null || dateKey.isEmpty || title.isEmpty) {
          continue;
        }

        appendTask(
          dateKey,
          _HomeCalendarTask(
            id: 'daily_${row['id']}',
            title: title,
            isCompleted: row['is_completed'] == true,
            isImportant: row['is_important'] == true,
            source: _HomeCalendarTaskSource.dailyTodo,
            secondaryLabel:
                _dailyTodoCategoryLabel(row['category']?.toString()),
            sortOrder: (row['order_index'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching daily todo map: $e');
    }

    try {
      final dynamic mindlessRowsRaw = await Supabase.instance.client
          .from('mindless_tasks')
          .select('id,task_date,hour_slot,content,is_completed')
          .eq('user_id', userId)
          .gte('task_date', startKey)
          .lte('task_date', endKey)
          .order('task_date', ascending: true)
          .order('hour_slot', ascending: true);
      final mindlessRows =
          mindlessRowsRaw is List ? mindlessRowsRaw : const <dynamic>[];

      for (final row in mindlessRows.whereType<Map<String, dynamic>>()) {
        final dateKey = row['task_date']?.toString();
        final title = (row['content'] as String? ?? '').trim();
        if (dateKey == null || dateKey.isEmpty || title.isEmpty) {
          continue;
        }

        final hourSlot = (row['hour_slot'] as num?)?.toInt();
        appendTask(
          dateKey,
          _HomeCalendarTask(
            id: 'mindless_${row['id']}',
            title: title,
            isCompleted: row['is_completed'] == true,
            isImportant: false,
            source: _HomeCalendarTaskSource.mindless,
            secondaryLabel: _hourSlotLabel(hourSlot),
            sortOrder: 1000 + (hourSlot ?? 0),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching mindless task map: $e');
    }

    for (final tasks in tasksByDate.values) {
      tasks.sort((a, b) {
        final completedCompare =
            (a.isCompleted ? 1 : 0).compareTo(b.isCompleted ? 1 : 0);
        if (completedCompare != 0) {
          return completedCompare;
        }

        final sortCompare = a.sortOrder.compareTo(b.sortOrder);
        if (sortCompare != 0) {
          return sortCompare;
        }

        return a.title.compareTo(b.title);
      });
    }

    return tasksByDate;
  }

  String _dailyTodoCategoryLabel(String? category) {
    return switch (category) {
      'work' => '仕事',
      'health' => '健康',
      'household' => '生活',
      'study' => '学習',
      'personal' => '個人',
      _ => '今日タスク',
    };
  }

  String _hourSlotLabel(int? hourSlot) {
    if (hourSlot == null) {
      return '実行枠';
    }
    final safeHour = hourSlot.clamp(0, 23);
    return '${safeHour.toString().padLeft(2, '0')}:00';
  }

  Future<_HomeKpiOverview> _loadHomeKpiOverview() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return const _HomeKpiOverview();
    }

    try {
      final results = await Future.wait<dynamic>([
        Supabase.instance.client
            .from('cfo_assets')
            .select('title,amount,created_at')
            .eq('user_id', userId)
            .order('created_at', ascending: true),
        Supabase.instance.client
            .from('wealth_struggles')
            .select('amount,description,occurred_at,action_type')
            .eq('user_id', userId)
            .order('occurred_at', ascending: true),
      ]);
      final rows = results[0] is List ? results[0] as List<dynamic> : const [];
      final wasteRows =
          results[1] is List ? results[1] as List<dynamic> : const [];
      if (rows.isEmpty) {
        return const _HomeKpiOverview();
      }

      final rawByDate = <String, Map<String, double>>{};
      for (final rawRow in rows.whereType<Map>()) {
        final row = Map<String, dynamic>.from(rawRow);
        final createdAtRaw = row['created_at']?.toString();
        final createdAt = createdAtRaw == null
            ? null
            : DateTime.tryParse(createdAtRaw)?.toLocal();
        if (createdAt == null) continue;
        final amount = (row['amount'] as num?)?.toDouble();
        if (amount == null) continue;

        final dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
        final title = (row['title']?.toString().trim().isNotEmpty ?? false)
            ? row['title'].toString().trim()
            : 'その他';
        rawByDate.putIfAbsent(dateKey, () => <String, double>{});
        rawByDate[dateKey]![title] = amount;
      }

      if (rawByDate.isEmpty) {
        return const _HomeKpiOverview();
      }

      final wasteByDate = <String, double>{};
      final wasteBreakdown = <String, double>{};
      var totalWaste = 0.0;
      var wasteRecordCount = 0;

      for (final rawRow in wasteRows.whereType<Map>()) {
        final row = Map<String, dynamic>.from(rawRow);
        final actionType = row['action_type']?.toString() ?? '';
        if (actionType != 'expense') continue;

        final amount = (row['amount'] as num?)?.toDouble();
        if (amount == null || amount <= 0) continue;

        final occurredAtRaw = row['occurred_at']?.toString();
        final occurredAt = occurredAtRaw == null
            ? null
            : DateTime.tryParse(occurredAtRaw)?.toLocal();
        if (occurredAt == null) continue;

        final description = row['description']?.toString() ?? '';
        final category = WasteTrackingService.extractWasteCategory(description);
        if (category == null) continue;

        final dateKey = DateFormat('yyyy-MM-dd').format(occurredAt);
        wasteByDate.update(
          dateKey,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
        wasteBreakdown.update(
          category,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
        totalWaste += amount;
        wasteRecordCount += 1;
      }

      final sortedDateKeys = <String>{
        ...rawByDate.keys,
        ...wasteByDate.keys,
      }.toList()
        ..sort();
      final running = <String, double>{};
      final trendPoints = <_KpiTrendPoint>[];
      var latestBreakdown = <String, double>{};
      var hasAssetSnapshot = false;

      for (final dateKey in sortedDateKeys) {
        final updates = rawByDate[dateKey];
        if (updates != null) {
          updates.forEach((key, value) {
            running[key] = value;
          });
          latestBreakdown = Map<String, double>.from(running);
          hasAssetSnapshot = true;
        }
        if (!hasAssetSnapshot) {
          continue;
        }

        var total = 0.0;
        for (final value in running.values) {
          total += value;
        }

        final pointDate = DateTime.tryParse(dateKey);
        if (pointDate == null) continue;
        trendPoints.add(
          _KpiTrendPoint(
            date: pointDate,
            total: total,
            waste: wasteByDate[dateKey] ?? 0,
          ),
        );
      }

      if (trendPoints.isEmpty) {
        return const _HomeKpiOverview();
      }

      double? totalAtOrBefore(DateTime targetDate) {
        for (var i = trendPoints.length - 1; i >= 0; i--) {
          final pointDate = _startOfDay(trendPoints[i].date);
          if (!pointDate.isAfter(targetDate)) {
            return trendPoints[i].total;
          }
        }
        return null;
      }

      final latestTotal = trendPoints.last.total;
      final previousTotal = trendPoints.length > 1
          ? trendPoints[trendPoints.length - 2].total
          : latestTotal;
      final today = _startOfDay(_now());
      final weekBase = totalAtOrBefore(today.subtract(const Duration(days: 7)));
      final monthBase = totalAtOrBefore(DateTime(today.year, today.month, 1));
      final yearBase = totalAtOrBefore(DateTime(today.year, 1, 1));

      var cashAndCryptoTotal = 0.0;
      var equityTotal = 0.0;
      var otherTotal = 0.0;
      latestBreakdown.forEach((title, amount) {
        switch (_resolveAssetBucket(title)) {
          case _AssetBucket.cashAndCrypto:
            cashAndCryptoTotal += amount;
            break;
          case _AssetBucket.equity:
            equityTotal += amount;
            break;
          case _AssetBucket.other:
            otherTotal += amount;
            break;
        }
      });

      return _HomeKpiOverview(
        latestTotal: latestTotal,
        previousTotal: previousTotal,
        weekBaseTotal: weekBase,
        monthBaseTotal: monthBase,
        yearBaseTotal: yearBase,
        cashAndCryptoTotal: cashAndCryptoTotal + otherTotal,
        equityTotal: equityTotal,
        trendPoints: trendPoints,
        totalWaste: totalWaste,
        wasteRecordCount: wasteRecordCount,
        wasteBreakdown: wasteBreakdown,
      );
    } catch (e) {
      debugPrint('Error loading home KPI overview: $e');
      return const _HomeKpiOverview();
    }
  }

  Future<_HomeMarketingKpiSummary> _loadHomeMarketingKpiSummary() async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('get-home-dashboard', body: <String, dynamic>{});
      final data = response.data;
      if (data is! Map || data['success'] != true) {
        return const _HomeMarketingKpiSummary();
      }
      final rawSeries = data['lpSeries'];
      final lpSeries = <_LpSeriesEntry>[];
      if (rawSeries is List) {
        for (final entry in rawSeries) {
          if (entry is Map) {
            final date = entry['date']?.toString() ?? '';
            final count = _toIntValue(entry['count']);
            if (date.length >= 10) {
              lpSeries.add(_LpSeriesEntry(date: date, count: count));
            }
          }
        }
      }
      return _HomeMarketingKpiSummary(
        todayViews: _toIntValue(data['todayViews']),
        todayRegistrations: _toIntValue(data['todaySignups']),
        todayShares: _toIntValue(data['todayShares']),
        topShareChannelKey: data['topShareChannelKey']?.toString(),
        totalUsers: _toIntValue(data['totalUsers']),
        lpSeries: lpSeries,
      );
    } catch (e) {
      debugPrint('Error loading home marketing summary: $e');
      return const _HomeMarketingKpiSummary();
    }
  }

  _AssetBucket _resolveAssetBucket(String title) {
    if (title.contains('株') ||
        title.contains('証券') ||
        title.contains('投信') ||
        title.toUpperCase().contains('ETF') ||
        title.toLowerCase().contains('equity') ||
        title.toLowerCase().contains('stock')) {
      return _AssetBucket.equity;
    }

    if (title.contains('預金') ||
        title.contains('現金') ||
        title.contains('銀行') ||
        title.contains('暗号') ||
        title.contains('仮想通貨') ||
        title.toLowerCase().contains('crypto') ||
        title.toLowerCase().contains('wallet')) {
      return _AssetBucket.cashAndCrypto;
    }

    return _AssetBucket.other;
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  int _toIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _shareChannelLabel(String? sourceKey) {
    switch (sourceKey) {
      case 'share_x':
      case 'x_share':
        return 'X';
      case 'share_line':
      case 'line':
        return 'LINE';
      case 'share_facebook':
      case 'facebook':
        return 'Facebook';
      case 'share_copy':
      case 'copy':
        return 'リンクコピー';
      default:
        return '未検出';
    }
  }

  DateTime _calendarAnchorMonth() {
    final anchor = _calendarMonthAnchor ?? _startOfDay(_now());
    return DateTime(anchor.year, anchor.month, 1);
  }

  String _statusDateKey(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(_startOfDay(date));

  Future<Map<String, _HomeDailyStatusRecord>?>
      _fetchHomeDailyStatusMapFromSupabase({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final startKey = _statusDateKey(startDate);
    final endKey = _statusDateKey(endDate);

    try {
      final dynamic rowsRaw = await Supabase.instance.client
          .from('home_daily_status')
          .select('status_date,morning_briefing_done,balance_check_done')
          .eq('user_id', userId)
          .gte('status_date', startKey)
          .lte('status_date', endKey);
      final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];
      final map = <String, _HomeDailyStatusRecord>{};

      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final dateKey = row['status_date']?.toString();
        if (dateKey == null || dateKey.isEmpty) continue;
        map[dateKey] = _HomeDailyStatusRecord(
          morningBriefingDone: row['morning_briefing_done'] == true,
          balanceCheckDone: row['balance_check_done'] == true,
        );
      }

      return map;
    } catch (e) {
      debugPrint('Error fetching home daily status from supabase: $e');
      return null;
    }
  }

  Future<Map<String, _HomeDailyStatusRecord>> _loadHomeDailyStatusMap({
    required SharedPreferences prefs,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final normalizedStart = _startOfDay(startDate);
    final normalizedEnd = _startOfDay(endDate);
    final supabaseMap = await _fetchHomeDailyStatusMapFromSupabase(
      startDate: normalizedStart,
      endDate: normalizedEnd,
    );
    final usesSupabaseSource = supabaseMap != null;
    final map = <String, _HomeDailyStatusRecord>{
      if (supabaseMap != null) ...supabaseMap,
    };

    for (DateTime day = normalizedStart;
        !day.isAfter(normalizedEnd);
        day = day.add(const Duration(days: 1))) {
      final dateKey = _statusDateKey(day);
      map.putIfAbsent(
        dateKey,
        () => usesSupabaseSource
            ? const _HomeDailyStatusRecord()
            : _HomeDailyStatusRecord(
                morningBriefingDone:
                    prefs.getBool(_morningBriefingDoneKeyFor(day)) ?? false,
                balanceCheckDone:
                    prefs.getBool(_balanceCheckDoneKeyFor(day)) ?? false,
              ),
      );
    }

    return map;
  }

  Future<_HomeOpsSnapshot> _loadOpsSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _startOfDay(_now());
    final monthlyCashflowSummary = await _loadMonthlyCashflowSummary(
      prefs: prefs,
      month: today,
    );
    final pendingCriticalTaskCount = await _fetchPendingCriticalTaskCount();
    final pendingStockTaskCount = await _fetchPendingStockTaskCount();
    final homeDailyMap = await _loadHomeDailyStatusMap(
      prefs: prefs,
      startDate: today,
      endDate: today,
    );
    final todayStatus =
        homeDailyMap[_statusDateKey(today)] ?? const _HomeDailyStatusRecord();
    final abstinenceSnapshot = await AbstinenceGuardStore.loadSnapshot(
      now: today,
    );
    final completionGoalSnapshot = await _loadDailyCompletionGoalSnapshot(
      now: today,
    );
    final primaryInterference = abstinenceSnapshot.primaryInterference;
    final calendarDays = await _loadCalendarDays(prefs: prefs);

    return _HomeOpsSnapshot(
      morningBriefingDone: todayStatus.morningBriefingDone,
      balanceCheckDone: todayStatus.balanceCheckDone,
      pendingCriticalTaskCount: pendingCriticalTaskCount,
      pendingStockTaskCount: pendingStockTaskCount,
      abstinenceFocusCount: abstinenceSnapshot.enabledCount,
      abstinenceSlipCount: abstinenceSnapshot.totalSlipCount,
      abstinenceSlipDetails: abstinenceSnapshot.slipDetails,
      abstinenceTopLabels: abstinenceSnapshot.topEnabledLabels,
      abstinencePrimaryLabel: primaryInterference?.item.label,
      abstinencePrimarySignal: primaryInterference?.item.interruptionSignal,
      abstinencePrimaryAction: primaryInterference?.item.eliminationAction,
      abstinenceDisciplineRepCount:
          abstinenceSnapshot.disciplineSnapshot.totalRepCount,
      abstinenceDisciplineMoneySaved:
          abstinenceSnapshot.disciplineSnapshot.totalMoneySaved,
      abstinenceDisciplineTimeSavedMinutes:
          abstinenceSnapshot.disciplineSnapshot.totalTimeSavedMinutes,
      abstinenceDisciplineStreakDays:
          abstinenceSnapshot.disciplineSnapshot.streakDays,
      abstinenceDisciplineStageLabel:
          abstinenceSnapshot.disciplineSnapshot.mindsetStageLabel,
      completionGoalSnapshot: completionGoalSnapshot,
      calendarDays: calendarDays,
      monthlyCashflowSummary: monthlyCashflowSummary,
    );
  }

  Future<List<_HomeCalendarDay>> _loadCalendarDays({
    required SharedPreferences prefs,
  }) async {
    final now = _now();
    final monthAnchor = _calendarAnchorMonth();
    final firstDayOfMonth = DateTime(monthAnchor.year, monthAnchor.month, 1);
    final lastDayOfMonth = DateTime(monthAnchor.year, monthAnchor.month + 1, 0);
    final startOffset = firstDayOfMonth.weekday % 7;
    final startDay = firstDayOfMonth.subtract(Duration(days: startOffset));
    final endOffset = 6 - (lastDayOfMonth.weekday % 7);
    final endDay = lastDayOfMonth.add(Duration(days: endOffset));
    final homeDailyMap = await _loadHomeDailyStatusMap(
      prefs: prefs,
      startDate: startDay,
      endDate: endDay,
    );
    final pendingCriticalTaskMap = await _fetchPendingCriticalTaskCountMap(
      startDate: startDay,
      endDate: endDay,
    );
    final cashflowByDate = await _loadCalendarCashflowMap(
      startDate: startDay,
      endDate: endDay,
    );
    final tasksByDate = await _fetchHomeCalendarTaskMap(
      startDate: startDay,
      endDate: endDay,
    );

    final days = <_HomeCalendarDay>[];
    for (DateTime day = startDay;
        !day.isAfter(endDay);
        day = day.add(const Duration(days: 1))) {
      final dateKey = _statusDateKey(day);
      final abstinence = await AbstinenceGuardStore.loadSnapshot(
        now: day,
      );
      final isCurrentMonth =
          day.year == monthAnchor.year && day.month == monthAnchor.month;
      final isToday =
          day.year == now.year && day.month == now.month && day.day == now.day;
      final dayStatus = homeDailyMap[dateKey] ?? const _HomeDailyStatusRecord();
      final morningDone = dayStatus.morningBriefingDone;
      final balanceDone = dayStatus.balanceCheckDone;
      final pendingCriticalTaskCountForDay =
          pendingCriticalTaskMap[dateKey] ?? 0;
      final tasks = List<_HomeCalendarTask>.from(
        tasksByDate[dateKey] ?? const <_HomeCalendarTask>[],
      );
      final cashflow =
          cashflowByDate[dateKey] ?? const _HomeDailyCashflowSummary();
      final hasProtection = abstinence.enabledCount > 0;
      final hasSlip = abstinence.totalSlipCount > 0;
      final isFuture = day.isAfter(DateTime(now.year, now.month, now.day));
      final missingItems = <String>[
        if (!isFuture && !morningDone) 'モーニング・ブリーフィング',
        if (!isFuture && !balanceDone) '口座残高確認',
        if (!isFuture && pendingCriticalTaskCountForDay > 0)
          '必須タスク $pendingCriticalTaskCountForDay件',
        if (!isFuture && !hasProtection) '禁欲ガード設定',
      ];
      final relapsePreventionAction = _buildRelapsePreventionAction(
        abstinence: abstinence,
        isFuture: isFuture,
        morningDone: morningDone,
        balanceDone: balanceDone,
        hasProtection: hasProtection,
        hasSlip: hasSlip,
      );

      days.add(
        _HomeCalendarDay(
          date: day,
          isCurrentMonth: isCurrentMonth,
          isToday: isToday,
          isFuture: isFuture,
          morningDone: morningDone,
          balanceDone: balanceDone,
          pendingCriticalTaskCount: pendingCriticalTaskCountForDay,
          hasAbstinenceProtection: hasProtection,
          hasAbstinenceSlip: hasSlip,
          isSaturday: day.weekday == DateTime.saturday,
          enabledLabels: abstinence.enabledLabels,
          slipDetails: abstinence.slipDetails,
          missingItems: missingItems,
          relapsePreventionAction: relapsePreventionAction,
          cashflow: cashflow,
          tasks: tasks,
        ),
      );
    }
    return days;
  }

  String _buildRelapsePreventionAction({
    required AbstinenceGuardSnapshot abstinence,
    required bool isFuture,
    required bool morningDone,
    required bool balanceDone,
    required bool hasProtection,
    required bool hasSlip,
  }) {
    if (isFuture) {
      return '前日までの逸脱傾向を見て、禁止対象を1件だけ先に固定する。';
    }

    if (hasSlip) {
      final sortedSlips = abstinence.slippedStates.toList()
        ..sort((a, b) => b.slipCount.compareTo(a.slipCount));
      if (sortedSlips.isNotEmpty) {
        final top = sortedSlips.first;
        return '${top.item.label}が崩れやすい日。${top.item.replacementAction}';
      }
    }

    if (!hasProtection) {
      return '朝いちで禁止対象を1件だけ固定して、先に逃げ道を塞ぐ。';
    }
    if (abstinence.disciplineSnapshot.totalRepCount == 0) {
      return '今日はまだ我慢の実績がありません。買わない・開かないを1回記録する。';
    }
    if (!morningDone) {
      return '朝の最初にブリーフィングを実施し、優先順位を固定する。';
    }
    if (!balanceDone) {
      return '口座残高確認を先に終えて、意思決定を数字に戻す。';
    }

    return '同じ禁止対象を維持し、夜に逸脱ゼロを確認して日次を閉じる。';
  }

  Future<_HomeDailyStatusRecord?> _fetchHomeDailyStatusFromSupabase(
    DateTime date,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final dynamic row = await Supabase.instance.client
          .from('home_daily_status')
          .select('morning_briefing_done,balance_check_done')
          .eq('user_id', userId)
          .eq('status_date', _statusDateKey(date))
          .maybeSingle();
      if (row is! Map<String, dynamic>) {
        return null;
      }
      return _HomeDailyStatusRecord(
        morningBriefingDone: row['morning_briefing_done'] == true,
        balanceCheckDone: row['balance_check_done'] == true,
      );
    } catch (e) {
      debugPrint('Error fetching home daily status (single): $e');
      return null;
    }
  }

  Future<void> _upsertHomeDailyStatus({
    bool? morningBriefingDone,
    bool? balanceCheckDone,
    DateTime? date,
  }) async {
    final targetDate = _startOfDay(date ?? _now());
    final prefs = await SharedPreferences.getInstance();

    // Local cache is kept as fallback for offline/testing paths.
    if (morningBriefingDone != null) {
      await prefs.setBool(
        _morningBriefingDoneKeyFor(targetDate),
        morningBriefingDone,
      );
    }
    if (balanceCheckDone != null) {
      await prefs.setBool(
        _balanceCheckDoneKeyFor(targetDate),
        balanceCheckDone,
      );
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final current = await _fetchHomeDailyStatusFromSupabase(targetDate) ??
          _HomeDailyStatusRecord(
            morningBriefingDone:
                prefs.getBool(_morningBriefingDoneKeyFor(targetDate)) ?? false,
            balanceCheckDone:
                prefs.getBool(_balanceCheckDoneKeyFor(targetDate)) ?? false,
          );
      final next = _HomeDailyStatusRecord(
        morningBriefingDone: morningBriefingDone ?? current.morningBriefingDone,
        balanceCheckDone: balanceCheckDone ?? current.balanceCheckDone,
      );

      await Supabase.instance.client.from('home_daily_status').upsert(
        {
          'user_id': userId,
          'status_date': _statusDateKey(targetDate),
          'morning_briefing_done': next.morningBriefingDone,
          'balance_check_done': next.balanceCheckDone,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,status_date',
      );
    } catch (e) {
      debugPrint('Error upserting home daily status: $e');
    }
  }

  String _resolveHomeModel(SharedPreferences prefs) {
    const legacyModels = {
      'gemini-pro',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-2.0-flash',
    };
    final candidates = <String?>[
      prefs.getString('gemini_model_home'),
      prefs.getString('gemini_model_emergency_meeting'),
      prefs.getString('gemini_model'),
    ];
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        final normalized = candidate.trim();
        return legacyModels.contains(normalized)
            ? 'gemini-2.5-flash'
            : normalized;
      }
    }
    return 'gemini-2.5-flash';
  }

  Future<String?> _loadHomeApiKey(SharedPreferences prefs) async {
    final secureKey = await _secureStorage.read(key: 'gemini_api_key');
    if (secureKey != null && secureKey.trim().isNotEmpty) {
      return secureKey.trim();
    }
    final legacyKey = prefs.getString('gemini_api_key');
    if (legacyKey != null && legacyKey.trim().isNotEmpty) {
      return legacyKey.trim();
    }
    return null;
  }

  String? _normalizeAiNudge(String? rawText) {
    final text = rawText?.replaceAll('\n', ' ').trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    if (text.length <= 80) {
      return text;
    }
    return '${text.substring(0, 80)}...';
  }

  Future<String?> _loadAiNudgeIfNeeded(
    _HomeActionCommand command,
    _HomeOpsSnapshot snapshot,
  ) async {
    if (command.type == _HomeActionType.none) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _aiNudgeCacheKey(command.type, snapshot);
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim();
    }

    // 並列インスタンスによる 429 ストームを防ぐ:
    // 別のインスタンスがすでに呼び出し中なら即座に null を返す
    if (_nudgeCallInProgress) {
      return null;
    }
    // 前回呼び出しから 60 秒未満ならスキップ
    final now = DateTime.now();
    if (_lastNudgeCallTime != null &&
        now.difference(_lastNudgeCallTime!) < const Duration(seconds: 60)) {
      return null;
    }

    try {
      final apiKey = await _loadHomeApiKey(prefs);
      if (apiKey == null) {
        return null;
      }

      _nudgeCallInProgress = true;
      _lastNudgeCallTime = DateTime.now();
      final model = _resolveHomeModel(prefs);
      final aiService = AIService(null, apiKey);
      final slipDetailsText = snapshot.abstinenceSlipDetails.isEmpty
          ? 'none'
          : snapshot.abstinenceSlipDetails.join(' / ');
      final prompt = '''
あなたはホーム画面の運用アシスタントです。
次アクションに対して、実行を後押しする短い補足を日本語で1文だけ返してください。
出力は1文のみ（句点あり、絵文字なし）。
abstinence_slip_details がある場合は、逸脱項目を1つ具体的に入れてください。

action_title: ${command.title}
action_detail: ${command.detail}
pending_critical_tasks: ${snapshot.pendingCriticalTaskCount}
abstinence_slip_count: ${snapshot.abstinenceSlipCount}
abstinence_slip_details: $slipDetailsText
''';

      final generated = await aiService.generateContent(
        model: model,
        prompt: prompt,
      );
      final nudge = _normalizeAiNudge(generated);
      if (nudge == null) {
        return null;
      }

      await prefs.setString(cacheKey, nudge);
      return nudge;
    } catch (e) {
      debugPrint('Home AI nudge generation failed: $e');
      return null;
    } finally {
      _nudgeCallInProgress = false;
    }
  }

  _HomeActionCommand _resolveNextAction(_HomeOpsSnapshot snapshot) {
    final hour = _now().hour;
    if (snapshot.abstinenceSlipCount > 0) {
      return _HomeActionCommand(
        type: _HomeActionType.abstinenceGuard,
        title: '逸脱が発生。禁欲ガードを最優先',
        detail: '今日の逸脱は${snapshot.abstinenceSlipCount}回。先に再設定して再発を止める。',
        icon: Icons.shield_moon,
        color: const Color(0xFFE53935),
      );
    }

    if (snapshot.monthlyCashflowSummary.needsReview) {
      return _HomeActionCommand(
        type: _HomeActionType.monthlyFlowReview,
        title: '今月の収支を先に把握する',
        detail: snapshot.monthlyCashflowSummary.summaryLine,
        icon: Icons.receipt_long,
        color: const Color(0xFF4CAF50),
      );
    }

    if (!snapshot.morningBriefingDone && hour < 12) {
      return const _HomeActionCommand(
        type: _HomeActionType.morningBriefing,
        title: 'モーニング・ブリーフィングを先に実施',
        detail: '朝の優先順位を確定してから他メニューへ進む。',
        icon: Icons.wb_sunny,
        color: Color(0xFFFFC107),
      );
    }

    if (!snapshot.balanceCheckDone) {
      return const _HomeActionCommand(
        type: _HomeActionType.balanceCheck,
        title: '今日の口座残高を確認',
        detail: 'まず資金状態を把握して、日次の打ち手を決める。',
        icon: Icons.account_balance_wallet,
        color: Color(0xFF4CAF50),
      );
    }

    if (snapshot.pendingCriticalTaskCount > 0) {
      return _HomeActionCommand(
        type: _HomeActionType.criticalTasks,
        title: '必須タスクを先に完了',
        detail: '思考停止ログの必須タスクが${snapshot.pendingCriticalTaskCount}件残っています。',
        icon: Icons.lock_clock,
        color: const Color(0xFFE53935),
      );
    }

    if (!snapshot.completionGoalSnapshot.isAchieved) {
      return _HomeActionCommand(
        type: _HomeActionType.beatYesterdayGoal,
        title: '今日は昨日より1件多く完了する',
        detail:
            '昨日 ${snapshot.completionGoalSnapshot.yesterdayCompletedCount}件 / 今日 ${snapshot.completionGoalSnapshot.todayCompletedCount}件 / 目標 ${snapshot.completionGoalSnapshot.targetCount}件',
        icon: Icons.trending_up,
        color: const Color(0xFF3D5AFE),
      );
    }

    if (hour >= 6 &&
        snapshot.pendingStockTaskCount > 0 &&
        _now().weekday == DateTime.saturday) {
      return _HomeActionCommand(
        type: _HomeActionType.stockReview,
        title: '週末ストックを見直す',
        detail: '土曜リマインド: 未完了ストックが${snapshot.pendingStockTaskCount}件あります。',
        icon: Icons.inventory_2,
        color: const Color(0xFFFFC107),
      );
    }

    return const _HomeActionCommand(
      type: _HomeActionType.none,
      title: '今日の必須導線は完了済み',
      detail: '次は通常メニューを優先度順に実行。',
      icon: Icons.verified,
      color: Color(0xFF4CAF50),
    );
  }

  Future<void> _openMorningBriefing(BuildContext context) async {
    await _openMorningBriefingForDate(context, _now());
  }

  Future<void> _openMonthlyCashflowReview(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final month = DateTime(_now().year, _now().month, 1);
    await prefs.setBool(_monthlyFlowReviewDoneKeyFor(month), true);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AssetManagementPage(
          initialFocus: AssetManagementInitialFocus.flow,
          emphasizeMonthlyFlow: true,
        ),
      ),
    );
    if (mounted) {
      await _refreshKpis();
    }
  }

  Future<void> _openMorningBriefingForDate(
    BuildContext context,
    DateTime date,
  ) async {
    await _upsertHomeDailyStatus(
      morningBriefingDone: true,
      date: date,
    );
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MorningBriefingPage(),
      ),
    );
    if (mounted) {
      await _refreshKpis();
    }
  }

  Future<void> _openCfoOffice(BuildContext context) async {
    await _openCfoOfficeForDate(context, _now());
  }

  Future<void> _openCfoOfficeForDate(
    BuildContext context,
    DateTime date,
  ) async {
    await _upsertHomeDailyStatus(
      balanceCheckDone: true,
      date: date,
    );
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CfoOfficePage()),
    );
    if (mounted) {
      await _refreshKpis();
    }
  }

  Future<void> _openAbstinenceGuard(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AbstinenceGuardPage(
          nowProvider: widget.nowProvider,
        ),
      ),
    );
    if (mounted) {
      await _refreshKpis();
    }
  }

  Future<void> _openAbstinenceGuardForDate(
    BuildContext context,
    DateTime date,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AbstinenceGuardPage(
          nowProvider: widget.nowProvider,
          initialDate: date,
        ),
      ),
    );
    if (mounted) {
      await _refreshKpis();
    }
  }

  Future<void> _runTrackedAction(
    String toolId,
    Future<dynamic> Function() action,
  ) async {
    await HomeToolUsageService.recordToolUse(toolId);
    unawaited(recordFeatureTap(toolId, toolId));
    await action();
    if (!mounted) return;
    setState(() {
      _reloadRecentToolSignals();
    });
  }

  List<HomeToolEntry> _buildHomeToolCatalog() {
    return buildHomeToolCatalog(
      openMorningBriefing: _openMorningBriefing,
      openCfoOffice: _openCfoOffice,
      openAbstinenceGuard: _openAbstinenceGuard,
    );
  }

  Set<String> _buildHighlightedToolIds({
    required bool highlightMorning,
    required bool highlightMonthlyFlow,
    required bool highlightBalance,
    required bool highlightCritical,
    required bool highlightStock,
    required bool highlightAbstinence,
  }) {
    final ids = <String>{};
    if (highlightMorning) ids.add('morning-briefing');
    if (highlightMonthlyFlow || highlightBalance) ids.add('cfo-office');
    if (highlightCritical) ids.add('mindless-task');
    if (highlightStock) ids.add('stock-tasks');
    if (highlightAbstinence) ids.add('abstinence-guard');
    return ids;
  }

  Map<String, String> _buildToolBadgeLabels({
    required bool highlightMorning,
    required bool highlightMonthlyFlow,
    required bool highlightBalance,
    required bool highlightCritical,
    required bool highlightStock,
    required bool highlightAbstinence,
    required _HomeOpsSnapshot opsSnapshot,
  }) {
    final badges = <String, String>{};
    if (highlightMorning) badges['morning-briefing'] = 'NOW';
    if (highlightMonthlyFlow) {
      badges['cfo-office'] = 'NOW';
    } else if (highlightBalance) {
      badges['cfo-office'] = 'NEXT';
    }
    if (highlightCritical) badges['mindless-task'] = 'NEXT';
    if (highlightStock) badges['stock-tasks'] = 'SAT';
    if (highlightAbstinence) {
      badges['abstinence-guard'] = 'NEXT';
    } else if (opsSnapshot.abstinenceSlipCount > 0) {
      badges['abstinence-guard'] = 'WARN';
    }
    return badges;
  }

  Future<void> _openWorkMenu(
    BuildContext context, {
    required bool shouldLockExploratoryMenus,
    required Set<String> highlightedToolIds,
    required Map<String, String> badgeLabels,
    bool autofocusSearch = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkMenuPage(
          lockExploratoryTools: shouldLockExploratoryMenus,
          highlightedToolIds: highlightedToolIds,
          badgeLabels: badgeLabels,
          autofocusSearch: autofocusSearch,
          openMorningBriefing: _openMorningBriefing,
          openCfoOffice: _openCfoOffice,
          openAbstinenceGuard: _openAbstinenceGuard,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _reloadRecentToolSignals();
    });
  }

  Widget _buildNextActionBubble(
    BuildContext context,
    _HomeActionCommand command,
    _HomeOpsSnapshot snapshot, {
    String? aiNudge,
    bool isAiNudgeLoading = false,
  }) {
    String buttonLabel = '最新化';
    VoidCallback? onPressed = () {
      _refreshKpis();
    };

    if (command.type == _HomeActionType.morningBriefing) {
      buttonLabel = 'ブリーフィングへ';
      onPressed = () {
        _openMorningBriefing(context);
      };
    } else if (command.type == _HomeActionType.monthlyFlowReview) {
      buttonLabel = '今月の収支へ';
      onPressed = () {
        _openMonthlyCashflowReview(context);
      };
    } else if (command.type == _HomeActionType.balanceCheck) {
      buttonLabel = '財務管理へ';
      onPressed = () {
        _openCfoOffice(context);
      };
    } else if (command.type == _HomeActionType.criticalTasks) {
      buttonLabel = '必須タスクへ';
      onPressed = () {
        _nav(context, const MindlessTaskPage());
      };
    } else if (command.type == _HomeActionType.stockReview) {
      buttonLabel = '週末ストックへ';
      onPressed = () {
        _nav(context, const StockTasksPage());
      };
    } else if (command.type == _HomeActionType.beatYesterdayGoal) {
      buttonLabel = 'タスク一覧へ';
      onPressed = () {
        _openMorningBriefing(context);
      };
    } else if (command.type == _HomeActionType.abstinenceGuard) {
      buttonLabel = '禁欲ガードへ';
      onPressed = () {
        _openAbstinenceGuard(context);
      };
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = Color.alphaBlend(
      command.color.withValues(alpha: isDark ? 0.2 : 0.12),
      isDark ? const Color(0xFF1A1A1A) : Colors.white,
    );
    final textColor = isDark ? Colors.white : const Color(0xDE000000);

    return Container(
      key: Key('home_next_action_${command.type.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            Color.alphaBlend(
              Colors.white.withValues(alpha: isDark ? 0.02 : 0.55),
              baseColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: command.color.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: command.color.withValues(alpha: isDark ? 0.16 : 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: command.color.withValues(alpha: 0.35)),
            ),
            child: Icon(command.icon, color: command.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '次に実施すべきアクション',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  command.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: textColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI推奨: ${command.detail}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.88),
                    height: 1.5,
                  ),
                ),
                if (isAiNudgeLoading &&
                    command.type != _HomeActionType.none) ...[
                  const SizedBox(height: 4),
                  Text(
                    'AI補足を生成中...',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.72),
                      height: 1.5,
                    ),
                  ),
                ],
                if (aiNudge != null && aiNudge.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'AI補足: $aiNudge',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                ],
                if (snapshot.pendingCriticalTaskCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '未完了の必須タスク: ${snapshot.pendingCriticalTaskCount}件',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.5,
                    ),
                  ),
                ],
                if (command.type == _HomeActionType.stockReview &&
                    snapshot.pendingStockTaskCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '未完了の週末ストック: ${snapshot.pendingStockTaskCount}件',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: command.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onPressed: onPressed,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCashflowPriorityCard(
    BuildContext context,
    _HomeOpsSnapshot snapshot, {
    required bool isHighlighted,
  }) {
    final summary = snapshot.monthlyCashflowSummary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = summary.netTotal >= 0
        ? const Color(0xFF4CAF50)
        : const Color(0xFFEF9A9A);
    final cardColor =
        isDark ? const Color(0xFF1E1E1E) : Colors.white.withValues(alpha: 0.92);
    final borderColor = isHighlighted
        ? accentColor.withValues(alpha: 0.7)
        : accentColor.withValues(alpha: 0.22);
    final monthLabel = summary.monthLabel;
    final recordLabel =
        summary.recordCount == 0 ? '未記録' : '${summary.recordCount}件記録';

    return Container(
      key: const Key('home_monthly_cashflow_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isHighlighted ? 1.6 : 1),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isHighlighted ? 0.18 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$monthLabelの収支を最優先',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xDE000000),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.summaryLine,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: (isDark ? Colors.white : const Color(0xDE000000))
                            .withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              if (isHighlighted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'NOW',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMonthlyCashflowMetric(
                label: '収入',
                value: _formatYen(summary.incomeTotal.toDouble()),
                color: const Color(0xFF388E3C),
              ),
              _buildMonthlyCashflowMetric(
                label: '支出',
                value: _formatYen(summary.expenseTotal.toDouble()),
                color: const Color(0xFFE53935),
              ),
              _buildMonthlyCashflowMetric(
                label: '差額',
                value: _formatSignedYen(summary.netTotal.toDouble()),
                color: accentColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMonthlyCashflowChip(
                icon:
                    summary.reviewDone ? Icons.visibility : Icons.priority_high,
                label: summary.reviewDone ? '今月レビュー済み' : '今月レビュー未実施',
                color:
                    summary.reviewDone ? const Color(0xFFB0B0B0) : accentColor,
              ),
              _buildMonthlyCashflowChip(
                icon: Icons.edit_note,
                label: recordLabel,
                color: summary.recordCount > 0
                    ? const Color(0xFF6366F1)
                    : const Color(0xFFFF6B35),
              ),
              if (summary.lastRecordedAt != null)
                _buildMonthlyCashflowChip(
                  icon: Icons.schedule,
                  label:
                      '最終記録 ${DateFormat('M/d HH:mm').format(summary.lastRecordedAt!)}',
                  color: const Color(0xFF3D5AFE),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('home_monthly_cashflow_cta'),
            onPressed: () => _openMonthlyCashflowReview(context),
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              summary.recordCount == 0 ? '今月の収支を記録する' : '今月の収支を確認する',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCashflowMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
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

  Widget _buildMonthlyCashflowChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForcedTaskPanel(
    BuildContext context,
    _HomeOpsSnapshot snapshot,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var title = '嫌でも先にやる1件を固定';
    var detail = '強制導線は解除済みです。次の通常メニューへ進めます。';
    var buttonLabel = '状態を更新';
    Color color = const Color(0xFFB0B0B0);
    var icon = Icons.verified;
    VoidCallback onPressed = _refreshKpis;

    if (snapshot.pendingCriticalTaskCount > 0) {
      title = 'まず嫌な必須タスクを片付ける';
      detail = '未完了の必須タスクが${snapshot.pendingCriticalTaskCount}件あります。'
          ' 他メニューより先に思考停止ログを消化してください。';
      buttonLabel = '必須タスクへ';
      color = const Color(0xFFE53935);
      icon = Icons.lock_clock;
      onPressed = () {
        _nav(context, const MindlessTaskPage());
      };
    } else if (!snapshot.morningBriefingDone) {
      title = '朝の固定を先に終える';
      detail = '気分で動く前に、朝の優先順位を先に固定します。';
      buttonLabel = 'ブリーフィングへ';
      color = const Color(0xFFFFC107);
      icon = Icons.wb_sunny;
      onPressed = () {
        _openMorningBriefing(context);
      };
    } else if (!snapshot.balanceCheckDone) {
      title = '数字確認を先に終える';
      detail = 'なんとなく触りたいメニューに行く前に、口座残高を確認します。';
      buttonLabel = '財務管理へ';
      color = const Color(0xFF4CAF50);
      icon = Icons.account_balance_wallet;
      onPressed = () {
        _openCfoOffice(context);
      };
    } else if (snapshot.abstinenceSlipCount > 0) {
      title = '逸脱復旧を先にやる';
      detail = '今日は${snapshot.abstinenceSlipCount}回の逸脱があります。'
          ' 先に禁欲ガードを再設定してください。';
      buttonLabel = '禁欲ガードへ';
      color = const Color(0xFFFF6B35);
      icon = Icons.shield_moon;
      onPressed = () {
        _openAbstinenceGuard(context);
      };
    }

    final baseColor = Color.alphaBlend(
      color.withValues(alpha: isDark ? 0.18 : 0.1),
      isDark ? const Color(0xFF1E1E1E) : Colors.white,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            Color.alphaBlend(
              Colors.white.withValues(alpha: isDark ? 0.02 : 0.5),
              baseColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '強制導線',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0x8A000000),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xDE000000),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionGoalPanel(
    BuildContext context,
    _HomeOpsSnapshot snapshot, {
    bool isHighlighted = false,
  }) {
    final goal = snapshot.completionGoalSnapshot;
    final achieved = goal.isAchieved;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = achieved ? const Color(0xFF4CAF50) : const Color(0xFF3D5AFE);
    final headline = achieved ? '前日超えを達成中' : '今日は昨日より1件多く終える';
    final detail =
        '昨日 ${goal.yesterdayCompletedCount}件 / 今日 ${goal.todayCompletedCount}件 / 目標 ${goal.targetCount}件';
    final helper = achieved
        ? 'このまま維持して、次の1件は短く終わるタスクから取ります。'
        : 'あと ${goal.remainingCount}件で前日超えです。5分で終わるものから先に片付けます。';
    final baseColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      key: const Key('home_completion_goal_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: isHighlighted ? 0.18 : 0.08),
              baseColor,
            ),
            Color.alphaBlend(
              Colors.white.withValues(alpha: isDark ? 0.02 : 0.5),
              baseColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  achieved ? Icons.trending_up : Icons.flag,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '前日超えチャレンジ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headline,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  achieved ? '達成中' : '未達',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detail,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : const Color(0xDE000000),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: goal.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor:
                isDark ? Colors.white.withValues(alpha: 0.24) : Colors.white,
            color: accent,
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : const Color(0xDE000000),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('home_completion_goal_open_morning_briefing'),
            onPressed: () => _openMorningBriefing(context),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('タスク一覧へ'),
          ),
        ],
      ),
    );
  }

  Widget _buildAbstinenceGuardPanel(
    BuildContext context,
    _HomeOpsSnapshot snapshot,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeLabels = snapshot.abstinenceTopLabels;
    final primaryLabel = snapshot.abstinencePrimaryLabel;
    final primarySignal = snapshot.abstinencePrimarySignal;
    final primaryAction = snapshot.abstinencePrimaryAction;

    return Container(
      key: const Key('home_abstinence_guard_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1F2937), Color(0xFF1E1E1E)]
              : const [Color(0xFFFFFBFB), Color(0xFFFFF3F2)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x47E53935)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0x1FE53935),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_moon, color: Color(0xFFE53935)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'やらないことガード',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: () => _openAbstinenceGuard(context),
                child: const Text('設定'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '今日の害悪行動を先に禁止して、逸脱は回数で管理する。',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusPill(
                label: '禁止中',
                value: '${snapshot.abstinenceFocusCount}件',
                color: const Color(0xFFE53935),
              ),
              _buildStatusPill(
                label: '逸脱',
                value: '${snapshot.abstinenceSlipCount}回',
                color: snapshot.abstinenceSlipCount > 0
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF4CAF50),
              ),
              _buildStatusPill(
                label: '我慢',
                value: '${snapshot.abstinenceDisciplineRepCount}回',
                color: const Color(0xFF3D5AFE),
              ),
              _buildStatusPill(
                label: '連続',
                value: '${snapshot.abstinenceDisciplineStreakDays}日',
                color: const Color(0xFF78716C),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            activeLabels.isEmpty
                ? 'まだ今日の禁止対象が固定されていません。酒・スマホ・動画などから先に封鎖してください。'
                : '今日の禁止対象: ${activeLabels.join(' / ')}'
                    '${snapshot.abstinenceFocusCount > activeLabels.length ? ' ほか' : ''}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : const Color(0xDE000000),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('home_abstinence_discipline_card'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x123D5AFE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0x2E3D5AFE),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '浪費耐性トレーニング',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1F3D5AFE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        snapshot.abstinenceDisciplineStageLabel,
                        style: const TextStyle(
                          color: Color(0xFF3D5AFE),
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  snapshot.abstinenceDisciplineRepCount == 0
                      ? '今日はまだ我慢の実績がありません。買わない・開かない・不便に耐えるを1回だけ積みます。'
                      : '今日の我慢 ${snapshot.abstinenceDisciplineRepCount}回 / 防いだ出費 ${_formatYen(snapshot.abstinenceDisciplineMoneySaved.toDouble())}円 / 取り戻した時間 ${snapshot.abstinenceDisciplineTimeSavedMinutes}分',
                  key: const Key('home_abstinence_discipline_summary'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xDE000000),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    key: const Key('home_abstinence_open_training_button'),
                    onPressed: () => _openAbstinenceGuard(context),
                    icon: const Icon(Icons.fitness_center),
                    label: Text(
                      snapshot.abstinenceDisciplineRepCount == 0
                          ? '最初の我慢を記録'
                          : '浪費耐性を更新',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (primaryLabel != null &&
              primarySignal != null &&
              primaryAction != null) ...[
            const SizedBox(height: 10),
            Container(
              key: const Key('home_abstinence_primary_card'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x14E53935),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日の主犯: $primaryLabel',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '切断サイン: $primarySignal',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xDE000000),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '排除手順: $primaryAction',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE53935),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          const ThoughtInterruptQuickWidget(),
        ],
      ),
    );
  }

  Widget _buildCalendarPanel(
    BuildContext context,
    _HomeOpsSnapshot snapshot,
  ) {
    final now = _now();
    final monthAnchor = _calendarAnchorMonth();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDay = _resolveSelectedCalendarDay(snapshot);
    final visibleMonthLabel = DateFormat('yyyy年M月').format(monthAnchor);
    final isViewingCurrentMonth =
        monthAnchor.year == now.year && monthAnchor.month == now.month;
    final currentMonthLabel = DateFormat('yyyy年M月').format(now);
    const weekLabels = ['日', '月', '火', '水', '木', '金', '土'];
    final displayedMonthDays =
        snapshot.calendarDays.where((day) => day.isCurrentMonth).toList();
    final recentDays = isViewingCurrentMonth
        ? displayedMonthDays.where((day) => !day.date.isAfter(now)).toList()
        : displayedMonthDays;
    final morningDoneCount = recentDays.where((day) => day.morningDone).length;
    final balanceDoneCount = recentDays.where((day) => day.balanceDone).length;
    final cleanDaysCount = recentDays
        .where((day) => day.hasAbstinenceProtection && !day.hasAbstinenceSlip)
        .length;
    final cashflowRecordedDaysCount =
        recentDays.where((day) => day.hasCashflow).length;
    final slipDaysCount =
        recentDays.where((day) => day.hasAbstinenceSlip).length;
    final unsetDaysCount =
        recentDays.where((day) => !day.hasAbstinenceProtection).length;
    final filterLabel = switch (_calendarHighlightFilter) {
      _CalendarHighlightFilter.all => null,
      _CalendarHighlightFilter.slip => '表示中: 逸脱日数のみハイライト',
      _CalendarHighlightFilter.clean => '表示中: 無傷日数のみハイライト',
      _CalendarHighlightFilter.unset => '表示中: 未設定日数のみハイライト',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1E1E1E), Color(0xFF172033)]
              : const [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFB0B0B0).withValues(alpha: isDark ? 0.3 : 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Color(0xFFB0B0B0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '継続カレンダー $currentMonthLabel',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('home_calendar_month_prev'),
                tooltip: '前月',
                visualDensity: VisualDensity.compact,
                onPressed: _showPreviousCalendarMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                key: const Key('home_calendar_month_next'),
                tooltip: '翌月',
                visualDensity: VisualDensity.compact,
                onPressed: _showNextCalendarMonth,
                icon: const Icon(Icons.chevron_right),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  _buildCalendarSummaryPill(
                    label: '逸脱日数',
                    value: '$slipDaysCount日',
                    color: const Color(0xFFFF6B35),
                    filter: _CalendarHighlightFilter.slip,
                  ),
                  _buildCalendarSummaryPill(
                    label: '無傷日数',
                    value: '$cleanDaysCount日',
                    color: const Color(0xFF4CAF50),
                    filter: _CalendarHighlightFilter.clean,
                  ),
                  _buildCalendarSummaryPill(
                    label: '未設定日数',
                    value: '$unsetDaysCount日',
                    color: const Color(0xFFB0B0B0),
                    filter: _CalendarHighlightFilter.unset,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            visibleMonthLabel,
            key: const Key('home_calendar_month_label'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF888888),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '朝の固定、残高確認、禁欲の安定を月単位で見る。',
          ),
          const SizedBox(height: 4),
          const Text(
            '各日の「収」「支」で、その日の入出金を月単位で俯瞰できます。',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888888),
              height: 1.5,
            ),
          ),
          if (filterLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              filterLabel,
              key: Key('home_calendar_filter_${_calendarHighlightFilter.name}'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF888888),
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusPill(
                label: '朝固定',
                value: '$morningDoneCount日',
                color: const Color(0xFFFFC107),
              ),
              _buildStatusPill(
                label: '残高確認',
                value: '$balanceDoneCount日',
                color: const Color(0xFF4CAF50),
              ),
              _buildStatusPill(
                label: '禁欲安定',
                value: '$cleanDaysCount日',
                color: const Color(0xFFE53935),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusPill(
                label: '収支記録',
                value: '$cashflowRecordedDaysCount日',
                color: const Color(0xFF3D5AFE),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: weekLabels.map((label) {
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF888888),
                      height: 1.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 86,
            ),
            itemCount: snapshot.calendarDays.length,
            itemBuilder: (context, index) {
              final day = snapshot.calendarDays[index];
              final status = _resolveCalendarDayStatus(day);
              final matchesFilter = _matchesCalendarHighlightFilter(day);
              final accentColor =
                  day.isCurrentMonth ? status.color : const Color(0xFFB0B0B0);
              final backgroundColor = day.isCurrentMonth
                  ? matchesFilter
                      ? accentColor.withValues(
                          alpha: day.hasAbstinenceSlip
                              ? 0.18
                              : status.label == '無傷'
                                  ? 0.14
                                  : status.label == '未設定'
                                      ? 0.08
                                      : 0.1,
                        )
                      : const Color(0xFFB0B0B0).withValues(alpha: 0.035)
                  : const Color(0xFFB0B0B0).withValues(alpha: 0.05);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key(
                    'calendar_day_${DateFormat('yyyy-MM-dd').format(day.date)}',
                  ),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    setState(() {
                      _selectedCalendarDate = _startOfDay(day.date);
                    });
                    await _showCalendarDayDetails(context, day);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: day.isToday
                            ? const Color(0xFF6366F1)
                            : day.isCurrentMonth
                                ? matchesFilter
                                    ? accentColor.withValues(alpha: 0.22)
                                    : const Color(0xFFB0B0B0)
                                        .withValues(alpha: 0.08)
                                : Colors.transparent,
                        width: day.isToday ? 1.6 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${day.date.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: day.isCurrentMonth
                                  ? matchesFilter
                                      ? (status.label == '未設定'
                                          ? (isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.7)
                                              : const Color(0xDE000000))
                                          : accentColor)
                                      : isDark
                                          ? const Color(0xFF666666)
                                          : const Color(0xFFB0B0B0)
                                  : const Color(0xFFB0B0B0),
                              height: 1.5,
                            ),
                          ),
                          if (day.isCurrentMonth && day.hasCashflow) ...[
                            const SizedBox(height: 4),
                            if (day.cashflow.incomeCount > 0)
                              _buildCalendarCashflowLine(
                                key: Key(
                                  'calendar_day_income_${DateFormat('yyyy-MM-dd').format(day.date)}',
                                ),
                                label: '収',
                                amount: day.cashflow.incomeTotal,
                                color: const Color(0xFF388E3C),
                                sign: '+',
                                isEmphasized: matchesFilter,
                              ),
                            if (day.cashflow.expenseCount > 0)
                              _buildCalendarCashflowLine(
                                key: Key(
                                  'calendar_day_expense_${DateFormat('yyyy-MM-dd').format(day.date)}',
                                ),
                                label: '支',
                                amount: day.cashflow.expenseTotal,
                                color: const Color(0xFFE53935),
                                sign: '-',
                                isEmphasized: matchesFilter,
                              ),
                          ],
                          const Spacer(),
                          Wrap(
                            spacing: 3,
                            runSpacing: 3,
                            children: [
                              if (day.morningDone)
                                _buildCalendarDot(
                                  _calendarDotDisplayColor(
                                    const Color(0xFFFFC107),
                                    isEmphasized: matchesFilter,
                                  ),
                                ),
                              if (day.balanceDone)
                                _buildCalendarDot(
                                  _calendarDotDisplayColor(
                                    const Color(0xFF4CAF50),
                                    isEmphasized: matchesFilter,
                                  ),
                                ),
                              if (day.hasAbstinenceProtection &&
                                  !day.hasAbstinenceSlip)
                                _buildCalendarDot(
                                  _calendarDotDisplayColor(
                                    const Color(0xFFE53935),
                                    isEmphasized: matchesFilter,
                                  ),
                                ),
                              if (day.hasAbstinenceSlip)
                                _buildCalendarDot(
                                  _calendarDotDisplayColor(
                                    const Color(0xFFFF6B35),
                                    isEmphasized: matchesFilter,
                                  ),
                                ),
                              if (day.isSaturday)
                                _buildCalendarDot(
                                  _calendarDotDisplayColor(
                                    const Color(0xFF009688),
                                    isEmphasized: matchesFilter,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildSelectedDayTaskPreviewPanel(context, selectedDay),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _CalendarLegend(color: Color(0xFF4CAF50), label: '収入'),
              _CalendarLegend(color: Color(0xFFE53935), label: '支出'),
            ],
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _CalendarLegend(color: Color(0xFFFFC107), label: '朝'),
              _CalendarLegend(color: Color(0xFF4CAF50), label: '残高'),
              _CalendarLegend(color: Color(0xFFE53935), label: '禁欲安定'),
              _CalendarLegend(color: Color(0xFFFF6B35), label: '逸脱'),
              _CalendarLegend(color: Color(0xFF009688), label: '土曜'),
            ],
          ),
        ],
      ),
    );
  }

  void _showPreviousCalendarMonth() {
    final current = _calendarAnchorMonth();
    _setCalendarMonth(DateTime(current.year, current.month - 1, 1));
  }

  void _showNextCalendarMonth() {
    final current = _calendarAnchorMonth();
    _setCalendarMonth(DateTime(current.year, current.month + 1, 1));
  }

  void _setCalendarMonth(DateTime month) {
    final normalizedMonth = DateTime(month.year, month.month, 1);
    final currentSelected = _selectedCalendarDate;
    final now = _startOfDay(_now());
    final nextSelected = currentSelected != null &&
            currentSelected.year == normalizedMonth.year &&
            currentSelected.month == normalizedMonth.month
        ? _startOfDay(currentSelected)
        : (now.year == normalizedMonth.year &&
                now.month == normalizedMonth.month
            ? now
            : normalizedMonth);

    setState(() {
      _calendarMonthAnchor = normalizedMonth;
      _selectedCalendarDate = nextSelected;
      _reloadHomeSignals();
    });
  }

  _HomeCalendarDay? _resolveSelectedCalendarDay(_HomeOpsSnapshot snapshot) {
    if (snapshot.calendarDays.isEmpty) {
      return null;
    }

    final selectedDate = _selectedCalendarDate ?? _startOfDay(_now());
    for (final day in snapshot.calendarDays) {
      if (DateUtils.isSameDay(day.date, selectedDate)) {
        return day;
      }
    }
    for (final day in snapshot.calendarDays) {
      if (day.isToday) {
        return day;
      }
    }
    for (final day in snapshot.calendarDays) {
      if (day.isCurrentMonth) {
        return day;
      }
    }
    return snapshot.calendarDays.first;
  }

  // ignore: unused_element
  Widget _buildSelectedDayTaskPreview(
    BuildContext context,
    _HomeCalendarDay? day,
  ) {
    if (day == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completedCount = day.completedTaskCount;
    final remainingCount = day.totalTaskCount - completedCount;
    final filteredTasks = _filterCalendarPreviewTasks(day.tasks);
    final hiddenTaskCount =
        filteredTasks.length > 6 ? filteredTasks.length - 6 : 0;
    final title = DateFormat('yyyy/MM/dd').format(day.date);

    return Container(
      key: const Key('home_calendar_task_preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x0D3D5AFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0x243D5AFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title のタスク',
                      key: const Key('home_calendar_task_preview_title'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '完了 $completedCount / 全体 ${day.totalTaskCount} / 未完了 $remainingCount',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF888888),
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                key: const Key('home_calendar_task_preview_open_detail'),
                onPressed: () => _showCalendarDayDetails(context, day),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('詳細'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCalendarTaskPreviewFilterChip(
                label: 'すべて',
                filter: _CalendarTaskPreviewFilter.all,
              ),
              _buildCalendarTaskPreviewFilterChip(
                label: '未完了のみ',
                filter: _CalendarTaskPreviewFilter.incompleteOnly,
              ),
              _buildCalendarTaskPreviewFilterChip(
                label: '重要のみ',
                filter: _CalendarTaskPreviewFilter.importantOnly,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (filteredTasks.isEmpty)
            Container(
              key: const Key('home_calendar_task_preview_empty'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surfaceContainerLow
                    : Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'この日に登録されているタスクはありません。',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            )
          else
            ...filteredTasks.take(6).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final task = entry.value;
              final sourceColor = _calendarTaskSourceColor(task);
              return Container(
                key: Key('home_calendar_task_preview_item_$index'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Theme.of(context).colorScheme.surfaceContainerLow
                      : Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sourceColor.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      task.isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: task.isCompleted
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFB0B0B0),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted
                                  ? const Color(0xFF888888)
                                  : null,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildCalendarTaskBadge(
                                label: _calendarTaskSourceLabel(task),
                                color: sourceColor,
                              ),
                              if (task.secondaryLabel != null)
                                _buildCalendarTaskBadge(
                                  label: task.secondaryLabel!,
                                  color: const Color(0xFFB0B0B0),
                                ),
                              if (task.isImportant)
                                _buildCalendarTaskBadge(
                                  label: '重要',
                                  color: const Color(0xFFE53935),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (hiddenTaskCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '他 ${day.tasks.length - 6} 件のタスクがあります。',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayTaskPreviewPanel(
    BuildContext context,
    _HomeCalendarDay? day,
  ) {
    if (day == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completedCount = day.completedTaskCount;
    final remainingCount = day.totalTaskCount - completedCount;
    final filteredTasks = _filterCalendarPreviewTasks(day.tasks);
    final hiddenTaskCount =
        filteredTasks.length > 6 ? filteredTasks.length - 6 : 0;
    final title = DateFormat('yyyy/MM/dd').format(day.date);

    return Container(
      key: const Key('home_calendar_task_preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x0D3D5AFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0x243D5AFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title のタスク',
                      key: const Key('home_calendar_task_preview_title'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '完了 $completedCount / 全体 ${day.totalTaskCount} / 未完了 $remainingCount',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF888888),
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                key: const Key('home_calendar_task_preview_open_detail'),
                onPressed: () => _showCalendarDayDetails(context, day),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('詳細'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCalendarTaskPreviewFilterChip(
                label: 'すべて',
                filter: _CalendarTaskPreviewFilter.all,
              ),
              _buildCalendarTaskPreviewFilterChip(
                label: '未完了のみ',
                filter: _CalendarTaskPreviewFilter.incompleteOnly,
              ),
              _buildCalendarTaskPreviewFilterChip(
                label: '重要のみ',
                filter: _CalendarTaskPreviewFilter.importantOnly,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (filteredTasks.isEmpty)
            Container(
              key: const Key('home_calendar_task_preview_empty'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surfaceContainerLow
                    : Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'この日に該当するタスクはありません。',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            )
          else
            ...filteredTasks.take(6).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final task = entry.value;
              final sourceColor = _calendarTaskSourceColor(task);
              return Container(
                key: Key('home_calendar_task_preview_item_$index'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Theme.of(context).colorScheme.surfaceContainerLow
                      : Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sourceColor.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      task.isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: task.isCompleted
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFB0B0B0),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted
                                  ? const Color(0xFF888888)
                                  : null,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildCalendarTaskBadge(
                                label: _calendarTaskSourceLabel(task),
                                color: sourceColor,
                              ),
                              if (task.secondaryLabel != null)
                                _buildCalendarTaskBadge(
                                  label: task.secondaryLabel!,
                                  color: const Color(0xFFB0B0B0),
                                ),
                              if (task.isImportant)
                                _buildCalendarTaskBadge(
                                  label: '重要',
                                  color: const Color(0xFFE53935),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (hiddenTaskCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '他 $hiddenTaskCount 件のタスクがあります。',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_HomeCalendarTask> _filterCalendarPreviewTasks(
    List<_HomeCalendarTask> tasks,
  ) {
    return switch (_calendarTaskPreviewFilter) {
      _CalendarTaskPreviewFilter.all => tasks,
      _CalendarTaskPreviewFilter.incompleteOnly =>
        tasks.where((task) => !task.isCompleted).toList(),
      _CalendarTaskPreviewFilter.importantOnly =>
        tasks.where((task) => task.isImportant).toList(),
    };
  }

  Widget _buildCalendarTaskPreviewFilterChip({
    required String label,
    required _CalendarTaskPreviewFilter filter,
  }) {
    final isSelected = _calendarTaskPreviewFilter == filter;
    return ChoiceChip(
      key: Key('home_calendar_preview_filter_${filter.name}'),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _calendarTaskPreviewFilter = filter;
        });
      },
    );
  }

  Widget _buildCalendarTaskBadge({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.5,
        ),
      ),
    );
  }

  String _calendarTaskSourceLabel(_HomeCalendarTask task) {
    return switch (task.source) {
      _HomeCalendarTaskSource.dailyTodo => '今日タスク',
      _HomeCalendarTaskSource.mindless => '時間割',
    };
  }

  Color _calendarTaskSourceColor(_HomeCalendarTask task) {
    return switch (task.source) {
      _HomeCalendarTaskSource.dailyTodo => const Color(0xFF3D5AFE),
      _HomeCalendarTaskSource.mindless => const Color(0xFF009688),
    };
  }

  String _formatCalendarTaskForDetail(_HomeCalendarTask task) {
    final sourceLabel = _calendarTaskSourceLabel(task);
    final stateLabel = task.isCompleted ? '完了' : '未完了';
    final secondary =
        task.secondaryLabel == null ? '' : ' ${task.secondaryLabel}';
    final important = task.isImportant ? ' [重要]' : '';
    return '[$sourceLabel/$stateLabel]$secondary$important ${task.title}';
  }

  Widget _buildCalendarDot(Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Color _calendarDotDisplayColor(
    Color color, {
    required bool isEmphasized,
  }) {
    if (isEmphasized) return color;
    return color.withValues(alpha: 0.22);
  }

  Widget _buildCalendarCashflowLine({
    required Key key,
    required String label,
    required int amount,
    required Color color,
    required String sign,
    required bool isEmphasized,
  }) {
    final textColor = isEmphasized ? color : color.withValues(alpha: 0.74);

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Text(
        '$label $sign${_formatCalendarCashflowAmount(amount)}',
        key: key,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildCalendarSummaryPill({
    required String label,
    required String value,
    required Color color,
    required _CalendarHighlightFilter filter,
  }) {
    final isSelected = _calendarHighlightFilter == filter;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('home_calendar_summary_${filter.name}'),
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            setState(() {
              _calendarHighlightFilter =
                  isSelected ? _CalendarHighlightFilter.all : filter;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isSelected ? 0.24 : 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: color.withValues(alpha: isSelected ? 0.38 : 0.18),
              ),
            ),
            child: Text(
              '$label $value',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _matchesCalendarHighlightFilter(_HomeCalendarDay day) {
    if (_calendarHighlightFilter == _CalendarHighlightFilter.all) {
      return true;
    }
    if (!day.isCurrentMonth || day.isFuture) {
      return false;
    }

    return switch (_calendarHighlightFilter) {
      _CalendarHighlightFilter.all => true,
      _CalendarHighlightFilter.slip => day.hasAbstinenceSlip,
      _CalendarHighlightFilter.clean =>
        day.hasAbstinenceProtection && !day.hasAbstinenceSlip,
      _CalendarHighlightFilter.unset => !day.hasAbstinenceProtection,
    };
  }

  _CalendarDayStatus _resolveCalendarDayStatus(_HomeCalendarDay day) {
    if (day.isFuture) {
      return const _CalendarDayStatus(
        label: '未設定',
        detail: '未来の日付です。まだ運用状態は確定していません。',
        color: Color(0xFFB0B0B0),
        icon: Icons.radio_button_unchecked,
      );
    }
    if (day.hasAbstinenceSlip) {
      return const _CalendarDayStatus(
        label: '逸脱あり',
        detail: 'その日は抑止ラインを突破しています。',
        color: Color(0xFFFF6B35),
        icon: Icons.warning_amber_rounded,
      );
    }
    if (!day.hasAbstinenceProtection) {
      return const _CalendarDayStatus(
        label: '未設定',
        detail: 'その日の禁止対象が固定されていません。',
        color: Color(0xFFB0B0B0),
        icon: Icons.radio_button_unchecked,
      );
    }
    return const _CalendarDayStatus(
      label: '無傷',
      detail: '禁止対象を保ったまま終えています。',
      color: Color(0xFF4CAF50),
      icon: Icons.verified,
    );
  }

  Future<void> _showCalendarDayDetails(
    BuildContext context,
    _HomeCalendarDay day,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parentContext = context;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final title = DateFormat('yyyy/MM/dd').format(day.date);
        final detailDateKey = DateFormat('yyyy-MM-dd').format(day.date);
        final status = _resolveCalendarDayStatus(day);
        final completedItems = <String>[
          if (day.morningDone) 'モーニング・ブリーフィング',
          if (day.balanceDone) '口座残高確認',
          if (day.pendingCriticalTaskCount == 0) '必須タスク完了',
          if (day.hasAbstinenceProtection && !day.hasAbstinenceSlip) '禁欲ガード安定',
        ];
        final taskItems = day.tasks
            .map((task) => _formatCalendarTaskForDetail(task))
            .toList();
        final needsMorning = !day.isFuture && !day.morningDone;
        final needsBalance = !day.isFuture && !day.balanceDone;
        final needsCriticalTask =
            !day.isFuture && day.pendingCriticalTaskCount > 0;
        final canQuickRecover =
            needsMorning || needsBalance || needsCriticalTask;

        return SafeArea(
          key: Key('calendar_day_detail_$detailDateKey'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$title の状態',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.5,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: status.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(status.icon, size: 16, color: status.color),
                            const SizedBox(width: 6),
                            Text(
                              status.label,
                              style: TextStyle(
                                color: status.color,
                                fontWeight: FontWeight.w800,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status.detail,
                    style: TextStyle(
                      color: status.color.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: status.color.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      '再発防止アクション: ${day.relapsePreventionAction}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key:
                        const Key('calendar_day_detail_open_abstinence_button'),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _openAbstinenceGuardForDate(
                        parentContext,
                        day.date,
                      );
                    },
                    icon: const Icon(Icons.shield_moon, size: 18),
                    label: const Text('その日の禁欲ガードへ'),
                  ),
                  if (canQuickRecover) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '未達項目へショートカット',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (needsMorning)
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _openMorningBriefingForDate(
                                parentContext,
                                day.date,
                              );
                            },
                            icon: const Icon(Icons.wb_sunny, size: 18),
                            label: const Text('朝を実施'),
                          ),
                        if (needsBalance)
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _openCfoOfficeForDate(
                                parentContext,
                                day.date,
                              );
                            },
                            icon: const Icon(
                              Icons.account_balance_wallet,
                              size: 18,
                            ),
                            label: const Text('残高確認へ'),
                          ),
                        if (needsCriticalTask)
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.pop(context);
                              _nav(parentContext, const MindlessTaskPage());
                            },
                            icon: const Icon(Icons.lock_clock, size: 18),
                            label: Text(
                              '必須タスクへ (${day.pendingCriticalTaskCount}件)',
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (day.isFuture) ...[
                    const Text('未来の日付です。まだ実績はありません。'),
                  ] else ...[
                    Text(
                      day.isCurrentMonth
                          ? 'その日の継続状態と逸脱内容を確認できます。'
                          : '前後月の補助セルです。',
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildCalendarCashflowDetailSection(parentContext, day),
                  const SizedBox(height: 12),
                  _buildCalendarDetailSection(
                    title: '登録タスク',
                    accent: const Color(0xFF3D5AFE),
                    emptyLabel: day.isFuture
                        ? 'まだこの日のタスクは登録されていません。'
                        : 'この日のタスクはありません。',
                    items: taskItems,
                  ),
                  const SizedBox(height: 12),
                  _buildCalendarDetailSection(
                    title: '逸脱内容',
                    accent: const Color(0xFFFF6B35),
                    emptyLabel: day.isFuture ? 'まだ記録はありません。' : '逸脱はありません。',
                    items: day.slipDetails,
                  ),
                  const SizedBox(height: 12),
                  _buildCalendarDetailSection(
                    title: '未達成項目',
                    accent: const Color(0xFFE53935),
                    emptyLabel:
                        day.isFuture ? 'まだ未達成判定はありません。' : '未達成項目はありません。',
                    items: day.missingItems,
                  ),
                  const SizedBox(height: 12),
                  _buildCalendarDetailSection(
                    title: '実施できた項目',
                    accent: const Color(0xFF4CAF50),
                    emptyLabel: day.isFuture ? 'まだ実施記録はありません。' : '実施項目はありません。',
                    items: completedItems,
                  ),
                  const SizedBox(height: 12),
                  _buildCalendarDetailSection(
                    title: 'その日に設定していた禁止対象',
                    accent: const Color(0xFFB0B0B0),
                    emptyLabel: day.isFuture ? 'まだ設定はありません。' : '禁止対象は未設定です。',
                    items: day.enabledLabels,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarCashflowDetailSection(
    BuildContext parentContext,
    _HomeCalendarDay day,
  ) {
    final cashflow = day.cashflow;
    final dateKey = _statusDateKey(day.date);

    return Container(
      key: Key('calendar_day_detail_cashflow_$dateKey'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x0F3D5AFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x293D5AFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '収支サマリ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF3D5AFE),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          if (!cashflow.hasAnyEntry)
            Text(
              day.isFuture ? 'この日の収支記録はまだありません。' : 'この日の収支記録はまだありません。',
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _buildCalendarCashflowMetricTile(
                    label: '収入',
                    value: _formatYen(cashflow.incomeTotal.toDouble()),
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCalendarCashflowMetricTile(
                    label: '支出',
                    value: _formatYen(cashflow.expenseTotal.toDouble()),
                    color: const Color(0xFFE53935),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCalendarCashflowMetricTile(
                    label: '差額',
                    value: _formatSignedYen(cashflow.netTotal.toDouble()),
                    color: cashflow.netTotal >= 0
                        ? const Color(0xFF3D5AFE)
                        : const Color(0xFFFF6B35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '入出金 ${cashflow.recordCount} 件'
              '${cashflow.transferCount > 0 ? ' / 振替 ${cashflow.transferCount} 件 (${_formatYen(cashflow.transferTotal.toDouble())})' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
                height: 1.5,
              ),
            ),
          ],
          if (!day.isFuture) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('calendar_day_detail_open_cashflow_$dateKey'),
                onPressed: () {
                  Navigator.pop(parentContext);
                  _nav(
                    parentContext,
                    const AssetManagementPage(
                      initialFocus: AssetManagementInitialFocus.flow,
                      emphasizeMonthlyFlow: true,
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('資産管理で詳細を見る'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarCashflowMetricTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDetailSection({
    required String title,
    required Color accent,
    required List<String> items,
    required String emptyLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(emptyLabel)
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('・$item'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }

  Future<String> _fetchTotalAssets() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return NumberFormat.currency(
        locale: 'ja_JP',
        symbol: '¥',
        decimalDigits: 0,
      ).format(0);
    }

    try {
      // ✅ RPC: スカラー(numeric)が返ってくる想定
      final res = await Supabase.instance.client.rpc('cfo_total_assets');

      final total = (res as num?)?.toDouble() ?? 0.0;

      final formatter = NumberFormat.currency(
        locale: 'ja_JP',
        symbol: '¥',
        decimalDigits: 0,
      );
      return formatter.format(total);
    } catch (e) {
      debugPrint('Error fetching total assets (rpc): $e');
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final primaryColor = themeService.primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 390;
    final isWide = screenWidth >= 1200;
    final contentHorizontalPadding = isCompact ? 12.0 : (isWide ? 24.0 : 16.0);

    return Scaffold(
      key: const Key('home_page_scaffold'),
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF3F7FF),
      appBar: AppBar(
        toolbarHeight: 74,
        title: const Column(
          key: Key('home_page_title'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('経営コックピット'),
          ],
        ),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  Colors.white.withValues(alpha: 0.08),
                  primaryColor,
                ),
                Color.alphaBlend(
                  Colors.black.withValues(alpha: 0.2),
                  primaryColor,
                ),
              ],
            ),
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // Win版#131 part 11: WBS ガントチャート導線
          IconButton(
            icon: const Icon(Icons.timeline),
            tooltip: 'WBS ガントチャート',
            onPressed: () => Navigator.pushNamed(context, '/project-gantt'),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: '通知',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
                  );
                  _fetchNotifUnreadCount();
                },
              ),
              if (_notifUnreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _notifUnreadCount > 9 ? '9+' : '$_notifUnreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeService.toggleTheme(),
            tooltip: 'テーマ切替',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileSettingsPage()),
            ),
            tooltip: 'プロフィール設定',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            tooltip: '設定',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'ログアウト',
          ),
        ],
      ),

      // ✅ 改善: RefreshIndicator を追加（KPIのみ再取得できる）
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF0A0A0A),
                    Color(0xFF121212),
                    Color(0xFF0A0A0A),
                  ]
                : const [
                    Color(0xFFF8FAFF),
                    Color(0xFFF1F5F9),
                    Color(0xFFE8EFF8),
                  ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refreshKpis,
          child: FutureBuilder<_HomeOpsSnapshot>(
            future: _opsSnapshotFuture,
            builder: (context, snapshot) {
              final opsSnapshot = snapshot.data ?? const _HomeOpsSnapshot();
              final nextAction = _resolveNextAction(opsSnapshot);
              final highlightMonthlyFlow =
                  nextAction.type == _HomeActionType.monthlyFlowReview;
              final highlightMorning =
                  nextAction.type == _HomeActionType.morningBriefing;
              final highlightBalance =
                  nextAction.type == _HomeActionType.balanceCheck;
              final highlightCritical =
                  nextAction.type == _HomeActionType.criticalTasks;
              final highlightBeatYesterday =
                  nextAction.type == _HomeActionType.beatYesterdayGoal;
              final highlightStock =
                  nextAction.type == _HomeActionType.stockReview;
              final highlightAbstinence =
                  nextAction.type == _HomeActionType.abstinenceGuard;
              final shouldLockExploratoryMenus =
                  opsSnapshot.pendingCriticalTaskCount > 0 ||
                      !opsSnapshot.morningBriefingDone ||
                      opsSnapshot.abstinenceSlipCount > 0;
              return FutureBuilder<String?>(
                future: _aiNudgeFuture,
                builder: (context, aiNudgeSnapshot) {
                  final aiNudge = aiNudgeSnapshot.data;
                  final isAiLoading = aiNudgeSnapshot.connectionState ==
                      ConnectionState.waiting;
                  final highlightedToolIds = _buildHighlightedToolIds(
                    highlightMorning: highlightMorning,
                    highlightMonthlyFlow: highlightMonthlyFlow,
                    highlightBalance: highlightBalance,
                    highlightCritical: highlightCritical,
                    highlightStock: highlightStock,
                    highlightAbstinence: highlightAbstinence,
                  );
                  final toolBadgeLabels = _buildToolBadgeLabels(
                    highlightMorning: highlightMorning,
                    highlightMonthlyFlow: highlightMonthlyFlow,
                    highlightBalance: highlightBalance,
                    highlightCritical: highlightCritical,
                    highlightStock: highlightStock,
                    highlightAbstinence: highlightAbstinence,
                    opsSnapshot: opsSnapshot,
                  );

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      contentHorizontalPadding,
                      16,
                      contentHorizontalPadding,
                      24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1140),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // AI プロバイダー API キー未設定バナー (Windows版#94)
                            const ApiKeyStatusBanner(),
                            // 最上部: AI大学キラーコンテンツバナー
                            const AiUniversityHomeCard(),
                            const SizedBox(height: 8),
                            // 5階層カスタマイズパネル
                            const CollapsibleHomeSection(
                              storageKey: 'home_tier_recent',
                              title: '最近使った機能',
                              icon: Icons.history,
                              iconColor: Color(0xFFFF6B35),
                              initiallyExpanded: true,
                              child: RecentFeaturesList(),
                            ),
                            const SizedBox(height: 4),
                            const CollapsibleHomeSection(
                              storageKey: 'home_tier_system',
                              title: 'システム固定機能',
                              icon: Icons.lock_outline,
                              iconColor: Color(0xFF6366F1),
                              initiallyExpanded: true,
                              child: SystemFixedFeaturesList(),
                            ),
                            const SizedBox(height: 4),
                            const CollapsibleHomeSection(
                              storageKey: 'home_tier_pinned',
                              title: 'お気に入り (ピン留め)',
                              icon: Icons.push_pin_outlined,
                              iconColor: Color(0xFF6366F1),
                              initiallyExpanded: true,
                              child: UserPinnedFeaturesList(),
                            ),
                            const SizedBox(height: 4),
                            const CollapsibleHomeSection(
                              storageKey: 'home_tier_new',
                              title: '最近追加された機能',
                              icon: Icons.new_releases_outlined,
                              iconColor: Color(0xFFFF6B35),
                              initiallyExpanded: false,
                              child: NewFeaturesList(),
                            ),
                            const SizedBox(height: 4),
                            const CollapsibleHomeSection(
                              storageKey: 'home_tier_recommend',
                              title: 'AI おすすめ機能',
                              icon: Icons.auto_awesome,
                              iconColor: Color(0xFF6366F1),
                              initiallyExpanded: false,
                              child: AiRecommendedFeaturesList(),
                            ),
                            const SizedBox(height: 8),
                            // AI競馬的中率リーダーボード
                            ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.leaderboard_outlined,
                                color: Color(0xFFFF6B35),
                                size: 20,
                              ),
                              title: const Text(
                                'AI競馬 的中率リーダーボード',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                              subtitle: const Text(
                                'プロバイダー別1着的中率・3連単率',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/horse-provider-leaderboard',
                              ),
                            ),
                            const SizedBox(height: 8),
                            // ギター録音スタジオ
                            const _GuitarMainFeatureBanner(),
                            const SizedBox(height: 10),
                            // 競合21社 vs 開発進捗バー (アコーディオン)
                            const CollapsibleHomeSection(
                              storageKey: 'home_section_growth_roadmap',
                              title: 'GROWTH ROADMAP',
                              icon: Icons.flag_outlined,
                              iconColor: Color(0xFF6366F1),
                              initiallyExpanded: false,
                              child: GrowthRoadmapProgressCard(),
                            ),
                            const SizedBox(height: 12),
                            if (WelcomeNewUserCard.shouldShow()) ...[
                              const WelcomeNewUserCard(),
                              const SizedBox(height: 10),
                            ],
                            const ProfileCompletionBanner(),
                            const ProfileProgressCard(),
                            const ReferralShareCard(),
                            const _PersonalityTypeBanner(),
                            const SizedBox(height: 10),
                            _buildMonthlyCashflowPriorityCard(
                              context,
                              opsSnapshot,
                              isHighlighted: highlightMonthlyFlow,
                            ),
                            const SizedBox(height: 14),
                            _buildNextActionBubble(
                              context,
                              nextAction,
                              opsSnapshot,
                              aiNudge: aiNudge,
                              isAiNudgeLoading: isAiLoading,
                            ),
                            const SizedBox(height: 14),
                            _buildForcedTaskPanel(context, opsSnapshot),
                            const SizedBox(height: 14),
                            _buildCompletionGoalPanel(
                              context,
                              opsSnapshot,
                              isHighlighted: highlightBeatYesterday,
                            ),
                            const SizedBox(height: 14),
                            _buildAbstinenceGuardPanel(context, opsSnapshot),
                            const SizedBox(height: 20),
                            _buildSectionHeader(
                              'CEO OFFICE',
                              Icons.business_center,
                              const Color(0xFFE53935),
                              key: const Key('home_section_ceo_office'),
                            ),
                            _buildCeoCard(context),
                            const SizedBox(height: 12),
                            // AI 秘書カード
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: const Color(0xFF3D5AFE)
                                      .withValues(alpha: 0.24),
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _runTrackedAction(
                                  'ai-secretary',
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const AISecretaryPage(
                                        autoRunOnOpen: true,
                                      ),
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3D5AFE)
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.support_agent,
                                          color: Color(0xFF3D5AFE),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'AI 秘書',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                height: 1.5,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '戦略提案・全部署横断指示・本日のタスク生成',
                                              style: TextStyle(
                                                fontSize: 12,
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const TimeWasteGuardWidget(),
                            _buildMorningBriefingCard(
                              context,
                              isHighlighted: highlightMorning,
                            ),
                            const SizedBox(height: 12),
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE7F6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.repeat,
                                    color: Color(0xFF4338CA),
                                  ),
                                ),
                                title: const Text(
                                  '毎日の習慣',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                subtitle: const Text(
                                  'マネフォ更新・体重記録など',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _runTrackedAction(
                                  'daily-habits',
                                  () => Navigator.pushNamed(
                                    context,
                                    '/daily-habits',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'OFFICE KPI SNAPSHOT',
                              Icons.space_dashboard,
                              const Color(0xFF3D5AFE),
                              key: const Key('home_section_office_kpi_summary'),
                            ),
                            _buildOfficeKpiSummary(
                              context,
                              isDark,
                              isCompact,
                              opsSnapshot,
                            ),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'AI FEATURE STRATEGY MONITOR',
                              Icons.auto_graph,
                              const Color(0xFF7C3AED),
                              key: const Key(
                                'home_section_feature_strategy_monitor',
                              ),
                            ),
                            _buildFeatureStrategyMonitor(isDark, isCompact),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'KPI SUMMARY',
                              Icons.show_chart,
                              const Color(0xFF3D5AFE),
                            ),
                            _buildKpiSummary(
                              context,
                              isDark,
                              isCompact,
                              opsSnapshot,
                            ),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'OPERATIONS CALENDAR',
                              Icons.calendar_month,
                              const Color(0xFFB0B0B0),
                              key:
                                  const Key('home_section_operations_calendar'),
                            ),
                            _buildCalendarPanel(context, opsSnapshot),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'SPECIAL PROJECT',
                              Icons.rocket_launch,
                              const Color(0xFF3D5AFE),
                            ),
                            Card(
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: Colors.transparent,
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF3F46CC),
                                      Color(0xFF4F46E5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x403D5AFE),
                                      blurRadius: 18,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.white,
                                    radius: 28,
                                    child: Icon(
                                      Icons.campaign,
                                      color: Color(0xFF3D5AFE),
                                      size: 30,
                                    ),
                                  ),
                                  title: const Text(
                                    '2026 衆院選 勝利戦略室',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                      height: 1.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'AI参謀と連携し、地域特性を踏まえた勝利戦略を立案します。',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      height: 1.5,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  onTap: () => _runTrackedAction(
                                    'election-strategy',
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ElectionStrategyPage(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: Colors.transparent,
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF0F766E),
                                      Color(0xFF16A34A),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x404CAF50),
                                      blurRadius: 18,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.white,
                                    radius: 28,
                                    child: Icon(
                                      Icons.how_to_vote,
                                      color: Color(0xFF4CAF50),
                                      size: 30,
                                    ),
                                  ),
                                  title: const Text(
                                    '2027 統一地方選 700必達管理室',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                      height: 1.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '県連別の純増配分と月次KPIをまとめて管理し、'
                                    '未配分ギャップや公認内定の遅れを可視化します。',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      height: 1.5,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  onTap: () => _runTrackedAction(
                                    'local-election-700',
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ElectionVictoryPage(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'QUICK ACCESS',
                              Icons.dashboard_customize,
                              const Color(0xFF3D5AFE),
                            ),
                            _buildQuickAccessMenu(
                              context,
                              isCompact,
                              shouldLockExploratoryMenus:
                                  shouldLockExploratoryMenus,
                              highlightedToolIds: highlightedToolIds,
                              badgeLabels: toolBadgeLabels,
                            ),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'RECENT TOOLS',
                              Icons.history,
                              const Color(0xFF3D5AFE),
                            ),
                            _buildRecentToolsMenu(context, isCompact),
                            const SizedBox(height: 16),
                            // 開発・成長実績 (アコーディオン / 初期折りたたみ)
                            const CollapsibleHomeSection(
                              storageKey: 'home_section_dev_achievements',
                              title: '開発・成長実績',
                              icon: Icons.bar_chart,
                              iconColor: Color(0xFF10B981),
                              initiallyExpanded: false,
                              child: DevelopmentAchievementsCard(),
                            ),
                            const SizedBox(height: 12),
                            // Edge Functions 実装状況 (アコーディオン / 初期折りたたみ)
                            const CollapsibleHomeSection(
                              storageKey: 'home_section_edge_functions',
                              title: 'Edge Functions 実装状況',
                              icon: Icons.bolt_outlined,
                              iconColor: Color(0xFF6366F1),
                              initiallyExpanded: false,
                              child: EdgeFunctionSummaryCard(),
                            ),
                            const SizedBox(height: 16),
                            _buildUiStatusButton(context),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _nav(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  Widget _buildUiStatusButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).pushNamed('/ui-design-status'),
      icon: const Icon(Icons.palette_outlined, size: 16),
      label: const Text('UI デザインステータス'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFF6B35),
        side: const BorderSide(color: Color(0xFFFF6B35)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        minimumSize: const Size(double.infinity, 44),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color, {
    Key? key,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12.0, left: 2, right: 2),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: color.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessMenu(
    BuildContext context,
    bool isCompact, {
    required bool shouldLockExploratoryMenus,
    required Set<String> highlightedToolIds,
    required Map<String, String> badgeLabels,
  }) {
    return _buildGridMenu(context, isCompact, [
      _MenuData(
        '業務メニュー',
        Icons.dashboard_customize,
        const Color(0xFF3D5AFE),
        () => _openWorkMenu(
          context,
          shouldLockExploratoryMenus: shouldLockExploratoryMenus,
          highlightedToolIds: highlightedToolIds,
          badgeLabels: badgeLabels,
        ),
      ),
      _MenuData(
        '機能を探す',
        Icons.search,
        const Color(0xFF3D5AFE),
        () => _openWorkMenu(
          context,
          shouldLockExploratoryMenus: shouldLockExploratoryMenus,
          highlightedToolIds: highlightedToolIds,
          badgeLabels: badgeLabels,
          autofocusSearch: true,
        ),
      ),
      _MenuData(
        '成長・支援',
        Icons.space_dashboard_outlined,
        const Color(0xFF009688),
        () => _runTrackedAction(
          'home-insights',
          () => Navigator.of(context).pushNamed('/home-insights'),
        ),
      ),
    ]);
  }

  Widget _buildRecentToolsMenu(BuildContext context, bool isCompact) {
    return FutureBuilder<List<String>>(
      future: _recentToolIdsFuture,
      builder: (context, snapshot) {
        final toolMap = <String, HomeToolEntry>{
          for (final entry in _buildHomeToolCatalog()) entry.id: entry,
        };
        final recentEntries = (snapshot.data ?? const <String>[])
            .map((id) => toolMap[id])
            .whereType<HomeToolEntry>()
            .take(4)
            .toList();
        if (recentEntries.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              ),
            ),
            child: const Text(
              'まだ履歴がありません。業務メニューや特別案件を開くと、ここに最近使った機能が並びます。',
              style: TextStyle(
                height: 1.5,
              ),
            ),
          );
        }
        return _buildGridMenu(
          context,
          isCompact,
          recentEntries
              .map(
                (entry) => _MenuData(
                  entry.title,
                  entry.icon,
                  entry.color,
                  () => _runTrackedAction(
                    entry.id,
                    () => entry.onOpen(context),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildCeoCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1F2937) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            Color.alphaBlend(
              const Color(0xFFE53935).withValues(alpha: isDark ? 0.16 : 0.07),
              baseColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4CE53935)),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFFE53935).withValues(alpha: isDark ? 0.16 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE53935),
          radius: 26,
          child: Icon(Icons.emergency, color: Colors.white, size: 28),
        ),
        title: const Text(
          '緊急役員会議',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        subtitle: const Text('CEOとして全AI役員を招集し、直面している課題を解決します。'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EmergencyMeetingPage(),
          ),
        ),
      ),
    );
  }

  Widget _buildMorningBriefingCard(
    BuildContext context, {
    bool isHighlighted = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final accent =
        isHighlighted ? const Color(0xFFFFA000) : const Color(0xFFFFC107);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            Color.alphaBlend(
              const Color(0xFFFFC107)
                  .withValues(alpha: isHighlighted ? 0.2 : 0.09),
              baseColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isHighlighted ? 0.18 : 0.1),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        leading: CircleAvatar(
          backgroundColor: accent,
          radius: 26,
          child: const Icon(Icons.wb_sunny, color: Colors.white, size: 28),
        ),
        title: Text(
          isHighlighted ? 'モーニング・ブリーフィング（最優先）' : 'モーニング・ブリーフィング',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        subtitle: Text(
          isHighlighted ? 'まず朝の優先順位を固定してください。' : '今日のタスクと優先順位を確認します。',
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _runTrackedAction(
          'morning-briefing',
          () => _openMorningBriefing(context),
        ),
      ),
    );
  }

  Widget _buildGridMenu(
    BuildContext context,
    bool isCompact,
    List<_MenuData> items,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isCompact ? 1 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isCompact ? 3.2 : 2.7,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final cardColor = Theme.of(context).cardColor;
        final borderColor = Theme.of(context).dividerColor.withValues(
              alpha: 0.25,
            );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: item.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: item.color.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(item.icon, color: item.color, size: 18),
                    ),
                    SizedBox(width: isCompact ? 10 : 12),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureStrategyMonitor(bool isDark, bool isCompact) {
    return FutureBuilder<FeatureStrategyReport>(
      future: _featureStrategyReportFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: const LinearProgressIndicator(minHeight: 6),
          );
        }

        final report = snapshot.data ?? FeatureStrategyReport.empty(_now());
        return FeatureStrategyMonitorPanel(
          report: report,
          isDark: isDark,
          isCompact: isCompact,
        );
      },
    );
  }

  Widget _buildOfficeKpiSummary(
    BuildContext context,
    bool isDark,
    bool isCompact,
    _HomeOpsSnapshot snapshot,
  ) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([_kpiOverviewFuture, _marketingKpiFuture]),
      builder: (context, officeSnapshot) {
        final overview =
            officeSnapshot.data != null && officeSnapshot.data!.isNotEmpty
                ? officeSnapshot.data![0] as _HomeKpiOverview? ??
                    const _HomeKpiOverview()
                : const _HomeKpiOverview();
        final marketing =
            officeSnapshot.data != null && officeSnapshot.data!.length > 1
                ? officeSnapshot.data![1] as _HomeMarketingKpiSummary? ??
                    const _HomeMarketingKpiSummary()
                : const _HomeMarketingKpiSummary();
        final nextAction = _resolveNextAction(snapshot);
        final goal = snapshot.completionGoalSnapshot;
        final coreFlowDone = [
          snapshot.monthlyCashflowSummary.reviewDone,
          snapshot.morningBriefingDone,
          snapshot.balanceCheckDone,
        ].where((value) => value).length;
        final hasAssetData = overview.hasData || overview.latestTotal > 0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = isCompact || width < 720
                ? 1
                : width < 1180
                    ? 2
                    : 3;
            const spacing = 12.0;
            final cardWidth = columns == 1
                ? width
                : (width - (spacing * (columns - 1))) / columns;

            final cards = <Widget>[
              SizedBox(
                width: cardWidth,
                child: _buildOfficeKpiCard(
                  key: const Key('home_office_kpi_card_ceo'),
                  isDark: isDark,
                  officeLabel: 'CEO',
                  title: '全体進行',
                  headline: '$coreFlowDone/3',
                  subtitle: '今日の必須導線',
                  icon: Icons.business_center,
                  accentColor: const Color(0xFFE53935),
                  metrics: <_OfficeKpiMetricItem>[
                    _OfficeKpiMetricItem('次アクション', nextAction.title),
                    _OfficeKpiMetricItem(
                      '必須タスク残',
                      '${snapshot.pendingCriticalTaskCount}件',
                    ),
                    _OfficeKpiMetricItem(
                      '前日超え目標',
                      goal.isAchieved ? '達成済み' : 'あと ${goal.remainingCount}件',
                    ),
                  ],
                  strategicPlan: _buildOfficeStrategicPlan(
                    domain: 'CEO',
                    kgi: '今日の経営必須導線を100%完了する',
                    actualLabel: '$coreFlowDone/3',
                    targetLabel: '3/3',
                    progress: coreFlowDone / 3,
                    metrics: <KgiCsfKpiMetric>[
                      KgiCsfKpiMetric.number(
                        csf: '日次統制',
                        kpi: '必須導線完了',
                        actual: coreFlowDone,
                        target: 3,
                        unit: '件',
                      ),
                      KgiCsfKpiMetric.number(
                        csf: 'リスク低減',
                        kpi: '必須タスク残の圧縮',
                        actual: math.max(
                          0,
                          5 - snapshot.pendingCriticalTaskCount,
                        ),
                        target: 5,
                        unit: '件',
                      ),
                    ],
                  ),
                  actionLabel: '役員会議へ',
                  onTap: () => _nav(context, const EmergencyMeetingPage()),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildOfficeKpiCard(
                  key: const Key('home_office_kpi_card_cfo'),
                  isDark: isDark,
                  officeLabel: 'CFO',
                  title: '財務',
                  headline:
                      hasAssetData ? _formatYen(overview.latestTotal) : '--',
                  subtitle: '総資産',
                  icon: Icons.account_balance_wallet,
                  accentColor: const Color(0xFF4CAF50),
                  metrics: <_OfficeKpiMetricItem>[
                    _OfficeKpiMetricItem(
                      '今月差額',
                      _formatSignedYen(
                        snapshot.monthlyCashflowSummary.netTotal.toDouble(),
                      ),
                    ),
                    _OfficeKpiMetricItem(
                      '記録件数',
                      '${snapshot.monthlyCashflowSummary.recordCount}件',
                    ),
                    _OfficeKpiMetricItem(
                      'レビュー',
                      snapshot.monthlyCashflowSummary.reviewDone
                          ? '確認済み'
                          : '未実施',
                    ),
                  ],
                  strategicPlan: _buildOfficeStrategicPlan(
                    domain: 'CFO',
                    kgi: '月次収支を黒字化し、資産状況を確認済みにする',
                    actualLabel: _formatSignedYen(
                      snapshot.monthlyCashflowSummary.netTotal.toDouble(),
                    ),
                    targetLabel: '黒字 / レビュー済み',
                    progress:
                        snapshot.monthlyCashflowSummary.reviewDone ? 1 : 0.5,
                    metrics: <KgiCsfKpiMetric>[
                      KgiCsfKpiMetric.number(
                        csf: '取引記録',
                        kpi: '月次記録件数',
                        actual: snapshot.monthlyCashflowSummary.recordCount,
                        target: 30,
                        unit: '件',
                      ),
                      KgiCsfKpiMetric.number(
                        csf: '決算レビュー',
                        kpi: 'レビュー完了',
                        actual:
                            snapshot.monthlyCashflowSummary.reviewDone ? 1 : 0,
                        target: 1,
                        unit: '回',
                      ),
                    ],
                  ),
                  actionLabel: '収支を見る',
                  onTap: () => _nav(context, const AssetManagementPage()),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildOfficeKpiCard(
                  key: const Key('home_office_kpi_card_cmo'),
                  isDark: isDark,
                  officeLabel: 'CMO',
                  title: 'マーケティング',
                  headline: marketing.totalUsers > 0
                      ? '${marketing.totalUsers}人'
                      : '--',
                  subtitle: '総ユーザー数',
                  icon: Icons.campaign,
                  accentColor: const Color(0xFFFF6B35),
                  metrics: <_OfficeKpiMetricItem>[
                    _OfficeKpiMetricItem(
                      '今日のLP View',
                      '${marketing.todayViews}',
                    ),
                    _OfficeKpiMetricItem(
                      '今日の登録/CVR',
                      '${marketing.todayRegistrations}件 (${marketing.todayCvrLabel})',
                    ),
                    _OfficeKpiMetricItem(
                      'シェア/チャネル',
                      '${marketing.todayShares}件 ${_shareChannelLabel(marketing.topShareChannelKey)}',
                    ),
                  ],
                  strategicPlan: _buildOfficeStrategicPlan(
                    domain: 'CMO',
                    kgi: 'α版50ユーザー到達に向けて日次獲得導線を回す',
                    actualLabel: '${marketing.totalUsers}人',
                    targetLabel: '50人',
                    progress: marketing.totalUsers / 50,
                    metrics: <KgiCsfKpiMetric>[
                      KgiCsfKpiMetric.number(
                        csf: '流入獲得',
                        kpi: '今日のLP View',
                        actual: marketing.todayViews,
                        target: 100,
                        unit: '件',
                      ),
                      KgiCsfKpiMetric.number(
                        csf: '登録転換',
                        kpi: '今日の登録',
                        actual: marketing.todayRegistrations,
                        target: 1,
                        unit: '件',
                      ),
                      KgiCsfKpiMetric.number(
                        csf: '拡散',
                        kpi: '今日のシェア',
                        actual: marketing.todayShares,
                        target: 3,
                        unit: '件',
                      ),
                    ],
                  ),
                  bottomWidget: marketing.lpSeries.length >= 2
                      ? _buildLpSparkline(marketing.lpSeries, isDark)
                      : null,
                  actionLabel: '分析を見る',
                  onTap: () => _nav(context, const AdminAnalyticsPage()),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildOfficeKpiCard(
                  key: const Key('home_office_kpi_card_cho'),
                  isDark: isDark,
                  officeLabel: 'CHO',
                  title: '集中防衛',
                  headline: '${snapshot.abstinenceFocusCount}件',
                  subtitle: '遮断中の邪魔',
                  icon: Icons.shield_moon,
                  accentColor: const Color(0xFF009688),
                  metrics: <_OfficeKpiMetricItem>[
                    _OfficeKpiMetricItem(
                      '逸脱回数',
                      '${snapshot.abstinenceSlipCount}回',
                    ),
                    _OfficeKpiMetricItem(
                      '主犯候補',
                      snapshot.abstinencePrimaryLabel ?? '未検出',
                    ),
                    _OfficeKpiMetricItem(
                      '切断サイン',
                      snapshot.abstinencePrimarySignal ?? '監視中',
                    ),
                  ],
                  strategicPlan: _buildOfficeStrategicPlan(
                    domain: 'CHO',
                    kgi: '集中を阻害する行動を日次で抑止する',
                    actualLabel: '${snapshot.abstinenceFocusCount}件遮断中',
                    targetLabel: '逸脱0回',
                    progress: snapshot.abstinenceSlipCount == 0 ? 1 : 0.4,
                    metrics: <KgiCsfKpiMetric>[
                      KgiCsfKpiMetric.number(
                        csf: '誘惑遮断',
                        kpi: '遮断中の邪魔',
                        actual: snapshot.abstinenceFocusCount,
                        target: 3,
                        unit: '件',
                      ),
                      KgiCsfKpiMetric.number(
                        csf: '逸脱抑止',
                        kpi: '逸脱0回',
                        actual: snapshot.abstinenceSlipCount == 0 ? 1 : 0,
                        target: 1,
                        unit: '日',
                      ),
                    ],
                  ),
                  actionLabel: '抑止設定へ',
                  onTap: () => _openAbstinenceGuard(context),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildOfficeKpiCard(
                  key: const Key('home_office_kpi_card_chro'),
                  isDark: isDark,
                  officeLabel: 'CHRO',
                  title: '実行管理',
                  headline: '${goal.todayCompletedCount}/${goal.targetCount}',
                  subtitle: '今日の完了数 / 目標',
                  icon: Icons.groups_2,
                  accentColor: const Color(0xFF3D5AFE),
                  metrics: <_OfficeKpiMetricItem>[
                    _OfficeKpiMetricItem(
                      '昨日の完了',
                      '${goal.yesterdayCompletedCount}件',
                    ),
                    _OfficeKpiMetricItem(
                      '残り',
                      goal.isAchieved ? '達成済み' : '${goal.remainingCount}件',
                    ),
                    _OfficeKpiMetricItem(
                      '重要タスク残',
                      '${snapshot.pendingCriticalTaskCount}件',
                    ),
                  ],
                  strategicPlan: _buildOfficeStrategicPlan(
                    domain: 'CHRO',
                    kgi: '今日の完了数を前日以上にする',
                    actualLabel:
                        '${goal.todayCompletedCount}/${goal.targetCount}',
                    targetLabel: '${goal.targetCount}件',
                    progress: goal.targetCount <= 0
                        ? 0
                        : goal.todayCompletedCount / goal.targetCount,
                    metrics: <KgiCsfKpiMetric>[
                      KgiCsfKpiMetric.number(
                        csf: '実行完了',
                        kpi: '今日の完了数',
                        actual: goal.todayCompletedCount,
                        target: goal.targetCount,
                        unit: '件',
                      ),
                      KgiCsfKpiMetric.number(
                        csf: '重要タスク処理',
                        kpi: '重要タスク残の圧縮',
                        actual: math.max(
                          0,
                          5 - snapshot.pendingCriticalTaskCount,
                        ),
                        target: 5,
                        unit: '件',
                      ),
                    ],
                  ),
                  actionLabel: 'タスクを見る',
                  onTap: () => _openMorningBriefing(context),
                ),
              ),
            ];

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: cards,
            );
          },
        );
      },
    );
  }

  KgiCsfKpiPlan _buildOfficeStrategicPlan({
    required String domain,
    required String kgi,
    required String actualLabel,
    required String targetLabel,
    required double progress,
    required List<KgiCsfKpiMetric> metrics,
  }) {
    return KgiCsfKpiPlan(
      domain: domain,
      kgi: kgi,
      actualLabel: actualLabel,
      targetLabel: targetLabel,
      progress: progress.clamp(0, 1).toDouble(),
      metrics: metrics,
    );
  }

  Widget _buildOfficeKpiCard({
    required Key key,
    required bool isDark,
    required String officeLabel,
    required String title,
    required String headline,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<_OfficeKpiMetricItem> metrics,
    required String actionLabel,
    required VoidCallback onTap,
    KgiCsfKpiPlan? strategicPlan,
    Widget? bottomWidget,
  }) {
    final baseColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.65);
    final titleColor = isDark ? Colors.white : const Color(0xDE000000);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 232),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                Color.alphaBlend(
                  accentColor.withValues(alpha: isDark ? 0.16 : 0.09),
                  baseColor,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        officeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(icon, color: accentColor, size: 20),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                    height: 1.5,
                  ),
                ),
                if (strategicPlan != null) ...[
                  const SizedBox(height: 10),
                  KgiCsfKpiPanel(
                    plan: strategicPlan,
                    accentColor: accentColor,
                    dense: true,
                    dark: isDark,
                  ),
                ],
                const SizedBox(height: 12),
                ...metrics
                    .take(3)
                    .map((metric) => _buildOfficeKpiMetricRow(metric, isDark)),
                if (bottomWidget != null) ...[
                  const SizedBox(height: 8),
                  bottomWidget,
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(actionLabel),
                    style: TextButton.styleFrom(
                      foregroundColor: accentColor,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeKpiMetricRow(
    _OfficeKpiMetricItem metric,
    bool isDark,
  ) {
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);
    final valueColor = isDark ? Colors.white : const Color(0xDE000000);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              metric.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: labelColor,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              metric.value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: valueColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLpSparkline(List<_LpSeriesEntry> series, bool isDark) {
    final spots = <FlSpot>[];
    for (var i = 0; i < series.length; i++) {
      spots.add(FlSpot(i.toDouble(), series[i].count.toDouble()));
    }
    final lineColor =
        isDark ? const Color(0xFFFF6B35) : const Color(0xFFFF6B35);
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '7日間 LP View 推移',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: labelColor,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: lineColor,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                      radius: spot.x == spots.last.x ? 3 : 0,
                      color: lineColor,
                      strokeColor: Colors.transparent,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: lineColor.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // KPIサマリー
  Widget _buildKpiSummary(
    BuildContext context,
    bool isDark,
    bool isCompact,
    _HomeOpsSnapshot snapshot,
  ) {
    return FutureBuilder<_HomeKpiOverview>(
      future: _kpiOverviewFuture,
      builder: (context, kpiSnapshot) {
        final overview = kpiSnapshot.data;
        if (overview == null || !overview.hasData) {
          return _buildLegacyKpiSummary(context, isDark, isCompact, snapshot);
        }

        final latest = overview.latestTotal;
        final dayDelta = overview.dayDelta;
        final dayRate = _ratioFromBase(dayDelta, overview.previousTotal);
        final weekDelta = overview.weekDelta;
        final weekRate = _ratioFromBase(weekDelta, overview.weekBaseTotal);
        final monthDelta = overview.monthDelta;
        final monthRate = _ratioFromBase(monthDelta, overview.monthBaseTotal);
        final yearDelta = overview.yearDelta;
        final yearRate = _ratioFromBase(yearDelta, overview.yearBaseTotal);
        final filteredTrend = _filterKpiTrendPoints(overview.trendPoints);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F1F3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '総資産',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 2,
                color: const Color(0xFFF57C00),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_formatYen(latest)} (前日比) ${_formatSignedYen(dayDelta)} (${_formatSignedPercent(dayRate)})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildKpiTableCard(
                    context,
                    title: '増減',
                    isDark: isDark,
                    flexes: const [1.2, 1.1, 1.5],
                    rows: [
                      [
                        '今週',
                        _formatSignedPercent(weekRate),
                        _formatSignedYen(weekDelta),
                      ],
                      [
                        '今月',
                        _formatSignedPercent(monthRate),
                        _formatSignedYen(monthDelta),
                      ],
                      [
                        '今年',
                        _formatSignedPercent(yearRate),
                        _formatSignedYen(yearDelta),
                      ],
                    ],
                  ),
                  _buildKpiTableCard(
                    context,
                    title: '内訳',
                    isDark: isDark,
                    flexes: const [2.0, 1.2, 1.0],
                    rows: [
                      [
                        '預金・現金・暗号資産',
                        _formatYen(overview.cashAndCryptoTotal),
                        _formatPercentRatio(
                          overview.cashAndCryptoTotal,
                          latest,
                        ),
                      ],
                      [
                        '株式(現物)',
                        _formatYen(overview.equityTotal),
                        _formatPercentRatio(
                          overview.equityTotal,
                          latest,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _nav(context, const CfoOfficePage()),
                  icon: const Icon(Icons.arrow_circle_right, size: 18),
                  label: const Text('詳細(資産内訳)を見る'),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '資産の時系列推移',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 2,
                color: const Color(0xFFF57C00),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _KpiTrendRange.values.map((range) {
                    final isSelected = _kpiTrendRange == range;
                    return InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        setState(() {
                          _kpiTrendRange = range;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : Colors.white)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.white.withValues(alpha: 0.74)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF6B35)
                                    .withValues(alpha: 0.62)
                                : const Color(0xFFB0B0B0)
                                    .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          _kpiTrendRangeLabel(range),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              _buildKpiTrendChart(
                isDark: isDark,
                points: filteredTrend,
              ),
              if (overview.hasWasteData) ...[
                const SizedBox(height: 14),
                _buildWasteOverviewSection(
                  isDark: isDark,
                  overview: overview,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegacyKpiSummary(
    BuildContext context,
    bool isDark,
    bool isCompact,
    _HomeOpsSnapshot snapshot,
  ) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isCompact ? 1 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: isCompact ? 130 : 150,
      ),
      children: [
        _buildAsyncKpiCard(
          context,
          isDark,
          '総資産 (CFO)',
          Icons.account_balance,
          const Color(0xFF4CAF50),
          _totalAssetsFuture,
        ),
        _buildKpiCard(
          context,
          isDark,
          '禁欲フォーカス',
          '${snapshot.abstinenceFocusCount}件',
          Icons.shield_moon,
          const Color(0xFFE53935),
        ),
        _buildKpiCard(
          context,
          isDark,
          '必須タスク残',
          '${snapshot.pendingCriticalTaskCount}件',
          Icons.lock_clock,
          const Color(0xFF3D5AFE),
        ),
        _buildKpiCard(
          context,
          isDark,
          '週末ストック残',
          '${snapshot.pendingStockTaskCount}件',
          Icons.inventory_2,
          const Color(0xFF009688),
        ),
      ],
    );
  }

  Widget _buildKpiTableCard(
    BuildContext context, {
    required String title,
    required bool isDark,
    required List<List<String>> rows,
    required List<double> flexes,
  }) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : const Color(0xFFB0B0B0).withValues(alpha: 0.24);
    final titleColor =
        isDark ? Colors.white : Colors.black.withValues(alpha: 0.86);

    return Container(
      constraints: const BoxConstraints(minWidth: 330),
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: titleColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            color: const Color(0xFFF57C00),
          ),
          const SizedBox(height: 4),
          Table(
            border: TableBorder.all(color: borderColor),
            columnWidths: {
              for (var i = 0; i < flexes.length; i++)
                i: FlexColumnWidth(flexes[i]),
            },
            children: rows.map((row) {
              return TableRow(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.7),
                ),
                children: row.map((cell) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Text(
                      cell,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTrendChart({
    required bool isDark,
    required List<_KpiTrendPoint> points,
  }) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(child: Text('資産推移データがありません')),
      );
    }

    final assetSpots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].total),
    ];
    final hasWasteSeries = points.any((point) => point.waste > 0);

    var minY = points.first.total;
    var maxY = points.first.total;
    for (final point in points) {
      minY = math.min(minY, point.total);
      maxY = math.max(maxY, point.total);
    }
    final ySpan = (maxY - minY).abs();
    final yPadding = math.max(ySpan * 0.14, 10000);
    final chartMinY = minY - yPadding;
    final chartMaxY = maxY + yPadding;
    final wasteMax = hasWasteSeries
        ? points.fold<double>(
            0,
            (currentMax, point) => math.max(currentMax, point.waste),
          )
        : 0.0;

    double mapWasteToPrimaryAxis(double value) {
      if (!hasWasteSeries || wasteMax <= 0) {
        return chartMinY;
      }
      return chartMinY + (value / wasteMax) * (chartMaxY - chartMinY);
    }

    final wasteSpots = hasWasteSeries
        ? <FlSpot>[
            for (var i = 0; i < points.length; i++)
              FlSpot(i.toDouble(), mapWasteToPrimaryAxis(points[i].waste)),
          ]
        : const <FlSpot>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildTrendLegendChip(
              isDark: isDark,
              label: '資産',
              color: const Color(0xFFE53935),
            ),
            if (hasWasteSeries)
              _buildTrendLegendChip(
                isDark: isDark,
                label: '浪費',
                color: const Color(0xFFFFAB40),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (assetSpots.length - 1).toDouble(),
              minY: chartMinY,
              maxY: chartMaxY,
              backgroundColor: isDark
                  ? Colors.black.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.72),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _kpiChartHorizontalInterval(
                  chartMaxY - chartMinY,
                ),
                getDrawingHorizontalLine: (_) {
                  return FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: hasWasteSeries,
                    reservedSize: 62,
                    interval:
                        hasWasteSeries ? (chartMaxY - chartMinY) / 4 : null,
                    getTitlesWidget: (value, meta) {
                      if (!hasWasteSeries || wasteMax <= 0) {
                        return const SizedBox.shrink();
                      }
                      final normalized =
                          ((value - chartMinY) / (chartMaxY - chartMinY))
                              .clamp(0.0, 1.0)
                              .toDouble();
                      final wasteValue = normalized * wasteMax;
                      return Text(
                        _formatCompactYen(wasteValue),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0x8A000000),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.right,
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 54,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        _formatManLabel(value),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0x8A000000),
                          height: 1.5,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final isEdge = index == 0 || index == points.length - 1;
                      final isMiddle = index == points.length ~/ 2;
                      if (!isEdge && !isMiddle) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          DateFormat('M/d').format(points[index].date),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : const Color(0x8A000000),
                            height: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.2),
                  ),
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.2),
                  ),
                  right: hasWasteSeries
                      ? BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.black.withValues(alpha: 0.14),
                        )
                      : BorderSide.none,
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => isDark
                      ? Colors.black.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.95),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final idx = spot.x.toInt();
                      final point = points[idx];
                      final isWasteSpot = spot.barIndex == 1;
                      return LineTooltipItem(
                        isWasteSpot
                            ? '浪費 ${DateFormat('yyyy/MM/dd').format(point.date)}\n${_formatYen(point.waste)}'
                            : '資産 ${DateFormat('yyyy/MM/dd').format(point.date)}\n${_formatYen(point.total)}',
                        TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xDE000000),
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: assetSpots,
                  isCurved: false,
                  color: const Color(0xFFE53935),
                  barWidth: 2.8,
                  dotData: FlDotData(show: assetSpots.length <= 40),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.6),
                        const Color(0xFF6366F1).withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
                if (hasWasteSeries)
                  LineChartBarData(
                    spots: wasteSpots,
                    isCurved: false,
                    color: const Color(0xFFFFAB40),
                    barWidth: 2.4,
                    dashArray: const [8, 4],
                    dotData: FlDotData(show: wasteSpots.length <= 40),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendLegendChip({
    required bool isDark,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteOverviewSection({
    required bool isDark,
    required _HomeKpiOverview overview,
  }) {
    final breakdownEntries = overview.wasteBreakdown.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (breakdownEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = <Color>[
      const Color(0xFFFF6B35),
      const Color(0xFFE53935),
      const Color(0xFF3D5AFE),
      const Color(0xFF009688),
      const Color(0xFF3D5AFE),
      const Color(0xFF6366F1),
      const Color(0xFF4CAF50),
      const Color(0xFF78716C),
      const Color(0xFFFF6B35),
      const Color(0xFFFFC107),
      const Color(0xFF3D5AFE),
    ];
    final total = breakdownEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.value,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '浪費の内訳',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildWasteMetricCard(
                isDark: isDark,
                title: '累計浪費',
                value: _formatYen(overview.totalWaste),
                accent: const Color(0xFFFF6B35),
              ),
              _buildWasteMetricCard(
                isDark: isDark,
                title: '記録件数',
                value: '${overview.wasteRecordCount}件',
                accent: const Color(0xFFE53935),
              ),
              _buildWasteMetricCard(
                isDark: isDark,
                title: '最大カテゴリ',
                value: overview.topWasteCategory ?? '--',
                accent: const Color(0xFFB0B0B0),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 720;
              final pieChart = SizedBox(
                width: 240,
                height: 240,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 42,
                    sections: [
                      for (var i = 0; i < breakdownEntries.length; i++)
                        PieChartSectionData(
                          color: palette[i % palette.length],
                          value: breakdownEntries[i].value,
                          radius: 72,
                          title: breakdownEntries[i].value / total >= 0.08
                              ? '${(breakdownEntries[i].value / total * 100).toStringAsFixed(0)}%'
                              : '',
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),
              );
              final legend = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < breakdownEntries.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.white.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: palette[i % palette.length].withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: palette[i % palette.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            breakdownEntries[i].key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatYen(breakdownEntries[i].value),
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : const Color(0x8A000000),
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );

              if (isNarrow) {
                return Column(
                  children: [
                    pieChart,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: legend),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  pieChart,
                  const SizedBox(width: 18),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWasteMetricCard({
    required bool isDark,
    required String title,
    required String value,
    required Color accent,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : const Color(0x8A000000),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _kpiTrendRangeLabel(_KpiTrendRange range) {
    return switch (range) {
      _KpiTrendRange.oneMonth => '1ヶ月',
      _KpiTrendRange.threeMonths => '3ヶ月',
      _KpiTrendRange.sixMonths => '6ヶ月',
      _KpiTrendRange.oneYear => '1年',
      _KpiTrendRange.all => '全期間',
    };
  }

  List<_KpiTrendPoint> _filterKpiTrendPoints(List<_KpiTrendPoint> points) {
    if (points.isEmpty) return const <_KpiTrendPoint>[];

    final today = _startOfDay(_now());
    DateTime? lowerBound;
    switch (_kpiTrendRange) {
      case _KpiTrendRange.oneMonth:
        lowerBound = today.subtract(const Duration(days: 30));
        break;
      case _KpiTrendRange.threeMonths:
        lowerBound = today.subtract(const Duration(days: 90));
        break;
      case _KpiTrendRange.sixMonths:
        lowerBound = today.subtract(const Duration(days: 180));
        break;
      case _KpiTrendRange.oneYear:
        lowerBound = today.subtract(const Duration(days: 365));
        break;
      case _KpiTrendRange.all:
        lowerBound = null;
        break;
    }

    if (lowerBound == null) return points;
    final filtered = points
        .where((point) => !_startOfDay(point.date).isBefore(lowerBound!))
        .toList();
    if (filtered.length >= 2) return filtered;
    if (points.length >= 2) {
      return points.sublist(math.max(0, points.length - 2));
    }
    return points;
  }

  double? _ratioFromBase(double? delta, double? base) {
    if (delta == null || base == null || base == 0) {
      return null;
    }
    return delta / base.abs();
  }

  String _formatYen(double value) {
    return '${NumberFormat('#,##0', 'ja_JP').format(value.round())}円';
  }

  String _formatSignedYen(double? value) {
    if (value == null) return '--';
    final rounded = value.round();
    if (rounded == 0) return '0円';
    final absText = NumberFormat('#,##0', 'ja_JP').format(rounded.abs());
    final sign = rounded > 0 ? '+' : '-';
    return '$sign$absText円';
  }

  String _formatSignedPercent(double? ratio) {
    if (ratio == null) return '--';
    final percent = ratio * 100;
    final absText = percent.abs().toStringAsFixed(1);
    final sign = percent > 0
        ? '+'
        : percent < 0
            ? '-'
            : '';
    return '$sign$absText%';
  }

  String _formatCompactYen(double value) {
    final absValue = value.abs();
    if (absValue >= 10000) {
      final man = value / 10000;
      final digits = man.abs() >= 100 ? 0 : 1;
      return '${man.toStringAsFixed(digits)}万';
    }
    return '${NumberFormat('#,##0', 'ja_JP').format(value.round())}円';
  }

  String _formatCalendarCashflowAmount(int value) {
    final absValue = value.abs();
    if (absValue >= 10000) {
      final man = absValue / 10000;
      final digits = man >= 100 ? 0 : 1;
      return '${man.toStringAsFixed(digits)}万';
    }
    return NumberFormat('#,##0', 'ja_JP').format(absValue);
  }

  String _formatPercentRatio(double part, double total) {
    if (total == 0) return '--';
    return '${(part / total * 100).toStringAsFixed(2)}%';
  }

  double _kpiChartHorizontalInterval(double range) {
    if (range <= 80000) return 20000;
    if (range <= 200000) return 50000;
    if (range <= 500000) return 100000;
    if (range <= 1000000) return 200000;
    return 500000;
  }

  String _formatManLabel(double value) {
    final man = value / 10000;
    if (man.abs() >= 100) {
      return '${man.toStringAsFixed(0)}万円';
    }
    return '${man.toStringAsFixed(1)}万円';
  }

  // 非同期データ用KPIカード
  Widget _buildAsyncKpiCard(
    BuildContext context,
    bool isDark,
    String title,
    IconData icon,
    Color color,
    Future<String> futureValue,
  ) {
    return FutureBuilder<String>(
      future: futureValue,
      builder: (context, snapshot) {
        // ローディング中はインジケータ
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final displayValue = snapshot.hasError
            ? 'Error'
            : (snapshot.data == null || snapshot.data!.isEmpty)
                ? '¥0'
                : snapshot.data!;

        return _buildKpiCard(
          context,
          isDark,
          title,
          displayValue,
          icon,
          color,
        );
      },
    );
  }

  // 通常のKPIカード
  Widget _buildKpiCard(
    BuildContext context,
    bool isDark,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);
    final base = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base,
            Color.alphaBlend(
              color.withValues(alpha: isDark ? 0.14 : 0.08),
              base,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// 時計表示（独立Widget）
class _MenuData {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _MenuData(
    this.title,
    this.icon,
    this.color,
    this.onTap,
  );
}

enum _HomeActionType {
  abstinenceGuard,
  monthlyFlowReview,
  morningBriefing,
  balanceCheck,
  criticalTasks,
  beatYesterdayGoal,
  stockReview,
  none,
}

enum _CalendarHighlightFilter {
  all,
  slip,
  clean,
  unset,
}

enum _CalendarTaskPreviewFilter {
  all,
  incompleteOnly,
  importantOnly,
}

enum _KpiTrendRange {
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  all,
}

enum _AssetBucket {
  cashAndCrypto,
  equity,
  other,
}

class _HomeActionCommand {
  final _HomeActionType type;
  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  const _HomeActionCommand({
    required this.type,
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

class _HomeDailyStatusRecord {
  final bool morningBriefingDone;
  final bool balanceCheckDone;

  const _HomeDailyStatusRecord({
    this.morningBriefingDone = false,
    this.balanceCheckDone = false,
  });
}

class _KpiTrendPoint {
  final DateTime date;
  final double total;
  final double waste;

  const _KpiTrendPoint({
    required this.date,
    required this.total,
    this.waste = 0,
  });
}

class _HomeKpiOverview {
  final double latestTotal;
  final double previousTotal;
  final double? weekBaseTotal;
  final double? monthBaseTotal;
  final double? yearBaseTotal;
  final double cashAndCryptoTotal;
  final double equityTotal;
  final List<_KpiTrendPoint> trendPoints;
  final double totalWaste;
  final int wasteRecordCount;
  final Map<String, double> wasteBreakdown;

  const _HomeKpiOverview({
    this.latestTotal = 0,
    this.previousTotal = 0,
    this.weekBaseTotal,
    this.monthBaseTotal,
    this.yearBaseTotal,
    this.cashAndCryptoTotal = 0,
    this.equityTotal = 0,
    this.trendPoints = const [],
    this.totalWaste = 0,
    this.wasteRecordCount = 0,
    this.wasteBreakdown = const <String, double>{},
  });

  bool get hasData => trendPoints.isNotEmpty;
  bool get hasWasteData => totalWaste > 0 && wasteBreakdown.isNotEmpty;
  double get dayDelta => latestTotal - previousTotal;
  double? get weekDelta =>
      weekBaseTotal == null ? null : latestTotal - weekBaseTotal!;
  double? get monthDelta =>
      monthBaseTotal == null ? null : latestTotal - monthBaseTotal!;
  double? get yearDelta =>
      yearBaseTotal == null ? null : latestTotal - yearBaseTotal!;

  String? get topWasteCategory {
    if (wasteBreakdown.isEmpty) return null;
    final sorted = wasteBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
}

class _HomeMarketingKpiSummary {
  final int todayViews;
  final int todayRegistrations;
  final int todayShares;
  final String? topShareChannelKey;
  final int totalUsers;
  final List<_LpSeriesEntry> lpSeries;

  const _HomeMarketingKpiSummary({
    this.todayViews = 0,
    this.todayRegistrations = 0,
    this.todayShares = 0,
    this.topShareChannelKey,
    this.totalUsers = 0,
    this.lpSeries = const [],
  });

  double get todayCvr =>
      todayViews == 0 ? 0 : (todayRegistrations / todayViews) * 100;

  String get todayCvrLabel => '${todayCvr.toStringAsFixed(1)}%';
}

class _LpSeriesEntry {
  final String date;
  final int count;

  const _LpSeriesEntry({required this.date, required this.count});
}

class _HomeMonthlyCashflowSummary {
  final DateTime? month;
  final int incomeTotal;
  final int expenseTotal;
  final int incomeCount;
  final int expenseCount;
  final bool reviewDone;
  final DateTime? lastRecordedAt;

  const _HomeMonthlyCashflowSummary({
    this.month,
    this.incomeTotal = 0,
    this.expenseTotal = 0,
    this.incomeCount = 0,
    this.expenseCount = 0,
    this.reviewDone = false,
    this.lastRecordedAt,
  });

  int get netTotal => incomeTotal - expenseTotal;

  int get recordCount => incomeCount + expenseCount;

  bool get needsReview => !reviewDone;

  String get monthLabel =>
      month == null ? '今月' : DateFormat('M月').format(month!);

  String get summaryLine {
    if (recordCount == 0) {
      return '$monthLabelの収支がまだ記録されていません。先に全体像を把握してください。';
    }
    if (incomeCount == 0) {
      return '$monthLabelは支出のみ記録されています。収入側も含めて差額を確認してください。';
    }
    if (expenseCount == 0) {
      return '$monthLabelは収入のみ記録されています。支出側も含めて差額を確認してください。';
    }
    final netLabel = netTotal >= 0 ? '黒字' : '赤字';
    return '$monthLabelの収入${NumberFormat('#,##0').format(incomeTotal)}円、支出${NumberFormat('#,##0').format(expenseTotal)}円、差額${NumberFormat('#,##0').format(netTotal.abs())}円の$netLabelです。';
  }
}

class _OfficeKpiMetricItem {
  final String label;
  final String value;

  const _OfficeKpiMetricItem(this.label, this.value);
}

class _HomeOpsSnapshot {
  final bool morningBriefingDone;
  final bool balanceCheckDone;
  final _HomeMonthlyCashflowSummary monthlyCashflowSummary;
  final DailyCompletionGoalSnapshot completionGoalSnapshot;
  final int pendingCriticalTaskCount;
  final int pendingStockTaskCount;
  final int abstinenceFocusCount;
  final int abstinenceSlipCount;
  final List<String> abstinenceSlipDetails;
  final List<String> abstinenceTopLabels;
  final String? abstinencePrimaryLabel;
  final String? abstinencePrimarySignal;
  final String? abstinencePrimaryAction;
  final int abstinenceDisciplineRepCount;
  final int abstinenceDisciplineMoneySaved;
  final int abstinenceDisciplineTimeSavedMinutes;
  final int abstinenceDisciplineStreakDays;
  final String abstinenceDisciplineStageLabel;
  final List<_HomeCalendarDay> calendarDays;

  const _HomeOpsSnapshot({
    this.morningBriefingDone = false,
    this.balanceCheckDone = false,
    this.monthlyCashflowSummary = const _HomeMonthlyCashflowSummary(),
    this.completionGoalSnapshot = const DailyCompletionGoalSnapshot(
      todayCompletedCount: 0,
      yesterdayCompletedCount: 0,
    ),
    this.pendingCriticalTaskCount = 0,
    this.pendingStockTaskCount = 0,
    this.abstinenceFocusCount = 0,
    this.abstinenceSlipCount = 0,
    this.abstinenceSlipDetails = const [],
    this.abstinenceTopLabels = const [],
    this.abstinencePrimaryLabel,
    this.abstinencePrimarySignal,
    this.abstinencePrimaryAction,
    this.abstinenceDisciplineRepCount = 0,
    this.abstinenceDisciplineMoneySaved = 0,
    this.abstinenceDisciplineTimeSavedMinutes = 0,
    this.abstinenceDisciplineStreakDays = 0,
    this.abstinenceDisciplineStageLabel = '未着手',
    this.calendarDays = const [],
  });
}

class _HomeCalendarDay {
  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isFuture;
  final bool morningDone;
  final bool balanceDone;
  final int pendingCriticalTaskCount;
  final bool hasAbstinenceProtection;
  final bool hasAbstinenceSlip;
  final bool isSaturday;
  final List<String> enabledLabels;
  final List<String> slipDetails;
  final List<String> missingItems;
  final String relapsePreventionAction;
  final _HomeDailyCashflowSummary cashflow;
  final List<_HomeCalendarTask> tasks;

  const _HomeCalendarDay({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isFuture,
    required this.morningDone,
    required this.balanceDone,
    required this.pendingCriticalTaskCount,
    required this.hasAbstinenceProtection,
    required this.hasAbstinenceSlip,
    required this.isSaturday,
    required this.enabledLabels,
    required this.slipDetails,
    required this.missingItems,
    required this.relapsePreventionAction,
    this.cashflow = const _HomeDailyCashflowSummary(),
    this.tasks = const <_HomeCalendarTask>[],
  });

  bool get hasCashflow => cashflow.hasCashflow;

  int get totalTaskCount => tasks.length;

  int get completedTaskCount => tasks.where((task) => task.isCompleted).length;
}

class _HomeDailyCashflowSummary {
  final int incomeTotal;
  final int expenseTotal;
  final int transferTotal;
  final int incomeCount;
  final int expenseCount;
  final int transferCount;

  const _HomeDailyCashflowSummary({
    this.incomeTotal = 0,
    this.expenseTotal = 0,
    this.transferTotal = 0,
    this.incomeCount = 0,
    this.expenseCount = 0,
    this.transferCount = 0,
  });

  _HomeDailyCashflowSummary copyWith({
    int? incomeTotal,
    int? expenseTotal,
    int? transferTotal,
    int? incomeCount,
    int? expenseCount,
    int? transferCount,
  }) {
    return _HomeDailyCashflowSummary(
      incomeTotal: incomeTotal ?? this.incomeTotal,
      expenseTotal: expenseTotal ?? this.expenseTotal,
      transferTotal: transferTotal ?? this.transferTotal,
      incomeCount: incomeCount ?? this.incomeCount,
      expenseCount: expenseCount ?? this.expenseCount,
      transferCount: transferCount ?? this.transferCount,
    );
  }

  int get recordCount => incomeCount + expenseCount;

  int get netTotal => incomeTotal - expenseTotal;

  bool get hasCashflow => recordCount > 0;

  bool get hasAnyEntry => hasCashflow || transferCount > 0;
}

enum _HomeCalendarTaskSource {
  dailyTodo,
  mindless,
}

class _HomeCalendarTask {
  final String id;
  final String title;
  final bool isCompleted;
  final bool isImportant;
  final _HomeCalendarTaskSource source;
  final String? secondaryLabel;
  final int sortOrder;

  const _HomeCalendarTask({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.isImportant,
    required this.source,
    required this.sortOrder,
    this.secondaryLabel,
  });
}

class _CalendarLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _CalendarLegend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF666666),
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _CalendarDayStatus {
  final String label;
  final String detail;
  final Color color;
  final IconData icon;

  const _CalendarDayStatus({
    required this.label,
    required this.detail,
    required this.color,
    required this.icon,
  });
}

class _PersonalityTypeBanner extends StatelessWidget {
  const _PersonalityTypeBanner();

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder(
      future: PersonalityTestService().getLatestTestResult(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final test = snapshot.data;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        if (test != null && test.personalityType != null) {
          final typeCode = test.personalityType!;
          final details =
              PersonalityTestService().getPersonalityTypeDetails(typeCode);
          return Card(
            elevation: 0,
            color: isDark
                ? const Color(0xFF2E1065).withValues(alpha: 0.47)
                : const Color(0xFFF3E8FF),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF4C1D95).withValues(alpha: 0.55)
                      : const Color(0xFFDDD6FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology_alt,
                  color: Color(0xFF7C3AED),
                ),
              ),
              title: Text(
                '性格タイプ: $typeCode — ${details.nameJa}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              subtitle: Text(
                details.noteAdvice.first,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => Navigator.of(context)
                  .pushNamed('/personality-test-result', arguments: test.id),
            ),
          );
        }
        return Card(
          elevation: 0,
          color: isDark
              ? const Color(0xFF2E1065).withValues(alpha: 0.47)
              : const Color(0xFFF3E8FF),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF4C1D95).withValues(alpha: 0.55)
                    : const Color(0xFFDDD6FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.psychology_alt_outlined,
                color: Color(0xFF7C3AED),
              ),
            ),
            title: const Text(
              '性格診断 (16タイプ)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            subtitle: const Text(
              'あなたの性格タイプに合ったメモ術・学習スタイルを診断',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.of(context)
                .pushNamed('/personality-test', arguments: 1),
          ),
        );
      },
    );
  }
}

/// ホーム画面最上部に表示するギター録音スタジオへの導線バナー (メイン機能)
class _GuitarMainFeatureBanner extends StatelessWidget {
  const _GuitarMainFeatureBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/guitar-recording-studio'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF6B35), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFFF6B35),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.music_note,
                color: Color(0xFFFF6B35),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'ギター録音スタジオ 🎸',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(width: 8),
                      _MainFeatureBadge(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'スマホで演奏を録音・保存・メトロノーム・コード辞典・AI分析',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFFFF6B35),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _MainFeatureBadge extends StatelessWidget {
  const _MainFeatureBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'MAIN',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          height: 1.5,
        ),
      ),
    );
  }
}
