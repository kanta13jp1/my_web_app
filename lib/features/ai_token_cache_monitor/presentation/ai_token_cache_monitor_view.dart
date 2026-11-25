import 'package:flutter/material.dart';

import '../application/ai_token_cache_monitor_controller.dart';
import '../domain/ai_token_cache_monitor_models.dart';

class AiTokenCacheMonitorView extends StatefulWidget {
  const AiTokenCacheMonitorView({
    super.key,
    required this.controller,
  });

  final AiTokenCacheMonitorController controller;

  @override
  State<AiTokenCacheMonitorView> createState() =>
      _AiTokenCacheMonitorViewState();
}

class _AiTokenCacheMonitorViewState extends State<AiTokenCacheMonitorView> {
  final TextEditingController _toolNameController = TextEditingController(
    text: 'claude-search',
  );
  final TextEditingController _modelIdController = TextEditingController(
    text: 'claude-haiku-4-5',
  );
  final TextEditingController _inputUnitsController = TextEditingController(
    text: '1200',
  );
  final TextEditingController _outputUnitsController = TextEditingController(
    text: '240',
  );
  final TextEditingController _cachedReadController = TextEditingController(
    text: '900',
  );
  final TextEditingController _systemPromptController = TextEditingController(
    text: 'You are a concise tool discovery assistant.',
  );
  final TextEditingController _toolCountController = TextEditingController(
    text: '20',
  );
  final TextEditingController _breakpointController = TextEditingController(
    text: '1',
  );

  bool _useToolSearch = true;

  @override
  void dispose() {
    _toolNameController.dispose();
    _modelIdController.dispose();
    _inputUnitsController.dispose();
    _outputUnitsController.dispose();
    _cachedReadController.dispose();
    _systemPromptController.dispose();
    _toolCountController.dispose();
    _breakpointController.dispose();
    super.dispose();
  }

