enum FunctionalEmotionCategory {
  calm('calm', '冷静', false),
  empathy('empathy', '共感', false),
  urgency('urgency', '焦り', true),
  overWarning('over_warning', '過度な警告', true),
  panic('panic', 'パニック', true);

  const FunctionalEmotionCategory(
    this.apiValue,
    this.label,
    this.isAlertable,
  );

  final String apiValue;
  final String label;
  final bool isAlertable;

  static FunctionalEmotionCategory fromApi(final String raw) {
    for (final value in FunctionalEmotionCategory.values) {
      if (value.apiValue == raw) {
        return value;
      }
    }
    return FunctionalEmotionCategory.calm;
  }
}

class AiEmotionAuthException implements Exception {
  const AiEmotionAuthException([this.message = 'Unauthorized']);

  final String message;

  @override
  String toString() => message;
}

class AiEmotionLogEntry {
  const AiEmotionLogEntry({
    required this.id,
    required this.model,
    required this.sourceAction,
    required this.responseExcerpt,
    required this.tone,
    required this.score,
    required this.alertThreshold,
    required this.thresholdExceeded,
    required this.alertSeverity,
    required this.needsVerification,
    required this.verificationNote,
    required this.matchedSignals,
    required this.recordedAt,
  });

  final String id;
  final String model;
  final String sourceAction;
  final String responseExcerpt;
  final FunctionalEmotionCategory tone;
  final double score;
  final double alertThreshold;
  final bool thresholdExceeded;
  final String alertSeverity;
  final bool needsVerification;
  final String verificationNote;
  final List<String> matchedSignals;
  final DateTime recordedAt;

  factory AiEmotionLogEntry.fromJson(final Map<String, Object?> json) {
    final rawSignals = json['matched_signals'];
    final signals = <String>[];
    if (rawSignals is List<Object?>) {
      for (final item in rawSignals) {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty) {
          signals.add(s);
        }
      }
    }
    final parsedDate = DateTime.tryParse(
          json['recorded_at']?.toString() ?? '',
        ) ??
        DateTime.now();
    return AiEmotionLogEntry(
      id: json['id']?.toString() ?? '',
      model: json['model']?.toString() ?? 'ai-assistant',
      sourceAction: json['source_action']?.toString() ?? 'assistant_reply',
      responseExcerpt: json['response_excerpt']?.toString() ?? '',
      tone: FunctionalEmotionCategory.fromApi(
        json['tone']?.toString() ?? 'calm',
      ),
      score: _toDouble(json['score'], 0.0),
      alertThreshold: _toDouble(json['alert_threshold'], 0.7),
      thresholdExceeded: json['threshold_exceeded'] == true,
      alertSeverity: json['alert_severity']?.toString() ?? 'none',
      needsVerification: true,
      verificationNote: json['verification_note']?.toString() ?? '',
      matchedSignals: signals,
      recordedAt: parsedDate,
    );
  }
}

class AiEmotionAlertEntry {
  const AiEmotionAlertEntry({
    required this.id,
    required this.logId,
    required this.model,
    required this.tone,
    required this.score,
    required this.threshold,
    required this.severity,
    required this.message,
    required this.needsVerification,
    required this.notified,
    required this.triggeredAt,
  });

  final String id;
  final String logId;
  final String model;
  final FunctionalEmotionCategory tone;
  final double score;
  final double threshold;
  final String severity;
  final String message;
  final bool needsVerification;
  final bool notified;
  final DateTime triggeredAt;

  factory AiEmotionAlertEntry.fromJson(final Map<String, Object?> json) {
    final parsedDate = DateTime.tryParse(
          json['triggered_at']?.toString() ?? '',
        ) ??
        DateTime.now();
    return AiEmotionAlertEntry(
      id: json['id']?.toString() ?? '',
      logId: json['log_id']?.toString() ?? '',
      model: json['model']?.toString() ?? 'ai-assistant',
      tone: FunctionalEmotionCategory.fromApi(
        json['tone']?.toString() ?? 'urgency',
      ),
      score: _toDouble(json['score'], 0.0),
      threshold: _toDouble(json['threshold'], 0.7),
      severity: json['severity']?.toString() ?? 'warning',
      message: json['message']?.toString() ?? '',
      needsVerification: true,
      notified: json['notified'] == true,
      triggeredAt: parsedDate,
    );
  }
}

class EmotionTimeBucket {
  const EmotionTimeBucket({
    required this.bucketLabel,
    required this.totalCount,
    required this.alertCount,
    required this.dominantTone,
    required this.avgUrgencyScore,
    required this.toneCounts,
  });

  final String bucketLabel;
  final int totalCount;
  final int alertCount;
  final FunctionalEmotionCategory dominantTone;
  final double avgUrgencyScore;
  final Map<FunctionalEmotionCategory, int> toneCounts;

  factory EmotionTimeBucket.fromJson(final Map<String, Object?> json) {
    final counts = <FunctionalEmotionCategory, int>{};
    final rawCounts = json['tone_counts'];
    for (final cat in FunctionalEmotionCategory.values) {
      var val = 0;
      if (rawCounts is Map<Object?, Object?>) {
        val = _toInt(rawCounts[cat.apiValue], 0);
      }
      counts[cat] = val;
    }
    return EmotionTimeBucket(
      bucketLabel: json['bucket_label']?.toString() ?? '',
      totalCount: _toInt(json['total_count'], 0),
      alertCount: _toInt(json['alert_count'], 0),
      dominantTone: FunctionalEmotionCategory.fromApi(
        json['dominant_tone']?.toString() ?? 'calm',
      ),
      avgUrgencyScore: _toDouble(json['avg_urgency_score'], 0.0),
      toneCounts: counts,
    );
  }
}

