import 'package:supabase_flutter/supabase_flutter.dart';

abstract class TaskClarityEvaluator {
  Future<TaskClarityEvaluation> evaluate({
    required String title,
    String description = '',
  });
}

/// Injectable adapter for the authenticated task-clarity action.
typedef TaskClarityInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

class TaskClarityEvaluation {
  static const int defaultThreshold = 6;

  final int score;
  final int threshold;
  final String status;
  final String source;
  final List<String> questions;
  final List<String> ambiguities;
  final DateTime evaluatedAt;

  const TaskClarityEvaluation({
    required this.score,
    required this.threshold,
    required this.status,
    required this.source,
    required this.questions,
    required this.ambiguities,
    required this.evaluatedAt,
  });

  factory TaskClarityEvaluation.fromJson(Map<String, dynamic> json) {
    final score = _readInt(json['score'], fallback: 1).clamp(1, 10).toInt();
    final threshold = _readInt(
      json['threshold'],
      fallback: defaultThreshold,
    ).clamp(1, 9).toInt();
    final requestedStatus = json['status']?.toString();
    final needsClarification =
        requestedStatus != 'clarified' && score <= threshold;
    final questions = _readStringList(json['questions']);

    return TaskClarityEvaluation(
      score: score,
      threshold: threshold,
      status: requestedStatus == 'clarified'
          ? 'clarified'
          : score <= threshold
              ? 'needs_clarification'
              : 'clear',
      source: json['source']?.toString().trim().isNotEmpty == true
          ? json['source'].toString().trim()
          : 'unknown',
      questions: needsClarification && questions.isEmpty
          ? const <String>['完了を一意に判断できる条件は何ですか？']
          : questions,
      ambiguities: _readStringList(json['ambiguities']),
      evaluatedAt:
          DateTime.tryParse(json['evaluated_at']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }

  factory TaskClarityEvaluation.offline({
    required String title,
    String description = '',
  }) {
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    final combined = '$normalizedTitle\n$normalizedDescription'.toLowerCase();
    var score = 1;

    if (normalizedTitle.length >= 12) {
      score += 2;
    } else if (normalizedTitle.length >= 6) {
      score += 1;
    }
    if (normalizedDescription.length >= 30) {
      score += 2;
    } else if (normalizedDescription.length >= 12) {
      score += 1;
    }

    final hasDeadline = RegExp(
      r'(\d{1,2}[/-]\d{1,2}|\d{1,2}月\d{1,2}日|今日|明日|今週|来週|まで|deadline|due\s|by\s)',
      caseSensitive: false,
    ).hasMatch(combined);
    final hasMeasure = RegExp(
      r'(\d+\s*(%|件|回|人|円|分|時間|個)|達成|削減|増加|完了条件|acceptance|success|target|metric)',
      caseSensitive: false,
    ).hasMatch(combined);
    final hasAction = RegExp(
      r'(作成|実装|送信|確認|調査|修正|公開|更新|準備|提出|prepare|create|implement|send|review|publish|update|fix|investigate|deliver|improve|outline|confirm)',
      caseSensitive: false,
    ).hasMatch(combined);
    final hasScope = RegExp(
      r'(対象|範囲|画面|ページ|機能|顧客|ユーザー|価格|前提|scope|screen|page|feature|customer|user|pricing|assumption)',
      caseSensitive: false,
    ).hasMatch(combined);

    if (hasDeadline) score += 2;
    if (hasMeasure) score += 2;
    if (hasAction) score += 1;
    if (hasScope) score += 1;
    score = score.clamp(1, 10).toInt();

    final questions = <String>[];
    final ambiguities = <String>[];
    if (normalizedDescription.isEmpty) {
      questions.add('具体的に何を実行し、どの成果物を作りますか？');
      ambiguities.add('実行内容と成果物が未指定です');
    }
    if (!hasDeadline) {
      questions.add('いつまでに完了する必要がありますか？');
      ambiguities.add('期限が未指定です');
    }
    if (!hasMeasure) {
      questions.add('完了を判断できる数値または条件は何ですか？');
      ambiguities.add('完了条件が未指定です');
    }
    if (!hasScope) {
      questions.add('対象範囲、ユーザー、または画面はどこですか？');
      ambiguities.add('対象範囲が未指定です');
    }
    if (score <= defaultThreshold && questions.isEmpty) {
      questions.add('完了を一意に判断できる条件は何ですか？');
    }

    return TaskClarityEvaluation(
      score: score,
      threshold: defaultThreshold,
      status: score <= defaultThreshold ? 'needs_clarification' : 'clear',
      source: 'offline_heuristic',
      questions: questions.take(3).toList(growable: false),
      ambiguities: ambiguities.take(3).toList(growable: false),
      evaluatedAt: DateTime.now().toUtc(),
    );
  }

  bool get needsClarification => status != 'clarified' && score <= threshold;

  Map<String, dynamic> toMetadata({
    Map<String, String> answers = const <String, String>{},
    DateTime? clarifiedAt,
  }) {
    final normalizedAnswers = answers.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map(
          (entry) => <String, String>{
            'question': entry.key,
            'answer': entry.value.trim(),
          },
        )
        .toList(growable: false);

    return <String, dynamic>{
      'score': score,
      'threshold': threshold,
      'status': normalizedAnswers.isEmpty ? status : 'clarified',
      'source': source,
      'questions': questions,
      'ambiguities': ambiguities,
      'evaluated_at': evaluatedAt.toIso8601String(),
      if (normalizedAnswers.isNotEmpty) ...<String, dynamic>{
        'answers': normalizedAnswers,
        'clarified_at':
            (clarifiedAt ?? DateTime.now().toUtc()).toIso8601String(),
      },
    };
  }

  static int _readInt(Object? value, {required int fallback}) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .take(3)
        .toList(growable: false);
  }
}

class TaskClarityService implements TaskClarityEvaluator {
  final SupabaseClient? _supabaseClient;
  final TaskClarityInvoker? _invoker;

  const TaskClarityService({
    SupabaseClient? supabaseClient,
    TaskClarityInvoker? invoker,
  })  : _supabaseClient = supabaseClient,
        _invoker = invoker;

  SupabaseClient get _supabase => _supabaseClient ?? Supabase.instance.client;

  @override
  Future<TaskClarityEvaluation> evaluate({
    required String title,
    String description = '',
  }) async {
    try {
      final body = <String, dynamic>{
        'action': 'task.clarity.evaluate',
        'title': title.trim(),
        'description': description.trim(),
      };
      final payload = await _invoke(body);
      if (payload['success'] != true || payload['evaluation'] is! Map) {
        throw const FormatException('Task clarity evaluation is missing.');
      }
      return TaskClarityEvaluation.fromJson(
        Map<String, dynamic>.from(payload['evaluation'] as Map),
      );
    } catch (_) {
      return TaskClarityEvaluation.offline(
        title: title,
        description: description,
      );
    }
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final invoker = _invoker;
    if (invoker != null) {
      return invoker(body);
    }
    final response = await _supabase.functions.invoke('ai-hub', body: body);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const FormatException('Task clarity response must be an object.');
  }
}
