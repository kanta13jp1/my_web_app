import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/multi_agent_analysis/application/multi_agent_analysis_controller.dart';
import 'package:my_web_app/features/multi_agent_analysis/domain/multi_agent_analysis_models.dart';
import 'package:my_web_app/features/multi_agent_analysis/multi_agent_analysis_container.dart';

class _FakeMultiAgentAnalysisRepository
    implements MultiAgentAnalysisRepository {
  _FakeMultiAgentAnalysisRepository({List<MultiAgentAnalysisRun>? initialRuns})
      : _runs = List<MultiAgentAnalysisRun>.from(
          initialRuns ?? <MultiAgentAnalysisRun>[],
        );

  final List<MultiAgentAnalysisRun> _runs;
  bool throwOnLoad = false;
  Completer<List<MultiAgentAnalysisRun>>? pendingLoad;
  int nextId = 1;

  @override
  Future<List<MultiAgentAnalysisRun>> fetchRuns() async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('network unavailable');
    }
    return List<MultiAgentAnalysisRun>.unmodifiable(_runs);
  }

  @override
  Future<MultiAgentAnalysisRun> createRun(MultiAgentAnalysisRun draft) async {
    final created = draft.copyWith(id: 'run-${nextId++}');
    _runs.insert(0, created);
    return created;
  }

  @override
  Future<MultiAgentAnalysisRun> submitHumanReview({
    required String runId,
    required HumanReviewStatus status,
    required String note,
  }) async {
    final cleanedNote = LocalSequentialAnalysisRunner.scrubSensitiveText(note);
    final idx = _runs.indexWhere((item) => item.id == runId);
    if (idx < 0) {
      throw StateError('run not found');
    }
    final updated = _runs[idx].copyWith(
      reviewStatus: status,
      reviewNote: cleanedNote,
      reviewedAt: DateTime.utc(2026, 11, 24, 15, 0),
    );
    _runs[idx] = updated;
    return updated;
  }
}

MultiAgentAnalysisRun _sampleRun({
  String id = 'run-sample-1',
  String topic = '積立配分とリスク管理分析',
}) {
  return LocalSequentialAnalysisRunner.execute(
    topic: topic,
    now: DateTime.utc(2026, 11, 24, 14, 0),
  ).copyWith(id: id);
}

void main() {
  group(
    'MultiAgentAnalysisController & LocalSequentialAnalysisRunner (#2641)',
    () {
      test(
        'executes 3-stage pipeline, scrubs PII, and guards disposed controller',
        () async {
          final fakeEmail = const <String>['user', 'example.org'].join('@');
          final run = LocalSequentialAnalysisRunner.execute(
            topic: '家計レビュー $fakeEmail',
          );
          expect(run.reasoningTrace.length, 3);
          expect(
            run.reasoningTrace.map((s) => s.agentName).toList(),
            <String>[
              'DataCollectorAgent',
              'MetricCalculatorAgent',
              'SynthesisAdvisorAgent',
            ],
          );
          expect(run.topic.contains(fakeEmail), isFalse);
          expect(run.reviewStatus, HumanReviewStatus.pendingHumanReview);
          expect(run.requiresHumanConfirmation, isTrue);

          final repo = _FakeMultiAgentAnalysisRepository(
            initialRuns: <MultiAgentAnalysisRun>[_sampleRun()],
          );
          final controller = MultiAgentAnalysisController(repository: repo);
          await controller.loadRuns();
          expect(controller.state.runs.length, 1);

          controller.selectStageFilter(AgentStageFilter.calculator);
          expect(controller.state.visibleTraceSteps.length, 1);
          expect(
            controller.state.visibleTraceSteps.first.agentName,
            'MetricCalculatorAgent',
          );

          controller.dispose();
          expect(controller.isDisposed, isTrue);
          // Must remain no-op after disposal.
          await controller.runNewAnalysis(topic: 'after dispose');
          expect(controller.state.runs.length, 1);
        },
      );
    },
  );

  group(
    'MultiAgentAnalysisContainer Widget & A11y tests (#2641)',
    () {
      testWidgets(
        'displays 3-agent trace, executes new run, and submits Human-in-the-Loop approval',
        (WidgetTester tester) async {
          final repo = _FakeMultiAgentAnalysisRepository(
            initialRuns: <MultiAgentAnalysisRun>[_sampleRun()],
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MultiAgentAnalysisContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('stage_collector_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('stage_calculator_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('stage_synthesizer_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('multi_agent_hitl_banner')),
            findsOneWidget,
          );
          expect(find.textContaining('人間確認待ち'), findsOneWidget);

          await tester.enterText(
            find.byKey(const ValueKey<String>('multi_agent_topic_input')),
            '四半期キャッシュフロー検証',
          );
          final runBtn = find.byKey(
            const ValueKey<String>('multi_agent_run_button'),
          );
          await tester.ensureVisible(runBtn);
          await tester.tap(runBtn);
          await tester.pumpAndSettle();

          expect(find.textContaining('四半期キャッシュフロー検証'), findsWidgets);

          await tester.enterText(
            find.byKey(const ValueKey<String>('multi_agent_review_note_input')),
            '計算根拠と閾値を確認し承認',
          );
          final approveBtn = find.byKey(
            const ValueKey<String>('review_approve_button'),
          );
          await tester.ensureVisible(approveBtn);
          await tester.tap(approveBtn);
          await tester.pumpAndSettle();

          expect(find.textContaining('承認済み'), findsOneWidget);
          expect(
              find.textContaining('記録済みコメント: 計算根拠と閾値を確認し承認'), findsOneWidget);
        },
      );

      testWidgets(
        'displays error banner and recovers on retry',
        (WidgetTester tester) async {
          final repo = _FakeMultiAgentAnalysisRepository(
            initialRuns: <MultiAgentAnalysisRun>[_sampleRun()],
          )..throwOnLoad = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MultiAgentAnalysisContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('multi_agent_error_banner')),
            findsOneWidget,
          );

          repo.throwOnLoad = false;
          final retryBtn = find.byKey(
            const ValueKey<String>('multi_agent_retry_button'),
          );
          await tester.ensureVisible(retryBtn);
          await tester.tap(retryBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('multi_agent_error_banner')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey<String>('stage_collector_card')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'disposes cleanly while loadRuns request is pending',
        (WidgetTester tester) async {
          final completer = Completer<List<MultiAgentAnalysisRun>>();
          final repo = _FakeMultiAgentAnalysisRepository()
            ..pendingLoad = completer;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MultiAgentAnalysisContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pump();

          // Unmount before async completion.
          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
          );
          completer.complete(<MultiAgentAnalysisRun>[_sampleRun()]);
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
                final repo = _FakeMultiAgentAnalysisRepository(
                  initialRuns: <MultiAgentAnalysisRun>[_sampleRun()],
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
                              child:
                                  MultiAgentAnalysisContainer(repository: repo),
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
