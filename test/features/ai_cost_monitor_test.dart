import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/ai_cost_monitor/ai_cost_monitor_container.dart';
import 'package:my_web_app/features/ai_cost_monitor/application/ai_cost_monitor_controller.dart';
import 'package:my_web_app/features/ai_cost_monitor/data/supabase_ai_cost_repository.dart';
import 'package:my_web_app/features/ai_cost_monitor/domain/ai_cost_monitor_models.dart';
import 'package:my_web_app/pages/enterprise_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _InMemoryAiCostRepository implements AiCostMonitorRepository {
  _InMemoryAiCostRepository({
    final List<AiApiUsageLog>? initialLogs,
    this.pendingFetch,
  }) : _logs = List<AiApiUsageLog>.from(
          initialLogs ?? const <AiApiUsageLog>[],
        );

  final List<AiApiUsageLog> _logs;
  final Completer<AiCostDashboardSnapshot>? pendingFetch;
  final List<BudgetAlertRecord> _alerts = <BudgetAlertRecord>[];
  int _seq = 1;

  @override
  Future<AiCostDashboardSnapshot> fetchDashboard({
    final String? targetDate,
  }) async {
    if (pendingFetch != null) {
      return pendingFetch!.future;
    }
    final date = (targetDate != null && targetDate.isNotEmpty)
        ? targetDate
        : '2026-11-26';
    final byProviderMap = <String, _ProviderAcc>{};
    var knownCalls = 0;
    var unpricedCalls = 0;
    var totalCost = 0.0;
    var totalIn = 0;
    var totalOut = 0;
    for (final log in _logs) {
      totalIn += log.inputUnits;
      totalOut += log.outputUnits;
      final acc = byProviderMap.putIfAbsent(log.provider, _ProviderAcc.new);
      acc.calls += 1;
      acc.inUnits += log.inputUnits;
      acc.outUnits += log.outputUnits;
      if (log.knownPricing && log.estimatedCostUsd != null) {
        knownCalls += 1;
        totalCost += log.estimatedCostUsd!;
        acc.costUsd += log.estimatedCostUsd!;
      } else {
        unpricedCalls += 1;
        acc.unpriced += 1;
      }
    }
    final providers = byProviderMap.entries
        .map(
          (final entry) => ProviderCostBreakdown(
            provider: entry.key,
            callCount: entry.value.calls,
            unpricedCallCount: entry.value.unpriced,
            inputUnits: entry.value.inUnits,
            outputUnits: entry.value.outUnits,
            totalUnits: entry.value.inUnits + entry.value.outUnits,
            estimatedCostUsd: entry.value.costUsd,
          ),
        )
        .toList(growable: false);

    return AiCostDashboardSnapshot(
      targetDate: date,
      totalCalls: _logs.length,
      knownCostCalls: knownCalls,
      unpricedCallCount: unpricedCalls,
      totalCostUsd: totalCost,
      totalInputUnits: totalIn,
      totalOutputUnits: totalOut,
      totalUnits: totalIn + totalOut,
      byProvider: providers,
      logs: List<AiApiUsageLog>.unmodifiable(_logs),
      recentAlerts: List<BudgetAlertRecord>.unmodifiable(_alerts),
      pricingDisclaimer: AiCostDashboardSnapshot.empty.pricingDisclaimer,
    );
  }

  @override
  Future<AiApiUsageLog> recordUsage({
    required final String model,
    required final int inputUnits,
    required final int outputUnits,
    final String actionName = 'manual_entry',
  }) async {
    final normalized = model.trim().toLowerCase();
    final known = normalized == 'gemini-2.5-flash' ||
        normalized == 'gpt-4o-mini' ||
        normalized == 'claude-sonnet-4-5';
    final double? cost = normalized == 'gemini-2.5-flash'
        ? (inputUnits * 0.30 + outputUnits * 2.50) / 1000000
        : normalized == 'gpt-4o-mini'
            ? (inputUnits * 0.15 + outputUnits * 0.60) / 1000000
            : normalized == 'claude-sonnet-4-5'
                ? (inputUnits * 3.00 + outputUnits * 15.00) / 1000000
                : null;
    final provider = normalized.startsWith('gemini')
        ? 'gemini'
        : normalized.startsWith('gpt')
            ? 'openai'
            : normalized.startsWith('claude')
                ? 'anthropic'
                : 'unknown';
    final entry = AiApiUsageLog(
      id: 'usage-${_seq++}',
      provider: provider,
      model: normalized,
      actionName: actionName,
      inputUnits: inputUnits,
      outputUnits: outputUnits,
      totalUnits: inputUnits + outputUnits,
      knownPricing: known,
      estimatedCostUsd: cost,
      pricingNote: known ? 'reference' : 'unknown',
      recordedAt: '2026-11-26T09:00:00Z',
      usageDate: '2026-11-26',
    );
    _logs.insert(0, entry);
    return entry;
  }

  @override
  Future<BudgetCheckOutcome> checkBudget({
    required final double budgetThresholdUsd,
    final String? targetDate,
  }) async {
    final snapshot = await fetchDashboard(targetDate: targetDate);
    final exceeded = snapshot.totalCostUsd > budgetThresholdUsd;
    final exceededBy =
        exceeded ? snapshot.totalCostUsd - budgetThresholdUsd : 0.0;
    final title =
        '[AI Cost Alert] Daily 3rd-party AI API cost exceeded \$${budgetThresholdUsd.toStringAsFixed(2)}';
    if (exceeded) {
      _alerts.insert(
        0,
        BudgetAlertRecord(
          id: 'alert-${_seq++}',
          usageDate: snapshot.targetDate,
          dailyCostUsd: snapshot.totalCostUsd,
          budgetThresholdUsd: budgetThresholdUsd,
          exceededByUsd: exceededBy,
          issueTitle: title,
          githubStatus: 'skipped_no_token',
          githubIssueUrl: null,
          githubIssueNumber: null,
          recordedAt: '2026-11-26T09:05:00Z',
        ),
      );
    }
    var ghStatus = 'not_needed';
    if (exceeded) {
      ghStatus = 'skipped_no_token';
    }
    return BudgetCheckOutcome(
      targetDate: snapshot.targetDate,
      budgetThresholdUsd: budgetThresholdUsd,
      dailyCostUsd: snapshot.totalCostUsd,
      exceededByUsd: exceededBy,
      thresholdExceeded: exceeded,
      unpricedCallCount: snapshot.unpricedCallCount,
      githubStatus: ghStatus,
      issueTitle: title,
      githubIssueUrl: null,
      githubIssueNumber: null,
    );
  }
}

