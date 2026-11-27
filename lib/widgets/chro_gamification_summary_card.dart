import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../models/chro_achievement_evaluation.dart';
import '../models/user_stats.dart';

/// CHRO オフィス画面に表示する獲得ポイント・実績・最新 AI 人事評価サマリーカード (#1406)。
class ChroGamificationSummaryCard extends StatelessWidget {
  final ChroEvaluationSummary summary;
  final List<Achievement> unlockedAchievements;
  final bool isEvaluating;
  final VoidCallback? onEvaluate;

  const ChroGamificationSummaryCard({
    super.key,
    required this.summary,
    required this.unlockedAchievements,
    this.isEvaluating = false,
    this.onEvaluate,
  });

  @override
  Widget build(BuildContext context) {
    final statsPreview = UserStats(
      userId: 'ceo',
      totalPoints: summary.totalPoints,
      currentLevel: summary.currentLevel,
    );
    final scheme = Theme.of(context).colorScheme;
    final latest = summary.latestEvaluation;

    return Card(
      key: const Key('chro_gamification_summary_card'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE8EAF6),
                  child: Icon(
                    Icons.emoji_events_outlined,
                    color: Color(0xFF283593),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CHRO 人事評価 & 実績サマリー',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      Text(
                        'Lv.${summary.currentLevel} ${summary.levelTitle} ・ 解除実績 ${summary.unlockedCount}/${summary.totalCatalogCount}件',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D5AFE).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${summary.totalPoints} pt',
                    key: const Key('chro_total_points_label'),
                    style: const TextStyle(
                      color: Color(0xFF283593),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: statsPreview.levelProgress.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF3D5AFE),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_outlined,
                        size: 16,
                        color: Color(0xFF3D5AFE),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '最新のAI人事評価サマリー',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (latest != null)
                        Text(
                          latest.executiveRole,
                          style: const TextStyle(
                            color: Color(0xFF283593),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary.headline,
                    key: const Key('chro_latest_evaluation_text'),
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '次の目標: ${summary.nextRecommendedGoal}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '解除済み実績 (${unlockedAchievements.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: OutlinedButton.icon(
                    key: const Key('chro_gamification_evaluate_btn'),
                    onPressed: isEvaluating ? null : onEvaluate,
                    icon: isEvaluating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: const Text('実績を再評価'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (unlockedAchievements.isEmpty)
              Text(
                'まだ解除済みの実績はありません。タスク完了や断捨離クエストで実績を解除できます。',
                key: const Key('chro_achievements_empty_text'),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              )
            else
              Column(
                children: unlockedAchievements.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      key: Key('chro_unlocked_achievement_${item.id}'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_outlined,
                            color: Color(0xFF047857),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+${item.pointsReward} pt',
                            style: const TextStyle(
                              color: Color(0xFF047857),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
