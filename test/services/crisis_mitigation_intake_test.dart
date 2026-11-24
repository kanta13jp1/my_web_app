import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/crisis_mitigation_service.dart';
import 'package:my_web_app/widgets/crisis_mitigation_intake_panel.dart';

class _FakeCrisisIntakeRepository implements CrisisIntakeRepository {
  _FakeCrisisIntakeRepository({
    required List<CrisisRiskItem> seedRisks,
    required List<MitigationPlanItem> seedPlans,
    required this.failFetch,
  })  : risks = List<CrisisRiskItem>.from(seedRisks),
        plans = List<MitigationPlanItem>.from(seedPlans);

  final List<CrisisRiskItem> risks;
  final List<MitigationPlanItem> plans;
  final bool failFetch;

  @override
  Future<CrisisIntakeSnapshot> fetchAll() async {
    if (failFetch) {
      throw StateError('network unreachable');
    }
    return CrisisIntakeSnapshot(
      risks: List<CrisisRiskItem>.unmodifiable(risks),
      plans: List<MitigationPlanItem>.unmodifiable(plans),
    );
  }

  @override
  Future<CrisisRiskItem> createRisk({
    required String title,
    required CrisisCategory category,
    required CrisisSeverity severity,
    required int likelihood,
    required int impact,
    CrisisStatus status = CrisisStatus.monitoring,
    String notes = '',
  }) async {
    final created = CrisisRiskItem(
      id: 'risk-${risks.length + 1}',
      userId: 'user-crisis-1',
      title: title,
      category: category,
      severity: severity,
      likelihood: likelihood,
      impact: impact,
      status: status,
      notes: notes,
      createdAt: DateTime.utc(2026, 11, 24),
      updatedAt: DateTime.utc(2026, 11, 24),
    );
    risks.insert(0, created);
    return created;
  }

  @override
  Future<MitigationPlanItem> createMitigationPlan({
    required String riskId,
    required String actionTitle,
    String ownerRole = '',
    String triggerCondition = '',
    int offlinePriority = 1,
    bool isOfflineEssential = true,
  }) async {
    final created = MitigationPlanItem(
      id: 'plan-${plans.length + 1}',
      riskId: riskId,
      userId: 'user-crisis-1',
      actionTitle: actionTitle,
      ownerRole: ownerRole,
      triggerCondition: triggerCondition,
      offlinePriority: offlinePriority,
      isOfflineEssential: isOfflineEssential,
      createdAt: DateTime.utc(2026, 11, 24),
    );
    plans.insert(0, created);
    return created;
  }
}

CrisisRiskItem _sampleRisk() {
  return CrisisRiskItem(
    id: 'risk-seed-1',
    userId: 'user-crisis-1',
    title: '首都圏大規模地震による通信途絶',
    category: CrisisCategory.naturalDisaster,
    severity: CrisisSeverity.critical,
    likelihood: 4,
    impact: 5,
    status: CrisisStatus.monitoring,
    notes: '防災備蓄・非常電源と衛星連絡網の確保が必要',
    createdAt: DateTime.utc(2026, 11, 24),
    updatedAt: DateTime.utc(2026, 11, 24),
  );
}

MitigationPlanItem _sampleEssentialPlan() {
  return MitigationPlanItem(
    id: 'plan-essential-1',
    riskId: 'risk-seed-1',
    userId: 'user-crisis-1',
    actionTitle: '衛星端末起動と安否確認ボード同期',
    ownerRole: '防災対策本部長',
    triggerCondition: '震度5強以上または基地局停波',
    offlinePriority: 1,
    isOfflineEssential: true,
    createdAt: DateTime.utc(2026, 11, 24),
  );
}

MitigationPlanItem _sampleNonEssentialPlan() {
  return MitigationPlanItem(
    id: 'plan-optional-2',
    riskId: 'risk-seed-1',
    userId: 'user-crisis-1',
    actionTitle: '事後広報リリース文面レビュー',
    ownerRole: '広報担当',
    triggerCondition: '復旧フェーズ移行後',
    offlinePriority: 5,
    isOfflineEssential: false,
    createdAt: DateTime.utc(2026, 11, 24),
  );
}

