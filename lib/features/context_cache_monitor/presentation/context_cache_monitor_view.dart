import 'package:flutter/material.dart';

import '../application/context_cache_monitor_controller.dart';
import '../domain/context_cache_monitor_models.dart';

@immutable
class _CacheMonitorPalette {
  const _CacheMonitorPalette({
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
    required this.successBg,
    required this.successInk,
    required this.errorBg,
    required this.errorBorder,
    required this.errorInk,
  });

  factory _CacheMonitorPalette.fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _CacheMonitorPalette(
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
        successBg: Color(0xFF064E3B),
        successInk: Color(0xFFECFDF5),
        errorBg: Color(0xFF450A0A),
        errorBorder: Color(0xFFFCA5A5),
        errorInk: Color(0xFFFEE2E2),
      );
    }
    return const _CacheMonitorPalette(
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
      successBg: Color(0xFFE6F4EA),
      successInk: Color(0xFF0D4A22),
      errorBg: Color(0xFFFDECEC),
      errorBorder: Color(0xFF991B1B),
      errorInk: Color(0xFF7F1D1D),
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
  final Color successBg;
  final Color successInk;
  final Color errorBg;
  final Color errorBorder;
  final Color errorInk;
}

/// 管理者向けコンテキストキャッシュ消費・USD 節約可視化 View (#2656).
class ContextCacheMonitorView extends StatelessWidget {
  const ContextCacheMonitorView({
    super.key,
    required this.state,
    required this.userFilterController,
    required this.workflowInputController,
    required this.onUserFilterChanged,
    required this.onWorkflowFilterSelected,
    required this.onModelSelected,
    required this.onToggleSimulateCacheHit,
    required this.onRecordSimulatedRequest,
    required this.onRetryLoad,
  });

  final ContextCacheMonitorState state;
  final TextEditingController userFilterController;
  final TextEditingController workflowInputController;
  final ValueChanged<String> onUserFilterChanged;
  final ValueChanged<String> onWorkflowFilterSelected;
  final ValueChanged<String> onModelSelected;
  final ValueChanged<bool> onToggleSimulateCacheHit;
  final VoidCallback onRecordSimulatedRequest;
  final VoidCallback onRetryLoad;

