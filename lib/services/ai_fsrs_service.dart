import 'package:supabase_flutter/supabase_flutter.dart';

class FsrsCard {
  final String questionId;
  final String provider;
  final DateTime dueDate;
  final double stability;
  final String state;

  const FsrsCard({
    required this.questionId,
    required this.provider,
    required this.dueDate,
    required this.stability,
    required this.state,
  });

  factory FsrsCard.fromJson(Map<String, dynamic> json) => FsrsCard(
        questionId: json['question_id'] as String,
        provider: json['provider'] as String,
        dueDate: DateTime.parse(json['due_date'] as String),
        stability: (json['stability'] as num).toDouble(),
        state: json['state'] as String? ?? 'new',
      );
}

class AiFsrsService {
  final _supabase = Supabase.instance.client;

  /// grade: 1=Again, 2=Hard, 3=Good, 4=Easy
  static String gradeLabel(int grade) {
    const labels = {1: 'また明日', 2: '難しい', 3: '覚えた', 4: '簡単'};
    return labels[grade] ?? '';
  }

  Future<List<FsrsCard>> getNextCards(String provider, {int limit = 10}) async {
    try {
      final response = await _supabase.functions.invoke('ai-hub', body: {
        'action': 'quiz.fsrs_next',
        'provider': provider,
        'limit': limit,
      },);
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) return [];
      final cards = data['cards'] as List<dynamic>? ?? [];
      return cards
          .map((c) => FsrsCard.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<({DateTime nextDue, double stability})> gradeCard({
    required String provider,
    required String questionId,
    required int grade,
  }) async {
    try {
      final response = await _supabase.functions.invoke('ai-hub', body: {
        'action': 'quiz.fsrs_grade',
        'provider': provider,
        'question_id': questionId,
        'grade': grade,
      },);
      final data = response.data as Map<String, dynamic>?;
      final nextDueStr = data?['next_due'] as String? ?? '';
      final stability = (data?['stability'] as num?)?.toDouble() ?? 1.0;
      final nextDue = nextDueStr.isNotEmpty
          ? DateTime.parse(nextDueStr)
          : DateTime.now().add(const Duration(days: 1));
      return (nextDue: nextDue, stability: stability);
    } catch (_) {
      return (nextDue: DateTime.now().add(const Duration(days: 1)), stability: 1.0);
    }
  }

  static String nextDueLabel(DateTime nextDue) {
    final now = DateTime.now();
    final diff = nextDue.difference(now).inDays;
    if (diff <= 0) return '今日';
    if (diff == 1) return '明日';
    return '$diff日後';
  }
}
