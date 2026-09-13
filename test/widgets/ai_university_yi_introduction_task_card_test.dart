import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/ai_university_yi_introduction_task_card.dart';

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Widget subject(AiUniversityYiIntroductionTaskSubmit onSubmit) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityYiIntroductionTaskCard(onSubmit: onSubmit),
          ),
        ),
      );

  Future<void> completeTask(WidgetTester tester) async {
    await tapVisible(tester, find.byKey(const Key('yi-intro-q0-o1')));
    await tapVisible(tester, find.byKey(const Key('yi-intro-q0-o0')));
    await tapVisible(tester, find.byKey(const Key('yi-intro-q1-o1')));
    await tapVisible(tester, find.byKey(const Key('yi-intro-q2-o0')));
    await tapVisible(
      tester,
      find.byKey(const Key('yi-intro-next-yi_repository')),
    );
    await tapVisible(tester, find.byKey(const Key('yi-intro-rating-4')));
  }

  testWidgets('requires all classifications, next page, and self-rating', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(({
        required correctAnswers,
        required firstAttemptCorrectAnswers,
        required selfRating,
        required nextOfficialPage,
      }) async {
        return true;
      }),
    );

    final submit = find.byKey(const Key('yi-intro-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await completeTask(tester);
    await tester.ensureVisible(submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('submits finite final and first-attempt evidence', (
    tester,
  ) async {
    Map<String, Object>? submitted;
    await tester.pumpWidget(
      subject(({
        required correctAnswers,
        required firstAttemptCorrectAnswers,
        required selfRating,
        required nextOfficialPage,
      }) async {
        submitted = <String, Object>{
          'correctAnswers': correctAnswers,
          'firstAttemptCorrectAnswers': firstAttemptCorrectAnswers,
          'selfRating': selfRating,
          'nextOfficialPage': nextOfficialPage,
        };
        return true;
      }),
    );

    await completeTask(tester);
    await tapVisible(tester, find.byKey(const Key('yi-intro-submit')));
    await tester.pumpAndSettle();

    expect(submitted, <String, Object>{
      'correctAnswers': 3,
      'firstAttemptCorrectAnswers': 2,
      'selfRating': 4,
      'nextOfficialPage': 'yi_repository',
    });
    expect(find.byKey(const Key('yi-intro-submitted-result')), findsOneWidget);
  });

  testWidgets('keeps the task retryable when submission is rejected', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(({
        required correctAnswers,
        required firstAttemptCorrectAnswers,
        required selfRating,
        required nextOfficialPage,
      }) async {
        return false;
      }),
    );

    await completeTask(tester);
    await tapVisible(tester, find.byKey(const Key('yi-intro-submit')));
    await tester.pump();

    expect(find.textContaining('結果を送信できませんでした'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('yi-intro-submit')))
          .onPressed,
      isNotNull,
    );
  });
}
