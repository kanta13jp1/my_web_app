import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/ai_compute_cost_monitor/ai_compute_cost_monitor_container.dart';
import 'package:my_web_app/features/ai_compute_cost_monitor/application/ai_compute_cost_monitor_controller.dart';
import 'package:my_web_app/features/ai_compute_cost_monitor/domain/ai_compute_cost_monitor_models.dart';

class _InMemoryAiComputeCostMonitorRepository
    implements AiComputeCostMonitorRepository {
  _InMemoryAiComputeCostMonitorRepository({
    List<AiComputeTelemetryEntry>? initialEntries,
    AiComputeThresholdSettings? initialSettings,
    this.isAdmin = true,
  })  : _entries = List<AiComputeTelemetryEntry>.from(
          initialEntries ?? <AiComputeTelemetryEntry>[],
        ),
        _settings = initialSettings ?? AiComputeThresholdSettings.defaults();

  final List<AiComputeTelemetryEntry> _entries;
  AiComputeThresholdSettings _settings;
  bool isAdmin;
  bool throwOnLoad = false;
  Completer<AiComputeDashboardSnapshot>? pendingLoad;
  int _nextId = 1;

  @override
  Future<AiComputeDashboardSnapshot> fetchDashboard() async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('compute cost telemetry unavailable');
    }
    return AiComputeDashboardSnapshot(
      entries: List<AiComputeTelemetryEntry>.unmodifiable(_entries),
      thresholdSettings: _settings,
      isAdmin: isAdmin,
    );
  }

  @override
  Future<AiComputeTelemetryEntry> recordTelemetry(
    AiComputeTelemetryEntry draft,
  ) async {
    final created = draft.copyWith(
      id: 'tel-${_nextId++}',
      userId: 'usr-admin-1',
    );
    _entries.insert(0, created);
    return created;
  }

  @override
  Future<AiComputeThresholdSettings> updateThresholds({
    required double dailyThresholdUsd,
    required double monthlyThresholdUsd,
  }) async {
    _settings = AiComputeThresholdSettings(
      dailyThresholdUsd: dailyThresholdUsd,
      monthlyThresholdUsd: monthlyThresholdUsd,
      updatedAt: DateTime.utc(2026, 11, 24, 19, 0),
    );
    return _settings;
  }
}

List<AiComputeTelemetryEntry> _sampleEntries() {
  return <AiComputeTelemetryEntry>[
    AiComputeTelemetryEntry(
      id: 'tel-hub-1',
      userId: 'usr-alpha',
      toolName: 'ai-hub',
      gpuProfile: GpuComputeProfile.l4Inference,
      modelId: 'gemini-2.5-flash',
      inputTokens: 1800,
      outputTokens: 600,
      apiRequestCount: 2,
      latencyMs: 850,
      estimatedComputeCostUsd: 0.002395,
      costThresholdUsd: 50.0,
      thresholdAlertTriggered: false,
      recordedAt: DateTime.utc(2026, 11, 24, 18, 0),
    ),
    AiComputeTelemetryEntry(
      id: 'tel-writer-2',
      userId: 'usr-beta',
      toolName: 'ai-writing-assistant',
      gpuProfile: GpuComputeProfile.a100Cluster,
      modelId: 'claude-sonnet',
      inputTokens: 4000,
      outputTokens: 1500,
      apiRequestCount: 3,
      latencyMs: 2100,
      estimatedComputeCostUsd: 0.016060,
      costThresholdUsd: 50.0,
      thresholdAlertTriggered: false,
      recordedAt: DateTime.utc(2026, 11, 23, 15, 0),
    ),
  ];
}

