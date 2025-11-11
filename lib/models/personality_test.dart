// 性格診断機能のモデルクラス

import 'package:flutter/foundation.dart';

/// 性格診断のステータス
enum PersonalityTestStatus {
  running, // 実行中
  paused, // 一時停止
  completed, // 完了
  stopped, // 停止
}

/// 性格診断テスト
class PersonalityTest {
  final int id;
  final String userId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? personalityType; // INTJ, INFP, etc.
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  PersonalityTest({
    required this.id,
    required this.userId,
    required this.startedAt,
    this.completedAt,
    this.personalityType,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PersonalityTest.fromJson(Map<String, dynamic> json) {
    return PersonalityTest(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      personalityType: json['personality_type'] as String?,
      isCompleted: json['is_completed'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'personality_type': personalityType,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PersonalityTest copyWith({
    int? id,
    String? userId,
    DateTime? startedAt,
    DateTime? completedAt,
    String? personalityType,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonalityTest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      personalityType: personalityType ?? this.personalityType,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 性格診断の質問
class PersonalityQuestion {
  final int id;
  final String text;
  final String axis; // E/I, N/S, T/F, J/P, A/T
  final String direction; // A or B
  final String optionA;
  final String optionB;
  final int orderNum;

  PersonalityQuestion({
    required this.id,
    required this.text,
    required this.axis,
    required this.direction,
    required this.optionA,
    required this.optionB,
    required this.orderNum,
  });

  factory PersonalityQuestion.fromJson(Map<String, dynamic> json) {
    return PersonalityQuestion(
      id: json['id'] as int,
      text: json['text'] as String,
      axis: json['axis'] as String,
      direction: json['direction'] as String,
      optionA: json['option_a'] as String,
      optionB: json['option_b'] as String,
      orderNum: json['order_num'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'axis': axis,
      'direction': direction,
      'option_a': optionA,
      'option_b': optionB,
      'order_num': orderNum,
    };
  }
}

/// 性格診断の回答
class PersonalityAnswer {
  final int id;
  final int testId;
  final int questionId;
  final String answer; // A or B
  final DateTime answeredAt;

  PersonalityAnswer({
    required this.id,
    required this.testId,
    required this.questionId,
    required this.answer,
    required this.answeredAt,
  });

  factory PersonalityAnswer.fromJson(Map<String, dynamic> json) {
    return PersonalityAnswer(
      id: json['id'] as int,
      testId: json['test_id'] as int,
      questionId: json['question_id'] as int,
      answer: json['answer'] as String,
      answeredAt: DateTime.parse(json['answered_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'test_id': testId,
      'question_id': questionId,
      'answer': answer,
      'answered_at': answeredAt.toIso8601String(),
    };
  }
}

/// 性格診断のスコア
class PersonalityScore {
  final int id;
  final int testId;
  final String axis; // E/I, N/S, T/F, J/P, A/T
  final int score; // -100 to 100

  PersonalityScore({
    required this.id,
    required this.testId,
    required this.axis,
    required this.score,
  });

  factory PersonalityScore.fromJson(Map<String, dynamic> json) {
    return PersonalityScore(
      id: json['id'] as int,
      testId: json['test_id'] as int,
      axis: json['axis'] as String,
      score: json['score'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'test_id': testId,
      'axis': axis,
      'score': score,
    };
  }
}

/// 性格タイプ（16タイプ）
class PersonalityType {
  final String code; // INTJ, INFP, etc.
  final String nameJa;
  final String nameEn;
  final String description;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> noteAdvice;
  final String iconUrl;

  PersonalityType({
    required this.code,
    required this.nameJa,
    required this.nameEn,
    required this.description,
    required this.strengths,
    required this.weaknesses,
    required this.noteAdvice,
    required this.iconUrl,
  });

  factory PersonalityType.fromJson(Map<String, dynamic> json) {
    return PersonalityType(
      code: json['code'] as String,
      nameJa: json['name_ja'] as String,
      nameEn: json['name_en'] as String,
      description: json['description'] as String,
      strengths: (json['strengths'] as List).cast<String>(),
      weaknesses: (json['weaknesses'] as List).cast<String>(),
      noteAdvice: (json['note_advice'] as List).cast<String>(),
      iconUrl: json['icon_url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name_ja': nameJa,
      'name_en': nameEn,
      'description': description,
      'strengths': strengths,
      'weaknesses': weaknesses,
      'note_advice': noteAdvice,
      'icon_url': iconUrl,
    };
  }
}
