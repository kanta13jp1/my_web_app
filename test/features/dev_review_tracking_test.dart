import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/dev_review/dev_review_tracking_container.dart';
import 'package:my_web_app/features/dev_review/domain/dev_review_models.dart';

class _FakeDevReviewTrackingRepository implements DevReviewTrackingRepository {
  _FakeDevReviewTrackingRepository();

  List<DevReviewSession> sessions = <DevReviewSession>[_buildInitialSession()];
  bool throwOnList = false;
  Completer<List<DevReviewSession>>? pendingListCompleter;
  int listCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int syncCalls = 0;
  int advanceCalls = 0;

  @override
  Future<List<DevReviewSession>> listSessions({
    String statusFilter = 'all',
    String assigneeFilter = '',
  }) async {
    listCalls += 1;
    if (pendingListCompleter != null) {
      return pendingListCompleter!.future;
    }
    if (throwOnList) {
      throw StateError('repository unavailable');
    }
    return sessions.map((sess) {
      final filtered = sess.items.where((item) {
        if (statusFilter != 'all' && item.status.wireValue != statusFilter) {
          return false;
        }
        if (assigneeFilter.isNotEmpty &&
            !item.assignee
                .toLowerCase()
                .contains(assigneeFilter.toLowerCase())) {
          return false;
        }
        return true;
      }).toList(growable: false);
      return DevReviewSession(
        id: sess.id,
        title: sess.title,
        targetType: sess.targetType,
        githubRepo: sess.githubRepo,
        targetNumber: sess.targetNumber,
        currentPhase: sess.currentPhase,
        approver: sess.approver,
        items: filtered,
        githubSnapshot: sess.githubSnapshot,
        updatedAt: sess.updatedAt,
      );
    }).toList(growable: false);
  }

  @override
  Future<DevReviewSession> createSession({
    required String title,
    required String targetType,
    required String githubRepo,
    required int targetNumber,
    required String approver,
    required String assignee,
  }) async {
    createCalls += 1;
    final created = DevReviewSession(
      id: 'rev-created-$createCalls',
      title: title,
      targetType: targetType,
      githubRepo: githubRepo,
      targetNumber: targetNumber,
      currentPhase: DevReviewPhase.intake,
      approver: approver,
      items: <DevReviewChecklistItem>[
        DevReviewChecklistItem(
          id: 'chk-1',
          kind: DevReviewItemKind.checklist,
          title: '受入条件チェック',
          category: 'spec',
          status: DevReviewItemStatus.pending,
          assignee: assignee,
          note: '',
          updatedAt: '2026-11-25T12:00:00Z',
        ),
      ],
      githubSnapshot: DevReviewGithubSnapshot(
        repo: githubRepo,
        targetType: targetType,
        number: targetNumber,
        url: 'https://github.com/$githubRepo/pull/$targetNumber',
        state: 'open',
        reviewDecision: 'none',
        syncedAt: '2026-11-25T12:00:00Z',
      ),
      updatedAt: '2026-11-25T12:00:00Z',
    );
    sessions = <DevReviewSession>[created, ...sessions];
    return created;
  }

  @override
  Future<DevReviewSession> updateItemStatus({
    required String sessionId,
    required String itemId,
    required DevReviewItemStatus status,
    required String assignee,
    required String note,
  }) async {
    updateCalls += 1;
    sessions = sessions.map((sess) {
      if (sess.id != sessionId) return sess;
      return DevReviewSession(
        id: sess.id,
        title: sess.title,
        targetType: sess.targetType,
        githubRepo: sess.githubRepo,
        targetNumber: sess.targetNumber,
        currentPhase: sess.currentPhase,
        approver: sess.approver,
        items: sess.items
            .map(
              (item) => item.id == itemId
                  ? DevReviewChecklistItem(
                      id: item.id,
                      kind: item.kind,
                      title: item.title,
                      category: item.category,
                      status: status,
                      assignee: assignee,
                      note: note,
                      updatedAt: '2026-11-25T12:05:00Z',
                    )
                  : item,
            )
            .toList(growable: false),
        githubSnapshot: sess.githubSnapshot,
        updatedAt: '2026-11-25T12:05:00Z',
      );
    }).toList(growable: false);
    return sessions.first;
  }

