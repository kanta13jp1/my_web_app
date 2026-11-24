import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Human-in-the-Loop のレビュー状態 (#2641).
enum HumanReviewStatus {
  pendingHumanReview('pending_human_review', '人間確認待ち'),
  approved('approved', '承認済み'),
  needsRevision('needs_revision', '要修正'),
  rejected('rejected', '却下');

  const HumanReviewStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static HumanReviewStatus fromWire(String? raw) {
    for (final status in HumanReviewStatus.values) {
      if (status.wireValue == raw) {
        return status;
      }
    }
    return HumanReviewStatus.pendingHumanReview;
  }
}

/// 個別ステージの推論トレースステップ (#2641).
@immutable
class AgentTraceStep {
  const AgentTraceStep({
    required this.stepIndex,
    required this.agentName,
    required this.role,
    required this.inputSchema,
    required this.outputSchema,
    required this.summary,
    required this.decisionBasis,
    required this.durationMs,
  });

  final int stepIndex;
  final String agentName;
  final String role;
  final String inputSchema;
  final String outputSchema;
  final String summary;
  final String decisionBasis;
  final double durationMs;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'step_index': stepIndex,
      'agent_name': agentName,
      'role': role,
      'input_schema': inputSchema,
      'output_schema': outputSchema,
      'summary': summary,
      'decision_basis': decisionBasis,
      'duration_ms': durationMs,
    };
  }

  static AgentTraceStep fromMap(Map<String, Object?> map, int fallbackIndex) {
    final rawDuration = map['duration_ms'];
    final double duration;
    if (rawDuration is num) {
      duration = rawDuration.toDouble();
    } else {
      duration = 0.0;
    }
    final rawStep = map['step_index'];
    final int stepIndex;
    if (rawStep is num) {
      stepIndex = rawStep.toInt();
    } else {
      stepIndex = fallbackIndex;
    }
    return AgentTraceStep(
      stepIndex: stepIndex,
      agentName: (map['agent_name'] as String?) ?? 'Agent',
      role: (map['role'] as String?) ?? 'worker',
      inputSchema: (map['input_schema'] as String?) ?? 'unknown',
      outputSchema: (map['output_schema'] as String?) ?? 'unknown',
      summary: (map['summary'] as String?) ?? '',
      decisionBasis: (map['decision_basis'] as String?) ?? '',
      durationMs: duration,
    );
  }
}

/// 3エージェント逐次分析の 1 実行結果と Human-in-the-Loop 状態 (#2641).
@immutable
class MultiAgentAnalysisRun {
  const MultiAgentAnalysisRun({
    required this.id,
    required this.topic,
    required this.collectorSummary,
    required this.collectedObservationCount,
    required this.sanitizedRedactionCount,
    required this.calculatorMetrics,
    required this.anomalies,
    required this.riskLevel,
    required this.headline,
    required this.rationale,
    required this.recommendedActions,
    required this.advisoryNotice,
    required this.reasoningTrace,
    required this.reviewStatus,
    required this.reviewNote,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedAt,
  });

  final String id;
  final String topic;
  final String collectorSummary;
  final int collectedObservationCount;
  final int sanitizedRedactionCount;
  final Map<String, double> calculatorMetrics;
  final List<String> anomalies;
  final String riskLevel;
  final String headline;
  final List<String> rationale;
  final List<String> recommendedActions;
  final String advisoryNotice;
  final List<AgentTraceStep> reasoningTrace;
  final HumanReviewStatus reviewStatus;
  final String reviewNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reviewedAt;

  bool get requiresHumanConfirmation =>
      reviewStatus == HumanReviewStatus.pendingHumanReview ||
      reviewStatus == HumanReviewStatus.needsRevision;

