import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/micro_survey.dart';
import 'package:my_web_app/services/micro_survey_controller.dart';
import 'package:my_web_app/services/micro_survey_repository.dart';

const _surveyContext = MicroSurveyContext(
  trigger: MicroSurveyTrigger.resourceCreated,
  route: '/team-workspace',
  resourceType: 'team',
);

class _FakeRepository implements MicroSurveyRepository {
  bool claimResult = true;
  bool throwOnClaim = false;
  bool throwOnSubmit = false;
  bool optedOut = false;
  MicroSurveyAnswer? submittedAnswer;

  @override
  Future<bool> claimPrompt(MicroSurveyContext surveyContext) async {
    if (throwOnClaim) throw StateError('offline');
    return claimResult;
  }

  @override
  Future<void> setOptOut(bool optedOut) async {
    this.optedOut = optedOut;
  }

  @override
  Future<void> submit(
    MicroSurveyContext surveyContext,
    MicroSurveyAnswer answer,
  ) async {
    if (throwOnSubmit) throw StateError('offline');
    submittedAnswer = answer;
  }
}

void main() {
  test('eligible prompt is presented and ineligible prompt is skipped',
      () async {
    final repository = _FakeRepository();
    final controller = MicroSurveyController(repository: repository);
    addTearDown(controller.dispose);

    expect(await controller.shouldPresent(_surveyContext), isTrue);
    repository.claimResult = false;
    expect(await controller.shouldPresent(_surveyContext), isFalse);
  });

  test('claim failure is fail-closed and does not break the product task',
      () async {
    final repository = _FakeRepository()..throwOnClaim = true;
    final controller = MicroSurveyController(repository: repository);
    addTearDown(controller.dispose);

    expect(await controller.shouldPresent(_surveyContext), isFalse);
    expect(controller.errorMessage, contains('表示判定'));
    expect(controller.isChecking, isFalse);
  });

  test('valid answer is submitted and invalid rating is rejected', () async {
    final repository = _FakeRepository();
    final controller = MicroSurveyController(repository: repository);
    addTearDown(controller.dispose);

    expect(
      await controller.submit(
        _surveyContext,
        const MicroSurveyAnswer(rating: 5, comment: 'fast'),
      ),
      isTrue,
    );
    expect(repository.submittedAnswer?.rating, 5);
    expect(
      await controller.submit(
        _surveyContext,
        const MicroSurveyAnswer(rating: 0),
      ),
      isFalse,
    );
  });

  test('opt-out is delegated to the repository', () async {
    final repository = _FakeRepository();
    final controller = MicroSurveyController(repository: repository);
    addTearDown(controller.dispose);

    expect(await controller.optOut(), isTrue);
    expect(repository.optedOut, isTrue);
  });
}
