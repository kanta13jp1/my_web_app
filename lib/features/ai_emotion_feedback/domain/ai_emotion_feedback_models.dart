/// Categories of inappropriate or overly emotional AI behavior (#2766).
enum EmotionFeedbackCategory {
  overEmotional(
    apiValue: 'over_emotional',
    shortLabel: '過剰感情',
    description: '感嘆符や誇張表現が多く冷静さを欠く応答',
  ),
  panic(
    apiValue: 'panic',
    shortLabel: 'パニック',
    description: '危機を煽り落ち着いて対処できないパニック応答',
  ),
  excessiveSympathy(
    apiValue: 'excessive_sympathy',
    shortLabel: '過剰同情',
    description: '過剰な感情移入や同情で機能的助言が曖昧な応答',
  ),
  inappropriateTone(
    apiValue: 'inappropriate_tone',
    shortLabel: '不適切口調',
    description: 'キャラクターやサポート文脈に不釣り合いな口調',
  );

  const EmotionFeedbackCategory({
    required this.apiValue,
    required this.shortLabel,
    required this.description,
  });

  final String apiValue;
  final String shortLabel;
  final String description;

  static EmotionFeedbackCategory fromApi(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final value in EmotionFeedbackCategory.values) {
      if (value.apiValue == normalized) {
        return value;
      }
    }
    return EmotionFeedbackCategory.inappropriateTone;
  }
}

/// Severity levels for AI functional emotion feedback (#2766).
enum EmotionFeedbackSeverity {
  low(apiValue: 'low', shortLabel: '軽微'),
  medium(apiValue: 'medium', shortLabel: '中程度'),
  high(apiValue: 'high', shortLabel: '重大');

  const EmotionFeedbackSeverity({
    required this.apiValue,
    required this.shortLabel,
  });

  final String apiValue;
  final String shortLabel;

  static EmotionFeedbackSeverity fromApi(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final value in EmotionFeedbackSeverity.values) {
      if (value.apiValue == normalized) {
        return value;
      }
    }
    return EmotionFeedbackSeverity.medium;
  }
}

/// Single AI emotion feedback record synced via Supabase hub_data (#2766).
class AiEmotionFeedbackEntry {
  const AiEmotionFeedbackEntry({
    required this.id,
    required this.category,
    required this.severity,
    required this.aiSnippet,
    required this.userComment,
    required this.sessionRef,
    required this.modelRef,
    required this.issueCreated,
    this.issueNumber,
    this.issueUrl,
    this.issueSkippedReason,
    this.submittedAt,
  });

  final String id;
  final EmotionFeedbackCategory category;
  final EmotionFeedbackSeverity severity;
  final String aiSnippet;
  final String userComment;
  final String sessionRef;
  final String modelRef;
  final bool issueCreated;
  final int? issueNumber;
  final String? issueUrl;
  final String? issueSkippedReason;
  final DateTime? submittedAt;
}

/// Aggregate counters for collected AI emotion feedback (#2766).
class AiEmotionFeedbackSummary {
  const AiEmotionFeedbackSummary({
    required this.totalCount,
    required this.highSeverityCount,
    required this.issueCreatedCount,
    this.byCategory = const <EmotionFeedbackCategory, int>{},
  });

  const AiEmotionFeedbackSummary.empty()
      : totalCount = 0,
        highSeverityCount = 0,
        issueCreatedCount = 0,
        byCategory = const <EmotionFeedbackCategory, int>{};

  final int totalCount;
  final int highSeverityCount;
  final int issueCreatedCount;
  final Map<EmotionFeedbackCategory, int> byCategory;

  factory AiEmotionFeedbackSummary.fromEntries(
    final List<AiEmotionFeedbackEntry> entries,
  ) {
    final counts = <EmotionFeedbackCategory, int>{
      for (final category in EmotionFeedbackCategory.values) category: 0,
    };
    var highCount = 0;
    var issueCount = 0;
    for (final entry in entries) {
      counts[entry.category] = (counts[entry.category] ?? 0) + 1;
      if (entry.severity == EmotionFeedbackSeverity.high) {
        highCount += 1;
      }
      if (entry.issueCreated) {
        issueCount += 1;
      }
    }
    return AiEmotionFeedbackSummary(
      totalCount: entries.length,
      highSeverityCount: highCount,
      issueCreatedCount: issueCount,
      byCategory: Map<EmotionFeedbackCategory, int>.unmodifiable(counts),
    );
  }
}

/// Exported NotebookLM knowledge-base intake package (#2766).
class NotebookLmIntakePackage {
  const NotebookLmIntakePackage({
    required this.notebookId,
    required this.notebookTitle,
    required this.exportedAt,
    required this.recordCount,
    required this.markdownSummary,
    required this.jsonBundleText,
  });

  final String notebookId;
  final String notebookTitle;
  final String exportedAt;
  final int recordCount;
  final String markdownSummary;
  final String jsonBundleText;
}

/// Snapshot returned by listing or seeding AI emotion feedback (#2766).
class AiEmotionFeedbackSnapshot {
  const AiEmotionFeedbackSnapshot({
    required this.entries,
    required this.summary,
    this.seededCount = 0,
  });

  final List<AiEmotionFeedbackEntry> entries;
  final AiEmotionFeedbackSummary summary;
  final int seededCount;
}

/// Abstract repository boundary for AI emotion feedback (#2766).
abstract class AiEmotionFeedbackRepository {
  Future<AiEmotionFeedbackSnapshot> fetchFeedbacks({
    final EmotionFeedbackCategory? categoryFilter,
    final int limit = 50,
  });

  Future<AiEmotionFeedbackEntry> submitFeedback({
    required final EmotionFeedbackCategory category,
    required final EmotionFeedbackSeverity severity,
    required final String aiSnippet,
    required final String userComment,
    final String sessionRef = '',
    final String modelRef = '',
  });

  Future<AiEmotionFeedbackSnapshot> seedDefaults();

  Future<NotebookLmIntakePackage> exportNotebookLmIntake({
    final int limit = 100,
  });
}
