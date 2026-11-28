import 'package:flutter/material.dart';

import '../application/structured_llm_routing_controller.dart';
import '../domain/structured_llm_routing_models.dart';

class StructuredLlmRoutingView extends StatefulWidget {
  const StructuredLlmRoutingView({
    super.key,
    required this.controller,
    this.initialTaskType = 'classification',
  });

  final StructuredLlmRoutingController controller;
  final String initialTaskType;

  @override
  State<StructuredLlmRoutingView> createState() =>
      _StructuredLlmRoutingViewState();
}

class _StructuredLlmRoutingViewState extends State<StructuredLlmRoutingView> {
  static const String _defaultSchemaJson = '''{
  "type": "object",
  "additionalProperties": false,
  "required": ["category", "confidence", "tags"],
  "properties": {
    "category": {
      "type": "string",
      "enum": ["food", "travel", "software", "utilities"]
    },
    "confidence": {
      "type": "number",
      "minimum": 0,
      "maximum": 1
    },
    "tags": {
      "type": "array",
      "minItems": 1,
      "items": { "type": "string" }
    }
  }
}''';

  static const String _defaultOutputJson = '''{
  "category": "software",
  "confidence": 0.94,
  "tags": ["cloud", "ai-router"]
}''';

  late final TextEditingController _taskTypeController;
  late final TextEditingController _promptController;
  late final TextEditingController _schemaNameController;
  late final TextEditingController _schemaJsonController;
  late final TextEditingController _outputJsonController;
  bool _requiresReasoning = false;

  @override
  void initState() {
    super.initState();
    _taskTypeController = TextEditingController(text: widget.initialTaskType);
    _promptController = TextEditingController(
      text: 'Classify this expense item into a strict JSON category.',
    );
    _schemaNameController = TextEditingController(text: 'expense_category');
    _schemaJsonController = TextEditingController(text: _defaultSchemaJson);
    _outputJsonController = TextEditingController(text: _defaultOutputJson);
  }

  @override
  void dispose() {
    _taskTypeController.dispose();
    _promptController.dispose();
    _schemaNameController.dispose();
    _schemaJsonController.dispose();
    _outputJsonController.dispose();
    super.dispose();
  }

  void _selectPreset(String taskType, bool requiresReasoning, String prompt) {
    setState(() {
      _taskTypeController.text = taskType;
      _requiresReasoning = requiresReasoning;
      _promptController.text = prompt;
    });
    widget.controller.previewRoute(
      taskType: taskType,
      prompt: prompt,
      requiresReasoning: requiresReasoning,
    );
  }

  Future<void> _onEvaluateRoute() async {
    await widget.controller.evaluateRoute(
      taskType: _taskTypeController.text,
      prompt: _promptController.text,
      requiresReasoning: _requiresReasoning,
      rawSchemaJson: _schemaJsonController.text,
      schemaName: _schemaNameController.text,
    );
  }

