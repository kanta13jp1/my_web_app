import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_growth_evidence.dart';

class AdminPaidConversionCard extends StatelessWidget {
  final AdminPaidConversionMetrics metrics;
  final int totalUsers;

  const AdminPaidConversionCard({
    super.key,
    required this.metrics,
    required this.totalUsers,
  });

  @override
  Widget build(BuildContext context) {
    final formattedMrr = NumberFormat.currency(
      locale: 'ja_JP',
      symbol: '¥',
      decimalDigits: 0,
    ).format(metrics.mrrYen);

    return Card(
      elevation: 3,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium, color: Color(0xFF0D9488)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '有料転換',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                ),
                Text(
                  'active pro/team',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'billing_subscriptions の active な Pro/Team だけを集計します。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AdminAnalyticsMetricChip(
                  label: '課金ユーザー数',
                  value: '${metrics.paidCustomers}',
                  color: const Color(0xFF0D9488),
                ),
                AdminAnalyticsMetricChip(
                  label: 'MRR',
                  value: formattedMrr,
                  color: const Color(0xFF7C3AED),
                ),
                AdminAnalyticsMetricChip(
                  label: 'free→paid CVR',
                  value: _formatRate(metrics.conversionRate(totalUsers)),
                  color: const Color(0xFF6366F1),
                ),
                AdminAnalyticsMetricChip(
                  label: '登録総数',
                  value: '$totalUsers',
                  color: const Color(0xFF475569),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AdminBillingFunnelCard extends StatelessWidget {
  final AdminBillingFunnelMetrics metrics;

  const AdminBillingFunnelCard({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('billing_funnel_card'),
      elevation: 3,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shopping_cart_checkout, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '過去30日の課金ファネル',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '課金ページ表示 → アップグレードクリック → Stripe決済結果を同じ集計窓で確認します。',
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
                AdminAnalyticsMetricChip(
                  label: '課金ページ表示',
                  value: '${metrics.billingViews}',
                  color: const Color(0xFF475569),
                ),
                AdminAnalyticsMetricChip(
                  label: 'アップグレードクリック',
                  value: '${metrics.upgradeClicks}',
                  color: const Color(0xFF6366F1),
                ),
                AdminAnalyticsMetricChip(
                  label: '決済成功',
                  value: '${metrics.checkoutSuccesses}',
                  color: const Color(0xFF0D9488),
                ),
                AdminAnalyticsMetricChip(
                  label: '決済キャンセル',
                  value: '${metrics.checkoutCancels}',
                  color: const Color(0xFFB45309),
                ),
                AdminAnalyticsMetricChip(
                  label: '表示→クリック',
                  value: _formatRate(metrics.viewToClickRate),
                  color: const Color(0xFF6366F1),
                ),
                AdminAnalyticsMetricChip(
                  label: 'クリック→成功',
                  value: _formatRate(metrics.clickToSuccessRate),
                  color: const Color(0xFF0D9488),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AdminAnalyticsMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const AdminAnalyticsMetricChip({
    super.key,
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

String _formatRate(double? rate) =>
    rate == null ? '—' : '${(rate * 100).toStringAsFixed(1)}%';
