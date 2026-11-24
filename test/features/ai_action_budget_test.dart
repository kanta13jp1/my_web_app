import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/ai_action_budget/ai_action_budget_container.dart';
import 'package:my_web_app/features/ai_action_budget/application/ai_action_budget_controller.dart';
import 'package:my_web_app/features/ai_action_budget/domain/ai_action_budget_models.dart';

class _FakeAiActionBudgetRepository implements AiActionBudgetRepository {
  _FakeAiActionBudgetRepository({
    AiActionBudgetConfig? initialConfig,
    List<AiActionLedgerEntry>? initialEntries,
    this.callerIsAdmin = true,
  })  : _config = initialConfig ?? _defaultConfig(),
        _entries = List<AiActionLedgerEntry>.from(
          initialEntries ?? <AiActionLedgerEntry>[],
        );

  AiActionBudgetConfig _config;
  final List<AiActionLedgerEntry> _entries;
  final bool callerIsAdmin;
  bool throwOnLoad = false;
  Completer<AiBudgetSnapshot>? pendingLoad;
  int nextId = 1;

  static AiActionBudgetConfig _defaultConfig() {
    final ts = DateTime.utc(2026, 11, 24, 16, 0);
    return AiActionBudgetConfig(
      id: 'cfg-1',
      monthlyUsdCap: 10.0,
      warningThresholdPct: 80.0,
      hardStopPct: 100.0,
      isPaused: false,
      createdAt: ts,
      updatedAt: ts,
    );
  }

  @override
  Future<AiBudgetSnapshot> fetchSnapshot({required String billingMonth}) async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('budget ledger offline');
    }
    return AiBudgetSnapshot(
      config: _config,
      entries: List<AiActionLedgerEntry>.unmodifiable(_entries),
      callerIsAdmin: callerIsAdmin,
    );
  }

  @override
  Future<AiActionBudgetConfig> updateMonthlyCap({
    required double monthlyUsdCap,
  }) async {
    if (_config.isPaused && !callerIsAdmin) {
      throw StateError('Only admins may modify cap while paused');
    }
    _config = _config.copyWith(
      monthlyUsdCap: monthlyUsdCap,
      updatedAt: DateTime.utc(2026, 11, 24, 16, 5),
    );
    return _config;
  }

  @override
  Future<AiActionBudgetConfig> resumePausedBudget() async {
    if (!callerIsAdmin) {
      throw StateError('Only admins may clear auto-pause state');
    }
    _config = _config.copyWith(
      isPaused: false,
      clearPausedAt: true,
      resumedAt: DateTime.utc(2026, 11, 24, 16, 10),
    );
    return _config;
  }

  @override
  Future<AiActionRecordResult> recordActionUsage({
    required AiActionLedgerEntry draft,
  }) async {
    final created = draft.copyWith(id: 'entry-${nextId++}');
    _entries.insert(0, created);
    var totalSpent = 0.0;
    for (final item in _entries) {
      if (item.billingMonth == draft.billingMonth) {
        totalSpent += item.estimatedUsd;
      }
    }
    final pct = _config.monthlyUsdCap > 0
        ? (totalSpent / _config.monthlyUsdCap) * 100.0
        : 100.0;
    if (pct >= _config.hardStopPct) {
      _config = _config.copyWith(
        isPaused: true,
        pausedAt: DateTime.utc(2026, 11, 24, 16, 8),
      );
    }
    return AiActionRecordResult(
      entry: created,
      updatedConfig: _config,
    );
  }
}

List<AiActionLedgerEntry> _sampleEntries({double firstUsd = 8.5}) {
  final ts = DateTime.utc(2026, 11, 24, 15, 0);
  return <AiActionLedgerEntry>[
    AiActionLedgerEntry(
      id: 'seed-1',
      actionName: 'weekly_digest',
      modelId: 'gemini-2.5-pro',
      promptCount: 400000,
      completionCount: 100000,
      estimatedUsd: firstUsd,
      billingMonth: '2026-11',
      createdAt: ts,
    ),
  ];
}

