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
import '../services/theme_service.dart';
import '../services/waste_tracking_service.dart';

// Pages
import 'abstinence_guard_page.dart';
import 'note_editor_page.dart';
import 'note_list_page.dart';
import 'ai_status_page.dart';
import 'danshari_page.dart';
import 'gemini_university_v2_page.dart';
import 'emergency_meeting_page.dart';
import 'real_world_danshari_page.dart';
import 'landing_page.dart';
import 'agent_org_page.dart';
import 'admin_analytics_page.dart';
import 'cfo_office_page.dart';
import 'asset_management_page.dart';
import 'cho_office_page.dart';
import 'cmo_office_page.dart';
import 'chro_office_page.dart';
import 'morning_briefing_page.dart';
import 'election_strategy_page.dart';
import 'mind_map_page.dart';
import 'memory_drill_page.dart';
import 'behavior_review_page.dart';
import 'digest_queue_page.dart';
import 'reality_check_page.dart';
import 'thought_anchor_page.dart';
import 'settings_page.dart';
import 'stock_tasks_page.dart';
import 'mindless_task_page.dart';
import 'wardrobe_page.dart'; // 先頭のimport群に追加
import '../widgets/development_achievements_card.dart';
import '../widgets/growth_roadmap_progress_card.dart';

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
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  _CalendarHighlightFilter _calendarHighlightFilter =
      _CalendarHighlightFilter.all;
  _KpiTrendRange _kpiTrendRange = _KpiTrendRange.oneMonth;
  _CalendarTaskPreviewFilter _calendarTaskPreviewFilter =
      _CalendarTaskPreviewFilter.all;
  DateTime? _calendarMonthAnchor;
  DateTime? _selectedCalendarDate;

  @override
  void initState() {
    super.initState();
    final today = _startOfDay(_now());
    _calendarMonthAnchor = DateTime(today.year, today.month, 1);
    _selectedCalendarDate = today;
    _reloadHomeSignals();
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
    final today = _startOfDay(_now());
    final todayKey = _statusDateKey(today);
    final tomorrow = today.add(const Duration(days: 1));

    try {
      final results = await Future.wait<dynamic>([
        Supabase.instance.client
            .from('app_analytics')
            .select('date,landing_views,share_count,source_details')
            .eq('date', todayKey)
            .maybeSingle(),
        Supabase.instance.client
            .from('user_profiles')
            .select('created_at')
            .gte('created_at', today.toIso8601String())
            .lt('created_at', tomorrow.toIso8601String()),
        Supabase.instance.client.rpc('get_lp_view_stats'),
      ]);

      final analyticsRow = results[0] is Map
          ? Map<String, dynamic>.from(results[0] as Map)
          : <String, dynamic>{};
      final profileRows =
          results[1] is List ? results[1] as List<dynamic> : const [];
      final lpStats = results[2] is Map
          ? Map<String, dynamic>.from(results[2] as Map)
          : <String, dynamic>{};

      var todayViews = _toIntValue(analyticsRow['landing_views']);
      if (lpStats.isNotEmpty) {
        todayViews = _toIntValue(lpStats['today']);
        final rawSeries = lpStats['series'];
        if (todayViews == 0 && rawSeries is List) {
          for (final row in rawSeries.whereType<Map>()) {
            final dateKey = _normalizeDateKey(row['date']);
            if (dateKey == todayKey) {
              todayViews = _toIntValue(row['count']);
              break;
            }
          }
        }
      }

      String? topShareChannelKey;
      var topShareChannelCount = 0;
      final rawSourceDetails = analyticsRow['source_details'];
      if (rawSourceDetails is Map) {
        for (final entry in rawSourceDetails.entries) {
          final sourceKey = entry.key.toString();
          if (!sourceKey.startsWith('share_') && sourceKey != 'x_share') {
            continue;
          }
          final count = _toIntValue(entry.value);
          if (count > topShareChannelCount) {
            topShareChannelCount = count;
            topShareChannelKey = sourceKey;
          }
        }
      }

      return _HomeMarketingKpiSummary(
        todayViews: todayViews,
        todayRegistrations: profileRows.length,
        todayShares: _toIntValue(analyticsRow['share_count']),
        topShareChannelKey: topShareChannelKey,
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

  String? _normalizeDateKey(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return _statusDateKey(parsed.toLocal());
    }

    return raw.length >= 10 ? raw.substring(0, 10) : raw;
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
    final candidates = <String?>[
      prefs.getString('gemini_model_home'),
      prefs.getString('gemini_model_emergency_meeting'),
      prefs.getString('gemini_model'),
    ];
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return 'gemini-1.5-flash';
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

    try {
      final apiKey = await _loadHomeApiKey(prefs);
      if (apiKey == null) {
        return null;
      }

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
        color: Colors.redAccent,
      );
    }

    if (snapshot.monthlyCashflowSummary.needsReview) {
      return _HomeActionCommand(
        type: _HomeActionType.monthlyFlowReview,
        title: '今月の収支を先に把握する',
        detail: snapshot.monthlyCashflowSummary.summaryLine,
        icon: Icons.receipt_long,
        color: Colors.green.shade700,
      );
    }

    if (!snapshot.morningBriefingDone && hour < 12) {
      return const _HomeActionCommand(
        type: _HomeActionType.morningBriefing,
        title: 'モーニング・ブリーフィングを先に実施',
        detail: '朝の優先順位を確定してから他メニューへ進む。',
        icon: Icons.wb_sunny,
        color: Colors.amber,
      );
    }

    if (!snapshot.balanceCheckDone) {
      return const _HomeActionCommand(
        type: _HomeActionType.balanceCheck,
        title: '今日の口座残高を確認',
        detail: 'まず資金状態を把握して、日次の打ち手を決める。',
        icon: Icons.account_balance_wallet,
        color: Colors.green,
      );
    }

    if (snapshot.pendingCriticalTaskCount > 0) {
      return _HomeActionCommand(
        type: _HomeActionType.criticalTasks,
        title: '必須タスクを先に完了',
        detail: '思考停止ログの必須タスクが${snapshot.pendingCriticalTaskCount}件残っています。',
        icon: Icons.lock_clock,
        color: Colors.redAccent,
      );
    }

    if (!snapshot.completionGoalSnapshot.isAchieved) {
      return _HomeActionCommand(
        type: _HomeActionType.beatYesterdayGoal,
        title: '今日は昨日より1件多く完了する',
        detail:
            '昨日 ${snapshot.completionGoalSnapshot.yesterdayCompletedCount}件 / 今日 ${snapshot.completionGoalSnapshot.todayCompletedCount}件 / 目標 ${snapshot.completionGoalSnapshot.targetCount}件',
        icon: Icons.trending_up,
        color: Colors.indigo,
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
        color: Colors.teal,
      );
    }

    return const _HomeActionCommand(
      type: _HomeActionType.none,
      title: '今日の必須導線は完了済み',
      detail: '次は通常メニューを優先度順に実行。',
      icon: Icons.verified,
      color: Colors.blueGrey,
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
      isDark ? const Color(0xFF0F172A) : Colors.white,
    );
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      key: Key('home_next_action_${command.type.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
        borderRadius: BorderRadius.circular(18),
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
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  command.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI推奨: ${command.detail}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.88),
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
        ? Colors.green.shade700
        : Colors.redAccent.shade200;
    final cardColor =
        isDark ? const Color(0xFF111827) : Colors.white.withValues(alpha: 0.92);
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
        borderRadius: BorderRadius.circular(18),
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
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.summaryLine,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: (isDark ? Colors.white : Colors.black87)
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
                color: Colors.green.shade700,
              ),
              _buildMonthlyCashflowMetric(
                label: '支出',
                value: _formatYen(summary.expenseTotal.toDouble()),
                color: Colors.redAccent,
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
                color: summary.reviewDone ? Colors.blueGrey : accentColor,
              ),
              _buildMonthlyCashflowChip(
                icon: Icons.edit_note,
                label: recordLabel,
                color: summary.recordCount > 0 ? Colors.blue : Colors.orange,
              ),
              if (summary.lastRecordedAt != null)
                _buildMonthlyCashflowChip(
                  icon: Icons.schedule,
                  label:
                      '最終記録 ${DateFormat('M/d HH:mm').format(summary.lastRecordedAt!)}',
                  color: Colors.indigo,
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
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
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
            ),
          ),
        ],
      ),
    );
  }

  void _showLockedMenuSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
    Color color = Colors.blueGrey;
    var icon = Icons.verified;
    VoidCallback onPressed = _refreshKpis;

    if (snapshot.pendingCriticalTaskCount > 0) {
      title = 'まず嫌な必須タスクを片付ける';
      detail = '未完了の必須タスクが${snapshot.pendingCriticalTaskCount}件あります。'
          ' 他メニューより先に思考停止ログを消化してください。';
      buttonLabel = '必須タスクへ';
      color = Colors.redAccent;
      icon = Icons.lock_clock;
      onPressed = () {
        _nav(context, const MindlessTaskPage());
      };
    } else if (!snapshot.morningBriefingDone) {
      title = '朝の固定を先に終える';
      detail = '気分で動く前に、朝の優先順位を先に固定します。';
      buttonLabel = 'ブリーフィングへ';
      color = Colors.amber;
      icon = Icons.wb_sunny;
      onPressed = () {
        _openMorningBriefing(context);
      };
    } else if (!snapshot.balanceCheckDone) {
      title = '数字確認を先に終える';
      detail = 'なんとなく触りたいメニューに行く前に、口座残高を確認します。';
      buttonLabel = '財務管理へ';
      color = Colors.green;
      icon = Icons.account_balance_wallet;
      onPressed = () {
        _openCfoOffice(context);
      };
    } else if (snapshot.abstinenceSlipCount > 0) {
      title = '逸脱復旧を先にやる';
      detail = '今日は${snapshot.abstinenceSlipCount}回の逸脱があります。'
          ' 先に禁欲ガードを再設定してください。';
      buttonLabel = '禁欲ガードへ';
      color = Colors.deepOrange;
      icon = Icons.shield_moon;
      onPressed = () {
        _openAbstinenceGuard(context);
      };
    }

    final baseColor = Color.alphaBlend(
      color.withValues(alpha: isDark ? 0.18 : 0.1),
      isDark ? const Color(0xFF111827) : Colors.white,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
        borderRadius: BorderRadius.circular(18),
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
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
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
    final accent = achieved ? Colors.green : Colors.indigo;
    final headline = achieved ? '前日超えを達成中' : '今日は昨日より1件多く終える';
    final detail =
        '昨日 ${goal.yesterdayCompletedCount}件 / 今日 ${goal.todayCompletedCount}件 / 目標 ${goal.targetCount}件';
    final helper = achieved
        ? 'このまま維持して、次の1件は短く終わるタスクから取ります。'
        : 'あと ${goal.remainingCount}件で前日超えです。5分で終わるものから先に片付けます。';
    final baseColor = isDark ? const Color(0xFF111827) : Colors.white;

    return Container(
      key: const Key('home_completion_goal_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
        borderRadius: BorderRadius.circular(18),
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
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headline,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
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
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: goal.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white,
            color: accent,
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1F2937), Color(0xFF111827)]
              : const [Color(0xFFFFFBFB), Color(0xFFFFF3F2)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.28)),
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
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_moon, color: Colors.redAccent),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'やらないことガード',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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
                color: Colors.redAccent,
              ),
              _buildStatusPill(
                label: '逸脱',
                value: '${snapshot.abstinenceSlipCount}回',
                color: snapshot.abstinenceSlipCount > 0
                    ? Colors.orange
                    : Colors.green,
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
              color: isDark ? Colors.white70 : Colors.black87,
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
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日の主犯: $primaryLabel',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '切断サイン: $primarySignal',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '排除手順: $primaryAction',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF111827), Color(0xFF172033)]
              : const [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.blueGrey.withValues(alpha: isDark ? 0.3 : 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '継続カレンダー $currentMonthLabel',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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
                    color: Colors.orange,
                    filter: _CalendarHighlightFilter.slip,
                  ),
                  _buildCalendarSummaryPill(
                    label: '無傷日数',
                    value: '$cleanDaysCount日',
                    color: Colors.green,
                    filter: _CalendarHighlightFilter.clean,
                  ),
                  _buildCalendarSummaryPill(
                    label: '未設定日数',
                    value: '$unsetDaysCount日',
                    color: Colors.blueGrey,
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '朝の固定、残高確認、禁欲の安定を月単位で見る。',
          ),
          const SizedBox(height: 4),
          Text(
            '各日の「収」「支」で、その日の入出金を月単位で俯瞰できます。',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade600,
            ),
          ),
          if (filterLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              filterLabel,
              key: Key('home_calendar_filter_${_calendarHighlightFilter.name}'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.blueGrey.shade600,
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
                color: Colors.amber,
              ),
              _buildStatusPill(
                label: '残高確認',
                value: '$balanceDoneCount日',
                color: Colors.green,
              ),
              _buildStatusPill(
                label: '禁欲安定',
                value: '$cleanDaysCount日',
                color: Colors.redAccent,
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
                color: Colors.indigo,
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.blueGrey.shade500,
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
                  day.isCurrentMonth ? status.color : Colors.blueGrey;
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
                      : Colors.blueGrey.withValues(alpha: 0.035)
                  : Colors.blueGrey.withValues(alpha: 0.05);

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
                            ? Colors.blue.shade400
                            : day.isCurrentMonth
                                ? matchesFilter
                                    ? accentColor.withValues(alpha: 0.22)
                                    : Colors.blueGrey.withValues(alpha: 0.08)
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
                                              ? Colors.white70
                                              : Colors.black87)
                                          : accentColor)
                                      : isDark
                                          ? Colors.blueGrey.shade700
                                          : Colors.blueGrey.shade300
                                  : Colors.blueGrey.shade300,
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
                                color: Colors.green.shade700,
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
                                color: Colors.red.shade600,
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
                                    Colors.amber,
                                    isEmphasized: matchesFilter,
                                  ),
                                ),
                              if (day.balanceDone)
                                _buildCalendarDot(
                                  _calendarDotDisplayColor(
                                    Colors.green,
                                    isEmphasized: matchesFilter,
                                  ),
                                ),
                              if (day.hasAbstinenceProtection &&
                                  !day.hasAbstinenceSlip)
                                _buildCalendarDot(
                                  _calendarDotDisplayColor(
                                    Colors.redAccent,
                                    isEmphasized: matchesFilter,
                                  ),
                                ),
                              if (day.hasAbstinenceSlip)
                                _buildCalendarDot(
                                  _calendarDotDisplayColor(
                                    Colors.orange,
                                    isEmphasized: matchesFilter,
                                  ),
                                ),
                              if (day.isSaturday)
                                _buildCalendarDot(
                                  _calendarDotDisplayColor(
                                    Colors.teal,
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
              _CalendarLegend(color: Colors.green, label: '収入'),
              _CalendarLegend(color: Colors.red, label: '支出'),
            ],
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _CalendarLegend(color: Colors.amber, label: '朝'),
              _CalendarLegend(color: Colors.green, label: '残高'),
              _CalendarLegend(color: Colors.redAccent, label: '禁欲安定'),
              _CalendarLegend(color: Colors.orange, label: '逸脱'),
              _CalendarLegend(color: Colors.teal, label: '土曜'),
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

    final completedCount = day.completedTaskCount;
    final remainingCount = day.totalTaskCount - completedCount;
    final filteredTasks = _filterCalendarPreviewTasks(day.tasks);
    final hiddenTaskCount =
        filteredTasks.length > 6 ? filteredTasks.length - 6 : 0;
    final title = DateFormat('yyyy/MM/dd').format(day.date);

    return Container(
      key: const Key('home_calendar_task_preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.indigo.withValues(alpha: 0.14),
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
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '完了 $completedCount / 全体 ${day.totalTaskCount} / 未完了 $remainingCount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade600,
                        fontWeight: FontWeight.w600,
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
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'この日に登録されているタスクはありません。',
                style: TextStyle(fontWeight: FontWeight.w600),
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
                  color: Colors.white.withValues(alpha: 0.82),
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
                      color: task.isCompleted ? Colors.green : Colors.blueGrey,
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
                                  ? Colors.blueGrey.shade500
                                  : null,
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
                                  color: Colors.blueGrey,
                                ),
                              if (task.isImportant)
                                _buildCalendarTaskBadge(
                                  label: '重要',
                                  color: Colors.redAccent,
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
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey.shade600,
                  fontWeight: FontWeight.w600,
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

    final completedCount = day.completedTaskCount;
    final remainingCount = day.totalTaskCount - completedCount;
    final filteredTasks = _filterCalendarPreviewTasks(day.tasks);
    final hiddenTaskCount =
        filteredTasks.length > 6 ? filteredTasks.length - 6 : 0;
    final title = DateFormat('yyyy/MM/dd').format(day.date);

    return Container(
      key: const Key('home_calendar_task_preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.indigo.withValues(alpha: 0.14),
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
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '完了 $completedCount / 全体 ${day.totalTaskCount} / 未完了 $remainingCount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade600,
                        fontWeight: FontWeight.w600,
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
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'この日に該当するタスクはありません。',
                style: TextStyle(fontWeight: FontWeight.w600),
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
                  color: Colors.white.withValues(alpha: 0.82),
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
                      color: task.isCompleted ? Colors.green : Colors.blueGrey,
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
                                  ? Colors.blueGrey.shade500
                                  : null,
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
                                  color: Colors.blueGrey,
                                ),
                              if (task.isImportant)
                                _buildCalendarTaskBadge(
                                  label: '重要',
                                  color: Colors.redAccent,
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
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey.shade600,
                  fontWeight: FontWeight.w600,
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
      _HomeCalendarTaskSource.dailyTodo => Colors.indigo,
      _HomeCalendarTaskSource.mindless => Colors.teal,
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
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: textColor,
          height: 1.1,
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
        color: Colors.blueGrey,
        icon: Icons.radio_button_unchecked,
      );
    }
    if (day.hasAbstinenceSlip) {
      return const _CalendarDayStatus(
        label: '逸脱あり',
        detail: 'その日は抑止ラインを突破しています。',
        color: Colors.orange,
        icon: Icons.warning_amber_rounded,
      );
    }
    if (!day.hasAbstinenceProtection) {
      return const _CalendarDayStatus(
        label: '未設定',
        detail: 'その日の禁止対象が固定されていません。',
        color: Colors.blueGrey,
        icon: Icons.radio_button_unchecked,
      );
    }
    return const _CalendarDayStatus(
      label: '無傷',
      detail: '禁止対象を保ったまま終えています。',
      color: Colors.green,
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
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                    accent: Colors.indigo,
                    emptyLabel: day.isFuture
                        ? 'まだこの日のタスクは登録されていません。'
                        : 'この日のタスクはありません。',
                    items: taskItems,
                  ),
                  const SizedBox(height: 12),
                  _buildCalendarDetailSection(
                    title: '逸脱内容',
                    accent: Colors.orange,
                    emptyLabel: day.isFuture ? 'まだ記録はありません。' : '逸脱はありません。',
                    items: day.slipDetails,
                  ),
                  const SizedBox(height: 12),
                  _buildCalendarDetailSection(
                    title: '未達成項目',
                    accent: Colors.redAccent,
                    emptyLabel:
                        day.isFuture ? 'まだ未達成判定はありません。' : '未達成項目はありません。',
                    items: day.missingItems,
                  ),
                  const SizedBox(height: 12),
                  _buildCalendarDetailSection(
                    title: '実施できた項目',
                    accent: Colors.green,
                    emptyLabel: day.isFuture ? 'まだ実施記録はありません。' : '実施項目はありません。',
                    items: completedItems,
                  ),
                  const SizedBox(height: 12),
                  _buildCalendarDetailSection(
                    title: 'その日に設定していた禁止対象',
                    accent: Colors.blueGrey,
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
        color: Colors.indigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '収支サマリ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.indigo,
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
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCalendarCashflowMetricTile(
                    label: '支出',
                    value: _formatYen(cashflow.expenseTotal.toDouble()),
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCalendarCashflowMetricTile(
                    label: '差額',
                    value: _formatSignedYen(cashflow.netTotal.toDouble()),
                    color:
                        cashflow.netTotal >= 0 ? Colors.indigo : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '入出金 ${cashflow.recordCount} 件'
              '${cashflow.transferCount > 0 ? ' / 振替 ${cashflow.transferCount} 件 (${_formatYen(cashflow.transferTotal.toDouble())})' : ''}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey.shade700,
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
          isDark ? const Color(0xFF0B1220) : const Color(0xFFF3F7FF),
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
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeService.toggleTheme(),
            tooltip: 'テーマ切替',
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
                    Color(0xFF0B1220),
                    Color(0xFF111827),
                    Color(0xFF0F172A),
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
                            const GrowthRoadmapProgressCard(),
                            const SizedBox(height: 10),
                            const NotionFeatureComparisonCard(),
                            const SizedBox(height: 10),
                            _UserManualBanner(),
                            const SizedBox(height: 10),
                            const DevelopmentAchievementsCard(),
                            const SizedBox(height: 14),
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
                              Colors.redAccent,
                              key: const Key('home_section_ceo_office'),
                            ),
                            _buildCeoCard(context),
                            const SizedBox(height: 12),
                            _buildMorningBriefingCard(
                              context,
                              isHighlighted: highlightMorning,
                            ),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'OFFICE KPI SNAPSHOT',
                              Icons.space_dashboard,
                              Colors.deepPurple,
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
                              'KPI SUMMARY',
                              Icons.show_chart,
                              Colors.purple,
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
                              Colors.blueGrey,
                              key:
                                  const Key('home_section_operations_calendar'),
                            ),
                            _buildCalendarPanel(context, opsSnapshot),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'SPECIAL PROJECT',
                              Icons.rocket_launch,
                              Colors.indigo,
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
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.indigo.withValues(alpha: 0.25),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
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
                                      color: Colors.indigo,
                                      size: 30,
                                    ),
                                  ),
                                  title: const Text(
                                    '2026 衆院選 勝利戦略室',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'AI参謀と連携し、地域特性を踏まえた勝利戦略を立案します。',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ElectionStrategyPage(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'CSO OFFICE',
                              Icons.flag,
                              Colors.orange,
                              key: const Key('home_section_cso_office'),
                            ),
                            _buildGridMenu(context, isCompact, [
                              _MenuData(
                                '禁欲ガード',
                                Icons.shield_moon,
                                Colors.redAccent,
                                () => _openAbstinenceGuard(context),
                                isHighlighted: highlightAbstinence ||
                                    opsSnapshot.abstinenceSlipCount > 0,
                                badgeLabel: highlightAbstinence
                                    ? 'NEXT'
                                    : opsSnapshot.abstinenceSlipCount > 0
                                        ? 'WARN'
                                        : null,
                              ),
                              _MenuData(
                                '断捨離 (デジタル)',
                                Icons.cleaning_services,
                                Colors.orange,
                                () => _nav(context, const DanshariPage()),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                              _MenuData(
                                '断捨離 (リアル)',
                                Icons.camera_alt,
                                Colors.deepOrange,
                                () => _nav(
                                  context,
                                  RealWorldDanshariPage(
                                    supabaseClient: Supabase.instance.client,
                                  ),
                                ),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                              _MenuData(
                                'AI稼働モニター',
                                Icons.monitor_heart,
                                Colors.orange,
                                () => _nav(context, const AiStatusPage()),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                              _MenuData(
                                '週末ストック / 思考ネタ',
                                Icons.check_circle_outline,
                                Colors.teal,
                                () => _nav(context, const StockTasksPage()),
                                isHighlighted: highlightStock,
                                badgeLabel: highlightStock ? 'SAT' : null,
                              ),
                              _MenuData(
                                '思考停止ログ（読書ループ）',
                                Icons.access_time_filled,
                                Colors.indigo,
                                () => _nav(context, const MindlessTaskPage()),
                                isHighlighted: highlightCritical,
                                badgeLabel: highlightCritical ? 'NEXT' : null,
                              ),
                              _MenuData(
                                'ワードローブ整理',
                                Icons.checkroom,
                                Colors.brown,
                                () => _nav(context, const WardrobePage()),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                              _MenuData(
                                '暗記ドリル (日課)',
                                Icons.memory_rounded,
                                Colors.indigo,
                                () => _nav(context, const MemoryDrillPage()),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                              _MenuData(
                                '消化してから次へ',
                                Icons.restaurant_menu,
                                Colors.cyan,
                                () => _nav(context, const DigestQueuePage()),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                              _MenuData(
                                '思考アンカー',
                                Icons.center_focus_strong,
                                Colors.indigo,
                                () => _nav(context, const ThoughtAnchorPage()),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                            ]),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'CFO/CHO/CHRO OFFICE',
                              Icons.balance,
                              Colors.teal,
                            ),
                            _buildGridMenu(context, isCompact, [
                              _MenuData(
                                '財務管理 (CFO)',
                                Icons.account_balance_wallet,
                                Colors.green,
                                () => _openCfoOffice(context),
                                isHighlighted:
                                    highlightMonthlyFlow || highlightBalance,
                                badgeLabel: highlightMonthlyFlow
                                    ? 'NOW'
                                    : highlightBalance
                                        ? 'NEXT'
                                        : null,
                              ),
                              _MenuData(
                                '健康管理 (CHO)',
                                Icons.medical_services,
                                Colors.teal,
                                () => _nav(context, const ChoOfficePage()),
                              ),
                              _MenuData(
                                '人事厚生 (CHRO)',
                                Icons.diversity_3,
                                Colors.indigo,
                                () => _nav(context, const ChroOfficePage()),
                              ),
                            ]),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'CMO/CKO OFFICE',
                              Icons.analytics,
                              Colors.blue,
                            ),
                            _buildGridMenu(context, isCompact, [
                              _MenuData(
                                '市場分析 (CMO)',
                                Icons.trending_up,
                                Colors.pink,
                                () => _nav(context, const CmoOfficePage()),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                              _MenuData(
                                'AI組織OS',
                                Icons.account_tree,
                                Colors.deepPurple,
                                () => _nav(context, AgentOrgPage()),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                              _MenuData(
                                'メモ一覧 (CKO)',
                                Icons.list_alt,
                                Colors.blue,
                                () => _nav(context, const NoteListPage()),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                              _MenuData(
                                '新規事業起案',
                                Icons.edit_note,
                                Colors.blue,
                                () => _nav(context, const NoteEditorPage()),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                              _MenuData(
                                'Gemini大学',
                                Icons.menu_book,
                                Colors.blue,
                                () => _nav(
                                  context,
                                  const GeminiUniversityV2Page(),
                                ),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                              _MenuData(
                                'マインドマップ (思考整理)',
                                Icons.hub,
                                Colors.blue,
                                () => _nav(context, const MindMapPage()),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                              _MenuData(
                                '行動・発言レビュー',
                                Icons.history_edu,
                                Colors.blueGrey,
                                () => _nav(context, BehaviorReviewPage()),
                              ),
                              _MenuData(
                                '現実直視ノート',
                                Icons.fact_check,
                                Colors.redAccent,
                                () => _nav(context, const RealityCheckPage()),
                                isLocked: shouldLockExploratoryMenus,
                                lockedReason: '先に必須導線を完了してください。',
                              ),
                            ]),
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
              Colors.redAccent.withValues(alpha: isDark ? 0.16 : 0.07),
              baseColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: isDark ? 0.16 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        leading: const CircleAvatar(
          backgroundColor: Colors.redAccent,
          radius: 26,
          child: Icon(Icons.emergency, color: Colors.white, size: 28),
        ),
        title: const Text(
          '緊急役員会議',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    final accent = isHighlighted ? Colors.amber.shade700 : Colors.amber;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            Color.alphaBlend(
              Colors.amber.withValues(alpha: isHighlighted ? 0.2 : 0.09),
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          isHighlighted ? 'まず朝の優先順位を固定してください。' : '今日のタスクと優先順位を確認します。',
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _openMorningBriefing(context),
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
        final baseCardColor = item.isHighlighted
            ? Color.alphaBlend(
                item.color.withValues(alpha: isDark ? 0.24 : 0.14),
                Theme.of(context).cardColor,
              )
            : Theme.of(context).cardColor;
        final cardColor = item.isLocked
            ? Color.alphaBlend(
                Colors.blueGrey.withValues(alpha: isDark ? 0.18 : 0.12),
                baseCardColor,
              )
            : baseCardColor;
        final borderColor = item.isLocked
            ? Colors.blueGrey.withValues(alpha: 0.22)
            : item.isHighlighted
                ? item.color.withValues(alpha: 0.65)
                : Theme.of(context).dividerColor.withValues(alpha: 0.25);

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
              onTap: item.isLocked
                  ? () {
                      _showLockedMenuSnackBar(
                        context,
                        item.lockedReason ?? '先に必須導線を完了してください。',
                      );
                    }
                  : item.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (item.isLocked ? Colors.blueGrey : item.color)
                            .withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (item.isLocked ? Colors.blueGrey : item.color)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        item.icon,
                        color: item.isLocked ? Colors.blueGrey : item.color,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: isCompact ? 10 : 12),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: item.isLocked
                              ? (isDark ? Colors.white60 : Colors.black45)
                              : item.isHighlighted
                                  ? item.color
                                  : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isLocked)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: Colors.blueGrey,
                        ),
                      ),
                    if (item.badgeLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.badgeLabel!,
                          style: TextStyle(
                            color: item.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
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
                  accentColor: Colors.redAccent,
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
                  accentColor: Colors.green,
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
                  title: '流入',
                  headline: '${marketing.todayViews}',
                  subtitle: '今日のLP View',
                  icon: Icons.campaign,
                  accentColor: Colors.pink,
                  metrics: <_OfficeKpiMetricItem>[
                    _OfficeKpiMetricItem(
                      '今日の登録',
                      '${marketing.todayRegistrations}件',
                    ),
                    _OfficeKpiMetricItem('今日のCVR', marketing.todayCvrLabel),
                    _OfficeKpiMetricItem(
                      '主要チャネル',
                      _shareChannelLabel(marketing.topShareChannelKey),
                    ),
                  ],
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
                  accentColor: Colors.teal,
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
                  accentColor: Colors.indigo,
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
  }) {
    final baseColor = isDark ? const Color(0xFF111827) : Colors.white;
    final labelColor =
        isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.65);
    final titleColor = isDark ? Colors.white : Colors.black87;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(18),
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
            borderRadius: BorderRadius.circular(18),
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
                  ),
                ),
                const SizedBox(height: 12),
                ...metrics
                    .take(3)
                    .map((metric) => _buildOfficeKpiMetricRow(metric, isDark)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(actionLabel),
                    style: TextButton.styleFrom(
                      foregroundColor: accentColor,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
    final labelColor =
        isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.6);
    final valueColor = isDark ? Colors.white : Colors.black87;

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
              ),
            ),
          ),
        ],
      ),
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : const Color(0xFFF0F1F3),
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
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 2,
                color: Colors.orange.shade700,
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
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 2,
                color: Colors.orange.shade700,
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
                                ? Colors.orange.withValues(alpha: 0.62)
                                : Colors.blueGrey.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          _kpiTrendRangeLabel(range),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
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
          Colors.green,
          _totalAssetsFuture,
        ),
        _buildKpiCard(
          context,
          isDark,
          '禁欲フォーカス',
          '${snapshot.abstinenceFocusCount}件',
          Icons.shield_moon,
          Colors.redAccent,
        ),
        _buildKpiCard(
          context,
          isDark,
          '必須タスク残',
          '${snapshot.pendingCriticalTaskCount}件',
          Icons.lock_clock,
          Colors.indigo,
        ),
        _buildKpiCard(
          context,
          isDark,
          '週末ストック残',
          '${snapshot.pendingStockTaskCount}件',
          Icons.inventory_2,
          Colors.teal,
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
        : Colors.blueGrey.withValues(alpha: 0.24);
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
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            color: Colors.orange.shade700,
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
              color: Colors.redAccent,
            ),
            if (hasWasteSeries)
              _buildTrendLegendChip(
                isDark: isDark,
                label: '浪費',
                color: Colors.orangeAccent,
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
                          color: isDark ? Colors.white70 : Colors.black54,
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
                          color: isDark ? Colors.white70 : Colors.black54,
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
                        axisSide: meta.axisSide,
                        child: Text(
                          DateFormat('M/d').format(points[index].date),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white70 : Colors.black54,
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
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
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
                  color: Colors.redAccent,
                  barWidth: 2.8,
                  dotData: FlDotData(show: assetSpots.length <= 40),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blue.withValues(alpha: 0.6),
                        Colors.blue.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
                if (hasWasteSeries)
                  LineChartBarData(
                    spots: wasteSpots,
                    isCurved: false,
                    color: Colors.orangeAccent,
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
      Colors.orange,
      Colors.redAccent,
      Colors.indigo,
      Colors.teal,
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.brown,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
    ];
    final total = breakdownEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.value,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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
                accent: Colors.orange,
              ),
              _buildWasteMetricCard(
                isDark: isDark,
                title: '記録件数',
                value: '${overview.wasteRecordCount}件',
                accent: Colors.redAccent,
              ),
              _buildWasteMetricCard(
                isDark: isDark,
                title: '最大カテゴリ',
                value: overview.topWasteCategory ?? '--',
                accent: Colors.blueGrey,
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
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatYen(breakdownEntries[i].value),
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w600,
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
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
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
    final labelColor =
        isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.6);
    final base = isDark ? const Color(0xFF111827) : Colors.white;

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
  final bool isHighlighted;
  final String? badgeLabel;
  final bool isLocked;
  final String? lockedReason;

  _MenuData(
    this.title,
    this.icon,
    this.color,
    this.onTap, {
    this.isHighlighted = false,
    this.badgeLabel,
    this.isLocked = false,
    this.lockedReason,
  });
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

  const _HomeMarketingKpiSummary({
    this.todayViews = 0,
    this.todayRegistrations = 0,
    this.todayShares = 0,
    this.topShareChannelKey,
  });

  double get todayCvr =>
      todayViews == 0 ? 0 : (todayRegistrations / todayViews) * 100;

  String get todayCvrLabel => '${todayCvr.toStringAsFixed(1)}%';
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
          style: TextStyle(
            fontSize: 12,
            color: Colors.blueGrey.shade700,
            fontWeight: FontWeight.w600,
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

// ---------------------------------------------------------------------------
// User manual banner
// ---------------------------------------------------------------------------

class _UserManualBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1A2233) : const Color(0xFFFFFFFF);
    final borderColor =
        isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).pushNamed('/user-manual'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 20,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ユーザーマニュアル',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '実装済み全機能の操作手順を確認できます',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFF6366F1),
            ),
          ],
        ),
      ),
    );
  }
}
