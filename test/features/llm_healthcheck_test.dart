import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/llm_healthcheck/application/llm_healthcheck_controller.dart';
import 'package:my_web_app/features/llm_healthcheck/data/supabase_llm_healthcheck_repository.dart';
import 'package:my_web_app/features/llm_healthcheck/domain/llm_healthcheck_models.dart';
import 'package:my_web_app/features/llm_healthcheck/llm_healthcheck_container.dart';
import 'package:my_web_app/pages/enterprise_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _InMemoryHealthRepository implements LlmHealthcheckRepository {
  _InMemoryHealthRepository({this.pendingFetch});

  final Completer<LlmHealthDashboardSnapshot>? pendingFetch;
  final List<LlmEndpointConfig> _endpoints = <LlmEndpointConfig>[];
  final List<LlmHealthLog> _logs = <LlmHealthLog>[];
  final List<LlmHealthAlert> _alerts = <LlmHealthAlert>[];
  int _seq = 1;
  bool simulateNextDown = false;

  @override
  Future<LlmHealthDashboardSnapshot> fetchSummary() async {
    if (pendingFetch != null) return pendingFetch!.future;
    var healthyAll = 0;
    var latSum = 0;
    final summaries = <ProviderUptimeSummary>[];
    for (final ep in _endpoints) {
      final epLogs = _logs
          .where((final l) => l.endpointId == ep.id)
          .toList(growable: false);
      final epHealthy = epLogs.where((final l) => l.status != 'down').length;
      var latTotal = 0;
      for (final log in epLogs) {
        latTotal += log.latencyMs;
      }
      final epLat = epLogs.isEmpty ? 0 : latTotal ~/ epLogs.length;
      summaries.add(
        ProviderUptimeSummary(
          providerName: ep.providerName,
          endpointId: ep.id,
          totalChecks: epLogs.length,
          healthyChecks: epHealthy,
          uptimePct:
              epLogs.isEmpty ? 100.0 : (epHealthy / epLogs.length) * 100.0,
          avgLatencyMs: epLat,
          latestStatus: epLogs.isEmpty ? null : epLogs.first.status,
          latestLatencyMs: epLogs.isEmpty ? null : epLogs.first.latencyMs,
        ),
      );
    }
    for (final log in _logs) {
      latSum += log.latencyMs;
      if (log.status != 'down') healthyAll += 1;
    }
    return LlmHealthDashboardSnapshot(
      overallUptimePct:
          _logs.isEmpty ? 100.0 : (healthyAll / _logs.length) * 100.0,
      avgLatencyMs: _logs.isEmpty ? 0 : (latSum ~/ _logs.length),
      providers: summaries,
      endpoints: List<LlmEndpointConfig>.unmodifiable(_endpoints),
      logs: List<LlmHealthLog>.unmodifiable(_logs),
      alerts: List<LlmHealthAlert>.unmodifiable(_alerts),
    );
  }

  @override
  Future<void> seedDefaults() async {
    if (_endpoints.isNotEmpty) return;
    await upsertEndpoint(
      providerName: 'OpenAI Status',
      endpointUrl: 'https://status.openai.com/api/v2/status.json',
    );
  }

  @override
  Future<LlmEndpointConfig> upsertEndpoint({
    final String? id,
    required final String providerName,
    required final String endpointUrl,
    final String method = 'GET',
    final int timeoutMs = 5000,
    final String alertChannel = 'ops-alerts',
  }) async {
    final ep = LlmEndpointConfig(
      id: id ?? 'ep-${_seq++}',
      providerName: providerName,
      endpointUrl: endpointUrl,
      method: method,
      timeoutMs: timeoutMs,
      alertChannel: alertChannel,
      enabled: true,
      updatedAt: '2026-11-26T00:00:00Z',
    );
    _endpoints.insert(0, ep);
    return ep;
  }

  @override
  Future<void> deleteEndpoint(final String id) async {
    _endpoints.removeWhere((final e) => e.id == id);
  }

  @override
  Future<void> runProbe({final String? endpointId}) async {
    final targets = endpointId == null
        ? _endpoints
        : _endpoints.where((final e) => e.id == endpointId).toList();
    for (final ep in targets) {
      final isDown = simulateNextDown;
      _logs.insert(
        0,
        LlmHealthLog(
          id: 'log-${_seq++}',
          endpointId: ep.id,
          providerName: ep.providerName,
          endpointUrl: ep.endpointUrl,
          status: isDown ? 'down' : 'healthy',
          httpStatus: isDown ? null : 200,
          latencyMs: isDown ? ep.timeoutMs : 120,
          errorType: isDown ? 'timeout' : null,
          errorMessage: isDown ? 'Probe timed out' : null,
          checkedAt: '2026-11-26T01:00:00Z',
        ),
      );
      if (isDown) {
        _alerts.insert(
          0,
          LlmHealthAlert(
            id: 'alert-${_seq++}',
            endpointId: ep.id,
            providerName: ep.providerName,
            status: 'down',
            errorType: 'timeout',
            errorMessage: 'Probe timed out',
            alertChannel: ep.alertChannel,
            deliveryStatus: 'notified',
            recordedAt: '2026-11-26T01:00:00Z',
          ),
        );
      }
    }
  }
}

