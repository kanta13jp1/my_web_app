import 'package:flutter/material.dart';

typedef AiUniversityYiIntroductionTaskSubmit = Future<bool> Function({
  required int correctAnswers,
  required int firstAttemptCorrectAnswers,
  required int selfRating,
  required String nextOfficialPage,
});

class AiUniversityYiIntroductionTaskCard extends StatefulWidget {
  const AiUniversityYiIntroductionTaskCard({
    super.key,
    required this.onSubmit,
  });

  final AiUniversityYiIntroductionTaskSubmit onSubmit;

  @override
  State<AiUniversityYiIntroductionTaskCard> createState() =>
      _AiUniversityYiIntroductionTaskCardState();
}

class _IntroductionQuestion {
  const _IntroductionQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
}

class _AiUniversityYiIntroductionTaskCardState
    extends State<AiUniversityYiIntroductionTaskCard> {
  static const List<_IntroductionQuestion> _questions = [
    _IntroductionQuestion(
      prompt: '01.AIは4層マップのどの層ですか？',
      options: ['企業', 'Yiモデル群', '企業向け基盤', '意思決定製品群'],
      correctIndex: 0,
    ),
    _IntroductionQuestion(
      prompt: 'Yiは01.AIの何を指しますか？',
      options: ['企業名', '同社が訓練したモデル群', '販売管理製品', '投資判断製品'],
      correctIndex: 1,
    ),
    _IntroductionQuestion(
      prompt: 'WorldWiseとTrueNorthの区別として正しいものは？',
      options: [
        'WorldWiseは企業向けLLM基盤、TrueNorthは意思決定ハブと製品群',
        'WorldWiseはモデル名、TrueNorthは会社名',
        'どちらもYiのモデルサイズ名',
      ],
      correctIndex: 0,
    ),
  ];

  static const Map<String, String> _nextPages = {
    'yi_repository': 'Yiモデルの技術・公開状況（公式GitHub）',
    'worldwise_overview': 'WorldWise基盤の位置付け（01.AI公式）',
    'truenorth_product': 'TrueNorth製品の現行説明（01.AI公式）',
  };

  final List<int?> _answers = List<int?>.filled(_questions.length, null);
  final List<int?> _firstAnswers = List<int?>.filled(_questions.length, null);
  String? _nextOfficialPage;
  int? _selfRating;
  bool _submitting = false;
  bool _submitted = false;
  int? _correctAnswers;
  int? _firstAttemptCorrectAnswers;

  bool get _canSubmit =>
      !_submitting &&
      !_submitted &&
      _answers.every((answer) => answer != null) &&
      _nextOfficialPage != null &&
      _selfRating != null;

  void _selectAnswer(int questionIndex, int optionIndex) {
    if (_submitted) return;
    setState(() {
      _answers[questionIndex] = optionIndex;
      _firstAnswers[questionIndex] ??= optionIndex;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final correctAnswers = List<int>.generate(
      _questions.length,
      (index) => _answers[index] == _questions[index].correctIndex ? 1 : 0,
    ).fold<int>(0, (total, value) => total + value);
    final firstAttemptCorrectAnswers = List<int>.generate(
      _questions.length,
      (index) => _firstAnswers[index] == _questions[index].correctIndex ? 1 : 0,
    ).fold<int>(0, (total, value) => total + value);

    setState(() => _submitting = true);
    final accepted = await widget.onSubmit(
      correctAnswers: correctAnswers,
      firstAttemptCorrectAnswers: firstAttemptCorrectAnswers,
      selfRating: _selfRating!,
      nextOfficialPage: _nextOfficialPage!,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (accepted) {
        _submitted = true;
        _correctAnswers = correctAnswers;
        _firstAttemptCorrectAnswers = firstAttemptCorrectAnswers;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF26A69A).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_tree_outlined, color: Color(0xFF80CBC4)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '5分で会社・モデル・基盤・製品を分類',
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
            '最初の回答も匿名の正答数として集計します。回答本文、利用者ID、セッションIDは送信しません。',
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
                        key: Key('yi-intro-q$questionIndex-o$optionIndex'),
                        label: Text(question.options[optionIndex]),
                        selected: _answers[questionIndex] == optionIndex,
                        onSelected: _submitted
                            ? null
                            : (_) => _selectAnswer(questionIndex, optionIndex),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Text(
            'Yiモデルの技術詳細を次に調べる場合、どの公式ページを開きますか？',
            style: TextStyle(
              color: Color(0xFFE5E7EB),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _nextPages.entries
                .map(
                  (entry) => ChoiceChip(
                    key: Key('yi-intro-next-${entry.key}'),
                    label: Text(entry.value),
                    selected: _nextOfficialPage == entry.key,
                    onSelected: _submitted
                        ? null
                        : (_) => setState(() => _nextOfficialPage = entry.key),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            '4層の違いを説明できる度合い（1〜5）',
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
                key: Key('yi-intro-rating-$rating'),
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
              '送信済み: 最終 $_correctAnswers / 3、初回 $_firstAttemptCorrectAnswers / 3 問正解',
              key: const Key('yi-intro-submitted-result'),
              style: const TextStyle(
                color: Color(0xFF81C784),
                fontWeight: FontWeight.w700,
              ),
            )
          else if (_submitting)
            const LinearProgressIndicator()
          else
            FilledButton.icon(
              key: const Key('yi-intro-submit'),
              onPressed: _canSubmit ? _submit : null,
              icon: const Icon(Icons.send_outlined),
              label: const Text('匿名結果を送信'),
            ),
        ],
      ),
    );
  }
}
