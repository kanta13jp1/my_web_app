import 'package:flutter/material.dart';

import '../application/vision_benchmark_controller.dart';
import '../domain/vision_benchmark_models.dart';

/// Pure presentation dashboard for AI Vision benchmark monitoring (#2758).
class VisionBenchmarkDashboardView extends StatelessWidget {
  const VisionBenchmarkDashboardView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onThresholdChanged,
    required this.onSelectModel,
    this.onRunLiveTest,
  });

  final VisionBenchmarkState state;
  final VoidCallback onRefresh;
  final ValueChanged<int> onThresholdChanged;
  final ValueChanged<String?> onSelectModel;
  final ValueChanged<String>? onRunLiveTest;

  static const List<int> _presetThresholds = <int>[50, 70, 85, 90];

  @override
  Widget build(final BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final runs = state.visibleRuns;
    final alertModels = state.alertModels;

    return SingleChildScrollView(
      key: const ValueKey<String>('vision_benchmark_scroll_view'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeaderCard(context, colors),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            _buildBanner(
              key: const ValueKey<String>('vision_benchmark_error_banner'),
              icon: Icons.error_outline,
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
              title: 'データ取得エラー',
              lines: <String>[state.errorMessage!],
            ),
            const SizedBox(height: 12),
          ],
          if (state.statusNotice != null) ...<Widget>[
            _buildBanner(
              key: const ValueKey<String>('vision_benchmark_status_notice'),
              icon: Icons.check_circle_outline,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              title: '計測完了',
              lines: <String>[state.statusNotice!],
            ),
            const SizedBox(height: 12),
          ],
          if (alertModels.isNotEmpty) ...<Widget>[
            _buildAlertBanner(colors, alertModels),
            const SizedBox(height: 12),
          ] else if (runs.isNotEmpty) ...<Widget>[
            _buildBanner(
              key: const ValueKey<String>('vision_benchmark_healthy_banner'),
              icon: Icons.verified_outlined,
              backgroundColor: const Color(0xFFDCFCE7),
              foregroundColor: const Color(0xFF14532D),
              title: '全モデル正常稼働中 (基準値 ${state.threshold}点以上)',
              lines: const <String>[
                '監視対象モデルはすべて最新の Vision ベンチマーク基準を満たしています。',
              ],
            ),
            const SizedBox(height: 12),
          ],
          _buildKpiSummaryWrap(colors),
          const SizedBox(height: 12),
          _buildThresholdCard(context, colors),
          const SizedBox(height: 12),
          if (state.availableModels.isNotEmpty) ...<Widget>[
            _buildModelFilterCard(colors),
            const SizedBox(height: 12),
          ],
          if (state.isLoading)
            const Padding(
              key: ValueKey<String>('vision_benchmark_loading'),
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (runs.isEmpty)
            _buildEmptyCard(colors)
          else ...<Widget>[
            _buildTrendChartCard(context, colors, runs),
            const SizedBox(height: 12),
            _buildHistoryTableCard(context, colors, runs),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    final BuildContext context,
    final ColorScheme colors,
  ) {
    final testTargetModel = state.selectedModel ??
        (state.availableModels.isNotEmpty
            ? state.availableModels.first
            : 'gemini-2.5-flash');

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.visibility_outlined,
                  color: colors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'AI監視ダッシュボード（Visionベンチマーク）',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The Five Emperors 6段階 Vision テストの精度推移と閾値アラートを監視します。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key:
                      const ValueKey<String>('vision_benchmark_refresh_button'),
                  tooltip: '最新結果を再読込',
                  onPressed: state.isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (onRunLiveTest != null) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  FilledButton.icon(
                    key: const ValueKey<String>(
                      'vision_benchmark_run_test_button',
                    ),
                    onPressed: state.isRecording
                        ? null
                        : () => onRunLiveTest!(testTargetModel),
                    icon: state.isRecording
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_outlined),
                    label: Text(
                      state.isRecording
                          ? '計測・保存中...'
                          : '$testTargetModel をテスト記録',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner(
    final ColorScheme colors,
    final List<VisionModelSummary> alertModels,
  ) {
    final lines = <String>[
      for (final item in alertModels)
        '• ${item.model}: ${item.latestScore}点 (基準値 ${state.threshold}点を ${state.threshold - item.latestScore}点 下回っています)',
    ];
    return _buildBanner(
      key: const ValueKey<String>('vision_benchmark_alert_banner'),
      icon: Icons.warning_amber_rounded,
      backgroundColor: const Color(0xFFFEE2E2),
      foregroundColor: const Color(0xFF991B1B),
      borderColor: const Color(0xFFDC2626),
      title:
          'しきい値未達アラート: ${alertModels.length}モデルが基準値 (${state.threshold}点) 未満',
      lines: lines,
    );
  }

  Widget _buildBanner({
    required final Key key,
    required final IconData icon,
    required final Color backgroundColor,
    required final Color foregroundColor,
    required final String title,
    required final List<String> lines,
    final Color? borderColor,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? foregroundColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: foregroundColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(height: 4),
                for (final line in lines)
                  Text(
                    line,
                    style: TextStyle(
                      fontSize: 12,
                      color: foregroundColor,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryWrap(final ColorScheme colors) {
    final items = <Widget>[
      _buildKpiTile(
        colors: colors,
        label: '総計測回数',
        value: '${state.visibleRuns.length}件',
        accent: colors.primary,
      ),
      _buildKpiTile(
        colors: colors,
        label: '平均スコア',
        value: '${state.averageScore.toStringAsFixed(1)}点',
        accent: const Color(0xFF0F766E),
      ),
      _buildKpiTile(
        colors: colors,
        label: '警告モデル数',
        value: '${state.alertModels.length}件',
        accent: state.alertModels.isNotEmpty
            ? const Color(0xFFDC2626)
            : const Color(0xFF15803D),
      ),
      _buildKpiTile(
        colors: colors,
        label: '監視モデル数',
        value: '${state.modelSummaries.length}モデル',
        accent: const Color(0xFF4F46E5),
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items,
    );
  }

  Widget _buildKpiTile({
    required final ColorScheme colors,
    required final String label,
    required final String value,
    required final Color accent,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdCard(
    final BuildContext context,
    final ColorScheme colors,
  ) {
    return Card(
      key: const ValueKey<String>('vision_benchmark_threshold_card'),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '警告しきい値: ${state.threshold}点',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('vision_threshold_dec'),
                  tooltip: 'しきい値を5下げる',
                  onPressed: state.threshold <= 10
                      ? null
                      : () => onThresholdChanged(state.threshold - 5),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  key: const ValueKey<String>('vision_threshold_inc'),
                  tooltip: 'しきい値を5上げる',
                  onPressed: state.threshold >= 100
                      ? null
                      : () => onThresholdChanged(state.threshold + 5),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            Slider(
              key: const ValueKey<String>('vision_benchmark_threshold_slider'),
              value: state.threshold.clamp(10, 100).toDouble(),
              min: 10,
              max: 100,
              divisions: 18,
              label: '${state.threshold}点',
              onChanged: (final double value) =>
                  onThresholdChanged(value.round()),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final preset in _presetThresholds)
                  ChoiceChip(
                    key: ValueKey<String>('vision_threshold_chip_$preset'),
                    label: Text('$preset点'),
                    selected: state.threshold == preset,
                    onSelected: (final bool selected) {
                      if (selected) {
                        onThresholdChanged(preset);
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelFilterCard(final ColorScheme colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        ChoiceChip(
          key: const ValueKey<String>('vision_model_filter_all'),
          label: const Text('すべてのモデル'),
          selected: state.selectedModel == null,
          onSelected: (final bool selected) {
            if (selected) {
              onSelectModel(null);
            }
          },
        ),
        for (final model in state.availableModels)
          ChoiceChip(
            key: ValueKey<String>('vision_model_filter_$model'),
            label: Text(model),
            selected: state.selectedModel == model,
            onSelected: (final bool selected) {
              onSelectModel(selected ? model : null);
            },
          ),
      ],
    );
  }

  Widget _buildEmptyCard(final ColorScheme colors) {
    return Container(
      key: const ValueKey<String>('vision_benchmark_empty_state'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.analytics_outlined,
            size: 36,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          const Text(
            'Vision ベンチマークの計測履歴はまだありません',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'AI ステータス画面でモデルテストを実行すると、ここに時系列推移と警告判定が記録されます。',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChartCard(
    final BuildContext context,
    final ColorScheme colors,
    final List<VisionBenchmarkRun> runs,
  ) {
    final chronological =
        runs.take(14).toList(growable: false).reversed.toList();
    const maxBarHeight = 108.0;
    const labelFooterHeight = 36.0;
    final thresholdBottom = labelFooterHeight +
        (state.threshold.clamp(1, 100) / 100.0) * maxBarHeight;

    return Card(
      key: const ValueKey<String>('vision_benchmark_trend_chart'),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '時系列スコア推移（直近 ${chronological.length}件 / 基準線 ${state.threshold}点）',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                height: 176,
                width: (chronological.length * 64.0).clamp(280.0, 1200.0),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: thresholdBottom,
                      child: Container(
                        height: 1.5,
                        color: const Color(0xFFDC2626).withValues(alpha: 0.7),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        for (final run in chronological)
                          _buildChartBar(
                            colors: colors,
                            run: run,
                            maxBarHeight: maxBarHeight,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBar({
    required final ColorScheme colors,
    required final VisionBenchmarkRun run,
    required final double maxBarHeight,
  }) {
    final isAlert = run.isBelowThreshold(state.threshold);
    final barColor =
        isAlert ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final barHeight = ((run.score.clamp(4, 100) / 100.0) * maxBarHeight);
    final timeLabel = _formatShortTime(run.recordedAt);

    return SizedBox(
      width: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              '${run.score}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 24,
              height: barHeight,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
            ),
            Text(
              run.model,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: colors.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTableCard(
    final BuildContext context,
    final ColorScheme colors,
    final List<VisionBenchmarkRun> runs,
  ) {
    return Card(
      key: const ValueKey<String>('vision_benchmark_history_table'),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '計測履歴一覧 (${runs.length}件)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            for (final run in runs) _buildHistoryRow(colors, run),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRow(
    final ColorScheme colors,
    final VisionBenchmarkRun run,
  ) {
    final isAlert = run.isBelowThreshold(state.threshold);
    final badgeBg = isAlert ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    final badgeFg = isAlert ? const Color(0xFF991B1B) : const Color(0xFF166534);

    return Container(
      key: ValueKey<String>('vision_run_card_${run.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlert ? const Color(0xFFDC2626) : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      run.model,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${run.provider.toUpperCase()} · ${_formatTimestamp(run.recordedAt)} · ${run.latencyMs}ms',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${run.score}点 · ${isAlert ? '警告' : '正常'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          if (run.detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              run.detail,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
          if (run.levels.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final level in run.levels)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: level.passed
                          ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                          : const Color(0xFFDC2626).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${level.level}: ${level.score}/${level.maxPoints}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: level.passed
                            ? const Color(0xFF166534)
                            : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatShortTime(final DateTime dt) {
    final local = dt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  String _formatTimestamp(final DateTime dt) {
    final local = dt.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
