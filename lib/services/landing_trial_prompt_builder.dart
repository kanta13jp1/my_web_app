class LandingTrialDeepDiveQuestion {
  const LandingTrialDeepDiveQuestion({
    required this.label,
    required this.question,
    required this.hint,
    required this.quickAnswer,
  });

  final String label;
  final String question;
  final String hint;
  final String quickAnswer;
}

const landingTrialDeepDiveQuestions = <LandingTrialDeepDiveQuestion>[
  LandingTrialDeepDiveQuestion(
    label: '目標',
    question: 'どうなれば「少し前に進んだ」と言えますか？',
    hint: '例: 次に連絡する相手と内容が決まっている',
    quickAnswer: 'まず動き出せればよい',
  ),
  LandingTrialDeepDiveQuestion(
    label: '期限',
    question: 'いつまでに、どの程度まで進めたいですか？',
    hint: '例: 今日中に、最初の一歩だけ終えたい',
    quickAnswer: '今日中に一歩進めたい',
  ),
  LandingTrialDeepDiveQuestion(
    label: '条件',
    question: '使える時間・予算・守る条件はありますか？',
    hint: '例: 10分以内、追加費用なし、1人でできる範囲',
    quickAnswer: '10分以内・追加費用なし',
  ),
  LandingTrialDeepDiveQuestion(
    label: '試行',
    question: 'すでに試したことや、分かっていることは？',
    hint: '例: 一覧にはしたが、優先順位を決められなかった',
    quickAnswer: 'まだ何も試していない',
  ),
  LandingTrialDeepDiveQuestion(
    label: '回避',
    question: '今回の提案で避けたいことはありますか？',
    hint: '例: 大きな設定変更、誰かへの長い説明',
    quickAnswer: '大きな変更は避けたい',
  ),
];

class LandingTrialPromptBuilder {
  const LandingTrialPromptBuilder._();

  static const int maxPromptLength = 280;
  static const List<int> _fieldLimits = <int>[72, 34, 30, 34, 34, 32];

  static String build({
    required String concern,
    required List<String> answers,
  }) {
    if (answers.length != landingTrialDeepDiveQuestions.length) {
      throw ArgumentError.value(
        answers.length,
        'answers',
        '${landingTrialDeepDiveQuestions.length}件の回答が必要です。',
      );
    }

    final fields = <({String label, String value})>[
      (label: '相談', value: concern),
      for (var index = 0; index < landingTrialDeepDiveQuestions.length; index++)
        (
          label: landingTrialDeepDiveQuestions[index].label,
          value: answers[index],
        ),
    ];

    final normalizedFields = <({String label, String value})>[
      for (final field in fields)
        (label: field.label, value: _normalize(field.value)),
    ];
    final fullPrompt = _serialize(normalizedFields);
    if (_runeLength(fullPrompt) <= maxPromptLength) return fullPrompt;

    final prompt = _serialize(<({String label, String value})>[
      for (var index = 0; index < normalizedFields.length; index++)
        (
          label: normalizedFields[index].label,
          value: _truncate(
            normalizedFields[index].value,
            _fieldLimits[index],
          ),
        ),
    ]);

    if (_runeLength(prompt) > maxPromptLength) {
      throw StateError('生成したプロンプトが上限を超えました。');
    }
    return prompt;
  }

  static String _serialize(List<({String label, String value})> fields) {
    return <String>[
      for (final field in fields) '${field.label}:${field.value}',
    ].join('\n');
  }

  static String _normalize(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _truncate(String value, int maxLength) {
    final runes = value.runes.toList(growable: false);
    if (runes.length <= maxLength) return value;
    return '${String.fromCharCodes(runes.take(maxLength - 1))}…';
  }

  static int _runeLength(String value) => value.runes.length;
}
