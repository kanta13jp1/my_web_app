import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/horse_racing/horse_racing_today_action_bar.dart';

void main() {
  const mobileViewport = Size(360, 800);

  Widget wrapMobile2x(Widget child) {
    return MediaQuery(
      data: const MediaQueryData(
        size: mobileViewport,
        textScaler: TextScaler.linear(2.0),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('HorseRacingTodayActionBar @ 360x800 2.0x', () {
    testWidgets('renders summary chips and triggers prediction generation',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var generated = 0;
      await tester.pumpWidget(
        wrapMobile2x(
          HorseRacingTodayActionBar(
            totalRaces: 12,
            predictedRaces: 8,
            entriesReadyRaces: 10,
            nextRaceLabel: '東京 11R 15:40',
            isPredicting: false,
            onGeneratePredictions: () => generated++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(HorseRacingTodayActionBar.barKey),
        findsOneWidget,
      );
      expect(find.text('12件'), findsOneWidget);
      expect(find.text('8/12'), findsOneWidget);
      expect(find.text('10件'), findsOneWidget);
      expect(find.text('東京 11R 15:40'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(HorseRacingTodayActionBar.generateButtonKey),
      );
      await tester.tap(
        find.byKey(HorseRacingTodayActionBar.generateButtonKey),
      );
      await tester.pump();
      expect(generated, 1);
    });

    testWidgets('disables button when totalRaces is 0 (empty state)',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var generated = 0;
      await tester.pumpWidget(
        wrapMobile2x(
          HorseRacingTodayActionBar(
            totalRaces: 0,
            predictedRaces: 0,
            entriesReadyRaces: 0,
            nextRaceLabel: '次走なし',
            isPredicting: false,
            onGeneratePredictions: () => generated++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('次走なし'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(HorseRacingTodayActionBar.generateButtonKey),
      );
      expect(button.onPressed, isNull);
      expect(generated, 0);
    });

    testWidgets('shows loading indicator and predictionStatus while predicting',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapMobile2x(
          const HorseRacingTodayActionBar(
            totalRaces: 12,
            predictedRaces: 8,
            entriesReadyRaces: 10,
            nextRaceLabel: '京都 10R 15:00',
            isPredicting: true,
            predictionStatus: 'AI予想を生成しています...',
            onGeneratePredictions: null,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('AI予想中'), findsOneWidget);
      expect(find.text('AI予想を生成しています...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
