// DETACHED SYNTHETIC TEST CANDIDATE. NOT RUN. No real Auth or user data.
// Place under test/widgets/ only for isolated review with the warning candidate.
// The legacy reset case checks a temporary UI restriction; it does not prove
// that legacy-key recovery or deletion is available.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_revolving_credit_config_store.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:my_web_app/widgets/asset_debt_owner_warning.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Allow construction only. Neither this fake nor its close opens a socket.
class _NoNetworkClient implements HttpClient {
  _NoNetworkClient(this.guard);
  final _DenyAllHttp guard;

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // This includes request methods and all other unsupported methods/setters.
    // Count before throwing: production code may catch the exception.
    guard.blockedCalls++;
    throw StateError('Synthetic HttpClient invocation prohibited');
  }
}

/// Overrides dart:io HttpClient creation; injected Supabase mock rejects sends.
class _DenyAllHttp extends HttpOverrides {
  int blockedCalls = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _NoNetworkClient(this);
  }
}

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

class _ControlledRepository extends _SyntheticDebtRepository {
  _ControlledRepository(super.seed);
  bool holdWrites = false;
  bool rejectWrites = false;
  final List<Completer<void>> permits = [];
  final List<Map<String, int>> snapshots = [];

  @override
  Future<void> saveDebtPaymentDayOverrides(Map<String, int> overrides) async {
    if (!holdWrites && !rejectWrites) {
      return super.saveDebtPaymentDayOverrides(overrides);
    }
    snapshots.add(Map.of(overrides));
    if (rejectWrites) throw StateError('synthetic write failure');
    final permit = Completer<void>();
    permits.add(permit);
    await permit.future;
    values = Map.of(overrides);
  }
}

Finder _debtCard(String syntheticId) => find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.key is GlobalKey &&
          widget.key.toString().contains('debt_master_card_$syntheticId'),
      description: 'synthetic debt card $syntheticId',
    );

Future<void> _pumpSyntheticPage(
  WidgetTester tester, {
  required _SyntheticDebtRepository repository,
  required String accountName,
  Map<String, dynamic>? revolvingMirror,
}) async {
  final syntheticNow = DateTime(2026, 10, 20);
  await tester.binding.setSurfaceSize(const Size(1200, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: AssetManagementPage(
        assetLiabilityRepository: repository,
        debugNow: syntheticNow,
        debugInitialAssetData: <String, Map<String, double>>{
          '2026-10-20': <String, double>{accountName: -100000},
        },
        debugRevolvingConfigsMirror: revolvingMirror,
      ),
    ),
  );
  // The page has persistent animations; do not use pumpAndSettle.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  expect(
    _debtCard(accountName.contains('aupay') ? 'aupay_card' : 'mobit'),
    findsOneWidget,
  );
}

Future<void> _finishSyntheticPage(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
  expect(tester.takeException(), isNull);
}

