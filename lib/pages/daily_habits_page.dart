import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/habit_resource_metrics_dialog.dart';
import 'resource_optimization_page.dart';

const _habitDefaultMeasurementSource = 'habit_default_proxy';
const _selfReportedMeasurementSource = 'self_reported_goal_contribution_proxy';

@visibleForTesting
Map<String, dynamic> buildHabitResourceMeasurementPayload(
  HabitResourceEntry entry, {
  required bool isSelfReported,
}) {
  return <String, dynamic>{
    'time_cost_minutes': entry.timeCostMinutes,
    'fatigue_score': entry.fatigueScore,
    'goal_contribution_score': entry.goalContributionScore,
    'goal_contribution_measurement_source': isSelfReported
        ? _selfReportedMeasurementSource
        : _habitDefaultMeasurementSource,
    'goal_id': entry.goalId,
    'goal_title': entry.goalTitle,
  };
}

class DailyHabitsSnapshot {
  final List<Map<String, dynamic>> habits;
  final Set<String> completedToday;
  final Map<String, Map<String, dynamic>> todayLogs;
  final List<HabitGoalOption> goals;
  final int allClearStreak;

  const DailyHabitsSnapshot({
    required this.habits,
    required this.completedToday,
    required this.todayLogs,
    required this.goals,
    required this.allClearStreak,
  });
}

typedef DailyHabitsSnapshotLoader = Future<DailyHabitsSnapshot> Function(
  String userId,
  DateTime today,
);
typedef DailyHabitToggler = Future<bool> Function(
  String userId,
  Map<String, dynamic> habit,
  DateTime today,
  bool currentlyCompleted,
);
typedef DailyHabitResourceUpdater = Future<bool> Function(
  String userId,
  String habitId,
  DateTime today,
  HabitResourceEntry entry,
);
typedef DailyHabitInserter = Future<void> Function(
  Map<String, dynamic> payload,
);
typedef DailyHabitDeleter = Future<bool> Function(
  String userId,
  Object? habitId,
);

