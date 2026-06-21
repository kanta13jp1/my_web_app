import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/english_reading_models.dart';
import 'package:my_web_app/pages/english_reading_dashboard_page.dart';
import 'package:my_web_app/services/english_reading_ability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders ability hero and level map from an injected summary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final summary =
        EnglishReadingAbilitySummary.fromAttempts(<EnglishReadingAttempt>[
      EnglishReadingAttempt(
        id: 'a1',
        lessonCode: 'L4-01',
        level: 4,
        mode: 'measure',
        wordCount: 200,
        elapsedMs: 60000,
        wpm: 200,
        comprehensionCorrect: 4,
        comprehensionTotal: 4,
        effectiveWpm: 200,
        createdAt: DateTime(2026, 6, 20),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: EnglishReadingDashboardPage(
          initialSummary: summary,
          autoLoad: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('英語速読 実力ダッシュボード'), findsOneWidget);
    expect(find.text('レベル制覇マップ'), findsOneWidget);
    expect(find.textContaining('対ネイティブ'), findsWidgets);
    // estimated level for 200 effective wpm = Lv4
    expect(find.textContaining('Lv4'), findsWidgets);
  });
}
