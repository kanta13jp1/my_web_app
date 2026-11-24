import 'package:flutter/foundation.dart';

/// 実行モード種別 (`standard` / `deep_research` / `background`) (#2654).
enum ReasoningDepthMode {
  standard(
    wireValue: 'standard',
    displayName: 'Standard',
    description: '単発・軽量な推論向け。ツール上限 3 回、15 秒枠で即時回答します。',
    maxToolCalls: 3,
    timeoutSeconds: 15,
    estimatedCostUsd: 0.002000,
    estimatedLatencyMs: 1500,
    isAsyncQueue: false,
  ),
  deepResearch(
    wireValue: 'deep_research',
    displayName: 'Deep Research',
    description: '複数ドキュメント横断分析向け。最大 25 回ツール呼び出し・300 秒非同期キューで段階進行します。',
    maxToolCalls: 25,
    timeoutSeconds: 300,
    estimatedCostUsd: 0.032000,
    estimatedLatencyMs: 45000,
    isAsyncQueue: true,
  ),
  background(
    wireValue: 'background',
    displayName: 'Background',
    description: '長時間の自律調査向け。最大 50 回ツール呼び出し・600 秒非同期キューで継続実行します。',
    maxToolCalls: 50,
    timeoutSeconds: 600,
    estimatedCostUsd: 0.058000,
    estimatedLatencyMs: 180000,
    isAsyncQueue: true,
  );

  const ReasoningDepthMode({
    required this.wireValue,
    required this.displayName,
    required this.description,
    required this.maxToolCalls,
    required this.timeoutSeconds,
    required this.estimatedCostUsd,
    required this.estimatedLatencyMs,
    required this.isAsyncQueue,
  });

  final String wireValue;
  final String displayName;
  final String description;
  final int maxToolCalls;
  final int timeoutSeconds;
  final double estimatedCostUsd;
  final int estimatedLatencyMs;
  final bool isAsyncQueue;

  static ReasoningDepthMode fromWireValue(String? raw) {
    for (final mode in values) {
      if (mode.wireValue == raw) {
        return mode;
      }
    }
    return ReasoningDepthMode.standard;
  }
}

/// 非同期推論ジョブの状態 (#2654).
enum ReasoningJobStatus {
  queued(wireValue: 'queued', displayLabel: '待機中 (非同期キュー)', isTerminal: false),
  running(
    wireValue: 'running',
    displayLabel: '実行中 (ポーリング監視)',
    isTerminal: false,
  ),
  completed(wireValue: 'completed', displayLabel: '完了', isTerminal: true),
  failed(wireValue: 'failed', displayLabel: '失敗', isTerminal: true),
  cancelled(wireValue: 'cancelled', displayLabel: 'キャンセル', isTerminal: true);

  const ReasoningJobStatus({
    required this.wireValue,
    required this.displayLabel,
    required this.isTerminal,
  });

  final String wireValue;
  final String displayLabel;
  final bool isTerminal;

  static ReasoningJobStatus fromWireValue(String? raw) {
    for (final status in values) {
      if (status.wireValue == raw) {
        return status;
      }
    }
    return ReasoningJobStatus.queued;
  }
}

/// モード別のコストと所要時間差分比較エントリ (#2654).
@immutable
class ReasoningModeComparison {
  const ReasoningModeComparison({
    required this.mode,
    required this.estimatedCostUsd,
    required this.estimatedLatencyMs,
    required this.costDeltaVsStandardUsd,
    required this.latencyDeltaVsStandardMs,
    required this.costMultiplierVsStandard,
  });

  final ReasoningDepthMode mode;
  final double estimatedCostUsd;
  final int estimatedLatencyMs;
  final double costDeltaVsStandardUsd;
  final int latencyDeltaVsStandardMs;
  final double costMultiplierVsStandard;

  String get formattedCost => 'USD ${estimatedCostUsd.toStringAsFixed(4)}';

