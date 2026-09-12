import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../services/ai_university_agentverse_lab_analytics.dart';

typedef AiUniversityAgentVerseLabStart = Future<bool> Function();
typedef AiUniversityAgentVerseImportChecked = Future<bool> Function(
  String outcome,
);
typedef AiUniversityAgentVerseLabSubmit = Future<bool> Function(
  AiUniversityAgentVerseLabCompletion completion,
);

class AiUniversityAgentVerseLabTaskCard extends StatefulWidget {
  const AiUniversityAgentVerseLabTaskCard({
    super.key,
    required this.onStart,
    required this.onImportChecked,
    required this.onSubmit,
  });

  final AiUniversityAgentVerseLabStart onStart;
  final AiUniversityAgentVerseImportChecked onImportChecked;
  final AiUniversityAgentVerseLabSubmit onSubmit;

  @override
  State<AiUniversityAgentVerseLabTaskCard> createState() =>
      _AiUniversityAgentVerseLabTaskCardState();
}

class _AiUniversityAgentVerseLabTaskCardState
    extends State<AiUniversityAgentVerseLabTaskCard> {
  final _singleQuality = TextEditingController();
  final _singleWall = TextEditingController();
  final _singleTokens = TextEditingController();
  final _singleCost = TextEditingController();
  final _fixedQuality = TextEditingController();
  final _fixedWall = TextEditingController();
  final _fixedTokens = TextEditingController();
  final _fixedCost = TextEditingController();
  final _conditionalQuality = TextEditingController();
  final _conditionalWall = TextEditingController();
  final _conditionalTokens = TextEditingController();
  final _conditionalCost = TextEditingController();

  DateTime? _startedAt;
  bool _starting = false;
  bool _importSubmitting = false;
  bool _importRecorded = false;
  bool _importSucceeded = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _importOutcome;
  String? _roleAddReason;
  int? _rubricScore;
  String? _reproducibilityResult;
  String? _workplaceApplication;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _singleQuality,
      _singleWall,
      _singleTokens,
      _singleCost,
      _fixedQuality,
      _fixedWall,
      _fixedTokens,
      _fixedCost,
      _conditionalQuality,
      _conditionalWall,
      _conditionalTokens,
      _conditionalCost,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting || _startedAt != null) return;
    setState(() => _starting = true);
    final accepted = await widget.onStart();
    if (!mounted) return;
    setState(() {
      _starting = false;
      if (accepted) _startedAt = DateTime.now();
    });
    if (!accepted) _showFailure('開始を記録できませんでした。再試行してください。');
  }

  Future<void> _recordImport() async {
    final outcome = _importOutcome;
    if (_importSubmitting || _importRecorded || outcome == null) return;
    setState(() => _importSubmitting = true);
    final accepted = await widget.onImportChecked(outcome);
    if (!mounted) return;
    setState(() {
      _importSubmitting = false;
      _importRecorded = accepted;
      _importSucceeded = accepted && outcome == 'succeeded';
    });
    if (!accepted) _showFailure('import結果を記録できませんでした。再試行してください。');
  }

  AiUniversityAgentVerseRunMetrics? _metrics(
    TextEditingController quality,
    TextEditingController wall,
    TextEditingController tokens,
    TextEditingController cost,
  ) {
    final qualityScore = int.tryParse(quality.text);
    final wallTimeSeconds = int.tryParse(wall.text);
    final tokenCount = int.tryParse(tokens.text);
    final costUsd = double.tryParse(cost.text);
    if (qualityScore == null ||
        wallTimeSeconds == null ||
        tokenCount == null ||
        costUsd == null) {
      return null;
    }
    return AiUniversityAgentVerseRunMetrics(
      qualityScore: qualityScore,
      wallTimeSeconds: wallTimeSeconds,
      tokenCount: tokenCount,
      costUsd: costUsd,
    );
  }

  AiUniversityAgentVerseLabCompletion? _completion() {
    if (!_importSucceeded || _startedAt == null) return null;
    final single = _metrics(
      _singleQuality,
      _singleWall,
      _singleTokens,
      _singleCost,
    );
    final fixed = _metrics(
      _fixedQuality,
      _fixedWall,
      _fixedTokens,
      _fixedCost,
    );
    final conditional = _metrics(
      _conditionalQuality,
      _conditionalWall,
      _conditionalTokens,
      _conditionalCost,
    );
    if (single == null ||
        fixed == null ||
        conditional == null ||
        _roleAddReason == null ||
        _rubricScore == null ||
        _reproducibilityResult == null ||
        _workplaceApplication == null) {
      return null;
    }
    return AiUniversityAgentVerseLabCompletion(
      singleAgent: single,
      fixedRoleTeam: fixed,
      conditionalRoleTeam: conditional,
      roleAddReason: _roleAddReason!,
      rubricScore: _rubricScore!,
      reproducibilityResult: _reproducibilityResult!,
      workplaceApplication: _workplaceApplication!,
      completionSeconds:
          max(1, DateTime.now().difference(_startedAt!).inSeconds),
    );
  }

  Future<void> _submit() async {
    final completion = _completion();
    if (_submitting || _submitted || completion == null) return;
    setState(() => _submitting = true);
    final accepted = await widget.onSubmit(completion);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = accepted;
    });
    if (!accepted) {
      _showFailure('入力値を確認してください。結果は送信されていません。');
    }
  }

  void _showFailure(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _numberField({
    required Key key,
    required String label,
    required TextEditingController controller,
    bool decimal = false,
  }) =>
      TextField(
        key: key,
        controller: controller,
        enabled: !_submitted,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (_) => setState(() {}),
      );

  Widget _runFields({
    required String prefix,
    required String label,
    required TextEditingController quality,
    required TextEditingController wall,
    required TextEditingController tokens,
    required TextEditingController cost,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            _numberField(
              key: Key('agentverse-lab-$prefix-quality'),
              label: '品質rubric（0〜4）',
              controller: quality,
            ),
            _numberField(
              key: Key('agentverse-lab-$prefix-wall'),
              label: 'wall time 秒（1〜3600）',
              controller: wall,
            ),
            _numberField(
              key: Key('agentverse-lab-$prefix-tokens'),
              label: '合計tokens（1〜10000000）',
              controller: tokens,
            ),
            _numberField(
              key: Key('agentverse-lab-$prefix-cost'),
              label: '実測cost USD（0〜100）',
              controller: cost,
              decimal: true,
            ),
          ],
        ),
      );

  Widget _choices({
    required String label,
    required String keyPrefix,
    required List<(String, String)> options,
    required String? value,
    required ValueChanged<String> onSelected,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (optionValue, optionLabel) in options)
                  ChoiceChip(
                    key: Key('$keyPrefix-$optionValue'),
                    label: Text(optionLabel),
                    selected: value == optionValue,
                    onSelected: _submitted
                        ? null
                        : (_) => setState(() => onSelected(optionValue)),
                  ),
              ],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF0F1929),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AgentVerse 60分比較lab — 匿名run evidence',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Startを押すまで記録しません。prompt、生成結果、error本文、API key、個人情報は送信しません。',
              ),
              if (_startedAt == null) ...[
                const SizedBox(height: 12),
                if (_starting)
                  const LinearProgressIndicator()
                else
                  FilledButton.icon(
                    key: const Key('agentverse-lab-start'),
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('labを開始'),
                  ),
              ] else ...[
                _choices(
                  label: 'from agentverse import TaskSolving の結果',
                  keyPrefix: 'agentverse-lab-import',
                  options: const [
                    ('succeeded', '成功'),
                    ('failed', '失敗'),
                  ],
                  value: _importOutcome,
                  onSelected: (value) => _importOutcome = value,
                ),
                const SizedBox(height: 8),
                if (_importSubmitting)
                  const LinearProgressIndicator()
                else if (!_importRecorded)
                  FilledButton(
                    key: const Key('agentverse-lab-import-submit'),
                    onPressed: _importOutcome == null ? null : _recordImport,
                    child: const Text('import結果を匿名送信'),
                  )
                else if (!_importSucceeded) ...[
                  const Text(
                    '失敗を記録しました。講座の代表エラーを確認し、修正後に再計測してください。',
                  ),
                  TextButton(
                    key: const Key('agentverse-lab-import-retry'),
                    onPressed: () => setState(() {
                      _importOutcome = null;
                      _importRecorded = false;
                    }),
                    child: const Text('importを再確認'),
                  ),
                ] else ...[
                  _runFields(
                    prefix: 'single',
                    label: '1. single agent',
                    quality: _singleQuality,
                    wall: _singleWall,
                    tokens: _singleTokens,
                    cost: _singleCost,
                  ),
                  _runFields(
                    prefix: 'fixed',
                    label: '2. fixed role team',
                    quality: _fixedQuality,
                    wall: _fixedWall,
                    tokens: _fixedTokens,
                    cost: _fixedCost,
                  ),
                  _runFields(
                    prefix: 'conditional',
                    label: '3. conditional role team',
                    quality: _conditionalQuality,
                    wall: _conditionalWall,
                    tokens: _conditionalTokens,
                    cost: _conditionalCost,
                  ),
                  _choices(
                    label: '役割追加の判断理由',
                    keyPrefix: 'agentverse-lab-role-reason',
                    options: const [
                      ('missing_expertise', '専門知識不足'),
                      ('quality_gate_failed', '品質gate未達'),
                      ('conflict_resolution', '意見衝突の解消'),
                      ('no_role_added', '追加条件なし'),
                    ],
                    value: _roleAddReason,
                    onSelected: (value) => _roleAddReason = value,
                  ),
                  _choices(
                    label: '4項目lab rubric',
                    keyPrefix: 'agentverse-lab-rubric',
                    options: const [
                      ('0', '0'),
                      ('1', '1'),
                      ('2', '2'),
                      ('3', '3'),
                      ('4', '4'),
                    ],
                    value: _rubricScore?.toString(),
                    onSelected: (value) => _rubricScore = int.parse(value),
                  ),
                  _choices(
                    label: '同じmanifest条件での再現性',
                    keyPrefix: 'agentverse-lab-reproducibility',
                    options: const [
                      ('reproduced', '再現した'),
                      ('not_reproduced', '再現しなかった'),
                      ('not_checked', '未確認'),
                    ],
                    value: _reproducibilityResult,
                    onSelected: (value) => _reproducibilityResult = value,
                  ),
                  _choices(
                    label: '職場での適用',
                    keyPrefix: 'agentverse-lab-workplace',
                    options: const [
                      ('applied', '適用した'),
                      ('planned', '計画した'),
                      ('not_yet', '未実施'),
                    ],
                    value: _workplaceApplication,
                    onSelected: (value) => _workplaceApplication = value,
                  ),
                  const SizedBox(height: 16),
                  if (_submitted)
                    const Text(
                      '匿名run evidenceを送信しました。',
                      key: Key('agentverse-lab-submitted'),
                    )
                  else if (_submitting)
                    const LinearProgressIndicator()
                  else
                    FilledButton.icon(
                      key: const Key('agentverse-lab-submit'),
                      onPressed: _completion() == null ? null : _submit,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('匿名完了結果を送信'),
                    ),
                ],
              ],
            ],
          ),
        ),
      );
}
