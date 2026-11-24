import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/context_cache_monitor/application/context_cache_monitor_controller.dart';
import 'package:my_web_app/features/context_cache_monitor/context_cache_monitor_container.dart';
import 'package:my_web_app/features/context_cache_monitor/domain/context_cache_monitor_models.dart';

class _FakeContextCacheMonitorRepository
    implements ContextCacheMonitorRepository {
  _FakeContextCacheMonitorRepository({
    List<ContextCacheUsageMetric>? initialMetrics,
  }) : _metrics = List<ContextCacheUsageMetric>.from(
          initialMetrics ?? <ContextCacheUsageMetric>[],
        );

  final List<ContextCacheUsageMetric> _metrics;
  bool throwOnLoad = false;
  Completer<List<ContextCacheUsageMetric>>? pendingLoad;
  int nextId = 1;

  @override
  Future<List<ContextCacheUsageMetric>> fetchUsageMetrics() async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('usage telemetry offline');
    }
    return List<ContextCacheUsageMetric>.unmodifiable(_metrics);
  }

  @override
  Future<ContextCacheUsageMetric> recordUsageMetric(
    ContextCacheUsageMetric draft,
  ) async {
    final created = draft.copyWith(id: 'metric-${nextId++}');
    _metrics.insert(0, created);
    return created;
  }
}

List<ContextCacheUsageMetric> _sampleMetrics() {
  final ts = DateTime.utc(2026, 11, 24, 18, 0);
  return <ContextCacheUsageMetric>[
    ContextCacheEstimator.buildSimulatedMetric(
      workflowKey: 'daily-brief',
      modelId: 'claude-sonnet-4',
      simulateCacheHit: true,
      userId: 'user-alpha',
      now: ts,
    ).copyWith(id: 'seed-1'),
    ContextCacheEstimator.buildSimulatedMetric(
      workflowKey: 'issue-triage',
      modelId: 'gemini-2.5-flash',
      simulateCacheHit: false,
      userId: 'user-beta',
      now: ts.add(const Duration(minutes: 1)),
    ).copyWith(id: 'seed-2'),
  ];
}