/// 毎日の定型タスク (習慣) リマインダーページ。
/// マネーフォワード更新、財布残高入力、体重記録など毎日やるべきことを管理。
class DailyHabitsPage extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  final DateTime Function()? nowProvider;
  final DailyHabitsSnapshotLoader? loadSnapshot;
  final DailyHabitToggler? toggleHabit;
  final DailyHabitResourceUpdater? updateTodayResource;
  final DailyHabitInserter? insertHabit;
  final DailyHabitDeleter? deleteHabit;

  const DailyHabitsPage({
    super.key,
    this.supabaseClient,
    this.nowProvider,
    this.loadSnapshot,
    this.toggleHabit,
    this.updateTodayResource,
    this.insertHabit,
    this.deleteHabit,
  });

  static int? safeInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '');
      return int.tryParse(cleaned);
    }
    return null;
  }

  static double? safeDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static int calculateAllClearStreak({
    required Set<String> activeHabitIds,
    required Map<String, Set<String>> completedDateToHabitIds,
    required DateTime today,
    int maxDays = 365,
  }) {
    if (activeHabitIds.isEmpty) return 0;
    final dateFmt = DateFormat('yyyy-MM-dd');
    final activeCount = activeHabitIds.length;
    var streak = 0;

    for (var i = 1; i <= maxDays; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr = dateFmt.format(date);
      final doneIds = completedDateToHabitIds[dateStr];
      if (doneIds == null) break;
      final matched = doneIds.intersection(activeHabitIds).length;
      if (matched >= activeCount) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  State<DailyHabitsPage> createState() => _DailyHabitsPageState();
}

class _DailyHabitsPageState extends State<DailyHabitsPage> {
  bool _loading = true;
  bool _requiresLogin = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _habits = <Map<String, dynamic>>[];
  Set<String> _completedToday = <String>{};
  Map<String, Map<String, dynamic>> _todayLogs =
      <String, Map<String, dynamic>>{};
  List<HabitGoalOption> _goals = <HabitGoalOption>[];
  final Set<String> _savingHabitIds = <String>{};
  int _allClearStreak = 0;

  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  DateTime _now() => (widget.nowProvider ?? DateTime.now)();

  /// 5分で終わりそうなタスク名キーワード
  static const _quickTaskKeywords = <String>[
    '記録',
    '入力',
    '歯を磨',
    '薬を飲',
    '着替え',
    'スキンケア',
    '体重',
    '水を',
    '振り返り',
    'リスト',
    'メール',
  ];

  static const _presets = <(String, String, String, String)>[
    ('マネーフォワード更新・財布残高入力', '💰', '#4CAF50', '21:00'),
    ('体重を記録する', '⚖️', '#2196F3', '07:00'),
    ('水を2L飲む', '💧', '#03A9F4', '20:00'),
    ('10分間読書する', '📚', '#795548', '22:00'),
    ('日記を書く', '📝', '#9C27B0', '22:30'),
    ('ストレッチする', '🧘', '#FF9800', '07:30'),
    ('部屋を片付ける', '🧹', '#607D8B', '21:30'),
    ('英語の勉強をする', '🌐', '#E91E63', '20:00'),
    ('薬を飲む', '💊', '#F44336', '08:00'),
    ('瞑想する', '🧠', '#673AB7', '06:30'),
    ('洗い物をする', '🍽️', '#00BCD4', '21:00'),
    ('洗濯する', '👕', '#3F51B5', '07:00'),
    ('ゴミ出しの準備', '🗑️', '#8BC34A', '21:30'),
    ('メール整理', '📧', '#2196F3', '20:00'),
    ('寝る前にキッチンをリセット', '🧼', '#009688', '22:00'),
    ('今日すべきことリストを作る', '📋', '#FF5722', '06:30'),
    ('明日のタスクを前夜に整理する', '🌙', '#311B92', '22:30'),
    ('1日の振り返りをする', '🔄', '#006064', '22:00'),
    ('お風呂に入る', '🛁', '#0097A7', '21:00'),
    ('歯を磨く (朝)', '🪥', '#26A69A', '07:00'),
    ('歯を磨く (夜)', '🪥', '#26A69A', '22:30'),
    ('スキンケアをする', '🧴', '#AB47BC', '22:00'),
    ('着替える (上着・ズボン・パンツ)', '👔', '#5C6BC0', '07:00'),
    ('机の下を整理する', '🗄️', '#78909C', '21:00'),
    ('Xブックマーク整理', '🔖', '#1DA1F2', '20:30'),
    ('ブラウザブックマーク整理', '🌐', '#4285F4', '20:30'),
    ('暗記ドリル (10項目)', '🧠', '#1D4ED8', '07:30'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<DailyHabitsSnapshot> _defaultLoadSnapshot(
    String userId,
    DateTime today,
  ) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final sinceStr = DateFormat('yyyy-MM-dd')
        .format(today.subtract(const Duration(days: 365)));

    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _supabase
          .from('daily_habits')
          .select()
          .eq('user_id', userId)
          .order('created_at'),
      _supabase
          .from('daily_habit_logs')
          .select(
            'habit_id, time_cost_minutes, fatigue_score, '
            'goal_contribution_score, goal_id, goal_title',
          )
          .eq('user_id', userId)
          .eq('completed_date', todayStr),
      _supabase
          .from('daily_habit_logs')
          .select('habit_id, completed_date')
          .eq('user_id', userId)
          .gte('completed_date', sinceStr)
          .lt('completed_date', todayStr),
      _loadGoalOptions(),
    ]);

    final habits = (results[0] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final logs = (results[1] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final historyRows = (results[2] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final goals = results[3] as List<HabitGoalOption>;

    final completed = logs
        .map((l) => l['habit_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final todayLogs = <String, Map<String, dynamic>>{
      for (final log in logs)
        if ((log['habit_id']?.toString() ?? '').isNotEmpty)
          log['habit_id'].toString(): log,
    };

    final activeIds = habits
        .where((h) => h['is_active'] == true)
        .map((h) => h['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final dateToHabits = <String, Set<String>>{};
    for (final row in historyRows) {
      final dateStr = row['completed_date']?.toString() ?? '';
      final hid = row['habit_id']?.toString() ?? '';
      if (dateStr.isEmpty || hid.isEmpty) continue;
      (dateToHabits[dateStr] ??= <String>{}).add(hid);
    }

    final streak = DailyHabitsPage.calculateAllClearStreak(
      activeHabitIds: activeIds,
      completedDateToHabitIds: dateToHabits,
      today: today,
    );

    return DailyHabitsSnapshot(
      habits: habits,
      completedToday: completed,
      todayLogs: todayLogs,
      goals: goals,
      allClearStreak: streak,
    );
  }

  Future<List<HabitGoalOption>> _loadGoalOptions() async {
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: const <String, dynamic>{'action': 'goal.list'},
      );
      final data = response.data;
      final rows = data is Map && data['goals'] is List
          ? data['goals'] as List
          : const <dynamic>[];
      return rows.whereType<Map>().map((row) {
        final metadata = row['metadata'] is Map
            ? Map<String, dynamic>.from(row['metadata'] as Map)
            : <String, dynamic>{};
        return (row, metadata);
      }).where((entry) {
        final status = (entry.$2['status'] ?? 'active').toString();
        return status == 'active' &&
            (entry.$1['id']?.toString() ?? '').isNotEmpty &&
            (entry.$2['title']?.toString().trim() ?? '').isNotEmpty;
      }).map((entry) {
        return HabitGoalOption(
          id: entry.$1['id'].toString(),
          title: entry.$2['title'].toString(),
        );
      }).toList(growable: false);
    } catch (_) {
      return const <HabitGoalOption>[];
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _requiresLogin = false;
      _errorMessage = null;
    });

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _requiresLogin = true;
        _habits = <Map<String, dynamic>>[];
        _completedToday = <String>{};
        _todayLogs = <String, Map<String, dynamic>>{};
        _allClearStreak = 0;
        _loading = false;
      });
      return;
    }

    try {
      final loader = widget.loadSnapshot ?? _defaultLoadSnapshot;
      final snapshot = await loader(userId, _now());
      if (!mounted) return;
      setState(() {
        _habits = snapshot.habits
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
        _completedToday = Set<String>.from(snapshot.completedToday);
        _todayLogs = snapshot.todayLogs.map(
          (key, value) => MapEntry<String, Map<String, dynamic>>(
            key,
            Map<String, dynamic>.from(value),
          ),
        );
        _goals = List<HabitGoalOption>.from(snapshot.goals);
        _allClearStreak = snapshot.allClearStreak;
        _loading = false;
      });
    } catch (e) {
      debugPrint('DailyHabitsPage load error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = '毎日の習慣を読み込めませんでした。時間をおいて再試行してください。';
        _loading = false;
      });
    }
  }

  HabitResourceEntry _defaultResourceEntry(Map<String, dynamic> habit) {
    final goalId = habit['goal_id']?.toString();
    final goalTitle = habit['goal_title']?.toString();
    final defaultTime =
        DailyHabitsPage.safeInt(habit['default_time_cost_minutes']);
    final defaultFatigue =
        DailyHabitsPage.safeDouble(habit['default_fatigue_score']);
    final defaultContrib =
        DailyHabitsPage.safeDouble(habit['default_goal_contribution_score']);
    return HabitResourceEntry(
      timeCostMinutes: defaultTime ?? 15,
      fatigueScore: defaultFatigue ?? 3,
      goalContributionScore: defaultContrib ?? 50,
      goalId: (goalId?.isEmpty ?? true) ? null : goalId,
      goalTitle: (goalTitle?.isEmpty ?? true) ? null : goalTitle,
    );
  }

  Future<bool> _defaultToggleHabit(
    String userId,
    Map<String, dynamic> habit,
    DateTime today,
    bool currentlyCompleted,
  ) async {
    final habitId = habit['id']?.toString() ?? '';
    if (habitId.isEmpty) return false;
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final nowIso = today.toIso8601String();

    if (currentlyCompleted) {
      final deleted = await _supabase
          .from('daily_habit_logs')
          .delete()
          .eq('user_id', userId)
          .eq('habit_id', habitId)
          .eq('completed_date', todayStr)
          .select('habit_id');
      if (deleted.isEmpty) return false;

      final currentStreak = DailyHabitsPage.safeInt(habit['streak']) ?? 0;
      if (currentStreak > 0) {
        await _supabase
            .from('daily_habits')
            .update(<String, dynamic>{
              'streak': currentStreak - 1,
              'updated_at': nowIso,
            })
            .eq('id', habitId)
            .eq('user_id', userId)
            .select('id');
      }
      return true;
    }

    final resourceEntry = _defaultResourceEntry(habit);
    await _supabase.from('daily_habit_logs').insert(<String, dynamic>{
      'user_id': userId,
      'habit_id': habitId,
      'completed_date': todayStr,
      ...buildHabitResourceMeasurementPayload(
        resourceEntry,
        isSelfReported: false,
      ),
    });

    final currentStreak = (DailyHabitsPage.safeInt(habit['streak']) ?? 0) + 1;
    final bestStreak = DailyHabitsPage.safeInt(habit['best_streak']) ?? 0;
    await _supabase
        .from('daily_habits')
        .update(<String, dynamic>{
          'streak': currentStreak,
          'best_streak':
              currentStreak > bestStreak ? currentStreak : bestStreak,
          'updated_at': nowIso,
        })
        .eq('id', habitId)
        .eq('user_id', userId)
        .select('id');
    return true;
  }

  Future<bool> _defaultUpdateTodayResource(
    String userId,
    String habitId,
    DateTime today,
    HabitResourceEntry entry,
  ) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final updated = await _supabase
        .from('daily_habit_logs')
        .update(
          buildHabitResourceMeasurementPayload(entry, isSelfReported: true),
        )
        .eq('user_id', userId)
        .eq('habit_id', habitId)
        .eq('completed_date', todayStr)
        .select('habit_id');
    return updated.isNotEmpty;
  }

  Future<void> _defaultInsertHabit(Map<String, dynamic> payload) async {
    await _supabase.from('daily_habits').insert(payload);
  }

  Future<bool> _defaultDeleteHabit(String userId, Object? habitId) async {
    if (habitId == null) return false;
    final deleted = await _supabase
        .from('daily_habits')
        .delete()
        .eq('id', habitId)
        .eq('user_id', userId)
        .select('id');
    return deleted.isNotEmpty;
  }

  void _showSnack(
    String message, {
    Color? backgroundColor,
    SnackBarAction? action,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: backgroundColor != null
              ? const TextStyle(color: Colors.white)
              : null,
        ),
        backgroundColor: backgroundColor,
        action: action,
      ),
    );
  }

  Future<void> _toggleComplete(Map<String, dynamic> habit) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('達成を記録するにはログインしてください。');
      return;
    }

    final habitId = habit['id']?.toString() ?? '';
    if (habitId.isEmpty || _savingHabitIds.contains(habitId)) return;
    final wasCompleted = _completedToday.contains(habitId);

    setState(() => _savingHabitIds.add(habitId));
    try {
      final toggler = widget.toggleHabit ?? _defaultToggleHabit;
      final saved = await toggler(userId, habit, _now(), wasCompleted);
      if (!mounted) return;
      if (!saved) {
        _showSnack(
          '習慣の達成状態を更新できませんでした。画面を更新してお試しください。',
          backgroundColor: const Color(0xFFB71C1C),
        );
        return;
      }
      await _load();
      if (!wasCompleted && mounted) {
        _showSnack(
          '既定値で完了を記録しました',
          backgroundColor: const Color(0xFF2E7D32),
          action: SnackBarAction(
            label: '実績を修正',
            textColor: Colors.white,
            onPressed: () => _editTodayResourceById(habitId),
          ),
        );
      }
    } catch (e) {
      _showSnack(
        '更新に失敗しました。時間をおいて再試行してください。',
        backgroundColor: const Color(0xFFB71C1C),
      );
    } finally {
      if (mounted) {
        setState(() => _savingHabitIds.remove(habitId));
      }
    }
  }

  Future<void> _editTodayResourceById(String habitId) async {
    for (final habit in _habits) {
      if ('${habit['id'] ?? ''}' == habitId) {
        await _editTodayResource(habit);
        return;
      }
    }
  }

  Future<void> _editTodayResource(Map<String, dynamic> habit) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('実績を修正するにはログインしてください。');
      return;
    }
    final habitId = habit['id']?.toString() ?? '';
    if (habitId.isEmpty || _savingHabitIds.contains(habitId)) return;
    final log = _todayLogs[habitId];
    if (log == null || !_completedToday.contains(habitId)) return;

    final initialGoalId = log['goal_id']?.toString();
    final initialGoalTitle = log['goal_title']?.toString();
    final goals = List<HabitGoalOption>.of(_goals);
    if (initialGoalId != null &&
        initialGoalId.isNotEmpty &&
        initialGoalTitle != null &&
        initialGoalTitle.isNotEmpty &&
        !goals.any((goal) => goal.id == initialGoalId)) {
      goals.add(HabitGoalOption(id: initialGoalId, title: initialGoalTitle));
    }

    final entry = await showDialog<HabitResourceEntry>(
      context: context,
      builder: (_) => HabitResourceMetricsDialog(
        dialogTitle: '今日の実績を修正',
        submitLabel: '更新',
        habitTitle: habit['title']?.toString() ?? '',
        goals: goals,
        initialTimeCostMinutes:
            DailyHabitsPage.safeInt(log['time_cost_minutes']) ?? 15,
        initialFatigueScore:
            DailyHabitsPage.safeDouble(log['fatigue_score']) ?? 3,
        initialGoalContributionScore:
            DailyHabitsPage.safeDouble(log['goal_contribution_score']) ?? 50,
        initialGoalId: initialGoalId,
      ),
    );
    if (!mounted || entry == null || !_completedToday.contains(habitId)) return;

    setState(() => _savingHabitIds.add(habitId));
    try {
      final updater = widget.updateTodayResource ?? _defaultUpdateTodayResource;
      final updated = await updater(userId, habitId, _now(), entry);
      if (!mounted) return;
      if (!updated) {
        _showSnack(
          '今日の実績を更新できませんでした。再読み込みしてお試しください。',
          backgroundColor: const Color(0xFFB71C1C),
        );
        return;
      }
      await _load();
      _showSnack(
        '今日の実績を更新しました',
        backgroundColor: const Color(0xFF2E7D32),
      );
    } catch (e) {
      _showSnack(
        '実績の更新に失敗しました。時間をおいて再試行してください。',
        backgroundColor: const Color(0xFFB71C1C),
      );
    } finally {
      if (mounted) {
        setState(() => _savingHabitIds.remove(habitId));
      }
    }
  }

  Future<void> _addHabit({
    String? presetTitle,
    String? presetColor,
    String? presetTime,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('習慣を登録するにはログインしてください。');
      return;
    }

    TimeOfDay? initialTime;
    if (presetTime != null) {
      final parts = presetTime.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null &&
            minute != null &&
            hour >= 0 &&
            hour < 24 &&
            minute >= 0 &&
            minute < 60) {
          initialTime = TimeOfDay(hour: hour, minute: minute);
        }
      }
    }

    final input = await showDialog<_NewDailyHabitInput>(
      context: context,
      builder: (_) => _AddDailyHabitDialog(
        presetTitle: presetTitle,
        initialRemindTime: initialTime,
      ),
    );
    if (!mounted || input == null) return;

    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      _showSnack('習慣を登録するにはログインしてください。');
      return;
    }

    final defaults = await showDialog<HabitResourceEntry>(
      context: context,
      builder: (_) => HabitResourceMetricsDialog(
        dialogTitle: '標準コストを設定',
        submitLabel: '設定',
        habitTitle: input.title,
        goals: _goals,
      ),
    );
    if (!mounted || defaults == null) return;

    try {
      final inserter = widget.insertHabit ?? _defaultInsertHabit;
      await inserter(<String, dynamic>{
        'user_id': currentUserId,
        'title': input.title,
        'description': input.description,
        'color_hex': presetColor ?? '#4338CA',
        'remind_time': input.remindTime != null
            ? '${input.remindTime!.hour.toString().padLeft(2, '0')}:'
                '${input.remindTime!.minute.toString().padLeft(2, '0')}'
            : null,
        'goal_id': defaults.goalId,
        'goal_title': defaults.goalTitle,
        'default_time_cost_minutes': defaults.timeCostMinutes,
        'default_fatigue_score': defaults.fatigueScore,
        'default_goal_contribution_score': defaults.goalContributionScore,
      });
      if (!mounted) return;
      await _load();
      _showSnack('「${input.title}」を追加しました');
    } catch (e) {
      _showSnack(
        '習慣の追加に失敗しました。時間をおいて再試行してください。',
        backgroundColor: const Color(0xFFB71C1C),
      );
    }
  }

  Future<void> _deleteHabit(Map<String, dynamic> habit) async {
    final title = habit['title']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('習慣を削除'),
        content: Text('「$title」を削除しますか？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('削除するにはログインしてください。');
      return;
    }

    try {
      final deleter = widget.deleteHabit ?? _defaultDeleteHabit;
      final deleted = await deleter(userId, habit['id']);
      if (!mounted) return;
      if (!deleted) {
        _showSnack(
          '削除対象が見つからず、削除できませんでした。',
          backgroundColor: const Color(0xFFB71C1C),
        );
        return;
      }
      await _load();
      _showSnack('「$title」を削除しました');
    } catch (e) {
      _showSnack(
        '削除に失敗しました。時間をおいて再試行してください。',
        backgroundColor: const Color(0xFFB71C1C),
      );
    }
  }

  void _openLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  void _showPresetPicker() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('習慣を登録するにはログインしてください。');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'おすすめの毎日習慣',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _presets.map((p) {
                  return ListTile(
                    leading: Text(
                      p.$2,
                      style: const TextStyle(fontSize: 22, height: 1.4),
                    ),
                    title: Text(p.$1),
                    subtitle: Text('リマインド ${p.$4}'),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () {
                      Navigator.pop(ctx);
                      _addHabit(
                        presetTitle: p.$1,
                        presetColor: p.$3,
                        presetTime: p.$4,
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColorHex(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return const Color(0xFF4338CA);
    final normalized = text.replaceFirst('#', '');
    if (normalized.length != 6) return const Color(0xFF4338CA);
    final value = int.tryParse('FF$normalized', radix: 16);
    return value != null ? Color(value) : const Color(0xFF4338CA);
  }

  bool _isQuickTask(String title) {
    return _quickTaskKeywords.any((kw) => title.contains(kw));
  }

  @override
  Widget build(BuildContext context) {
    final active = _habits.where((h) => h['is_active'] == true).toList();
    final completedCount = active
        .where((h) => _completedToday.contains(h['id']?.toString()))
        .length;
    final progress = active.isEmpty ? 0.0 : completedCount / active.length;
    final remaining = active.length - completedCount;

    final List<Map<String, dynamic>> sortedActive;
    if (remaining > 0 && remaining <= 5) {
      sortedActive = List<Map<String, dynamic>>.of(active)
        ..sort((a, b) {
          final aCompleted =
              _completedToday.contains(a['id']?.toString()) ? 1 : 0;
          final bCompleted =
              _completedToday.contains(b['id']?.toString()) ? 1 : 0;
          if (aCompleted != bCompleted) return aCompleted - bCompleted;
          final aQuick = _isQuickTask(a['title']?.toString() ?? '') ? 0 : 1;
          final bQuick = _isQuickTask(b['title']?.toString() ?? '') ? 0 : 1;
          return aQuick - bQuick;
        });
    } else {
      sortedActive = active;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('毎日の習慣'),
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: 'リソース最適化',
            icon: const Icon(Icons.scatter_plot),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ResourceOptimizationPage(),
                settings: const RouteSettings(name: '/daily-habits'),
              ),
            ),
          ),
          if (!_requiresLogin) ...<Widget>[
            IconButton(
              key: const Key('daily_habits_appbar_preset_button'),
              tooltip: 'テンプレートから追加',
              onPressed: _showPresetPicker,
              icon: const Icon(Icons.flash_on),
            ),
            IconButton(
              key: const Key('daily_habits_appbar_add_button'),
              tooltip: '習慣を追加',
              onPressed: () => _addHabit(),
              icon: const Icon(Icons.add),
            ),
          ],
        ],
      ),
      body: _buildBody(
        sortedActive: sortedActive,
        completedCount: completedCount,
        totalCount: active.length,
        progress: progress,
        remaining: remaining,
      ),
    );
  }

  Widget _buildBody({
    required List<Map<String, dynamic>> sortedActive,
    required int completedCount,
    required int totalCount,
    required double progress,
    required int remaining,
  }) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_requiresLogin) {
      return _buildSignedOutState();
    }
    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }
    if (_habits.isEmpty) {
      return _buildEmptyState();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quickHintColor =
        isDark ? const Color(0xFFFFCC80) : const Color(0xFF9A3412);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: <Widget>[
              OutlinedButton.icon(
                key: const Key('daily_habits_header_preset_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                onPressed: _showPresetPicker,
                icon: const Icon(Icons.flash_on),
                label: const Text('テンプレート'),
              ),
              FilledButton.icon(
                key: const Key('daily_habits_header_add_button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                onPressed: () => _addHabit(),
                icon: const Icon(Icons.add),
                label: const Text('習慣を追加'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProgressCard(completedCount, totalCount, progress),
          if (remaining > 0 && remaining <= 5)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Row(
                children: <Widget>[
                  Icon(Icons.bolt, size: 16, color: quickHintColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '残り$remaining件 — 5分で終わるタスクを優先表示中',
                      style: TextStyle(
                        fontSize: 12,
                        color: quickHintColor,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          ...sortedActive.map(_buildHabitCard),
        ],
      ),
    );
  }

  Widget _buildSignedOutState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      key: const Key('daily_habits_signed_out_state'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_outline,
              size: 56,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'ログインすると毎日の習慣や連続達成記録を管理できます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: _openLogin,
              icon: const Icon(Icons.login),
              label: const Text('ログイン'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      key: const Key('daily_habits_error_state'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 56,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('daily_habits_retry_button'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      key: const Key('daily_habits_empty_state'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.repeat,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '毎日やることを登録して\n習慣化しましょう',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('daily_habits_empty_add_button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  onPressed: () => _addHabit(),
                  icon: const Icon(Icons.add),
                  label: const Text('習慣を追加'),
                ),
                OutlinedButton.icon(
                  key: const Key('daily_habits_empty_preset_button'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  onPressed: _showPresetPicker,
                  icon: const Icon(Icons.flash_on),
                  label: const Text('テンプレートから追加'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int done, int total, double progress) {
    final allDone = progress >= 1.0 && total > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allDone
              ? const <Color>[Color(0xFF1B5E20), Color(0xFF2E7D32)]
              : const <Color>[Color(0xFF283593), Color(0xFF3949AB)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                allDone ? Icons.emoji_events : Icons.today,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      allDone ? '今日は全て完了！' : '今日の習慣',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      '$done / $total 完了',
                      style: const TextStyle(
                        color: Color(0xFFF1F5F9),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.24),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          if (_allClearStreak > 0) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.workspace_premium,
                    color: Color(0xFFFFE082),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '前日全達成ストリーク: $_allClearStreak日連続',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
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

  Widget _buildHabitCard(Map<String, dynamic> habit) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final habitId = habit['id']?.toString() ?? '';
    final isCompleted = habitId.isNotEmpty && _completedToday.contains(habitId);
    final isSaving = habitId.isNotEmpty && _savingHabitIds.contains(habitId);
    final title = habit['title']?.toString() ?? '';
    final desc = habit['description']?.toString().trim() ?? '';
    final streak = DailyHabitsPage.safeInt(habit['streak']) ?? 0;
    final bestStreak = DailyHabitsPage.safeInt(habit['best_streak']) ?? 0;
    final color = _parseColorHex(habit['color_hex']?.toString());
    final todayLog = _todayLogs[habitId];

    final completedAccent =
        isDark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20);
    final completedBg =
        isDark ? const Color(0xFF14331B) : const Color(0xFFE8F5E9);
    final streakFg = isDark ? const Color(0xFFFFCC80) : const Color(0xFF9A3412);
    final streakBg = isDark ? const Color(0xFF3E2209) : const Color(0xFFFFF3E0);
    final metricsFg =
        isDark ? const Color(0xFF81C784) : const Color(0xFF166534);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCompleted
              ? completedAccent.withValues(alpha: 0.45)
              : colorScheme.surfaceContainerHigh,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? completedBg
                        : color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle : Icons.circle_outlined,
                    color: isCompleted ? completedAccent : color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                      if (desc.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (isCompleted && todayLog != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '${DailyHabitsPage.safeInt(todayLog['time_cost_minutes']) ?? '-'}分 ・ '
                          '疲労${DailyHabitsPage.safeDouble(todayLog['fatigue_score'])?.toStringAsFixed(0) ?? '-'} ・ '
                          '貢献${DailyHabitsPage.safeInt(todayLog['goal_contribution_score']) ?? '-'}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: metricsFg,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '$title の操作メニュー',
                  enabled: !isSaving,
                  onSelected: (v) {
                    if (v == 'delete') _deleteHabit(habit);
                  },
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        '削除',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFFFB4AB)
                              : const Color(0xFFB71C1C),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: streakBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.local_fire_department,
                          size: 14,
                          color: streakFg,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$streak日連続',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: streakFg,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (bestStreak > streak && bestStreak > 0)
                  Text(
                    '最高 $bestStreak日',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                FilledButton.tonalIcon(
                  key: Key('daily_habit_toggle_button_$habitId'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  onPressed: isSaving ? null : () => _toggleComplete(habit),
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isCompleted ? Icons.undo : Icons.check,
                          size: 18,
                        ),
                  label: Text(
                    isSaving
                        ? '保存中'
                        : isCompleted
                            ? '完了を取り消す'
                            : '完了にする',
                  ),
                ),
                if (isCompleted)
                  OutlinedButton.icon(
                    key: ValueKey<String>('edit_habit_resource_$habitId'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    onPressed:
                        isSaving ? null : () => _editTodayResource(habit),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('実績を修正'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewDailyHabitInput {
  final String title;
  final String? description;
  final TimeOfDay? remindTime;

  const _NewDailyHabitInput({
    required this.title,
    required this.description,
    required this.remindTime,
  });
}

class _AddDailyHabitDialog extends StatefulWidget {
  final String? presetTitle;
  final TimeOfDay? initialRemindTime;

  const _AddDailyHabitDialog({
    this.presetTitle,
    this.initialRemindTime,
  });

  @override
  State<_AddDailyHabitDialog> createState() => _AddDailyHabitDialogState();
}

class _AddDailyHabitDialogState extends State<_AddDailyHabitDialog> {
  late final TextEditingController _titleCtrl;
  final TextEditingController _descCtrl = TextEditingController();
  TimeOfDay? _remindTime;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.presetTitle ?? '');
    _remindTime = widget.initialRemindTime;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _remindTime ?? const TimeOfDay(hour: 21, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _remindTime = picked);
    }
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'タスク名を入力してください');
      return;
    }

    final descText = _descCtrl.text.trim();
    Navigator.pop(
      context,
      _NewDailyHabitInput(
        title: title,
        description: descText.isEmpty ? null : descText,
        remindTime: _remindTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('毎日の習慣を追加'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'タスク名 *',
                hintText: 'マネーフォワード更新・財布残高入力',
                errorText: _titleError,
                prefixIcon: const Icon(Icons.task_alt),
              ),
              autofocus: widget.presetTitle == null,
              onChanged: (_) {
                if (_titleError != null) {
                  setState(() => _titleError = null);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: '説明 (任意)',
                hintText: '毎晩寝る前に実施',
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(
                _remindTime != null
                    ? 'リマインド: ${_remindTime!.format(context)}'
                    : 'リマインド時刻 (任意)',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTime,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('追加'),
        ),
      ],
    );
  }
}
