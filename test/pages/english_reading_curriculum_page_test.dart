import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/english_reading_models.dart';
import 'package:my_web_app/pages/english_reading_curriculum_page.dart';
import 'package:my_web_app/services/english_reading_ability.dart';

EnglishReadingLesson _lesson(int level, String code, String title) {
  return EnglishReadingLesson(
    id: 'id-$code',
    lessonCode: code,
    level: level,
    cefr: 'A2',
    title: title,
    topic: 'test',
    targetWpm: 100,
    passage: 'one two three four five',
    declaredWordCount: 5,
    questions: const <EnglishReadingQuestion>[],
    source: 'seed',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the level ladder and lessons without Supabase', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: EnglishReadingCurriculumPage(
          initialLessons: <EnglishReadingLesson>[
            _lesson(1, 'L1-01', 'A Morning Walk'),
            _lesson(2, 'L2-01', 'Why People Sleep'),
          ],
          initialSummary: EnglishReadingAbilitySummary.empty(),
          autoLoad: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('📖 英語速読カリキュラム'), findsOneWidget);
    expect(find.text('A Morning Walk'), findsOneWidget);
    expect(find.text('Lv1 基礎'), findsWidgets);
    // both practice mode buttons exist for a lesson
    expect(find.text('計測'), findsWidgets);
    expect(find.text('RSVP'), findsWidgets);
  });
}
