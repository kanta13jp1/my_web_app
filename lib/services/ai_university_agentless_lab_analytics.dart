import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AiUniversityAgentlessLabWriter = Future<void> Function(
  Map<String, Object> row,
);

class AiUniversityAgentlessLabCompletion {
  const AiUniversityAgentlessLabCompletion({
    required this.pythonVersion,
    required this.maxThreads,
    required this.promptTokens,
    required this.completionTokens,
    required this.embeddingTokens,
    required this.apiCostUsd,
    required this.predictedApiCostUsd,
    required this.wallTimeSeconds,
    required this.localizationCorrect,
    required this.regressionResult,
    required this.reproductionResult,
    required this.testResult,
    required this.reproducibilityResult,
    required this.workplaceApplication,
  });

  final String pythonVersion;
  final int maxThreads;
  final int promptTokens;
  final int completionTokens;
  final int embeddingTokens;
  final double apiCostUsd;
  final double predictedApiCostUsd;
  final int wallTimeSeconds;
  final bool localizationCorrect;
  final String regressionResult;
  final String reproductionResult;
  final String testResult;
  final String reproducibilityResult;
  final String workplaceApplication;
}

/// Privacy-minimal analytics for the single fixed Agentless lab cohort.
///
/// Course identity is compile-time fixed. The API accepts only bounded numeric,
/// boolean, and finite-enum outcomes; it has no learner text or identifier path.
class AiUniversityAgentlessLabAnalytics {
  const AiUniversityAgentlessLabAnalytics({
    AiUniversityAgentlessLabWriter? writer,
  }) : _writer = writer;

  factory AiUniversityAgentlessLabAnalytics.supabase(SupabaseClient client) {
    return AiUniversityAgentlessLabAnalytics(
      writer: (row) async {
        await client.from('ai_university_agentless_lab_events').insert(row);
      },
    );
  }

  static const taskVersion = 'agentless_lab_20260830_v1';
  static const agentlessRelease = 'v1.5.0';
  static const agentlessRevision = 'b150f28465a77a81a7f4776384957a4271f5bd69';
  static const dataset = 'princeton-nlp/SWE-bench_Lite';
  static const datasetRevision = '6ec7bb89b9342f664a54a6e0a6ea6501d3437cc2';
  static const instanceId = 'django__django-10914';
  static const model = 'gpt-4o-2024-05-13';
  static const candidateCount = 4;
  static const maxTokenCount = 100000000;

  static const regressionResults = {'passed', 'failed', 'not_run'};
  static const reproductionResults = {'passed', 'failed', 'not_run'};
  static const testResults = {'resolved', 'unresolved', 'not_run'};
  static const reproducibilityResults = {
    'reproduced',
    'not_reproduced',
    'not_checked',
  };
  static const workplaceApplications = {'applied', 'planned', 'not_yet'};

  static const allowedPropertyNames = <String>{
    'event_name',
    'task_version',
    'python_version',
    'agentless_release',
    'agentless_revision',
    'dataset',
    'dataset_revision',
    'instance_id',
    'model',
    'candidate_count',
    'max_threads',
    'prompt_tokens',
    'completion_tokens',
    'embedding_tokens',
    'api_cost_usd',
    'predicted_api_cost_usd',
    'wall_time_seconds',
    'localization_correct',
    'regression_result',
    'reproduction_result',
    'test_result',
    'reproducibility_result',
    'workplace_application',
  };

  final AiUniversityAgentlessLabWriter? _writer;

  Future<bool> recordStarted() => _record(<String, Object>{
        'event_name': 'lab_started',
        'task_version': taskVersion,
      });

  Future<bool> recordCompleted(AiUniversityAgentlessLabCompletion completion) {
    if (!_isValid(completion)) return Future.value(false);

    return _record(<String, Object>{
      'event_name': 'lab_completed',
      'task_version': taskVersion,
      'python_version': completion.pythonVersion,
      'agentless_release': agentlessRelease,
      'agentless_revision': agentlessRevision,
      'dataset': dataset,
      'dataset_revision': datasetRevision,
      'instance_id': instanceId,
      'model': model,
      'candidate_count': candidateCount,
      'max_threads': completion.maxThreads,
      'prompt_tokens': completion.promptTokens,
      'completion_tokens': completion.completionTokens,
      'embedding_tokens': completion.embeddingTokens,
      'api_cost_usd': completion.apiCostUsd,
      'predicted_api_cost_usd': completion.predictedApiCostUsd,
      'wall_time_seconds': completion.wallTimeSeconds,
      'localization_correct': completion.localizationCorrect,
      'regression_result': completion.regressionResult,
      'reproduction_result': completion.reproductionResult,
      'test_result': completion.testResult,
      'reproducibility_result': completion.reproducibilityResult,
      'workplace_application': completion.workplaceApplication,
    });
  }

  static bool _isValid(AiUniversityAgentlessLabCompletion value) {
    final tokenCounts = <int>[
      value.promptTokens,
      value.completionTokens,
      value.embeddingTokens,
    ];
    return RegExp(r'^3[.]11[.][0-9]+$').hasMatch(value.pythonVersion) &&
        value.maxThreads >= 1 &&
        value.maxThreads <= 10 &&
        tokenCounts.every((count) => count >= 0 && count <= maxTokenCount) &&
        value.promptTokens + value.completionTokens > 0 &&
        value.apiCostUsd.isFinite &&
        value.apiCostUsd > 0 &&
        value.apiCostUsd <= 100 &&
        value.predictedApiCostUsd.isFinite &&
        value.predictedApiCostUsd >= 0 &&
        value.predictedApiCostUsd <= 100 &&
        value.wallTimeSeconds >= 1 &&
        value.wallTimeSeconds <= 3600 &&
        regressionResults.contains(value.regressionResult) &&
        reproductionResults.contains(value.reproductionResult) &&
        testResults.contains(value.testResult) &&
        reproducibilityResults.contains(value.reproducibilityResult) &&
        workplaceApplications.contains(value.workplaceApplication);
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
      debugPrint('AI University Agentless lab event was dropped.');
      return false;
    }
  }
}