class _ProviderAcc {
  int calls = 0;
  int unpriced = 0;
  int inUnits = 0;
  int outUnits = 0;
  double costUsd = 0.0;
}

class _FakeUser extends Fake implements User {
  @override
  String get id => 'user-cost-1';
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
    if (action == 'ai_cost.daily_summary') {
      return FunctionResponse(
        status: 200,
        data: const <String, Object?>{
          'success': true,
          'target_date': '2026-11-26',
          'total_calls': 2,
          'known_cost_calls': 1,
          'unpriced_call_count': 1,
          'total_cost_usd': 0.75,
          'total_input_units': 1020000,
          'total_output_units': 505000,
          'total_units': 1525000,
          'by_provider': <Object?>[
            <String, Object?>{
              'provider': 'openai',
              'call_count': 1,
              'unpriced_call_count': 0,
              'input_units': 1000000,
              'output_units': 500000,
              'total_units': 1500000,
              'estimated_cost_usd': 0.75,
            },
          ],
          'recent_alerts': <Object?>[],
          'pricing_disclaimer': '参考単価に基づく概算です。',
        },
      );
    }
    if (action == 'ai_cost.list_usage') {
      return FunctionResponse(
        status: 200,
        data: const <String, Object?>{
          'success': true,
          'logs': <Object?>[
            <String, Object?>{
              'id': 'usage-1',
              'provider': 'openai',
              'model': 'gpt-4o-mini',
              'action_name': 'summarize',
              'input_units': 1000000,
              'output_units': 500000,
              'total_units': 1500000,
              'known_pricing': true,
              'estimated_cost_usd': 0.75,
              'pricing_note': 'OpenAI reference',
              'recorded_at': '2026-11-26T08:00:00Z',
              'usage_date': '2026-11-26',
            },
            <String, Object?>{
              'id': 'usage-2',
              'provider': 'unknown',
              'model': 'experimental-x',
              'action_name': 'test',
              'input_units': 20000,
              'output_units': 5000,
              'total_units': 25000,
              'known_pricing': false,
              'estimated_cost_usd': null,
              'pricing_note': 'unknown',
              'recorded_at': '2026-11-26T08:01:00Z',
              'usage_date': '2026-11-26',
            },
          ],
        },
      );
    }
    if (action == 'ai_cost.check_budget') {
      return FunctionResponse(
        status: 200,
        data: const <String, Object?>{
          'success': true,
          'target_date': '2026-11-26',
          'budget_threshold_usd': 0.5,
          'daily_cost_usd': 0.75,
          'exceeded_by_usd': 0.25,
          'threshold_exceeded': true,
          'unpriced_call_count': 1,
          'github_issue_payload': <String, Object?>{
            'title': '[AI Cost Alert] Exceeded',
          },
          'github_result': <String, Object?>{
            'status': 'created',
            'issue_number': 7777,
            'html_url': 'https://github.com/kanta13jp1/my_web_app/issues/7777',
          },
        },
      );
    }
    return FunctionResponse(
      status: 201,
      data: <String, Object?>{
        'success': true,
        'log': <String, Object?>{
          'id': 'usage-new',
          'provider': 'unknown',
          'model': req['model'] ?? 'unknown',
          'action_name': req['action_name'] ?? 'manual_entry',
          'input_units': req['input_units'] ?? 0,
          'output_units': req['output_units'] ?? 0,
          'total_units': 1000,
          'known_pricing': false,
          'estimated_cost_usd': null,
          'pricing_note': 'unknown',
          'recorded_at': '2026-11-26T08:10:00Z',
          'usage_date': '2026-11-26',
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

void main() {
  group('SupabaseAiCostRepository', () {
    test('parses daily summary, unknown null pricing, and 401 errors',
        () async {
      final functions = _FakeFunctionsClient();
      final repo = SupabaseAiCostRepository(
        client: _FakeSupabaseClient(functions),
      );

      final dashboard = await repo.fetchDashboard();
      expect(dashboard.totalCalls, 2);
      expect(dashboard.unpricedCallCount, 1);
      expect(dashboard.totalCostUsd, 0.75);
      expect(dashboard.logs.last.knownPricing, isFalse);
      expect(dashboard.logs.last.estimatedCostUsd, isNull);

      final outcome = await repo.checkBudget(budgetThresholdUsd: 0.5);
      expect(outcome.thresholdExceeded, isTrue);
      expect(outcome.githubStatus, 'created');
      expect(outcome.githubIssueNumber, 7777);

      functions.throwUnauthorized = true;
      await expectLater(
        repo.fetchDashboard(),
        throwsA(isA<AiCostAuthException>()),
      );
    });
  });

  group('AiCostMonitorController', () {
    test('ignores late fetch completion after dispose', () async {
      final completer = Completer<AiCostDashboardSnapshot>();
      final repo = _InMemoryAiCostRepository(pendingFetch: completer);
      final controller = AiCostMonitorController(repository: repo);

      final loadFuture = controller.loadDashboard();
      controller.dispose();

      completer.complete(AiCostDashboardSnapshot.empty);
      await loadFuture;
      expect(controller.state.isLoading, isTrue);
    });
  });

  group('AiCostMonitorContainer UI', () {
    testWidgets(
      'displays provider breakdown, unpriced badge, and budget alert banner',
      (final WidgetTester tester) async {
        final repo = _InMemoryAiCostRepository(
          initialLogs: const <AiApiUsageLog>[
            AiApiUsageLog(
              id: 'log-1',
              provider: 'anthropic',
              model: 'claude-sonnet-4-5',
              actionName: 'hold_board_meeting',
              inputUnits: 1000000,
              outputUnits: 200000,
              totalUnits: 1200000,
              knownPricing: true,
              estimatedCostUsd: 6.0,
              pricingNote: 'Anthropic reference',
              recordedAt: '2026-11-26T01:00:00Z',
              usageDate: '2026-11-26',
            ),
            AiApiUsageLog(
              id: 'log-2',
              provider: 'unknown',
              model: 'experimental-local',
              actionName: 'probe',
              inputUnits: 1000,
              outputUnits: 500,
              totalUnits: 1500,
              knownPricing: false,
              estimatedCostUsd: null,
              pricingNote: 'unknown',
              recordedAt: '2026-11-26T02:00:00Z',
              usageDate: '2026-11-26',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AiCostMonitorContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('\$6.0000'), findsWidgets);
        expect(find.text('1 件'), findsOneWidget);
        expect(find.text('単価未登録'), findsOneWidget);

        final thresholdField = find.byKey(
          const ValueKey<String>('budget_threshold_field'),
        );
        await tester.ensureVisible(thresholdField);
        await tester.enterText(thresholdField, '4.50');

        final checkButton = find.byKey(
          const ValueKey<String>('check_budget_button'),
        );
        await tester.ensureVisible(checkButton);
        await tester.tap(checkButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('ai_cost_budget_alert_banner')),
          findsOneWidget,
        );
        expect(find.textContaining('超過 \$1.5000'), findsOneWidget);

        final filterAnthropic = find.byKey(
          const ValueKey<String>('ai_cost_filter_anthropic'),
        );
        await tester.ensureVisible(filterAnthropic);
        await tester.tap(filterAnthropic);
        await tester.pumpAndSettle();

        expect(find.text('anthropic / claude-sonnet-4-5'), findsOneWidget);
        expect(find.text('unknown / experimental-local'), findsNothing);
      },
    );

    testWidgets(
      'passes responsive and WCAG accessibility audit in Light and Dark modes',
      (final WidgetTester tester) async {
        final repo = _InMemoryAiCostRepository(
          initialLogs: const <AiApiUsageLog>[
            AiApiUsageLog(
              id: 'log-a11y',
              provider: 'gemini',
              model: 'gemini-2.5-flash',
              actionName: 'summarize',
              inputUnits: 500000,
              outputUnits: 100000,
              totalUnits: 600000,
              knownPricing: true,
              estimatedCostUsd: 0.4,
              pricingNote: 'Gemini reference',
              recordedAt: '2026-11-26T04:00:00Z',
              usageDate: '2026-11-26',
            ),
          ],
        );

        for (final brightness in const <Brightness>[
          Brightness.light,
          Brightness.dark,
        ]) {
          for (final size in const <Size>[
            Size(360, 800),
            Size(1280, 800),
          ]) {
            final handle = tester.ensureSemantics();
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  useMaterial3: true,
                ),
                builder: (final context, final child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2.0),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: AiCostMonitorContainer(repository: repo),
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
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            handle.dispose();
          }
        }
      },
    );

    testWidgets(
      'EnterprisePage exposes AI cost monitor action cleanly',
      (final WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: EnterprisePage()),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('enterprise_ai_cost_monitor_action')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
