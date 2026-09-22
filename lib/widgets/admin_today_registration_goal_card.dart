import 'package:flutter/material.dart';

class AdminTodayRegistrationGoalCard extends StatelessWidget {
  final int todayViews;
  final int todayRegistrations;
  final int trialRuns;
  final int magicLinkSends;
  final String cvrText;
  final String diagnosisLabel;
  final Color diagnosisColor;
  final String? priorityChannelLabel;
  final String statusText;
  final String? actionTitle;
  final String? actionDetail;
  final IconData? actionIcon;
  final String? actionButtonLabel;
  final VoidCallback? onActionPressed;

  const AdminTodayRegistrationGoalCard({
    super.key,
    required this.todayViews,
    required this.todayRegistrations,
    required this.trialRuns,
    required this.magicLinkSends,
    required this.cvrText,
    required this.diagnosisLabel,
    required this.diagnosisColor,
    required this.priorityChannelLabel,
    required this.statusText,
    required this.actionTitle,
    required this.actionDetail,
    required this.actionIcon,
    required this.actionButtonLabel,
    required this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    const dailyTarget = 1;
    final achieved = todayRegistrations >= dailyTarget;
    final remaining = achieved ? 0 : dailyTarget - todayRegistrations;
    final progress = (todayRegistrations / dailyTarget).clamp(0.0, 1.0);
    final accentColor =
        achieved ? const Color(0xFF0D9488) : const Color(0xFFB91C1C);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: achieved
              ? (isDark
                  ? const [Color(0xFF0D2E1A), Color(0xFF0A1F12)]
                  : const [Color(0xFFE8F5E9), Color(0xFFF6FFF7)])
              : (isDark
                  ? const [Color(0xFF2E0A0A), Color(0xFF1F0808)]
                  : const [Color(0xFFFFEBEE), Color(0xFFFFF8F8)]),
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  achieved ? Icons.check_circle : Icons.track_changes,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日の登録目標',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$todayRegistrations / $dailyTarget',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        height: 1,
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
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  achieved ? '達成' : '未達',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniKpiChip(
                label: '今日のLP View数',
                value: '$todayViews',
                color: const Color(0xFF6366F1),
              ),
              _MiniKpiChip(
                label: '今日のCVR',
                value: cvrText,
                color: diagnosisColor,
              ),
              if (todayViews > 0)
                _MiniKpiChip(
                  label: '今日体験',
                  value: '$trialRuns',
                  color: const Color(0xFF0D9488),
                ),
              if (todayViews > 0)
                _MiniKpiChip(
                  label: '今日送信',
                  value: '$magicLinkSends',
                  color: const Color(0xFFFF6B35),
                ),
              _MiniKpiChip(
                label: '今日の診断',
                value: diagnosisLabel,
                color: diagnosisColor,
              ),
              if (priorityChannelLabel != null)
                _MiniKpiChip(
                  label: '最優先チャネル',
                  value: priorityChannelLabel!,
                  color: const Color(0xFF475569),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            achieved ? statusText : '$statusText あと$remaining人の登録が必要です。',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.7,
            ),
          ),
          if (actionTitle != null &&
              actionDetail != null &&
              actionIcon != null &&
              actionButtonLabel != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: diagnosisColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: diagnosisColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: diagnosisColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(actionIcon, color: diagnosisColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionTitle!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: diagnosisColor,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          actionDetail!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: diagnosisColor,
                            foregroundColor: const Color(0xFFE5E7EB),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onPressed: onActionPressed,
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text(actionButtonLabel!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniKpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniKpiChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
