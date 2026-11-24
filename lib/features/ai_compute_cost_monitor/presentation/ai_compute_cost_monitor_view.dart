import 'package:flutter/material.dart';

import '../application/ai_compute_cost_monitor_controller.dart';
import '../domain/ai_compute_cost_monitor_models.dart';

@immutable
class _ComputeCostPalette {
  const _ComputeCostPalette({
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.ink,
    required this.inkSecondary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.accentSoftInk,
    required this.warnBg,
    required this.warnBorder,
    required this.warnInk,
    required this.dangerBg,
    required this.dangerBorder,
    required this.dangerInk,
    required this.okBg,
    required this.okBorder,
    required this.okInk,
  });

  factory _ComputeCostPalette.fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _ComputeCostPalette(
        surface: Color(0xFF111827),
        surfaceSubtle: Color(0xFF1F2937),
        border: Color(0xFF9CA3AF),
        ink: Color(0xFFF9FAFB),
        inkSecondary: Color(0xFFE5E7EB),
        accent: Color(0xFF93C5FD),
        onAccent: Color(0xFF0B2545),
        accentSoft: Color(0xFF1E3A5F),
        accentSoftInk: Color(0xFFE0F2FE),
        warnBg: Color(0xFF332100),
        warnBorder: Color(0xFFFBBF24),
        warnInk: Color(0xFFFEF3C7),
        dangerBg: Color(0xFF450A0A),
        dangerBorder: Color(0xFFFCA5A5),
        dangerInk: Color(0xFFFEE2E2),
        okBg: Color(0xFF022C22),
        okBorder: Color(0xFF6EE7B7),
        okInk: Color(0xFFD1FAE5),
      );
    }
    return const _ComputeCostPalette(
      surface: Color(0xFFFFFFFF),
      surfaceSubtle: Color(0xFFF3F5F8),
      border: Color(0xFF4B5563),
      ink: Color(0xFF111827),
      inkSecondary: Color(0xFF374151),
      accent: Color(0xFF0F4C81),
      onAccent: Color(0xFFFFFFFF),
      accentSoft: Color(0xFFE6EFF8),
      accentSoftInk: Color(0xFF0B355C),
      warnBg: Color(0xFFFFF4E5),
      warnBorder: Color(0xFF8A4B00),
      warnInk: Color(0xFF5A2E00),
      dangerBg: Color(0xFFFEF2F2),
      dangerBorder: Color(0xFF991B1B),
      dangerInk: Color(0xFF7F1D1D),
      okBg: Color(0xFFECFDF5),
      okBorder: Color(0xFF065F46),
      okInk: Color(0xFF064E3B),
    );
  }

  final Color surface;
  final Color surfaceSubtle;
  final Color border;
  final Color ink;
  final Color inkSecondary;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color accentSoftInk;
  final Color warnBg;
  final Color warnBorder;
  final Color warnInk;
  final Color dangerBg;
  final Color dangerBorder;
  final Color dangerInk;
  final Color okBg;
  final Color okBorder;
  final Color okInk;
}

/// 計算規模・GPU コスト＆レイテンシ監視 純粋 Presentation View (#2658).
class AiComputeCostMonitorView extends StatelessWidget {
  const AiComputeCostMonitorView({
    super.key,
    required this.state,
    required this.selectedInputProfile,
    required this.toolController,
    required this.modelController,
    required this.inputTokensController,
    required this.outputTokensController,
    required this.latencyMsController,
    required this.dailyThresholdController,
    required this.monthlyThresholdController,
    required this.searchController,
    required this.onRetryLoad,
    required this.onSelectPeriod,
    required this.onSelectProfileFilter,
    required this.onSelectInputProfile,
    required this.onSearchChanged,
    required this.onSubmitInvocation,
    required this.onUpdateThresholds,
  });

  final AiComputeCostMonitorState state;
  final GpuComputeProfile selectedInputProfile;
  final TextEditingController toolController;
  final TextEditingController modelController;
  final TextEditingController inputTokensController;
  final TextEditingController outputTokensController;
  final TextEditingController latencyMsController;
  final TextEditingController dailyThresholdController;
  final TextEditingController monthlyThresholdController;
  final TextEditingController searchController;
  final VoidCallback onRetryLoad;
  final ValueChanged<ComputeCostPeriod> onSelectPeriod;
  final ValueChanged<GpuComputeProfile?> onSelectProfileFilter;
  final ValueChanged<GpuComputeProfile> onSelectInputProfile;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSubmitInvocation;
  final VoidCallback onUpdateThresholds;