class _FakeUser extends Fake implements User {
  @override
  String get id => 'user-health-1';
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
    return FunctionResponse(
      status: 200,
      data: const <String, Object?>{
        'success': true,
        'overall_uptime_pct': 99.5,
        'avg_latency_ms': 145,
        'providers': <Object?>[],
        'endpoints': <Object?>[],
        'logs': <Object?>[],
        'alerts': <Object?>[],
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
  group('SupabaseLlmHealthcheckRepository', () {
    test('parses summary and maps 401 FunctionException cleanly', () async {
      final functions = _FakeFunctionsClient();
      final repo = SupabaseLlmHealthcheckRepository(
        client: _FakeSupabaseClient(functions),
      );
      final summary = await repo.fetchSummary();
      expect(summary.overallUptimePct, 99.5);
      expect(summary.avgLatencyMs, 145);

      functions.throwUnauthorized = true;
      await expectLater(
        repo.fetchSummary(),
        throwsA(isA<LlmHealthAuthException>()),
      );
    });
  });

  group('LlmHealthcheckController', () {
    test('ignores late response after dispose', () async {
      final completer = Completer<LlmHealthDashboardSnapshot>();
      final repo = _InMemoryHealthRepository(pendingFetch: completer);
      final controller = LlmHealthcheckController(repository: repo);

      final future = controller.loadDashboard();
      controller.dispose();
      completer.complete(LlmHealthDashboardSnapshot.empty);
      await future;
      expect(controller.state.isLoading, isTrue);
    });
  });

  group('LlmHealthcheckContainer UI', () {
    testWidgets(
      'registers endpoint, probes latency history, and logs timeout alert',
      (final WidgetTester tester) async {
        final repo = _InMemoryHealthRepository();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LlmHealthcheckContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('llm_health_empty_state')),
          findsOneWidget,
        );

        final providerField = find.byKey(
          const ValueKey<String>('llm_health_provider_field'),
        );
        await tester.ensureVisible(providerField);
        await tester.enterText(providerField, 'NewAI Alpha');

        final urlField = find.byKey(
          const ValueKey<String>('llm_health_url_field'),
        );
        await tester.ensureVisible(urlField);
        await tester.enterText(
          urlField,
          'https://api.newai.example.com/health',
        );

        final saveBtn = find.byKey(
          const ValueKey<String>('llm_health_save_button'),
        );
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('NewAI Alpha [GET]'), findsOneWidget);

        final probeBtn = find.byKey(
          const ValueKey<String>('llm_health_run_probe_button'),
        );
        await tester.ensureVisible(probeBtn);
        await tester.tap(probeBtn);
        await tester.pumpAndSettle();
        expect(find.text('120 ms'), findsWidgets);

        repo.simulateNextDown = true;
        await tester.ensureVisible(probeBtn);
        await tester.tap(probeBtn);
        await tester.pumpAndSettle();

        expect(find.text('50.0%'), findsWidgets);
        expect(find.textContaining('timeout (notified)'), findsOneWidget);
      },
    );

    testWidgets(
      'passes responsive and WCAG accessibility audit in Light and Dark modes',
      (final WidgetTester tester) async {
        final repo = _InMemoryHealthRepository();
        await repo.upsertEndpoint(
          providerName: 'Gemini Health',
          endpointUrl: 'https://generativelanguage.googleapis.com/',
        );
        await repo.runProbe();

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
                theme: ThemeData(brightness: brightness, useMaterial3: true),
                builder: (final context, final child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2.0),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: LlmHealthcheckContainer(repository: repo),
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
      'EnterprisePage exposes LLM healthcheck action cleanly',
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
          find.byKey(const Key('enterprise_llm_healthcheck_action')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