void main() {
  group(
    'AiComputeCostEstimator & AiComputeCostMonitorController (#2658)',
    () {
      test(
        'estimates compute costs consistently and aggregates daily/monthly/user buckets',
        () async {
          final cpuCost = AiComputeCostEstimator.estimateUsd(
            gpuProfile: GpuComputeProfile.cpuFallback,
            inputTokens: 1000,
            outputTokens: 1000,
            apiRequestCount: 1,
            latencyMs: 1000,
          );
          final h100Cost = AiComputeCostEstimator.estimateUsd(
            gpuProfile: GpuComputeProfile.h100Cluster,
            inputTokens: 1000,
            outputTokens: 1000,
            apiRequestCount: 1,
            latencyMs: 1000,
          );
          expect(h100Cost, greaterThan(cpuCost));

          final repo = _InMemoryAiComputeCostMonitorRepository(
            initialEntries: _sampleEntries(),
            initialSettings: AiComputeThresholdSettings(
              dailyThresholdUsd: 0.001,
              monthlyThresholdUsd: 500.0,
              updatedAt: DateTime.utc(2026, 11, 24, 18, 0),
            ),
            isAdmin: true,
          );
          final controller = AiComputeCostMonitorController(repository: repo);
          await controller.loadDashboard();

          expect(controller.state.totalRequests, 5);
          expect(controller.state.dailyBuckets.length, 2);
          expect(controller.state.monthlyBuckets.length, 1);
          expect(controller.state.userSummaries.length, 2);
          expect(controller.state.isDailyThresholdExceeded, isTrue);
          expect(controller.state.isThresholdAlertActive, isTrue);

          final updated = await controller.updateThresholds(
            dailyThresholdUsd: 25.0,
            monthlyThresholdUsd: 250.0,
          );
          expect(updated, isTrue);
          expect(controller.state.isThresholdAlertActive, isFalse);

          controller.dispose();
        },
      );

      test(
        'gates non-admin threshold updates and clears stale error on actions',
        () async {
          final repo = _InMemoryAiComputeCostMonitorRepository(
            initialEntries: _sampleEntries(),
            isAdmin: false,
          );
          final controller = AiComputeCostMonitorController(repository: repo);
          await controller.loadDashboard();

          final blocked = await controller.updateThresholds(
            dailyThresholdUsd: 10.0,
            monthlyThresholdUsd: 100.0,
          );
          expect(blocked, isFalse);
          expect(controller.state.errorMessage, isNotNull);

          controller.setPeriod(ComputeCostPeriod.monthly);
          expect(controller.state.errorMessage, isNull);
          expect(controller.state.selectedPeriod, ComputeCostPeriod.monthly);

          controller.setProfileFilter(GpuComputeProfile.a100Cluster);
          expect(controller.state.filteredEntries.length, 1);
          expect(controller.state.filteredEntries.first.id, 'tel-writer-2');

          expect(controller.state.modelBreakdowns.length, 2);
          expect(
            controller.state.modelBreakdowns.first.modelId,
            'claude-sonnet',
          );
          expect(controller.state.modelBreakdowns.first.totalTokens, 5500);

          controller.dispose();
        },
      );

      test(
        'halts invocations automatically on abnormal consecutive retry loop (#2694)',
        () async {
          final loopEntries = List<AiComputeTelemetryEntry>.generate(
            5,
            (final int i) => AiComputeTelemetryEntry(
              id: 'loop-$i',
              userId: 'usr-agent',
              toolName: 'ai-hub',
              gpuProfile: GpuComputeProfile.managedApi,
              modelId: 'claude-opus-4-7',
              inputTokens: 25000,
              outputTokens: 5000,
              apiRequestCount: 1,
              latencyMs: 1200,
              estimatedComputeCostUsd: 0.4,
              costThresholdUsd: 50.0,
              thresholdAlertTriggered: false,
              recordedAt: DateTime.utc(2026, 11, 25, 3, 0, i),
            ),
          );
          final repo = _InMemoryAiComputeCostMonitorRepository(
            initialEntries: loopEntries,
            isAdmin: true,
          );
          final controller = AiComputeCostMonitorController(repository: repo);
          await controller.loadDashboard();

          expect(controller.state.loopDetection.autoHalted, isTrue);
          expect(
            controller.state.loopDetection.maxConsecutiveRepeats,
            greaterThanOrEqualTo(5),
          );

          final blocked = await controller.recordInvocation(
            toolName: 'ai-hub',
            gpuProfile: GpuComputeProfile.managedApi,
            modelId: 'claude-opus-4-7',
            inputTokens: 1000,
            outputTokens: 500,
            apiRequestCount: 1,
            latencyMs: 500,
          );
          expect(blocked, isFalse);
          expect(
            controller.state.errorMessage,
            contains('異常ループまたはコスト上限超過を検知したため自動停止しました'),
          );

          controller.dispose();
        },
      );
    },
  );

  group(
    'AiComputeCostMonitorContainer Widget & A11y (#2658)',
    () {
      testWidgets(
        'recovers cleanly from load failure, records telemetry, and gates admin threshold controls',
        (WidgetTester tester) async {
          final repo = _InMemoryAiComputeCostMonitorRepository(
            initialEntries: _sampleEntries(),
            isAdmin: true,
          )..throwOnLoad = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiComputeCostMonitorContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(
              const ValueKey<String>('ai-compute-error-banner'),
            ),
            findsOneWidget,
          );

          repo.throwOnLoad = false;
          final retryBtn = find.byKey(
            const ValueKey<String>('ai-compute-retry-button'),
          );
          await tester.ensureVisible(retryBtn);
          await tester.tap(retryBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(
              const ValueKey<String>('ai-compute-error-banner'),
            ),
            findsNothing,
          );
          expect(
            find.byKey(
              const ValueKey<String>('ai-compute-update-threshold-button'),
            ),
            findsOneWidget,
          );

          final submitBtn = find.byKey(
            const ValueKey<String>('ai-compute-submit-button'),
          );
          await tester.ensureVisible(submitBtn);
          await tester.tap(submitBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(
              const ValueKey<String>('ai-compute-entry-tel-1'),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(
              const ValueKey<String>('ai-compute-model-breakdown-card'),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders abnormal agent loop halt banner when consecutive loop triggered (#2694)',
        (final WidgetTester tester) async {
          final loopEntries = List<AiComputeTelemetryEntry>.generate(
            5,
            (final int i) => AiComputeTelemetryEntry(
              id: 'loop-$i',
              userId: 'usr-agent',
              toolName: 'ai-hub',
              gpuProfile: GpuComputeProfile.managedApi,
              modelId: 'claude-opus-4-7',
              inputTokens: 25000,
              outputTokens: 5000,
              apiRequestCount: 1,
              latencyMs: 1200,
              estimatedComputeCostUsd: 0.4,
              costThresholdUsd: 50.0,
              thresholdAlertTriggered: false,
              recordedAt: DateTime.utc(2026, 11, 25, 3, 0, i),
            ),
          );
          final repo = _InMemoryAiComputeCostMonitorRepository(
            initialEntries: loopEntries,
            isAdmin: true,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiComputeCostMonitorContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(
              const ValueKey<String>('ai-compute-loop-halt-banner'),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(
              const ValueKey<String>('ai-compute-model-breakdown-card'),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'hides admin threshold editor for non-admin callers',
        (WidgetTester tester) async {
          final repo = _InMemoryAiComputeCostMonitorRepository(
            initialEntries: _sampleEntries(),
            isAdmin: false,
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiComputeCostMonitorContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(
              const ValueKey<String>('ai-compute-update-threshold-button'),
            ),
            findsNothing,
          );
          expect(
            find.byKey(
              const ValueKey<String>('ai-compute-threshold-readonly-note'),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'disposes safely while dashboard fetch is pending',
        (WidgetTester tester) async {
          final completer = Completer<AiComputeDashboardSnapshot>();
          final repo = _InMemoryAiComputeCostMonitorRepository()
            ..pendingLoad = completer;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiComputeCostMonitorContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
          );
          completer.complete(
            AiComputeDashboardSnapshot(
              entries: _sampleEntries(),
              thresholdSettings: AiComputeThresholdSettings.defaults(),
              isAdmin: true,
            ),
          );
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
            'meets WCAG/tap-target guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} $brightness 2.0x textScale',
            (WidgetTester tester) async {
              final semanticsHandle = tester.ensureSemantics();
              tester.view.physicalSize = viewport;
              tester.view.devicePixelRatio = 1.0;
              try {
                final repo = _InMemoryAiComputeCostMonitorRepository(
                  initialEntries: _sampleEntries(),
                  isAdmin: true,
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
                              child: AiComputeCostMonitorContainer(
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
