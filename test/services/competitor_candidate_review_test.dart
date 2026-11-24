import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/competitor_candidate_review_service.dart';
import 'package:my_web_app/widgets/competitor_monitoring_card.dart';

class _FakeCandidateReviewRepository
    implements CompetitorCandidateReviewRepository {
  _FakeCandidateReviewRepository(List<CompetitorCandidateReviewItem> seed)
      : items = List<CompetitorCandidateReviewItem>.from(seed);

  final List<CompetitorCandidateReviewItem> items;

  @override
  Future<List<CompetitorCandidateReviewItem>> listCandidates({
    bool onlyManualReview = false,
    int limit = 50,
  }) async {
    return items
        .where((i) => !onlyManualReview || i.needsManualReview)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<CompetitorCandidateReviewItem> verifyCandidateUrl(
    String candidateId,
  ) async {
    final idx = items.indexWhere((i) => i.id == candidateId);
    final cur = items[idx];
    final updated = CompetitorCandidateReviewItem(
      id: cur.id,
      displayName: cur.displayName,
      category: cur.category,
      website: cur.website,
      sourceUrlStatusCode: 200,
      sourceUrlError: null,
      needsManualReview: false,
      reviewDecision: cur.reviewDecision,
      reviewed: cur.reviewed,
      sourceUrlCheckedAt: DateTime.utc(2026, 11, 24),
    );
    items[idx] = updated;
    return updated;
  }

  @override
  Future<CompetitorCandidateReviewItem> submitReviewDecision({
    required String candidateId,
    required CandidateReviewDecision decision,
    String? rejectedReason,
  }) async {
    final idx = items.indexWhere((i) => i.id == candidateId);
    final cur = items[idx];
    final updated = CompetitorCandidateReviewItem(
      id: cur.id,
      displayName: cur.displayName,
      category: cur.category,
      website: cur.website,
      sourceUrlStatusCode: cur.sourceUrlStatusCode,
      sourceUrlError: cur.sourceUrlError,
      needsManualReview: false,
      reviewDecision: decision,
      reviewed: true,
      rejectedReason: decision == CandidateReviewDecision.rejected
          ? (rejectedReason ?? 'Manual review rejected')
          : null,
      sourceUrlCheckedAt: cur.sourceUrlCheckedAt,
    );
    items[idx] = updated;
    return updated;
  }
}

List<CompetitorCandidateReviewItem> _sampleCandidates() =>
    <CompetitorCandidateReviewItem>[
      const CompetitorCandidateReviewItem(
        id: 'cand-404',
        displayName: 'Ghost Note AI',
        category: 'knowledge',
        website: 'https://ghost.example.com/missing',
        sourceUrlStatusCode: 404,
        sourceUrlError: 'HTTP 404: Not Found',
        needsManualReview: true,
        reviewDecision: CandidateReviewDecision.pending,
        reviewed: false,
      ),
      const CompetitorCandidateReviewItem(
        id: 'cand-ok',
        displayName: 'Verified Workspace',
        category: 'productivity',
        website: 'https://verified.example.com',
        sourceUrlStatusCode: 200,
        needsManualReview: false,
        reviewDecision: CandidateReviewDecision.pending,
        reviewed: false,
      ),
    ];

void main() {
  group('CompetitorCandidateReviewPanel & URL verification UI (#2698)', () {
    test('parses CompetitorCandidateReviewItem JSON cleanly', () {
      final item = CompetitorCandidateReviewItem.fromJson(<String, dynamic>{
        'id': 'cand-1',
        'display_name': 'Example AI',
        'website': 'https://example.com/source',
        'source_url_status_code': 404,
        'source_url_error': 'HTTP 404',
        'needs_manual_review': true,
        'review_decision': 'pending',
        'reviewed': false,
      });
      expect(item.id, 'cand-1');
      expect(item.sourceUrlStatusCode, 404);
      expect(item.needsManualReview, isTrue);
      expect(item.reviewDecision, CandidateReviewDecision.pending);
    });

    testWidgets(
      'filters manual-review flagged items and executes verify/approve/reject actions',
      (tester) async {
        final repo = _FakeCandidateReviewRepository(_sampleCandidates());

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: CompetitorCandidateReviewPanel(repository: repo),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('candidate_review_item_cand-404')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('candidate_review_item_cand-ok')),
          findsOneWidget,
        );

        // Toggle filter to manual review flagged only
        await tester.tap(
          find.byKey(
            const ValueKey<String>('candidate_manual_review_filter'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('candidate_review_item_cand-404')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('candidate_review_item_cand-ok')),
          findsNothing,
        );

        // Clear filter and approve cand-ok, reject cand-404
        await tester.tap(
          find.byKey(
            const ValueKey<String>('candidate_manual_review_filter'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('candidate_approve_cand-ok')),
        );
        await tester.pumpAndSettle();
        expect(repo.items[1].reviewDecision, CandidateReviewDecision.approved);
        expect(repo.items[1].reviewed, isTrue);

        await tester.tap(
          find.byKey(const ValueKey<String>('candidate_reject_cand-404')),
        );
        await tester.pumpAndSettle();
        expect(repo.items[0].reviewDecision, CandidateReviewDecision.rejected);
        expect(repo.items[0].needsManualReview, isFalse);
      },
    );

    testWidgets(
      'meets light/dark layout, 2.0x text scaling, and accessibility guidelines',
      (tester) async {
        final seeded = _sampleCandidates();
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
                      child: CompetitorMonitoringCard(
                        initialDiscoveryLogs: const [],
                        initialReviewCandidates: seeded,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(
                const ValueKey<String>('competitor_candidate_review_panel'),
              ),
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
