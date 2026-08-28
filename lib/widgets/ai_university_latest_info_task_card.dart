import 'package:flutter/material.dart';

typedef AiUniversityLatestInfoTaskSubmit = Future<bool> Function({
  required int correctAnswers,
  required int selfRating,
});

class AiUniversityLatestInfoTaskCard extends StatefulWidget {
  const AiUniversityLatestInfoTaskCard({super.key, required this.onSubmit});

  final AiUniversityLatestInfoTaskSubmit onSubmit;

  @override
  State<AiUniversityLatestInfoTaskCard> createState() =>
      _AiUniversityLatestInfoTaskCardState();
}

class _AiUniversityLatestInfoQuestion {
  const _AiUniversityLatestInfoQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
}

class _AiUniversityLatestInfoTaskCardState
    extends State<AiUniversityLatestInfoTaskCard> {
  static const List<_AiUniversityLatestInfoQuestion> _questions = [
    _AiUniversityLatestInfoQuestion(
      prompt: '公式会社沿革で2026年7月に公開されたものは？',
      options: ['TrueNorth', 'Yi-34B', 'Yi Cookbook 1.0'],
      correctIndex: 0,
    ),
    _AiUniversityLatestInfoQuestion(
      prompt: '2026年1月のWorldWise更新として記録されているものは？',
      options: ['2.5と企業向けマルチエージェント', '200K文脈', '画像生成API'],
      correctIndex: 0,
    ),
    _AiUniversityLatestInfoQuestion(
      prompt: '旧版から、現在の一次情報なしに引き継がないものは？',
      options: ['価格・性能比較や出典のない採用状況', '確認日', '公式リンク'],
      correctIndex: 0,
    ),
  ];

  final List<int?> _answers = List<int?>.filled(_questions.length, null);
  bool _summaryCompleted = false;
  int? _selfRating;
  bool _submitting = false;
  bool _submitted = false;
  int? _correctAnswers;

  bool get _canSubmit =>
      !_submitting &&
      !_submitted &&
      _summaryCompleted &&
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
          color: const Color(0xFF1A73E8).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: Color(0xFF64B5F6)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '確認日付き3点要約・差分チェック',
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
            '一次情報を開き、確認日付きの3点要約と旧版との差分を手元に作成してください。入力本文や個人情報は送信しません。',
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
                    children: List<Widget>.generate(question.options.length,
                        (optionIndex) {
                      return ChoiceChip(
                        key: Key('latest-info-q$questionIndex-o$optionIndex'),
                        label: Text(question.options[optionIndex]),
                        selected: _answers[questionIndex] == optionIndex,
                        onSelected: _submitted
                            ? null
                            : (_) => setState(
                                  () => _answers[questionIndex] = optionIndex,
                                ),
                      );
                    }),
                  ),
                ],
              ),
            );
          }),
          CheckboxListTile(
            key: const Key('latest-info-summary-completed'),
            contentPadding: EdgeInsets.zero,
            value: _summaryCompleted,
            onChanged: _submitted
                ? null
                : (value) => setState(() => _summaryCompleted = value ?? false),
            title: const Text(
              '3点要約と旧版との差分を作成した',
              style: TextStyle(color: Color(0xFFE5E7EB)),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          const Text(
            '自分で説明できる度合い（1〜5）',
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
                key: Key('latest-info-rating-$rating'),
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
              key: const Key('latest-info-submitted-result'),
              style: const TextStyle(
                color: Color(0xFF81C784),
                fontWeight: FontWeight.w700,
              ),
            )
          else if (_submitting)
            const LinearProgressIndicator()
          else
            FilledButton.icon(
              key: const Key('latest-info-submit'),
              onPressed: _canSubmit ? _submit : null,
              icon: const Icon(Icons.send_outlined),
              label: const Text('匿名結果を送信'),
            ),
        ],
      ),
    );
  }
}