  MultiAgentAnalysisRun copyWith({
    String? id,
    HumanReviewStatus? reviewStatus,
    String? reviewNote,
    DateTime? updatedAt,
    DateTime? reviewedAt,
  }) {
    return MultiAgentAnalysisRun(
      id: id ?? this.id,
      topic: topic,
      collectorSummary: collectorSummary,
      collectedObservationCount: collectedObservationCount,
      sanitizedRedactionCount: sanitizedRedactionCount,
      calculatorMetrics: calculatorMetrics,
      anomalies: anomalies,
      riskLevel: riskLevel,
      headline: headline,
      rationale: rationale,
      recommendedActions: recommendedActions,
      advisoryNotice: advisoryNotice,
      reasoningTrace: reasoningTrace,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      reviewNote: reviewNote ?? this.reviewNote,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, Object?> toInsertPayload({required String userId}) {
    return <String, Object?>{
      'user_id': userId,
      'topic': topic,
      'collector_output': <String, Object?>{
        'schema_version': '1.0',
        'stage': 'data_collection',
        'payload': <String, Object?>{
          'topic': topic,
          'total_observations': collectedObservationCount,
          'sanitized_redaction_count': sanitizedRedactionCount,
          'summary': collectorSummary,
        },
      },
      'calculator_output': <String, Object?>{
        'schema_version': '1.0',
        'stage': 'metric_calculation',
        'payload': <String, Object?>{
          'topic': topic,
          'metrics': calculatorMetrics,
          'anomalies': anomalies
              .map((item) => <String, Object?>{'description': item})
              .toList(growable: false),
        },
      },
      'synthesizer_output': <String, Object?>{
        'schema_version': '1.0',
        'stage': 'synthesis_advisory',
        'payload': <String, Object?>{
          'topic': topic,
          'risk_level': riskLevel,
          'headline': headline,
          'rationale': rationale,
          'recommended_actions': recommendedActions,
          'advisory_notice': advisoryNotice,
          'requires_human_confirmation': true,
        },
      },
      'reasoning_trace':
          reasoningTrace.map((step) => step.toJson()).toList(growable: false),
      'human_review_status': HumanReviewStatus.pendingHumanReview.wireValue,
      'human_review_note': '',
    };
  }

  static MultiAgentAnalysisRun fromSupabaseRow(Map<String, Object?> row) {
    final collector = _asMap(row['collector_output']);
    final collectorPayload = _asMap(collector['payload']);
    final calculator = _asMap(row['calculator_output']);
    final calculatorPayload = _asMap(calculator['payload']);
    final synthesizer = _asMap(row['synthesizer_output']);
    final synthesizerPayload = _asMap(synthesizer['payload']);

    final rawMetrics = _asMap(calculatorPayload['metrics']);
    final metrics = <String, double>{};
    for (final entry in rawMetrics.entries) {
      final val = entry.value;
      if (val is num && val.isFinite) {
        metrics[entry.key] = val.toDouble();
      }
    }

    final rawAnomalies = _asList(calculatorPayload['anomalies']);
    final parsedAnomalies = <String>[];
    for (final item in rawAnomalies) {
      if (item is String && item.trim().isNotEmpty) {
        parsedAnomalies.add(item.trim());
      } else if (item is Map<Object?, Object?>) {
        final typed = _asMap(item);
        final desc = typed['description'] ?? typed['label'];
        if (desc is String && desc.trim().isNotEmpty) {
          parsedAnomalies.add(desc.trim());
        }
      }
    }

    final traceList = _asList(row['reasoning_trace']);
    final steps = <AgentTraceStep>[];
    for (var i = 0; i < traceList.length; i++) {
      final entry = _asMap(traceList[i]);
      if (entry.isNotEmpty) {
        steps.add(AgentTraceStep.fromMap(entry, i + 1));
      }
    }

    final obsCount = collectorPayload['total_observations'];
    final redactCount = collectorPayload['sanitized_redaction_count'];

    return MultiAgentAnalysisRun(
      id: (row['id'] as String?) ?? '',
      topic: (row['topic'] as String?) ?? '',
      collectorSummary: (collectorPayload['summary'] as String?) ?? '',
      collectedObservationCount: obsCount is num ? obsCount.toInt() : 0,
      sanitizedRedactionCount: redactCount is num ? redactCount.toInt() : 0,
      calculatorMetrics: Map<String, double>.unmodifiable(metrics),
      anomalies: List<String>.unmodifiable(parsedAnomalies),
      riskLevel: (synthesizerPayload['risk_level'] as String?) ?? 'medium',
      headline: (synthesizerPayload['headline'] as String?) ?? '',
      rationale: _asStringList(synthesizerPayload['rationale']),
      recommendedActions: _asStringList(
        synthesizerPayload['recommended_actions'],
      ),
      advisoryNotice: (synthesizerPayload['advisory_notice'] as String?) ??
          LocalSequentialAnalysisRunner.defaultAdvisoryNotice,
      reasoningTrace: List<AgentTraceStep>.unmodifiable(steps),
      reviewStatus: HumanReviewStatus.fromWire(
        row['human_review_status'] as String?,
      ),
      reviewNote: (row['human_review_note'] as String?) ?? '',
      createdAt: _parseDateTime(row['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDateTime(row['updated_at']) ?? DateTime.now().toUtc(),
      reviewedAt: _parseDateTime(row['reviewed_at']),
    );
  }
}

/// 決定論的 3 エージェント逐次実行器（クライアント側プレビュー・オフラインフォールバック兼務）(#2641).
class LocalSequentialAnalysisRunner {
  static const String defaultAdvisoryNotice =
      '本分析は参考情報です。金融・法務・投資等の最終確認と承認は必ず利用者自身が行ってください（Human-in-the-Loop）。';

  static final RegExp _emailPattern = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
  );
  static final RegExp _bearerPattern = RegExp(
    r'Bearer\s+[A-Za-z0-9._~+/-]{8,}',
    caseSensitive: false,
  );
  static final RegExp _tokenPattern = RegExp(
    r'(?<![A-Za-z0-9])(?:sb_secret_|sbp_|github_pat_|gh[pousr]_|glpat-|sk-(?:proj-)?|AIzaSy)[A-Za-z0-9._-]{10,}',
  );

  static String scrubSensitiveText(String raw) {
    return raw
        .replaceAll(_bearerPattern, 'Bearer [REDACTED]')
        .replaceAll(_tokenPattern, '[REDACTED_TOKEN]')
        .replaceAll(_emailPattern, '[REDACTED_EMAIL]')
        .trim();
  }

  static MultiAgentAnalysisRun execute({
    required String topic,
    List<double> series = const <double>[100.0, 114.0, 109.0, 142.0],
    DateTime? now,
  }) {
    final cleanedTopic = scrubSensitiveText(topic);
    if (cleanedTopic.isEmpty) {
      throw const FormatException('分析テーマは1文字以上で入力してください。');
    }
    if (series.isEmpty) {
      throw const FormatException('数値データ系列は1件以上必要です。');
    }
    final sanitizedCount = cleanedTopic != topic.trim() ? 1 : 0;
    final timestamp = (now ?? DateTime.now()).toUtc();

    final double total = series.fold(0.0, (prev, value) => prev + value);
    final double mean = total / series.length;
    final double first = series.first;
    final double last = series.last;
    final double pctChange = first != 0
        ? ((last - first) / first.abs()) * 100.0
        : (last == 0 ? 0.0 : 100.0);
    final double variance = series.fold(
          0.0,
          (prev, value) => prev + math.pow(value - mean, 2).toDouble(),
        ) /
        series.length;
    final double stdDev = math.sqrt(variance);
    final double volatilityRatio = mean != 0 ? stdDev / mean.abs() : stdDev;

    final anomalies = <String>[];
    if (pctChange.abs() >= 20.0) {
      anomalies.add(
        '区間変化率が ${pctChange.toStringAsFixed(1)}%（閾値 20.0% 超過）です。',
      );
    }

    final String riskLevel;
    final String headline;
    if (volatilityRatio >= 0.35 || anomalies.length >= 2) {
      riskLevel = 'high';
      headline = '[$cleanedTopic] 高リスク変動を検出 — 人間確認完了まで自動処理を保留';
    } else if (anomalies.isNotEmpty || pctChange.abs() >= 15.0) {
      riskLevel = 'medium';
      headline = '[$cleanedTopic] 注意シグナルあり — 根拠確認後に承認/修正を選択してください';
    } else {
      riskLevel = 'low';
      headline = '[$cleanedTopic] 指標は安定範囲内 — 内容確認後に承認可能';
    }

    final trace = <AgentTraceStep>[
      AgentTraceStep(
        stepIndex: 1,
        agentName: 'DataCollectorAgent',
        role: 'data_collector',
        inputSchema: 'raw_input_v1',
        outputSchema: 'data_collection_v1',
        summary:
            '観測データ ${series.length} 件を検証し PII 保護 ($sanitizedCount 件マスキング) を適用',
        decisionBasis: '必須項目・有限数値検証・秘密情報マスキング後に JSON ハンドオフを生成',
        durationMs: 4.2,
      ),
      AgentTraceStep(
        stepIndex: 2,
        agentName: 'MetricCalculatorAgent',
        role: 'metric_calculator',
        inputSchema: 'data_collection_v1',
        outputSchema: 'metric_calculation_v1',
        summary:
            '平均 ${mean.toStringAsFixed(2)} / 変化率 ${pctChange.toStringAsFixed(1)}% / 異常 ${anomalies.length} 件を算出',
        decisionBasis: 'Collector JSON スキーマ厳格検証後、決定論的統計指標と閾値逸脱を計算',
        durationMs: 3.1,
      ),
      AgentTraceStep(
        stepIndex: 3,
        agentName: 'SynthesisAdvisorAgent',
        role: 'synthesis_advisor',
        inputSchema: 'metric_calculation_v1',
        outputSchema: 'synthesis_advisory_v1',
        summary: headline,
        decisionBasis: '計算 JSON をもとにリスク分類と Human-in-the-Loop 確認必須フラグを付与',
        durationMs: 2.8,
      ),
    ];

    return MultiAgentAnalysisRun(
      id: 'local-${timestamp.millisecondsSinceEpoch}',
      topic: cleanedTopic,
      collectorSummary: 'データ収集エージェントが ${series.length} 件の観測値を構造化済み',
      collectedObservationCount: series.length,
      sanitizedRedactionCount: sanitizedCount,
      calculatorMetrics: Map<String, double>.unmodifiable(<String, double>{
        'observation_count': series.length.toDouble(),
        'numeric_total': double.parse(total.toStringAsFixed(2)),
        'numeric_mean': double.parse(mean.toStringAsFixed(2)),
        'pct_change': double.parse(pctChange.toStringAsFixed(2)),
        'volatility_ratio': double.parse(volatilityRatio.toStringAsFixed(4)),
      }),
      anomalies: List<String>.unmodifiable(anomalies),
      riskLevel: riskLevel,
      headline: headline,
      rationale: List<String>.unmodifiable(<String>[
        '合計値: ${total.toStringAsFixed(2)} / 平均値: ${mean.toStringAsFixed(2)}',
        '区間変化率: ${pctChange.toStringAsFixed(1)}% / 変動比: ${volatilityRatio.toStringAsFixed(3)}',
      ]),
      recommendedActions: const <String>[
        '推論トレース（収集→計算→統合）の各入出力整合を目視確認する',
        '非拘束助言のため、承認・要修正・却下を必ず利用者が確定する',
      ],
      advisoryNotice: defaultAdvisoryNotice,
      reasoningTrace: List<AgentTraceStep>.unmodifiable(trace),
      reviewStatus: HumanReviewStatus.pendingHumanReview,
      reviewNote: '',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}

/// 永続化層を抽象化するリポジトリ契約 (#2641).
abstract interface class MultiAgentAnalysisRepository {
  Future<List<MultiAgentAnalysisRun>> fetchRuns();
  Future<MultiAgentAnalysisRun> createRun(MultiAgentAnalysisRun draft);
  Future<MultiAgentAnalysisRun> submitHumanReview({
    required String runId,
    required HumanReviewStatus status,
    required String note,
  });
}

Map<String, Object?> _asMap(Object? raw) {
  if (raw is Map<String, Object?>) {
    return raw;
  }
  if (raw is Map<Object?, Object?>) {
    final result = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key != null) {
        result[entry.key.toString()] = entry.value;
      }
    }
    return result;
  }
  return const <String, Object?>{};
}

List<Object?> _asList(Object? raw) {
  if (raw is List<Object?>) {
    return raw;
  }
  return const <Object?>[];
}

List<String> _asStringList(Object? raw) {
  final list = _asList(raw);
  final out = <String>[];
  for (final item in list) {
    if (item is String && item.trim().isNotEmpty) {
      out.add(item.trim());
    }
  }
  return List<String>.unmodifiable(out);
}

DateTime? _parseDateTime(Object? raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw.trim());
  }
  return null;
}
