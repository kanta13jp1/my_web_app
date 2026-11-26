import 'package:flutter/material.dart';

import '../application/ai_emotion_controller.dart';
import '../domain/ai_emotion_models.dart';

class _AiEmotionPalette {
  const _AiEmotionPalette({
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.ink,
    required this.inkSecondary,
    required this.accent,
    required this.alertBg,
    required this.alertFg,
    required this.alertBorder,
    required this.warnBg,
    required this.warnFg,
    required this.warnBorder,
    required this.okBg,
    required this.okFg,
  });

  final Color surface;
  final Color surfaceSubtle;
  final Color border;
  final Color ink;
  final Color inkSecondary;
  final Color accent;
  final Color alertBg;
  final Color alertFg;
  final Color alertBorder;
  final Color warnBg;
  final Color warnFg;
  final Color warnBorder;
  final Color okBg;
  final Color okFg;

  factory _AiEmotionPalette.of(final BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    if (isDark) {
      return _AiEmotionPalette(
        surface: colors.surface,
        surfaceSubtle: colors.surfaceContainerHigh,
        border: colors.outline,
        ink: colors.onSurface,
        inkSecondary: colors.onSurfaceVariant,
        accent: colors.primary,
        alertBg: colors.errorContainer,
        alertFg: colors.onErrorContainer,
        alertBorder: colors.error,
        warnBg: const Color(0xFF422006),
        warnFg: const Color(0xFFFEF08A),
        warnBorder: const Color(0xFFFACC15),
        okBg: colors.primaryContainer,
        okFg: colors.onPrimaryContainer,
      );
    }
    return _AiEmotionPalette(
      surface: colors.surface,
      surfaceSubtle: colors.surfaceContainerLow,
      border: colors.outlineVariant,
      ink: colors.onSurface,
      inkSecondary: colors.onSurfaceVariant,
      accent: colors.primary,
      alertBg: colors.errorContainer,
      alertFg: colors.onErrorContainer,
      alertBorder: colors.error,
      warnBg: const Color(0xFFFEF3C7),
      warnFg: const Color(0xFF78350F),
      warnBorder: const Color(0xFFD97706),
      okBg: colors.primaryContainer,
      okFg: colors.onPrimaryContainer,
    );
  }
}

/// Pure presentation dashboard for AI functional emotion logging & monitoring
/// (#2764). Zero direct backend/network imports.
class AiEmotionDashboardView extends StatelessWidget {
  const AiEmotionDashboardView({
    super.key,
    required this.state,
    required this.responseTextController,
    required this.modelController,
    required this.thresholdController,
    required this.onRefresh,
    required this.onSeedDefaults,
    required this.onSelectTone,
    required this.onClassifyAndLog,
  });

  final AiEmotionState state;
  final TextEditingController responseTextController;
  final TextEditingController modelController;
  final TextEditingController thresholdController;
  final VoidCallback onRefresh;
  final VoidCallback onSeedDefaults;
  final ValueChanged<FunctionalEmotionCategory?> onSelectTone;
  final VoidCallback onClassifyAndLog;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final palette = _AiEmotionPalette.of(context);
    final snapshot = state.snapshot;

