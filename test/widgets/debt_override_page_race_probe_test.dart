// PROBE ONLY. Not executed. Install into test/widgets only on a diagnostic
// branch together with debt_override_page_probe.patch; never into production.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LocalDebtRepository extends SharedPreferencesAssetLiabilityRepository {
  @override
  Future<Map<String, int>> loadDebtPaymentDayOverrides() async => {};

  @override
  Future<void> saveDebtPaymentDayOverrides(Map<String, int> value) async {}
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
    final first = Completer<void>();
    final second = Completer<void>();
    final sent = <Map<String, int>>[];
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
        debugInitialAssetData: {date: const {'モビット': -100000}},
        debugDebtOverrideProbeOwner: 'synthetic-owner',
        debugDebtOverrideProbeWriter: (owner, values) {
          expect(owner, 'synthetic-owner');
          sent.add(Map<String, int>.from(values));
          return sent.length == 1 ? first.future : second.future;
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
    expect(sent.first['mobit'], 10);

    tester.widget<DropdownButton<int?>>(field).onChanged!(20);
    for (var i = 0; i < 20 && sent.length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(sent, hasLength(2));
    expect(sent.last['mobit'], 20);
    const domain = 'debt_payment_day_overrides';
    const dirty = AssetSyncDirtyKeysStore();
    final prefs = await SharedPreferences.getInstance();
    expect(await dirty.loadDirty(domain, prefs: prefs), contains('mobit'));

    first.complete();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final observedAfterOldAck = await dirty.loadDirty(domain, prefs: prefs);
    // Finish the held future before asserting so the probe cleans up even on red.
    second.complete();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    // Expected red on the unmodified clearDomain call; not yet executed.
    expect(observedAfterOldAck, contains('mobit'));
  });
}
