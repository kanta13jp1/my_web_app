import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/toeic_practice_repository.dart';
import 'package:my_web_app/domain/models/toeic_practice.dart';
import 'package:my_web_app/ui/features/toeic/toeic_feature.dart';

class _FakeRepository implements ToeicPracticeRepository {
  ToeicProgress progress = ToeicProgress.initial();

  @override
  Future<List<ToeicQuestion>> getQuestions() async =>
      List<ToeicQuestion>.generate(
        5,
        (index) => ToeicQuestion(
          id: 'q$index',
          part: ToeicPart.values[index % ToeicPart.values.length],
          category: '文法',
          prompt: 'Practice question $index',
          choices: const <String>[
            'Correct choice',
            'Choice B',
            'Choice C',
            'Choice D',
          ],
          answerIndex: 0,
          explanation: 'This explanation confirms the answer.',
        ),
      );

  @override
  Future<ToeicProgress> getProgress() async => progress;

  @override
  Future<void> saveProgress(ToeicProgress next) async => progress = next;
}

Future<void> _pumpFeature(WidgetTester tester, {required Size size}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: ToeicFeature(
        repository: _FakeRepository(),
        clock: () => DateTime(2026, 8, 23),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the responsive dashboard at desktop width', (
    tester,
  ) async {
    await _pumpFeature(tester, size: const Size(1200, 1000));

    expect(find.text('AI大学 TOEIC対策'), findsOneWidget);
    expect(find.text('目標スコア'), findsWidgets);
    expect(find.text('Part別トレーニング'), findsOneWidget);
    expect(find.byKey(const Key('start_part5_drill')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starts a drill and reveals an explanation at mobile width', (
    tester,
  ) async {
    await _pumpFeature(tester, size: const Size(360, 800));

    await tester.tap(find.byKey(const Key('start_daily_toeic_drill')));
    await tester.pump();
    expect(find.byKey(const Key('toeic_question_prompt')), findsOneWidget);

    await tester.tap(find.byKey(const Key('toeic_choice_0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit_toeic_answer')));
    await tester.pump();

    expect(find.byKey(const Key('toeic_answer_feedback')), findsOneWidget);
    expect(find.text('正解です！'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
