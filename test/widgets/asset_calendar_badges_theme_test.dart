import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_spending_attention_calendar.dart';
import 'package:my_web_app/widgets/asset_attention_day_label.dart';
import 'package:my_web_app/widgets/asset_borrowing_calendar_badge.dart';
import 'package:my_web_app/widgets/asset_unreconciled_expense_badge.dart';

void main() {
  group('Asset calendar badges light/dark theme adaptation', () {
    testWidgets(
      'AssetAttentionDayLabel switches background and foreground contrast between light and dark',
      (tester) async {
        final day =
            AssetSpendingAttentionCalendar.forDate(DateTime(2026, 10, 16));
        expect(
          AssetAttentionDayLabel.backgroundFor(Brightness.light),
          AssetAttentionDayLabel.background,
        );
        expect(
          AssetAttentionDayLabel.backgroundFor(Brightness.dark)
              .computeLuminance(),
          lessThan(0.1),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(body: AssetAttentionDayLabel(day: day)),
          ),
        );
        final lightText = tester.widget<Text>(find.text('注意'));
        expect(lightText.style?.color, const Color(0xFF78350F));
        expect(lightText.style!.color!.computeLuminance(), lessThan(0.3));

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(body: AssetAttentionDayLabel(day: day)),
          ),
        );
        final darkText = tester.widget<Text>(find.text('注意'));
        expect(darkText.style?.color, const Color(0xFFFDE68A));
        expect(darkText.style!.color!.computeLuminance(), greaterThan(0.5));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AssetUnreconciledExpenseBadge switches icon and text foreground by brightness',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(body: AssetUnreconciledExpenseBadge()),
          ),
        );
        final lightText = tester.widget<Text>(find.text('不明'));
        final lightIcon = tester.widget<Icon>(find.byIcon(Icons.help_outline));
        expect(lightText.style?.color, const Color(0xFF92400E));
        expect(lightIcon.color, const Color(0xFF92400E));
        expect(lightText.style!.color!.computeLuminance(), lessThan(0.3));

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(body: AssetUnreconciledExpenseBadge()),
          ),
        );
        final darkText = tester.widget<Text>(find.text('不明'));
        final darkIcon = tester.widget<Icon>(find.byIcon(Icons.help_outline));
        expect(darkText.style?.color, const Color(0xFFFCD34D));
        expect(darkIcon.color, const Color(0xFFFCD34D));
        expect(darkText.style!.color!.computeLuminance(), greaterThan(0.5));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AssetBorrowingCalendarBadge renders dark/light cell backgrounds and pill contrast',
      (tester) async {
        expect(
          AssetBorrowingCalendarBadge.cellBackgroundFor(
            hasBorrowing: true,
            hasRevolvingUsage: false,
            hasDebtGuardViolation: false,
          ),
          const Color(0xFFFEF3C7),
        );
        expect(
          AssetBorrowingCalendarBadge.cellBackgroundFor(
            hasBorrowing: true,
            hasRevolvingUsage: false,
            hasDebtGuardViolation: false,
            brightness: Brightness.dark,
          )?.computeLuminance(),
          lessThan(0.1),
        );
        expect(
          AssetBorrowingCalendarBadge.cellBackgroundFor(
            hasBorrowing: false,
            hasRevolvingUsage: true,
            hasDebtGuardViolation: false,
            brightness: Brightness.dark,
          )?.computeLuminance(),
          lessThan(0.1),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: AssetBorrowingCalendarBadge(
                hasBorrowing: true,
                hasRevolvingUsage: true,
                hasDebtGuardViolation: true,
              ),
            ),
          ),
        );
        final lightBorrowText = tester.widget<Text>(find.text('借入'));
        final lightRevolvingText = tester.widget<Text>(find.text('リボ'));
        final lightViolationText = tester.widget<Text>(find.text('借金違反'));
        expect(lightBorrowText.style!.color!.computeLuminance(), lessThan(0.3));
        expect(
          lightRevolvingText.style!.color!.computeLuminance(),
          lessThan(0.3),
        );
        expect(
          lightViolationText.style!.color!.computeLuminance(),
          lessThan(0.3),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: AssetBorrowingCalendarBadge(
                hasBorrowing: true,
                hasRevolvingUsage: true,
                hasDebtGuardViolation: true,
              ),
            ),
          ),
        );
        final darkBorrowText = tester.widget<Text>(find.text('借入'));
        final darkRevolvingText = tester.widget<Text>(find.text('リボ'));
        final darkViolationText = tester.widget<Text>(find.text('借金違反'));
        expect(
          darkBorrowText.style!.color!.computeLuminance(),
          greaterThan(0.5),
        );
        expect(
          darkRevolvingText.style!.color!.computeLuminance(),
          greaterThan(0.5),
        );
        expect(
          darkViolationText.style!.color!.computeLuminance(),
          greaterThan(0.5),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
