import 'package:flutter/material.dart';

typedef AiUniversityModelSelectionTaskSubmit = Future<bool> Function({
  required int correctAnswers,
  required int selfRating,
});

class AiUniversityModelSelectionTaskCard extends StatefulWidget {
  const AiUniversityModelSelectionTaskCard({super.key, required this.onSubmit});

  final AiUniversityModelSelectionTaskSubmit onSubmit;

  @override
  State<AiUniversityModelSelectionTaskCard> createState() =>
      _AiUniversityModelSelectionTaskCardState();
}

class _ModelSelectionQuestion {
  const _ModelSelectionQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
}

class _AiUniversityModelSelectionTaskCardState
    extends State<AiUniversityModelSelectionTaskCard> {
  static const List<_ModelSelectionQuestion> _questions = [
    _ModelSelectionQuestion(
      prompt: '3K以内の短い文章処理で、料金を最優先する場合は？',
      options: ['yi-large-turbo', 'yi-large', 'yi-vision'],
      correctIndex: 0,
    ),
    _ModelSelectionQuestion(
      prompt: '20Kの文書を使う複雑な推論には？',
      options: ['yi-large-turbo', 'yi-large', 'yi-vision'],
      correctIndex: 1,
    ),
    _ModelSelectionQuestion(
      prompt: '10K以内の図表をOCRして説明する用途には？',
      options: ['yi-large-turbo', 'yi-large', 'yi-vision'],
      correctIndex: 2,
    ),
  ];

  final List<int?> _answers = List<int?>.filled(_questions.length, null);
  bool _comparisonCompleted = false;
  int? _selfRating;
  bool _submitting = false;
  bool _submitted = false;
  int? _correctAnswers;

  bool get _canSubmit =>
      !_submitting &&
      !_submitted &&
      _comparisonCompleted &&
      _selfRating != null &&
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
        const SnackBar(content: Text('結果を送信できませんでした。時間をおいて再試行してください。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF7E57C2).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_arrows, color: Color(0xFFB39DDB)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '用途・予算・文脈長でモデルを選ぶ',
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
            '公式モデル表を確認し、3つの条件に合うモデルを選んでください。回答本文や個人情報は送信しません。',
            style: TextStyle(color: Color(0xFFB0B0B0), height: 1.6),
          ),
          const SizedBox(height: 12),
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
                          'model-selection-q$questionIndex-o$optionIndex',
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
          CheckboxListTile(
            key: const Key('model-selection-comparison-completed'),
            contentPadding: EdgeInsets.zero,
            value: _comparisonCompleted,
            onChanged: _submitted
                ? null
                : (value) =>
                    setState(() => _comparisonCompleted = value ?? false),
            title: const Text(
              '用途・予算・文脈長の比較メモを作成した',
              style: TextStyle(color: Color(0xFFE5E7EB)),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          const Text(
            '選定理由を自分で説明できる度合い（1〜5）',
            style: TextStyle(
              color: Color(0xFFE5E7EB),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: List<Widget>.generate(5, (index) {
              final rating = index + 1;
              return ChoiceChip(
                key: Key('model-selection-rating-$rating'),
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
              key: const Key('model-selection-submitted-result'),
              style: const TextStyle(
                color: Color(0xFF81C784),
                fontWeight: FontWeight.w700,
              ),
            )
          else if (_submitting)
            const LinearProgressIndicator()
          else
            FilledButton.icon(
              key: const Key('model-selection-submit'),
              onPressed: _canSubmit ? _submit : null,
              icon: const Icon(Icons.send_outlined),
              label: const Text('匿名結果を送信'),
            ),
        ],
      ),
    );
  }
}
