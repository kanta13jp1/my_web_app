import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/synthetic_media_audit/application/synthetic_media_audit_controller.dart';
import 'package:my_web_app/features/synthetic_media_audit/data/supabase_synthetic_media_audit_repository.dart';
import 'package:my_web_app/features/synthetic_media_audit/domain/synthetic_media_audit_models.dart';
import 'package:my_web_app/features/synthetic_media_audit/synthetic_media_audit_container.dart';

class _FakeSyntheticMediaAuditRepository
    implements SyntheticMediaAuditRepository {
  _FakeSyntheticMediaAuditRepository({
    required this.isAdminUser,
    required final List<SyntheticMediaVideo> initialVideos,
  }) : _videos = List<SyntheticMediaVideo>.from(initialVideos);

  bool isAdminUser;
  final List<SyntheticMediaVideo> _videos;
  final List<SyntheticMediaAuditLogEntry> _logs =
      <SyntheticMediaAuditLogEntry>[];
  Completer<List<SyntheticMediaVideo>>? pendingVideosFetch;
  Completer<SyntheticMediaVideo>? pendingSubmit;

  @override
  Future<bool> fetchIsAdmin() async => isAdminUser;

  @override
  Future<List<SyntheticMediaVideo>> fetchVideos({final int limit = 60}) async {
    if (pendingVideosFetch != null) {
      return pendingVideosFetch!.future;
    }
    if (isAdminUser) {
      return List<SyntheticMediaVideo>.unmodifiable(_videos);
    }
    return List<SyntheticMediaVideo>.unmodifiable(
      _videos.where(
        (final SyntheticMediaVideo v) =>
            v.isApproved &&
            v.moderationStatus == SyntheticMediaModerationStatus.approved,
      ),
    );
  }

  @override
  Future<List<SyntheticMediaAuditLogEntry>> fetchAuditLogs({
    final int limit = 60,
  }) async {
    if (!isAdminUser) {
      throw StateError('admin privileges required');
    }
    return List<SyntheticMediaAuditLogEntry>.unmodifiable(_logs);
  }

  @override
  Future<SyntheticMediaVideo> submitVideo(
    final SubmitSyntheticMediaInput input,
  ) async {
    if (pendingSubmit != null) {
      return pendingSubmit!.future;
    }
    final DateTime now = DateTime.utc(2026, 11, 24, 17);
    final SyntheticMediaVideo created = SyntheticMediaVideo(
      id: 'vid-${_videos.length + 1}',
      userId: 'user-1',
      title: input.title.trim(),
      videoUrl: input.videoUrl.trim(),
      sourceProvider: input.sourceProvider,
      copyrightConsentStatus: input.copyrightConsentStatus,
      likenessConsentStatus: input.likenessConsentStatus,
      commercialWatermarkPresent: input.commercialWatermarkPresent,
      celebrityLikenessCleared: input.celebrityLikenessCleared,
      trackAndTraceProvider: input.trackAndTraceProvider,
      trackAndTraceId: input.trackAndTraceId,
      moderationStatus: SyntheticMediaModerationStatus.pending,
      isApproved: false,
      createdAt: now,
      updatedAt: now,
    );
    _videos.insert(0, created);
    _logs.insert(
      0,
      SyntheticMediaAuditLogEntry(
        id: 'log-${_logs.length + 1}',
        videoId: created.id,
        actorId: 'user-1',
        action: 'submitted',
        newStatus: 'pending',
        reason: 'submitted for synthetic media ethics review',
        createdAt: now,
      ),
    );
    return created;
  }

  @override
  Future<SyntheticMediaVideo> reviewVideo({
    required final String videoId,
    required final SyntheticMediaModerationStatus decision,
    final String? reviewNote,
  }) async {
    if (!isAdminUser) {
      throw StateError('42501 admin privileges required');
    }
    final int idx =
        _videos.indexWhere((final SyntheticMediaVideo v) => v.id == videoId);
    if (idx < 0) {
      throw StateError('not found');
    }
    final SyntheticMediaVideo target = _videos[idx];
    if (decision == SyntheticMediaModerationStatus.approved &&
        !target.meetsApprovalPrerequisites) {
      throw StateError('23514 prerequisites missing');
    }
    final DateTime now = DateTime.utc(2026, 11, 24, 18);
    final SyntheticMediaVideo updated = target.copyWith(
      moderationStatus: decision,
      isApproved: decision == SyntheticMediaModerationStatus.approved,
      reviewedBy: 'admin-1',
      reviewedAt: now,
      reviewNote: reviewNote,
      updatedAt: now,
    );
    _videos[idx] = updated;
    _logs.insert(
      0,
      SyntheticMediaAuditLogEntry(
        id: 'log-${_logs.length + 1}',
        videoId: updated.id,
        actorId: 'admin-1',
        action: decision.wireValue,
        previousStatus: target.moderationStatus.wireValue,
        newStatus: updated.moderationStatus.wireValue,
        reason: reviewNote,
        createdAt: now,
      ),
    );
    return updated;
  }
}

