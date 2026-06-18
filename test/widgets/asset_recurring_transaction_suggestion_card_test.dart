import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_recurring_transaction_detector.dart';
import 'package:my_web_app/widgets/asset_recurring_transaction_suggestion_card.dart';

void main() {
  DetectedRecurringTransaction make(
    String label, {
    RecurringTransactionConfidence confidence =
        RecurringTransactionConfidence.high,
  }) {
    return DetectedRecurringTransaction(
      label: label,
      typicalAmount: 8000,
      typicalPaymentDay: 15,
      occurrenceCount: 4,
      monthsObserved: 4,
      confidence: confidence,
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

  testWidgets('exposes a semantics label per suggestion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetRecurringTransactionSuggestionCard(
            suggestions: [make('電気代')],
            onRegister: (_) {},
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
