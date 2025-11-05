import 'package:flutter/material.dart';
import '../models/achievement.dart';

class AchievementCardWidget extends StatelessWidget {
  final Achievement achievement;

  const AchievementCardWidget({
    Key? key,
    required this.achievement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = achievement.isUnlocked;

    return Card(
      elevation: isUnlocked ? 4 : 1,
      color: isUnlocked
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceVariant.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      achievement.icon,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isUnlocked
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isUnlocked
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+${achievement.pointsReward}pt',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (!isUnlocked) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${achievement.currentProgress} / ${achievement.targetValue}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        '${(achievement.progressPercentage * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: achievement.progressPercentage,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.onSurface.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '達成済み',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (achievement.unlockedAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${achievement.unlockedAt!.month}/${achievement.unlockedAt!.day}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