List<SyntheticMediaVideo> _sampleVideos() {
  final DateTime ts = DateTime.utc(2026, 11, 24, 16);
  return <SyntheticMediaVideo>[
    SyntheticMediaVideo(
      id: 'vid-pending-ready',
      userId: 'creator-1',
      title: 'D-ID Ethics Ready Intro',
      videoUrl: 'https://cdn.example.com/synthetic/ready.mp4',
      sourceProvider: 'd_id',
      copyrightConsentStatus: ConsentVerificationStatus.verified,
      likenessConsentStatus: ConsentVerificationStatus.verified,
      commercialWatermarkPresent: true,
      celebrityLikenessCleared: true,
      trackAndTraceProvider: TrackAndTraceProvider.c2pa,
      trackAndTraceId: 'c2pa_urn_001',
      moderationStatus: SyntheticMediaModerationStatus.pending,
      isApproved: false,
      createdAt: ts,
      updatedAt: ts,
    ),
    SyntheticMediaVideo(
      id: 'vid-pending-incomplete',
      userId: 'creator-2',
      title: 'Unverified Draft Video',
      videoUrl: 'https://cdn.example.com/synthetic/draft.mp4',
      sourceProvider: 'd_id',
      copyrightConsentStatus: ConsentVerificationStatus.pending,
      likenessConsentStatus: ConsentVerificationStatus.verified,
      commercialWatermarkPresent: false,
      celebrityLikenessCleared: true,
      trackAndTraceProvider: TrackAndTraceProvider.none,
      moderationStatus: SyntheticMediaModerationStatus.pending,
      isApproved: false,
      createdAt: ts,
      updatedAt: ts,
    ),
    SyntheticMediaVideo(
      id: 'vid-approved',
      userId: 'creator-3',
      title: 'Approved Philosophy Avatar',
      videoUrl: 'https://cdn.example.com/synthetic/approved.mp4',
      sourceProvider: 'd_id',
      copyrightConsentStatus: ConsentVerificationStatus.verified,
      likenessConsentStatus: ConsentVerificationStatus.verified,
      commercialWatermarkPresent: true,
      celebrityLikenessCleared: true,
      trackAndTraceProvider: TrackAndTraceProvider.digitalWatermark,
      trackAndTraceId: 'wm_8892',
      moderationStatus: SyntheticMediaModerationStatus.approved,
      isApproved: true,
      reviewedBy: 'admin-1',
      reviewedAt: ts,
      createdAt: ts,
      updatedAt: ts,
    ),
    SyntheticMediaVideo(
      id: 'vid-rejected',
      userId: 'creator-4',
      title: 'Rejected Celebrity Lookalike',
      videoUrl: 'https://cdn.example.com/synthetic/rejected.mp4',
      sourceProvider: 'd_id',
      copyrightConsentStatus: ConsentVerificationStatus.verified,
      likenessConsentStatus: ConsentVerificationStatus.rejected,
      commercialWatermarkPresent: true,
      celebrityLikenessCleared: false,
      trackAndTraceProvider: TrackAndTraceProvider.none,
      moderationStatus: SyntheticMediaModerationStatus.rejected,
      isApproved: false,
      reviewedBy: 'admin-1',
      reviewedAt: ts,
      reviewNote: '肖像権同意未確認のため却下',
      createdAt: ts,
      updatedAt: ts,
    ),
  ];
}

