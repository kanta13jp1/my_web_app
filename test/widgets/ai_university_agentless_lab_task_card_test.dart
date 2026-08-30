import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_university_agentless_lab_analytics.dart';
import 'package:my_web_app/widgets/ai_university_agentless_lab_task_card.dart';

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
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

  testWidgets('records nothing until explicit Start succeeds', (tester) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityAgentlessLabTaskCard(
              onStart: () async {
                starts += 1;
                return false;
              },
              onSubmit: (_) async => true,
            ),
          ),
        ),
      ),
    );

    expect(starts, 0);
    expect(find.byKey(const Key('agentless-lab-python')), findsNothing);
    await tapVisible(tester, find.byKey(const Key('agentless-lab-start')));
    await tester.pumpAndSettle();

    expect(starts, 1);
    expect(find.byKey(const Key('agentless-lab-python')), findsNothing);
  });

  testWidgets('collects measured fields and submits no manifest or text', (
    tester,
  ) async {
    AiUniversityAgentlessLabCompletion? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityAgentlessLabTaskCard(
              onStart: () async => true,
              onSubmit: (completion) async {
                submitted = completion;
                return true;
              },
            ),
          ),
        ),
      ),
    );

    await tapVisible(tester, find.byKey(const Key('agentless-lab-start')));
    await enter(tester, 'agentless-lab-python', '3.11.9');
    await enter(tester, 'agentless-lab-threads', '4');
    await enter(tester, 'agentless-lab-prompt-tokens', '1200');
    await enter(tester, 'agentless-lab-completion-tokens', '300');
    await enter(tester, 'agentless-lab-embedding-tokens', '0');
    await enter(tester, 'agentless-lab-predicted-cost', '0.50');
    await enter(tester, 'agentless-lab-actual-cost', '0.42');
    await enter(tester, 'agentless-lab-wall-time', '1800');
    await tapVisible(
      tester,
      find.byKey(const Key('agentless-lab-localization-yes')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('agentless-lab-regression-passed')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('agentless-lab-reproduction-passed')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('agentless-lab-test-resolved')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('agentless-lab-reproducibility-reproduced')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('agentless-lab-workplace-planned')),
    );
    await tapVisible(tester, find.byKey(const Key('agentless-lab-submit')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.pythonVersion, '3.11.9');
    expect(submitted!.maxThreads, 4);
    expect(submitted!.promptTokens, 1200);
    expect(submitted!.apiCostUsd, 0.42);
    expect(submitted!.testResult, 'resolved');
    expect(find.byKey(const Key('agentless-lab-submitted')), findsOneWidget);
    expect(find.textContaining('patch、issue本文'), findsOneWidget);
  });
}
