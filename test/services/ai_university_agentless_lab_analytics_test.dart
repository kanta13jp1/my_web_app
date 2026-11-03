import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_university_agentless_lab_analytics.dart';

AiUniversityAgentlessLabCompletion validCompletion({
  String pythonVersion = '3.11.9',
  int maxThreads = 4,
  int promptTokens = 1200,
  int completionTokens = 300,
  int embeddingTokens = 0,
  double apiCostUsd = 0.42,
  double predictedApiCostUsd = 0.5,
  int wallTimeSeconds = 1800,
  String regressionResult = 'passed',
}) {
  return AiUniversityAgentlessLabCompletion(
    pythonVersion: pythonVersion,
    maxThreads: maxThreads,
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    embeddingTokens: embeddingTokens,
    apiCostUsd: apiCostUsd,
    predictedApiCostUsd: predictedApiCostUsd,
    wallTimeSeconds: wallTimeSeconds,
    localizationCorrect: true,
    regressionResult: regressionResult,
    reproductionResult: 'passed',
    testResult: 'resolved',
    reproducibilityResult: 'reproduced',
    workplaceApplication: 'planned',
  );
}

void main() {
  test('start is explicit and completion emits only bounded manifest columns',
      () async {
    final rows = <Map<String, Object>>[];
    final analytics = AiUniversityAgentlessLabAnalytics(
      writer: (row) async => rows.add(row),
    );

    expect(rows, isEmpty);
    expect(await analytics.recordStarted(), isTrue);
    expect(await analytics.recordCompleted(validCompletion()), isTrue);

    expect(rows.first, <String, Object>{
      'event_name': 'lab_started',
      'task_version': 'agentless_lab_20260830_v1',
    });
    expect(rows.last['agentless_release'], 'v1.5.0');
    expect(rows.last['instance_id'], 'django__django-10914');
    expect(rows.last['candidate_count'], 4);
    expect(rows.last['python_version'], '3.11.9');
    expect(rows.last['api_cost_usd'], 0.42);
    expect(
      rows.last.keys,
      everyElement(
        AiUniversityAgentlessLabAnalytics.allowedPropertyNames.contains,
      ),
    );
    for (final prohibited in <String>[
      'user_id',
      'session_id',
      'ip_address',
      'url',
      'patch',
      'issue_text',
      'free_text',
    ]) {
      expect(rows.last, isNot(contains(prohibited)));
    }
  });

  test('invalid versions, ranges, placeholders, and enums never write',
      () async {
    var writes = 0;
    final analytics = AiUniversityAgentlessLabAnalytics(
      writer: (_) async => writes += 1,
    );

    final invalid = <AiUniversityAgentlessLabCompletion>[
      validCompletion(pythonVersion: '3.12.0'),
      validCompletion(maxThreads: 0),
      validCompletion(maxThreads: 11),
      validCompletion(promptTokens: 0, completionTokens: 0),
      validCompletion(promptTokens: -1),
      validCompletion(apiCostUsd: 0),
      validCompletion(apiCostUsd: double.nan),
      validCompletion(predictedApiCostUsd: -0.01),
      validCompletion(wallTimeSeconds: 0),
      validCompletion(wallTimeSeconds: 3601),
      validCompletion(regressionResult: 'unknown'),
    ];
    for (final completion in invalid) {
      expect(await analytics.recordCompleted(completion), isFalse);
    }
    expect(writes, 0);
  });

  test('writer failure is swallowed and reported as not recorded', () async {
    final analytics = AiUniversityAgentlessLabAnalytics(
      writer: (_) async => throw StateError('offline'),
    );

    expect(await analytics.recordStarted(), isFalse);
    expect(await analytics.recordCompleted(validCompletion()), isFalse);
  });
}
