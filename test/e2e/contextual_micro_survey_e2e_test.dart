import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/models/micro_survey.dart';
import 'package:my_web_app/services/micro_survey_repository.dart';
import 'package:my_web_app/widgets/micro_survey_bottom_sheet.dart';

const _surveyContext = MicroSurveyContext(
  trigger: MicroSurveyTrigger.resourceCreated,
  route: '/team-workspace',
  resourceType: 'team',
);

class _FakeRepository implements MicroSurveyRepository {
  int submitFailuresRemaining = 0;
  int submitAttempts = 0;
  bool optedOut = false;
  MicroSurveyAnswer? answer;

  @override
  Future<bool> claimPrompt(MicroSurveyContext surveyContext) async => true;

  @override
  Future<void> setOptOut(bool optedOut) async {
    this.optedOut = optedOut;
  }

  @override
  Future<void> submit(
    MicroSurveyContext surveyContext,
    MicroSurveyAnswer answer,
  ) async {
    submitAttempts += 1;
    if (submitFailuresRemaining > 0) {
      submitFailuresRemaining -= 1;
      throw StateError('temporary outage');
    }
    this.answer = answer;
  }
}

Widget _testApp(_FakeRepository repository) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => FilledButton(
          onPressed: () => presentMicroSurveyIfEligible(
            context: context,
            repository: repository,
            surveyContext: _surveyContext,
          ),
          child: const Text('タスク完了'),
        ),
      ),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('task completion opens two questions and submits an answer',
      (tester) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_testApp(repository));

    await tester.tap(find.text('タスク完了'));
    await tester.pumpAndSettle();
    expect(find.text('かんたんフィードバック'), findsOneWidget);
    expect(find.text('1. この操作はスムーズでしたか？'), findsOneWidget);

    await tester.tap(find.byKey(const Key('microSurveyRating5')));
    await tester.pump();
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();

    expect(find.text('かんたんフィードバック'), findsNothing);
    expect(repository.answer?.rating, 5);
  });

  testWidgets('user can opt out without answering', (tester) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_testApp(repository));

    await tester.tap(find.text('タスク完了'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今後表示しない'));
    await tester.pumpAndSettle();

    expect(find.text('かんたんフィードバック'), findsNothing);
    expect(repository.optedOut, isTrue);
    expect(repository.answer, isNull);
  });

  testWidgets('temporary submit failure is recoverable in the same sheet',
      (tester) async {
    final repository = _FakeRepository()..submitFailuresRemaining = 1;
    await tester.pumpWidget(_testApp(repository));

    await tester.tap(find.text('タスク完了'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('microSurveyRating3')));
    await tester.pump();
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();

    expect(find.textContaining('送信できませんでした'), findsOneWidget);
    expect(find.text('かんたんフィードバック'), findsOneWidget);

    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();

    expect(find.text('かんたんフィードバック'), findsNothing);
    expect(repository.submitAttempts, 2);
    expect(repository.answer?.rating, 3);
  });
}
