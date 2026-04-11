import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI大学ホームカード — ホーム最上部に表示するキラーコンテンツバナー
///
/// 機能:
/// - プロバイダー絵文字一覧 (DB登録数に関わらず既知分を表示)
/// - クイズ達成数 (SharedPreferences から取得)
/// - シェアボタン (share_plus)
/// - タップで /gemini-university へ遷移

class AiUniversityHomeCard extends StatefulWidget {
  const AiUniversityHomeCard({super.key});

  @override
  State<AiUniversityHomeCard> createState() => _AiUniversityHomeCardState();
}

class _AiUniversityHomeCardState extends State<AiUniversityHomeCard> {
  final _supabase = Supabase.instance.client;
  int _answeredCount = 0;
  int _currentStreak = 0;
  int _badgeCount = 0;
  static const int _totalQuizzes = 9; // google/openai/anthropic/microsoft/meta/x/deepseek/mistral/perplexity
  static const String _prefsKey = 'ai_univ_answered_quizzes';

  static const List<String> _providerEmojis = [
    '🔵', '⚫', '🟠', '🔷', '🟣', '⚡', '🐋', '💨', '🔍',
  ];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey) ?? '';
    final answered = saved.isEmpty ? <String>[] : saved.split(',');
    if (mounted) {
      setState(() => _answeredCount = answered.length);
    }

    // Supabase からクロスデバイス学習記録・ストリーク・バッジ数を取得
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final scoresRow = await _supabase
          .from('ai_university_scores')
          .select('provider_id')
          .eq('user_id', user.id)
          .eq('quiz_correct', true)
          .timeout(const Duration(seconds: 5));
      final remoteCount =
          ((scoresRow as List).cast<Map<String, dynamic>>()).length;
      final streakRow = await _supabase
          .from('ai_university_streaks')
          .select('current_streak')
          .eq('user_id', user.id)
          .maybeSingle();
      final badgeRow = await _supabase
          .from('ai_university_badges')
          .select('id')
          .eq('user_id', user.id)
          .count(CountOption.exact);
      if (mounted) {
        setState(() {
          // リモート記録があればローカルより優先 (クロスデバイス対応)
          if (remoteCount > _answeredCount) _answeredCount = remoteCount;
          _currentStreak =
              (streakRow?['current_streak'] as num?)?.toInt() ?? 0;
          _badgeCount = badgeRow.count;
        });
      }
    } catch (_) {
      // 取得失敗はサイレント — ローカルデータを維持
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text: '自分株式会社の AI 大学で学習中！\n'
            'Google・OpenAI・Anthropic・DeepSeek・Mistral・Perplexityなど9社以上のAIを総合的に学べます。\n'
            'https://my-web-app-b67f4.web.app/#/gemini-university\n'
            '#AILearning #buildinpublic #FlutterWeb',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalQuizzes == 0
        ? 0.0
        : _answeredCount / _totalQuizzes;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/gemini-university'),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A0A2E), Color(0xFF0D1B3E), Color(0xFF3949AB)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // タイトル行
              Row(
                children: [
                  const Text(
                    '🎓 AI 大学',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white70),
                    tooltip: '共有',
                    onPressed: _share,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '9社以上のAIを総合的に学ぶ — 毎週最新情報に自動更新',
                style: TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),

              // プロバイダー絵文字
              Row(
                children: _providerEmojis
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),

              // ストリーク・バッジ行 (ログイン済みかつデータあり時のみ表示)
              if (_currentStreak > 0 || _badgeCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (_currentStreak > 0) ...[
                        const Text('🔥', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          '$_currentStreak 日連続',
                          style: const TextStyle(
                            color: Color(0xFFFF6B35),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (_badgeCount > 0) ...[
                        const Text('🏅', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          '$_badgeCount バッジ',
                          style: const TextStyle(
                            color: Color(0xFFFFC107),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // 達成度バー + ボタン
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📊 クイズ達成: $_answeredCount / $_totalQuizzes 問',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFC107),
                          ),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/gemini-university'),
                    child: const Text(
                      '今すぐ学ぶ →',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
