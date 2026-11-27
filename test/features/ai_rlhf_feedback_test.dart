import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/ai_rlhf_feedback/ai_rlhf_feedback_container.dart';
import 'package:my_web_app/features/ai_rlhf_feedback/domain/ai_rlhf_feedback_models.dart';

class _FakeAiRlhfFeedbackRepository implements AiRlhfFeedbackRepository {
  _FakeAiRlhfFeedbackRepository({List<AiRlhfFeedbackEntry>? initialEntries})
      : _entries = List<AiRlhfFeedbackEntry>.from(
          initialEntries ?? const <AiRlhfFeedbackEntry>[],
        );

  final List<AiRlhfFeedbackEntry> _entries;
  final List<String> webhookTriggeredIds = <String>[];
  bool throwOnLoad = false;
  Completer<List<AiRlhfFeedbackEntry>>? pendingLoad;
  int nextId = 1;
  int nextIssueNumber = 801;

  @override
  Future<List<AiRlhfFeedbackEntry>> fetchRecentFeedback() async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('rlhf store offline');
    }
    return List<AiRlhfFeedbackEntry>.unmodifiable(_entries);
  }

  @override
  Future<AiRlhfFeedbackEntry> submitFeedback(AiRlhfFeedbackDraft draft) async {
    final now = DateTime.utc(2026, 11, 24, 16, 35);
    final entry = AiRlhfFeedbackEntry(
      id: 'fb-${nextId++}',
      actionName: draft.actionName,
      modelId: draft.modelId,
      promptText: draft.promptText,
      aiOutput: draft.aiOutput,
      ratingStatus: draft.ratingStatus,
      userComment: draft.userComment,
      dispatchStatus: draft.ratingStatus.triggersGitHubIssue
          ? RlhfDispatchStatus.pending
          : RlhfDispatchStatus.notNeeded,
      createdAt: now,
      updatedAt: now,
    );
    _entries.insert(0, entry);
    return entry;
  }

  @override
  Future<RlhfWebhookDispatchResult> triggerWebhookDispatch({
    required String feedbackId,
    bool dryRun = false,
  }) async {
    webhookTriggeredIds.add(feedbackId);
    final index = _entries.indexWhere((item) => item.id == feedbackId);
    if (index < 0) {
      return RlhfWebhookDispatchResult(
        feedbackId: feedbackId,
        dispatched: false,
        skipped: true,
      );
    }
    final target = _entries[index];
    if (!target.ratingStatus.triggersGitHubIssue) {
      return RlhfWebhookDispatchResult(
        feedbackId: feedbackId,
        dispatched: false,
        skipped: true,
        message: 'rating_not_bad',
      );
    }
    final issueNo = nextIssueNumber++;
    final issueUrl = 'https://github.com/kanta13jp1/my_web_app/issues/$issueNo';
    if (!dryRun) {
      _entries[index] = target.copyWith(
        dispatchStatus: RlhfDispatchStatus.dispatched,
        githubIssueNumber: issueNo,
        githubIssueUrl: issueUrl,
        webhookDispatchedAt: DateTime.utc(2026, 11, 24, 16, 36),
      );
    }
    return RlhfWebhookDispatchResult(
      feedbackId: feedbackId,
      dispatched: !dryRun,
      dryRun: dryRun,
      issueNumber: dryRun ? null : issueNo,
      issueUrl: dryRun ? null : issueUrl,
      labels: const <String>['AI-Feedback', 'rlhf', 'automation'],
    );
  }
}

List<AiRlhfFeedbackEntry> _seedEntries() {
  final ts = DateTime.utc(2026, 11, 24, 16, 0);
  return <AiRlhfFeedbackEntry>[
    AiRlhfFeedbackEntry(
      id: 'seed-1',
      actionName: 'asset_advisor',
      modelId: 'gemini-2.5-pro',
      promptText: 'Summarize budget',
      aiOutput: 'Total was stale',
      ratingStatus: RlhfRatingStatus.bad,
      userComment: 'Outdated calculation',
      dispatchStatus: RlhfDispatchStatus.pending,
      createdAt: ts,
      updatedAt: ts,
    ),
  ];
}

void main() {
  group(
    'AiRlhfFeedbackContainer',
    () {
      testWidgets(
        'bad rating dispatches AI-Feedback GitHub Issue while good rating does not',
        (WidgetTester tester) async {
          final repo = _FakeAiRlhfFeedbackRepository(
            initialEntries: _seedEntries(),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiRlhfFeedbackContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const ValueKey<String>('rlhf_prompt_input')),
            'Calculate total fixed expenses',
          );
          await tester.enterText(
            find.byKey(const ValueKey<String>('rlhf_output_input')),
            'Incorrect sum shown',
          );
          await tester.enterText(
            find.byKey(const ValueKey<String>('rlhf_comment_input')),
            'Expected sum is 12000',
          );

          final submitBtn = find.byKey(
            const ValueKey<String>('rlhf_submit_button'),
          );
          await tester.ensureVisible(submitBtn);
          await tester.tap(submitBtn);
          await tester.pumpAndSettle();

          expect(repo.webhookTriggeredIds, equals(<String>['fb-1']));
          expect(
            find.descendant(
              of: find.byKey(const ValueKey<String>('rlhf_status_notice')),
              matching: find.textContaining('Issue #801 (AI-Feedback)'),
              matchRoot: true,
            ),
            findsOneWidget,
          );

          final goodButton = find.byKey(
            const ValueKey<String>('rlhf_rating_good'),
          );
          await tester.ensureVisible(goodButton);
          await tester.tap(goodButton);
          await tester.pumpAndSettle();

          await tester.ensureVisible(submitBtn);
          await tester.tap(submitBtn);
          await tester.pumpAndSettle();

          expect(repo.webhookTriggeredIds, equals(<String>['fb-1']));
          expect(
            find.byKey(const ValueKey<String>('rlhf_entry_fb-2')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'displays error banner and recovers on retry',
        (WidgetTester tester) async {
          final repo = _FakeAiRlhfFeedbackRepository(
            initialEntries: _seedEntries(),
          )..throwOnLoad = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiRlhfFeedbackContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('rlhf_error_banner')),
            findsOneWidget,
          );

          repo.throwOnLoad = false;
          final retryBtn = find.byKey(
            const ValueKey<String>('rlhf_retry_button'),
          );
          await tester.ensureVisible(retryBtn);
          await tester.tap(retryBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('rlhf_error_banner')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey<String>('rlhf_entry_seed-1')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'disposes cleanly while feedback load is pending',
        (WidgetTester tester) async {
          final completer = Completer<List<AiRlhfFeedbackEntry>>();
          final repo = _FakeAiRlhfFeedbackRepository()..pendingLoad = completer;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiRlhfFeedbackContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
          );
          completer.complete(_seedEntries());
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
                final repo = _FakeAiRlhfFeedbackRepository(
                  initialEntries: _seedEntries(),
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
                            textScaler: const TextScaler.linear(2.0),
                          ),
                          child: Scaffold(
                            body: SingleChildScrollView(
                              child: AiRlhfFeedbackContainer(repository: repo),
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
