import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_suggested_action.dart';

typedef AiActionTelemetryRecorder = Future<bool> Function(
  AiSuggestedActionEvent event,
);

class AiActionEngagementEvaluation {
  const AiActionEngagementEvaluation({
    required this.userId,
    required this.impressionCount,
    required this.clickCount,
    required this.ctr,
    required this.consecutiveIgnoredImpressions,
    required this.suppressionThreshold,
    required this.shouldSuppressActionTools,
  });

  final String userId;
  final int impressionCount;
  final int clickCount;
  final double ctr;
  final int consecutiveIgnoredImpressions;
  final int suppressionThreshold;
  final bool shouldSuppressActionTools;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_id': userId,
      'impression_count': impressionCount,
      'click_count': clickCount,
      'ctr': ctr,
      'consecutive_ignored_impressions': consecutiveIgnoredImpressions,
      'suppression_threshold': suppressionThreshold,
      'should_suppress_action_tools': shouldSuppressActionTools,
    };
  }
}

class AiSuggestedActionMonitorService {
  static const String defaultPrefsKey = 'ai_suggested_action_events_v1';
  static const int maxRetainedEvents = 200;
  static const Set<String> defaultActionToolNames = <String>{
    'suggested_actions',
    'ui_action',
    'narrative_choice',
    'scene_transition',
    'generic_narrative_choice',
  };

  final String prefsKey;
  final AiActionTelemetryRecorder? _telemetryRecorder;

  const AiSuggestedActionMonitorService({
    this.prefsKey = defaultPrefsKey,
    AiActionTelemetryRecorder? telemetryRecorder,
  }) : _telemetryRecorder = telemetryRecorder;

  Future<List<AiSuggestedActionEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <AiSuggestedActionEvent>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <AiSuggestedActionEvent>[];
      }
      final events = decoded
          .whereType<Map>()
          .map(
            (item) => AiSuggestedActionEvent.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
      events.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return events;
    } catch (_) {
      return const <AiSuggestedActionEvent>[];
    }
  }

  Future<AiSuggestedActionEvent> recordActionEvent({
    required AiSuggestedAction action,
    required String eventKind,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now().toUtc();
    final normalizedKind = eventKind == 'click' ? 'click' : 'impression';
    final reason = action.deceptionReason;
    final event = AiSuggestedActionEvent(
      id: '${action.id}_${normalizedKind}_${timestamp.microsecondsSinceEpoch}',
      actionId: action.id,
      label: action.label,
      actionType: action.type,
      rawActionType: action.rawActionType,
      eventKind: normalizedKind,
      contextExcerpt: action.contextExcerpt,
      flaggedDeception: reason != null,
      deceptionReason: reason,
      recordedAt: timestamp,
    );

    if (_telemetryRecorder != null) {
      try {
        await _telemetryRecorder(event);
      } catch (_) {
        // Fail-open: telemetry failures must never break action rendering.
      }
    }

    final existing = await loadEvents();
    final updated = <AiSuggestedActionEvent>[event, ...existing]
        .take(maxRetainedEvents)
        .toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
    return event;
  }

  Future<void> clearEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  List<AiActionTypeAuditSummary> buildTypeSummaries(
    List<AiSuggestedActionEvent> events,
  ) {
    final impressions = <AiSuggestedActionType, int>{};
    final clicks = <AiSuggestedActionType, int>{};
    final deceptions = <AiSuggestedActionType, int>{};

    for (final event in events) {
      if (event.eventKind == 'click') {
        clicks[event.actionType] = (clicks[event.actionType] ?? 0) + 1;
      } else {
        impressions[event.actionType] =
            (impressions[event.actionType] ?? 0) + 1;
      }
      if (event.flaggedDeception) {
        deceptions[event.actionType] = (deceptions[event.actionType] ?? 0) + 1;
      }
    }

    final summaries = <AiActionTypeAuditSummary>[];
    for (final type in AiSuggestedActionType.values) {
      final imp = impressions[type] ?? 0;
      final clk = clicks[type] ?? 0;
      final dec = deceptions[type] ?? 0;
      if (imp > 0 || clk > 0) {
        summaries.add(
          AiActionTypeAuditSummary(
            actionType: type,
            impressionCount: imp,
            clickCount: clk,
            deceptionCount: dec,
          ),
        );
      }
    }
    summaries.sort((a, b) => b.totalEvents.compareTo(a.totalEvents));
    return summaries;
  }

  List<AiSuggestedActionEvent> filterEvents(
    List<AiSuggestedActionEvent> events, {
    String query = '',
    AiSuggestedActionType? typeFilter,
    bool onlyFlaggedDeception = false,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return events.where((event) {
      if (typeFilter != null && event.actionType != typeFilter) {
        return false;
      }
      if (onlyFlaggedDeception && !event.flaggedDeception) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final haystack = <String>[
        event.label,
        event.rawActionType,
        event.actionType.wireValue,
        event.actionType.displayName,
        event.contextExcerpt,
        event.deceptionReason ?? '',
      ].join('\n').toLowerCase();
      return haystack.contains(normalizedQuery);
    }).toList(growable: false);
  }

  AiActionEngagementEvaluation evaluateUserEngagement(
    List<AiSuggestedActionEvent> events, {
    String userId = 'local',
    int consecutiveIgnoreThreshold = 5,
  }) {
    final sorted = List<AiSuggestedActionEvent>.from(events)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    var impressions = 0;
    var clicks = 0;
    var consecutiveIgnored = 0;
    var streakBroken = false;

    for (final event in sorted) {
      if (event.eventKind == 'click') {
        clicks += 1;
        streakBroken = true;
      } else {
        impressions += 1;
        if (!streakBroken) {
          consecutiveIgnored += 1;
        }
      }
    }

    final ctr = impressions == 0 ? 0.0 : clicks / impressions;
    final shouldSuppress =
        consecutiveIgnored >= consecutiveIgnoreThreshold && impressions > 0;
    return AiActionEngagementEvaluation(
      userId: userId,
      impressionCount: impressions,
      clickCount: clicks,
      ctr: ctr,
      consecutiveIgnoredImpressions: consecutiveIgnored,
      suppressionThreshold: consecutiveIgnoreThreshold,
      shouldSuppressActionTools: shouldSuppress,
    );
  }

  Future<AiActionEngagementEvaluation> fetchUserEngagementSummary({
    String userId = 'local',
    int consecutiveIgnoreThreshold = 5,
  }) async {
    final events = await loadEvents();
    return evaluateUserEngagement(
      events,
      userId: userId,
      consecutiveIgnoreThreshold: consecutiveIgnoreThreshold,
    );
  }

  List<Map<String, dynamic>> filterLlmToolsForEngagement(
    List<Map<String, dynamic>> tools,
    AiActionEngagementEvaluation evaluation, {
    Set<String> actionToolNames = defaultActionToolNames,
  }) {
    if (!evaluation.shouldSuppressActionTools) {
      return List<Map<String, dynamic>>.from(tools);
    }
    return tools.where((tool) {
      final topName = tool['name']?.toString().trim() ?? '';
      final fn = tool['function'];
      final nestedName = fn is Map ? (fn['name']?.toString().trim() ?? '') : '';
      final resolvedName = topName.isNotEmpty ? topName : nestedName;
      return !actionToolNames.contains(resolvedName);
    }).toList(growable: false);
  }
}
