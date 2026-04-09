import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final results = await Future.wait([
        _supabase
            .from('daily_habits')
            .select()
            .eq('user_id', userId)
            .order('created_at'),
        _supabase
            .from('daily_habit_logs')
            .select('habit_id')
            .eq('user_id', userId)
            .eq('completed_date', _todayStr),
      ]);

      final habits = List<Map<String, dynamic>>.from(results[0] as List);
      final logs = List<Map<String, dynamic>>.from(results[1] as List);
      final completed =
          logs.map((l) => l['habit_id']?.toString() ?? '').toSet();

      // 全習慣達成ストリークを計算
      final streak = await _calcAllClearStreak(userId, habits);

      if (mounted) {
        setState(() {
          _habits = habits;
          _completedToday = completed;
          _allClearStreak = streak;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('DailyHabitsPage load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 全習慣達成を連続何日達成しているかを計算
  Future<int> _calcAllClearStreak(
    String userId,
    List<Map<String, dynamic>> habits,
  ) async {
    final activeHabits =
        habits.where((h) => h['is_active'] == true).toList();
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
    final isCompleted = _completedToday.contains(habitId);

    try {
      if (isCompleted) {
        // 完了取り消し
        await _supabase
            .from('daily_habit_logs')
            .delete()
            .eq('habit_id', habitId)
            .eq('completed_date', _todayStr);

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
        await _supabase.from('daily_habit_logs').insert({
          'user_id': userId,
          'habit_id': habitId,
          'completed_date': _todayStr,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
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
                      initialTime: remindTime ?? const TimeOfDay(hour: 21, minute: 0),
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
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$title」を追加しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase.from('daily_habits').delete().eq('id', habit['id']);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _habits.where((h) => h['is_active'] == true).toList();
    final completedCount =
        active.where((h) => _completedToday.contains(h['id']?.toString())).length;
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
      appBar: AppBar(title: const Text('毎日の習慣'), elevation: 0),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'preset',
            onPressed: _showPresetPicker,
            backgroundColor: Colors.orange,
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
                    _buildProgressCard(
                      completedCount,
                      active.length,
                      progress,
                    ),
                    if (remaining > 0 && remaining <= 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          '⚡ 残り$remaining件 — 5分で終わるタスクを優先表示中',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
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
            Icon(Icons.repeat, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              '毎日やることを登録して\n習慣化しましょう',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _presets.map((p) {
                  return ListTile(
                    leading: Text(p.$2, style: const TextStyle(fontSize: 24)),
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
              ? [Colors.green.shade600, Colors.green.shade400]
              : [Colors.indigo.shade700, Colors.indigo.shade500],
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
                      ),
                    ),
                    Text(
                      '$done / $total 完了',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
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
                  const Text('🏆', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    '前日全達成ストリーク: $_allClearStreak日連続！',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
    return _quickTaskKeywords.any(
      (kw) => title.contains(kw),
    );
  }

  Widget _buildHabitCard(Map<String, dynamic> habit) {
    final habitId = habit['id']?.toString() ?? '';
    final title = habit['title']?.toString() ?? '';
    final desc = habit['description']?.toString();
    final streak = habit['streak'] as int? ?? 0;
    final bestStreak = habit['best_streak'] as int? ?? 0;
    final isCompleted = _completedToday.contains(habitId);
    final colorHex = habit['color_hex']?.toString() ?? '#4338CA';
    final color = Color(
      int.parse(colorHex.replaceFirst('#', '0xFF')),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCompleted ? Colors.green.shade200 : Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleComplete(habit),
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
                      ? Colors.green.shade50
                      : color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  color: isCompleted ? Colors.green : color,
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
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: isCompleted ? Colors.grey : null,
                      ),
                    ),
                    if (desc != null && desc.isNotEmpty)
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
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
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🔥 $streak日',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.deepOrange,
                    ),
                  ),
                ),
              if (bestStreak > streak && bestStreak > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '🏆$bestStreak',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') _deleteHabit(habit);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('削除', style: TextStyle(color: Colors.red)),
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
