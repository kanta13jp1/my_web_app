import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/english_reading_models.dart';
import 'package:my_web_app/pages/english_reading_practice_page.dart';

EnglishReadingLesson _lesson() {
  return const EnglishReadingLesson(
    id: 'id-1',
    lessonCode: 'L1-01',
    level: 1,
    cefr: 'A2',
    title: 'Measure Me',
    topic: 'test',
    targetWpm: 100,
    passage: 'Alpha bravo charlie delta echo foxtrot',
    declaredWordCount: 6,
    questions: <EnglishReadingQuestion>[
      EnglishReadingQuestion(
        question: 'Pick alpha',
        choices: <String>['alpha', 'bravo', 'charlie', 'delta'],
        answerIndex: 0,
        explanation: 'It is alpha.',
      ),
    ],
    source: 'seed',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('measure intro shows start button and hides the passage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: EnglishReadingPracticePage(
          lesson: _lesson(),
          mode: 'measure',
          autoLoad: false,
          submitToServer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Measure Me'), findsOneWidget);
    expect(find.text('計測を開始'), findsOneWidget);
    // The passage must stay hidden until reading starts (fair measurement).
    expect(find.textContaining('Alpha bravo charlie'), findsNothing);
  });

  testWidgets('rsvp intro shows a speed slider and start button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: EnglishReadingPracticePage(
          lesson: _lesson(),
          mode: 'rsvp',
          autoLoad: false,
          submitToServer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RSVP を開始'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });
}
