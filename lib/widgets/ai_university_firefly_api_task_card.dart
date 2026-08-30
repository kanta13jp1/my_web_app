import 'package:flutter/material.dart';

typedef AiUniversityFireflyApiTaskSubmit = Future<bool> Function({
  required int correctAnswers,
  required int selfRating,
  required String learnerRole,
  required bool firstCallSucceeded,
  required bool secretHandlingPassed,
  required bool apiSelectionPassed,
  required bool non2xxRecoveryPassed,
  required int estimatedDailyRequests,
  required int completionSeconds,
});

class AiUniversityFireflyApiTaskCard extends StatefulWidget {
  const AiUniversityFireflyApiTaskCard({
    super.key,
    required this.onSubmit,
  });

  final AiUniversityFireflyApiTaskSubmit onSubmit;

  @override
  State<AiUniversityFireflyApiTaskCard> createState() =>
      _AiUniversityFireflyApiTaskCardState();
}

class _FireflyQuestion {
  const _FireflyQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
}

class _AiUniversityFireflyApiTaskCardState
    extends State<AiUniversityFireflyApiTaskCard> {
  static const List<_FireflyQuestion> _questions = [
    _FireflyQuestion(
      prompt: 'Client Secretを置く場所は？',
      options: [
        'Flutter/Web client',
        '安全なserver-side環境変数またはsecret manager',
        '公開リポジトリ',
      ],
      correctIndex: 1,
    ),
    _FireflyQuestion(
      prompt: '確認日時点のGenerate Image endpointは？',
      options: [
        '/v3/images/generate-async',
        '/v3/images/generate',
        '/v1/text-to-image',
      ],
      correctIndex: 0,
    ),
    _FireflyQuestion(
      prompt: 'HTTP 429を受けたときの安全な初動は？',
      options: [
        '即時に無制限再送する',
        'Retry-Afterまたは指数backoffを使い利用量を確認する',
        'access tokenをログへ出す',
      ],
      correctIndex: 1,
    ),
  ];

  static const Map<String, String> _roles = {
    'developer': '開発',
    'operations': '運用',
    'creator': '制作',
    'product_owner': '企画・責任者',
  };
  static const List<int> _dailyRequestChoices = [50, 500, 9000];

  final List<int?> _answers = List<int?>.filled(_questions.length, null);
  final DateTime _startedAt = DateTime.now();
  String? _learnerRole;
  bool? _firstCallSucceeded;
  bool _singleAndBatchCompleted = false;
  bool _productionChecklistCompleted = false;
  int? _estimatedDailyRequests;
  int? _selfRating;
  bool _submitting = false;
  bool _submitted = false;
  int? _correctAnswers;

  bool get _canSubmit =>
      !_submitting &&
      !_submitted &&
      _learnerRole != null &&
      _firstCallSucceeded != null &&
      _singleAndBatchCompleted &&
      _productionChecklistCompleted &&
      _estimatedDailyRequests != null &&
      _selfRating != null &&
      _answers.every((answer) => answer != null);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final correctAnswers = List<int>.generate(
      _questions.length,
      (index) => _answers[index] == _questions[index].correctIndex ? 1 : 0,
    ).fold<int>(0, (total, value) => total + value);
    final completionSeconds =
        DateTime.now().difference(_startedAt).inSeconds.clamp(1, 3600).toInt();

    setState(() => _submitting = true);
    final accepted = await widget.onSubmit(
      correctAnswers: correctAnswers,
      selfRating: _selfRating!,
      learnerRole: _learnerRole!,
      firstCallSucceeded: _firstCallSucceeded!,
      secretHandlingPassed: _answers[0] == _questions[0].correctIndex,
      apiSelectionPassed: _answers[1] == _questions[1].correctIndex,
      non2xxRecoveryPassed: _answers[2] == _questions[2].correctIndex,
      estimatedDailyRequests: _estimatedDailyRequests!,
      completionSeconds: completionSeconds,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF7043).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.security_outlined, color: Color(0xFFFF8A65)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Firefly API 安全運用ラボ',
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
            'secret、token、prompt、回答本文、利用者IDは送信しません。固定選択の達成指標だけを匿名集計します。',
            style: TextStyle(color: Color(0xFFB0B0B0), height: 1.6),
          ),
          const SizedBox(height: 14),
          const Text(
            'あなたの役割',
            style: TextStyle(
              color: Color(0xFFE5E7EB),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _roles.entries
                .map(
                  (entry) => ChoiceChip(
                    key: Key('firefly-role-${entry.key}'),
                    label: Text(entry.value),
                    selected: _learnerRole == entry.key,
                    onSelected: _submitted
                        ? null
                        : (_) => setState(() => _learnerRole = entry.key),
                  ),
                )
                .toList(),
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
                        key: Key('firefly-q$questionIndex-o$optionIndex'),
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
          const Text(
            '初回callの結果',
            style: TextStyle(
              color: Color(0xFFE5E7EB),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const Key('firefly-first-call-success'),
                label: const Text('成功'),
                selected: _firstCallSucceeded == true,
                onSelected: _submitted
                    ? null
                    : (_) => setState(() => _firstCallSucceeded = true),
              ),
              ChoiceChip(
                key: const Key('firefly-first-call-not-yet'),
                label: const Text('未成功'),
                selected: _firstCallSucceeded == false,
                onSelected: _submitted
                    ? null
                    : (_) => setState(() => _firstCallSucceeded = false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const Key('firefly-single-batch-completed'),
            contentPadding: EdgeInsets.zero,
            value: _singleAndBatchCompleted,
            onChanged: _submitted
                ? null
                : (value) => setState(
                      () => _singleAndBatchCompleted = value ?? false,
                    ),
            title: const Text(
              '1件requestと、上限内の複数件requestを実行した',
              style: TextStyle(color: Color(0xFFE5E7EB)),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            key: const Key('firefly-production-checklist-completed'),
            contentPadding: EdgeInsets.zero,
            value: _productionChecklistCompleted,
            onChanged: _submitted
                ? null
                : (value) => setState(
                      () => _productionChecklistCompleted = value ?? false,
                    ),
            title: const Text(
              'token更新、非2xx、secret除外ログ、usage budgetを確認した',
              style: TextStyle(color: Color(0xFFE5E7EB)),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          const Text(
            '想定する1日request数',
            style: TextStyle(
              color: Color(0xFFE5E7EB),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: _dailyRequestChoices
                .map(
                  (count) => ChoiceChip(
                    key: Key('firefly-daily-requests-$count'),
                    label: Text('$count /日'),
                    selected: _estimatedDailyRequests == count,
                    onSelected: _submitted
                        ? null
                        : (_) =>
                            setState(() => _estimatedDailyRequests = count),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            '安全に運用判断できる度合い（1〜5）',
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
                key: Key('firefly-rating-$rating'),
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
              key: const Key('firefly-submitted-result'),
              style: const TextStyle(
                color: Color(0xFF81C784),
                fontWeight: FontWeight.w700,
              ),
            )
          else if (_submitting)
            const LinearProgressIndicator()
          else
            FilledButton.icon(
              key: const Key('firefly-submit'),
              onPressed: _canSubmit ? _submit : null,
              icon: const Icon(Icons.send_outlined),
              label: const Text('匿名結果を送信'),
            ),
        ],
      ),
    );
  }
}
