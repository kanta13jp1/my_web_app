import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_category_budget_service.dart';
import 'package:my_web_app/widgets/asset_category_budget_card.dart';

Future<void> _pump(
  WidgetTester tester,
  CategoryBudgetReport report, {
  VoidCallback? onEdit,
  ThemeData? theme,
  String? periodLabel,
  TextScaler? textScaler,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) {
          final child = Scaffold(
            body: SingleChildScrollView(
              child: AssetCategoryBudgetCard(
                report: report,
                onEditBudgets: onEdit,
                currencyFormatter: (value) => '¥${value.round()}',
                periodLabel: periodLabel,
              ),
            ),
          );
          if (textScaler == null) {
            return child;
          }
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child,
          );
        },
      ),
    ),
  );
}

void main() {
  group('AssetCategoryBudgetCard', () {
    testWidgets('shows the empty state when no budget is set', (tester) async {
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{'食費': 30000},
        budgets: <String, double>{},
      );

      await _pump(tester, report);

      expect(
        find.byKey(const Key('asset_category_budget_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_category_budget_empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_category_budget_total')),
        findsNothing,
      );
    });

    testWidgets('shows totals and an over-budget marker', (tester) async {
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{'食費': 60000},
        budgets: <String, double>{'食費': 50000},
      );

      await _pump(tester, report);

      expect(
        find.byKey(const Key('asset_category_budget_total')),
        findsOneWidget,
      );
      expect(find.textContaining('超過'), findsWidgets);
    });

    testWidgets('the edit button fires the callback', (tester) async {
      var tapped = false;
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{},
        budgets: <String, double>{'住居': 63000},
      );

      await _pump(tester, report, onEdit: () => tapped = true);

      final button = find.byKey(const Key('asset_category_budget_edit'));
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('marks the over-budget total as a live region for a11y', (
      tester,
    ) async {
      final report = AssetCategoryBudgetService.build(
        actualByCategory: <String, double>{'食費': 60000},
        budgets: <String, double>{'食費': 50000},
      );

      await _pump(tester, report);

      // 予算超過の合計は liveRegion(変化をスクリーンリーダーが読み上げる)。
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && (widget.properties.liveRegion ?? false),
        ),
        findsWidgets,
      );
      // 各行は MergeSemantics で1ノードに統合(断片的な読み上げを防ぐ)。
      expect(find.byType(MergeSemantics), findsWidgets);
    });

    testWidgets(
      'renders without overflow on 320px narrow screen with long labels and large amounts',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final report = AssetCategoryBudgetService.build(
          actualByCategory: <String, double>{
            '非常に長い食費および外食・交際費カテゴリ名のテスト': 123456789,
            '非常に長い光熱費・通信費・住居関連維持費カテゴリ名': 98765432,
          },
          budgets: <String, double>{
            '非常に長い食費および外食・交際費カテゴリ名のテスト': 100000000,
          },
        );

        await _pump(
          tester,
          report,
          onEdit: () {},
          periodLabel: '5/25〜6/24(給料サイクル)',
        );

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('asset_category_budget_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('asset_category_budget_total_percent')),
          findsOneWidget,
        );
        expect(find.text('消化率 222%'), findsOneWidget);
        expect(find.text('予算を設定'), findsOneWidget);
      },
    );

    testWidgets(
      'renders without overflow on 320px narrow screen with enlarged text scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final report = AssetCategoryBudgetService.build(
          actualByCategory: <String, double>{
            '非常に長い食費および日用品カテゴリ名のテスト': 60000000,
          },
          budgets: <String, double>{
            '非常に長い食費および日用品カテゴリ名のテスト': 50000000,
          },
        );

        await _pump(
          tester,
          report,
          onEdit: () {},
          periodLabel: '5/25〜6/24(給料サイクル)',
          textScaler: const TextScaler.linear(2),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('asset_category_budget_total_percent')),
          findsOneWidget,
        );
        expect(find.text('消化率 120%'), findsOneWidget);
      },
    );

    testWidgets(
      'renders in ThemeData.dark() and shows total percentage',
      (tester) async {
        final darkTheme = ThemeData.dark();
        final overReport = AssetCategoryBudgetService.build(
          actualByCategory: <String, double>{'食費': 60000},
          budgets: <String, double>{'食費': 50000},
        );

        await _pump(
          tester,
          overReport,
          theme: darkTheme,
          onEdit: () {},
          periodLabel: '5/25〜6/24(給料サイクル)',
        );

        expect(tester.takeException(), isNull);

        final percentFinder = find.byKey(
          const Key('asset_category_budget_total_percent'),
        );
        expect(percentFinder, findsOneWidget);
        expect(tester.widget<Text>(percentFinder).data, '消化率 120%');

        final context = tester.element(
          find.byKey(const Key('asset_category_budget_card')),
        );
        final scheme = Theme.of(context).colorScheme;
        final totalIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator).first,
        );
        expect(totalIndicator.color, scheme.error);
        expect(
          totalIndicator.backgroundColor,
          scheme.surfaceContainerHighest,
        );

        final underReport = AssetCategoryBudgetService.build(
          actualByCategory: <String, double>{'食費': 25000},
          budgets: <String, double>{'食費': 50000},
        );

        await _pump(
          tester,
          underReport,
          theme: darkTheme,
        );

        expect(tester.takeException(), isNull);
        expect(tester.widget<Text>(percentFinder).data, '消化率 50%');

        final underIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator).first,
        );
        expect(underIndicator.color, scheme.primary);
        expect(
          underIndicator.backgroundColor,
          scheme.surfaceContainerHighest,
        );
      },
    );
  });
}
