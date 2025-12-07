import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/daily_challenge_service.dart';
import '../models/daily_challenge.dart';
import '../utils/app_logger.dart';
// ✅ 追加: AIサービスをインポート
import '../services/ai_service.dart';

class DailyChallengesPage extends StatefulWidget {
  const DailyChallengesPage({super.key});

  @override
  State<DailyChallengesPage> createState() => _DailyChallengesPageState();
}

class _DailyChallengesPageState extends State<DailyChallengesPage> {
  final _supabase = Supabase.instance.client;
  late DailyChallengeService _challengeService;
  // ✅ 追加: AIサービス
  late AIService _aiService;

  List<Map<String, dynamic>> _challenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _challengeService = DailyChallengeService(_supabase);
    // ✅ 追加: AIサービスの初期化
    _aiService = AIService(_supabase);
    _loadChallenges();
  }

  // 🔥 管理者判定ロジック
  bool get _isAdmin {
    final user = _supabase.auth.currentUser;
    return user?.email == 'kanta13jp@gmail.com';
  }

  // 🔥 管理者用: 手動でチャレンジを生成する
  Future<void> _generateTodaysChallenges() async {
    setState(() => _isLoading = true);
    try {
      // 今日の日付で生成を実行
      await _aiService.generateDailyChallenges();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AIが今日のチャレンジを生成しました！🤖✨'),
            backgroundColor: Colors.purple,
          ),
        );
        // 生成後にリストを再読み込み
        await _loadChallenges();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('生成エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final challenges =
          await _challengeService.getTodaysChallengesWithProgress(userId);

      setState(() {
        _challenges = challenges;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to load challenges',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _claimReward(int challengeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final success =
        await _challengeService.claimChallengeReward(userId, challengeId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('報酬を受け取りました！🎉'),
          backgroundColor: Colors.amber,
          duration: Duration(seconds: 2),
        ),
      );
      _loadChallenges(); // Reload to update UI
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('デイリーチャレンジ'),
        actions: [
          // 🔥 管理者のみ表示される生成ボタン
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              color: Colors.purpleAccent,
              tooltip: 'AIでチャレンジ生成 (管理者)',
              onPressed: _isLoading ? null : _generateTodaysChallenges,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChallenges,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadChallenges,
              child: _challenges.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('今日のチャレンジはありません'),
                          if (_isAdmin) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _generateTodaysChallenges,
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('AIで生成する'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          '今日のチャレンジ',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'チャレンジを達成してポイントを獲得しよう！',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 20),
                        ..._challenges.map(_buildChallengeCard),
                      ],
                    ),
            ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challengeData) {
    final challenge = challengeData['challenge'] as DailyChallenge;
    final currentProgress = challengeData['current_progress'] as int;
    final isCompleted = challengeData['is_completed'] as bool;
    final rewardClaimed = challengeData['reward_claimed'] as bool;

    final progress = currentProgress / challenge.targetValue;
    final progressClamped = progress.clamp(0.0, 1.0);

    IconData icon;
    Color iconColor;

    switch (challenge.challengeType) {
      case 'create_notes':
        icon = Icons.note_add;
        iconColor = Colors.blue;
        break;
      case 'earn_points':
        icon = Icons.star;
        iconColor = Colors.amber;
        break;
      case 'share_notes':
        icon = Icons.share;
        iconColor = Colors.green;
        break;
      default:
        icon = Icons.check_circle;
        iconColor = Colors.purple;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.challengeTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        challenge.challengeDescription,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '進捗: $currentProgress / ${challenge.targetValue}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${(progressClamped * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressClamped,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted ? Colors.green : iconColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.card_giftcard,
                      size: 20,
                      color: Colors.amber[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '報酬: ${challenge.rewardPoints}ポイント',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
                if (isCompleted)
                  ElevatedButton.icon(
                    onPressed:
                        rewardClaimed ? null : () => _claimReward(challenge.id),
                    icon: Icon(
                      rewardClaimed ? Icons.check : Icons.card_giftcard,
                      size: 18,
                    ),
                    label: Text(
                      rewardClaimed ? '受取済' : '受け取る',
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          rewardClaimed ? Colors.grey : Colors.green,
                      foregroundColor: Colors.white,
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