  String get formattedCostDelta {
    if (costDeltaVsStandardUsd == 0) {
      return 'Standard 基準 (1.0x)';
    }
    return 'Standard比 +USD ${costDeltaVsStandardUsd.toStringAsFixed(4)} '
        '(${costMultiplierVsStandard.toStringAsFixed(1)}x)';
  }

  String get formattedLatency {
    final seconds = estimatedLatencyMs / 1000.0;
    return '${seconds.toStringAsFixed(1)}秒';
  }

  String get formattedLatencyDelta {
    if (latencyDeltaVsStandardMs == 0) {
      return '即時同期 (追加待ちなし)';
    }
    final deltaSec = latencyDeltaVsStandardMs / 1000.0;
    return 'Standard比 +${deltaSec.toStringAsFixed(1)}秒';
  }
}

/// Supabase `ai_reasoning_depth_jobs` の不変ジョブモデル (#2654).
@immutable
class ReasoningDepthJob {
  const ReasoningDepthJob({
    required this.id,
    required this.reasoningMode,
    required this.promptSummary,
    required this.maxToolCalls,
    required this.timeoutSeconds,
    required this.estimatedCostUsd,
    required this.estimatedLatencyMs,
    required this.toolCallsCompleted,
    required this.jobStatus,
    required this.progressNote,
    required this.resultSummary,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReasoningDepthJob.fromSupabaseRow(Map<String, Object?> row) {
    final mode = ReasoningDepthMode.fromWireValue(
      row['reasoning_mode']?.toString(),
    );
    return ReasoningDepthJob(
      id: (row['id'] ?? '').toString(),
      reasoningMode: mode,
      promptSummary: (row['prompt_summary'] ?? '').toString(),
      maxToolCalls:
          _parseInt(row['max_tool_calls'], fallback: mode.maxToolCalls),
      timeoutSeconds:
          _parseInt(row['timeout_seconds'], fallback: mode.timeoutSeconds),
      estimatedCostUsd: _parseDouble(
        row['estimated_cost_usd'],
        fallback: mode.estimatedCostUsd,
      ),
      estimatedLatencyMs: _parseInt(
        row['estimated_latency_ms'],
        fallback: mode.estimatedLatencyMs,
      ),
      toolCallsCompleted: _parseInt(row['tool_calls_completed'], fallback: 0),
      jobStatus: ReasoningJobStatus.fromWireValue(
        row['job_status']?.toString(),
      ),
      progressNote: (row['progress_note'] ?? '').toString(),
      resultSummary: (row['result_summary'] ?? '').toString(),
      createdAt: _parseDateTime(row['created_at']) ?? DateTime.utc(2026),
      updatedAt: _parseDateTime(row['updated_at']) ?? DateTime.utc(2026),
    );
  }

  final String id;
  final ReasoningDepthMode reasoningMode;
  final String promptSummary;
  final int maxToolCalls;
  final int timeoutSeconds;
  final double estimatedCostUsd;
  final int estimatedLatencyMs;
  final int toolCallsCompleted;
  final ReasoningJobStatus jobStatus;
  final String progressNote;
  final String resultSummary;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get progressFraction {
    if (maxToolCalls <= 0) {
      return 0;
    }
    final ratio = toolCallsCompleted / maxToolCalls;
    if (ratio < 0) {
      return 0;
    }
    if (ratio > 1) {
      return 1;
    }
    return ratio;
  }

  ReasoningDepthJob copyWith({
    String? id,
    ReasoningDepthMode? reasoningMode,
    String? promptSummary,
    int? maxToolCalls,
    int? timeoutSeconds,
    double? estimatedCostUsd,
    int? estimatedLatencyMs,
    int? toolCallsCompleted,
    ReasoningJobStatus? jobStatus,
    String? progressNote,
    String? resultSummary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReasoningDepthJob(
      id: id ?? this.id,
      reasoningMode: reasoningMode ?? this.reasoningMode,
      promptSummary: promptSummary ?? this.promptSummary,
      maxToolCalls: maxToolCalls ?? this.maxToolCalls,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      estimatedCostUsd: estimatedCostUsd ?? this.estimatedCostUsd,
      estimatedLatencyMs: estimatedLatencyMs ?? this.estimatedLatencyMs,
      toolCallsCompleted: toolCallsCompleted ?? this.toolCallsCompleted,
      jobStatus: jobStatus ?? this.jobStatus,
      progressNote: progressNote ?? this.progressNote,
      resultSummary: resultSummary ?? this.resultSummary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toInsertPayload({required String userId}) {
    return <String, Object?>{
      'user_id': userId,
      'reasoning_mode': reasoningMode.wireValue,
      'prompt_summary': promptSummary,
      'max_tool_calls': maxToolCalls,
      'timeout_seconds': timeoutSeconds,
      'estimated_cost_usd': estimatedCostUsd,
      'estimated_latency_ms': estimatedLatencyMs,
      'tool_calls_completed': toolCallsCompleted,
      'job_status': jobStatus.wireValue,
      'progress_note': progressNote,
      'result_summary': resultSummary,
    };
  }

  static int _parseInt(Object? raw, {required int fallback}) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static double _parseDouble(Object? raw, {required double fallback}) {
    if (raw is double) {
      return raw;
    }
    if (raw is num) {
      return raw.toDouble();
    }
    return double.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw is DateTime) {
      return raw.toUtc();
    }
    final text = raw?.toString() ?? '';
    if (text.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(text)?.toUtc();
  }
}

/// 推論深度比較・ローカル非同期キュー遷移・サニタイズ用ドメインロジック (#2654).
abstract final class ReasoningDepthPlanner {
  static final RegExp _emailPattern = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  );
  static final RegExp _bearerPattern = RegExp(
    r'bearer\s+[A-Za-z0-9._\-]{8,}',
    caseSensitive: false,
  );
  static final RegExp _prefixSecretPattern = RegExp(
    r'\b(?:sk|sb|ghp|gho|AIza)[A-Za-z0-9_\-]{8,}\b',
  );

  static String scrubSensitiveText(String raw, {int maxLength = 500}) {
    var cleaned = raw.trim();
    cleaned = cleaned.replaceAll(_bearerPattern, 'Bearer [redacted]');
    cleaned = cleaned.replaceAll(_prefixSecretPattern, '[redacted]');
    cleaned = cleaned.replaceAll(_emailPattern, '[email-redacted]');
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength).trimRight();
    }
    return cleaned;
  }

  static List<ReasoningModeComparison> compareAllModes() {
    const base = ReasoningDepthMode.standard;
    final list = <ReasoningModeComparison>[];
    for (final mode in ReasoningDepthMode.values) {
      final costDelta = mode.estimatedCostUsd - base.estimatedCostUsd;
      final latencyDelta = mode.estimatedLatencyMs - base.estimatedLatencyMs;
      final multiplier = base.estimatedCostUsd > 0
          ? mode.estimatedCostUsd / base.estimatedCostUsd
          : 1.0;
      list.add(
        ReasoningModeComparison(
          mode: mode,
          estimatedCostUsd: mode.estimatedCostUsd,
          estimatedLatencyMs: mode.estimatedLatencyMs,
          costDeltaVsStandardUsd: costDelta,
          latencyDeltaVsStandardMs: latencyDelta,
          costMultiplierVsStandard: multiplier,
        ),
      );
    }
    return List<ReasoningModeComparison>.unmodifiable(list);
  }

  static ReasoningDepthJob buildInitialJob({
    required ReasoningDepthMode mode,
    required String promptSummary,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final sanitized = scrubSensitiveText(promptSummary);
    if (sanitized.isEmpty) {
      throw ArgumentError('分析したい課題内容を入力してください。');
    }

    if (mode.isAsyncQueue) {
      return ReasoningDepthJob(
        id: 'draft-${timestamp.microsecondsSinceEpoch}',
        reasoningMode: mode,
        promptSummary: sanitized,
        maxToolCalls: mode.maxToolCalls,
        timeoutSeconds: mode.timeoutSeconds,
        estimatedCostUsd: mode.estimatedCostUsd,
        estimatedLatencyMs: mode.estimatedLatencyMs,
        toolCallsCompleted: 0,
        jobStatus: ReasoningJobStatus.queued,
        progressNote:
            '${mode.displayName} 非同期キュー投入済み (上限 ${mode.maxToolCalls} ツール / ${mode.timeoutSeconds}秒)',
        resultSummary: '',
        createdAt: timestamp,
        updatedAt: timestamp,
      );
    }

    const completedTools = 2;
    return ReasoningDepthJob(
      id: 'draft-${timestamp.microsecondsSinceEpoch}',
      reasoningMode: mode,
      promptSummary: sanitized,
      maxToolCalls: mode.maxToolCalls,
      timeoutSeconds: mode.timeoutSeconds,
      estimatedCostUsd: mode.estimatedCostUsd,
      estimatedLatencyMs: mode.estimatedLatencyMs,
      toolCallsCompleted: completedTools,
      jobStatus: ReasoningJobStatus.completed,
      progressNote:
          'Standard 同期推論完了 ($completedTools/${mode.maxToolCalls} ツール)',
      resultSummary: '[Standard] 「$sanitized」を同期モードで即時回答しました。',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  static ReasoningDepthJob advanceQueuedJob(
    ReasoningDepthJob job, {
    DateTime? now,
  }) {
    if (job.jobStatus.isTerminal) {
      return job;
    }
    final timestamp = (now ?? DateTime.now()).toUtc();
    if (job.jobStatus == ReasoningJobStatus.queued) {
      final firstBatch = (job.maxToolCalls ~/ 4).clamp(1, job.maxToolCalls);
      return job.copyWith(
        jobStatus: ReasoningJobStatus.running,
        toolCallsCompleted: firstBatch,
        progressNote:
            '${job.reasoningMode.displayName} 実行中: 複数ドキュメント横断検索 ($firstBatch/${job.maxToolCalls} ツール)',
        updatedAt: timestamp,
      );
    }

    final increment = ((job.maxToolCalls + 1) ~/ 2).clamp(1, job.maxToolCalls);
    final nextTools =
        (job.toolCallsCompleted + increment).clamp(0, job.maxToolCalls);
    if (nextTools >= job.maxToolCalls) {
      return job.copyWith(
        jobStatus: ReasoningJobStatus.completed,
        toolCallsCompleted: job.maxToolCalls,
        progressNote:
            '${job.reasoningMode.displayName} 完了 (${job.maxToolCalls}/${job.maxToolCalls} ツール)',
        resultSummary:
            '[${job.reasoningMode.displayName}] 「${job.promptSummary}」を最大 ${job.maxToolCalls} 回のツール探索・${job.timeoutSeconds}秒枠で統合完了しました。',
        updatedAt: timestamp,
      );
    }

    return job.copyWith(
      jobStatus: ReasoningJobStatus.running,
      toolCallsCompleted: nextTools,
      progressNote:
          '${job.reasoningMode.displayName} 実行中: 論点突合・証拠検証 ($nextTools/${job.maxToolCalls} ツール)',
      updatedAt: timestamp,
    );
  }
}

/// AI推論深度ジョブ永続化リポジトリ境界 (#2654).
abstract interface class AiReasoningDepthRepository {
  Future<List<ReasoningDepthJob>> fetchJobs();

  Future<ReasoningDepthJob> createJob(ReasoningDepthJob draft);

  Future<ReasoningDepthJob> updateJobProgress({
    required String jobId,
    required ReasoningJobStatus jobStatus,
    required int toolCallsCompleted,
    required String progressNote,
    required String resultSummary,
  });
}
