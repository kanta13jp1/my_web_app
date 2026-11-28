import 'package:flutter/material.dart';

import '../services/ai_daily_quota_service.dart';

/// ユーザープラン別の日次 AI リクエスト上限表示・超過時実行ブロックバナー (#2699)。
class AiDailyQuotaGuardBanner extends StatelessWidget {
  const AiDailyQuotaGuardBanner({
    super.key,
    required this.status,
    this.onRefresh,
  });

  final AiDailyQuotaStatus status;
  final VoidCallback? onRefresh;

  String _planDisplayName(String plan) {
    switch (plan.toLowerCase()) {
      case 'enterprise':
        return 'Enterprise';
      case 'team':
        return 'Team';
      case 'premium':
        return 'Premium';
      case 'pro':
        return 'Pro';
      case 'free':
      default:
        return 'Free';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final blocked = status.isLimitReached;

    final fg = blocked
        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
        : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8));
    final bg = blocked
        ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
        : (isDark ? const Color(0xFF172554) : const Color(0xFFDBEAFE));

    final resetLabel = status.resetAt != null
        ? '次回リセット (UTC): ${status.resetAt!.toIso8601String().substring(0, 16)}'
        : '毎日 00:00 JST にリセット';

    return Semantics(
      container: true,
      label: blocked
          ? '本日の AI リクエスト上限 (${status.used}/${status.dailyLimit}) に達したため実行がブロックされています'
          : '${_planDisplayName(status.plan)} プランの日次 AI 利用状況: ${status.used}/${status.dailyLimit}',
      child: Container(
        key: const ValueKey<String>('ai_daily_quota_guard_banner'),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  blocked ? Icons.block : Icons.bolt_outlined,
                  size: 18,
                  color: fg,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_planDisplayName(status.plan)} プラン日次枠: ${status.used} / ${status.dailyLimit} 回 (残り ${status.remaining} 回)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    key: const ValueKey<String>('ai_daily_quota_refresh'),
                    tooltip: '日次利用枠を再取得',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: onRefresh,
                    icon: Icon(Icons.refresh, color: fg),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: status.usageRatio,
              color: fg,
              backgroundColor: fg.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 6),
            Text(
              blocked
                  ? '本日のリクエスト上限に到達したため AI 実行はブロックされました。$resetLabel'
                  : resetLabel,
              key: ValueKey<String>(
                blocked
                    ? 'ai_daily_quota_blocked_text'
                    : 'ai_daily_quota_ok_text',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// 日次上限に到達した際に子アクションボタンの実行をフロントエンドで抑止するラッパー (#2699)。
class AiDailyQuotaActionGate extends StatelessWidget {
  const AiDailyQuotaActionGate({
    super.key,
    required this.status,
    required this.actionLabel,
    required this.onExecute,
    this.onRefresh,
  });

  final AiDailyQuotaStatus status;
  final String actionLabel;
  final VoidCallback onExecute;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final blocked = status.isLimitReached;
    return Column(
      key: const ValueKey<String>('ai_daily_quota_action_gate'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AiDailyQuotaGuardBanner(
          status: status,
          onRefresh: onRefresh,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            key: const ValueKey<String>('ai_daily_quota_execute_button'),
            onPressed: blocked ? null : onExecute,
            icon: Icon(blocked ? Icons.lock_outline : Icons.auto_awesome),
            label: Text(blocked ? '本日の上限に到達 ($actionLabel 停止中)' : actionLabel),
          ),
        ),
      ],
    );
  }
}
