import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/agent_gpa_dashboard_page.dart';

void main() {
  AgentGpaEvaluation evaluation({
    required String id,
    required String sourceType,
    required double gpa,
    DateTime? evaluatedAt,
  }) {
    return AgentGpaEvaluation(
      id: id,
      sourceType: sourceType,
      sourceId: '00000000-0000-4000-8000-0000000000$id',
      goalScore: gpa,
      planScore: gpa,
      actionScore: gpa,
      consistencyScore: gpa,
      gpa: gpa,
      rationaleShort:
          'Trace $id was evaluated without storing raw prompt data.',
      judgeModel: 'claude-sonnet-4-6',
      evaluatedAt: evaluatedAt,
      improvementSuggestions: gpa < 2.5
          ? const [
              AgentGpaSuggestion(
                type: 'prompt_edit',
                axis: 'plan',
                suggestion: 'Tighten the plan before rerun.',
              ),
            ]
          : const [],
    );
  }

  test('filterAgentGpaEvaluations filters low GPA and sorts by date', () {
    final oldLow = evaluation(
      id: '1111',
      sourceType: 'executive_chat',
      gpa: 1.8,
      evaluatedAt: DateTime.utc(2026, 5, 8),
    );
    final newLow = evaluation(
      id: '2222',
      sourceType: 'secretary_action',
      gpa: 2.1,
      evaluatedAt: DateTime.utc(2026, 5, 9),
    );
    final high = evaluation(
      id: '3333',
      sourceType: 'secretary_action',
      gpa: 3.7,
      evaluatedAt: DateTime.utc(2026, 5, 10),
    );

    final result = filterAgentGpaEvaluations(
      [
        oldLow,
        newLow,
        high,
      ],
      lowOnly: true,
    );

    expect(result.map((item) => item.id), ['2222', '1111']);
  });

  testWidgets('AgentGpaDashboardPage renders cards and reloads filters', (
    tester,
  ) async {
    final queries = <AgentGpaDashboardQuery>[];
    final items = [
      evaluation(
        id: '1111',
        sourceType: 'executive_chat',
        gpa: 1.8,
        evaluatedAt: DateTime.utc(2026, 5, 8, 10),
      ),
      evaluation(
        id: '2222',
        sourceType: 'secretary_action',
        gpa: 3.7,
        evaluatedAt: DateTime.utc(2026, 5, 9, 10),
      ),
    ];

    Future<List<AgentGpaEvaluation>> loader(
      AgentGpaDashboardQuery query,
    ) async {
      queries.add(query);
      return filterAgentGpaEvaluations(
        items,
        sourceType: query.sourceType,
        lowOnly: query.lowOnly,
      );
    }

    await tester.pumpWidget(
      MaterialApp(home: AgentGpaDashboardPage(loader: loader)),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Executive GPA'), findsWidgets);
    expect(find.text('3.70'), findsOneWidget);
    expect(queries.single.lowOnly, isFalse);

    await tester.tap(find.widgetWithText(FilterChip, 'Low GPA'));
    await tester.pumpAndSettle();

    expect(queries.last.lowOnly, isTrue);
    expect(find.text('1.80'), findsWidgets);
    expect(find.text('3.70'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Secretary'));
    await tester.pumpAndSettle();

    expect(queries.last.sourceType, 'secretary_action');
    expect(find.text('No GPA evaluations yet'), findsOneWidget);
  });
}
