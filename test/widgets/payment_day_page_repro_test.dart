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

class SyntheticRepository extends SharedPreferencesAssetLiabilityRepository {
  final saved = <Map<String, int>>[];

  @override
  Future<Map<String, int>> loadDebtPaymentDayOverrides() async => {'debt-a': 10};

  @override
  Future<void> saveDebtPaymentDayOverrides(Map<String, int> overrides) async {
    saved.add(Map<String, int>.from(overrides));
  }
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
  });

  testWidgets('characterize remote key loss after the guard aborts',
      (tester) async {
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    const domain = 'debt_payment_day_overrides';
    const store = AssetSyncDirtyKeysStore();
    final dirtyReadStarted = Completer<void>();
    final aborted = Completer<void>();
    final firstWrite = Completer<void>();
    final releaseWrite = Completer<void>();
    var remote = <String, int>{'debt-a': 10, 'debt-b': 5};
    final releaseDirtyRead = Completer<Set<String>>();
    final repo = SyntheticRepository();
    final key = GlobalKey();
    var reads = 0;
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    print('RESTORE_STAGE mount');
    await tester.pumpWidget(MaterialApp(
      home: AssetManagementPage(
        key: key,
        assetLiabilityRepository: repo,
        // Force the normal union-merge path to add an unrelated server key.
        debugDebtOverridesMirror: const <String, dynamic>{'debt-b': 5},
        debugDebtOverrideReproWriter: (values) async {
          remote = Map<String, int>.from(values);
          if (!firstWrite.isCompleted) firstWrite.complete();
          await releaseWrite.future;
        },
        debugRestoreGuardAborted: () { if (!aborted.isCompleted) aborted.complete(); },
        debugRestoreDirtyReader: () {
          reads++;
          if (!dirtyReadStarted.isCompleted) dirtyReadStarted.complete();
          return releaseDirtyRead.future;
        },
      ),
    ));
    for (var i = 0; i < 40 && !dirtyReadStarted.isCompleted; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    print('RESTORE_STAGE restore-waiting');
    expect(dirtyReadStarted.isCompleted, isTrue,
        reason: 'restore must have captured its Map and entered dirty read');
    expect(reads, 1);
    final dynamic page = key.currentState;
    expect(page, isNotNull);
    expect(page.debugDebtOverridesForRestoreRepro()['debt-a'], 10);

    // Invoke the actual page edit after the restore copied its old Map.
    print('RESTORE_STAGE edit');
    page.debugEditDebtOverrideForRestoreRepro(rowA, 11);
    await tester.pump(const Duration(milliseconds: 100));
    expect(page.debugDebtOverridesForRestoreRepro()['debt-a'], 11);
    final actualDirty = await pumpUntil(tester, store.loadDirty(domain), 'dirty-before-release') as Set<String>;
    expect(actualDirty, contains('debt-a'));
    await pumpUntil(tester, firstWrite.future, 'synthetic-remote-write');
    expect(remote, {'debt-a': 11}, reason: 'simulate whole-map upsert before restore returns');
    releaseWrite.complete();
    await tester.pump(const Duration(milliseconds: 100));
    print('RESTORE_STAGE release');
    releaseDirtyRead.complete(actualDirty);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (aborted.isCompleted) break;
    }

    print('RESTORE_STAGE observe');
    final Map<String, int> after = page.debugDebtOverridesForRestoreRepro();
    expect(aborted.isCompleted, isTrue, reason: 'the guard must actually run');
    expect(after['debt-b'], isNull, reason: 'stale restore is deferred');
    expect(after['debt-a'], 11, reason: 'the newer edit must survive');
    expect(remote.containsKey('debt-b'), isFalse, reason: 'characterizes server-side loss, not desired behavior');
    expect(await pumpUntil(tester, store.loadDirty(domain), 'dirty-after-restore'), isNot(contains('debt-a')),
        reason: 'the synthetic whole-map write also acknowledges the dirty marker');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

}
