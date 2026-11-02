import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/admin_registration_ops_card.dart';

void main() {
  Widget testApp({
    int todayDropBeforeTrial = 0,
    int totalDropBeforeTrial = 0,
    int zeroRegistrationStreakDays = 0,
    bool zeroStreakAtCap = false,
    double averageViewsLast7Days = 0,
    String totalTrialRate = '—',
    String? registrationsPerLpView,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminRegistrationOpsCard(
            todayDropBeforeTrial: todayDropBeforeTrial,
            totalDropBeforeTrial: totalDropBeforeTrial,
            zeroRegistrationStreakDays: zeroRegistrationStreakDays,
            zeroStreakAtCap: zeroStreakAtCap,
            averageViewsLast7Days: averageViewsLast7Days,
            totalTrialRate: totalTrialRate,
            registrationsPerLpView: registrationsPerLpView,
          ),
        ),
      ),
    );
  }

  testWidgets('shows capped zero-registration streak without understating it', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(zeroRegistrationStreakDays: 30, zeroStreakAtCap: true),
    );

    expect(find.text('登録管理の追加指標'), findsOneWidget);
    expect(find.text('30日以上'), findsOneWidget);
    expect(find.textContaining('登録ゼロが30日以上連続です。'), findsOneWidget);
  });

  testWidgets('prioritizes trial drop-off when traffic does not convert', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        todayDropBeforeTrial: 4,
        totalDropBeforeTrial: 17,
        averageViewsLast7Days: 8.25,
        totalTrialRate: '23.5%',
      ),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('8.3'), findsOneWidget);
    expect(find.text('23.5%'), findsOneWidget);
    expect(find.text('登録未発生'), findsOneWidget);
    expect(find.textContaining('体験前に4件が離脱しています。'), findsOneWidget);
  });

  testWidgets('shows healthy guidance and measured registration efficiency', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        totalDropBeforeTrial: 2,
        averageViewsLast7Days: 3,
        totalTrialRate: '50.0%',
        registrationsPerLpView: '4.5',
      ),
    );

    expect(find.text('4.5 LP/登録'), findsOneWidget);
    expect(find.textContaining('直近の登録導線は動いています。'), findsOneWidget);
  });
}
