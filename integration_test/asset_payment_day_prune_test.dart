import 'dart:convert';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_expected_inflow_store.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DiagnosticBinding extends IntegrationTestWidgetsFlutterBinding {
  @override
  void reportExceptionNoticed(foundation.FlutterErrorDetails exception) {
    final data = reportData ??= <String, dynamic>{};
    final errors =
        data.putIfAbsent('frameworkErrors', () => <String>[]) as List<String>;
    if (errors.length < 20) errors.add(exception.toString());
    super.reportExceptionNoticed(exception);
  }
}

// All values, the preference store and the loopback Supabase endpoint are fake.
const _debtKey = 'debt_payment_day_override_deleted_v1';
const _inflowKey = 'asset_expected_inflow_deleted_ids_v1';
const _oldDebt =
    '[{"id":"synthetic-unassigned","at":"2020-01-01T00:00:00.000Z"}]';
String _expired(String id) => jsonEncode(<Map<String, String>>[
  <String, String>{'id': id, 'at': '2020-01-01T00:00:00.000Z'},
]);

Future<SharedPreferences> _openPage(WidgetTester tester) async {
  AssetSyncDirtyKeysStore.resetWriteLockForTest();
  AssetRecurringTombstoneSyncService.resetSharedForTest();
  SharedPreferences.setMockInitialValues(<String, Object>{
    _debtKey: _oldDebt,
    _inflowKey: _expired('boot-old'),
    'fx_rate_usd_jpy_v1': jsonEncode(<String, dynamic>{
      'jpyPerUnit': 150,
      'fetchedAt': DateTime.now().toUtc().toIso8601String(),
      'asOf': DateTime.now().toUtc().toIso8601String(),
    }),
    'asset_expected_inflow_rules_v1': jsonEncode(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'synthetic-rule',
        'day_of_month': 25,
        'amount': 1234,
        'label': '合成入金',
      },
    ]),
  });
  const mobile = bool.fromEnvironment('PRUNE_MOBILE');
  const viewport = mobile ? Size(390, 851) : Size(1440, 1000);
  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    const MaterialApp(
      home: AssetManagementPage(
        debugTombstoneGcConfig: AssetTombstoneGcConfig(
          maxCount: 1000,
          maxAgeDays: 10,
        ),
      ),
    ),
  );
  final prefs = await SharedPreferences.getInstance();
  // Await the observed fake boot cleanup before reseeding a manual case.
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    final raw = prefs.getString(_inflowKey);
    if (raw != null && !raw.contains('boot-old')) break;
  }
  expect(prefs.getString(_inflowKey), isNotNull);
  expect(prefs.getString(_inflowKey), isNot(contains('boot-old')));
  return prefs;
}

Future<void> _openPruneDialog(WidgetTester tester) async {
  final inflow = find.byKey(const Key('asset_inflow_rules_button'));
  await tester.ensureVisible(inflow);
  await tester.tap(inflow);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.byKey(const Key('asset_tombstone_gc_edit')));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _prune(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('asset_tombstone_gc_prune')));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  final binding = _DiagnosticBinding();
  void completedCase() {
    final data = binding.reportData ??= <String, dynamic>{};
    data['pruneCasesCompleted'] =
        (data['pruneCasesCompleted'] as int? ?? 0) + 1;
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  testWidgets('boot and manual cleanup preserve synthetic payment-day raw', (
    tester,
  ) async {
    final prefs = await _openPage(tester);
    expect(prefs.getString(_debtKey), _oldDebt);
    expect(prefs.getString(_inflowKey), isNotNull);
    expect(prefs.getString(_inflowKey), isNot(contains('boot-old')));
    completedCase();

    await _openPruneDialog(tester);
    await prefs.setString(_inflowKey, _expired('manual-old'));
    await _prune(tester);
    expect(find.textContaining('古い削除記録を1件 掃除しました'), findsOneWidget);
    expect(find.textContaining('今回の一括掃除では対象外'), findsOneWidget);
    expect(prefs.getString(_debtKey), _oldDebt);
    expect(prefs.getString(_inflowKey), isNot(contains('manual-old')));
    completedCase();

    // Let the first SnackBar finish before observing the next user action.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('古い削除記録を1件 掃除しました'), findsNothing);
    await prefs.setString(_inflowKey, '[]');
    await _prune(tester);
    expect(find.textContaining('古い削除記録を0件 掃除しました'), findsOneWidget);
    expect(find.textContaining('今回の一括掃除では対象外'), findsOneWidget);
    expect(prefs.getString(_debtKey), _oldDebt);
    completedCase();
    await _close(tester);
  });
}
