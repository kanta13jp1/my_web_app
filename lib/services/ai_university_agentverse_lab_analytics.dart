import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AiUniversityAgentVerseLabWriter = Future<void> Function(
  Map<String, Object> row,
);

class AiUniversityAgentVerseRunMetrics {
  const AiUniversityAgentVerseRunMetrics({
    required this.qualityScore,
    required this.wallTimeSeconds,
    required this.tokenCount,
    required this.costUsd,
  });

  final int qualityScore;
  final int wallTimeSeconds;
  final int tokenCount;
  final double costUsd;
}

class AiUniversityAgentVerseLabCompletion {
  const AiUniversityAgentVerseLabCompletion({
    required this.singleAgent,
    required this.fixedRoleTeam,
    required this.conditionalRoleTeam,
    required this.roleAddReason,
    required this.rubricScore,
    required this.reproducibilityResult,
    required this.workplaceApplication,
    required this.completionSeconds,
  });

  final AiUniversityAgentVerseRunMetrics singleAgent;
  final AiUniversityAgentVerseRunMetrics fixedRoleTeam;
  final AiUniversityAgentVerseRunMetrics conditionalRoleTeam;
  final String roleAddReason;
  final int rubricScore;
  final String reproducibilityResult;
  final String workplaceApplication;
  final int completionSeconds;
}

/// Privacy-minimal analytics for the fixed AgentVerse comparison lab.
///
/// The API accepts only finite enums and bounded measurements. Prompts,
/// generated output, error text, learner identity, session IDs, and URLs have
/// no input path.
class AiUniversityAgentVerseLabAnalytics {
  const AiUniversityAgentVerseLabAnalytics({
    AiUniversityAgentVerseLabWriter? writer,
  }) : _writer = writer;

  factory AiUniversityAgentVerseLabAnalytics.supabase(SupabaseClient client) {
    return AiUniversityAgentVerseLabAnalytics(
      writer: (row) async {
        await client.from('ai_university_agentverse_lab_events').insert(row);
      },
    );
  }

  static const taskVersion = 'agentverse_role_comparison_20260903_v1';
  static const maxTokenCount = 10000000;
  static const importOutcomes = {'succeeded', 'failed'};
  static const roleAddReasons = {
    'missing_expertise',
    'quality_gate_failed',
    'conflict_resolution',
    'no_role_added',
  };
  static const reproducibilityResults = {
    'reproduced',
    'not_reproduced',
    'not_checked',
  };
  static const workplaceApplications = {'applied', 'planned', 'not_yet'};
  static const allowedPropertyNames = <String>{
    'event_name',
    'task_version',
    'import_outcome',
    'single_quality_score',
    'single_wall_seconds',
    'single_token_count',
    'single_cost_usd',
    'fixed_quality_score',
    'fixed_wall_seconds',
    'fixed_token_count',
    'fixed_cost_usd',
    'conditional_quality_score',
    'conditional_wall_seconds',
    'conditional_token_count',
    'conditional_cost_usd',
    'role_add_reason',
    'rubric_score',
    'reproducibility_result',
    'workplace_application',
    'completion_seconds',
  };

  final AiUniversityAgentVerseLabWriter? _writer;

  Future<bool> recordStarted() => _record(<String, Object>{
        'event_name': 'lab_started',
        'task_version': taskVersion,
      });

  Future<bool> recordImportChecked(String outcome) {
    if (!importOutcomes.contains(outcome)) return Future.value(false);
    return _record(<String, Object>{
      'event_name': 'import_checked',
      'task_version': taskVersion,
      'import_outcome': outcome,
    });
  }

  Future<bool> recordCompleted(AiUniversityAgentVerseLabCompletion value) {
    if (!_isValid(value)) return Future.value(false);

    return _record(<String, Object>{
      'event_name': 'lab_completed',
      'task_version': taskVersion,
      ..._metrics('single', value.singleAgent),
      ..._metrics('fixed', value.fixedRoleTeam),
      ..._metrics('conditional', value.conditionalRoleTeam),
      'role_add_reason': value.roleAddReason,
      'rubric_score': value.rubricScore,
      'reproducibility_result': value.reproducibilityResult,
      'workplace_application': value.workplaceApplication,
      'completion_seconds': value.completionSeconds,
    });
  }

  static Map<String, Object> _metrics(
    String prefix,
    AiUniversityAgentVerseRunMetrics value,
  ) =>
      <String, Object>{
        '${prefix}_quality_score': value.qualityScore,
        '${prefix}_wall_seconds': value.wallTimeSeconds,
        '${prefix}_token_count': value.tokenCount,
        '${prefix}_cost_usd': value.costUsd,
      };

  static bool _isValid(AiUniversityAgentVerseLabCompletion value) {
    return <AiUniversityAgentVerseRunMetrics>[
          value.singleAgent,
          value.fixedRoleTeam,
          value.conditionalRoleTeam,
        ].every(_validMetrics) &&
        roleAddReasons.contains(value.roleAddReason) &&
        value.rubricScore >= 0 &&
        value.rubricScore <= 4 &&
        reproducibilityResults.contains(value.reproducibilityResult) &&
        workplaceApplications.contains(value.workplaceApplication) &&
        value.completionSeconds >= 1 &&
        value.completionSeconds <= 7200;
  }

  static bool _validMetrics(AiUniversityAgentVerseRunMetrics value) {
    return value.qualityScore >= 0 &&
        value.qualityScore <= 4 &&
        value.wallTimeSeconds >= 1 &&
        value.wallTimeSeconds <= 3600 &&
        value.tokenCount >= 1 &&
        value.tokenCount <= maxTokenCount &&
        value.costUsd.isFinite &&
        value.costUsd >= 0 &&
        value.costUsd <= 100;
  }

  Future<bool> _record(Map<String, Object> row) async {
    final writer = _writer;
    if (writer == null || !row.keys.every(allowedPropertyNames.contains)) {
      return false;
    }
    try {
      await writer(row);
      return true;
    } catch (_) {
      debugPrint('AI University AgentVerse lab event was dropped.');
      return false;
    }
  }
}
