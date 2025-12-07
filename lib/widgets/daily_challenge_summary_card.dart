import 'package:flutter/material.dart';
import '../main.dart'; // supabase getter
import '../services/daily_challenge_service.dart';
import '../models/daily_challenge.dart';
import '../pages/daily_challenges_page.dart';

class DailyChallengeSummaryCard extends StatefulWidget {
  const DailyChallengeSummaryCard({super.key});

  @override
  State<DailyChallengeSummaryCard> createState() =>
      _DailyChallengeSummaryCardState();
}

class _DailyChallengeSummaryCardState extends State<DailyChallengeSummaryCard> {
  late final DailyChallengeService _challengeService;
  List<Map<String, dynamic>> _challenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _challengeService = DailyChallengeService(supabase);
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final challenges =
          await _challengeService.getTodaysChallengesWithProgress(userId);

      if (mounted) {
        setState(() {
          _challenges = challenges;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ページ遷移から戻ってきた時に更新する
  void _onTap() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DailyChallengesPage()),
    );
    _loadChallenges();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_challenges.isEmpty) return const SizedBox.shrink();

    // 完了した数
    final completedCount =
        _challenges.where((c) => c['is_completed'] as bool).length;
    final totalCount = _challenges.length;
    final allCompleted = completedCount == totalCount && totalCount > 0;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.task_alt, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '今日のチャレンジ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: allCompleted
                          ? Colors.green
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      allCompleted ? '全達成 🎉' : '$completedCount / $totalCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: allCompleted
                            ? Colors.white
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._challenges
                  .take(3)
                  .map((data) => _buildMiniChallengeRow(data)),
              if (_challenges.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '...他 ${_challenges.length - 3} 件',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChallengeRow(Map<String, dynamic> data) {
    final challenge = data['challenge'] as DailyChallenge;
    final isCompleted = data['is_completed'] as bool;
    final progress = (data['current_progress'] as int) / challenge.targetValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isCompleted ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              challenge.challengeTitle,
              style: TextStyle(
                fontSize: 13,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isCompleted)
            SizedBox(
              width: 60,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