void main() {
  group(
    'ContextCacheMonitorController & Estimator (#2656)',
    () {
      test(
        'computes write vs read USD savings, aligns insert payload with SQL guard, filters workflow/user, and guards disposal',
        () async {
          final cold = ContextCacheEstimator.buildSimulatedMetric(
            workflowKey: 'pr-review',
            modelId: 'claude-sonnet-4',
            simulateCacheHit: false,
            userId: 'user-1',
            now: DateTime.utc(2026, 11, 24, 18, 5),
          );
          expect(cold.cacheHit, isFalse);
          expect(cold.netSavingsUsd < 0, isTrue);

          final warm = ContextCacheEstimator.buildSimulatedMetric(
            workflowKey: 'pr-review',
            modelId: 'claude-sonnet-4',
            simulateCacheHit: true,
            userId: 'user-1',
            now: DateTime.utc(2026, 11, 24, 18, 6),
          );
          expect(warm.cacheHit, isTrue);
          expect(warm.netSavingsUsd > 0, isTrue);
          expect(warm.formattedActualUsd, startsWith('USD '));

          final payload = warm.toInsertPayload(userId: 'user-1');
          expect(payload['cache_hit'], isTrue);
          expect(payload['net_savings_usd'], warm.netSavingsUsd);
          expect(payload['savings_ratio'], warm.savingsRatio);

          final repo = _FakeContextCacheMonitorRepository(
            initialMetrics: _sampleMetrics(),
          );
          final controller = ContextCacheMonitorController(repository: repo);
          await controller.loadMetrics();
          expect(controller.state.filteredMetrics.length, 2);
          expect(controller.state.cacheHitCount, 1);

          controller.setWorkflowFilter('daily-brief');
          expect(controller.state.filteredMetrics.length, 1);
          expect(controller.state.filteredMetrics.first.userId, 'user-alpha');

          controller.setWorkflowFilter('');
          controller.setUserFilter('user-beta');
          expect(controller.state.filteredMetrics.length, 1);
          expect(controller.state.filteredMetrics.first.workflowKey,
              'issue-triage');

          controller.dispose();
          expect(controller.isDisposed, isTrue);
          await controller.recordSimulatedRequest(workflowKey: 'after-dispose');
          expect(controller.state.metrics.length, 2);
        },
      );
    },
  );

  group(
    'ContextCacheMonitorContainer Widget & A11y tests (#2656)',
    () {
      testWidgets(
        'visualizes USD savings, filters admin dashboard by workflow/user, and records cache hit',
        (WidgetTester tester) async {
          final repo = _FakeContextCacheMonitorRepository(
            initialMetrics: _sampleMetrics(),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ContextCacheMonitorContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('cache_estimate_disclaimer')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('cache_summary_panel')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('cache_metric_card_seed-1')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('cache_metric_card_seed-2')),
            findsOneWidget,
          );

          final wfBtn = find.byKey(
            const ValueKey<String>('cache_workflow_filter_daily-brief'),
          );
          await tester.ensureVisible(wfBtn);
          await tester.tap(wfBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('cache_metric_card_seed-1')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('cache_metric_card_seed-2')),
            findsNothing,
          );

          final allWfBtn = find.byKey(
            const ValueKey<String>('cache_workflow_filter_all'),
          );
          await tester.ensureVisible(allWfBtn);
          await tester.tap(allWfBtn);
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const ValueKey<String>('cache_workflow_input')),
            'nightly-doc-sync',
          );
          final recordBtn = find.byKey(
            const ValueKey<String>('cache_record_button'),
          );
          await tester.ensureVisible(recordBtn);
          await tester.tap(recordBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('cache_metric_card_metric-1')),
            findsOneWidget,
          );
          expect(find.textContaining('nightly-doc-sync'), findsWidgets);
        },
      );

      testWidgets(
        'displays error banner and recovers cleanly on retry',
        (WidgetTester tester) async {
          final repo = _FakeContextCacheMonitorRepository(
            initialMetrics: _sampleMetrics(),
          )..throwOnLoad = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ContextCacheMonitorContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('cache_error_banner')),
            findsOneWidget,
          );

          repo.throwOnLoad = false;
          final retryBtn = find.byKey(
            const ValueKey<String>('cache_retry_button'),
          );
          await tester.ensureVisible(retryBtn);
          await tester.tap(retryBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('cache_error_banner')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey<String>('cache_metric_card_seed-1')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'disposes cleanly while usage fetch request is pending',
        (WidgetTester tester) async {
          final completer = Completer<List<ContextCacheUsageMetric>>();
          final repo = _FakeContextCacheMonitorRepository()
            ..pendingLoad = completer;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ContextCacheMonitorContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
          );
          completer.complete(_sampleMetrics());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      for (final viewport in const <Size>[Size(360, 800), Size(1280, 800)]) {
        for (final brightness in const <Brightness>[
          Brightness.light,
          Brightness.dark,
        ]) {
          testWidgets(
            'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} $brightness 2.0x textScale',
            (WidgetTester tester) async {
              final semanticsHandle = tester.ensureSemantics();
              tester.view.physicalSize = viewport;
              tester.view.devicePixelRatio = 1.0;
              try {
                final repo = _FakeContextCacheMonitorRepository(
                  initialMetrics: _sampleMetrics(),
                );
                final theme = brightness == Brightness.dark
                    ? ThemeData.dark()
                    : ThemeData.light();
                await tester.pumpWidget(
                  MaterialApp(
                    key: ValueKey<String>(
                      '${viewport.width.toInt()}_${brightness.name}',
                    ),
                    theme: theme,
                    home: Builder(
                      builder: (BuildContext context) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            size: viewport,
                            textScaler: const TextScaler.linear(2.0),
                          ),
                          child: Scaffold(
                            body: SingleChildScrollView(
                              child: ContextCacheMonitorContainer(
                                repository: repo,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
                await tester.pumpAndSettle();

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
                semanticsHandle.dispose();
                tester.view.resetPhysicalSize();
                tester.view.resetDevicePixelRatio();
              }
            },
          );
        }
      }
    },
  );
}
