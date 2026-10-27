// DRAFT ONLY. Not executed. Install into test/widgets only on a diagnostic
// branch together with debt_override_ordered_page_V2_DIAGNOSTIC.patch; never into production.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:my_web_app/services/asset_sync_timestamp_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LocalDebtRepository extends SharedPreferencesAssetLiabilityRepository {
  @override
  Future<Map<String, int>> loadDebtPaymentDayOverrides() async => Map.of(saved);

  final Map<String, int> saved = <String, int>{};

  @override
  Future<void> saveDebtPaymentDayOverrides(Map<String, int> value) async {
    saved..clear()..addAll(value);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
  });

  testWidgets('new same-key edit stays dirty after an older upsert completes',
      (tester) async {
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    final first = Completer<void>();
    final second = Completer<void>();
    final secondDeleted = Completer<void>();
    var deletedCalls = 0;
    final sent = <Map<String, int>>[];
    final owners = <String>[];
    final remote = <String, int>{};
    final repo = _LocalDebtRepository();
    final day = DateTime.now();
    final date = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
      home: AssetManagementPage(
        assetLiabilityRepository: repo,
        debugInitialAssetData: <String, Map<String, double>>{
          date: const <String, double>{
            'モビット': -100000,
          },
        },
        debugDebtOverrideProbeOwner: 'synthetic-owner',
        debugDebtOverrideDeletedProbeWriter: (owner, ids) async {
          deletedCalls++;
          if (deletedCalls == 2) await secondDeleted.future;
        },
        debugDebtOverrideProbeWriter: (owner, values) async {
          owners.add(owner);
          sent.add(Map<String, int>.from(values));
          final snapshot = Map<String, int>.from(values);
          final release = sent.length == 1 ? first.future : second.future;
          await release;
          remote
            ..clear()
            ..addAll(snapshot);
        },
      ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final field = find.byKey(const Key('probe_debt_payment_day_mobit'));
    expect(field, findsOneWidget);

    // Invoke the real DropdownButton callback; it calls the actual page edit,
    // local-save and mirror methods. No live session or DB is used.
    tester.widget<DropdownButton<int?>>(field).onChanged!(10);
    for (var i = 0; i < 20 && sent.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(sent, hasLength(1));
    expect(owners, <String>['synthetic-owner']);
    expect(sent.first['mobit'], 10);

    tester.widget<DropdownButton<int?>>(field).onChanged!(20);
    await tester.pump(const Duration(milliseconds: 200));
    // Fake local B is saved while remote A is held; B remote has not begun.
    expect(repo.saved['mobit'], 20);
    expect(sent, hasLength(1));
    const domain = 'debt_payment_day_overrides';
    const dirty = AssetSyncDirtyKeysStore();
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if ((await dirty.loadDirty(domain, prefs: prefs)).contains('mobit')) {
        break;
      }
    }
    debugPrint('PROBE dirty generation=${AssetSyncDirtyKeysStore.mutationGeneration} ' 
        'pending=${AssetSyncDirtyKeysStore.hasPendingMutations} ' 
        'blob=${prefs.getString(AssetSyncDirtyKeysStore.prefsKey)}');
    expect(await dirty.loadDirty(domain, prefs: prefs), contains('mobit'));

    first.complete();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final observedAfterOldAck = await dirty.loadDirty(domain, prefs: prefs);
    for (var i = 0; i < 20 && sent.length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(sent, hasLength(2));
    expect(sent.last['mobit'], 20);
    second.complete();
    for (var i = 0; i < 20 && deletedCalls < 2; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(deletedCalls, 2);
    expect(await dirty.loadDirty(domain, prefs: prefs), contains('mobit'));
    secondDeleted.complete();
    await tester.pump(const Duration(milliseconds: 200));
    final observedFinalDirty = await dirty.loadDirty(domain, prefs: prefs);
    expect(remote['mobit'], 20);
    expect(observedFinalDirty, isNot(contains('mobit')));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    // Also assert persisted server fake and final dirty after adapting probe writer.
    expect(observedAfterOldAck, contains('mobit'));
  });
  testWidgets('delete stays dirty until both synthetic writes succeed',
      (tester) async {
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    final blockedDelete = Completer<void>();
    Set<String>? capturedDeletedIds;
    var deletes = 0;
    final remote = <String, int>{};
    final repo = _LocalDebtRepository();
    final day = DateTime.now();
    final date = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AssetManagementPage(
      assetLiabilityRepository: repo,
      debugInitialAssetData: <String, Map<String, double>>{
        date: const <String, double>{'モビット': -100000},
      },
      debugDebtOverrideProbeOwner: 'synthetic-owner',
      debugDebtOverrideProbeWriter: (owner, values) async {
        remote..clear()..addAll(values);
      },
      debugDebtOverrideDeletedProbeWriter: (owner, ids) async {
        deletes++;
        if (deletes == 2) {
          capturedDeletedIds = Set<String>.from(ids);
          await blockedDelete.future;
        }
      },
    )));
    await tester.pump(const Duration(milliseconds: 600));
    final field = find.byKey(const Key('probe_debt_payment_day_mobit'));
    expect(field, findsOneWidget);
    tester.widget<DropdownButton<int?>>(field).onChanged!(10);
    for (var i = 0; i < 30 && deletes < 1; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(deletes, 1);
    await tester.pump(const Duration(milliseconds: 100));
    tester.widget<DropdownButton<int?>>(field).onChanged!(null);
    for (var i = 0; i < 30 && deletes < 2; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(deletes, 2);
    expect(capturedDeletedIds, contains('mobit'));
    expect(remote, isNot(contains('mobit')));
    final prefs = await SharedPreferences.getInstance();
    const dirty = AssetSyncDirtyKeysStore();
    const domain = 'debt_payment_day_overrides';
    expect(await dirty.loadDirty(domain, prefs: prefs), contains('mobit'));
    blockedDelete.complete();
    await tester.pump(const Duration(milliseconds: 200));
    expect(await dirty.loadDirty(domain, prefs: prefs), isNot(contains('mobit')));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
  // Compatibility cases: expectations are unverified against V2.
  // Non-shipping synthetic diagnostics only; not executed.
  testWidgets('signed-out edit still persists locally and does not upload',
      (tester) async {
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    final repo = _LocalDebtRepository();
    var sends = 0;
    final day = DateTime.now();
    final date = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AssetManagementPage(
      assetLiabilityRepository: repo,
      debugInitialAssetData: <String, Map<String, double>>{
        date: const <String, double>{'モビット': -100000},
      },
      debugDebtOverrideProbeWriter: (owner, values) async { sends++; },
      debugDebtOverrideDeletedProbeWriter: (owner, ids) async { sends++; },
    )));
    await tester.pump(const Duration(milliseconds: 600));
    final field = find.byKey(const Key('probe_debt_payment_day_mobit'));
    expect(field, findsOneWidget);
    tester.widget<DropdownButton<int?>>(field).onChanged!(12);
    for (var i = 0; i < 30 && repo.saved['mobit'] != 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(repo.saved['mobit'], 12);
    final prefs = await SharedPreferences.getInstance();
    const dirty = AssetSyncDirtyKeysStore();
    expect(await dirty.loadDirty('debt_payment_day_overrides', prefs: prefs),
        contains('mobit'));
    expect(sends, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('signed-out local edit records the LWW change timestamp',
      (tester) async {
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    final repo = _LocalDebtRepository();
    final day = DateTime.now();
    final date = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();
    const timestamps = AssetSyncTimestampStore();
    const domain = 'debt_payment_day_overrides';
    expect(await timestamps.loadTimestamp(domain, prefs: prefs), isNull);
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AssetManagementPage(
      assetLiabilityRepository: repo,
      debugInitialAssetData: <String, Map<String, double>>{
        date: const <String, double>{'モビット': -100000},
      },
    )));
    await tester.pump(const Duration(milliseconds: 600));
    final field = find.byKey(const Key('probe_debt_payment_day_mobit'));
    expect(field, findsOneWidget);
    tester.widget<DropdownButton<int?>>(field).onChanged!(13);
    DateTime? observed;
    for (var i = 0; i < 30 && observed == null; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      observed = await timestamps.loadTimestamp(domain, prefs: prefs);
    }
    expect(repo.saved['mobit'], 13);
    expect(observed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
  testWidgets('restore in flight does not block local edits or apply stale map',
      (tester) async {
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    final gate = Completer<void>();
    var restoreCalls = 0;
    final repo = _LocalDebtRepository();
    final day = DateTime.now();
    final date = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AssetManagementPage(
      assetLiabilityRepository: repo,
      debugInitialAssetData: <String, Map<String, double>>{
        date: const <String, double>{'モビット': -100000},
      },
      debugDebtOverrideProbeOwner: 'synthetic-owner',
      debugDebtOverridesMirror: const <String, dynamic>{'mobit': 10},
      debugDebtRestoreBarrier: () { restoreCalls++; return gate.future; },
      debugDebtOverrideProbeWriter: (owner, values) async {},
      debugDebtOverrideDeletedProbeWriter: (owner, ids) async {},
    )));
    for (var i = 0; i < 40 && restoreCalls == 0; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(restoreCalls, greaterThan(0));
    final field = find.byKey(const Key('probe_debt_payment_day_mobit'));
    expect(field, findsOneWidget);
    tester.widget<DropdownButton<int?>>(field).onChanged!(20);
    for (var i = 0; i < 30 && repo.saved['mobit'] != 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(repo.saved['mobit'], 20);
    gate.complete();
    await tester.pump(const Duration(milliseconds: 250));
    expect(repo.saved['mobit'], 20);
    tester.widget<DropdownButton<int?>>(field).onChanged!(21);
    for (var i = 0; i < 30 && repo.saved['mobit'] != 21; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(repo.saved['mobit'], 21);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('first sign-in enables normal local edit and synthetic sync',
      (tester) async {
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    final auth = ValueNotifier<String?>(null);
    addTearDown(auth.dispose);
    final repo = _LocalDebtRepository();
    final sent = <Map<String, int>>[];
    final day = DateTime.now();
    final date = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AssetManagementPage(
      assetLiabilityRepository: repo,
      debugInitialAssetData: <String, Map<String, double>>{
        date: const <String, double>{'モビット': -100000},
      },
      debugDebtOverrideProbeAuth: auth,
      debugDebtOverrideProbeWriter: (owner, values) async {
        sent.add(Map<String, int>.from(values));
      },
      debugDebtOverrideDeletedProbeWriter: (owner, ids) async {},
    )));
    await tester.pump(const Duration(milliseconds: 600));
    auth.value = 'synthetic-owner';
    await tester.pump();
    final field = find.byKey(const Key('probe_debt_payment_day_mobit'));
    expect(field, findsOneWidget);
    tester.widget<DropdownButton<int?>>(field).onChanged!(14);
    for (var i = 0; i < 40 && sent.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(repo.saved['mobit'], 14);
    expect(sent, isNotEmpty);
    expect(sent.last['mobit'], 14);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('anonymous edit remains local after first sign-in',
      (tester) async {
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    final auth = ValueNotifier<String?>(null);
    addTearDown(auth.dispose);
    final repo = _LocalDebtRepository();
    var sends = 0;
    final day = DateTime.now();
    final date = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AssetManagementPage(
      assetLiabilityRepository: repo,
      debugInitialAssetData: <String, Map<String, double>>{
        date: const <String, double>{'モビット': -100000},
      },
      debugDebtOverrideProbeAuth: auth,
      debugDebtOverrideProbeWriter: (owner, values) async { sends++; },
      debugDebtOverrideDeletedProbeWriter: (owner, ids) async { sends++; },
    )));
    await tester.pump(const Duration(milliseconds: 600));
    final field = find.byKey(const Key('probe_debt_payment_day_mobit'));
    expect(field, findsOneWidget);
    tester.widget<DropdownButton<int?>>(field).onChanged!(12);
    for (var i = 0; i < 30 && repo.saved['mobit'] != 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(repo.saved['mobit'], 12);
    auth.value = 'synthetic-owner';
    await tester.pump();
    tester.widget<DropdownButton<int?>>(field).onChanged!(13);
    for (var i = 0; i < 30 && repo.saved['mobit'] != 13; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(repo.saved['mobit'], 13);
    await tester.pump(const Duration(milliseconds: 300));
    expect(sends, 0);
    final prefs = await SharedPreferences.getInstance();
    const dirty = AssetSyncDirtyKeysStore();
    expect(await dirty.loadDirty('debt_payment_day_overrides', prefs: prefs),
        contains('mobit'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
  testWidgets('timeout stops later remote sends but allows local edit',
      (tester) async {
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    final failed = Completer<void>();
    final repo = _LocalDebtRepository();
    final calls = <Map<String, int>>[];
    final remote = <String, int>{};
    final day = DateTime.now();
    final date = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AssetManagementPage(
      assetLiabilityRepository: repo,
      debugInitialAssetData: <String, Map<String, double>>{
        date: const <String, double>{'モビット': -100000},
      },
      debugDebtOverrideProbeOwner: 'synthetic-owner',
      debugDebtOverrideProbeWriter: (owner, values) async {
        calls.add(Map<String, int>.from(values));
        await failed.future;
      },
      debugDebtOverrideDeletedProbeWriter: (owner, ids) async {},
    )));
    await tester.pump(const Duration(milliseconds: 600));
    final field = find.byKey(const Key('probe_debt_payment_day_mobit'));
    expect(field, findsOneWidget);
    tester.widget<DropdownButton<int?>>(field).onChanged!(10);
    for (var i = 0; i < 30 && calls.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(calls, hasLength(1));
    failed.completeError(TimeoutException('synthetic timeout'));
    await tester.pump(const Duration(milliseconds: 200));
    tester.widget<DropdownButton<int?>>(field).onChanged!(20);
    for (var i = 0; i < 30 && repo.saved['mobit'] != 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(repo.saved['mobit'], 20);
    // A server may still commit after the client saw the timeout.
    remote['mobit'] = 10;
    await tester.pump(const Duration(milliseconds: 200));
    expect(remote['mobit'], 10);
    expect(calls, hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    const dirty = AssetSyncDirtyKeysStore();
    expect(await dirty.loadDirty('debt_payment_day_overrides', prefs: prefs),
        contains('mobit'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
  testWidgets('owner switch retains dirty and never uploads to new owner',
      (tester) async {
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    final auth = ValueNotifier<String?>('synthetic-owner-A');
    addTearDown(auth.dispose);
    final first = Completer<void>();
    final owners = <String>[];
    final repo = _LocalDebtRepository();
    final day = DateTime.now();
    final date = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AssetManagementPage(
      assetLiabilityRepository: repo,
      debugInitialAssetData: <String, Map<String, double>>{
        date: const <String, double>{'モビット': -100000},
      },
      debugDebtOverrideProbeAuth: auth,
      debugDebtOverrideProbeWriter: (owner, values) async {
        owners.add(owner);
        await first.future;
      },
      debugDebtOverrideDeletedProbeWriter: (owner, ids) async {},
    )));
    await tester.pump(const Duration(milliseconds: 600));
    final field = find.byKey(const Key('probe_debt_payment_day_mobit'));
    expect(field, findsOneWidget);
    tester.widget<DropdownButton<int?>>(field).onChanged!(10);
    for (var i = 0; i < 40 && owners.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(owners, <String>['synthetic-owner-A']);
    auth.value = 'synthetic-owner-B';
    await tester.pump();
    tester.widget<DropdownButton<int?>>(field).onChanged!(20);
    for (var i = 0; i < 30 && repo.saved['mobit'] != 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(repo.saved['mobit'], 20);
    first.complete();
    await tester.pump(const Duration(milliseconds: 200));
    expect(owners, <String>['synthetic-owner-A']);
    final prefs = await SharedPreferences.getInstance();
    const dirty = AssetSyncDirtyKeysStore();
    expect(await dirty.loadDirty('debt_payment_day_overrides', prefs: prefs),
        contains('mobit'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}




