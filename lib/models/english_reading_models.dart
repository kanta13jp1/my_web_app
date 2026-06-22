import 'package:flutter/material.dart';

/// AI大学「英語速読カリキュラム」のドメインモデル。
///
/// すべて純粋なデータ + 変換ロジックのみで Supabase に依存しない。WPM / 実効 WPM /
/// レベル推定などの算出ロジックは [EnglishReadingMetrics]
/// (lib/services/english_reading_ability.dart) 側にまとめる。

/// ネイティブ成人の黙読速度の基準値 (実効 WPM ゲージの満点 = 到達ゴール)。
const int kNativeReadingWpm = 300;

/// 英文を空白区切りで数えた語数を返す純関数 (WPM 計算の分母)。
///
/// 改行・連続空白を 1 区切りに正規化する。空文字は 0。
int countEnglishWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}

/// CEFR × 目標 WPM のレベル階梯メタ。
@immutable
class EnglishReadingLevel {
  const EnglishReadingLevel({
    required this.level,
    required this.cefr,
    required this.labelJa,
    required this.targetWpm,
    required this.emoji,
    required this.color,
  });

  final int level;
  final String cefr;
  final String labelJa;
  final int targetWpm;
  final String emoji;
  final Color color;
}

/// 6 段階のレベル階梯 (A2 100WPM → C2 300WPM = ネイティブ速度)。
const List<EnglishReadingLevel> kEnglishReadingLevels = <EnglishReadingLevel>[
  EnglishReadingLevel(
    level: 1,
    cefr: 'A2',
    labelJa: '基礎',
    targetWpm: 100,
    emoji: '🌱',
    color: Color(0xFF4CAF50),
  ),
  EnglishReadingLevel(
    level: 2,
    cefr: 'B1',
    labelJa: '初級',
    targetWpm: 150,
    emoji: '📗',
    color: Color(0xFF66BB6A),
  ),
  EnglishReadingLevel(
    level: 3,
    cefr: 'B1+',
    labelJa: '中級',
    targetWpm: 180,
    emoji: '📘',
    color: Color(0xFF29B6F6),
  ),
  EnglishReadingLevel(
    level: 4,
    cefr: 'B2',
    labelJa: '中上級',
    targetWpm: 220,
    emoji: '📙',
    color: Color(0xFF3D5AFE),
  ),
  EnglishReadingLevel(
    level: 5,
    cefr: 'C1',
    labelJa: '上級',
    targetWpm: 260,
    emoji: '🚀',
    color: Color(0xFFFF8C5A),
  ),
  EnglishReadingLevel(
    level: 6,
    cefr: 'C2',
    labelJa: 'ネイティブ速度',
    targetWpm: 300,
    emoji: '🏆',
    color: Color(0xFFFF6B35),
  ),
];

/// 指定 level のメタを返す。範囲外は最も近い端へフォールバック。
EnglishReadingLevel englishReadingLevelOf(int level) {
  for (final l in kEnglishReadingLevels) {
    if (l.level == level) return l;
  }
  if (level < kEnglishReadingLevels.first.level) {
    return kEnglishReadingLevels.first;
  }
  return kEnglishReadingLevels.last;
}

/// 内容理解クイズ 1 問。
@immutable
class EnglishReadingQuestion {
  const EnglishReadingQuestion({
    required this.question,
    required this.choices,
    required this.answerIndex,
    this.explanation = '',
  });

  final String question;
  final List<String> choices;
  final int answerIndex;
  final String explanation;

  factory EnglishReadingQuestion.fromJson(Map<String, dynamic> json) {
    final rawChoices = json['choices'];
    final choices = rawChoices is List
        ? rawChoices.map((e) => e?.toString() ?? '').toList()
        : <String>[];
    final rawIndex = (json['answer_index'] as num?)?.toInt() ?? 0;
    final answerIndex =
        choices.isEmpty ? 0 : rawIndex.clamp(0, choices.length - 1);
    return EnglishReadingQuestion(
      question: json['q']?.toString() ?? json['question']?.toString() ?? '',
      choices: choices,
      answerIndex: answerIndex,
      explanation: json['explanation']?.toString() ?? '',
    );
  }
}

