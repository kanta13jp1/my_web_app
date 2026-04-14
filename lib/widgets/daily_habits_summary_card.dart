import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ホーム画面に表示する今日の習慣サマリーカード。
/// daily_habits テーブルから今日の完了率を表示し、
/// タップで /daily-habits ページへ遷移する。
class DailyHabitsSummaryCard extends StatefulWidget {
  const DailyHabitsSummaryCard({super.key});

  @override
  State<DailyHabitsSummaryCard> createState() => _DailyHabitsSummaryCardState();
}

class _DailyHabitsSummaryCardState extends State<DailyHabitsSummaryCard> {
  bool _loading = true;
  int _total = 0;
  int _completed = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final habits = await Supabase.instance.client
          .from('daily_habits')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true);

      final today = _todayKey();
      final logs = await Supabase.instance.client
          .from('daily_habit_logs')
          .select('habit_id')
          .eq('user_id', userId)
          .eq('completed_date', today);

      if (!mounted) return;
      setState(() {
        _total = (habits as List).length;
        _completed = (logs as List).length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _total == 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = _total > 0 ? _completed / _total : 0.0;
    final allDone = _completed >= _total;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).pushNamed('/daily-habits'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: allDone
              ? Colors.green.withAlpha(isDark ? 25 : 15)
              : (isDark ? const Color(0xFF1A2233) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: allDone
                ? Colors.green.withAlpha(60)
                : (isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (allDone ? Colors.green : Colors.orange)
                    .withAlpha(isDark ? 40 : 20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                allDone
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                size: 20,
                color: allDone ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allDone ? '今日の習慣 完了！🎉' : '今日の習慣',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: allDone
                          ? Colors.green
                          : (isDark ? Colors.white : const Color(0xFF1E293B)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: Colors.grey.withAlpha(40),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        allDone ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$_completed/$_total',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: allDone ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
