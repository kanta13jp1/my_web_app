import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/alt_supply_risk/alt_supply_risk_container.dart';
import 'package:my_web_app/features/alt_supply_risk/application/alt_supply_controller.dart';
import 'package:my_web_app/features/alt_supply_risk/data/supabase_alt_supply_repository.dart';
import 'package:my_web_app/features/alt_supply_risk/domain/alt_supply_models.dart';
import 'package:my_web_app/pages/enterprise_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _InMemoryAltSupplyRepository implements AltSupplyRepository {
  _InMemoryAltSupplyRepository({
    final List<AltSupplyScenario>? initialScenarios,
  }) : scenarios = List<AltSupplyScenario>.from(
          initialScenarios ?? const <AltSupplyScenario>[],
        );

  final List<AltSupplyScenario> scenarios;
  bool throwOnLoad = false;
  Completer<List<AltSupplyScenario>>? pendingLoad;

  @override
  Future<List<AltSupplyScenario>> listScenarios() async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('alt supply backend unavailable');
    }
    return List<AltSupplyScenario>.unmodifiable(scenarios);
  }

  @override
  Future<List<AltSupplyScenario>> seedDefaults() async {
    if (scenarios.isEmpty) {
      await createScenario(
        title: '国内作況低下・MA米転用リスク警戒シナリオ',
        stockpileTarget10kT: 100.0,
        domesticProcurement10kT: 64.0,
        stockpileThreshold10kT: 80.0,
        totalProductionTarget10kT: 800.0,
        currentProduction10kT: 735.0,
        maImportQuota10kT: 77.0,
      );
    }
    return List<AltSupplyScenario>.unmodifiable(scenarios);
  }

  @override
  Future<AltSupplyScenario> createScenario({
    required final String title,
    required final double stockpileTarget10kT,
    required final double domesticProcurement10kT,
    required final double stockpileThreshold10kT,
    required final double totalProductionTarget10kT,
    required final double currentProduction10kT,
    required final double maImportQuota10kT,
    final AltSupplySourceKind sourceKind = AltSupplySourceKind.manual,
    final String sourceRef = '',
    final String notes = '',
  }) async {
    final metrics = AltSupplyMetrics.evaluate(
      stockpileTarget10kT: stockpileTarget10kT,
      domesticProcurement10kT: domesticProcurement10kT,
      stockpileThreshold10kT: stockpileThreshold10kT,
      totalProductionTarget10kT: totalProductionTarget10kT,
      currentProduction10kT: currentProduction10kT,
      maImportQuota10kT: maImportQuota10kT,
    );
    final created = AltSupplyScenario(
      id: 'scn-${scenarios.length + 1}',
      title: title,
      sourceKind: sourceKind,
      sourceRef: sourceRef,
      stockpileTarget10kT: stockpileTarget10kT,
      domesticProcurement10kT: domesticProcurement10kT,
      stockpileThreshold10kT: stockpileThreshold10kT,
      totalProductionTarget10kT: totalProductionTarget10kT,
      currentProduction10kT: currentProduction10kT,
      maImportQuota10kT: maImportQuota10kT,
      metrics: metrics,
      notes: notes,
      updatedAt: DateTime.utc(2026, 11, 26, 0, scenarios.length),
    );
    scenarios.insert(0, created);
    return created;
  }

  @override
  Future<AltSupplyScenario> updateScenario({
    required final String id,
    required final String title,
    required final double stockpileTarget10kT,
    required final double domesticProcurement10kT,
    required final double stockpileThreshold10kT,
    required final double totalProductionTarget10kT,
    required final double currentProduction10kT,
    required final double maImportQuota10kT,
    final AltSupplySourceKind sourceKind = AltSupplySourceKind.manual,
    final String sourceRef = '',
    final String notes = '',
  }) async {
    final idx = scenarios.indexWhere(
      (final AltSupplyScenario s) => s.id == id,
    );
    final metrics = AltSupplyMetrics.evaluate(
      stockpileTarget10kT: stockpileTarget10kT,
      domesticProcurement10kT: domesticProcurement10kT,
      stockpileThreshold10kT: stockpileThreshold10kT,
      totalProductionTarget10kT: totalProductionTarget10kT,
      currentProduction10kT: currentProduction10kT,
      maImportQuota10kT: maImportQuota10kT,
    );
    final updated = AltSupplyScenario(
      id: id,
      title: title,
      sourceKind: sourceKind,
      sourceRef: sourceRef,
      stockpileTarget10kT: stockpileTarget10kT,
      domesticProcurement10kT: domesticProcurement10kT,
      stockpileThreshold10kT: stockpileThreshold10kT,
      totalProductionTarget10kT: totalProductionTarget10kT,
      currentProduction10kT: currentProduction10kT,
      maImportQuota10kT: maImportQuota10kT,
      metrics: metrics,
      notes: notes,
      updatedAt: DateTime.utc(2026, 11, 26, 1, 0),
    );
    scenarios[idx] = updated;
    return updated;
  }
}

