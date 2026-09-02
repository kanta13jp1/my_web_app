import 'package:flutter/material.dart';

import '../services/ai_university_agentless_lab_analytics.dart';

typedef AiUniversityAgentlessLabStart = Future<bool> Function();
typedef AiUniversityAgentlessLabSubmit = Future<bool> Function(
  AiUniversityAgentlessLabCompletion completion,
);

class AiUniversityAgentlessLabTaskCard extends StatefulWidget {
  const AiUniversityAgentlessLabTaskCard({
    super.key,
    required this.onStart,
    required this.onSubmit,
  });

  final AiUniversityAgentlessLabStart onStart;
  final AiUniversityAgentlessLabSubmit onSubmit;

  @override
  State<AiUniversityAgentlessLabTaskCard> createState() =>
      _AiUniversityAgentlessLabTaskCardState();
}

class _AiUniversityAgentlessLabTaskCardState
    extends State<AiUniversityAgentlessLabTaskCard> {
  final _python = TextEditingController();
  final _threads = TextEditingController();
  final _promptTokens = TextEditingController();
  final _completionTokens = TextEditingController();
  final _embeddingTokens = TextEditingController();
  final _predictedCost = TextEditingController();
  final _actualCost = TextEditingController();
  final _wallTime = TextEditingController();

  bool _starting = false;
  bool _started = false;
  bool _submitting = false;
  bool _submitted = false;
  bool? _localizationCorrect;
  String? _regressionResult;
  String? _reproductionResult;
  String? _testResult;
  String? _reproducibilityResult;
  String? _workplaceApplication;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _python,
      _threads,
      _promptTokens,
      _completionTokens,
      _embeddingTokens,
      _predictedCost,
      _actualCost,
      _wallTime,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting || _started) return;
    setState(() => _starting = true);
    final accepted = await widget.onStart();
    if (!mounted) return;
    setState(() {
      _starting = false;
      _started = accepted;
    });
    if (!accepted) _showFailure('開始を記録できませんでした。再試行してください。');
  }

  AiUniversityAgentlessLabCompletion? _completion() {
    final maxThreads = int.tryParse(_threads.text);
    final promptTokens = int.tryParse(_promptTokens.text);
    final completionTokens = int.tryParse(_completionTokens.text);
    final embeddingTokens = int.tryParse(_embeddingTokens.text);
    final predictedCost = double.tryParse(_predictedCost.text);
    final actualCost = double.tryParse(_actualCost.text);
    final wallTime = int.tryParse(_wallTime.text);
    if (maxThreads == null ||
        promptTokens == null ||
        completionTokens == null ||
        embeddingTokens == null ||
        predictedCost == null ||
        actualCost == null ||
        wallTime == null ||
        _localizationCorrect == null ||
        _regressionResult == null ||
        _reproductionResult == null ||
        _testResult == null ||
        _reproducibilityResult == null ||
        _workplaceApplication == null) {
      return null;
    }
    return AiUniversityAgentlessLabCompletion(
      pythonVersion: _python.text.trim(),
      maxThreads: maxThreads,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      embeddingTokens: embeddingTokens,
      apiCostUsd: actualCost,
      predictedApiCostUsd: predictedCost,
      wallTimeSeconds: wallTime,
      localizationCorrect: _localizationCorrect!,
      regressionResult: _regressionResult!,
      reproductionResult: _reproductionResult!,
      testResult: _testResult!,
      reproducibilityResult: _reproducibilityResult!,
      workplaceApplication: _workplaceApplication!,
    );
  }

  Future<void> _submit() async {
    final completion = _completion();
    if (!_started || _submitting || _submitted || completion == null) return;
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
  }) {
    return TextField(
      key: key,
      controller: controller,
      enabled: !_submitted,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _choices({
    required String label,
    required String keyPrefix,
    required List<(String, String)> options,
    required String? value,
    required ValueChanged<String> onSelected,
  }) {
    return Padding(
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
  }

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF0F1929),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Agentless 60分lab — 匿名run evidence',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Startを押すまで記録しません。manifest、patch、issue本文、API key、自由記述は端末内に残り、送信されません。',
              ),
              if (!_started) ...[
                const SizedBox(height: 12),
                if (_starting)
                  const LinearProgressIndicator()
                else
                  FilledButton.icon(
                    key: const Key('agentless-lab-start'),
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('labを開始'),
                  ),
              ] else ...[
                const SizedBox(height: 12),
                const Text('開始記録済み。実測値を入力してください。0のplaceholderは完了として受理されません。'),
                TextField(
                  key: const Key('agentless-lab-python'),
                  controller: _python,
                  enabled: !_submitted,
                  decoration: const InputDecoration(
                    labelText: 'Python実測版（例: 3.11.9）',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                _numberField(
                  key: const Key('agentless-lab-threads'),
                  label: '最大threads（1〜10）',
                  controller: _threads,
                ),
                _numberField(
                  key: const Key('agentless-lab-prompt-tokens'),
                  label: 'prompt tokens',
                  controller: _promptTokens,
                ),
                _numberField(
                  key: const Key('agentless-lab-completion-tokens'),
                  label: 'completion tokens',
                  controller: _completionTokens,
                ),
                _numberField(
                  key: const Key('agentless-lab-embedding-tokens'),
                  label: 'embedding tokens（未使用なら0）',
                  controller: _embeddingTokens,
                ),
                _numberField(
                  key: const Key('agentless-lab-predicted-cost'),
                  label: '予測API費用 USD',
                  controller: _predictedCost,
                  decimal: true,
                ),
                _numberField(
                  key: const Key('agentless-lab-actual-cost'),
                  label: '実測API費用 USD（0より大）',
                  controller: _actualCost,
                  decimal: true,
                ),
                _numberField(
                  key: const Key('agentless-lab-wall-time'),
                  label: 'wall time 秒（1〜3600）',
                  controller: _wallTime,
                ),
                _choices(
                  label: 'localizationは正しかったか',
                  keyPrefix: 'agentless-lab-localization',
                  options: const [('yes', '正しい'), ('no', '誤り')],
                  value: _localizationCorrect == null
                      ? null
                      : (_localizationCorrect! ? 'yes' : 'no'),
                  onSelected: (value) => _localizationCorrect = value == 'yes',
                ),
                _choices(
                  label: 'regression result',
                  keyPrefix: 'agentless-lab-regression',
                  options: const [
                    ('passed', 'passed'),
                    ('failed', 'failed'),
                    ('not_run', 'not run'),
                  ],
                  value: _regressionResult,
                  onSelected: (value) => _regressionResult = value,
                ),
                _choices(
                  label: 'reproduction result',
                  keyPrefix: 'agentless-lab-reproduction',
                  options: const [
                    ('passed', 'passed'),
                    ('failed', 'failed'),
                    ('not_run', 'not run'),
                  ],
                  value: _reproductionResult,
                  onSelected: (value) => _reproductionResult = value,
                ),
                _choices(
                  label: '公式instance test result',
                  keyPrefix: 'agentless-lab-test',
                  options: const [
                    ('resolved', 'resolved'),
                    ('unresolved', 'unresolved'),
                    ('not_run', 'not run'),
                  ],
                  value: _testResult,
                  onSelected: (value) => _testResult = value,
                ),
                _choices(
                  label: '同じmanifest条件での再現性',
                  keyPrefix: 'agentless-lab-reproducibility',
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
                  keyPrefix: 'agentless-lab-workplace',
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
                    key: Key('agentless-lab-submitted'),
                  )
                else if (_submitting)
                  const LinearProgressIndicator()
                else
                  FilledButton.icon(
                    key: const Key('agentless-lab-submit'),
                    onPressed: _completion() == null ? null : _submit,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('匿名完了結果を送信'),
                  ),
              ],
            ],
          ),
        ),
      );
}
