import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
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

class _OwnerSwitchRepository extends SharedPreferencesAssetLiabilityRepository {
  String owner = 'first';
  int saves = 0;
  int loads = 0;
  final beforeSave = Completer<AssetLiabilityMonthlyState>();
  static const initialState = AssetLiabilityMonthlyState(
    cardBillingAccountIds: {'subscription': 'card'},
    paymentOverrides: {'subscription': 1200},
  );

  @override
  bool get supabaseWritesEnabled => true;

  @override
  bool Function() captureMonthAiOwnership(DateTime month) {
    final startedBy = owner;
    return () => owner == startedBy;
  }

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) {
    loads++;
    return loads == 1 ? Future.value(initialState) : beforeSave.future;
  }

  @override
  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    saves++;
  }
}

void main() {
  testWidgets(
    'month rollover replaces an unavailable selection and discards its read',
    (tester) async {
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
    },
  );

  testWidgets('利用者が変わった場合は請求予定を保存しない', (tester) async {
    final repository = _OwnerSwitchRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetFutureCardBillCard(
            repository: repository,
            accounts: const [
              AssetLiabilityAccount(
                id: 'subscription',
                name: 'Test subscription',
                kind: AssetLiabilityAccountKind.otherLiability,
                balance: 0,
              ),
              AssetLiabilityAccount(
                id: 'card',
                name: 'Test card',
                kind: AssetLiabilityAccountKind.creditCard,
                balance: 0,
              ),
            ],
            subscriptionIds: const {'subscription'},
            currentStateMonth: DateTime(2026, 7),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(TextButton, '対象月を再読込'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test subscription').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '未確定・未払いで保存'));
    await tester.pump();
    expect(repository.loads, 2);
    repository.owner = 'second';
    repository.beforeSave.complete(_OwnerSwitchRepository.initialState);
    await tester.pumpAndSettle();

    expect(repository.saves, 0);
  });
}