class _FakeUser extends Fake implements User {
  @override
  String get id => 'user-supply-1';
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => _FakeUser();
}

class _FakeFunctionsClient extends Fake implements FunctionsClient {
  bool throwUnauthorized = false;

  @override
  Future<FunctionResponse> invoke(
    final String functionName, {
    final Map<String, String>? headers,
    final Object? body,
    final Iterable<Object?>? files,
    final Map<String, Object?>? queryParameters,
    final HttpMethod method = HttpMethod.post,
    final String? region,
  }) async {
    if (throwUnauthorized) {
      throw const FunctionException(
        status: 401,
        details: <String, Object?>{'error': 'Unauthorized'},
        reasonPhrase: 'Unauthorized',
      );
    }
    final req = body as Map<String, Object?>? ?? const <String, Object?>{};
    final action = req['action']?.toString() ?? '';
    if (action == 'alt_supply.list' || action == 'alt_supply.seed_defaults') {
      return FunctionResponse(
        status: 200,
        data: <String, Object?>{
          'success': true,
          'scenarios': <Object?>[
            <String, Object?>{
              'id': 'edge-scn-1',
              'title': 'MA米リスク警戒シナリオ',
              'stockpile_target_10k_t': 100.0,
              'domestic_procurement_10k_t': 62.0,
              'stockpile_threshold_10k_t': 80.0,
              'total_production_target_10k_t': 800.0,
              'current_production_10k_t': 740.0,
              'ma_import_quota_10k_t': 77.0,
              'updated_at': '2026-11-26T00:00:00Z',
            },
          ],
        },
      );
    }
    return FunctionResponse(
      status: 200,
      data: <String, Object?>{
        'success': true,
        'scenario': <String, Object?>{
          'id': req['id'] ?? 'edge-scn-2',
          'title': req['title'],
          'stockpile_target_10k_t': req['stockpile_target_10k_t'],
          'domestic_procurement_10k_t': req['domestic_procurement_10k_t'],
          'stockpile_threshold_10k_t': req['stockpile_threshold_10k_t'],
          'total_production_target_10k_t': req['total_production_target_10k_t'],
          'current_production_10k_t': req['current_production_10k_t'],
          'ma_import_quota_10k_t': req['ma_import_quota_10k_t'],
          'updated_at': '2026-11-26T00:10:00Z',
        },
      },
    );
  }
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  _FakeSupabaseClient(this._functions);

  final FunctionsClient _functions;

  @override
  FunctionsClient get functions => _functions;

  @override
  GoTrueClient get auth => _FakeGoTrueClient();
}

