import 'package:flutter/material.dart';

class AdminRegistrationOpsCard extends StatelessWidget {
  final int todayDropBeforeTrial;
  final int totalDropBeforeTrial;
  final int zeroRegistrationStreakDays;
  final bool zeroStreakAtCap;
  final double averageViewsLast7Days;
  final String totalTrialRate;
  final String? registrationsPerLpView;

  const AdminRegistrationOpsCard({
    super.key,
    required this.todayDropBeforeTrial,
    required this.totalDropBeforeTrial,
    required this.zeroRegistrationStreakDays,
    required this.zeroStreakAtCap,
    required this.averageViewsLast7Days,
    required this.totalTrialRate,
    required this.registrationsPerLpView,
  });

  @override
  Widget build(BuildContext context) {
    final streakLabel =
        '$zeroRegistrationStreakDays日${zeroStreakAtCap ? '以上' : ''}';
    final alertText = zeroRegistrationStreakDays >= 3
        ? '登録ゼロが$streakLabel連続です。流入ではなく、体験開始と認証前の離脱を最優先で潰してください。'
        : todayDropBeforeTrial > 0
            ? '今日は流入がありますが、体験前に$todayDropBeforeTrial件が離脱しています。無料体験の訴求を最優先で確認してください。'
            : '直近の登録導線は動いています。次は送信後の完了率を維持できているかを確認してください。';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '登録管理の追加指標',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'LP View以外に、体験前離脱・継続未達・直近流量をまとめて確認します。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AdminRegistrationMetricChip(
                  label: '今日の体験前離脱',
                  value: '$todayDropBeforeTrial',
                  color: const Color(0xFF0D9488),
                ),
                _AdminRegistrationMetricChip(
                  label: '30日体験前離脱',
                  value: '$totalDropBeforeTrial',
                  color: const Color(0xFF475569),
                ),
                _AdminRegistrationMetricChip(
                  label: '連続登録ゼロ日',
                  value: streakLabel,
                  color: const Color(0xFFB91C1C),
                ),
                _AdminRegistrationMetricChip(
                  label: '直近7日平均LP',
                  value: averageViewsLast7Days.toStringAsFixed(1),
                  color: const Color(0xFF6366F1),
                ),
                _AdminRegistrationMetricChip(
                  label: '30日体験率',
                  value: totalTrialRate,
                  color: const Color(0xFF0D9488),
                ),
                _AdminRegistrationMetricChip(
                  label: '直近登録効率',
                  value: registrationsPerLpView == null
                      ? '登録未発生'
                      : '$registrationsPerLpView LP/登録',
                  color: const Color(0xFF6366F1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                alertText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminRegistrationMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AdminRegistrationMetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
