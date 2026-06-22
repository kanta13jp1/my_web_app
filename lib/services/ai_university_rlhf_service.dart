import 'package:supabase_flutter/supabase_flutter.dart';

class AiUniversityRlhfSignal {
  const AiUniversityRlhfSignal({
    required this.providerId,
    required this.rating,
    required this.helpful,
  });

  final String providerId;
  final int rating;
  final bool helpful;
}

class AiUniversityRlhfSnapshot {
  const AiUniversityRlhfSnapshot({
    required this.totalSignals,
    required this.positiveSignals,
    required this.neutralSignals,
    required this.negativeSignals,
    required this.averageRating,
    required this.qualityScore,
    required this.readyForFineTune,
    required this.providerSignalCounts,
    required this.nextAction,
  });

  factory AiUniversityRlhfSnapshot.empty() => const AiUniversityRlhfSnapshot(
        totalSignals: 0,
        positiveSignals: 0,
        neutralSignals: 0,
        negativeSignals: 0,
        averageRating: 0,
        qualityScore: 0,
        readyForFineTune: false,
        providerSignalCounts: {},
        nextAction: 'レッスンやクイズへの学習者フィードバックを集めましょう。',
      );

  factory AiUniversityRlhfSnapshot.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    final rawCounts = json['provider_signal_counts'];
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        counts[entry.key.toString()] = (entry.value as num?)?.toInt() ?? 0;
      }
    }

    return AiUniversityRlhfSnapshot(
      totalSignals: (json['total_signals'] as num?)?.toInt() ?? 0,
      positiveSignals: (json['positive_signals'] as num?)?.toInt() ?? 0,
      neutralSignals: (json['neutral_signals'] as num?)?.toInt() ?? 0,
      negativeSignals: (json['negative_signals'] as num?)?.toInt() ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      qualityScore: (json['quality_score'] as num?)?.toInt() ?? 0,
      readyForFineTune: json['ready_for_fine_tune'] == true,
      providerSignalCounts: counts,
      nextAction:
          json['next_action'] as String? ?? 'レッスンやクイズへの学習者フィードバックを集めましょう。',
    );
  }

  factory AiUniversityRlhfSnapshot.fromSignals(
    List<AiUniversityRlhfSignal> signals,
  ) {
    if (signals.isEmpty) return AiUniversityRlhfSnapshot.empty();

    var positive = 0;
    var neutral = 0;
    var negative = 0;
    var ratingSum = 0;
    final providerCounts = <String, int>{};

    for (final signal in signals) {
      final rating = normalizeRating(signal.rating);
      ratingSum += rating;
      providerCounts.update(
        signal.providerId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      final label = labelFor(rating: rating, helpful: signal.helpful);
      if (label == 'positive') {
        positive += 1;
      } else if (label == 'negative') {
        negative += 1;
      } else {
        neutral += 1;
      }
    }

    final total = signals.length;
    final averageRating = double.parse((ratingSum / total).toStringAsFixed(1));
    final qualityScore = calculateQualityScore(
      positiveSignals: positive,
      neutralSignals: neutral,
      totalSignals: total,
    );

    return AiUniversityRlhfSnapshot(
      totalSignals: total,
      positiveSignals: positive,
      neutralSignals: neutral,
      negativeSignals: negative,
      averageRating: averageRating,
      qualityScore: qualityScore,
      readyForFineTune: total >= 20 && qualityScore >= 70,
      providerSignalCounts: providerCounts,
      nextAction:
          nextActionFor(totalSignals: total, qualityScore: qualityScore),
    );
  }

  final int totalSignals;
  final int positiveSignals;
  final int neutralSignals;
  final int negativeSignals;
  final double averageRating;
  final int qualityScore;
  final bool readyForFineTune;
  final Map<String, int> providerSignalCounts;
  final String nextAction;

  static int normalizeRating(int rating) {
    if (rating < 1) return 1;
    if (rating > 5) return 5;
    return rating;
  }

  static String labelFor({required int rating, required bool helpful}) {
    final normalized = normalizeRating(rating);
    if (helpful || normalized >= 4) return 'positive';
    if (!helpful || normalized <= 2) return 'negative';
    return 'neutral';
  }

  static int calculateQualityScore({
    required int positiveSignals,
    required int neutralSignals,
    required int totalSignals,
  }) {
    if (totalSignals <= 0) return 0;
    return (((positiveSignals + neutralSignals * 0.5) / totalSignals) * 100)
        .round();
  }

  static String nextActionFor({
    required int totalSignals,
    required int qualityScore,
  }) {
    if (totalSignals < 20) {
      return 'チューニング前に、まず選好シグナルを20件以上集めましょう。';
    }
    if (qualityScore < 70) {
      return '低評価のレッスンを見直し、弱い解説を再生成しましょう。';
    }
    return 'データセットは微調整・評価バッチに利用できる状態です。';
  }
}

class AiUniversityRlhfService {
  AiUniversityRlhfService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<AiUniversityRlhfSnapshot?> loadSnapshot() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return AiUniversityRlhfSnapshot.empty();

    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'university.rlhf_snapshot'},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) return null;
      final snapshot = data['snapshot'] as Map<String, dynamic>? ?? {};
      return AiUniversityRlhfSnapshot.fromJson(snapshot);
    } catch (_) {
      return null;
    }
  }

  Future<bool> submitSignal({
    required String providerId,
    required String contentId,
    required String contentTitle,
    required int rating,
    required bool helpful,
    String? comment,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'university.rlhf_signal',
          'provider_id': providerId,
          'content_id': contentId,
          'content_title': contentTitle,
          'rating': AiUniversityRlhfSnapshot.normalizeRating(rating),
          'helpful': helpful,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
      );
      final data = response.data as Map<String, dynamic>?;
      return data?['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
