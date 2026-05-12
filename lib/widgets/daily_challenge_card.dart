import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/daily_challenge.dart';
import '../services/daily_challenge_service.dart';

/// ホーム画面に表示するデイリーチャレンジカード。
/// growth-hub:daily.challenges_generate と連携し、
/// 今日のチャレンジ一覧・進捗・報酬を表示する。
class DailyChallengeCard extends StatefulWidget {
  const DailyChallengeCard({super.key});

  @override
  State<DailyChallengeCard> createState() => _DailyChallengeCardState();
}

class _DailyChallengeCardState extends State<DailyChallengeCard> {
  bool _loading = true;
  bool _generating = false;
  List<Map<String, dynamic>> _challenges = [];
  int _totalPoints = 0;

  late final DailyChallengeService _service;

  @override
  void initState() {
    super.initState();
    _service = DailyChallengeService(Supabase.instance.client);
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await _service.getTodaysChallengesWithProgress(userId);
      int pts = 0;
      for (final item in data) {
        if (item['is_completed'] == true) {
          final c = item['challenge'] as DailyChallenge;
          pts += c.rewardPoints;
        }
      }
      if (mounted) {
        setState(() {
          _challenges = data;
          _totalPoints = pts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateChallenges() async {
    setState(() => _generating = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'growth-hub',
        body: {
          'action': 'daily.challenges_generate',
          'date': DateTime.now().toIso8601String().substring(0, 10),
        },
      );
      await _loadChallenges();
    } catch (_) {
      if (!mounted) return;
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _claimReward(int challengeId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final ok = await _service.claimChallengeReward(userId, challengeId);
    if (ok) await _loadChallenges();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Color(0xFFEA580C),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'デイリーチャレンジ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
                if (_totalPoints > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 13,
                          color: Color(0xFFFFC107),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$_totalPoints pt',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFC107),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _loading ? null : _loadChallenges,
                  tooltip: '更新',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'タスクをこなしてポイントを獲得しましょう',
              style: TextStyle(
                fontSize: 11,
                color:
                    isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_challenges.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _challenges.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _challenges[index];
                  final challenge = item['challenge'] as DailyChallenge;
                  final progress = (item['current_progress'] as int?) ?? 0;
                  final isCompleted = (item['is_completed'] as bool?) ?? false;
                  final rewardClaimed =
                      (item['reward_claimed'] as bool?) ?? false;

                  return _ChallengeRow(
                    challenge: challenge,
                    progress: progress,
                    isCompleted: isCompleted,
                    rewardClaimed: rewardClaimed,
                    onClaimReward: () => _claimReward(challenge.id),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '今日のチャレンジがまだ生成されていません。',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        FilledButton.tonal(
          onPressed: _generating ? null : _generateChallenges,
          child: _generating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('チャレンジを生成する'),
        ),
      ],
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  final DailyChallenge challenge;
  final int progress;
  final bool isCompleted;
  final bool rewardClaimed;
  final VoidCallback onClaimReward;

  const _ChallengeRow({
    required this.challenge,
    required this.progress,
    required this.isCompleted,
    required this.rewardClaimed,
    required this.onClaimReward,
  });

  @override
  Widget build(BuildContext context) {
    final pct = challenge.targetValue > 0
        ? (progress / challenge.targetValue).clamp(0.0, 1.0)
        : (isCompleted ? 1.0 : 0.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green.withAlpha(isDark ? 20 : 15)
            : isDark
                ? const Color(0xFF1F2937)
                : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withAlpha(60)
              : const Color(0xFFB0B0B0).withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: isCompleted ? Colors.green : const Color(0xFFB0B0B0),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  challenge.challengeTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? const Color(0xFFB0B0B0) : null,
                    height: 1.5,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star,
                    size: 12,
                    color: Color(0xFFFFC107),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${challenge.rewardPoints}pt',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFC107),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (challenge.challengeDescription.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              challenge.challengeDescription,
              style: TextStyle(
                fontSize: 11,
                color:
                    isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFB0B0B0).withAlpha(40),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? Colors.green : const Color(0xFF6366F1),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$progress/${challenge.targetValue}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFFBDBDBD)
                      : const Color(0xFF757575),
                  height: 1.5,
                ),
              ),
              if (isCompleted && !rewardClaimed) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClaimReward,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '受け取る',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