Future<void> _enterVisible(
  final WidgetTester tester,
  final Finder finder,
  final String value,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(
  final WidgetTester tester,
  final Finder finder,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('SupabaseAltSupplyRepository', () {
    test('lists, creates, updates, and maps 401 errors', () async {
      final functions = _FakeFunctionsClient();
      final repo = SupabaseAltSupplyRepository(
        client: _FakeSupabaseClient(functions),
      );

      final list = await repo.listScenarios();
      expect(list, hasLength(1));
      expect(list.first.metrics.stockpileShortfall10kT, 38.0);
      expect(list.first.metrics.belowProcurementThreshold, isTrue);

      final created = await repo.createScenario(
        title: 'テストシナリオ',
        stockpileTarget10kT: 100,
        domesticProcurement10kT: 90,
        stockpileThreshold10kT: 80,
        totalProductionTarget10kT: 800,
        currentProduction10kT: 810,
        maImportQuota10kT: 77,
      );
      expect(created.metrics.stockpileShortfall10kT, 10.0);
      expect(created.metrics.totalProductionGap10kT, 10.0);

      final updated = await repo.updateScenario(
        id: created.id,
        title: '更新シナリオ',
        stockpileTarget10kT: 100,
        domesticProcurement10kT: 100,
        stockpileThreshold10kT: 80,
        totalProductionTarget10kT: 800,
        currentProduction10kT: 800,
        maImportQuota10kT: 77,
      );
      expect(updated.metrics.stockpileShortfall10kT, 0.0);

      functions.throwUnauthorized = true;
      await expectLater(
        repo.listScenarios(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('AltSupplyController', () {
    test('ignores late fetch response after dispose', () async {
      final repo = _InMemoryAltSupplyRepository();
      final pending = Completer<List<AltSupplyScenario>>();
      repo.pendingLoad = pending;

      final ctrl = AltSupplyController(repository: repo);
      final future = ctrl.loadScenarios();
      ctrl.dispose();

      pending.complete(const <AltSupplyScenario>[]);
      await future;
      expect(ctrl.state.isLoading, isTrue);
    });
  });

  group('AltSupplyRiskContainer UI', () {
    testWidgets(
      'computes shortfall, triggers import escalation alert, and visualizes 800万t KPI gap',
      (final WidgetTester tester) async {
        final repo = _InMemoryAltSupplyRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AltSupplyRiskContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('alt_supply_empty_state')),
          findsOneWidget,
        );

        await _tapVisible(
          tester,
          find.byKey(const ValueKey<String>('alt_supply_seed_button')),
        );

        expect(
          find.byKey(const ValueKey<String>('alt_supply_escalation_banner')),
          findsOneWidget,
        );
        expect(find.text('不足分: 36.0 万t'), findsOneWidget);
        expect(find.textContaining('-65.0 万t'), findsOneWidget);

        // Raise domestic procurement to 92.0 (>= 80.0 threshold).
        await _enterVisible(
          tester,
          find.byKey(const ValueKey<String>('alt_supply_procurement_field')),
          '92.0',
        );
        await _enterVisible(
          tester,
          find.byKey(const ValueKey<String>('alt_supply_current_prod_field')),
          '805.0',
        );

        final stableBanner = find.byKey(
          const ValueKey<String>('alt_supply_stable_banner'),
        );
        await tester.ensureVisible(stableBanner);
        expect(stableBanner, findsOneWidget);
        expect(find.text('不足分: 8.0 万t'), findsOneWidget);
        expect(find.textContaining('+5.0 万t'), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey<String>('alt_supply_save_button')),
        );
        expect(
          find.byKey(const ValueKey<String>('alt_supply_notice_banner')),
          findsOneWidget,
        );
        expect(repo.scenarios.first.domesticProcurement10kT, 92.0);
      },
    );

    testWidgets(
      'passes Light/Dark accessibility guidelines on 360x800 and 1280x800',
      (final WidgetTester tester) async {
        final repo = _InMemoryAltSupplyRepository();
        await repo.seedDefaults();

        for (final brightness in const <Brightness>[
          Brightness.light,
          Brightness.dark,
        ]) {
          for (final size in const <Size>[
            Size(360, 800),
            Size(1280, 800),
          ]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;

            final handle = tester.ensureSemantics();
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF0F766E),
                    brightness: brightness,
                  ),
                ),
                home: Scaffold(
                  body: AltSupplyRiskContainer(repository: repo),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            handle.dispose();
          }
        }

        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      },
    );

    testWidgets(
      'is reachable from Enterprise cockpit AppBar action',
      (final WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: EnterprisePage()),
        );
        await tester.pumpAndSettle();

        final action = find.byKey(
          const Key('enterprise_alt_supply_risk_action'),
        );
        expect(action, findsOneWidget);

        await tester.tap(action);
        await tester.pumpAndSettle();

        expect(find.byType(AltSupplyRiskContainer), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
