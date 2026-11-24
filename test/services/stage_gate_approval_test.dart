import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/stage_gate_review_service.dart';
import 'package:my_web_app/widgets/stage_gate_approval_panel.dart';

class _FakeStageGateRepository implements StageGateReviewRepository {
  _FakeStageGateRepository(
    this.reviews,
    this.history, {
    this.isAdmin = true,
  });

  final List<StageGateReview> reviews;
  final List<StageGateHistoryEntry> history;
  final bool isAdmin;
  int decideCalls = 0;

  @override
  Future<StageGateOverview> listReviews({
    StageGateDecision? statusFilter,
    int limit = 30,
  }) async {
    final filtered = statusFilter == null
        ? reviews
        : reviews.where((item) => item.status == statusFilter).toList();
    return StageGateOverview(
      isAdmin: isAdmin,
      reviews: filtered,
      history: history,
    );
  }

  @override
  Future<StageGateReview> submitTransition({
    required String sourceType,
    required String sourceRef,
    required String title,
    required StageGateStage currentStage,
    required StageGateStage targetStage,
    String feedback = '',
  }) async {
    final created = StageGateReview(
      id: 'rev-${reviews.length + 1}',
      sourceType: sourceType,
      sourceRef: sourceRef,
      title: title,
      currentStage: currentStage,
      targetStage: targetStage,
      status: StageGateDecision.pending,
      feedback: feedback,
    );
    reviews.insert(0, created);
    return created;
  }

  @override
  Future<StageGateReview> decideReview({
    required String reviewId,
    required StageGateDecision decision,
    required String feedback,
  }) async {
    decideCalls += 1;
    final idx = reviews.indexWhere((item) => item.id == reviewId);
    final cur = reviews[idx];
    final updated = StageGateReview(
      id: cur.id,
      sourceType: cur.sourceType,
      sourceRef: cur.sourceRef,
      title: cur.title,
      currentStage: decision == StageGateDecision.approved
          ? cur.targetStage
          : cur.currentStage,
      targetStage: cur.targetStage,
      status: decision,
      feedback: feedback,
      submittedBy: cur.submittedBy,
      decidedBy: 'admin-1',
    );
    reviews[idx] = updated;
    return updated;
  }
}

void main() {
  group('StageGateApprovalPanel (#2593)', () {
    testWidgets(
      'approves transition and enforces feedback when rejecting',
      (WidgetTester tester) async {
        final repo = _FakeStageGateRepository(
          <StageGateReview>[
            const StageGateReview(
              id: 'rev-1',
              sourceType: 'github_issue',
              sourceRef: '#2593',
              title: 'Stage-gate design review',
              currentStage: StageGateStage.intake,
              targetStage: StageGateStage.design,
              status: StageGateDecision.pending,
              feedback: '',
            ),
          ],
          <StageGateHistoryEntry>[],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: StageGateApprovalPanel(repository: repo),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('#2593 Stage-gate design review'), findsOneWidget);

        // Rejecting without feedback shows validation message without RPC call
        await tester.tap(
          find.byKey(const ValueKey<String>('stage_gate_reject_rev-1')),
        );
        await tester.pumpAndSettle();
        expect(repo.decideCalls, 0);
        expect(find.text('却下・差し戻し時はフィードバックを入力してください'), findsOneWidget);

        // Enter feedback and approve
        await tester.enterText(
          find.byKey(const ValueKey<String>('stage_gate_feedback_rev-1')),
          '設計仕様とRLS条件を確認済み',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('stage_gate_approve_rev-1')),
        );
        await tester.pumpAndSettle();

        expect(repo.decideCalls, 1);
        expect(find.text('#2593 を「承認」に更新しました'), findsOneWidget);
        expect(find.textContaining('承認: インテーク -> 設計審査'), findsOneWidget);
      },
    );

    testWidgets(
      'hides admin approval controls when non-admin user views panel',
      (WidgetTester tester) async {
        final nonAdminRepo = _FakeStageGateRepository(
          <StageGateReview>[
            const StageGateReview(
              id: 'rev-readonly',
              sourceType: 'github_issue',
              sourceRef: '#2593',
              title: 'Read-only check',
              currentStage: StageGateStage.intake,
              targetStage: StageGateStage.design,
              status: StageGateDecision.pending,
              feedback: '',
            ),
          ],
          <StageGateHistoryEntry>[],
          isAdmin: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StageGateApprovalPanel(repository: nonAdminRepo),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('#2593 Read-only check'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('stage_gate_approve_rev-readonly')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'meets light/dark responsive layout, 2.0x textScale, and a11y guidelines',
      (WidgetTester tester) async {
        final seeded = <StageGateReview>[
          const StageGateReview(
            id: 'rev-a11y',
            sourceType: 'github_issue',
            sourceRef: '#2593',
            title: 'ステージゲート移行監査の長文タイトル表示確認',
            currentStage: StageGateStage.design,
            targetStage: StageGateStage.implementation,
            status: StageGateDecision.changesRequested,
            feedback: '受け入れ条件のチェックリストを追記してください',
          ),
        ];
        final history = <StageGateHistoryEntry>[
          const StageGateHistoryEntry(
            id: 'hist-1',
            reviewId: 'rev-a11y',
            fromStage: StageGateStage.design,
            toStage: StageGateStage.implementation,
            decision: 'changes_requested',
            feedback: '受け入れ条件のチェックリストを追記してください',
          ),
        ];

        final configs = <(Size, ThemeData)>[
          (const Size(390, 844), ThemeData.light()),
          (const Size(1280, 800), ThemeData.dark()),
        ];

        for (final (viewport, theme) in configs) {
          final SemanticsHandle handle = tester.ensureSemantics();
          try {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey<String>('${viewport.width}_${theme.brightness}'),
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: viewport,
                    textScaler: const TextScaler.linear(2.0),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: StageGateApprovalPanel(
                        initialReviews: seeded,
                        initialHistory: history,
                        initialIsAdmin: true,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const ValueKey<String>('stage_gate_approval_panel')),
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
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          } finally {
            handle.dispose();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        }
      },
    );
  });
}
