import 'dart:convert';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_expected_inflow_store.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:my_web_app/widgets/asset_debt_owner_warning.dart';
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

class _SyntheticDebtRepository
    extends SharedPreferencesAssetLiabilityRepository {
  _SyntheticDebtRepository(Map<String, int> seed) : values = Map.of(seed);
  Map<String, int> values;
  Map<String, int>? lastSaved;
  int saveCalls = 0;

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async =>
      const AssetLiabilityMonthlyState();

  @override
  Future<Map<String, int>> loadDebtPaymentDayOverrides() async =>
      Map.of(values);

  @override
  Future<void> saveDebtPaymentDayOverrides(Map<String, int> overrides) async {
    saveCalls++;
    values = Map.of(overrides);
    lastSaved = Map.of(overrides);
  }
}

Future<Finder> _openDebtPage(
    WidgetTester tester, _SyntheticDebtRepository repo) async {
  AssetSyncDirtyKeysStore.resetWriteLockForTest();
  AssetRecurringTombstoneSyncService.resetSharedForTest();
  final now = DateTime.now().toUtc().toIso8601String();
  SharedPreferences.setMockInitialValues(<String, Object>{
    'fx_rate_usd_jpy_v1': jsonEncode(<String, Object>{
      'jpyPerUnit': 150.0,
      'fetchedAt': now,
      'asOf': now,
    }),
  });
  const mobile = bool.fromEnvironment('PRUNE_MOBILE');
  await tester.binding
      .setSurfaceSize(mobile ? const Size(390, 851) : const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: AssetManagementPage(
    assetLiabilityRepository: repo,
    debugNow: DateTime(2026, 10, 20),
    debugInitialAssetData: const <String, Map<String, double>>{
      '2026-10-20': <String, double>{'Synthetic mobit': -100000},
    },
  )));
  final card = find.byWidgetPredicate((widget) =>
      widget is Container &&
      widget.key is GlobalKey &&
      widget.key.toString().contains('debt_master_card_mobit'));
  final warning =
      find.descendant(of: card, matching: find.byType(AssetDebtOwnerWarning));
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (card.evaluate().length == 1 && warning.evaluate().length == 1) break;
  }
  expect(card, findsOneWidget);
  expect(warning, findsOneWidget);
  final control = find
      .ancestor(
          of: warning,
          matching: find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.width == 140,
          ))
      .first;
  final dropdown = find.descendant(
      of: control,
      matching: find.byWidgetPredicate(
        (widget) => widget is DropdownButton<int?>,
      ));
  expect(dropdown, findsOneWidget);
  return dropdown;
}

Future<Finder> _openDebtChoice(
    WidgetTester tester, Finder dropdown, int? day) async {
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  final item = find
      .byWidgetPredicate(
          (widget) => widget is DropdownMenuItem<int?> && widget.value == day)
      .last;
  expect(item, findsOneWidget);
  return item;
}

Future<SharedPreferences> _openPage(WidgetTester tester) async {
  debugPrint('SYNTHETIC_PRUNE_PHASE: open_page_start');
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
  debugPrint('SYNTHETIC_PRUNE_PHASE: before_pump_widget');
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
  debugPrint('SYNTHETIC_PRUNE_PHASE: after_pump_widget');
  final prefs = await SharedPreferences.getInstance();
  // Await the observed fake boot cleanup before reseeding a manual case.
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    final raw = prefs.getString(_inflowKey);
    if (raw != null && !raw.contains('boot-old')) break;
  }
  expect(prefs.getString(_inflowKey), isNotNull);
  expect(prefs.getString(_inflowKey), isNot(contains('boot-old')));
  debugPrint('SYNTHETIC_PRUNE_PHASE: boot_observed');
  return prefs;
}