void main() {
  group('SyntheticMediaAudit domain & controller (#2661)', () {
    test('blocks approval without full ethics pledge and enforces reject note',
        () async {
      final _FakeSyntheticMediaAuditRepository repo =
          _FakeSyntheticMediaAuditRepository(
        isAdminUser: true,
        initialVideos: _sampleVideos(),
      );
      final SyntheticMediaAuditController ctrl =
          SyntheticMediaAuditController(repository: repo);
      addTearDown(ctrl.dispose);

      await ctrl.loadDashboard();
      expect(ctrl.state.isAdmin, isTrue);
      expect(ctrl.state.approvedFeedVideos.length, 1);
      expect(
        ctrl.state.approvedFeedVideos.single.id,
        'vid-approved',
      );

      final SyntheticMediaVideo incomplete = ctrl.state.videos.firstWhere(
        (final SyntheticMediaVideo v) => v.id == 'vid-pending-incomplete',
      );
      final bool blockedApprove = await ctrl.reviewVideo(
        target: incomplete,
        decision: SyntheticMediaModerationStatus.approved,
      );
      expect(blockedApprove, isFalse);
      expect(ctrl.state.errorMessage, contains('著作権同意の確認'));

      // clearError on status filter change
      ctrl.selectStatusFilter(SyntheticMediaModerationStatus.pending);
      expect(ctrl.state.errorMessage, isNull);

      final bool missingRejectNote = await ctrl.reviewVideo(
        target: incomplete,
        decision: SyntheticMediaModerationStatus.rejected,
        reviewNote: '   ',
      );
      expect(missingRejectNote, isFalse);
      expect(ctrl.state.errorMessage, contains('必須'));

      final SyntheticMediaVideo ready = ctrl.state.videos.firstWhere(
        (final SyntheticMediaVideo v) => v.id == 'vid-pending-ready',
      );
      final bool approvedOk = await ctrl.reviewVideo(
        target: ready,
        decision: SyntheticMediaModerationStatus.approved,
        reviewNote: '全要件確認済み',
      );
      expect(approvedOk, isTrue);
      expect(ctrl.state.approvedFeedVideos.length, 2);
      expect(ctrl.state.auditLogs.first.action, 'approved');
    });

    test('isolates approved feed for non-admin and handles dispose mid-flight',
        () async {
      final _FakeSyntheticMediaAuditRepository nonAdminRepo =
          _FakeSyntheticMediaAuditRepository(
        isAdminUser: false,
        initialVideos: _sampleVideos(),
      );
      final SyntheticMediaAuditController nonAdminCtrl =
          SyntheticMediaAuditController(repository: nonAdminRepo);
      addTearDown(nonAdminCtrl.dispose);

      await nonAdminCtrl.loadDashboard();
      expect(nonAdminCtrl.state.isAdmin, isFalse);
      expect(nonAdminCtrl.state.videos.length, 1);
      expect(nonAdminCtrl.state.videos.single.id, 'vid-approved');
      expect(nonAdminCtrl.state.auditLogs, isEmpty);

      final bool nonAdminReview = await nonAdminCtrl.reviewVideo(
        target: _sampleVideos().first,
        decision: SyntheticMediaModerationStatus.approved,
      );
      expect(nonAdminReview, isFalse);
      expect(nonAdminCtrl.state.errorMessage, contains('管理者権限'));

      // Pending Completer disposal safety test (Rule #11a)
      final Completer<List<SyntheticMediaVideo>> pendingLoad =
          Completer<List<SyntheticMediaVideo>>();
      final _FakeSyntheticMediaAuditRepository pendingRepo =
          _FakeSyntheticMediaAuditRepository(
        isAdminUser: true,
        initialVideos: _sampleVideos(),
      )..pendingVideosFetch = pendingLoad;

      final SyntheticMediaAuditController disposedCtrl =
          SyntheticMediaAuditController(repository: pendingRepo);
      int notifications = 0;
      disposedCtrl.addListener(() {
        notifications += 1;
      });
      final Future<void> loadFuture = disposedCtrl.loadDashboard();
      final int beforeDispose = notifications;
      disposedCtrl.dispose();

      pendingLoad.complete(_sampleVideos());
      await loadFuture;
      expect(notifications, beforeDispose);
    });
  });

  group('SyntheticMediaAuditContainer widget & a11y (#2661)', () {
    Future<void> pumpViewport(
      final WidgetTester tester, {
      required final Size size,
      required final Brightness brightness,
      required final SyntheticMediaAuditController controller,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            brightness: brightness,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1D4ED8),
              brightness: brightness,
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (final BuildContext context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: SyntheticMediaAuditContainer(
                  controller: controller,
                  autoLoad: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'hides admin controls from non-admin and passes Light/Dark a11y',
      (final WidgetTester tester) async {
        final SemanticsHandle semanticsHandle = tester.ensureSemantics();
        final _FakeSyntheticMediaAuditRepository repo =
            _FakeSyntheticMediaAuditRepository(
          isAdminUser: false,
          initialVideos: _sampleVideos(),
        );
        final SyntheticMediaAuditController controller =
            SyntheticMediaAuditController(repository: repo);
        try {
          await controller.loadDashboard();

          await pumpViewport(
            tester,
            size: const Size(360, 800),
            brightness: Brightness.light,
            controller: controller,
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(
              const ValueKey<String>('synthetic-media-admin-section'),
            ),
            findsNothing,
          );
          final Finder approvedCard = find.byKey(
            const ValueKey<String>('approved-feed-card-vid-approved'),
          );
          await tester.ensureVisible(approvedCard);
          expect(approvedCard, findsOneWidget);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));

          await pumpViewport(
            tester,
            size: const Size(1280, 800),
            brightness: Brightness.dark,
            controller: controller,
          );
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        } finally {
          semanticsHandle.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          controller.dispose();
        }
      },
    );

    testWidgets(
      'renders admin moderation queue and approves eligible video',
      (final WidgetTester tester) async {
        final SemanticsHandle semanticsHandle = tester.ensureSemantics();
        final _FakeSyntheticMediaAuditRepository repo =
            _FakeSyntheticMediaAuditRepository(
          isAdminUser: true,
          initialVideos: _sampleVideos(),
        );
        final SyntheticMediaAuditController controller =
            SyntheticMediaAuditController(repository: repo);
        try {
          await controller.loadDashboard();

          await pumpViewport(
            tester,
            size: const Size(1280, 800),
            brightness: Brightness.light,
            controller: controller,
          );
          expect(
            find.byKey(
              const ValueKey<String>('synthetic-media-admin-section'),
            ),
            findsOneWidget,
          );

          final Finder approveBtn = find.byKey(
            const ValueKey<String>('audit-approve-button-vid-pending-ready'),
          );
          await tester.ensureVisible(approveBtn);
          await tester.tap(approveBtn);
          await tester.pumpAndSettle();

          expect(controller.state.approvedFeedVideos.length, 2);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        } finally {
          semanticsHandle.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          controller.dispose();
        }
      },
    );
  });
}
