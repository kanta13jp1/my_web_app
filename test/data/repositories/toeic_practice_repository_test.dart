import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/models/toeic_progress_model.dart';
import 'package:my_web_app/data/repositories/toeic_practice_repository.dart';
import 'package:my_web_app/data/services/toeic_progress_service.dart';
import 'package:my_web_app/data/services/toeic_question_catalog_service.dart';
import 'package:my_web_app/domain/models/toeic_practice.dart';

class _MemoryProgressService implements ToeicProgressService {
  ToeicProgressModel value = ToeicProgressModel.initial();

  @override
  Future<ToeicProgressModel> load() async => value;

  @override
  Future<void> save(ToeicProgressModel progress) async => value = progress;
}

void main() {
  test(
    'maps the original local catalog into all supported reading parts',
    () async {
      final repository = LocalToeicPracticeRepository(
        catalogService: const LocalToeicQuestionCatalogService(),
        progressService: _MemoryProgressService(),
      );

      final questions = await repository.getQuestions();

      expect(questions, hasLength(12));
      expect(questions.map((question) => question.id).toSet(), hasLength(12));
      expect(
        questions.map((question) => question.part).toSet(),
        ToeicPart.values.toSet(),
      );
      expect(
        questions.every((question) => question.choices.length == 4),
        isTrue,
      );
    },
  );

  test('round-trips domain progress through the progress service', () async {
    final progressService = _MemoryProgressService();
    final repository = LocalToeicPracticeRepository(
      catalogService: const LocalToeicQuestionCatalogService(),
      progressService: progressService,
    );
    const progress = ToeicProgress(
      targetScore: 600,
      totalAnswered: 5,
      totalCorrect: 4,
      answeredByPart: <ToeicPart, int>{ToeicPart.part5: 5},
      correctByPart: <ToeicPart, int>{ToeicPart.part5: 4},
      practiceDateKeys: <String>{'2026-08-23'},
    );

    await repository.saveProgress(progress);
    final restored = await repository.getProgress();

    expect(restored.targetScore, 600);
    expect(restored.accuracyFor(ToeicPart.part5), 0.8);
    expect(restored.practiceDateKeys, <String>{'2026-08-23'});
  });
}