void main() {
  final previousOverrides = HttpOverrides.current;
  final networkGuard = _DenyAllHttp();
  var deniedSupabaseRequests = 0;
  final syntheticSupabaseClient = MockClient((_) async {
    deniedSupabaseRequests++;
    throw StateError('Synthetic Supabase request prohibited');
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = networkGuard;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'synthetic-only',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: syntheticSupabaseClient,
    );
    expect(
      [networkGuard.blockedCalls, deniedSupabaseRequests],
      [0, 0],
      reason: 'Supabase initialization attempted a network operation',
    );
  });

  setUp(() {
    networkGuard.blockedCalls = 0;
    deniedSupabaseRequests = 0;
    final syntheticNow = DateTime.now().toUtc().toIso8601String();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'fx_rate_usd_jpy_v1': jsonEncode(<String, Object>{
        'jpyPerUnit': 150.0,
        'fetchedAt': syntheticNow,
        'asOf': syntheticNow,
      }),
    });
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
  });

  tearDownAll(() {
    HttpOverrides.global = previousOverrides;
  });

  tearDown(() {
    expect(
      [networkGuard.blockedCalls, deniedSupabaseRequests],
      [0, 0],
      reason:
          'Synthetic page attempted an unsupported client operation or request',
    );
  });

  testWidgets('legacy name override displays warning on the actual card', (
    tester,
  ) async {
    const name = 'Synthetic mobit';
    final repo = _SyntheticDebtRepository({name: 14});
    await _pumpSyntheticPage(tester, repository: repo, accountName: name);
    expect(
      find.descendant(
        of: _debtCard('mobit'),
        matching: find.byType(AssetDebtOwnerWarning),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _debtCard('mobit'), matching: find.text('14日')),
      findsWidgets,
    );
    await _finishSyntheticPage(tester);
  });

  testWidgets('ID override displays warning on the actual card', (
    tester,
  ) async {
    final repo = _SyntheticDebtRepository({'mobit': 12});
    await _pumpSyntheticPage(
      tester,
      repository: repo,
      accountName: 'Synthetic mobit',
    );
    expect(
      find.descendant(
        of: _debtCard('mobit'),
        matching: find.byType(AssetDebtOwnerWarning),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _debtCard('mobit'), matching: find.text('12日')),
      findsWidgets,
    );
    await _finishSyntheticPage(tester);
  });

  testWidgets('no override does not display this warning', (tester) async {
    final repo = _SyntheticDebtRepository({});
    await _pumpSyntheticPage(
      tester,
      repository: repo,
      accountName: 'Synthetic mobit',
    );
    expect(
      find.descendant(
        of: _debtCard('mobit'),
        matching: find.byType(AssetDebtOwnerWarning),
      ),
      findsNothing,
    );
    await _finishSyntheticPage(tester);
  });

  testWidgets('revolving row is outside this warning scope', (tester) async {
    final repo = _SyntheticDebtRepository({'aupay_card': 17});
    final mirror = AssetRevolvingCreditConfigStore.encodeMirrorValue(
      <String, AssetLiabilityRevolvingCreditConfig>{
        'aupay_card': const AssetLiabilityRevolvingCreditConfig(
          monthlyAmount: 10000,
          creditLimit: 500000,
        ),
      },
    );
    await _pumpSyntheticPage(
      tester,
      repository: repo,
      accountName: 'Synthetic aupay',
      revolvingMirror: mirror,
    );
    expect(
      find.byKey(const Key('asset_revolving_payoff_chip_aupay_card')),
      findsOneWidget,
    ); // Prevent a false pass from a non-revolving fixture.
    expect(
      find.descendant(
        of: _debtCard('aupay_card'),
        matching: find.byType(AssetDebtOwnerWarning),
      ),
      findsNothing,
    );
    await _finishSyntheticPage(tester);
  });

  testWidgets('legacy alias disables unset and does not save on tap', (
    tester,
  ) async {
    const name = 'Synthetic mobit';
    final repo = _SyntheticDebtRepository({name: 14});
    await _pumpSyntheticPage(tester, repository: repo, accountName: name);
    final card = _debtCard('mobit');
    final warning = find.descendant(
      of: card,
      matching: find.byType(AssetDebtOwnerWarning),
    );
    expect(warning, findsOneWidget);
    final control = find
        .ancestor(
          of: warning,
          matching: find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.width == 140,
          ),
        )
        .first;
    final dropdown = find.descendant(
      of: control,
      matching: find.byWidgetPredicate(
        (widget) => widget is DropdownButton<int?>,
      ),
    );
    expect(dropdown, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.textContaining('解除')),
      findsWidgets,
    );
    final beforeValues = Map<String, int>.from(repo.values);
    final beforeSaveCalls = repo.saveCalls;
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final unset = find
        .byWidgetPredicate(
          (widget) => widget is DropdownMenuItem<int?> && widget.value == null,
        )
        .last;
    expect(tester.widget<DropdownMenuItem<int?>>(unset).enabled, isFalse);
    await tester.tap(unset, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(repo.values, beforeValues);
    expect(repo.saveCalls, beforeSaveCalls);
    expect(
      find.descendant(of: card, matching: find.byType(AssetDebtOwnerWarning)),
      findsOneWidget,
    );
    await _finishSyntheticPage(tester);
  });

  testWidgets('ID-only override still permits unset', (tester) async {
    final repo = _SyntheticDebtRepository({'mobit': 12});
    await _pumpSyntheticPage(
      tester,
      repository: repo,
      accountName: 'Synthetic mobit',
    );
    final card = _debtCard('mobit');
    final warning = find.descendant(
      of: card,
      matching: find.byType(AssetDebtOwnerWarning),
    );
    expect(warning, findsOneWidget);
    final control = find
        .ancestor(
          of: warning,
          matching: find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.width == 140,
          ),
        )
        .first;
    final dropdown = find.descendant(
      of: control,
      matching: find.byWidgetPredicate(
        (widget) => widget is DropdownButton<int?>,
      ),
    );
    expect(dropdown, findsOneWidget);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final unset = find
        .byWidgetPredicate(
          (widget) => widget is DropdownMenuItem<int?> && widget.value == null,
        )
        .last;
    expect(tester.widget<DropdownMenuItem<int?>>(unset).enabled, isTrue);
    await tester.tap(unset);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(repo.lastSaved, isNotNull);
    expect(repo.lastSaved!.containsKey('mobit'), isFalse);
    await _finishSyntheticPage(tester);
  });

  testWidgets('legacy alias still permits setting a different ID day', (
    tester,
  ) async {
    const name = 'Synthetic mobit';
    final repo = _SyntheticDebtRepository({name: 14});
    await _pumpSyntheticPage(tester, repository: repo, accountName: name);
    final card = _debtCard('mobit');
    final warning = find.descendant(
      of: card,
      matching: find.byType(AssetDebtOwnerWarning),
    );
    expect(warning, findsOneWidget);
    final control = find
        .ancestor(
          of: warning,
          matching: find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.width == 140,
          ),
        )
        .first;
    final dropdown = find.descendant(
      of: control,
      matching: find.byWidgetPredicate(
        (widget) => widget is DropdownButton<int?>,
      ),
    );
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final changed = find
        .byWidgetPredicate(
          (widget) => widget is DropdownMenuItem<int?> && widget.value == 15,
        )
        .last;
    expect(tester.widget<DropdownMenuItem<int?>>(changed).enabled, isTrue);
    await tester.ensureVisible(changed);
    await tester.tap(changed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(repo.lastSaved, isNotNull);
    expect(repo.lastSaved![name], 14); // The legacy value is still retained.
    expect(repo.lastSaved!['mobit'], 15);
    await _finishSyntheticPage(tester);
  });

  testWidgets('duplicate IDs are held while a unique debt remains editable',
      (tester) async {
    final repo = _SyntheticDebtRepository({'mobit': 12, 'aupay_card': 13});
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          assetLiabilityRepository: repo,
          debugNow: DateTime(2026, 10, 20),
          debugInitialAssetData: const <String, Map<String, double>>{
            '2026-10-20': <String, double>{
              'Synthetic mobit alpha': -100000,
              'Synthetic mobit beta': -200000,
              'Synthetic aupay': -300000,
            },
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.takeException(),
      isNull,
      reason: 'duplicate ID must not duplicate a GlobalKey',
    );
    final warnings = find.textContaining('識別子または以前の口座名の重なりを確認するまで');
    expect(warnings, findsNWidgets(2));
    for (final warning in warnings.evaluate()) {
      Element? controlElement;
      warning.visitAncestorElements((element) {
        final widget = element.widget;
        if (widget is SizedBox && widget.width == 140) {
          controlElement = element;
          return false;
        }
        return true;
      });
      expect(controlElement, isNotNull);
      final control = find.byWidget(controlElement!.widget);
      final dropdown = find.descendant(
        of: control,
        matching: find.byType(DropdownButton<int?>),
      );
      expect(tester.widget<DropdownButton<int?>>(dropdown).onChanged, isNull);
    }
    final unique = find.descendant(
      of: _debtCard('aupay_card'),
      matching: find.byType(DropdownButton<int?>),
    );
    expect(unique, findsOneWidget);
    final before = repo.saveCalls;
    final callback = tester.widget<DropdownButton<int?>>(unique).onChanged;
    expect(callback, isNotNull);
    callback!(16);
    await tester.pump(const Duration(milliseconds: 600));
    expect(repo.saveCalls, greaterThan(before));
    expect(repo.lastSaved!['aupay_card'], 16);
    expect(repo.lastSaved!['mobit'], 12);
    final afterFirst = repo.saveCalls;
    callback(17); // The old row's value is stale after the first edit.
    await tester.pump(const Duration(milliseconds: 600));
    expect(repo.saveCalls, afterFirst);
    expect(repo.lastSaved!['aupay_card'], 16);
    await _finishSyntheticPage(tester);
  });

  testWidgets('ID colliding with another row name is held', (tester) async {
    final repo = _SyntheticDebtRepository({'custom_a': 12, 'mobit': 13});
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          assetLiabilityRepository: repo,
          debugNow: DateTime(2026, 10, 20),
          debugInitialAssetData: const <String, Map<String, double>>{
            '2026-10-20': <String, double>{
              'a': -100000,
              'custom_a': -200000,
              'Synthetic mobit': -300000,
            },
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('識別子または以前の口座名の重なりを確認するまで'),
      findsNWidgets(2),
    );
    final unique = find.descendant(
      of: _debtCard('mobit'),
      matching: find.byType(DropdownButton<int?>),
    );
    expect(tester.widget<DropdownButton<int?>>(unique).onChanged, isNotNull);
    await _finishSyntheticPage(tester);
  });

  testWidgets('an open payment-day menu closes after the page rebuilds',
      (tester) async {
    const name = 'Synthetic mobit';
    final repo = _SyntheticDebtRepository({'mobit': 12});
    await _pumpSyntheticPage(tester, repository: repo, accountName: name);
    final card = _debtCard('mobit');
    final dropdown = find.descendant(
      of: card,
      matching: find.byType(DropdownButton<int?>),
    );
    final pageStateBefore = tester.state(find.byType(AssetManagementPage));
    expect(
      find.text('画面が更新されると支払日メニューが閉じる場合があります。必要なら開き直してください。'),
      findsOneWidget,
    );
    final option = find.byWidgetPredicate(
      (widget) => widget is DropdownMenuItem<int?> && widget.value == 15,
    );
    expect(option, findsNothing, reason: 'the menu starts closed');
    final prefs = await SharedPreferences.getInstance();
    final dirtyBefore = prefs.getString(AssetSyncDirtyKeysStore.prefsKey);
    final tombstoneBefore =
        prefs.getString('debt_payment_day_override_deleted_v1');
    final valuesBefore = Map<String, int>.from(repo.values);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(option, findsWidgets, reason: 'the menu must first be open');
    expect(
      ModalRoute.of(option.last.evaluate().single),
      isA<PopupRoute<dynamic>>(),
    );
    final before = repo.saveCalls;
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          assetLiabilityRepository: repo,
          debugNow: DateTime(2026, 10, 20),
          debugInitialAssetData: const <String, Map<String, double>>{
            '2026-10-20': <String, double>{name: -100000},
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(option, findsNothing, reason: 'the old menu is no longer active');
    expect(
      identical(
        tester.state(find.byType(AssetManagementPage)),
        pageStateBefore,
      ),
      isTrue,
    );
    expect(repo.saveCalls, before);
    expect(repo.values, valuesBefore);
    expect(prefs.getString(AssetSyncDirtyKeysStore.prefsKey), dirtyBefore);
    expect(
      prefs.getString('debt_payment_day_override_deleted_v1'),
      tombstoneBefore,
    );
    expect(
      find.descendant(of: _debtCard('mobit'), matching: find.text('12日')),
      findsWidgets,
    );
    await _finishSyntheticPage(tester);
  });

  testWidgets(
      'shortfall retains debt events and explains held shift candidates',
      (tester) async {
    final repo = _SyntheticDebtRepository({'mobit': 15, 'aupay_card': 15});
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          assetLiabilityRepository: repo,
          debugNow: DateTime(2026, 7, 10),
          debugCalendarNow: DateTime(2026, 7, 10),
          debugInitialAssetData: const <String, Map<String, double>>{
            '2026-07-10': <String, double>{
              '財布(現金)': 10000,
              'Synthetic mobit alpha': -300000,
              'Synthetic mobit beta': -300000,
              'Synthetic aupay': -300000,
            },
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('期間内の最大不足:'), findsOneWidget);
    expect(
      find.textContaining('支払日変更の提案を表示していません。支払いが不要とは限りません。'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('asset_shift_payment_mobit')), findsNothing);
    expect(
      find.byKey(const Key('asset_shift_payment_aupay_card')),
      findsOneWidget,
    );
    await _finishSyntheticPage(tester);
  });

  testWidgets('diagnostic write serializes held fake updates', (tester) async {
    final repo = _ControlledRepository({'mobit': 12});
    await _pumpSyntheticPage(tester, repository: repo, accountName: 'Synthetic mobit');
    final access = tester.state(find.byType(AssetManagementPage)) as WriteOrderDiagnosticAccess;
    repo.holdWrites = true;
    expect(access.diagnosticSetDebtDay('mobit', 15), isTrue);
    expect(access.diagnosticSetDebtDay('mobit', 20), isTrue);
    await tester.pump();
    expect(repo.snapshots, [{'mobit': 15}]);
    expect(repo.permits, hasLength(1));
    repo.permits[0].complete();
    await tester.pump();
    expect(repo.values, {'mobit': 15});
    expect(repo.snapshots, [{'mobit': 15}, {'mobit': 20}]);
    expect(repo.permits, hasLength(2));
    repo.permits[1].complete();
    await tester.pump();
    expect(repo.values, {'mobit': 20});
    await _finishSyntheticPage(tester);
  });

  testWidgets('diagnostic write failure does not enter mirror function', (tester) async {
    final repo = _ControlledRepository({'mobit': 12});
    await _pumpSyntheticPage(tester, repository: repo, accountName: 'Synthetic mobit');
    final access = tester.state(find.byType(AssetManagementPage)) as WriteOrderDiagnosticAccess;
    final mirrorBefore = access.diagnosticMirrorEntries;
    repo.rejectWrites = true;
    expect(access.diagnosticSetDebtDay('mobit', 20), isTrue);
    await tester.pump();
    expect(repo.values, {'mobit': 12});
    expect(repo.snapshots, [{'mobit': 20}]);
    expect(access.diagnosticMirrorEntries, mirrorBefore, reason: 'the mirror method is not entered after the synthetic local error');
    repo.rejectWrites = false;
    expect(access.diagnosticSetDebtDay('mobit', 25), isTrue);
    await tester.pump();
    expect(repo.values, {'mobit': 25}, reason: 'the queue must continue after a local exception');
    expect(access.diagnosticMirrorEntries, mirrorBefore + 1);
    expect(Supabase.instance.client.auth.currentUser, isNull);
    await _finishSyntheticPage(tester);
  });
}
