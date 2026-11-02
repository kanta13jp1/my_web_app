import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<Object?> pumpUntil<T>(WidgetTester tester, Future<T> operation, String phase) async {
  var done = false;
  Object? result;
  Object? failure;
  StackTrace? failureStack;
  operation.then<void>((value) {
    result = value;
    done = true;
  }, onError: (Object error, StackTrace stack) {
    failure = error;
    failureStack = stack;
    done = true;
  });
  for (var i = 0; i < 100 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  if (!done) throw TestFailure('Synthetic operation did not finish: $phase');
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  return result;
}

class FakeRepository extends SharedPreferencesAssetLiabilityRepository {
  @override
  Future<Map<String, int>> loadDebtPaymentDayOverrides() async => {'debt-a': 10};

  @override
  Future<void> saveDebtPaymentDayOverrides(Map<String, int> overrides) async {}
}

const rowA = AssetLiabilityDebtRow(
  id: 'debt-a', name: 'synthetic', kind: AssetLiabilityAccountKind.cardLoan,
  balance: 0, paymentDay: 10, paymentSourceAccountId: null,
  paymentSourceAccountName: null, paymentMethod: AssetLiabilityPaymentMethod.direct,
  paymentMethodLabel: null,
  paymentMethodSettingSource: AssetLiabilityPaymentMethodSettingSource.builtInDefault,
  billingAccountId: null, billingAccountName: null, includedInBillingAccount: false,
  annualRate: 0, minimumPaymentEstimate: 0, manualPaymentAmount: null,
  scheduledPaymentAmount: 0, monthlyInterestEstimate: 0,
  principalPaymentEstimate: 0, balanceAfterPaymentEstimate: 0, liabilityShare: 0,
  priorityLabel: '', paymentAmountEstimated: false, billingConfirmed: false,
  paid: false, requiresAction: false,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999', publishableKey: 'synthetic-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
  });

  testWidgets('characterize actual mirror acknowledgement after newer edit',
      (tester) async {
    const domain = 'debt_payment_day_overrides';
    const store = AssetSyncDirtyKeysStore();
    final pending = <Completer<void>>[];
    final sent = <Map<String, int>>[];
    final key = GlobalKey();
    print('REPRO_STAGE surface-size');
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    print('REPRO_STAGE pump-widget');
    await tester.pumpWidget(MaterialApp(
      home: AssetManagementPage(
        key: key,
        assetLiabilityRepository: FakeRepository(),
        debugDebtOverrideReproWriter: (payload) {
          sent.add(Map<String, int>.from(payload));
          final response = Completer<void>();
          pending.add(response);
          return response.future;
        },
      ),
    ));
    print('REPRO_STAGE initial-pump-start');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    print('REPRO_STAGE initial-pump-end');
    print('REPRO_STAGE initial-pump-done');
    final dynamic page = key.currentState;
    expect(page, isNotNull);
    print('REPRO_STAGE mark-a');
    await pumpUntil<void>(tester, store.markDirty(domain, 'debt-a'), 'mark-a');
    print('REPRO_STAGE send-a');
    final Future<void> first = page.debugMirrorDebtOverrideForRepro({'debt-a': 10});
    await tester.pump();
    expect(sent, hasLength(1));
    expect(sent.first, {'debt-a': 10});

    // Invoke the actual edit handler while A's network response is pending.
    print('REPRO_STAGE edit-b');
    page.debugEditDebtOverrideForRepro(rowA, 11);
    for (var i = 0; i < 20 && sent.length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sent.length, greaterThanOrEqualTo(2));
    expect(sent.last['debt-a'], 11);
    print('REPRO_STAGE check-dirty-b');
    expect(await pumpUntil(tester, store.loadDirty(domain), 'dirty-b'), contains('debt-a'));

    print('REPRO_STAGE complete-a');
    pending.first.complete();
    await tester.pump();
    print('REPRO_STAGE await-a-result');
    await pumpUntil<void>(tester, first, 'first-response');
    // Characterization of the bug, not a desired-behavior assertion.
    print('REPRO_STAGE check-result');
    expect(await pumpUntil(tester, store.loadDirty(domain), 'dirty-after-a'), isNot(contains('debt-a')),
        reason: 'old acknowledgement clears the newer real page edit');
    for (final response in pending.skip(1)) {
      if (!response.isCompleted) response.complete();
    }
    await tester.pump(const Duration(milliseconds: 100));
    print('REPRO_STAGE unmount');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
