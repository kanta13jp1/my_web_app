import 'package:flutter/material.dart';

class AdminRegistrationFunnelCard extends StatelessWidget {
  final String title;
  final int lpViews;
  final int registrations;
  final int trialRuns;
  final int saveClicks;
  final int magicLinkSends;
  final int inboxOpens;
  final int remainingRegistrations;
  final String bottleneckLabel;
  final int neededMagicLinks;

  const AdminRegistrationFunnelCard({
    super.key,
    required this.title,
    required this.lpViews,
    required this.registrations,
    required this.trialRuns,
    required this.saveClicks,
    required this.magicLinkSends,
    required this.inboxOpens,
    required this.remainingRegistrations,
    required this.bottleneckLabel,
    required this.neededMagicLinks,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'LP流入後の途中離脱を切り分けるためのファネルです。どこで止まっているかを先に確認します。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _AdminFunnelStepItem(
                  label: 'LP View',
                  value: '$lpViews',
                  icon: Icons.visibility,
                  color: const Color(0xFF6366F1),
                ),
                _AdminFunnelStepItem(
                  label: '体験実行',
                  value: '$trialRuns',
                  icon: Icons.play_circle_outline,
                  color: const Color(0xFF0D9488),
                ),
                _AdminFunnelStepItem(
                  label: '保存CTA',
                  value: '$saveClicks',
                  icon: Icons.save_outlined,
                  color: const Color(0xFF6366F1),
                ),
                _AdminFunnelStepItem(
                  label: 'Magic Link送信',
                  value: '$magicLinkSends',
                  icon: Icons.mail_outline,
                  color: const Color(0xFF7C3AED),
                ),
                _AdminFunnelStepItem(
                  label: '受信箱を開く',
                  value: '$inboxOpens',
                  icon: Icons.mark_email_read_outlined,
                  color: const Color(0xFFFF6B35),
                ),
                _AdminFunnelStepItem(
                  label: '実登録',
                  value: '$registrations',
                  icon: Icons.person_add,
                  color: const Color(0xFF0D9488),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AdminFunnelMetricChip(
                  label: 'LP→体験率',
                  value: _formatRate(trialRuns, lpViews),
                  color: const Color(0xFF0D9488),
                ),
                _AdminFunnelMetricChip(
                  label: '体験→保存率',
                  value: _formatRate(saveClicks, trialRuns),
                  color: const Color(0xFF6366F1),
                ),
                _AdminFunnelMetricChip(
                  label: '保存→送信率',
                  value: _formatRate(magicLinkSends, saveClicks),
                  color: const Color(0xFF7C3AED),
                ),
                _AdminFunnelMetricChip(
                  label: '送信→登録率',
                  value: _formatRate(registrations, magicLinkSends),
                  color: const Color(0xFF0D9488),
                ),
                if (remainingRegistrations > 0)
                  _AdminFunnelMetricChip(
                    label: '最大ボトルネック',
                    value: bottleneckLabel,
                    color: const Color(0xFF475569),
                  ),
                if (remainingRegistrations > 0)
                  _AdminFunnelMetricChip(
                    label: '目標達成に必要な送信',
                    value: '$neededMagicLinks件',
                    color: const Color(0xFFB91C1C),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRate(int numerator, int denominator) {
    if (denominator <= 0) return '--';
    return '${(numerator / denominator * 100).toStringAsFixed(1)}%';
  }
}

class _AdminFunnelStepItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AdminFunnelStepItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminFunnelMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AdminFunnelMetricChip({
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
