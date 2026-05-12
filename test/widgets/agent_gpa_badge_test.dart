import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/agent_gpa_dashboard_page.dart';
import 'package:my_web_app/widgets/agent_gpa_badge.dart';

void main() {
  AgentGpaEvaluation evaluation({
    required String id,
    required String sourceType,
    required String sourceId,
    required double gpa,
    required DateTime evaluatedAt,
  }) {
    return AgentGpaEvaluation(
      id: id,
      sourceType: sourceType,
      sourceId: sourceId,
      goalScore: gpa,
      planScore: gpa,
      actionScore: gpa,
      consistencyScore: gpa,
      gpa: gpa,
      rationaleShort: 'GPA rationale for $id',
      improvementSuggestions: const [],
      judgeModel: 'test-judge',
      evaluatedAt: evaluatedAt,
    );
  }

  test('selectAgentGpaBadgeEvaluation picks latest matching trace', () {
    final selected = selectAgentGpaBadgeEvaluation(
      [
        evaluation(
          id: 'old',
          sourceType: 'executive_chat',
          sourceId: 'trace-1',
          gpa: 2.4,
          evaluatedAt: DateTime.parse('2026-05-09T00:00:00Z'),
        ),
        evaluation(
          id: 'latest',
          sourceType: 'executive_chat',
          sourceId: 'trace-1',
          gpa: 3.7,
          evaluatedAt: DateTime.parse('2026-05-10T00:00:00Z'),
        ),
        evaluation(
          id: 'other',
          sourceType: 'secretary_action',
          sourceId: 'trace-1',
          gpa: 4,
          evaluatedAt: DateTime.parse('2026-05-11T00:00:00Z'),
        ),
      ],
      sourceType: 'executive_chat',
      sourceId: 'trace-1',
    );

    expect(selected?.id, 'latest');
  });

  testWidgets('AgentGpaBadge renders GPA and opens details', (tester) async {
    Future<List<AgentGpaEvaluation>> loader(
      AgentGpaDashboardQuery query,
    ) async {
      expect(query.sourceType, 'executive_meeting');
      return [
        evaluation(
          id: 'meeting-gpa',
          sourceType: 'executive_meeting',
          sourceId: 'meeting-1',
          gpa: 3.7,
          evaluatedAt: DateTime.parse('2026-05-10T00:00:00Z'),
        ),
      ];
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AgentGpaBadge(
              sourceType: 'executive_meeting',
              sourceId: 'meeting-1',
              loader: loader,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPA 3.7'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('agent_gpa_badge_executive_meeting_meeting-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Emergency meeting GPA'), findsOneWidget);
    expect(find.text('GPA 3.7'), findsWidgets);
    expect(find.text('GPA rationale for meeting-gpa'), findsOneWidget);
  });
}