  Future<void> _onValidateAndSave() async {
    final bool saved = await widget.controller.validateAndPersist(
      taskType: _taskTypeController.text,
      prompt: _promptController.text,
      requiresReasoning: _requiresReasoning,
      rawOutput: _outputJsonController.text,
      rawSchemaJson: _schemaJsonController.text,
      schemaName: _schemaNameController.text,
    );
    if (!mounted) {
      return;
    }
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('構造化出力を検証しルーティング設定を保存しました。'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM ルーティング & 構造化出力'),
        actions: [
          IconButton(
            tooltip: '設定を再読込',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.refresh),
            onPressed: () {
              widget.controller.loadPreferences();
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final LlmRoutePlan? plan = widget.controller.routePlan;
          final StructuredValidationOutcome? validation =
              widget.controller.validationOutcome;
          final String? errorMessage = widget.controller.errorMessage;
          final List<StructuredRoutingPreferenceRecord> preferences =
              widget.controller.preferences;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (errorMessage != null)
                      _StatusBanner(
                        backgroundColor: colors.errorContainer,
                        foregroundColor: colors.onErrorContainer,
                        icon: Icons.error_outline,
                        title: '確認が必要です',
                        body: errorMessage,
                        actionLabel: '再試行',
                        onAction: widget.controller.isLoading
                            ? null
                            : () {
                                widget.controller.loadPreferences();
                              },
                      ),
                    if (errorMessage != null) const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1. タスク複雑度ルーティング設定',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '分類やタグ付けなどの軽量タスクは高速・低コストモデルへ、複雑な分析や監査は高性能モデルへ振り分けます。',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ActionChip(
                                  label: const Text('分類 (軽量)'),
                                  onPressed: () => _selectPreset(
                                    'classification',
                                    false,
                                    'Classify this item into a single category.',
                                  ),
                                ),
                                ActionChip(
                                  label: const Text('要約 (標準)'),
                                  onPressed: () => _selectPreset(
                                    'summary',
                                    false,
                                    'Summarize key points in structured JSON.',
                                  ),
                                ),
                                ActionChip(
                                  label: const Text('分析 (高性能)'),
                                  onPressed: () => _selectPreset(
                                    'analysis',
                                    true,
                                    'Analyze tradeoffs across cost, latency, and reliability.',
                                  ),
                                ),
                                ActionChip(
                                  label: const Text('セキュリティ監査 (最高性能)'),
                                  onPressed: () => _selectPreset(
                                    'security_audit',
                                    true,
                                    'Audit access control and schema boundaries.',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const ValueKey<String>('task_type_field'),
                              controller: _taskTypeController,
                              decoration: const InputDecoration(
                                labelText: 'タスク種別 (task_type)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const ValueKey<String>('prompt_field'),
                              controller: _promptController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'プロンプト概要',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('高度な多段階推論が必要'),
                              subtitle: const Text('有効時は complex 以上へ自動昇格します'),
                              value: _requiresReasoning,
                              onChanged: (value) {
                                setState(() {
                                  _requiresReasoning = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  key: const ValueKey<String>(
                                    'evaluate_route_button',
                                  ),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  onPressed: widget.controller.isSubmitting
                                      ? null
                                      : _onEvaluateRoute,
                                  icon: const Icon(Icons.alt_route),
                                  label: const Text('最適モデルを判定'),
                                ),
                                OutlinedButton.icon(
                                  key: const ValueKey<String>(
                                    'preview_route_button',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  onPressed: () {
                                    widget.controller.previewRoute(
                                      taskType: _taskTypeController.text,
                                      prompt: _promptController.text,
                                      requiresReasoning: _requiresReasoning,
                                    );
                                  },
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('ローカル試算'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (plan != null) ...[
                      const SizedBox(height: 12),
                      _RouteDecisionCard(plan: plan),
                    ],
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '2. JSON Schema 厳密バリデーション & 保存',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'response_schema へ適合しない出力は保存前にブロックします。',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const ValueKey<String>('schema_name_field'),
                              controller: _schemaNameController,
                              decoration: const InputDecoration(
                                labelText: 'スキーマ名 (schema_name)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const ValueKey<String>('schema_json_field'),
                              controller: _schemaJsonController,
                              maxLines: 8,
                              decoration: const InputDecoration(
                                labelText: 'JSON Schema 定義',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const ValueKey<String>('output_json_field'),
                              controller: _outputJsonController,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: '構造化出力 JSON 候補',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              key: const ValueKey<String>(
                                'validate_and_save_button',
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: widget.controller.isSubmitting
                                  ? null
                                  : _onValidateAndSave,
                              icon: const Icon(Icons.verified_outlined),
                              label: const Text('スキーマ検証して保存'),
                            ),
                            if (validation != null) ...[
                              const SizedBox(height: 12),
                              _ValidationResultSection(validation: validation),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '3. 保存済みタスク別ルーティング設定',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (widget.controller.isLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            else if (preferences.isEmpty)
                              Text(
                                '保存済み設定はまだありません。上の検証・保存を実行するとここに反映されます。',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              )
                            else
                              Column(
                                children: preferences.map((pref) {
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      pref.isEnabled
                                          ? Icons.check_circle_outline
                                          : Icons.pause_circle_outline,
                                      color: colors.primary,
                                    ),
                                    title: Text(
                                      '${pref.task} → ${pref.provider}',
                                    ),
                                    subtitle: Text(
                                      'model: ${pref.model ?? '-'} (${pref.source})',
                                    ),
                                  );
                                }).toList(growable: false),
                              ),
                          ],
                        ),
                      ),
                    ),
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foregroundColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(color: foregroundColor),
                  ),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: TextStyle(color: foregroundColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteDecisionCard extends StatelessWidget {
  const _RouteDecisionCard({required this.plan});

  final LlmRoutePlan plan;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '選定結果: ${plan.provider} / ${plan.model}',
              style: textTheme.titleMedium?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Tier: ${plan.tier.wireValue}')),
                Chip(label: Text('Class: ${plan.modelClass.wireValue}')),
                Chip(label: Text('Effort: ${plan.effort}')),
                Chip(label: Text('OutputCap: ${plan.recommendedOutputLimit}')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plan.reason,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
            if (plan.fallbackChain.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Fallback: ${plan.fallbackChain.join(' -> ')}',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValidationResultSection extends StatelessWidget {
  const _ValidationResultSection({required this.validation});

  final StructuredValidationOutcome validation;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (validation.valid) {
      return _StatusBanner(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        icon: Icons.check_circle_outline,
        title: 'JSON Schema 検証 OK',
        body: validation.normalizedJson ?? '{}',
      );
    }

    final String issueLines = validation.issues
        .map((issue) => '• ${issue.path}: ${issue.message}')
        .join('\n');
    return _StatusBanner(
      backgroundColor: colors.errorContainer,
      foregroundColor: colors.onErrorContainer,
      icon: Icons.block,
      title: 'JSON Schema 不一致 (${validation.issues.length} 件)',
      body: issueLines,
    );
  }
}
