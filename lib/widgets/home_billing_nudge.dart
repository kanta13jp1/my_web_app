import 'package:flutter/material.dart';

import '../services/billing_service.dart';

class HomeBillingNudge extends StatelessWidget {
  const HomeBillingNudge({
    super.key,
    required this.status,
    required this.isLoading,
    required this.onOpenBilling,
  });

  final BillingStatus? status;
  final bool isLoading;
  final VoidCallback onOpenBilling;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = this.status;
    final isUnlimited = status?.isPro == true;
    final usageLabel = isLoading
        ? '今月のAI使用量を確認中'
        : isUnlimited
            ? '今月 無制限'
            : status == null
                ? '使用量を取得できませんでした'
                : '今月 ${status.aiQueryCount}/${BillingStatus.freeAiQueryLimit}';

    final usage = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: scheme.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'AI機能',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          usageLabel,
          key: const Key('home_ai_usage_label'),
          style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5),
        ),
        if (!isLoading && status != null && !isUnlimited) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(
            key: const Key('home_ai_usage_progress'),
            value: status.aiQueryUsageRatio,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 4),
          Text(
            '残り ${status.remainingAiQueries}回',
            key: const Key('home_ai_usage_remaining'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );

    final billingChip = ActionChip(
      key: const Key('home_billing_upgrade_chip'),
      avatar: Icon(
        isUnlimited ? Icons.manage_accounts_outlined : Icons.upgrade,
        size: 18,
      ),
      label: Text(isUnlimited ? 'プラン管理' : 'アップグレード'),
      onPressed: onOpenBilling,
    );

    return Card(
      key: const Key('home_billing_nudge'),
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 520) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: usage),
                  const SizedBox(width: 12),
                  billingChip,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: usage),
                const SizedBox(width: 16),
                billingChip,
              ],
            );
          },
        ),
      ),
    );
  }
}
