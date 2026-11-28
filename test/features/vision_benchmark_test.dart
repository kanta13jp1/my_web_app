import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/vision_benchmark/application/vision_benchmark_controller.dart';
import 'package:my_web_app/features/vision_benchmark/data/supabase_vision_benchmark_repository.dart';
import 'package:my_web_app/features/vision_benchmark/domain/vision_benchmark_models.dart';
import 'package:my_web_app/features/vision_benchmark/vision_benchmark_container.dart';
import 'package:my_web_app/pages/enterprise_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeVisionBenchmarkRepository implements VisionBenchmarkRepository {
  _FakeVisionBenchmarkRepository({
    final List<VisionBenchmarkRun>? initialRuns,
  }) : runs = List<VisionBenchmarkRun>.from(
          initialRuns ?? const <VisionBenchmarkRun>[],
        );

  final List<VisionBenchmarkRun> runs;
  bool throwOnFetch = false;
  Completer<List<VisionBenchmarkRun>>? pendingFetch;

  @override
  Future<VisionBenchmarkSnapshot> fetchDashboard({
    required final int threshold,
    final String? modelFilter,
    final int limit = 40,
  }) async {
    if (pendingFetch != null) {
      final resolved = await pendingFetch!.future;
      return VisionBenchmarkSnapshot.build(
        runs: resolved,
        threshold: threshold,
      );
    }
    if (throwOnFetch) {
      throw StateError('Vision backend unavailable');
    }
    final filtered = modelFilter == null || modelFilter.trim().isEmpty
        ? runs
        : runs
            .where((final VisionBenchmarkRun r) => r.model == modelFilter)
            .toList(growable: false);
    return VisionBenchmarkSnapshot.build(
      runs: filtered.take(limit).toList(growable: false),
      threshold: threshold,
    );
  }

  @override
  Future<VisionBenchmarkRun> recordRun({
    required final String model,
    required final String provider,
    required final int score,
    required final int latencyMs,
    required final int threshold,
    required final bool passed,
    required final String detail,
    final List<VisionBenchmarkLevel> levels = const <VisionBenchmarkLevel>[],
  }) async {
    final created = VisionBenchmarkRun(
      id: 'run-${runs.length + 1}',
      model: model,
      provider: provider,
      score: score,
      latencyMs: latencyMs,
      threshold: threshold,
      passed: passed,
      detail: detail,
      levels: levels,
      recordedAt: DateTime.utc(2026, 11, 25, 12, runs.length),
    );
    runs.insert(0, created);
    return created;
  }
}

class _FakeUser extends Fake implements User {
  @override
  String get id => 'user-vision-1';
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => _FakeUser();
}