void main() {
  group(
    'AiActionBudgetController & LocalActionCostEstimator (#2609)',
    () {
      test(
        'computes USD cost, enforces 80% warn and 100% auto-pause, and guards disposal',
        () async {
          const int inTok = 1000000;
          const int outTok = 500000;
          final double cost = LocalActionCostEstimator.estimateUsd(
            modelId: 'gemini-2.5-flash',
            promptCount: inTok,
            completionCount: outTok,
          );
          expect(cost, closeTo(0.45, 0.0001));

          final repo = _FakeAiActionBudgetRepository(
            initialEntries: _sampleEntries(firstUsd: 8.5),
          );
          final controller = AiActionBudgetController(repository: repo);
          await controller.loadSnapshot();
          expect(controller.state.tierStatus, BudgetTierStatus.warning80);
          expect(controller.state.isEffectivePaused, isFalse);

          // Adding gemini-2.5-pro (500k in + 200k out = USD 2.625) exceeds USD 10 cap -> pauses!
          await controller.recordUsage(actionName: 'pr_review_step');
          expect(controller.state.isEffectivePaused, isTrue);
          expect(controller.state.tierStatus, BudgetTierStatus.paused100);

          // Further action must be blocked while paused
          final int countBefore = controller.state.entries.length;
          await controller.recordUsage(actionName: 'blocked_followup');
          expect(controller.state.entries.length, countBefore);
          expect(controller.state.errorMessage, isNotNull);

          // Non-admin controller must refuse resumeBudget cleanly before hitting DB
          final nonAdminRepo = _FakeAiActionBudgetRepository(
            callerIsAdmin: false,
            initialEntries: _sampleEntries(firstUsd: 11.0),
          );
          final nonAdminController =
              AiActionBudgetController(repository: nonAdminRepo);
          await nonAdminController.loadSnapshot();
          expect(nonAdminController.state.callerIsAdmin, isFalse);
          await nonAdminController.updateMonthlyCap(rawCapUsd: '5.0');
          expect(
            nonAdminController.state.errorMessage,
            contains('管理者権限'),
          );
          await nonAdminController.resumeBudget();
          expect(
            nonAdminController.state.errorMessage,
            contains('管理者権限'),
          );
          nonAdminController.dispose();

          controller.dispose();
          expect(controller.isDisposed, isTrue);
          await controller.resumeBudget();
          expect(controller.state.isEffectivePaused, isTrue);
        },
      );
    },
  );

  group(
    'AiActionBudgetContainer Widget & A11y tests (#2609)',
    () {
      testWidgets(
        'shows 80% warning, triggers 100% auto-pause on overrun, and updates cap/resumes',
        (WidgetTester tester) async {
          final repo = _FakeAiActionBudgetRepository(
            initialEntries: _sampleEntries(firstUsd: 8.5),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiActionBudgetContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('budget_usage_progress_bar')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey<String>('budget_status_banner')),
              matching: find.textContaining('80% 到達警告'),
            ),
            findsOneWidget,
          );

          await tester.enterText(
            find.byKey(const ValueKey<String>('budget_action_input')),
            'deep_analysis_job',
          );
          final recordBtn = find.byKey(
            const ValueKey<String>('budget_record_action_button'),
          );
          await tester.ensureVisible(recordBtn);
          await tester.tap(recordBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('ledger_entry_entry-1')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey<String>('budget_status_banner')),
              matching: find.textContaining('100% 上限・自動停止中'),
            ),
            findsOneWidget,
          );

          await tester.enterText(
            find.byKey(const ValueKey<String>('budget_cap_input')),
            '30.0',
          );
          final capBtn = find.byKey(
            const ValueKey<String>('budget_update_cap_button'),
          );
          await tester.ensureVisible(capBtn);
          await tester.tap(capBtn);
          await tester.pumpAndSettle();

          final resumeBtn = find.byKey(
            const ValueKey<String>('budget_resume_button'),
          );
          await tester.ensureVisible(resumeBtn);
          await tester.tap(resumeBtn);
          await tester.pumpAndSettle();

          expect(
            find.descendant(
              of: find.byKey(const ValueKey<String>('budget_status_banner')),
              matching: find.textContaining('正常範囲'),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'hides resume button and shows admin-review notice for non-admin paused users',
        (WidgetTester tester) async {
          final ts = DateTime.utc(2026, 11, 24, 16, 0);
          final pausedConfig = AiActionBudgetConfig(
            id: 'cfg-non-admin',
            monthlyUsdCap: 10.0,
            warningThresholdPct: 80.0,
            hardStopPct: 100.0,
            isPaused: true,
            pausedAt: ts,
            createdAt: ts,
            updatedAt: ts,
          );
          final repo = _FakeAiActionBudgetRepository(
            initialConfig: pausedConfig,
            initialEntries: _sampleEntries(firstUsd: 10.5),
            callerIsAdmin: false,
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiActionBudgetContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('budget_resume_button')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey<String>('budget_admin_review_notice')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'displays error banner and recovers on retry',
        (WidgetTester tester) async {
          final repo = _FakeAiActionBudgetRepository(
            initialEntries: _sampleEntries(),
          )..throwOnLoad = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiActionBudgetContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('budget_error_banner')),
            findsOneWidget,
          );

          repo.throwOnLoad = false;
          final retryBtn = find.byKey(
            const ValueKey<String>('budget_retry_button'),
          );
          await tester.ensureVisible(retryBtn);
          await tester.tap(retryBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('budget_error_banner')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey<String>('ledger_entry_seed-1')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'disposes cleanly while snapshot load is pending',
        (WidgetTester tester) async {
          final completer = Completer<AiBudgetSnapshot>();
          final repo = _FakeAiActionBudgetRepository()..pendingLoad = completer;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiActionBudgetContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
          );
          completer.complete(
            AiBudgetSnapshot(
              config: _FakeAiActionBudgetRepository._defaultConfig(),
              entries: _sampleEntries(),
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
            'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} $brightness 2.0x textScale',
            (WidgetTester tester) async {
              final semanticsHandle = tester.ensureSemantics();
              tester.view.physicalSize = viewport;
              tester.view.devicePixelRatio = 1.0;
              try {
                final repo = _FakeAiActionBudgetRepository(
                  initialEntries: _sampleEntries(),
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
                              child: AiActionBudgetContainer(repository: repo),
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
