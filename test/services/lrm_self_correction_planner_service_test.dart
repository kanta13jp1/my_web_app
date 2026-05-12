import 'package:my_web_app/services/lrm_self_correction_planner_service.dart';
import 'package:test/test.dart';

void main() {
  test('buildPlan returns Goal-Plan-Action JSON with self review', () {
    final plan = LrmSelfCorrectionPlannerService.buildPlan(
      request: 'Reduce monthly cloud cost by 20% before the May review',
      availableAgentSlugs: const {
        'secretary',
        'planning-director',
        'cfo',
        'accountant',
      },
      now: DateTime.utc(2026, 5, 7),
    );

    final json = plan.toJson();

    expect(plan.strategyLabel, 'finance and budget planning');
    expect(json['goal'], isA<Map<String, dynamic>>());
    expect(json['plan'], isA<List<dynamic>>());
    expect(json['actions'], isA<List<dynamic>>());
    expect(json['self_review'], isA<Map<String, dynamic>>());
    expect(
      plan.plan.map((step) => step.phase),
      containsAll(['goal', 'plan', 'action', 'self_review']),
    );
    expect(
      plan.actions.map((action) => action.kind),
      containsAll(['app_task', 'github_issue_draft', 'wbs_draft']),
    );
    expect(plan.plan[2].agentSlug, 'cfo');
  });

  test('buildPlan flags dangerous or external operations for approval', () {
    final plan = LrmSelfCorrectionPlannerService.buildPlan(
      request: 'Deploy and publish the new payment flow with the secret key',
      availableAgentSlugs: const {
        'secretary',
        'planning-director',
        'cto',
        'legal-director',
      },
      now: DateTime.utc(2026, 5, 7),
    );

    expect(plan.requiresApproval, isTrue);
    expect(
      plan.selfReview.safetyChecks.join(' '),
      contains('CEO approval required'),
    );
    expect(plan.actions.first.nextAction, contains('Wait for CEO approval'));
  });

  test('buildPlan stays executable with a small agent roster', () {
    final plan = LrmSelfCorrectionPlannerService.buildPlan(
      request: 'Turn the customer support process into an app task',
      availableAgentSlugs: const {'secretary', 'planning-director'},
      now: DateTime.utc(2026, 5, 7),
    );

    expect(plan.plan, hasLength(4));
    expect(
      plan.plan.map((step) => step.agentSlug),
      everyElement(anyOf('secretary', 'planning-director')),
    );
    expect(plan.executionSummary, contains('LRM self-correcting GPA plan'));
  });
}