class _FakeFunctionsClient extends Fake implements FunctionsClient {
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];
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
    calls.add(<String, Object?>{
      'function': functionName,
      'body': body,
    });
    if (throwUnauthorized) {
      throw const FunctionException(
        status: 401,
        details: <String, Object?>{'error': 'Unauthorized'},
        reasonPhrase: 'Unauthorized',
      );
    }
    final req = body as Map<String, Object?>? ?? const <String, Object?>{};
    final action = req['action']?.toString() ?? '';
    if (action == 'vision_benchmark.record') {
      return FunctionResponse(
        status: 200,
        data: <String, Object?>{
          'success': true,
          'run': <String, Object?>{
            'id': 'edge-run-1',
            'model': req['model'],
            'provider': req['provider'],
            'score': req['score'],
            'latency_ms': req['latency_ms'],
            'threshold': req['threshold'],
            'passed': req['passed'],
            'detail': req['detail'],
            'levels': req['levels'] ?? const <Object?>[],
            'recorded_at': '2026-11-25T12:00:00Z',
          },
        },
      );
    }
    return FunctionResponse(
      status: 200,
      data: <String, Object?>{
        'success': true,
        'runs': <Object?>[
          <String, Object?>{
            'id': 'edge-run-0',
            'model': 'gemini-2.5-flash',
            'provider': 'gemini',
            'score': 94,
            'latency_ms': 310,
            'threshold': req['threshold'] ?? 70,
            'passed': true,
            'detail': '6-stage passed',
            'levels': <Object?>[],
            'recorded_at': '2026-11-25T11:30:00Z',
          },
        ],
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

List<VisionBenchmarkRun> _sampleRuns() {
  return <VisionBenchmarkRun>[
    VisionBenchmarkRun(
      id: 'r-1',
      model: 'gemini-2.5-flash',
      provider: 'gemini',
      score: 91,
      latencyMs: 320,
      threshold: 70,
      passed: true,
      detail: '6段階 Vision テスト合格',
      levels: const <VisionBenchmarkLevel>[
        VisionBenchmarkLevel(
          level: 'level1',
          description: '疎通確認',
          passed: true,
          score: 91,
          maxPoints: 100,
          latencyMs: 320,
          response: 'ping-ok',
        ),
        VisionBenchmarkLevel(
          level: 'level6',
          description: '専門領域対応',
          passed: true,
          score: 90,
          maxPoints: 100,
          latencyMs: 410,
          response: 'ok',
        ),
      ],
      recordedAt: DateTime.utc(2026, 11, 25, 10, 0),
    ),
    VisionBenchmarkRun(
      id: 'r-2',
      model: 'claude-sonnet-4-6',
      provider: 'claude',
      score: 78,
      latencyMs: 650,
      threshold: 70,
      passed: true,
      detail: '一部遅延あり',
      levels: const <VisionBenchmarkLevel>[],
      recordedAt: DateTime.utc(2026, 11, 25, 9, 0),
    ),
    VisionBenchmarkRun(
      id: 'r-3',
      model: 'gpt-4o-mini',
      provider: 'gpt',
      score: 54,
      latencyMs: 980,
      threshold: 70,
      passed: false,
      detail: 'L5 推論精度低下',
      levels: const <VisionBenchmarkLevel>[],
      recordedAt: DateTime.utc(2026, 11, 25, 8, 0),
    ),
  ];
}

void main() {
  group('SupabaseVisionBenchmarkRepository', () {
    test('fetches, records, and maps FunctionException 401 cleanly', () async {
      final functions = _FakeFunctionsClient();
      final repo = SupabaseVisionBenchmarkRepository(
        client: _FakeSupabaseClient(functions),
      );

      final snapshot = await repo.fetchDashboard(threshold: 70);
      expect(snapshot.runs, hasLength(1));
      expect(snapshot.runs.first.model, 'gemini-2.5-flash');
      expect(snapshot.runs.first.score, 94);

      final recorded = await repo.recordRun(
        model: 'claude-sonnet-4-6',
        provider: 'claude',
        score: 82,
        latencyMs: 400,
        threshold: 70,
        passed: true,
        detail: 'ok',
      );
      expect(recorded.id, 'edge-run-1');
      expect(recorded.score, 82);

      functions.throwUnauthorized = true;
      await expectLater(
        repo.fetchDashboard(threshold: 70),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('VisionBenchmarkController', () {
    test('safely ignores late fetch completion after dispose', () async {
      final repo = _FakeVisionBenchmarkRepository();
      final pending = Completer<List<VisionBenchmarkRun>>();
      repo.pendingFetch = pending;

      final controller = VisionBenchmarkController(repository: repo);
      final future = controller.loadDashboard();
      controller.dispose();

      pending.complete(_sampleRuns());
      await future;

      expect(controller.state.isLoading, isTrue);
    });
  });

  group('VisionBenchmarkDashboardPage UI', () {
    testWidgets(
      'displays trend chart, history table, threshold alerts, and filtering',
      (final WidgetTester tester) async {
        final repo = _FakeVisionBenchmarkRepository(initialRuns: _sampleRuns());

        await tester.pumpWidget(
          MaterialApp(
            home: VisionBenchmarkDashboardPage(
              repository: repo,
              onRunLiveTest: (final String model, final int threshold) async {
                return repo.recordRun(
                  model: model,
                  provider: 'claude',
                  score: 88,
                  latencyMs: 390,
                  threshold: threshold,
                  passed: 88 >= threshold,
                  detail: 'Live test recorded',
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('vision_benchmark_trend_chart')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('vision_benchmark_history_table')),
          findsOneWidget,
        );
        // Initial threshold 70 flags gpt-4o-mini (54).
        expect(
          find.byKey(const ValueKey<String>('vision_benchmark_alert_banner')),
          findsOneWidget,
        );
        expect(find.textContaining('gpt-4o-mini: 54点'), findsOneWidget);
        expect(find.textContaining('1モデルが基準値 (70点) 未満'), findsOneWidget);

        // Raising threshold to 85 flags claude-sonnet-4-6 (78) as well.
        final chip85 = find.byKey(
          const ValueKey<String>('vision_threshold_chip_85'),
        );
        await tester.ensureVisible(chip85);
        await tester.tap(chip85);
        await tester.pumpAndSettle();

        expect(find.textContaining('2モデルが基準値 (85点) 未満'), findsOneWidget);
        expect(find.textContaining('claude-sonnet-4-6: 78点'), findsOneWidget);

        // Filter to gemini-2.5-flash (91 >= 85) -> alert banner disappears.
        final geminiFilter = find.byKey(
          const ValueKey<String>('vision_model_filter_gemini-2.5-flash'),
        );
        await tester.ensureVisible(geminiFilter);
        await tester.tap(geminiFilter);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('vision_benchmark_alert_banner')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('vision_benchmark_healthy_banner')),
          findsOneWidget,
        );

        // Live benchmark execution records a new run.
        final runButton = find.byKey(
          const ValueKey<String>('vision_benchmark_run_test_button'),
        );
        await tester.ensureVisible(runButton);
        await tester.tap(runButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('vision_benchmark_status_notice')),
          findsOneWidget,
        );
        expect(repo.runs, hasLength(4));
      },
    );

    testWidgets(
      'handles empty and error states without throwing',
      (final WidgetTester tester) async {
        final repo = _FakeVisionBenchmarkRepository();
        repo.throwOnFetch = true;

        await tester.pumpWidget(
          MaterialApp(
            home: VisionBenchmarkDashboardPage(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('vision_benchmark_error_banner')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('vision_benchmark_empty_state')),
          findsOneWidget,
        );

        repo.throwOnFetch = false;
        final refreshButton = find.byKey(
          const ValueKey<String>('vision_benchmark_refresh_button'),
        );
        await tester.ensureVisible(refreshButton);
        await tester.tap(refreshButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('vision_benchmark_error_banner')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('vision_benchmark_empty_state')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders cleanly at 360x800 mobile and 1280x800 desktop viewports',
      (final WidgetTester tester) async {
        final repo = _FakeVisionBenchmarkRepository(initialRuns: _sampleRuns());

        for (final size in const <Size>[Size(360, 800), Size(1280, 800)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            MaterialApp(
              home: VisionBenchmarkDashboardPage(repository: repo),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey<String>('vision_benchmark_alert_banner')),
            findsOneWidget,
          );
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
          const Key('enterprise_vision_benchmark_action'),
        );
        expect(action, findsOneWidget);

        await tester.tap(action);
        await tester.pumpAndSettle();

        expect(find.byType(VisionBenchmarkContainer), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
