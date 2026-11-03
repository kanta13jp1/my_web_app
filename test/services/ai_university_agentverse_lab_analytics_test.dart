import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_university_agentverse_lab_analytics.dart';

void main() {
  AiUniversityAgentVerseRunMetrics metrics({
    int quality = 4,
    int wall = 120,
    int tokens = 2500,
    double cost = 0.02,
  }) =>
      AiUniversityAgentVerseRunMetrics(
        qualityScore: quality,
        wallTimeSeconds: wall,
        tokenCount: tokens,
        costUsd: cost,
      );

  AiUniversityAgentVerseLabCompletion completion({
    AiUniversityAgentVerseRunMetrics? single,
    String roleReason = 'quality_gate_failed',
  }) =>
      AiUniversityAgentVerseLabCompletion(
        singleAgent: single ?? metrics(),
        fixedRoleTeam: metrics(wall: 180, tokens: 5000, cost: 0.04),
        conditionalRoleTeam: metrics(
          wall: 240,
          tokens: 7200,
          cost: 0.06,
        ),
        roleAddReason: roleReason,
        rubricScore: 4,
        reproducibilityResult: 'reproduced',
        workplaceApplication: 'planned',
        completionSeconds: 900,
      );

  test('records only the fixed task and bounded anonymous evidence', () async {
    final rows = <Map<String, Object>>[];
    final analytics = AiUniversityAgentVerseLabAnalytics(
      writer: (row) async => rows.add(row),
    );

    expect(await analytics.recordStarted(), isTrue);
    expect(await analytics.recordImportChecked('succeeded'), isTrue);
    expect(await analytics.recordCompleted(completion()), isTrue);

    expect(rows, hasLength(3));
    expect(rows[0], {
      'event_name': 'lab_started',
      'task_version': 'agentverse_role_comparison_20260903_v1',
    });
    expect(rows[1]['import_outcome'], 'succeeded');
    expect(rows[2]['single_quality_score'], 4);
    expect(rows[2]['fixed_token_count'], 5000);
    expect(rows[2]['conditional_cost_usd'], 0.06);
    expect(rows[2]['role_add_reason'], 'quality_gate_failed');
    expect(
      rows.expand((row) => row.keys),
      everyElement(
        AiUniversityAgentVerseLabAnalytics.allowedPropertyNames.contains,
      ),
    );
    expect(rows.toString(), isNot(contains('prompt')));
    expect(rows.toString(), isNot(contains('user_id')));
    expect(rows.toString(), isNot(contains('session')));
  });

  test('rejects unknown enums and out-of-range run measurements', () async {
    var writes = 0;
    final analytics = AiUniversityAgentVerseLabAnalytics(
      writer: (_) async => writes += 1,
    );

    expect(await analytics.recordImportChecked('unknown'), isFalse);
    expect(
      await analytics.recordCompleted(
        completion(single: metrics(tokens: 0)),
      ),
      isFalse,
    );
    expect(
      await analytics.recordCompleted(completion(roleReason: 'free_text')),
      isFalse,
    );
    expect(writes, 0);
  });

  test('drops writer failures without throwing or retry identifiers', () async {
    final analytics = AiUniversityAgentVerseLabAnalytics(
      writer: (_) async => throw StateError('offline'),
    );

    expect(await analytics.recordStarted(), isFalse);
    expect(await analytics.recordImportChecked('failed'), isFalse);
    expect(await analytics.recordCompleted(completion()), isFalse);
  });
}
