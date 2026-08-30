import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/landing_trial_guided_intake.dart';

void main() {
  testWidgets('asks five questions and submits one generated prompt', (
    tester,
  ) async {
    String? submittedPrompt;
    var cancelCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LandingTrialGuidedIntake(
              concern: '仕事が多く、何から始めるか決められない',
              onCancel: () => cancelCount += 1,
              onSubmit: (prompt) => submittedPrompt = prompt,
            ),
          ),
        ),
      ),
    );

    expect(find.text('質問 1 / 5'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('landing_trial_guided_next')),
          )
          .onPressed,
      isNull,
    );

    for (var step = 1; step <= 5; step++) {
      expect(find.text('質問 $step / 5'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('landing_trial_guided_quick_answer')),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('landing_trial_guided_next')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('landing_trial_guided_next')));
      await tester.pumpAndSettle();
    }

    expect(
      find.byKey(const Key('landing_trial_guided_review')),
      findsOneWidget,
    );
    expect(find.text('AIに送る内容を確認'), findsOneWidget);
    expect(submittedPrompt, isNull);

    await tester.tap(find.byKey(const Key('landing_trial_guided_submit')));
    await tester.pump();

    expect(submittedPrompt, contains('相談:仕事が多く'));
    expect(submittedPrompt, contains('目標:まず動き出せればよい'));
    expect(submittedPrompt!.runes.length, lessThanOrEqualTo(280));
    expect(cancelCount, 0);
  });

  testWidgets('back preserves answers and cancel returns to the concern', (
    tester,
  ) async {
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LandingTrialGuidedIntake(
            concern: '相談',
            onCancel: () => cancelled = true,
            onSubmit: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('landing_trial_guided_answer')),
      '自分で書いた目標',
    );
    await tester.tap(find.byKey(const Key('landing_trial_guided_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('landing_trial_guided_back')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('landing_trial_guided_answer')),
          )
          .controller!
          .text,
      '自分で書いた目標',
    );

    await tester.tap(find.byKey(const Key('landing_trial_guided_cancel')));
    await tester.pump();
    expect(cancelled, isTrue);
  });
}
