import 'package:flutter/material.dart';

typedef AiUniversityLlmMechanicsTaskSubmit = Future<bool> Function({
  required int correctAnswers,
  required int selfRating,
});

class AiUniversityLlmMechanicsTaskCard extends StatefulWidget {
  const AiUniversityLlmMechanicsTaskCard({super.key, required this.onSubmit});

  final AiUniversityLlmMechanicsTaskSubmit onSubmit;

  @override
  State<AiUniversityLlmMechanicsTaskCard> createState() =>
      _AiUniversityLlmMechanicsTaskCardState();
}

class _AiUniversityLlmMechanicsTaskCardState
    extends State<AiUniversityLlmMechanicsTaskCard> {
  static const _questions = <(String, String)>[
    (
      'Self-Attentionで、文脈に応じて他tokenの情報を混ぜる流れは？',
      'QとKで重みを求めVを集約する|tokenを常に独立処理する|RNNだけで順番に処理する',
    ),
    (
      '原論文のTransformerを最も正確に説明するものは？',
      '再帰と畳み込みを使わずAttentionを中心に構成|Attentionを使わないCNN|単語頻度だけのモデル',
    ),
    (
      '創発的能力を評価するときに必要な注意は？',
      '指標選択で急な出現に見える可能性も検討する|閾値が見えれば原因は確定する|モデル規模だけを記録する',
    ),
  ];

  final _answers = List<int?>.filled(3, null);
  bool _mapCompleted = false;
  int? _selfRating;
  bool _submitting = false;
  bool _submitted = false;
  int? _score;

  bool get _canSubmit =>
      !_submitting &&
      !_submitted &&
      _mapCompleted &&
      _selfRating != null &&
      _answers.every((answer) => answer != null);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final score = _answers.where((answer) => answer == 0).length;
    setState(() => _submitting = true);
    final accepted = await widget.onSubmit(
      correctAnswers: score,
      selfRating: _selfRating!,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (accepted) {
        _submitted = true;
        _score = score;
      }
    });
    if (!accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('結果を送信できませんでした。時間をおいて再試行してください。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF0F1929),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('概念マップと測定論争チェック'),
              const SizedBox(height: 8),
              const Text('情報流と創発性の主張／反論を1枚に結んでください。図や回答本文は送信しません。'),
              const SizedBox(height: 12),
              ...List.generate(_questions.length, (questionIndex) {
                final (prompt, encodedOptions) = _questions[questionIndex];
                final options = encodedOptions.split('|');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${questionIndex + 1}. $prompt'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          options.length,
                          (optionIndex) => ChoiceChip(
                            key: Key('llm-q$questionIndex-o$optionIndex'),
                            label: Text(options[optionIndex]),
                            selected: _answers[questionIndex] == optionIndex,
                            onSelected: _submitted
                                ? null
                                : (_) => setState(
                                      () =>
                                          _answers[questionIndex] = optionIndex,
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              CheckboxListTile(
                key: const Key('llm-mechanics-map-completed'),
                contentPadding: EdgeInsets.zero,
                value: _mapCompleted,
                onChanged: _submitted
                    ? null
                    : (value) => setState(() => _mapCompleted = value ?? false),
                title: const Text('情報流・Transformer・創発性の両論を図示した'),
              ),
              const Text('3概念を説明できる度合い（1〜5）'),
              Wrap(
                spacing: 8,
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  return ChoiceChip(
                    key: Key('llm-mechanics-rating-$rating'),
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
                  '送信済み: $_score / 3 問正解',
                  key: const Key('llm-mechanics-submitted-result'),
                )
              else if (_submitting)
                const LinearProgressIndicator()
              else
                FilledButton.icon(
                  key: const Key('llm-mechanics-submit'),
                  onPressed: _canSubmit ? _submit : null,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('匿名結果を送信'),
                ),
            ],
          ),
        ),
      );
}
