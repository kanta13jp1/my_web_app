import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_recurring_transaction_detector.dart';
import 'package:my_web_app/widgets/asset_recurring_transaction_suggestion_card.dart';

void main() {
  DetectedRecurringTransaction make(
    String label, {
    RecurringTransactionConfidence confidence =
        RecurringTransactionConfidence.high,
    AssetRecurringFixedCostCadence cadence =
        AssetRecurringFixedCostCadence.monthly,
  }) {
    return DetectedRecurringTransaction(
      label: label,
      typicalAmount: 8000,
      typicalPaymentDay: 15,
      occurrenceCount: 4,
      monthsObserved: 4,
      confidence: confidence,
      cadence: cadence,
      lastSeen: DateTime(2026, 6, 15),
    );
  }

  testWidgets('renders nothing when there are no suggestions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetRecurringTransactionSuggestionCard(
            suggestions: const [],
            onRegister: (_) {},
            onIgnore: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('asset_recurring_transaction_suggestion_card')),
      findsNothing,
    );
  });

  testWidgets('renders each suggestion and fires onRegister', (tester) async {
    DetectedRecurringTransaction? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetRecurringTransactionSuggestionCard(
            suggestions: [make('電気代'), make('家賃')],
            onRegister: (detected) => tapped = detected,
            onIgnore: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('asset_recurring_transaction_suggestion_card')),
      findsOneWidget,
    );
    expect(find.text('電気代'), findsOneWidget);
    expect(find.text('家賃'), findsOneWidget);
    expect(find.text('固定費に登録'), findsNWidgets(2));

    await tester.tap(
      find.byKey(const Key('asset_recurring_suggestion_register_0')),
    );
    await tester.pump();

    expect(tapped, isNotNull);
    expect(tapped!.label, '電気代');
  });

  testWidgets('fires onIgnore when the ignore button is tapped',
      (tester) async {
    DetectedRecurringTransaction? ignored;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetRecurringTransactionSuggestionCard(
            suggestions: [make('電気代'), make('家賃')],
            onRegister: (_) {},
            onIgnore: (detected) => ignored = detected,
          ),
        ),
      ),
    );

    expect(find.text('無視'), findsNWidgets(2));

    await tester.tap(
      find.byKey(const Key('asset_recurring_suggestion_ignore_1')),
    );
    await tester.pump();

    expect(ignored, isNotNull);
    expect(ignored!.label, '家賃');
  });

  testWidgets('shows the cadence label (monthly vs bimonthly)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetRecurringTransactionSuggestionCard(
            suggestions: [
              make('電気代'),
              make(
                '水道代',
                cadence: AssetRecurringFixedCostCadence.bimonthlyEvenMonth,
              ),
            ],
            onRegister: (_) {},
            onIgnore: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('毎月15日頃'), findsOneWidget);
    expect(find.text('隔月(偶数月)15日頃'), findsOneWidget);
  });

  testWidgets('exposes a semantics label per suggestion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetRecurringTransactionSuggestionCard(
            suggestions: [make('電気代')],
            onRegister: (_) {},
            onIgnore: (_) {},
          ),
        ),
      ),
    );

    final hasLabel = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label?.contains('電気代') ?? false) &&
          (widget.properties.label?.contains('確度 高') ?? false),
    );
    expect(hasLabel, findsOneWidget);
  });
}