  @override
  Widget build(BuildContext context) {
    final palette = _CacheMonitorPalette.fromBrightness(
      Theme.of(context).brightness,
    );
    final filtered = state.filteredMetrics;
    final rollups = state.rollups;

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
              'コンテキストキャッシュ・USD コスト監視ダッシュボード',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              ContextCacheEstimator.estimateDisclaimer,
              key: const ValueKey<String>('cache_estimate_disclaimer'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.inkSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            _buildSummaryPanel(context, palette, filtered.length),
            const SizedBox(height: 12),
            _buildAdminFilterSection(context, palette),
            const SizedBox(height: 12),
            _buildSimulatorSection(context, palette),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildErrorBanner(context, palette, state.errorMessage!),
            ],
            const SizedBox(height: 16),
            if (state.isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(color: palette.accent),
                ),
              )
            else ...<Widget>[
              _buildRollupSection(context, palette, rollups),
              const SizedBox(height: 16),
              _buildMetricsHistory(context, palette, filtered),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPanel(
    BuildContext context,
    _CacheMonitorPalette palette,
    int filteredCount,
  ) {
    return Container(
      key: const ValueKey<String>('cache_summary_panel'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '集計サマリー ($filteredCount 件 / キャッシュヒット ${state.cacheHitCount} 件)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '実測推定コスト: USD ${state.totalActualUsd.toStringAsFixed(6)} / '
            '非キャッシュ基準: USD ${state.totalBaselineUsd.toStringAsFixed(6)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.ink,
                ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: state.totalSavingsUsd >= 0
                  ? palette.successBg
                  : palette.warnBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '推定節約額: USD ${state.totalSavingsUsd.toStringAsFixed(6)} '
              '(${state.weightedSavingsPercent.toStringAsFixed(1)}% 削減)',
              key: const ValueKey<String>('cache_total_savings_text'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: state.totalSavingsUsd >= 0
                        ? palette.successInk
                        : palette.warnInk,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminFilterSection(
    BuildContext context,
    _CacheMonitorPalette palette,
  ) {
    final workflows = state.availableWorkflows;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '管理者フィルタ (ワークフロー別 / ユーザー別)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildFilterChip(
                context: context,
                palette: palette,
                buttonKey: const ValueKey<String>('cache_workflow_filter_all'),
                label: '全ワークフロー',
                selected: state.workflowFilter.isEmpty,
                onTap: () => onWorkflowFilterSelected(''),
              ),
              for (final wf in workflows)
                _buildFilterChip(
                  context: context,
                  palette: palette,
                  buttonKey: ValueKey<String>('cache_workflow_filter_$wf'),
                  label: wf,
                  selected: state.workflowFilter == wf,
                  onTap: () => onWorkflowFilterSelected(wf),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('cache_user_filter_input'),
            controller: userFilterController,
            onChanged: onUserFilterChanged,
            style: TextStyle(color: palette.ink),
            decoration: InputDecoration(
              labelText: 'ユーザー ID で絞り込み',
              hintText: '例: user-2 / admin-operator',
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required _CacheMonitorPalette palette,
    required Key buttonKey,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label で絞り込み',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Material(
          color: selected ? palette.accent : palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: selected ? palette.accent : palette.border),
          ),
          child: InkWell(
            key: buttonKey,
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? palette.onAccent : palette.ink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimulatorSection(
    BuildContext context,
    _CacheMonitorPalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'マルチターン Cache Write / Read 計測記録',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ContextCacheEstimator.defaultRateCards.keys.map((model) {
              final selected = state.selectedModelId == model;
              return _buildFilterChip(
                context: context,
                palette: palette,
                buttonKey: ValueKey<String>('cache_model_$model'),
                label: model,
                selected: selected,
                onTap: () => onModelSelected(model),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('cache_workflow_input'),
            controller: workflowInputController,
            style: TextStyle(color: palette.ink),
            decoration: InputDecoration(
              labelText: '対象ワークフロー識別子',
              hintText: '例: multi-turn-code-review',
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
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: CheckboxListTile(
              key: const ValueKey<String>('cache_simulate_hit_toggle'),
              contentPadding: EdgeInsets.zero,
              value: state.simulateCacheHit,
              activeColor: palette.accent,
              checkColor: palette.onAccent,
              onChanged: (bool? checked) {
                onToggleSimulateCacheHit(checked ?? false);
              },
              title: Text(
                '2ターン目以降として Cache Read (~0.10x) を有効化',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              subtitle: Text(
                'OFF の場合は初回 Cache Write (プレフィックス登録) として記録されます。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.inkSecondary,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: ElevatedButton(
              key: const ValueKey<String>('cache_record_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.onAccent,
              ),
              onPressed: state.isSubmitting ? null : onRecordSimulatedRequest,
              child: Text(
                state.isSubmitting ? 'Usage テーブルへ記録中...' : 'リクエスト消費ログを記録',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    _CacheMonitorPalette palette,
    String message,
  ) {
    return Container(
      key: const ValueKey<String>('cache_error_banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.errorBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.errorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.errorInk,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: OutlinedButton(
                key: const ValueKey<String>('cache_retry_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.errorInk,
                  side: BorderSide(color: palette.errorBorder),
                ),
                onPressed: onRetryLoad,
                child: const Text('集計を再読み込み'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRollupSection(
    BuildContext context,
    _CacheMonitorPalette palette,
    List<WorkflowUserCacheRollup> rollups,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'ワークフロー・ユーザー別 USD コスト一覧 (${rollups.length} グループ)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        if (rollups.isEmpty)
          Text(
            '該当するワークフロー・ユーザーのキャッシュ利用実績はありません。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.inkSecondary,
                ),
          )
        else
          for (final rollup in rollups)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                key: ValueKey<String>(
                  'cache_rollup_${rollup.workflowKey}_${rollup.userId}',
                ),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  '${rollup.workflowKey} | user=${rollup.userId} | '
                  '実測 USD ${rollup.totalActualUsd.toStringAsFixed(6)} | '
                  '節約 USD ${rollup.totalSavingsUsd.toStringAsFixed(6)} '
                  '(hits ${rollup.cacheHitCount}/${rollup.requestCount})',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.ink,
                      ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildMetricsHistory(
    BuildContext context,
    _CacheMonitorPalette palette,
    List<ContextCacheUsageMetric> filtered,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'リクエスト別トークン・キャッシュ履歴 (${filtered.length} 件)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        for (final item in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              key: ValueKey<String>('cache_metric_card_${item.id}'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${item.workflowKey} (${item.modelId}) - '
                    '${item.cacheHit ? 'CACHE HIT' : 'CACHE WRITE'}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: palette.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Read: ${item.cacheReadCount} / Write: ${item.cacheWriteCount} / '
                    'Uncached: ${item.uncachedInputCount} / Output: ${item.outputCount}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.inkSecondary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '実測 ${item.formattedActualUsd} / 節約 ${item.formattedSavingsUsd} '
                    '(${item.formattedSavingsPercent})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.ink,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