Future<void> _openPruneDialog(WidgetTester tester) async {
  debugPrint('SYNTHETIC_PRUNE_PHASE: open_dialog');
  final inflow = find.byKey(const Key('asset_inflow_rules_button'));
  await tester.ensureVisible(inflow);
  await tester.tap(inflow);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.byKey(const Key('asset_tombstone_gc_edit')));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _prune(WidgetTester tester) async {
  debugPrint('SYNTHETIC_PRUNE_PHASE: tap_prune');
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
  var unexpectedSupabaseRequests = 0;
  final fakeSupabaseClient = MockClient((_) async {
    unexpectedSupabaseRequests++;
    throw StateError('Synthetic Supabase request prohibited');
  });
  void completedCase() {
    final data = binding.reportData ??= <String, dynamic>{};
    data['pruneCasesCompleted'] =
        (data['pruneCasesCompleted'] as int? ?? 0) + 1;
  }

  setUpAll(() async {
    debugPrint('SYNTHETIC_PRUNE_PHASE: setup_all');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: fakeSupabaseClient,
    );
    expect(unexpectedSupabaseRequests, 0);
  });

  tearDown(() {
    expect(unexpectedSupabaseRequests, 0);
  });

  testWidgets('boot and manual cleanup preserve synthetic payment-day raw', (
    tester,
  ) async {
    final prefs = await _openPage(tester);
    expect(prefs.getString(_debtKey), _oldDebt);
    expect(prefs.getString(_inflowKey), isNotNull);
    expect(prefs.getString(_inflowKey), isNot(contains('boot-old')));
    completedCase();
    debugPrint('SYNTHETIC_PRUNE_PHASE: boot_case_passed');

    await _openPruneDialog(tester);
    await prefs.setString(_inflowKey, _expired('manual-old'));
    await _prune(tester);
    expect(find.textContaining('古い削除記録を1件 掃除しました'), findsOneWidget);
    expect(find.textContaining('今回の一括掃除では対象外'), findsOneWidget);
    expect(prefs.getString(_debtKey), _oldDebt);
    expect(prefs.getString(_inflowKey), isNot(contains('manual-old')));
    completedCase();
    debugPrint('SYNTHETIC_PRUNE_PHASE: manual_one_passed');

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
    debugPrint('SYNTHETIC_PRUNE_PHASE: manual_zero_passed');
    await _close(tester);
    debugPrint('SYNTHETIC_PRUNE_PHASE: unmounted');
  });

  testWidgets('legacy name prevents clearing on actual debt page',
      (tester) async {
    const name = 'Synthetic mobit';
    final repo = _SyntheticDebtRepository(<String, int>{name: 14});
    final dropdown = await _openDebtPage(tester, repo);
    expect(tester.widget<DropdownButton<int?>>(dropdown).value, 14);
    final before = Map<String, int>.of(repo.values);
    final count = repo.saveCalls;
    final item = await _openDebtChoice(tester, dropdown, null);
    expect(tester.widget<DropdownMenuItem<int?>>(item).enabled, isFalse);
    await tester.ensureVisible(item);
    await tester.tap(item, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 600));
    expect(repo.values, before);
    expect(repo.saveCalls, count);
    expect(find.textContaining('この欄では解除できません'), findsWidgets);
    await _close(tester);
    expect(tester.takeException(), isNull);
    final data = binding.reportData ??= <String, dynamic>{};
    data['debtCasesCompleted'] = (data['debtCasesCompleted'] as int? ?? 0) + 1;
  });

  testWidgets('ID-only override permits clearing on actual debt page',
      (tester) async {
    final repo = _SyntheticDebtRepository(<String, int>{'mobit': 12});
    final dropdown = await _openDebtPage(tester, repo);
    expect(tester.widget<DropdownButton<int?>>(dropdown).value, 12);
    final item = await _openDebtChoice(tester, dropdown, null);
    expect(tester.widget<DropdownMenuItem<int?>>(item).enabled, isTrue);
    await tester.ensureVisible(item);
    expect(item.hitTestable(), findsOneWidget);
    await tester.tap(item);
    await tester.pump(const Duration(milliseconds: 600));
    expect(repo.lastSaved, isNotNull);
    expect(repo.lastSaved!.containsKey('mobit'), isFalse);
    await _close(tester);
    expect(tester.takeException(), isNull);
    final data = binding.reportData ??= <String, dynamic>{};
    data['debtCasesCompleted'] = (data['debtCasesCompleted'] as int? ?? 0) + 1;
  });

  testWidgets('different ID day keeps legacy name on actual debt page',
      (tester) async {
    const name = 'Synthetic mobit';
    final repo = _SyntheticDebtRepository(<String, int>{name: 14});
    final dropdown = await _openDebtPage(tester, repo);
    expect(tester.widget<DropdownButton<int?>>(dropdown).value, 14);
    final item = await _openDebtChoice(tester, dropdown, 15);
    expect(tester.widget<DropdownMenuItem<int?>>(item).enabled, isTrue);
    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pump(const Duration(milliseconds: 600));
    expect(repo.lastSaved, isNotNull);
    expect(repo.lastSaved![name], 14);
    expect(repo.lastSaved!['mobit'], 15);
    await _close(tester);
    expect(tester.takeException(), isNull);
    final data = binding.reportData ??= <String, dynamic>{};
    data['debtCasesCompleted'] = (data['debtCasesCompleted'] as int? ?? 0) + 1;
  });
}
