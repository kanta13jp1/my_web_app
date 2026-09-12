import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_university_agentverse_lab_analytics.dart';
import 'package:my_web_app/widgets/ai_university_agentverse_lab_task_card.dart';

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(
    WidgetTester tester,
    String key,
    String value,
  ) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pump();
  }

  testWidgets('records nothing before explicit start and import consent', (
    tester,
  ) async {
    var starts = 0;
    var imports = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityAgentVerseLabTaskCard(
              onStart: () async {
                starts += 1;
                return true;
              },
              onImportChecked: (_) async {
                imports += 1;
                return true;
              },
              onSubmit: (_) async => true,
            ),
          ),
        ),
      ),
    );

    expect(starts, 0);
    expect(imports, 0);
    expect(find.byKey(const Key('agentverse-lab-submit')), findsNothing);
    await tapVisible(tester, find.byKey(const Key('agentverse-lab-start')));

    expect(starts, 1);
    expect(imports, 0);
    expect(
      find.byKey(const Key('agentverse-lab-import-submit')),
      findsOneWidget,
    );
  });

  testWidgets('submits the three bounded run comparisons only', (
    tester,
  ) async {
    AiUniversityAgentVerseLabCompletion? submitted;
    final importOutcomes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityAgentVerseLabTaskCard(
              onStart: () async => true,
              onImportChecked: (outcome) async {
                importOutcomes.add(outcome);
                return true;
              },
              onSubmit: (completion) async {
                submitted = completion;
                return true;
              },
            ),
          ),
        ),
      ),
    );

    await tapVisible(tester, find.byKey(const Key('agentverse-lab-start')));
    await tapVisible(
      tester,
      find.byKey(const Key('agentverse-lab-import-succeeded')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('agentverse-lab-import-submit')),
    );

    for (final prefix in <String>['single', 'fixed', 'conditional']) {
      await enter(tester, 'agentverse-lab-$prefix-quality', '4');
      await enter(tester, 'agentverse-lab-$prefix-wall', '120');
      await enter(tester, 'agentverse-lab-$prefix-tokens', '2500');
      await enter(tester, 'agentverse-lab-$prefix-cost', '0.02');
    }
    await tapVisible(
      tester,
      find.byKey(
        const Key('agentverse-lab-role-reason-quality_gate_failed'),
      ),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('agentverse-lab-rubric-4')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('agentverse-lab-reproducibility-reproduced')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('agentverse-lab-workplace-planned')),
    );
    await tapVisible(tester, find.byKey(const Key('agentverse-lab-submit')));

    expect(importOutcomes, ['succeeded']);
    expect(submitted, isNotNull);
    expect(submitted!.singleAgent.qualityScore, 4);
    expect(submitted!.fixedRoleTeam.tokenCount, 2500);
    expect(submitted!.conditionalRoleTeam.costUsd, 0.02);
    expect(submitted!.roleAddReason, 'quality_gate_failed');
    expect(submitted!.rubricScore, 4);
    expect(submitted!.completionSeconds, greaterThanOrEqualTo(1));
    expect(
      find.byKey(const Key('agentverse-lab-submitted')),
      findsOneWidget,
    );
    expect(find.textContaining('個人情報は送信しません'), findsOneWidget);
  });
}
