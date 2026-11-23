enum SelfBurnoutRiskLevel { low, caution, high }

class SelfMentalHealthCheck {
  static const List<String> moodEmojis = <String>[
    '😣',
    '😕',
    '😐',
    '🙂',
    '😄',
  ];

  static const List<String> moodLabels = <String>[
    'かなりつらい',
    '少し落ち込み',
    'ふつう',
    '良好',
    'とても良好',
  ];

  static const List<String> fatigueEmojis = <String>[
    '🔋',
    '😌',
    '😮‍💨',
    '😫',
    '🪫',
  ];

  static const List<String> fatigueLabels = <String>[
    '元気十分',
    '軽い疲れ',
    'やや疲労',
    '強い疲労',
    '限界に近い',
  ];

  final String dateKey;
  final int moodScore;
  final int fatigueScore;
  final String note;
  final DateTime recordedAt;
  final bool syncedToCloud;

  const SelfMentalHealthCheck({
    required this.dateKey,
    required this.moodScore,
    required this.fatigueScore,
    this.note = '',
    required this.recordedAt,
    this.syncedToCloud = false,
  });

  String get moodEmoji => moodEmojis[clampScore(moodScore) - 1];
  String get moodLabel => moodLabels[clampScore(moodScore) - 1];
  String get fatigueEmoji => fatigueEmojis[clampScore(fatigueScore) - 1];
  String get fatigueLabel => fatigueLabels[clampScore(fatigueScore) - 1];

  bool get isHighStrain =>
      clampScore(fatigueScore) >= 4 || clampScore(moodScore) <= 2;

  static int clampScore(int score) {
    if (score < 1) return 1;
    if (score > 5) return 5;
    return score;
  }

  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'date_key': dateKey,
      'mood_score': clampScore(moodScore),
      'fatigue_score': clampScore(fatigueScore),
      'note': note,
      'recorded_at': recordedAt.toIso8601String(),
      'synced_to_cloud': syncedToCloud,
    };
  }

  factory SelfMentalHealthCheck.fromJson(Map<String, dynamic> json) {
    final recorded = DateTime.tryParse(json['recorded_at']?.toString() ?? '') ??
        DateTime.now();
    final key = json['date_key']?.toString().trim() ?? '';
    return SelfMentalHealthCheck(
      dateKey: key.isEmpty ? formatDateKey(recorded) : key,
      moodScore: clampScore((json['mood_score'] as num?)?.toInt() ?? 3),
      fatigueScore: clampScore((json['fatigue_score'] as num?)?.toInt() ?? 3),
      note: json['note']?.toString() ?? '',
      recordedAt: recorded,
      syncedToCloud: json['synced_to_cloud'] == true,
    );
  }
}

class SelfBurnoutRiskReport {
  static const String defaultNeutralNotice =
      '本アラートは一般的なセルフケアの目安であり、医療上の診断・助言ではありません。不調が続く場合は専門家へご相談ください。';

  final int windowDays;
  final int entryCount;
  final double averageMood;
  final double averageFatigue;
  final int lowMoodDays;
  final int highFatigueDays;
  final int consecutiveHighStrainDays;
  final SelfBurnoutRiskLevel level;
  final String headline;
  final List<String> suggestions;
  final String neutralNotice;

  const SelfBurnoutRiskReport({
    required this.windowDays,
    required this.entryCount,
    required this.averageMood,
    required this.averageFatigue,
    required this.lowMoodDays,
    required this.highFatigueDays,
    required this.consecutiveHighStrainDays,
    required this.level,
    required this.headline,
    required this.suggestions,
    this.neutralNotice = defaultNeutralNotice,
  });

  bool get hasAlert => level != SelfBurnoutRiskLevel.low;
}
