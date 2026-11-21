import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_future_card_bill.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/widgets/asset_future_card_bill_card.dart';

class _DelayedRepository extends SharedPreferencesAssetLiabilityRepository {
  final pending = Completer<AssetLiabilityMonthlyState>();
  final loadedMonths = <DateTime>[];

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) {
    loadedMonths.add(month);
    return pending.future;
  }
}

void main() {
  testWidgets(
      'month rollover replaces an unavailable selection and discards its read',
      (
    tester,
  ) async {
    final repository = _DelayedRepository();
    Future<void> showMonth(DateTime month) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AssetFutureCardBillCard(
                repository: repository,
                accounts: const [],
                subscriptionIds: const {},
                currentStateMonth: month,
              ),
            ),
          ),
        );

    final dropdown = find.byType(DropdownButtonFormField<DateTime>);
    final reload = find.widgetWithText(TextButton, '対象月を再読込');
    await showMonth(DateTime(2026, 7));
    expect(
      tester.widget<DropdownButtonFormField<DateTime>>(dropdown).initialValue,
      DateTime(2026, 8),
    );
    await tester.tap(reload);
    await tester.pump();
    expect(repository.loadedMonths, [DateTime(2026, 8)]);

    await showMonth(DateTime(2026, 8));
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<DropdownButtonFormField<DateTime>>(dropdown).initialValue,
      DateTime(2026, 9),
    );

    repository.pending.complete(
      const AssetLiabilityMonthlyState(
        paymentDifferenceReasons: {
          'old-bill': '${AssetFutureCardBill.notePrefix}old-month-result',
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('old-month-result'), findsNothing);
    expect(tester.widget<TextButton>(reload).onPressed, isNotNull);
  });
}
