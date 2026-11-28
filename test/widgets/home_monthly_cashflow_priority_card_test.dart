import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_monthly_cashflow_priority_card.dart';

void main() {
  testWidgets(
    'HomeMonthlyCashflowPriorityCard renders unrecorded, highlighted, and negative states at 360x800 @ 2.0x',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var ctaTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: HomeMonthlyCashflowPriorityCard(
                  monthLabel: '2026年11月',
                  summaryLine: '今月の収支が未記録です。',
                  incomeLabel: '¥0',
                  expenseLabel: '¥0',
                  netLabel: '¥0',
                  netTotal: 0,
                  reviewDone: false,
                  recordCount: 0,
                  isHighlighted: true,
                  onOpenReview: () => ctaTapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026年11月の収支を最優先'), findsOneWidget);
      expect(find.text('NOW'), findsOneWidget);
      expect(find.text('未記録'), findsOneWidget);
      expect(find.text('今月レビュー未実施'), findsOneWidget);
      expect(find.text('今月の収支を記録する'), findsOneWidget);

      final ctaFinder = find.byKey(const Key('home_monthly_cashflow_cta'));
      await tester.ensureVisible(ctaFinder);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();
      expect(ctaTapped, isTrue);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: HomeMonthlyCashflowPriorityCard(
                  monthLabel: '2026年11月',
                  summaryLine: '支出が収入を上回っています。',
                  incomeLabel: '¥150,000',
                  expenseLabel: '¥180,000',
                  netLabel: '-¥30,000',
                  netTotal: -30000,
                  reviewDone: true,
                  recordCount: 4,
                  lastRecordedLabel: '11/27 12:00',
                  isHighlighted: false,
                  onOpenReview: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NOW'), findsNothing);
      expect(find.text('4件記録'), findsOneWidget);
      expect(find.text('今月レビュー済み'), findsOneWidget);
      expect(find.text('最終記録 11/27 12:00'), findsOneWidget);
      expect(find.text('今月の収支を確認する'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
