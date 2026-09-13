import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/micro_survey.dart';
import 'package:my_web_app/services/micro_survey_controller.dart';
import 'package:my_web_app/services/micro_survey_repository.dart';
import 'package:my_web_app/widgets/micro_survey_bottom_sheet.dart';

const _surveyContext = MicroSurveyContext(
  trigger: MicroSurveyTrigger.deploymentMonitoringCreated,
  route: '/deployment-monitoring',
  resourceType: 'deployment_monitoring_setup',
);

class _FakeRepository implements MicroSurveyRepository {
  MicroSurveyAnswer? answer;
  bool optedOut = false;

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
    this.answer = answer;
  }
}

Future<void> _openSheet(
  WidgetTester tester,
  MicroSurveyController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => MicroSurveyBottomSheet(
                controller: controller,
                surveyContext: _surveyContext,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows only two questions and submits rating plus optional note',
      (tester) async {
    final repository = _FakeRepository();
    final controller = MicroSurveyController(repository: repository);
    addTearDown(controller.dispose);
    await _openSheet(tester, controller);

    expect(find.text('1. この操作はスムーズでしたか？'), findsOneWidget);
    expect(
      find.text('2. よろしければ理由を教えてください（任意）'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('microSurveySubmit')), findsOneWidget);

    await tester.tap(find.byKey(const Key('microSurveyRating4')));
    await tester.enterText(
      find.byKey(const Key('microSurveyComment')),
      '迷わず完了できた',
    );
    await tester.tap(find.byKey(const Key('microSurveySubmit')));
    await tester.pumpAndSettle();

    expect(repository.answer?.rating, 4);
    expect(repository.answer?.comment, '迷わず完了できた');
    expect(find.text('かんたんフィードバック'), findsNothing);
  });

  testWidgets('opt-out is available without answering', (tester) async {
    final repository = _FakeRepository();
    final controller = MicroSurveyController(repository: repository);
    addTearDown(controller.dispose);
    await _openSheet(tester, controller);

    await tester.tap(find.text('今後表示しない'));
    await tester.pumpAndSettle();

    expect(repository.optedOut, isTrue);
    expect(repository.answer, isNull);
  });

  testWidgets('compact viewport does not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = MicroSurveyController(repository: _FakeRepository());
    addTearDown(controller.dispose);

    await _openSheet(tester, controller);
    expect(tester.takeException(), isNull);
    expect(find.text('あとで'), findsOneWidget);
  });
}
