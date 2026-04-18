import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// ログイン継続日数（ストリーク）カード。
/// SharedPreferences でローカル管理し、毎日アクセスすることを促す。
/// ストリークが途切れた場合でも再スタートを促す。
class LoginStreakCard extends StatefulWidget {
  const LoginStreakCard({super.key});

  @override
  State<LoginStreakCard> createState() => _LoginStreakCardState();
}

class _LoginStreakCardState extends State<LoginStreakCard> {
  int _streak = 0;
  int _bestStreak = 0;

  static const _keyLastDate = 'login_streak_last_date';
  static const _keyStreak = 'login_streak_count';
  static const _keyBest = 'login_streak_best';

  @override
  void initState() {
    super.initState();
    _updateStreak();
  }

  Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final lastDate = prefs.getString(_keyLastDate) ?? '';
    final streak = prefs.getInt(_keyStreak) ?? 0;
    final best = prefs.getInt(_keyBest) ?? 0;

    int newStreak = streak;

    if (lastDate == today) {
      // Already recorded today
      if (!mounted) return;
      setState(() {
        _streak = streak;
        _bestStreak = best;
        // recorded
      });
      return;
    }

    final yesterday =
        _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    if (lastDate == yesterday) {
      // Consecutive day
      newStreak = streak + 1;
    } else if (lastDate.isEmpty) {
      // First ever login
      newStreak = 1;
    } else {
      // Streak broken
      newStreak = 1;
    }

    final newBest = newStreak > best ? newStreak : best;
    await prefs.setString(_keyLastDate, today);
    await prefs.setInt(_keyStreak, newStreak);
    await prefs.setInt(_keyBest, newBest);

    if (!mounted) return;
    setState(() {
      _streak = newStreak;
      _bestStreak = newBest;
      // recorded
    });
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String get _streakEmoji {
    if (_streak >= 365) return '👑';
    if (_streak >= 100) return '🏆';
    if (_streak >= 30) return '🔥';
    if (_streak >= 7) return '⚡';
    return '✨';
  }

  bool _isMilestone(int streak) =>
      streak == 3 ||
      streak == 7 ||
      streak == 14 ||
      streak == 30 ||
      streak == 100 ||
      streak == 365;

  Future<void> _shareOnX() async {
    final text = Uri.encodeComponent(
        '自分株式会社に$_streak日連続アクセス中！$_streakEmoji $_streakLabel\n'
        '#buildinpublic #自分株式会社\n'
        'https://my-web-app-b67f4.web.app/');
    final url = Uri.parse('https://x.com/intent/tweet?text=$text');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  String get _streakLabel {
    if (_streak >= 365) return '1年以上！伝説のユーザー';
    if (_streak >= 100) return '100日達成！チャンピオン';
    if (_streak >= 30) return '1ヶ月継続！素晴らしい';
    if (_streak >= 7) return '1週間継続！順調です';
    if (_streak >= 3) return '3日連続！いい調子';
    return '継続は力なり！';
  }

  /// 次のマイルストーンを返す
  int get _nextMilestone {
    const milestones = [3, 7, 14, 30, 100, 365];
    for (final m in milestones) {
      if (_streak < m) return m;
    }
    return 365;
  }

  /// 前のマイルストーン（0 or 直前）
  int get _prevMilestone {
    const milestones = [0, 3, 7, 14, 30, 100];
    int prev = 0;
    for (final m in milestones) {
      if (_streak >= m) prev = m;
    }
    return prev;
  }

  double get _milestoneProgress {
    final next = _nextMilestone;
    final prev = _prevMilestone;
    if (next == prev) return 1.0;
    return (_streak - prev) / (next - prev);
  }

  @override
  Widget build(BuildContext context) {
    if (_streak == 0) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF7C3AED).withAlpha(60)
              : const Color(0xFFDDD6FE),
        ),
      ),
      color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFF5F3FF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withAlpha(isDark ? 40 : 20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _streakEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$_streak日連続アクセス中',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFDDD6FE)
                              : const Color(0xFF4C1D95),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _streakLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _milestoneProgress,
                            minHeight: 4,
                            backgroundColor:
                                const Color(0xFF7C3AED).withAlpha(30),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '次: $_nextMilestone日',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_bestStreak > _streak)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '最高記録',
                    style: TextStyle(fontSize: 10, color: Color(0xFFB0B0B0)),
                  ),
                  Text(
                    '$_bestStreak日',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            if (_isMilestone(_streak)) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Text('𝕏', style: TextStyle(fontSize: 16)),
                tooltip: 'Xでシェア',
                onPressed: _shareOnX,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
