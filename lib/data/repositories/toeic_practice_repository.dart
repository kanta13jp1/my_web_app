import '../../domain/models/toeic_practice.dart';
import '../models/toeic_progress_model.dart';
import '../services/toeic_progress_service.dart';
import '../services/toeic_question_catalog_service.dart';

abstract interface class ToeicPracticeRepository {
  Future<List<ToeicQuestion>> getQuestions();

  Future<ToeicProgress> getProgress();

  Future<void> saveProgress(ToeicProgress progress);
}

class LocalToeicPracticeRepository implements ToeicPracticeRepository {
  const LocalToeicPracticeRepository({
    required this.catalogService,
    required this.progressService,
  });

  final ToeicQuestionCatalogService catalogService;
  final ToeicProgressService progressService;

  @override
  Future<List<ToeicQuestion>> getQuestions() async {
    return List<ToeicQuestion>.unmodifiable(
      catalogService.loadQuestions().map(_toQuestion),
    );
  }

  @override
  Future<ToeicProgress> getProgress() async {
    final model = await progressService.load();
    return ToeicProgress(
      targetScore: model.targetScore,
      totalAnswered: model.totalAnswered,
      totalCorrect: model.totalCorrect,
      answeredByPart: <ToeicPart, int>{
        for (final entry in model.answeredByPart.entries)
          toeicPartFromId(entry.key): entry.value,
      },
      correctByPart: <ToeicPart, int>{
        for (final entry in model.correctByPart.entries)
          toeicPartFromId(entry.key): entry.value,
      },
      practiceDateKeys: model.practiceDateKeys.toSet(),
    );
  }

  @override
  Future<void> saveProgress(ToeicProgress progress) {
    return progressService.save(
      ToeicProgressModel(
        targetScore: progress.targetScore,
        totalAnswered: progress.totalAnswered,
        totalCorrect: progress.totalCorrect,
        answeredByPart: <String, int>{
          for (final entry in progress.answeredByPart.entries)
            entry.key.id: entry.value,
        },
        correctByPart: <String, int>{
          for (final entry in progress.correctByPart.entries)
            entry.key.id: entry.value,
        },
        practiceDateKeys: progress.practiceDateKeys.toList(growable: false)
          ..sort(),
      ),
    );
  }

  ToeicQuestion _toQuestion(Map<String, Object?> raw) {
    final choices = (raw['choices'] as List<Object?>? ?? const <Object?>[])
        .map((choice) => choice.toString())
        .toList(growable: false);
    final answerIndex = (raw['answer_index'] as int?) ?? 0;
    if (choices.length < 2 ||
        answerIndex < 0 ||
        answerIndex >= choices.length) {
      throw FormatException('Invalid TOEIC question: ${raw['id']}');
    }
    return ToeicQuestion(
      id: raw['id']?.toString() ?? '',
      part: toeicPartFromId(raw['part']?.toString() ?? ''),
      category: raw['category']?.toString() ?? '',
      prompt: raw['prompt']?.toString() ?? '',
      choices: choices,
      answerIndex: answerIndex,
      explanation: raw['explanation']?.toString() ?? '',
      passage: raw['passage']?.toString(),
    );
  }
}
