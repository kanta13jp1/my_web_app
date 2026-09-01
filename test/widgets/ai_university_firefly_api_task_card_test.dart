import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/ai_university_firefly_api_task_card.dart';

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Widget subject(AiUniversityFireflyApiTaskSubmit onSubmit) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityFireflyApiTaskCard(onSubmit: onSubmit),
          ),
        ),
      );

  testWidgets('requires the complete security and operations lab',
      (tester) async {
    await tester.pumpWidget(
      subject(
        ({
          required correctAnswers,
          required selfRating,
          required learnerRole,
          required firstCallSucceeded,
          required secretHandlingPassed,
          required apiSelectionPassed,
          required non2xxRecoveryPassed,
          required estimatedDailyRequests,
          required completionSeconds,
        }) async =>
            true,
      ),
    );

    final submit = find.byKey(const Key('firefly-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tapVisible(tester, find.byKey(const Key('firefly-role-developer')));
    await tapVisible(tester, find.byKey(const Key('firefly-q0-o1')));
    await tapVisible(tester, find.byKey(const Key('firefly-q1-o0')));
    await tapVisible(tester, find.byKey(const Key('firefly-q2-o1')));
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-first-call-success')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-single-batch-completed')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-production-checklist-completed')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-daily-requests-500')),
    );
    await tapVisible(tester, find.byKey(const Key('firefly-rating-4')));

    await tester.ensureVisible(submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('submits only bounded role-level outcome metrics',
      (tester) async {
    Map<String, Object>? submitted;
    await tester.pumpWidget(
      subject(({
        required correctAnswers,
        required selfRating,
        required learnerRole,
        required firstCallSucceeded,
        required secretHandlingPassed,
        required apiSelectionPassed,
        required non2xxRecoveryPassed,
        required estimatedDailyRequests,
        required completionSeconds,
      }) async {
        submitted = <String, Object>{
          'correctAnswers': correctAnswers,
          'selfRating': selfRating,
          'learnerRole': learnerRole,
          'firstCallSucceeded': firstCallSucceeded,
          'secretHandlingPassed': secretHandlingPassed,
          'apiSelectionPassed': apiSelectionPassed,
          'non2xxRecoveryPassed': non2xxRecoveryPassed,
          'estimatedDailyRequests': estimatedDailyRequests,
          'completionSeconds': completionSeconds,
        };
        return true;
      }),
    );

    await tapVisible(tester, find.byKey(const Key('firefly-role-operations')));
    await tapVisible(tester, find.byKey(const Key('firefly-q0-o1')));
    await tapVisible(tester, find.byKey(const Key('firefly-q1-o0')));
    await tapVisible(tester, find.byKey(const Key('firefly-q2-o1')));
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-first-call-success')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-single-batch-completed')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-production-checklist-completed')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-daily-requests-500')),
    );
    await tapVisible(tester, find.byKey(const Key('firefly-rating-5')));
    await tapVisible(tester, find.byKey(const Key('firefly-submit')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!['correctAnswers'], 3);
    expect(submitted!['selfRating'], 5);
    expect(submitted!['learnerRole'], 'operations');
    expect(submitted!['firstCallSucceeded'], isTrue);
    expect(submitted!['secretHandlingPassed'], isTrue);
    expect(submitted!['apiSelectionPassed'], isTrue);
    expect(submitted!['non2xxRecoveryPassed'], isTrue);
    expect(submitted!['estimatedDailyRequests'], 500);
    expect(submitted!['completionSeconds'], inInclusiveRange(1, 3600));
    expect(find.text('送信済み: 3 / 3 問正解'), findsOneWidget);
  });
}
