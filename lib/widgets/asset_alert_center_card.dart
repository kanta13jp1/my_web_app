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

  Color _warningColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFD97706);
  }

  Color _infoColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFFA5B4FC)
        : const Color(0xFF4F46E5);
  }

  Color _severityColor(ThemeData theme, AssetAlertSeverity severity) {
    switch (severity) {
      case AssetAlertSeverity.critical:
        return theme.colorScheme.error;
      case AssetAlertSeverity.warning:
        return _warningColor(theme);
      case AssetAlertSeverity.info:
        return _infoColor(theme);
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
    final hasCounts = center.criticalCount > 0 || center.warningCount > 0;
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: _infoColor(theme),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'アラートセンター',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (hasCounts)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (center.criticalCount > 0)
                  _buildCountChip(
                    theme,
                    '緊急 ${center.criticalCount}',
                    theme.colorScheme.error,
                  ),
                if (center.warningCount > 0)
                  _buildCountChip(
                    theme,
                    '注意 ${center.warningCount}',
                    _warningColor(theme),
                  ),
              ],
            ),
        ],
      ),
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
    final color = _severityColor(theme, alert.severity);
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              key: Key('asset_alert_dismiss_${alert.id}'),
              icon: const Icon(Icons.close, size: 18),
              color: theme.colorScheme.onSurfaceVariant,
              tooltip: '非表示にする',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
    final canRestore = center.dismissedCount > 0 && onRestoreDismissed != null;
    final emptyColor = theme.brightness == Brightness.dark
        ? const Color(0xFF34D399)
        : const Color(0xFF059669);
    return Card(
      key: const Key('asset_alert_center_card_empty'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, color: emptyColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '対応が必要なアラートはありません。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (canRestore)
                TextButton(
                  key: const Key('asset_alert_center_restore_empty'),
                  onPressed: onRestoreDismissed,
                  child: Text('非表示 ${center.dismissedCount} 件を戻す'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
