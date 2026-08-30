import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/toeic_practice_repository.dart';
import 'package:my_web_app/domain/models/toeic_practice.dart';
import 'package:my_web_app/ui/features/toeic/view_models/toeic_practice_view_model.dart';

class _FakeRepository implements ToeicPracticeRepository {
  _FakeRepository({required this.questions});

  final List<ToeicQuestion> questions;
  ToeicProgress progress = ToeicProgress.initial();
  int saveCount = 0;

  @override
  Future<List<ToeicQuestion>> getQuestions() async => questions;

  @override
  Future<ToeicProgress> getProgress() async => progress;

  @override
  Future<void> saveProgress(ToeicProgress next) async {
    progress = next;
    saveCount++;
  }
}

List<ToeicQuestion> _questions() => List<ToeicQuestion>.generate(
      5,
      (index) => ToeicQuestion(
        id: 'q$index',
        part: ToeicPart.values[index % ToeicPart.values.length],
        category: 'test',
        prompt: 'Question $index',
        choices: const <String>['correct', 'wrong', 'wronger', 'wrongest'],
        answerIndex: 0,
        explanation: 'Because this is the correct answer.',
      ),
    );

void main() {
  test('completes five questions and persists the daily result', () async {
    final repository = _FakeRepository(questions: _questions());
    final viewModel = ToeicPracticeViewModel(
      repository: repository,
      clock: () => DateTime(2026, 8, 23, 18),
    );
    await viewModel.load();

    viewModel.startDailySession();
    for (var index = 0; index < 5; index++) {
      viewModel.selectAnswer(0);
      viewModel.submitAnswer();
      await viewModel.nextQuestion();
    }

    expect(viewModel.stage, ToeicPracticeStage.summary);
    expect(viewModel.sessionCorrect, 5);
    expect(viewModel.progress.totalAnswered, 5);
    expect(viewModel.progress.totalCorrect, 5);
    expect(viewModel.dashboard.todayCompleted, isTrue);
    expect(viewModel.dashboard.currentStreak, 1);
    expect(repository.saveCount, 1);
  });

  test('persists a changed target score independently of a session', () async {
    final repository = _FakeRepository(questions: _questions());
    final viewModel = ToeicPracticeViewModel(repository: repository);
    await viewModel.load();

    await viewModel.setTargetScore(860);

    expect(viewModel.progress.targetScore, 860);
    expect(repository.progress.targetScore, 860);
    expect(repository.saveCount, 1);
  });

  test('restores persisted progress in a new view model', () async {
    final repository = _FakeRepository(questions: _questions());
    final first = ToeicPracticeViewModel(
      repository: repository,
      clock: () => DateTime(2026, 8, 23),
    );
    await first.load();
    first.startDailySession();
    for (var index = 0; index < 5; index++) {
      first.selectAnswer(index == 0 ? 1 : 0);
      first.submitAnswer();
      await first.nextQuestion();
    }

    final restored = ToeicPracticeViewModel(
      repository: repository,
      clock: () => DateTime(2026, 8, 23),
    );
    await restored.load();

    expect(restored.progress.totalAnswered, 5);
    expect(restored.progress.totalCorrect, 4);
    expect(restored.dashboard.todayCompleted, isTrue);
    expect(restored.dashboard.currentStreak, 1);
  });
}
