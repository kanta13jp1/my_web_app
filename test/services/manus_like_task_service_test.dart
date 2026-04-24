import 'package:my_web_app/services/manus_like_task_service.dart';
import 'package:test/test.dart';

void main() {
  test('buildPlan routes finance objectives to CFO-led execution', () {
    final plan = ManusLikeTaskService.buildPlan(
      objective: '固定費と広告費のコストを下げて利益率を改善する',
      availableAgentSlugs: const {
        'secretary',
        'planning-director',
        'cfo',
        'accountant',
      },
    );

    expect(plan.steps, hasLength(5));
    expect(plan.strategyLabel, contains('財務'));
    expect(plan.steps[2].agentSlug, 'cfo');
    expect(plan.steps[3].agentSlug, 'accountant');
    expect(plan.steps.last.dependsOn, containsAll([1, 2, 3, 4]));
  });

  test('buildPlan keeps an executable fallback when specialists are missing',
      () {
    final plan = ManusLikeTaskService.buildPlan(
      objective: '新しい画面のUXを改善してユーザーの迷いを減らす',
      availableAgentSlugs: const {'secretary', 'planning-director'},
    );

    expect(plan.steps, hasLength(5));
    expect(
      plan.steps.map((step) => step.agentSlug),
      everyElement(anyOf('secretary', 'planning-director')),
    );
    expect(plan.executionSummary, contains('Manus-like multi-step execution'));
  });
}