class AiEmotionSummary {
  const AiEmotionSummary({
    required this.totalLogs,
    required this.alertCount,
    required this.overThresholdRatePct,
    required this.dominantTone,
    required this.needsVerification,
    required this.verificationNote,
    required this.countsByTone,
    required this.timeline,
  });

  const AiEmotionSummary.empty()
      : totalLogs = 0,
        alertCount = 0,
        overThresholdRatePct = 0,
        dominantTone = FunctionalEmotionCategory.calm,
        needsVerification = true,
        verificationNote =
            '要検証: Anthropic研究に基づく機能的感情の外部表現分類であり、内部ニューロン監視ではありません。',
        countsByTone = const <FunctionalEmotionCategory, int>{},
        timeline = const <EmotionTimeBucket>[];

  final int totalLogs;
  final int alertCount;
  final double overThresholdRatePct;
  final FunctionalEmotionCategory dominantTone;
  final bool needsVerification;
  final String verificationNote;
  final Map<FunctionalEmotionCategory, int> countsByTone;
  final List<EmotionTimeBucket> timeline;

  factory AiEmotionSummary.fromJson(final Map<String, Object?> json) {
    final counts = <FunctionalEmotionCategory, int>{};
    final rawCounts = json['counts_by_tone'];
    for (final cat in FunctionalEmotionCategory.values) {
      var val = 0;
      if (rawCounts is Map<Object?, Object?>) {
        val = _toInt(rawCounts[cat.apiValue], 0);
      }
      counts[cat] = val;
    }
    final timeline = <EmotionTimeBucket>[];
    final rawTimeline = json['timeline'];
    if (rawTimeline is List<Object?>) {
      for (final item in rawTimeline) {
        if (item is Map<Object?, Object?>) {
          timeline.add(EmotionTimeBucket.fromJson(_toStringMap(item)));
        }
      }
    }
    return AiEmotionSummary(
      totalLogs: _toInt(json['total_logs'], 0),
      alertCount: _toInt(json['alert_count'], 0),
      overThresholdRatePct: _toDouble(json['over_threshold_rate_pct'], 0.0),
      dominantTone: FunctionalEmotionCategory.fromApi(
        json['dominant_tone']?.toString() ?? 'calm',
      ),
      needsVerification: true,
      verificationNote: json['verification_note']?.toString() ??
          '要検証: Anthropic研究に基づく機能的感情分類',
      countsByTone: counts,
      timeline: timeline,
    );
  }
}

class AiEmotionDashboardSnapshot {
  const AiEmotionDashboardSnapshot({
    required this.threshold,
    required this.needsVerification,
    required this.verificationNote,
    required this.logs,
    required this.alerts,
    required this.summary,
  });

  const AiEmotionDashboardSnapshot.empty()
      : threshold = 0.7,
        needsVerification = true,
        verificationNote =
            '要検証: Anthropic研究に基づく機能的感情の外部表現分類であり、内部ニューロン監視ではありません。',
        logs = const <AiEmotionLogEntry>[],
        alerts = const <AiEmotionAlertEntry>[],
        summary = const AiEmotionSummary.empty();

  final double threshold;
  final bool needsVerification;
  final String verificationNote;
  final List<AiEmotionLogEntry> logs;
  final List<AiEmotionAlertEntry> alerts;
  final AiEmotionSummary summary;

  factory AiEmotionDashboardSnapshot.fromJson(
    final Map<String, Object?> json,
  ) {
    final logs = <AiEmotionLogEntry>[];
    final rawLogs = json['logs'];
    if (rawLogs is List<Object?>) {
      for (final item in rawLogs) {
        if (item is Map<Object?, Object?>) {
          logs.add(AiEmotionLogEntry.fromJson(_toStringMap(item)));
        }
      }
    }
    final alerts = <AiEmotionAlertEntry>[];
    final rawAlerts = json['alerts'];
    if (rawAlerts is List<Object?>) {
      for (final item in rawAlerts) {
        if (item is Map<Object?, Object?>) {
          alerts.add(AiEmotionAlertEntry.fromJson(_toStringMap(item)));
        }
      }
    }
    final rawSummary = json['summary'];
    final summary = rawSummary is Map<Object?, Object?>
        ? AiEmotionSummary.fromJson(_toStringMap(rawSummary))
        : const AiEmotionSummary.empty();

    return AiEmotionDashboardSnapshot(
      threshold: _toDouble(json['threshold'], 0.7),
      needsVerification: true,
      verificationNote:
          json['verification_note']?.toString() ?? summary.verificationNote,
      logs: logs,
      alerts: alerts,
      summary: summary,
    );
  }
}

abstract class AiEmotionRepository {
  Future<AiEmotionDashboardSnapshot> listDashboard({
    final FunctionalEmotionCategory? toneFilter,
    final double? threshold,
  });

  Future<AiEmotionDashboardSnapshot> seedDefaults({
    final double? threshold,
  });

  Future<AiEmotionLogEntry> classifyAndLog({
    required final String responseText,
    required final String model,
    final String sourceAction = 'manual_eval',
    final double? alertThreshold,
  });
}

Map<String, Object?> _toStringMap(final Map<Object?, Object?> raw) {
  final out = <String, Object?>{};
  for (final entry in raw.entries) {
    final key = entry.key?.toString();
    if (key != null) {
      out[key] = entry.value;
    }
  }
  return out;
}

double _toDouble(final Object? value, final double fallback) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _toInt(final Object? value, final int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
