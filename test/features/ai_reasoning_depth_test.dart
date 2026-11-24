import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/ai_reasoning_depth/ai_reasoning_depth_container.dart';
import 'package:my_web_app/features/ai_reasoning_depth/application/ai_reasoning_depth_controller.dart';
import 'package:my_web_app/features/ai_reasoning_depth/domain/ai_reasoning_depth_models.dart';

class _FakeAiReasoningDepthRepository implements AiReasoningDepthRepository {
  _FakeAiReasoningDepthRepository({List<ReasoningDepthJob>? initialJobs})
      : _jobs = List<ReasoningDepthJob>.from(
          initialJobs ?? <ReasoningDepthJob>[],
        );

  final List<ReasoningDepthJob> _jobs;
  bool throwOnLoad = false;
  Completer<List<ReasoningDepthJob>>? pendingLoad;
  int nextId = 1;

  @override
  Future<List<ReasoningDepthJob>> fetchJobs() async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('network unavailable');
    }
    return List<ReasoningDepthJob>.unmodifiable(_jobs);
  }

  @override
  Future<ReasoningDepthJob> createJob(ReasoningDepthJob draft) async {
    final created = draft.copyWith(id: 'job-${nextId++}');
    _jobs.insert(0, created);
    return created;
  }

  @override
  Future<ReasoningDepthJob> updateJobProgress({
    required String jobId,
    required ReasoningJobStatus jobStatus,
    required int toolCallsCompleted,
    required String progressNote,
    required String resultSummary,
  }) async {
    final idx = _jobs.indexWhere((item) => item.id == jobId);
    if (idx < 0) {
      throw StateError('job not found');
    }
    final updated = _jobs[idx].copyWith(
      jobStatus: jobStatus,
      toolCallsCompleted: toolCallsCompleted,
      progressNote: progressNote,
      resultSummary: resultSummary,
      updatedAt: DateTime.utc(2026, 11, 24, 18, 0),
    );
    _jobs[idx] = updated;
    return updated;
  }
}

ReasoningDepthJob _sampleDeepResearchJob({
  String id = 'job-sample-1',
  String prompt = '複数WBS間の依存リスク分析',
}) {
  return ReasoningDepthPlanner.buildInitialJob(
    mode: ReasoningDepthMode.deepResearch,
    promptSummary: prompt,
    now: DateTime.utc(2026, 11, 24, 17, 30),
  ).copyWith(id: id);
}