/// 速読教材 1 本。
@immutable
class EnglishReadingLesson {
  const EnglishReadingLesson({
    required this.id,
    required this.lessonCode,
    required this.level,
    required this.cefr,
    required this.title,
    required this.topic,
    required this.targetWpm,
    required this.passage,
    required this.declaredWordCount,
    required this.questions,
    required this.source,
  });

  final String id;
  final String lessonCode;
  final int level;
  final String cefr;
  final String title;
  final String topic;
  final int targetWpm;
  final String passage;
  final int declaredWordCount;
  final List<EnglishReadingQuestion> questions;
  final String source;

  /// WPM 計算に使う正準語数。本文から実数えし、空なら宣言値へフォールバック。
  int get wordCount {
    final counted = countEnglishWords(passage);
    return counted > 0 ? counted : declaredWordCount;
  }

  bool get isAiGenerated => source == 'ai';

  /// 目標 WPM でこの本文を読み切るのにかかる秒数 (目安表示用)。
  int get targetSeconds {
    if (targetWpm <= 0) return 0;
    return ((wordCount / targetWpm) * 60).round();
  }

  factory EnglishReadingLesson.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'];
    final questions = rawQuestions is List
        ? rawQuestions
            .whereType<Map>()
            .map(
              (e) => EnglishReadingQuestion.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList()
        : <EnglishReadingQuestion>[];
    return EnglishReadingLesson(
      id: json['id']?.toString() ?? '',
      lessonCode: json['lesson_code']?.toString() ?? '',
      level: (json['level'] as num?)?.toInt() ?? 1,
      cefr: json['cefr']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      targetWpm: (json['target_wpm'] as num?)?.toInt() ?? 0,
      passage: json['passage']?.toString() ?? '',
      declaredWordCount: (json['word_count'] as num?)?.toInt() ?? 0,
      questions: questions,
      source: json['source']?.toString() ?? 'seed',
    );
  }
}

/// ユーザーの 1 回の読書試行 (= 実力測定ログ)。
@immutable
class EnglishReadingAttempt {
  const EnglishReadingAttempt({
    required this.id,
    required this.lessonCode,
    required this.level,
    required this.mode,
    required this.wordCount,
    required this.elapsedMs,
    required this.wpm,
    required this.comprehensionCorrect,
    required this.comprehensionTotal,
    required this.effectiveWpm,
    required this.createdAt,
  });

  final String id;
  final String lessonCode;
  final int level;

  /// 'measure' (自己ペース計測) | 'rsvp' (高速逐次提示トレーナー)。
  final String mode;
  final int wordCount;
  final int elapsedMs;
  final int wpm;
  final int comprehensionCorrect;
  final int comprehensionTotal;
  final int effectiveWpm;
  final DateTime createdAt;

  /// 理解率 0.0〜1.0。クイズ未回答 (total=0) は 0。
  double get comprehensionRatio =>
      comprehensionTotal == 0 ? 0 : comprehensionCorrect / comprehensionTotal;

  factory EnglishReadingAttempt.fromJson(Map<String, dynamic> json) {
    DateTime parseTime(Object? v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      try {
        return DateTime.parse(v.toString()).toLocal();
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    return EnglishReadingAttempt(
      id: json['id']?.toString() ?? '',
      lessonCode: json['lesson_code']?.toString() ?? '',
      level: (json['level'] as num?)?.toInt() ?? 1,
      mode: json['mode']?.toString() ?? 'measure',
      wordCount: (json['word_count'] as num?)?.toInt() ?? 0,
      elapsedMs: (json['elapsed_ms'] as num?)?.toInt() ?? 0,
      wpm: (json['wpm'] as num?)?.toInt() ?? 0,
      comprehensionCorrect:
          (json['comprehension_correct'] as num?)?.toInt() ?? 0,
      comprehensionTotal: (json['comprehension_total'] as num?)?.toInt() ?? 0,
      effectiveWpm: (json['effective_wpm'] as num?)?.toInt() ?? 0,
      createdAt: parseTime(json['created_at']),
    );
  }
}