void main() {
  group('CrisisMitigationService & Offline Cache (#2584)', () {
    test('parses models, clamps bounds, and computes riskScore', () {
      final risk = CrisisRiskItem.fromJson(const <String, dynamic>{
        'id': 'r-1',
        'user_id': 'u-1',
        'title': 'データセンター電源喪失',
        'category': 'infra_outage',
        'severity': 'high',
        'likelihood': 9,
        'impact': 0,
        'status': 'mitigating',
        'notes': 'UPS切替試験済み',
      });
      expect(risk.category, CrisisCategory.infraOutage);
      expect(risk.severity, CrisisSeverity.high);
      expect(risk.likelihood, 5);
      expect(risk.impact, 1);
      expect(risk.riskScore, 5);
      expect(risk.status, CrisisStatus.mitigating);
      expect(risk.toJson()['category'], 'infra_outage');

      final plan = MitigationPlanItem.fromJson(const <String, dynamic>{
        'id': 'p-1',
        'risk_id': 'r-1',
        'user_id': 'u-1',
        'action_title': '非常用発電機を起動',
        'owner_role': 'SREリード',
        'trigger_condition': '商用電源断3分経過',
        'offline_priority': 10,
        'is_offline_essential': true,
      });
      expect(plan.offlinePriority, 5);
      expect(plan.isOfflineEssential, isTrue);
      expect(plan.toJson()['is_offline_essential'], isTrue);
    });

    test(
      'caches only isOfflineEssential plans sorted by priority and falls back on fetch error',
      () async {
        final store = InMemoryCrisisOfflineCacheStore();
        final cacheService = CrisisOfflineCacheService(store: store);

        final onlineRepo = _FakeCrisisIntakeRepository(
          seedRisks: <CrisisRiskItem>[_sampleRisk()],
          seedPlans: <MitigationPlanItem>[
            _sampleNonEssentialPlan(),
            _sampleEssentialPlan(),
          ],
          failFetch: false,
        );
        final onlineService = CrisisMitigationService(
          repository: onlineRepo,
          cacheService: cacheService,
        );

        final liveSnapshot = await onlineService.loadWithOfflineFallback();
        expect(liveSnapshot.fromOfflineCache, isFalse);
        expect(liveSnapshot.plans.length, 2);

        // Simulate disaster network outage while reusing the same offline cache store
        final offlineRepo = _FakeCrisisIntakeRepository(
          seedRisks: const <CrisisRiskItem>[],
          seedPlans: const <MitigationPlanItem>[],
          failFetch: true,
        );
        final offlineService = CrisisMitigationService(
          repository: offlineRepo,
          cacheService: cacheService,
        );

        final fallbackSnapshot = await offlineService.loadWithOfflineFallback();
        expect(fallbackSnapshot.fromOfflineCache, isTrue);
        expect(fallbackSnapshot.warningMessage, isNotNull);
        expect(fallbackSnapshot.risks.length, 1);
        expect(fallbackSnapshot.plans.length, 1);
        expect(fallbackSnapshot.plans.single.id, 'plan-essential-1');
        expect(fallbackSnapshot.plans.single.isOfflineEssential, isTrue);

        // Corrupt cache degrades cleanly to null
        await store.writePayload('{not-valid-json');
        expect(await cacheService.loadCachedSnapshot(), isNull);
      },
    );
  });

  group('CrisisMitigationIntakePanel widget & accessibility (#2584)', () {
    testWidgets(
      'validates empty title, submits risk and mitigation plan, and updates offline cache',
      (WidgetTester tester) async {
        final store = InMemoryCrisisOfflineCacheStore();
        final repo = _FakeCrisisIntakeRepository(
          seedRisks: const <CrisisRiskItem>[],
          seedPlans: const <MitigationPlanItem>[],
          failFetch: false,
        );
        final service = CrisisMitigationService(
          repository: repo,
          cacheService: CrisisOfflineCacheService(store: store),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: CrisisMitigationIntakePanel(service: service),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('crisis_online_sync_badge')),
          findsOneWidget,
        );

        // Empty risk title shows validation error
        final submitRiskBtn =
            find.byKey(const ValueKey<String>('crisis_submit_risk_button'));
        await tester.ensureVisible(submitRiskBtn);
        await tester.tap(submitRiskBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('crisis_form_error_text')),
          findsOneWidget,
        );

        // Submit risk intake
        final titleInput =
            find.byKey(const ValueKey<String>('crisis_risk_title_input'));
        await tester.ensureVisible(titleInput);
        await tester.enterText(titleInput, '豪雨による拠点浸水リスク');
        await tester.ensureVisible(submitRiskBtn);
        await tester.tap(submitRiskBtn);
        await tester.pumpAndSettle();

        expect(repo.risks.length, 1);
        expect(repo.risks.single.title, '豪雨による拠点浸水リスク');
        expect(
          find.byKey(const ValueKey<String>('crisis_risk_card_risk-1')),
          findsOneWidget,
        );

        // Submit mitigation plan intake
        final actionInput =
            find.byKey(const ValueKey<String>('crisis_plan_action_input'));
        await tester.ensureVisible(actionInput);
        await tester.enterText(actionInput, '止水板設置とサーバーラック退避');
        await tester.enterText(
          find.byKey(const ValueKey<String>('crisis_plan_owner_input')),
          '施設管理担当',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('crisis_plan_trigger_input')),
          '警戒レベル4発令時',
        );
        final submitPlanBtn =
            find.byKey(const ValueKey<String>('crisis_submit_plan_button'));
        await tester.ensureVisible(submitPlanBtn);
        await tester.tap(submitPlanBtn);
        await tester.pumpAndSettle();

        expect(repo.plans.length, 1);
        expect(repo.plans.single.actionTitle, '止水板設置とサーバーラック退避');
        expect(
          find.byKey(const ValueKey<String>('crisis_plan_card_plan-1')),
          findsOneWidget,
        );

        // Verify offline cache persisted the essential plan
        final cached =
            await CrisisOfflineCacheService(store: store).loadCachedSnapshot();
        expect(cached, isNotNull);
        expect(cached!.plans.single.actionTitle, '止水板設置とサーバーラック退避');
      },
    );

    testWidgets(
      'loads cached essential emergency plans with offline banner when repository fetch throws',
      (WidgetTester tester) async {
        final store = InMemoryCrisisOfflineCacheStore();
        final cacheService = CrisisOfflineCacheService(store: store);
        await cacheService.saveSnapshot(
          risks: <CrisisRiskItem>[_sampleRisk()],
          plans: <MitigationPlanItem>[
            _sampleEssentialPlan(),
            _sampleNonEssentialPlan(),
          ],
          cachedAt: DateTime.utc(2026, 11, 24, 1, 30),
        );

        final failingRepo = _FakeCrisisIntakeRepository(
          seedRisks: const <CrisisRiskItem>[],
          seedPlans: const <MitigationPlanItem>[],
          failFetch: true,
        );
        final service = CrisisMitigationService(
          repository: failingRepo,
          cacheService: cacheService,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: CrisisMitigationIntakePanel(service: service),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('crisis_offline_cache_banner')),
          findsOneWidget,
        );
        expect(find.text('オフライン防災キャッシュ表示中'), findsOneWidget);
        expect(find.text('衛星端末起動と安否確認ボード同期'), findsOneWidget);
        expect(find.text('事後広報リリース文面レビュー'), findsNothing);
      },
    );

    testWidgets(
      'passes 390x844 and 1280x800 light/dark 2.0x textScale and WCAG semantics guidelines',
      (WidgetTester tester) async {
        final viewports = <Size>[
          const Size(390, 844),
          const Size(1280, 800),
        ];
        final themes = <ThemeData>[
          ThemeData.light(),
          ThemeData.dark(),
        ];
        final snapshots = <CrisisIntakeSnapshot>[
          CrisisIntakeSnapshot(
            risks: <CrisisRiskItem>[_sampleRisk()],
            plans: <MitigationPlanItem>[_sampleEssentialPlan()],
            fromOfflineCache: false,
          ),
          CrisisIntakeSnapshot(
            risks: <CrisisRiskItem>[_sampleRisk()],
            plans: <MitigationPlanItem>[_sampleEssentialPlan()],
            fromOfflineCache: true,
            warningMessage: '通信障害のためオフライン防災キャッシュを表示しています。',
          ),
        ];

        for (final viewport in viewports) {
          for (final theme in themes) {
            for (final snapshot in snapshots) {
              final SemanticsHandle handle = tester.ensureSemantics();
              try {
                tester.view.physicalSize = viewport;
                tester.view.devicePixelRatio = 1.0;

                await tester.pumpWidget(
                  MaterialApp(
                    key: ValueKey<String>(
                      '${viewport.width}_${theme.brightness}_${snapshot.fromOfflineCache}',
                    ),
                    theme: theme,
                    home: MediaQuery(
                      data: MediaQueryData(
                        size: viewport,
                        textScaler: const TextScaler.linear(2.0),
                      ),
                      child: Scaffold(
                        body: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: CrisisMitigationIntakePanel(
                            initialSnapshot: snapshot,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                expect(
                  find.byKey(
                    const ValueKey<String>('crisis_mitigation_intake_panel'),
                  ),
                  findsOneWidget,
                );

                await expectLater(
                  tester,
                  meetsGuideline(androidTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(labeledTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(textContrastGuideline),
                );
              } finally {
                handle.dispose();
                tester.view.resetPhysicalSize();
                tester.view.resetDevicePixelRatio();
              }
            }
          }
        }
      },
    );
  });
}