void main() {
  group(
    'AiReasoningDepthController & Planner (#2654)',
    () {
      test(
        'compares Standard/Deep Research/Background, scrubs PII, advances async queue, and guards disposal',
        () async {
          final comparisons = ReasoningDepthPlanner.compareAllModes();
          expect(comparisons.length, 3);
          expect(
            comparisons[0].estimatedCostUsd < comparisons[1].estimatedCostUsd,
            isTrue,
          );
          expect(
            comparisons[1].estimatedCostUsd < comparisons[2].estimatedCostUsd,
            isTrue,
          );
          expect(comparisons[1].formattedCost, startsWith('USD '));

          final fakeEmail = const <String>['analyst', 'example.org'].join('@');
          final draft = ReasoningDepthPlanner.buildInitialJob(
            mode: ReasoningDepthMode.deepResearch,
            promptSummary: '監査依頼 $fakeEmail',
            now: DateTime.utc(2026, 11, 24, 17, 35),
          );
          expect(draft.promptSummary.contains(fakeEmail), isFalse);
          expect(draft.jobStatus, ReasoningJobStatus.queued);
          expect(draft.maxToolCalls, 25);
          expect(draft.timeoutSeconds, 300);

          final repo = _FakeAiReasoningDepthRepository(
            initialJobs: <ReasoningDepthJob>[_sampleDeepResearchJob()],
          );
          final controller = AiReasoningDepthController(repository: repo);
          await controller.loadJobs();
          expect(controller.state.jobs.length, 1);

          await controller.pollSelectedJob();
          expect(
            controller.state.selectedJob?.jobStatus,
            ReasoningJobStatus.running,
          );
          expect(
            (controller.state.selectedJob?.toolCallsCompleted ?? 0) > 0,
            isTrue,
          );

          await controller.cancelSelectedJob();
          expect(
            controller.state.selectedJob?.jobStatus,
            ReasoningJobStatus.cancelled,
          );

          controller.dispose();
          expect(controller.isDisposed, isTrue);
          await controller.submitJob(promptSummary: 'after dispose');
          expect(controller.state.jobs.length, 1);
        },
      );
    },
  );

  group(
    'AiReasoningDepthContainer Widget & A11y tests (#2654)',
    () {
      testWidgets(
        'switches mode to Deep Research, updates cost diff, submits async job, and polls to completion',
        (WidgetTester tester) async {
          final repo = _FakeAiReasoningDepthRepository(
            initialJobs: <ReasoningDepthJob>[_sampleDeepResearchJob()],
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiReasoningDepthContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('depth_mode_standard')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('depth_mode_deep_research')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('depth_mode_background')),
            findsOneWidget,
          );
          expect(
            find.byKey(
              const ValueKey<String>('depth_cost_latency_comparison'),
            ),
            findsOneWidget,
          );

          final deepTile = find.byKey(
            const ValueKey<String>('depth_mode_deep_research'),
          );
          await tester.ensureVisible(deepTile);
          await tester.tap(deepTile);
          await tester.pumpAndSettle();

          expect(
            find.descendant(
              of: find.byKey(
                const ValueKey<String>('depth_selected_comparison_summary'),
              ),
              matching: find.textContaining('USD 0.0320'),
            ),
            findsOneWidget,
          );

          await tester.enterText(
            find.byKey(const ValueKey<String>('depth_prompt_input')),
            '四半期データ整合性と権限監査の深掘り',
          );
          final runBtn = find.byKey(const ValueKey<String>('depth_run_button'));
          await tester.ensureVisible(runBtn);
          await tester.tap(runBtn);
          await tester.pumpAndSettle();

          expect(find.textContaining('四半期データ整合性と権限監査の深掘り'), findsWidgets);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey<String>('depth_job_status_badge')),
              matching: find.textContaining('待機中'),
            ),
            findsOneWidget,
          );

          final pollBtn = find.byKey(
            const ValueKey<String>('depth_poll_button'),
          );
          await tester.ensureVisible(pollBtn);
          await tester.tap(pollBtn);
          await tester.pumpAndSettle();

          expect(
            find.descendant(
              of: find.byKey(const ValueKey<String>('depth_job_status_badge')),
              matching: find.textContaining('実行中'),
            ),
            findsOneWidget,
          );

          await tester.ensureVisible(pollBtn);
          await tester.tap(pollBtn);
          await tester.pumpAndSettle();

          expect(
            find.descendant(
              of: find.byKey(const ValueKey<String>('depth_job_status_badge')),
              matching: find.textContaining('完了'),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'displays error banner and recovers cleanly on retry',
        (WidgetTester tester) async {
          final repo = _FakeAiReasoningDepthRepository(
            initialJobs: <ReasoningDepthJob>[_sampleDeepResearchJob()],
          )..throwOnLoad = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiReasoningDepthContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('depth_error_banner')),
            findsOneWidget,
          );

          repo.throwOnLoad = false;
          final retryBtn = find.byKey(
            const ValueKey<String>('depth_retry_button'),
          );
          await tester.ensureVisible(retryBtn);
          await tester.tap(retryBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('depth_error_banner')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey<String>('depth_selected_job_card')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'disposes cleanly while loadJobs request is pending',
        (WidgetTester tester) async {
          final completer = Completer<List<ReasoningDepthJob>>();
          final repo = _FakeAiReasoningDepthRepository()
            ..pendingLoad = completer;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiReasoningDepthContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
          );
          completer.complete(<ReasoningDepthJob>[_sampleDeepResearchJob()]);
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
                final repo = _FakeAiReasoningDepthRepository(
                  initialJobs: <ReasoningDepthJob>[_sampleDeepResearchJob()],
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
                                  AiReasoningDepthContainer(repository: repo),
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
