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

class FsrsStats {
  final String provider;
  final int totalCards;
  final int dueToday;
  final int totalReviews;
  final double avgStability;
  final int? retentionRate;

  const FsrsStats({
    required this.provider,
    required this.totalCards,
    required this.dueToday,
    required this.totalReviews,
    required this.avgStability,
    required this.retentionRate,
  });

  factory FsrsStats.fromJson(Map<String, dynamic> json) => FsrsStats(
        provider: json['provider'] as String? ?? 'all',
        totalCards: (json['total_cards'] as num?)?.toInt() ?? 0,
        dueToday: (json['due_today'] as num?)?.toInt() ?? 0,
        totalReviews: (json['total_reviews'] as num?)?.toInt() ?? 0,
        avgStability: (json['avg_stability'] as num?)?.toDouble() ?? 0.0,
        retentionRate: (json['retention_rate'] as num?)?.toInt(),
      );

  static FsrsStats empty(String provider) => FsrsStats(
        provider: provider,
        totalCards: 0,
        dueToday: 0,
        totalReviews: 0,
        avgStability: 0,
        retentionRate: null,
      );
}

class AiFsrsService {
  final _supabase = Supabase.instance.client;

  /// grade: 1=Again, 2=Hard, 3=Good, 4=Easy
  static String gradeLabel(int grade) {
    const labels = {1: 'もう一度', 2: '難しい', 3: '覚えた', 4: '簡単'};
    return labels[normalizeGrade(grade)] ?? '';
  }

  static int normalizeGrade(int grade) {
    if (grade < 1) return 1;
    if (grade > 4) return 4;
    return grade;
  }

  Future<List<FsrsCard>> getNextCards(String provider, {int limit = 10}) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'quiz.fsrs_next',
          'provider': provider,
          'limit': limit,
        },
      );
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
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'quiz.fsrs_grade',
          'provider': provider,
          'question_id': questionId,
          'grade': normalizeGrade(grade),
        },
      );
      final data = response.data as Map<String, dynamic>?;
      final nextDueStr = data?['next_due'] as String? ?? '';
      final stability = (data?['stability'] as num?)?.toDouble() ?? 1.0;
      final nextDue = nextDueStr.isNotEmpty
          ? DateTime.parse(nextDueStr)
          : DateTime.now().add(const Duration(days: 1));
      return (nextDue: nextDue, stability: stability);
    } catch (_) {
      return (
        nextDue: DateTime.now().add(const Duration(days: 1)),
        stability: 1.0
      );
    }
  }

  Future<FsrsStats> getStats(String provider) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'quiz.fsrs_stats', 'provider': provider},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        return FsrsStats.empty(provider);
      }
      return FsrsStats.fromJson(data);
    } catch (_) {
      return FsrsStats.empty(provider);
    }
  }

  static String nextDueLabel(DateTime nextDue, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final dueDay = _dateOnly(nextDue);
    final diff = dueDay.difference(today).inDays;
    if (diff <= 0) return '今日';
    if (diff == 1) return '明日';
    return '$diff日後';
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
