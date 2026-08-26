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
  return {
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

/// 毎日の定型タスク (習慣) リマインダーページ。
/// マネーフォワード更新、財布残高入力、体重記録など毎日やるべきことを管理。
class DailyHabitsPage extends StatefulWidget {
  const DailyHabitsPage({super.key});

  @override
  State<DailyHabitsPage> createState() => _DailyHabitsPageState();
}

class _DailyHabitsPageState extends State<DailyHabitsPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _habits = [];
  Set<String> _completedToday = {};
  Map<String, Map<String, dynamic>> _todayLogs = {};
  List<HabitGoalOption> _goals = [];
  final Set<String> _savingHabitIds = {};
  final DateTime _selectedDate = DateTime.now();
  int _allClearStreak = 0; // 全習慣達成の連続日数

  /// 5分で終わりそうなタスク名キーワード
  static const _quickTaskKeywords = [
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

  static const _presets = [
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

  String get _todayStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait<dynamic>([
        _supabase
            .from('daily_habits')
            .select()
            .eq('user_id', userId)
            .order('created_at')
            .then<dynamic>((value) => value),
        _supabase
            .from('daily_habit_logs')
            .select(
              'habit_id, time_cost_minutes, fatigue_score, '
              'goal_contribution_score, goal_id, goal_title',
            )
            .eq('user_id', userId)
            .eq('completed_date', _todayStr)
            .then<dynamic>((value) => value),
        _loadGoalOptions(),
      ]);

      final habits = List<Map<String, dynamic>>.from(results[0] as List);
      final logs = List<Map<String, dynamic>>.from(results[1] as List);
      final completed =
          logs.map((l) => l['habit_id']?.toString() ?? '').toSet();
      final todayLogs = <String, Map<String, dynamic>>{
        for (final log in logs)
          if ((log['habit_id']?.toString() ?? '').isNotEmpty)
            log['habit_id'].toString(): log,
      };
      final goals = results[2] as List<HabitGoalOption>;

      // 全習慣達成ストリークを計算
      final streak = await _calcAllClearStreak(userId, habits);

      if (mounted) {
        setState(() {
          _habits = habits;
          _completedToday = completed;
          _todayLogs = todayLogs;
          _goals = goals;
          _allClearStreak = streak;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('DailyHabitsPage load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<HabitGoalOption>> _loadGoalOptions() async {
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'goal.list'},
      );
      final data = response.data;
      final rows = data is Map && data['goals'] is List
          ? data['goals'] as List
          : const [];
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
      return const [];
    }
  }

  /// 全習慣達成を連続何日達成しているかを計算
  Future<int> _calcAllClearStreak(
    String userId,
    List<Map<String, dynamic>> habits,
  ) async {
    final activeHabits = habits.where((h) => h['is_active'] == true).toList();
    if (activeHabits.isEmpty) return 0;
    final activeCount = activeHabits.length;

    int streak = 0;
    // 昨日から遡って確認 (最大365日)
    for (int i = 1; i <= 365; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      try {
        final logs = await _supabase
            .from('daily_habit_logs')
            .select('habit_id')
            .eq('user_id', userId)
            .eq('completed_date', dateStr);
        final logList = List<Map<String, dynamic>>.from(logs as List);
        if (logList.length >= activeCount) {
          streak++;
        } else {
          break;
        }
      } catch (_) {
        break;
      }
    }
    return streak;
  }

  Future<void> _toggleComplete(Map<String, dynamic> habit) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final habitId = habit['id']?.toString() ?? '';
    if (habitId.isEmpty || _savingHabitIds.contains(habitId)) return;
    final isCompleted = _completedToday.contains(habitId);

    setState(() => _savingHabitIds.add(habitId));

    try {
      if (isCompleted) {
        // 完了取り消し
        await _supabase
            .from('daily_habit_logs')
            .delete()
            .eq('habit_id', habitId)
            .eq('completed_date', _todayStr)
            .select();

        // streak を減算
        final currentStreak = (habit['streak'] as int? ?? 0);
        if (currentStreak > 0) {
          await _supabase.from('daily_habits').update({
            'streak': currentStreak - 1,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', habitId);
        }
      } else {
        // 完了記録
        final resourceEntry = _defaultResourceEntry(habit);
        await _supabase.from('daily_habit_logs').insert({
          'user_id': userId,
          'habit_id': habitId,
          'completed_date': _todayStr,
          ...buildHabitResourceMeasurementPayload(
            resourceEntry,
            isSelfReported: false,
          ),
        });

        // streak を加算
        final currentStreak = (habit['streak'] as int? ?? 0) + 1;
        final bestStreak = habit['best_streak'] as int? ?? 0;
        await _supabase.from('daily_habits').update({
          'streak': currentStreak,
          'best_streak':
              currentStreak > bestStreak ? currentStreak : bestStreak,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', habitId);
      }
      await _load();
      if (!isCompleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('既定値で完了を記録しました'),
            action: SnackBarAction(
              label: '実績を修正',
              onPressed: () async => _editTodayResource(habit),
            ),
          ),
        );
      }
    } catch (e) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingHabitIds.remove(habitId));
      }
    }
  }

  HabitResourceEntry _defaultResourceEntry(Map<String, dynamic> habit) {
    final goalId = habit['goal_id']?.toString();
    final goalTitle = habit['goal_title']?.toString();
    return HabitResourceEntry(
      timeCostMinutes:
          (habit['default_time_cost_minutes'] as num?)?.toInt() ?? 15,
      fatigueScore: (habit['default_fatigue_score'] as num?)?.toDouble() ?? 3,
      goalContributionScore:
          (habit['default_goal_contribution_score'] as num?)?.toDouble() ?? 50,
      goalId: (goalId?.isEmpty ?? true) ? null : goalId,
      goalTitle: (goalTitle?.isEmpty ?? true) ? null : goalTitle,
    );
  }

  Future<void> _editTodayResource(Map<String, dynamic> habit) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
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
            (log['time_cost_minutes'] as num?)?.toInt() ?? 15,
        initialFatigueScore: (log['fatigue_score'] as num?)?.toDouble() ?? 3,
        initialGoalContributionScore:
            (log['goal_contribution_score'] as num?)?.toDouble() ?? 50,
        initialGoalId: initialGoalId,
      ),
    );
    if (!mounted || entry == null || !_completedToday.contains(habitId)) return;

    setState(() => _savingHabitIds.add(habitId));
    try {
      await _supabase
          .from('daily_habit_logs')
          .update(
            buildHabitResourceMeasurementPayload(
              entry,
              isSelfReported: true,
            ),
          )
          .eq('user_id', userId)
          .eq('habit_id', habitId)
          .eq('completed_date', _todayStr)
          .select();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今日の実績を更新しました')),
        );
      }
    } catch (e) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingHabitIds.remove(habitId));
      }
    }
  }

  Future<void> _addHabit({
    String? presetTitle,
    String? presetEmoji,
    String? presetColor,
    String? presetTime,
  }) async {
    final titleCtrl = TextEditingController(text: presetTitle ?? '');
    final descCtrl = TextEditingController();
    TimeOfDay? remindTime;
    if (presetTime != null) {
      final parts = presetTime.split(':');
      remindTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('毎日の習慣を追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'タスク名 *',
                    hintText: 'マネーフォワード更新・財布残高入力',
                    prefixIcon: Icon(Icons.task_alt),
                  ),
                  autofocus: presetTitle == null,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
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
                    remindTime != null
                        ? 'リマインド: ${remindTime!.format(ctx)}'
                        : 'リマインド時刻 (任意)',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime:
                          remindTime ?? const TimeOfDay(hour: 21, minute: 0),
                    );
                    if (picked != null) {
                      setD(() => remindTime = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    if (!mounted) return;
    final defaults = await showDialog<HabitResourceEntry>(
      context: context,
      builder: (_) => HabitResourceMetricsDialog(
        dialogTitle: '標準コストを設定',
        submitLabel: '設定',
        habitTitle: title,
        goals: _goals,
      ),
    );
    if (defaults == null) return;

    try {
      await _supabase.from('daily_habits').insert({
        'user_id': userId,
        'title': title,
        'description':
            descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        'color_hex': presetColor ?? '#4338CA',
        'remind_time': remindTime != null
            ? '${remindTime!.hour.toString().padLeft(2, '0')}:${remindTime!.minute.toString().padLeft(2, '0')}'
            : null,
        'goal_id': defaults.goalId,
        'goal_title': defaults.goalTitle,
        'default_time_cost_minutes': defaults.timeCostMinutes,
        'default_fatigue_score': defaults.fatigueScore,
        'default_goal_contribution_score': defaults.goalContributionScore,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('「$title」を追加しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  Future<void> _deleteHabit(Map<String, dynamic> habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('習慣を削除'),
        content: Text('「${habit['title']}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase
          .from('daily_habits')
          .delete()
          .eq('id', habit['id'])
          .select();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _habits.where((h) => h['is_active'] == true).toList();
    final completedCount = active
        .where((h) => _completedToday.contains(h['id']?.toString()))
        .length;
    final progress = active.isEmpty ? 0.0 : completedCount / active.length;
    final remaining = active.length - completedCount;

    // 残り件数が少ない場合、5分で終わるタスクを上に寄せる
    List<Map<String, dynamic>> sortedActive;
    if (remaining > 0 && remaining <= 5) {
      sortedActive = List.of(active)
        ..sort((a, b) {
          final aCompleted =
              _completedToday.contains(a['id']?.toString()) ? 1 : 0;
          final bCompleted =
              _completedToday.contains(b['id']?.toString()) ? 1 : 0;
          if (aCompleted != bCompleted) return aCompleted - bCompleted;
          // 未完了の中でクイックタスクを上に
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
        actions: [
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
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'preset',
            onPressed: _showPresetPicker,
            backgroundColor: const Color(0xFFFF6B35),
            child: const Icon(Icons.flash_on),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => _addHabit(),
            icon: const Icon(Icons.add),
            label: const Text('追加'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildProgressCard(completedCount, active.length, progress),
                    if (remaining > 0 && remaining <= 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          '⚡ 残り$remaining件 — 5分で終わるタスクを優先表示中',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFF57C00),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    ...sortedActive.map(_buildHabitCard),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.repeat,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              '毎日やることを登録して\n習慣化しましょう',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFFB0B0B0),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showPresetPicker,
              icon: const Icon(Icons.flash_on),
              label: const Text('テンプレートから追加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPresetPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                      style: const TextStyle(fontSize: 24, height: 1.5),
                    ),
                    title: Text(p.$1),
                    subtitle: Text('リマインド ${p.$4}'),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () {
                      Navigator.pop(ctx);
                      _addHabit(
                        presetTitle: p.$1,
                        presetEmoji: p.$2,
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

  Widget _buildProgressCard(int done, int total, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: progress >= 1.0
              ? [const Color(0xFF43A047), const Color(0xFF66BB6A)]
              : [const Color(0xFF303F9F), const Color(0xFF3F51B5)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                progress >= 1.0 ? Icons.emoji_events : Icons.today,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress >= 1.0 ? '🎉 今日は全て完了！' : '今日の習慣',
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
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
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
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 8,
            ),
          ),
          if (_allClearStreak > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(width: 6),
                  Text(
                    '前日全達成ストリーク: $_allClearStreak日連続！',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
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

  bool _isQuickTask(String title) {
    return _quickTaskKeywords.any((kw) => title.contains(kw));
  }

  Widget _buildHabitCard(Map<String, dynamic> habit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habitId = habit['id']?.toString() ?? '';
    final title = habit['title']?.toString() ?? '';
    final desc = habit['description']?.toString();
    final streak = habit['streak'] as int? ?? 0;
    final bestStreak = habit['best_streak'] as int? ?? 0;
    final isCompleted = _completedToday.contains(habitId);
    final isSaving = _savingHabitIds.contains(habitId);
    final todayLog = _todayLogs[habitId];
    final colorHex = habit['color_hex']?.toString() ?? '#4338CA';
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCompleted
              ? const Color(0xFFA5D6A7)
              : Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
      child: InkWell(
        onTap: isSaving ? null : () => _toggleComplete(habit),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? (isDark
                          ? const Color(0xFF0A1A0A)
                          : const Color(0xFFE8F5E9))
                      : color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  color: isCompleted ? const Color(0xFF4CAF50) : color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? const Color(0xFFB0B0B0) : null,
                        height: 1.5,
                      ),
                    ),
                    if (desc != null && desc.isNotEmpty)
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    if (isCompleted && todayLog != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${(todayLog['time_cost_minutes'] as num?)?.round() ?? '-'}分 ・ '
                        '疲労${(todayLog['fatigue_score'] as num?)?.toStringAsFixed(0) ?? '-'} ・ '
                        '貢献${(todayLog['goal_contribution_score'] as num?)?.round() ?? '-'}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF168C5A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A1A00)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🔥 $streak日',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF6B35),
                      height: 1.5,
                    ),
                  ),
                ),
              if (bestStreak > streak && bestStreak > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '🏆$bestStreak',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              if (isCompleted)
                IconButton(
                  key: ValueKey('edit_habit_resource_$habitId'),
                  tooltip: '今日の実績を修正',
                  visualDensity: VisualDensity.compact,
                  iconSize: 19,
                  onPressed: isSaving ? null : () => _editTodayResource(habit),
                  icon: const Icon(Icons.edit_note),
                ),
              PopupMenuButton<String>(
                enabled: !isSaving,
                onSelected: (v) {
                  if (v == 'delete') _deleteHabit(habit);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      '削除',
                      style: TextStyle(color: Color(0xFFE53935), height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