  int _parseNonNegativeInt(String raw, int fallback) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < 0) {
      return fallback;
    }
    return parsed;
  }

  void _runLocalPreview() {
    widget.controller.previewDiagnostics(
      systemPrompt: _systemPromptController.text,
      toolCount: _parseNonNegativeInt(_toolCountController.text, 0),
      useToolSearch: _useToolSearch,
      breakpointCount: _parseNonNegativeInt(_breakpointController.text, 0),
    );
  }

  Future<void> _submitRecord() async {
    await widget.controller.recordAndDiagnose(
      toolName: _toolNameController.text,
      modelId: _modelIdController.text,
      inputUnits: _parseNonNegativeInt(_inputUnitsController.text, 0),
      outputUnits: _parseNonNegativeInt(_outputUnitsController.text, 0),
      cachedReadUnits: _parseNonNegativeInt(_cachedReadController.text, 0),
      systemPrompt: _systemPromptController.text,
      toolCount: _parseNonNegativeInt(_toolCountController.text, 0),
      useToolSearch: _useToolSearch,
      breakpointCount: _parseNonNegativeInt(_breakpointController.text, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('AI ツール消費・キャッシュ最適化'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: <Widget>[
          IconButton(
            key: const Key('ai_token_cache_refresh_btn'),
            tooltip: '再読み込み',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: widget.controller.loadSummary,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (BuildContext context, Widget? child) {
          final summary = widget.controller.summary;
          final diagnostics = widget.controller.diagnostics;
          final errorMessage = widget.controller.errorMessage;

          if (widget.controller.isLoading && summary == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (errorMessage != null) ...<Widget>[
                      _ErrorCard(
                        message: errorMessage,
                        onRetry: widget.controller.loadSummary,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (summary != null) ...<Widget>[
                      _SummaryKpiSection(summary: summary),
                      const SizedBox(height: 16),
                    ],
                    _DiagnosticFormSection(
                      toolNameController: _toolNameController,
                      modelIdController: _modelIdController,
                      inputUnitsController: _inputUnitsController,
                      outputUnitsController: _outputUnitsController,
                      cachedReadController: _cachedReadController,
                      systemPromptController: _systemPromptController,
                      toolCountController: _toolCountController,
                      breakpointController: _breakpointController,
                      useToolSearch: _useToolSearch,
                      isSubmitting: widget.controller.isSubmitting,
                      onToolSearchChanged: (bool value) {
                        setState(() {
                          _useToolSearch = value;
                        });
                      },
                      onPreview: _runLocalPreview,
                      onSubmit: _submitRecord,
                    ),
                    if (diagnostics != null) ...<Widget>[
                      const SizedBox(height: 16),
                      _DiagnosticsResultCard(diagnostic: diagnostics),
                    ],
                    if (summary != null) ...<Widget>[
                      const SizedBox(height: 16),
                      _ToolBreakdownSection(entries: summary.perToolBreakdown),
                      const SizedBox(height: 16),
                      _SpecializationMatrixSection(
                        specs: summary.specializationMatrix,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('ai_token_cache_retry_btn'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: colorScheme.onErrorContainer,
                ),
                onPressed: onRetry,
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryKpiSection extends StatelessWidget {
  const _SummaryKpiSection({required this.summary});

  final TokenCacheSummarySnapshot summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reusePct = (summary.cacheReuseRatio * 100).toStringAsFixed(1);
    final hitPct = (summary.cacheHitRate * 100).toStringAsFixed(1);
    final savingsText = '\$${summary.totalNetSavingsUsd.toStringAsFixed(4)}';

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'ツール消費・コンテキストキャッシュ KPI',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _MetricTile(
                  label: '総リクエスト数',
                  value: '${summary.totalRequests}',
                ),
                _MetricTile(
                  label: '総処理量 (入力+出力)',
                  value: '${summary.totalUsageUnits}',
                ),
                _MetricTile(
                  label: 'キャッシュ再利用率',
                  value: '$reusePct%',
                ),
                _MetricTile(
                  label: 'キャッシュヒット率',
                  value: '$hitPct%',
                ),
                _MetricTile(
                  label: '純削減額 (USD)',
                  value: savingsText,
                ),
                _MetricTile(
                  label: 'キャッシュ読込 / 書込',
                  value:
                      '${summary.cachedReadUnits} / ${summary.cacheWriteUnits}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticFormSection extends StatelessWidget {
  const _DiagnosticFormSection({
    required this.toolNameController,
    required this.modelIdController,
    required this.inputUnitsController,
    required this.outputUnitsController,
    required this.cachedReadController,
    required this.systemPromptController,
    required this.toolCountController,
    required this.breakpointController,
    required this.useToolSearch,
    required this.isSubmitting,
    required this.onToolSearchChanged,
    required this.onPreview,
    required this.onSubmit,
  });

  final TextEditingController toolNameController;
  final TextEditingController modelIdController;
  final TextEditingController inputUnitsController;
  final TextEditingController outputUnitsController;
  final TextEditingController cachedReadController;
  final TextEditingController systemPromptController;
  final TextEditingController toolCountController;
  final TextEditingController breakpointController;
  final bool useToolSearch;
  final bool isSubmitting;
  final ValueChanged<bool> onToolSearchChanged;
  final VoidCallback onPreview;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'ツール消費記録 ＆ プレフィックス安定性診断',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ai_token_cache_tool_name_field'),
              controller: toolNameController,
              decoration: const InputDecoration(
                labelText: 'ツール名 (tool_name)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ai_token_cache_model_id_field'),
              controller: modelIdController,
              decoration: const InputDecoration(
                labelText: 'モデル ID (model_id)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: const Key('ai_token_cache_input_units_field'),
                    controller: inputUnitsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '入力量',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: const Key('ai_token_cache_output_units_field'),
                    controller: outputUnitsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '出力量',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: const Key('ai_token_cache_cached_read_field'),
                    controller: cachedReadController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'キャッシュ読込量',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: const Key('ai_token_cache_tool_count_field'),
                    controller: toolCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '登録ツール数',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: const Key('ai_token_cache_breakpoint_field'),
                    controller: breakpointController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ブレークポイント数 (最大 4)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ai_token_cache_system_prompt_field'),
              controller: systemPromptController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'システムプレフィックス（動的値混入チェック対象）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('ai_token_cache_tool_search_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Tool Search Tool（遅延ロード）を有効化'),
              value: useToolSearch,
              onChanged: onToolSearchChanged,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton(
                  key: const Key('ai_token_cache_preview_btn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: isSubmitting ? null : onPreview,
                  child: const Text('プレフィックス安定性を診断'),
                ),
                FilledButton(
                  key: const Key('ai_token_cache_submit_btn'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: isSubmitting ? null : onSubmit,
                  child: Text(isSubmitting ? '記録中...' : '使用量を記録して診断'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsResultCard extends StatelessWidget {
  const _DiagnosticsResultCard({required this.diagnostic});

  final PrefixStabilityDiagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isOptimal = diagnostic.status == 'optimal';

    return Card(
      color: isOptimal
          ? colorScheme.secondaryContainer
          : colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '安定性スコア: ${diagnostic.stabilityScore}/100 '
              '(${diagnostic.status})',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isOptimal
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onErrorContainer,
              ),
            ),
            if (diagnostic.warnings.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              for (final warning in diagnostic.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '警告: $warning',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isOptimal
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onErrorContainer,
                    ),
                  ),
                ),
            ],
            if (diagnostic.recommendations.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              for (final rec in diagnostic.recommendations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '推奨: $rec',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isOptimal
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onErrorContainer,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolBreakdownSection extends StatelessWidget {
  const _ToolBreakdownSection({required this.entries});

  final List<ToolUsageBreakdownEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'ツール別消費内訳',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text('計測データはまだ登録されていません。')
            else
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${entry.toolName} (${entry.modelId})',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: <Widget>[
                            Text('役割: ${entry.specializationTier.wireValue}'),
                            Text('件数: ${entry.requestCount}'),
                            Text('合計量: ${entry.totalUnits}'),
                            Text('平均遅延: ${entry.avgLatencyMs}ms'),
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
}

class _SpecializationMatrixSection extends StatelessWidget {
  const _SpecializationMatrixSection({required this.specs});

  final List<ModelSpecializationSpec> specs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'モデル専門特化マトリックス（Search / Execute / Reason）',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final spec in specs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${spec.labelJa} [${spec.tier.wireValue}]',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '推奨モデル: ${spec.recommendedModels.join(', ')}',
                      ),
                      const SizedBox(height: 4),
                      Text('キャッシュ戦略: ${spec.cachingStrategy}'),
                      const SizedBox(height: 4),
                      Text('検証区分: ${spec.measurementScope}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
