import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/horse_racing/horse_racing_tab_and_ticket_helper.dart';

void main() {
  test('HorseRacingTabRouteHelper maps routes and ?tab= query params', () {
    expect(HorseRacingTabRouteHelper.routeForTabIndex(0), '/horse-racing');
    expect(
      HorseRacingTabRouteHelper.routeForTabIndex(1),
      '/horse-racing/history',
    );
    expect(
      HorseRacingTabRouteHelper.routeForTabIndex(2),
      '/horse-racing/analysis',
    );
    expect(
      HorseRacingTabRouteHelper.routeForTabIndex(3),
      '/horse-racing/bets',
    );

    expect(
      HorseRacingTabRouteHelper.tabIndexFromUri(
        Uri.parse('https://app.example/?tab=analysis'),
      ),
      2,
    );
    expect(
      HorseRacingTabRouteHelper.tabIndexFromUri(
        Uri.parse('https://app.example/horse-racing/bets'),
      ),
      3,
    );
  });

  test('HorseRacingTicketValidationResult enforces budget and non-zero rules',
      () {
    final skipOk = HorseRacingTicketValidationResult.evaluate(
      lineAmounts: const [0],
      isSkipRecord: true,
      recordedToday: 1000,
      dailyBudgetYen: 3000,
    );
    expect(skipOk.isValid, isTrue);

    final zeroInvalid = HorseRacingTicketValidationResult.evaluate(
      lineAmounts: const [0],
      isSkipRecord: false,
      recordedToday: 1000,
      dailyBudgetYen: 3000,
    );
    expect(zeroInvalid.isValid, isFalse);

    final overBudget = HorseRacingTicketValidationResult.evaluate(
      lineAmounts: const [2500],
      isSkipRecord: false,
      recordedToday: 1000,
      dailyBudgetYen: 3000,
    );
    expect(overBudget.exceedsBudget, isTrue);
    expect(overBudget.isValid, isFalse);
  });

  testWidgets(
    'HorseRacingTicketBudgetBanner renders sample count and budget warning at 360x800 @ 2.0x',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final validation = HorseRacingTicketValidationResult.evaluate(
        lineAmounts: const [2500],
        isSkipRecord: false,
        recordedToday: 1000,
        dailyBudgetYen: 3000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: HorseRacingTicketBudgetBanner(
                  sampleCount: 12,
                  recordedToday: 1000,
                  dailyBudgetYen: 3000,
                  validation: validation,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('検証サンプル: 12/30件'), findsOneWidget);
      expect(find.text('本日記録: ¥1000 / 上限 ¥3000'), findsOneWidget);
      expect(find.text('1日の予算上限（¥3000）を超えています。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
