import 'package:flutter/material.dart';

typedef AiUniversityFireflyLatestInfoTaskSubmit = Future<bool> Function({
  required int correctAnswers,
  required int selfRating,
  required String releaseFeature,
  required String outputKind,
  required int inputAssetCount,
  required int legacyWorkflowMinutes,
  required int latestWorkflowMinutes,
  required int revisionCount,
  required bool usableOutput,
  required bool workplaceApplicable,
  required String adoptionDecision,
});

class AiUniversityFireflyLatestInfoTaskCard extends StatefulWidget {
  const AiUniversityFireflyLatestInfoTaskCard({
    super.key,
    required this.onSubmit,
  });

  final AiUniversityFireflyLatestInfoTaskSubmit onSubmit;

  @override
  State<AiUniversityFireflyLatestInfoTaskCard> createState() =>
      _AiUniversityFireflyLatestInfoTaskCardState();
}

class _FireflyLatestQuestion {
  const _FireflyLatestQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
}

class _AiUniversityFireflyLatestInfoTaskCardState
    extends State<AiUniversityFireflyLatestInfoTaskCard> {
  static const List<_FireflyLatestQuestion> _questions = [
    _FireflyLatestQuestion(
      prompt: '公式What’s NewのAugust 2026で追加されたBetaは？',
      options: ['中央ワークスペースとInterfaces', 'Yi Cookbook', 'v1 API'],
      correctIndex: 0,
    ),
    _FireflyLatestQuestion(
      prompt: '新しい中央ワークスペースで一元化されるものは？',
      options: [
        '画像・動画の生成/編集、プロジェクト資産、動画タイムライン',
        '請求と税務だけ',
        'コード実行だけ',
      ],
      correctIndex: 0,
    ),
    _FireflyLatestQuestion(
      prompt: 'Interfacesが扱える入力アセットの上限は？',
      options: ['50', '500', '無制限'],
      correctIndex: 1,
    ),
  ];

  static const Map<String, String> _features = {
    'central_workspace': '中央ワークスペース',
    'interfaces_batch': 'Interfacesバッチ',
  };
  static const Map<String, String> _outputKinds = {
    'image': '画像',
    'video': '動画',
    'asset_batch': 'アセット一式',
  };
  static const Map<String, String> _adoptionDecisions = {
    'adopt': '採用',
    'pilot': '試験導入',
    'defer': '保留',
  };
  static const List<int> _assetCounts = [1, 10, 100, 500];
  static const List<int> _minuteChoices = [5, 15, 30, 60];
  static const List<int> _revisionChoices = [0, 1, 2, 3, 5];

  final List<int?> _answers = List<int?>.filled(_questions.length, null);
  String? _releaseFeature;
  String? _outputKind;
  int? _inputAssetCount;
  int? _legacyWorkflowMinutes;
  int? _latestWorkflowMinutes;
  int? _revisionCount;
  bool? _usableOutput;
  bool? _workplaceApplicable;
  String? _adoptionDecision;
  int? _selfRating;
  bool _comparisonDocumented = false;
  bool _submitting = false;
  bool _submitted = false;
  int? _correctAnswers;

  bool get _canSubmit =>
      !_submitting &&
      !_submitted &&
      _releaseFeature != null &&
      _outputKind != null &&
      _inputAssetCount != null &&
      _legacyWorkflowMinutes != null &&
      _latestWorkflowMinutes != null &&
      _revisionCount != null &&
      _usableOutput != null &&
      _workplaceApplicable != null &&
      _adoptionDecision != null &&
      _selfRating != null &&
      _comparisonDocumented &&
      _answers.every((answer) => answer != null);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final correctAnswers = List<int>.generate(
      _questions.length,
      (index) => _answers[index] == _questions[index].correctIndex ? 1 : 0,
    ).fold<int>(0, (total, value) => total + value);

    setState(() => _submitting = true);
    final accepted = await widget.onSubmit(
      correctAnswers: correctAnswers,
      selfRating: _selfRating!,
      releaseFeature: _releaseFeature!,
      outputKind: _outputKind!,
      inputAssetCount: _inputAssetCount!,
      legacyWorkflowMinutes: _legacyWorkflowMinutes!,
      latestWorkflowMinutes: _latestWorkflowMinutes!,
      revisionCount: _revisionCount!,
      usableOutput: _usableOutput!,
      workplaceApplicable: _workplaceApplicable!,
      adoptionDecision: _adoptionDecision!,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (accepted) {
        _submitted = true;
        _correctAnswers = correctAnswers;
      }
    });
    if (!accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('結果を送信できませんでした。時間をおいて再試行してください。'),
        ),
      );
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFE5E7EB),
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _booleanChoices({
    required String keyPrefix,
    required bool? value,
    required ValueChanged<bool> onChanged,
  }) =>
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            key: Key('$keyPrefix-yes'),
            label: const Text('はい'),
            selected: value == true,
            onSelected: _submitted ? null : (_) => onChanged(true),
          ),
          ChoiceChip(
            key: Key('$keyPrefix-no'),
            label: const Text('いいえ'),
            selected: value == false,
            onSelected: _submitted ? null : (_) => onChanged(false),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE65100).withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_arrows, color: Color(0xFFFFB74D)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Firefly最新機能 30分workflow比較',
                  style: TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '同じ入力で旧workflowと新機能を比較し、入力・出力・時間・修正回数・採用基準を手元に記録してください。本文、入力素材、出力、利用者IDは送信しません。',
            style: TextStyle(color: Color(0xFFB0B0B0), height: 1.6),
          ),
          const SizedBox(height: 14),
          ...List<Widget>.generate(_questions.length, (questionIndex) {
            final question = _questions[questionIndex];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${questionIndex + 1}. ${question.prompt}',
                    style: const TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List<Widget>.generate(
                      question.options.length,
                      (optionIndex) => ChoiceChip(
                        key: Key(
                          'firefly-latest-q$questionIndex-o$optionIndex',
                        ),
                        label: Text(question.options[optionIndex]),
                        selected: _answers[questionIndex] == optionIndex,
                        onSelected: _submitted
                            ? null
                            : (_) => setState(
                                  () => _answers[questionIndex] = optionIndex,
                                ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          _label('比較するAugust 2026機能'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _features.entries
                .map(
                  (entry) => ChoiceChip(
                    key: Key('firefly-latest-feature-${entry.key}'),
                    label: Text(entry.value),
                    selected: _releaseFeature == entry.key,
                    onSelected: _submitted
                        ? null
                        : (_) => setState(() => _releaseFeature = entry.key),
                  ),
                )
                .toList(),
          ),
          _label('比較する出力'),
          Wrap(
            spacing: 8,
            children: _outputKinds.entries
                .map(
                  (entry) => ChoiceChip(
                    key: Key('firefly-latest-output-${entry.key}'),
                    label: Text(entry.value),
                    selected: _outputKind == entry.key,
                    onSelected: _submitted
                        ? null
                        : (_) => setState(() => _outputKind = entry.key),
                  ),
                )
                .toList(),
          ),
          _label('入力アセット数'),
          Wrap(
            spacing: 8,
            children: _assetCounts
                .map(
                  (count) => ChoiceChip(
                    key: Key('firefly-latest-assets-$count'),
                    label: Text('$count'),
                    selected: _inputAssetCount == count,
                    onSelected: _submitted
                        ? null
                        : (_) => setState(() => _inputAssetCount = count),
                  ),
                )
                .toList(),
          ),
          _label('旧workflowの所要時間'),
          Wrap(
            spacing: 8,
            children: _minuteChoices
                .map(
                  (minutes) => ChoiceChip(
                    key: Key('firefly-latest-legacy-$minutes'),
                    label: Text('$minutes分'),
                    selected: _legacyWorkflowMinutes == minutes,
                    onSelected: _submitted
                        ? null
                        : (_) => setState(
                              () => _legacyWorkflowMinutes = minutes,
                            ),
                  ),
                )
                .toList(),
          ),
          _label('新workflowの所要時間'),
          Wrap(
            spacing: 8,
            children: _minuteChoices
                .map(
                  (minutes) => ChoiceChip(
                    key: Key('firefly-latest-new-$minutes'),
                    label: Text('$minutes分'),
                    selected: _latestWorkflowMinutes == minutes,
                    onSelected: _submitted
                        ? null
                        : (_) => setState(
                              () => _latestWorkflowMinutes = minutes,
                            ),
                  ),
                )
                .toList(),
          ),
          _label('新workflowでの修正回数'),
          Wrap(
            spacing: 8,
            children: _revisionChoices
                .map(
                  (count) => ChoiceChip(
                    key: Key('firefly-latest-revisions-$count'),
                    label: Text('$count回'),
                    selected: _revisionCount == count,
                    onSelected: _submitted
                        ? null
                        : (_) => setState(() => _revisionCount = count),
                  ),
                )
                .toList(),
          ),
          _label('新workflowの出力はそのまま利用可能だった'),
          _booleanChoices(
            keyPrefix: 'firefly-latest-usable',
            value: _usableOutput,
            onChanged: (value) => setState(() => _usableOutput = value),
          ),
          _label('職場・実案件へ適用できる'),
          _booleanChoices(
            keyPrefix: 'firefly-latest-workplace',
            value: _workplaceApplicable,
            onChanged: (value) => setState(() => _workplaceApplicable = value),
          ),
          _label('採用判断'),
          Wrap(
            spacing: 8,
            children: _adoptionDecisions.entries
                .map(
                  (entry) => ChoiceChip(
                    key: Key('firefly-latest-adoption-${entry.key}'),
                    label: Text(entry.value),
                    selected: _adoptionDecision == entry.key,
                    onSelected: _submitted
                        ? null
                        : (_) => setState(() => _adoptionDecision = entry.key),
                  ),
                )
                .toList(),
          ),
          CheckboxListTile(
            key: const Key('firefly-latest-comparison-documented'),
            contentPadding: EdgeInsets.zero,
            value: _comparisonDocumented,
            onChanged: _submitted
                ? null
                : (value) => setState(
                      () => _comparisonDocumented = value ?? false,
                    ),
            title: const Text(
              '入力・出力・旧手順・新手順・採用基準を手元に記録した',
              style: TextStyle(color: Color(0xFFE5E7EB)),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          _label('新機能を説明・判断できる度合い（1〜5）'),
          Wrap(
            spacing: 8,
            children: List<Widget>.generate(5, (index) {
              final rating = index + 1;
              return ChoiceChip(
                key: Key('firefly-latest-rating-$rating'),
                label: Text('$rating'),
                selected: _selfRating == rating,
                onSelected: _submitted
                    ? null
                    : (_) => setState(() => _selfRating = rating),
              );
            }),
          ),
          const SizedBox(height: 14),
          if (_submitted)
            Text(
              '送信済み: $_correctAnswers / ${_questions.length} 問正解',
              key: const Key('firefly-latest-submitted-result'),
              style: const TextStyle(
                color: Color(0xFF81C784),
                fontWeight: FontWeight.w700,
              ),
            )
          else if (_submitting)
            const LinearProgressIndicator()
          else
            FilledButton.icon(
              key: const Key('firefly-latest-submit'),
              onPressed: _canSubmit ? _submit : null,
              icon: const Icon(Icons.send_outlined),
              label: const Text('匿名比較結果を送信'),
            ),
        ],
      ),
    );
  }
}