  @override
  Future<DevReviewSession> addFinding({
    required String sessionId,
    required String title,
    required String assignee,
    required String note,
  }) async {
    return sessions.first;
  }

  @override
  Future<DevReviewSession> syncGithubStatus({
    required String sessionId,
    required String state,
    required String reviewDecision,
    bool fetchLive = false,
  }) async {
    syncCalls += 1;
    sessions = sessions.map((sess) {
      if (sess.id != sessionId) return sess;
      return DevReviewSession(
        id: sess.id,
        title: sess.title,
        targetType: sess.targetType,
        githubRepo: sess.githubRepo,
        targetNumber: sess.targetNumber,
        currentPhase: sess.currentPhase,
        approver: sess.approver,
        items: sess.items,
        githubSnapshot: DevReviewGithubSnapshot(
          repo: sess.githubRepo,
          targetType: sess.targetType,
          number: sess.targetNumber,
          url: sess.githubSnapshot?.url ?? '',
          state: state,
          reviewDecision: reviewDecision,
          syncedAt: '2026-11-25T12:10:00Z',
        ),
        updatedAt: '2026-11-25T12:10:00Z',
      );
    }).toList(growable: false);
    return sessions.first;
  }

  @override
  Future<PhaseAdvanceOutcome> advancePhase({
    required String sessionId,
    required DevReviewPhase targetPhase,
    required String note,
  }) async {
    advanceCalls += 1;
    final target = sessions.firstWhere((s) => s.id == sessionId);
    final reasons = target.blockingReasonsForNextPhase();
    if (reasons.isNotEmpty) {
      return PhaseAdvanceOutcome(blocked: true, blockingReasons: reasons);
    }
    final nextSess = DevReviewSession(
      id: target.id,
      title: target.title,
      targetType: target.targetType,
      githubRepo: target.githubRepo,
      targetNumber: target.targetNumber,
      currentPhase: targetPhase,
      approver: target.approver,
      items: target.items,
      githubSnapshot: target.githubSnapshot,
      updatedAt: '2026-11-25T12:15:00Z',
    );
    sessions = sessions
        .map((s) => s.id == sessionId ? nextSess : s)
        .toList(growable: false);
    return PhaseAdvanceOutcome(
      blocked: false,
      blockingReasons: const <String>[],
      updatedSession: nextSess,
    );
  }
}

DevReviewSession _buildInitialSession() {
  return const DevReviewSession(
    id: 'rev-1',
    title: 'Issue #2743 初回レビュー',
    targetType: 'pr',
    githubRepo: 'kanta13jp1/my_web_app',
    targetNumber: 2743,
    currentPhase: DevReviewPhase.intake,
    approver: 'tech-lead',
    items: <DevReviewChecklistItem>[
      DevReviewChecklistItem(
        id: 'chk-spec',
        kind: DevReviewItemKind.checklist,
        title: 'PR 受入条件確認',
        category: 'spec',
        status: DevReviewItemStatus.pending,
        assignee: 'dev-a',
        note: '',
        updatedAt: '2026-11-25T11:00:00Z',
      ),
      DevReviewChecklistItem(
        id: 'tv-unit',
        kind: DevReviewItemKind.testVariation,
        title: 'ユニットテスト観点',
        category: 'unit',
        status: DevReviewItemStatus.approved,
        assignee: 'dev-b',
        note: 'OK',
        updatedAt: '2026-11-25T11:05:00Z',
      ),
    ],
    githubSnapshot: DevReviewGithubSnapshot(
      repo: 'kanta13jp1/my_web_app',
      targetType: 'pr',
      number: 2743,
      url: 'https://github.com/kanta13jp1/my_web_app/pull/2743',
      state: 'open',
      reviewDecision: 'none',
      syncedAt: '2026-11-25T11:00:00Z',
    ),
    updatedAt: '2026-11-25T11:05:00Z',
  );
}

