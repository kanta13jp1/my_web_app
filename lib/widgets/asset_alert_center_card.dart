import 'package:flutter/material.dart';

import '../models/asset_alert.dart';
import '../services/asset_alert_center_service.dart';

/// 統合アラートパネル (Issue #2475)。
///
/// 純サービス [AssetAlertCenterService] が集約した [AssetAlertCenter] を受け取り、
/// 重要度別に並んだアラートを badge 付きで描画する。各行の dismiss ボタンで
/// [onDismiss] を呼ぶ。ページ状態へ依存しないため単体検証できる。
class AssetAlertCenterCard extends StatelessWidget {
  const AssetAlertCenterCard({
    super.key,
    required this.center,
    this.onDismiss,
    this.onRestoreDismissed,
  });

  final AssetAlertCenter center;

  /// アラートを dismiss したとき (id を渡す)。null なら dismiss ボタンを出さない。
  final ValueChanged<String>? onDismiss;

  /// 「非表示を戻す」リンク。null なら出さない。
  final VoidCallback? onRestoreDismissed;

  static const Color _critical = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFD97706);
  static const Color _info = Color(0xFF4F46E5);
  static const Color _muted = Color(0xFF6B7280);

  Color _severityColor(AssetAlertSeverity severity) {
    switch (severity) {
      case AssetAlertSeverity.critical:
        return _critical;
      case AssetAlertSeverity.warning:
        return _warning;
      case AssetAlertSeverity.info:
        return _info;
    }
  }

  IconData _severityIcon(AssetAlertSeverity severity) {
    switch (severity) {
      case AssetAlertSeverity.critical:
        return Icons.error_outline;
      case AssetAlertSeverity.warning:
        return Icons.warning_amber_outlined;
      case AssetAlertSeverity.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!center.hasAlerts) {
      return _buildEmpty(theme);
    }

    return Card(
      key: const Key('asset_alert_center_card'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 12),
            for (final alert in center.alerts) _buildAlertRow(theme, alert),
            if (center.dismissedCount > 0 && onRestoreDismissed != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('asset_alert_center_restore'),
                  onPressed: onRestoreDismissed,
                  child: Text('非表示 ${center.dismissedCount} 件を戻す'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        const Icon(Icons.notifications_active_outlined, color: _info),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'アラートセンター',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (center.criticalCount > 0)
          _buildCountChip(theme, '緊急 ${center.criticalCount}', _critical),
        if (center.warningCount > 0) ...[
          const SizedBox(width: 6),
          _buildCountChip(theme, '注意 ${center.warningCount}', _warning),
        ],
      ],
    );
  }

  Widget _buildCountChip(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAlertRow(ThemeData theme, AssetAlert alert) {
    final color = _severityColor(alert.severity);
    return Container(
      key: Key('asset_alert_row_${alert.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_severityIcon(alert.severity), size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildSeverityBadge(theme, alert.severity, color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: _muted),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              key: Key('asset_alert_dismiss_${alert.id}'),
              icon: const Icon(Icons.close, size: 18),
              color: _muted,
              tooltip: '非表示にする',
              onPressed: () => onDismiss!(alert.id),
            ),
        ],
      ),
    );
  }

  Widget _buildSeverityBadge(
    ThemeData theme,
    AssetAlertSeverity severity,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        severity.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Card(
      key: const Key('asset_alert_center_card_empty'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF059669)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '対応が必要なアラートはありません。',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (center.dismissedCount > 0 && onRestoreDismissed != null)
              TextButton(
                key: const Key('asset_alert_center_restore_empty'),
                onPressed: onRestoreDismissed,
                child: Text('非表示 ${center.dismissedCount} 件を戻す'),
              ),
          ],
        ),
      ),
    );
  }
}