    return ColoredBox(
      color: palette.surface,
      child: SingleChildScrollView(
        key: const ValueKey<String>('ai_emotion_scroll_view'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeaderCard(theme, palette, snapshot),
            const SizedBox(height: 12),
            if (state.errorMessage != null) ...<Widget>[
              _buildNoticeBanner(
                key: const ValueKey<String>('ai_emotion_error_banner'),
                icon: Icons.error_outline,
                bg: palette.alertBg,
                fg: palette.alertFg,
                border: palette.alertBorder,
                title: '監視エラー',
                subtitle: state.errorMessage!,
                theme: theme,
              ),
              const SizedBox(height: 12),
            ],
            if (state.statusNotice != null) ...<Widget>[
              _buildNoticeBanner(
                key: const ValueKey<String>('ai_emotion_status_banner'),
                icon: Icons.check_circle_outline,
                bg: palette.okBg,
                fg: palette.okFg,
                border: palette.accent,
                title: '記録完了',
                subtitle: state.statusNotice!,
                theme: theme,
              ),
              const SizedBox(height: 12),
            ],
            if (snapshot.alerts.isNotEmpty) ...<Widget>[
              _buildAlertBanner(theme, palette, snapshot.alerts.first),
              const SizedBox(height: 12),
            ],
            _buildKpiSection(theme, palette, snapshot),
            const SizedBox(height: 12),
            _buildToneFilterSection(theme, palette),
            const SizedBox(height: 12),
            _buildTimelineCard(theme, palette, snapshot),
            const SizedBox(height: 12),
            _buildClassifyFormCard(theme, palette),
            const SizedBox(height: 12),
            if (state.isLoading)
              const Padding(
                key: ValueKey<String>('ai_emotion_loading'),
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...<Widget>[
              _buildAlertsCard(theme, palette, snapshot.alerts),
              const SizedBox(height: 12),
              _buildLogsCard(theme, palette, snapshot.logs),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    final ThemeData theme,
    final _AiEmotionPalette palette,
    final AiEmotionDashboardSnapshot snapshot,
  ) {
    return Card(
      elevation: 0,
      color: palette.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.psychology_alt, color: palette.accent, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'AI 機能的感情ステータス監視',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: palette.ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snapshot.verificationNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('ai_emotion_refresh_button'),
                  tooltip: '監視データを再読込',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: state.isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                Container(
                  key: const ValueKey<String>(
                    'ai_emotion_needs_verification_badge',
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.warnBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: palette.warnBorder),
                  ),
                  child: Text(
                    '要検証フラグ有効 (外部トーン分類)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: palette.warnFg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>('ai_emotion_seed_button'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: state.isSaving ? null : onSeedDefaults,
                  icon: const Icon(Icons.auto_fix_high_outlined),
                  label: const Text('標準投入'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeBanner({
    required final Key key,
    required final IconData icon,
    required final Color bg,
    required final Color fg,
    required final Color border,
    required final String title,
    required final String subtitle,
    required final ThemeData theme,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(
    final ThemeData theme,
    final _AiEmotionPalette palette,
    final AiEmotionAlertEntry latestAlert,
  ) {
    return _buildNoticeBanner(
      key: const ValueKey<String>('ai_emotion_alert_banner'),
      icon: Icons.warning_amber_rounded,
      bg: palette.alertBg,
      fg: palette.alertFg,
      border: palette.alertBorder,
      title: '異常トーン閾値超過検知 (${latestAlert.tone.label} '
          '${latestAlert.score.toStringAsFixed(2)})',
      subtitle: '${latestAlert.message} [モデル: ${latestAlert.model} / 要検証]',
      theme: theme,
    );
  }

  Widget _buildKpiSection(
    final ThemeData theme,
    final _AiEmotionPalette palette,
    final AiEmotionDashboardSnapshot snapshot,
  ) {
    final summary = snapshot.summary;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _buildKpiCard(
          key: const ValueKey<String>('ai_emotion_kpi_total'),
          title: '総記録数',
          value: '${summary.totalLogs} 件',
          theme: theme,
          palette: palette,
        ),
        _buildKpiCard(
          key: const ValueKey<String>('ai_emotion_kpi_alerts'),
          title: '閾値超過アラート',
          value: '${summary.alertCount} 件',
          theme: theme,
          palette: palette,
        ),
        _buildKpiCard(
          key: const ValueKey<String>('ai_emotion_kpi_dominant'),
          title: '最頻トーン',
          value: summary.dominantTone.label,
          theme: theme,
          palette: palette,
        ),
        _buildKpiCard(
          key: const ValueKey<String>('ai_emotion_kpi_rate'),
          title: '異常表現率',
          value: '${summary.overThresholdRatePct.toStringAsFixed(1)}%',
          theme: theme,
          palette: palette,
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required final Key key,
    required final String title,
    required final String value,
    required final ThemeData theme,
    required final _AiEmotionPalette palette,
  }) {
    return Container(
      key: key,
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.inkSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToneFilterSection(
    final ThemeData theme,
    final _AiEmotionPalette palette,
  ) {
    return Card(
      elevation: 0,
      color: palette.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '感情トーン絞り込み',
              style: theme.textTheme.titleSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildFilterButton(
                  key: const ValueKey<String>('ai_emotion_filter_all'),
                  label: 'すべて',
                  selected: state.selectedToneFilter == null,
                  onPressed: () => onSelectTone(null),
                  palette: palette,
                ),
                for (final cat in FunctionalEmotionCategory.values)
                  _buildFilterButton(
                    key: ValueKey<String>(
                      'ai_emotion_filter_${cat.apiValue}',
                    ),
                    label: cat.label,
                    selected: state.selectedToneFilter == cat,
                    onPressed: () => onSelectTone(cat),
                    palette: palette,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton({
    required final Key key,
    required final String label,
    required final bool selected,
    required final VoidCallback onPressed,
    required final _AiEmotionPalette palette,
  }) {
    return OutlinedButton(
      key: key,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        backgroundColor: selected ? palette.okBg : palette.surface,
        foregroundColor: selected ? palette.okFg : palette.ink,
        side: BorderSide(
          color: selected ? palette.accent : palette.border,
        ),
      ),
      onPressed: state.isLoading ? null : onPressed,
      child: Text(label),
    );
  }

  Widget _buildTimelineCard(
    final ThemeData theme,
    final _AiEmotionPalette palette,
    final AiEmotionDashboardSnapshot snapshot,
  ) {
    final buckets = snapshot.summary.timeline;
    return Card(
      key: const ValueKey<String>('ai_emotion_timeline_card'),
      elevation: 0,
      color: palette.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '時間帯別 機能的感情推移トレンド',
              style: theme.textTheme.titleSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (buckets.isEmpty)
              Text(
                '推移データがまだありません。「標準投入」または新規記録を実行してください。',
                key: const ValueKey<String>('ai_emotion_timeline_empty'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.inkSecondary,
                ),
              )
            else
              for (final bucket in buckets) ...<Widget>[
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 2,
                    children: <Widget>[
                      Text(
                        '${bucket.bucketLabel} ・ 主傾向: ${bucket.dominantTone.label}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${bucket.totalCount}件 / 負荷 ${bucket.avgUrgencyScore.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: bucket.alertCount > 0
                              ? palette.alertBorder
                              : palette.inkSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: bucket.avgUrgencyScore.clamp(0.05, 1.0),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  color: bucket.alertCount > 0
                      ? palette.alertBorder
                      : palette.accent,
                  backgroundColor: palette.surface,
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildClassifyFormCard(
    final ThemeData theme,
    final _AiEmotionPalette palette,
  ) {
    return Card(
      elevation: 0,
      color: palette.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'AI 応答トーン分類・記録',
              style: theme.textTheme.titleSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('ai_emotion_response_field'),
              controller: responseTextController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'AI 応答テキスト',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: const ValueKey<String>('ai_emotion_model_field'),
                    controller: modelController,
                    decoration: const InputDecoration(
                      labelText: '対象モデル',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    key: const ValueKey<String>('ai_emotion_threshold_field'),
                    controller: thresholdController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '警告閾値 (0.1-0.99)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  key: const ValueKey<String>('ai_emotion_submit_button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: state.isSaving ? null : onClassifyAndLog,
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('分析・記録'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsCard(
    final ThemeData theme,
    final _AiEmotionPalette palette,
    final List<AiEmotionAlertEntry> alerts,
  ) {
    return Card(
      elevation: 0,
      color: palette.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '異常感情アラート履歴 (${alerts.length}件)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (alerts.isEmpty)
              Text(
                '閾値を超過したアラートはありません。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.inkSecondary,
                ),
              )
            else
              for (final alert in alerts)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.alertBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          runSpacing: 2,
                          children: <Widget>[
                            Text(
                              '${alert.tone.label} (${alert.severity})',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: palette.ink,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${alert.score.toStringAsFixed(2)} / '
                              '閾値 ${alert.threshold.toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${alert.message} ・ ${alert.model} [要検証]',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsCard(
    final ThemeData theme,
    final _AiEmotionPalette palette,
    final List<AiEmotionLogEntry> logs,
  ) {
    return Card(
      elevation: 0,
      color: palette.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '応答別 感情ログ (${logs.length}件)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              Text(
                '記録済みの応答トーンログはありません。',
                key: const ValueKey<String>('ai_emotion_empty_state'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.inkSecondary,
                ),
              )
            else
              for (final log in logs)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: log.thresholdExceeded
                          ? palette.alertBorder
                          : palette.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          runSpacing: 2,
                          children: <Widget>[
                            Text(
                              '${log.tone.label} ・ ${log.model}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: palette.ink,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'スコア ${log.score.toStringAsFixed(2)} [要検証]',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.inkSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log.responseExcerpt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