void main() {
  group('DevReviewModels', () {
    test('rejects malformed payload and reports unapproved blocking reasons',
        () {
      expect(
        () => DevReviewSession.fromJson(
          const <String, Object?>{'id': 'rev-bad', 'items': 'invalid'},
        ),
        throwsFormatException,
      );

      final sess = _buildInitialSession();
      final reasons = sess.blockingReasonsForNextPhase();
      expect(reasons.length, 1);
      expect(reasons.first, contains('PR 受入条件確認'));
    });
  });

  group('DevReviewTrackingContainer widget tests', () {
    testWidgets(
        'blocks phase advance when checklist unapproved then advances once approved',
        (WidgetTester tester) async {
      final repo = _FakeDevReviewTrackingRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: DevReviewTrackingContainer(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Issue #2743 初回レビュー'), findsOneWidget);

      final advanceBtn = find.byKey(const Key('dev_review_advance_rev-1'));
      await tester.ensureVisible(advanceBtn);
      await tester.tap(advanceBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dev_review_error_banner')), findsOneWidget);
      expect(find.textContaining('すべての項目が承認されるまで'), findsOneWidget);

      final approveBtn =
          find.byKey(const Key('dev_review_approve_rev-1_chk-spec'));
      await tester.ensureVisible(approveBtn);
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      expect(repo.updateCalls, 1);

      await tester.ensureVisible(advanceBtn);
      await tester.tap(advanceBtn);
      await tester.pumpAndSettle();

      expect(repo.advanceCalls, 1);
      expect(find.text('現在フェーズ: 設計 (Design)'), findsOneWidget);
    });

    testWidgets('creates session, syncs GitHub status, and filters items', (
      WidgetTester tester,
    ) async {
      final repo = _FakeDevReviewTrackingRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: DevReviewTrackingContainer(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      final createBtn = find.byKey(const Key('dev_review_create_btn'));
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(repo.createCalls, 1);
      expect(find.textContaining('チェックリストとテスト観点を生成しました'), findsOneWidget);

      final syncBtn = find.byKey(const Key('dev_review_sync_gh_rev-1'));
      await tester.ensureVisible(syncBtn);
      await tester.tap(syncBtn);
      await tester.pumpAndSettle();

      expect(repo.syncCalls, 1);
      expect(find.text('GitHub #2743: open / approved'), findsOneWidget);

      final filterChip = find.byKey(const Key('dev_review_filter_pending'));
      await tester.ensureVisible(filterChip);
      await tester.tap(filterChip);
      await tester.pumpAndSettle();

      expect(find.textContaining('PR 受入条件確認'), findsOneWidget);
      expect(find.textContaining('ユニットテスト観点'), findsNothing);
    });

    testWidgets('shows error banner on failure and retries cleanly', (
      WidgetTester tester,
    ) async {
      final repo = _FakeDevReviewTrackingRepository()..throwOnList = true;
      await tester.pumpWidget(
        MaterialApp(
          home: DevReviewTrackingContainer(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dev_review_error_banner')), findsOneWidget);

      repo.throwOnList = false;
      final retryBtn = find.byKey(const Key('dev_review_retry_btn'));
      await tester.ensureVisible(retryBtn);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dev_review_error_banner')), findsNothing);
      expect(repo.listCalls, 2);
    });

    testWidgets('ignores mid-flight fetch after dispose', (
      WidgetTester tester,
    ) async {
      final repo = _FakeDevReviewTrackingRepository()
        ..pendingListCompleter = Completer<List<DevReviewSession>>();

      await tester.pumpWidget(
        MaterialApp(
          home: DevReviewTrackingContainer(repository: repo),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      repo.pendingListCompleter!
          .complete(<DevReviewSession>[_buildInitialSession()]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('supports mobile and desktop viewports in dark 2.0x textScale',
        (WidgetTester tester) async {
      final repo = _FakeDevReviewTrackingRepository();
      for (final Size viewport in const <Size>[
        Size(360, 800),
        Size(390, 844),
        Size(1280, 800),
      ]) {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: viewport,
              textScaler: const TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: DevReviewTrackingContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        for (final Finder btn in <Finder>[
          find.byKey(const Key('dev_review_refresh_btn')),
          find.byKey(const Key('dev_review_create_btn')),
          find.byKey(const Key('dev_review_apply_filter_btn')),
        ]) {
          final size = tester.getSize(btn);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
  });
}