  @override
  Widget build(BuildContext context) {
    final palette = _ComputeCostPalette.fromBrightness(
      Theme.of(context).brightness,
    );
    final filtered = state.filteredEntries;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'AI 計算規模・GPU コスト＆レイテンシ監視',
              style: TextStyle(
                color: palette.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AiComputeCostEstimator.estimateDisclaimer,
              style: TextStyle(color: palette.inkSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            _buildKpiRow(palette),
            const SizedBox(height: 14),
            _buildThresholdCard(palette),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildErrorBanner(palette, state.errorMessage!),
            ],
            const SizedBox(height: 14),
            _buildChartSection(palette),
            const SizedBox(height: 14),
            _buildUserUtilizationSection(palette),
            const SizedBox(height: 14),
            _buildTelemetryRecorder(palette),
            const SizedBox(height: 14),
            _buildFilterControls(palette),
            const SizedBox(height: 12),
            if (state.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Semantics(
                    label: '計算コストテレメトリを読み込み中',
                    child: CircularProgressIndicator(color: palette.accent),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              _buildEmptyState(palette)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: filtered
                    .map(
                      (AiComputeTelemetryEntry entry) =>
                          _buildEntryCard(palette, entry),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(_ComputeCostPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _buildMetricTile(palette, '総リクエスト', '${state.totalRequests}回'),
        _buildMetricTile(palette, '総トークン', '${state.totalTokens}'),
        _buildMetricTile(
          palette,
          '平均レイテンシ',
          '${state.averageLatencyMs.toStringAsFixed(1)} ms',
        ),
        _buildMetricTile(
          palette,
          '総概算コスト',
          'USD ${state.totalEstimatedCostUsd.toStringAsFixed(4)}',
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    _ComputeCostPalette palette,
    String label,
    String value,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(color: palette.inkSecondary, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: palette.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    _ComputeCostPalette palette, {
    required String labelText,
    required String hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: TextStyle(color: palette.inkSecondary),
      hintStyle: TextStyle(color: palette.inkSecondary),
      filled: true,
      fillColor: palette.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.accent, width: 2),
      ),
    );
  }

  Widget _buildThresholdCard(_ComputeCostPalette palette) {
    final alertActive = state.isThresholdAlertActive;
    final bg = alertActive ? palette.dangerBg : palette.okBg;
    final border = alertActive ? palette.dangerBorder : palette.okBorder;
    final ink = alertActive ? palette.dangerInk : palette.okInk;

    return DecoratedBox(
      key: const ValueKey<String>('ai-compute-threshold-card'),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  alertActive
                      ? 'システム計算コスト上限閾値を超過 — 運用アラート発報対象'
                      : 'システム計算コスト上限閾値内（正常稼働）',
                  style: TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '日別上限 USD ${state.thresholdSettings.dailyThresholdUsd.toStringAsFixed(2)} / 月別上限 USD ${state.thresholdSettings.monthlyThresholdUsd.toStringAsFixed(2)}',
                  style: TextStyle(color: ink, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (state.isAdmin) ...<Widget>[
              TextField(
                key: const ValueKey<String>('ai-compute-daily-threshold-field'),
                controller: dailyThresholdController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: palette.ink),
                decoration: _inputDecoration(
                  palette,
                  labelText: '日別コスト閾値 (USD)',
                  hintText: '50.0',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey<String>(
                  'ai-compute-monthly-threshold-field',
                ),
                controller: monthlyThresholdController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: palette.ink),
                decoration: _inputDecoration(
                  palette,
                  labelText: '月別コスト閾値 (USD)',
                  hintText: '500.0',
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                key: const ValueKey<String>(
                  'ai-compute-update-threshold-button',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                ),
                onPressed:
                    state.isUpdatingThreshold ? null : onUpdateThresholds,
                child: Text(
                  state.isUpdatingThreshold ? '閾値を更新中...' : 'システムコスト閾値を更新',
                ),
              ),
            ] else
              Text(
                'システム全体コスト閾値の変更は管理者のみ実行できます。',
                key: const ValueKey<String>(
                  'ai-compute-threshold-readonly-note',
                ),
                style: TextStyle(color: ink, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(_ComputeCostPalette palette, String message) {
    return DecoratedBox(
      key: const ValueKey<String>('ai-compute-error-banner'),
      decoration: BoxDecoration(
        color: palette.dangerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.dangerBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              message,
              style: TextStyle(color: palette.dangerInk, fontSize: 13),
            ),
            OutlinedButton(
              key: const ValueKey<String>('ai-compute-retry-button'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: palette.surface,
                foregroundColor: palette.dangerInk,
                side: BorderSide(color: palette.dangerBorder),
              ),
              onPressed: onRetryLoad,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(_ComputeCostPalette palette) {
    final buckets = state.activePeriodBuckets;
    double maxCost = 0.0;
    for (final b in buckets) {
      if (b.totalEstimatedCostUsd > maxCost) {
        maxCost = b.totalEstimatedCostUsd;
      }
    }
    final activeLimit = state.selectedPeriod == ComputeCostPeriod.daily
        ? state.thresholdSettings.dailyThresholdUsd
        : state.thresholdSettings.monthlyThresholdUsd;
    final chartCeiling = maxCost > activeLimit ? maxCost : activeLimit;

    return DecoratedBox(
      key: const ValueKey<String>('ai-compute-chart-card'),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  '推論概算コスト推移 (${state.selectedPeriod.label})',
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ComputeCostPeriod.values.map((
                    ComputeCostPeriod p,
                  ) {
                    final selected = state.selectedPeriod == p;
                    return Semantics(
                      selected: selected,
                      button: true,
                      label: '期間切替 ${p.label}',
                      child: OutlinedButton(
                        key: ValueKey<String>('ai-compute-period-${p.name}'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          backgroundColor:
                              selected ? palette.accentSoft : palette.surface,
                          foregroundColor:
                              selected ? palette.accentSoftInk : palette.ink,
                          side: BorderSide(
                            color: selected ? palette.accent : palette.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        onPressed: () => onSelectPeriod(p),
                        child: Text(p.label),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (buckets.isEmpty)
              Text(
                '集計対象のコストデータはまだありません。',
                style: TextStyle(color: palette.inkSecondary, fontSize: 13),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: buckets.map((ComputeCostPeriodBucket bucket) {
                  final ratio = chartCeiling <= 0
                      ? 0.0
                      : (bucket.totalEstimatedCostUsd / chartCeiling)
                          .clamp(0.05, 1.0);
                  final isOver = bucket.totalEstimatedCostUsd >= activeLimit;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              bucket.bucketKey,
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'USD ${bucket.totalEstimatedCostUsd.toStringAsFixed(4)} | ${bucket.requestCount}回 | ${bucket.avgLatencyMs.toStringAsFixed(1)} ms',
                              style: TextStyle(
                                color: palette.inkSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Semantics(
                          label:
                              '${bucket.bucketKey} コスト USD ${bucket.totalEstimatedCostUsd.toStringAsFixed(4)}',
                          child: SizedBox(
                            height: 12,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: palette.border),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: ratio,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: isOver
                                        ? palette.dangerBorder
                                        : palette.accent,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserUtilizationSection(_ComputeCostPalette palette) {
    final summaries = state.userSummaries;
    return DecoratedBox(
      key: const ValueKey<String>('ai-compute-user-utilization-card'),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'ユーザー別利用頻度＆計算負荷サマリー',
              style: TextStyle(
                color: palette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (summaries.isEmpty)
              Text(
                'ユーザー別利用履歴はまだありません。',
                style: TextStyle(color: palette.inkSecondary, fontSize: 13),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: summaries.map((UserUtilizationSummary u) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              u.userId,
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${u.requestCount}回 | ${u.totalTokens} tokens | 平均 ${u.avgLatencyMs.toStringAsFixed(1)} ms | USD ${u.totalEstimatedCostUsd.toStringAsFixed(4)}',
                              style: TextStyle(
                                color: palette.inkSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryRecorder(_ComputeCostPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'AI ツール推論消費の記録（シミュレーション）',
              style: TextStyle(
                color: palette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GpuComputeProfile.values.map((GpuComputeProfile p) {
                final selected = selectedInputProfile == p;
                return Semantics(
                  selected: selected,
                  button: true,
                  label: '記録GPUプロファイル ${p.displayLabel}',
                  child: OutlinedButton(
                    key: ValueKey<String>(
                      'ai-compute-input-profile-${p.wireValue}',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor:
                          selected ? palette.accentSoft : palette.surface,
                      foregroundColor:
                          selected ? palette.accentSoftInk : palette.ink,
                      side: BorderSide(
                        color: selected ? palette.accent : palette.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    onPressed: () => onSelectInputProfile(p),
                    child: Text(p.displayLabel),
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('ai-compute-tool-field'),
              controller: toolController,
              style: TextStyle(color: palette.ink),
              decoration: _inputDecoration(
                palette,
                labelText: 'AI ツール名',
                hintText: '例: ai-hub',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('ai-compute-model-field'),
              controller: modelController,
              style: TextStyle(color: palette.ink),
              decoration: _inputDecoration(
                palette,
                labelText: 'モデル ID',
                hintText: '例: gemini-2.5-flash',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('ai-compute-input-tokens-field'),
              controller: inputTokensController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: palette.ink),
              decoration: _inputDecoration(
                palette,
                labelText: '入力トークン数',
                hintText: '1200',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('ai-compute-output-tokens-field'),
              controller: outputTokensController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: palette.ink),
              decoration: _inputDecoration(
                palette,
                labelText: '出力トークン数',
                hintText: '450',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('ai-compute-latency-field'),
              controller: latencyMsController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: palette.ink),
              decoration: _inputDecoration(
                palette,
                labelText: '応答レイテンシ (ms)',
                hintText: '640',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const ValueKey<String>('ai-compute-submit-button'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: palette.accent,
                foregroundColor: palette.onAccent,
              ),
              onPressed: state.isSubmitting ? null : onSubmitInvocation,
              child: Text(
                state.isSubmitting ? 'テレメトリを記録中...' : '推論テレメトリを記録',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterControls(_ComputeCostPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('ai-compute-search-field'),
          controller: searchController,
          onChanged: onSearchChanged,
          style: TextStyle(color: palette.ink),
          decoration: _inputDecoration(
            palette,
            labelText: 'ツール・モデル・ユーザー検索',
            hintText: '例: ai-hub, claude, usr-alpha',
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _buildFilterButton(
              palette,
              keyValue: 'all',
              label: 'すべて',
              selected: state.selectedProfile == null,
              onPressed: () => onSelectProfileFilter(null),
            ),
            ...GpuComputeProfile.values.map(
              (GpuComputeProfile p) => _buildFilterButton(
                palette,
                keyValue: p.wireValue,
                label: p.displayLabel,
                selected: state.selectedProfile == p,
                onPressed: () => onSelectProfileFilter(p),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterButton(
    _ComputeCostPalette palette, {
    required String keyValue,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      selected: selected,
      button: true,
      label: 'GPUプロファイルフィルタ $label',
      child: OutlinedButton(
        key: ValueKey<String>('ai-compute-filter-$keyValue'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: selected ? palette.accentSoft : palette.surface,
          foregroundColor: selected ? palette.accentSoftInk : palette.ink,
          side: BorderSide(
            color: selected ? palette.accent : palette.border,
            width: selected ? 2 : 1,
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  Widget _buildEmptyState(_ComputeCostPalette palette) {
    return DecoratedBox(
      key: const ValueKey<String>('ai-compute-empty-card'),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '条件に一致する計算コストテレメトリはありません。',
          style: TextStyle(color: palette.inkSecondary, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildEntryCard(
    _ComputeCostPalette palette,
    AiComputeTelemetryEntry entry,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        key: ValueKey<String>('ai-compute-entry-${entry.id}'),
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: entry.thresholdAlertTriggered
                          ? palette.dangerBg
                          : palette.accentSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: entry.thresholdAlertTriggered
                            ? palette.dangerBorder
                            : palette.accent,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        entry.gpuProfile.displayLabel,
                        style: TextStyle(
                          color: entry.thresholdAlertTriggered
                              ? palette.dangerInk
                              : palette.accentSoftInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '${entry.toolName} (${entry.modelId})',
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '入力 ${entry.inputTokens} / 出力 ${entry.outputTokens} tokens | ${entry.apiRequestCount} req | ${entry.latencyMs} ms | USD ${entry.estimatedComputeCostUsd.toStringAsFixed(6)}',
                style: TextStyle(color: palette.inkSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
