import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// GitHub のコントリビューショングラフ風のアクティビティカレンダー。
/// ノート作成・習慣完了・ログインを日別に集計し、
/// 継続モチベーションを高める。
class ActivityCalendarCard extends StatefulWidget {
  const ActivityCalendarCard({super.key});

  @override
  State<ActivityCalendarCard> createState() => _ActivityCalendarCardState();
}

class _ActivityCalendarCardState extends State<ActivityCalendarCard> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;

  // 日付 → アクティビティ数
  final Map<String, int> _activity = {};
  int _totalDays = 0;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final since = DateTime.now().subtract(const Duration(days: 90));
      final sinceStr = since.toIso8601String().substring(0, 10);

      // ノート作成日を集計
      final notes = await _supabase
          .from('notes')
          .select('created_at')
          .eq('user_id', userId)
          .gte('created_at', sinceStr);

      // 習慣完了日を集計
      final habitLogs = await _supabase
          .from('daily_habit_logs')
          .select('completed_date')
          .eq('user_id', userId)
          .gte('completed_date', sinceStr);

      final activity = <String, int>{};

      for (final n in notes) {
        final raw = n['created_at']?.toString() ?? '';
        if (raw.length >= 10) {
          final key = raw.substring(0, 10);
          activity[key] = (activity[key] ?? 0) + 1;
        }
      }

      for (final h in habitLogs) {
        final key = h['completed_date']?.toString() ?? '';
        if (key.length >= 10) {
          activity[key] = (activity[key] ?? 0) + 1;
        }
      }

      // 現在のストリーク計算
      int streak = 0;
      DateTime day = DateTime.now();
      while (true) {
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        if (activity.containsKey(key)) {
          streak++;
          day = day.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _activity.addAll(activity);
        _totalDays = activity.keys.length;
        _currentStreak = streak;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _cellColor(int count, bool isDark) {
    if (count == 0) {
      return isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    }
    if (count == 1) return const Color(0xFF6366F1).withAlpha(120);
    if (count <= 3) return const Color(0xFF6366F1).withAlpha(180);
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const SizedBox.shrink();
    if (_loading) return const SizedBox.shrink();
    if (_activity.isEmpty && _totalDays == 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // 過去13週分 (91日) を日曜始まりで表示
    final startDay = now.subtract(Duration(days: now.weekday % 7 + 12 * 7));
    final weeks = <List<DateTime>>[];
    DateTime cursor = startDay;
    for (int w = 0; w < 13; w++) {
      final week = <DateTime>[];
      for (int d = 0; d < 7; d++) {
        week.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
      weeks.add(week);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF6366F1).withAlpha(40)
              : const Color(0xFFDDD6FE),
        ),
      ),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 6),
                Text(
                  'アクティビティカレンダー',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Text(
                  '$_totalDays日 アクティブ',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Calendar grid
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: weeks.map((week) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Column(
                      children: week.map((day) {
                        final key =
                            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                        final count = _activity[key] ?? 0;
                        final isToday = key ==
                            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                        return Tooltip(
                          message: count > 0 ? '$key: $countアクション' : key,
                          child: Container(
                            width: 13,
                            height: 13,
                            margin: const EdgeInsets.only(bottom: 3),
                            decoration: BoxDecoration(
                              color: _cellColor(count, isDark),
                              borderRadius: BorderRadius.circular(3),
                              border: isToday
                                  ? Border.all(
                                      color: const Color(0xFF6366F1),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_currentStreak > 0) ...[
                  const Icon(
                    Icons.local_fire_department,
                    size: 13,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$_currentStreak日連続',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                const Spacer(),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  'なし',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withAlpha(120),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '少',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '多',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
