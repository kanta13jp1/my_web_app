import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/admin_registration_funnel_card.dart';

void main() {
  Widget testApp({
    int lpViews = 0,
    int registrations = 0,
    int trialRuns = 0,
    int saveClicks = 0,
    int magicLinkSends = 0,
    int inboxOpens = 0,
    int remainingRegistrations = 0,
    String bottleneckLabel = '',
    int neededMagicLinks = 0,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminRegistrationFunnelCard(
            title: '今日の登録ファネル',
            lpViews: lpViews,
            registrations: registrations,
            trialRuns: trialRuns,
            saveClicks: saveClicks,
            magicLinkSends: magicLinkSends,
            inboxOpens: inboxOpens,
            remainingRegistrations: remainingRegistrations,
            bottleneckLabel: bottleneckLabel,
            neededMagicLinks: neededMagicLinks,
          ),
        ),
      ),
    );
  }

  testWidgets('renders every funnel step and measured conversion rate', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        lpViews: 100,
        registrations: 5,
        trialRuns: 40,
        saveClicks: 20,
        magicLinkSends: 10,
        inboxOpens: 8,
      ),
    );

    expect(find.text('今日の登録ファネル'), findsOneWidget);
    expect(find.text('LP View'), findsOneWidget);
    expect(find.text('体験実行'), findsOneWidget);
    expect(find.text('保存CTA'), findsOneWidget);
    expect(find.text('Magic Link送信'), findsOneWidget);
    expect(find.text('受信箱を開く'), findsOneWidget);
    expect(find.text('実登録'), findsOneWidget);
    expect(find.text('LP→体験率 40.0%', findRichText: true), findsOneWidget);
    expect(
      find.text('体験→保存率 50.0%', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('保存→送信率 50.0%', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('送信→登録率 50.0%', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('最大ボトルネック'), findsNothing);
  });

  testWidgets('shows the target gap guidance while registration remains', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        lpViews: 12,
        trialRuns: 4,
        saveClicks: 2,
        magicLinkSends: 1,
        remainingRegistrations: 1,
        bottleneckLabel: '送信後の登録完了',
        neededMagicLinks: 3,
      ),
    );

    expect(
      find.text('最大ボトルネック 送信後の登録完了', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('目標達成に必要な送信 3件', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('keeps rates unmeasured when their denominators are zero', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(registrations: 1));

    expect(find.text('LP→体験率 --', findRichText: true), findsOneWidget);
    expect(find.text('体験→保存率 --', findRichText: true), findsOneWidget);
    expect(find.text('保存→送信率 --', findRichText: true), findsOneWidget);
    expect(find.text('送信→登録率 --', findRichText: true), findsOneWidget);
  });
}
