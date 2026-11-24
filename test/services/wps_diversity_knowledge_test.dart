import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/wps_diversity_knowledge_service.dart';
import 'package:my_web_app/widgets/wps_diversity_dashboard_card.dart';

class _FakeWpsDiversityRepository implements WpsDiversityKnowledgeRepository {
  _FakeWpsDiversityRepository({
    required List<WpsDiversityPolicyItem> seed,
  }) : items = List<WpsDiversityPolicyItem>.from(seed);

  final List<WpsDiversityPolicyItem> items;
  bool shouldThrowOnList = false;

  @override
  Future<List<WpsDiversityPolicyItem>> listPolicies({int limit = 50}) async {
    if (shouldThrowOnList) {
      throw StateError('simulated list failure');
    }
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<WpsDiversityPolicyItem> createTaggedPolicy({
    required String title,
    required String summary,
    WpsKnowledgeSource source = WpsKnowledgeSource.notebooklm,
    String referenceUrl = '',
  }) async {
    final tagged = WpsDiversityKnowledgeTagger.classify(
      title: title,
      content: summary,
      referenceUrl: referenceUrl,
    );
    final created = WpsDiversityPolicyItem(
      id: 'wps-${items.length + 1}',
      userId: 'user-1',
      intakeSource: source,
      title: title,
      summary: summary,
      primaryTopic: tagged.primaryTopic,
      policyTags: tagged.tags,
      frameworkReferences: tagged.frameworkReferences,
      referenceUrl: tagged.referenceUrl,
      confidenceScore: tagged.confidenceScore,
      reviewStatus: tagged.suggestedReviewStatus,
      createdAt: DateTime.utc(2026, 11, 24),
      updatedAt: DateTime.utc(2026, 11, 24),
    );
    items.insert(0, created);
    return created;
  }

  @override
  Future<WpsDiversityPolicyItem> updateReview({
    required String id,
    required WpsPolicyReviewStatus status,
    String reviewNote = '',
    List<String>? overrideTags,
  }) async {
    final idx = items.indexWhere((item) => item.id == id);
    final cur = items[idx];
    final updated = WpsDiversityPolicyItem(
      id: cur.id,
      userId: cur.userId,
      intakeSource: cur.intakeSource,
      title: cur.title,
      summary: cur.summary,
      primaryTopic: cur.primaryTopic,
      policyTags: overrideTags ?? cur.policyTags,
      frameworkReferences: cur.frameworkReferences,
      referenceUrl: cur.referenceUrl,
      confidenceScore: cur.confidenceScore,
      reviewStatus: status,
      reviewNote: reviewNote,
      createdAt: cur.createdAt,
      updatedAt: DateTime.utc(2026, 11, 24, 2),
    );
    items[idx] = updated;
    return updated;
  }
}

List<WpsDiversityPolicyItem> _samplePolicies() => <WpsDiversityPolicyItem>[
      WpsDiversityPolicyItem(
        id: 'wps-1',
        userId: 'user-1',
        intakeSource: WpsKnowledgeSource.notebooklm,
        title: '第3次WPS行動計画・意思決定参画ガイドライン',
        summary: 'UNSCR 1325に基づく女性・平和・安全保障およびジェンダー平等の社内方針整理',
        primaryTopic: WpsTopicCategory.wps,
        policyTags: const <String>['WPS', 'ジェンダー', '人権・行動計画'],
        frameworkReferences: const <String>[
          WpsDiversityKnowledgeTagger.unscr1325Reference,
          WpsDiversityKnowledgeTagger.mofaNap3Reference,
        ],
        referenceUrl: WpsDiversityKnowledgeTagger.mofaWpsNap3Url,
        confidenceScore: 95,
        reviewStatus: WpsPolicyReviewStatus.pendingReview,
        createdAt: DateTime.utc(2026, 11, 24),
      ),
      WpsDiversityPolicyItem(
        id: 'dei-2',
        userId: 'user-1',
        intakeSource: WpsKnowledgeSource.aiMonitor,
        title: 'DE&I 採用多様性レポート',
        summary: 'ダイバーシティとインクルージョン推進に関する年次レビュー',
        primaryTopic: WpsTopicCategory.diversity,
        policyTags: const <String>['ダイバーシティ'],
        frameworkReferences: const <String>[],
        referenceUrl: '',
        confidenceScore: 60,
        reviewStatus: WpsPolicyReviewStatus.approved,
        createdAt: DateTime.utc(2026, 11, 23),
      ),
    ];

void main() {
  group('WpsDiversityKnowledgeService (#2585)', () {
    test(
      'tags WPS/UNSCR 1325/MOFA NAP3 and diversity topics cleanly with lazy repo',
      () {
        final repo = SupabaseWpsDiversityKnowledgeRepository();
        expect(repo, isNotNull);

        final wpsResult = WpsDiversityKnowledgeTagger.classify(
          title: '第3次WPS行動計画レビュー',
          content: '国連安保理決議第1325号とジェンダー平等の参画方針',
        );
        expect(wpsResult.primaryTopic, WpsTopicCategory.wps);
        expect(wpsResult.tags, containsAll(const <String>['WPS', 'ジェンダー']));
        expect(
          wpsResult.frameworkReferences,
          containsAll(
            const <String>[
              WpsDiversityKnowledgeTagger.unscr1325Reference,
              WpsDiversityKnowledgeTagger.mofaNap3Reference,
            ],
          ),
        );
        expect(
          wpsResult.referenceUrl,
          WpsDiversityKnowledgeTagger.mofaWpsNap3Url,
        );
        expect(wpsResult.requiresAdminReview, isTrue);

        expect(
          WpsDiversityKnowledgeTagger.sanitizeReferenceUrl(
            'javascript:alert(1)',
          ),
          isEmpty,
        );

        final stats = WpsKnowledgeStats.fromItems(_samplePolicies());
        expect(stats.totalCount, 2);
        expect(stats.pendingReviewCount, 1);
        expect(stats.approvedCount, 1);
        expect(stats.tagCounts['WPS'], 1);
        expect(stats.tagCounts['ダイバーシティ'], 1);

        final parsed = WpsDiversityPolicyItem.fromJson(
          const <String, Object?>{
            'id': 'row-1',
            'user_id': 'u-1',
            'intake_source': 'notebooklm',
            'title': 'UNSCR 1325 Study',
            'summary': 'Protection & participation',
            'primary_topic': 'wps',
            'policy_tags': <String>['WPS'],
            'framework_references': <String>['UNSCR 1325'],
            'reference_url': 'https://www.un.org/womenwatch/osagi/wps/',
            'confidence_score': 80,
            'review_status': 'approved',
          },
        );
        expect(parsed.hasSafeReferenceUrl, isTrue);
        expect(parsed.reviewStatus, WpsPolicyReviewStatus.approved);
      },
    );
  });

  group('WpsDiversityDashboardCard UI & accessibility (#2585)', () {
    testWidgets(
      'displays tag stats, filters items, opens official link, and executes admin review',
      (tester) async {
        final repo = _FakeWpsDiversityRepository(seed: _samplePolicies());
        final openedUrls = <Uri>[];

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: WpsDiversityDashboardCard(
                  repository: repo,
                  onOpenReferenceUrl: (uri) async {
                    openedUrls.add(uri);
                    return true;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('wps_policy_item_wps-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('wps_policy_item_dei-2')),
          findsOneWidget,
        );

        // Filter by WPS tag
        await tester.tap(
          find.byKey(const ValueKey<String>('wps_filter_chip_WPS')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('wps_policy_item_wps-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('wps_policy_item_dei-2')),
          findsNothing,
        );

        // Open official access link
        await tester.tap(
          find.byKey(const ValueKey<String>('wps_open_link_wps-1')),
        );
        await tester.pumpAndSettle();
        expect(
          openedUrls.single.toString(),
          WpsDiversityKnowledgeTagger.mofaWpsNap3Url,
        );

        // Enter admin review note and request revision
        await tester.enterText(
          find.byKey(const ValueKey<String>('wps_review_note_input')),
          '一次資料URLを確認の上、記述を明確化してください',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('wps_revise_wps-1')),
        );
        await tester.pumpAndSettle();
        expect(
          repo.items.first.reviewStatus,
          WpsPolicyReviewStatus.needsRevision,
        );
        expect(
          repo.items.first.reviewNote,
          '一次資料URLを確認の上、記述を明確化してください',
        );

        // Approve wps-1
        await tester.tap(
          find.byKey(const ValueKey<String>('wps_approve_wps-1')),
        );
        await tester.pumpAndSettle();
        expect(repo.items.first.reviewStatus, WpsPolicyReviewStatus.approved);

        // Error banner when refresh fails
        repo.shouldThrowOnList = true;
        await tester.tap(
          find.byKey(const ValueKey<String>('wps_refresh_btn')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('wps_error_banner')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'meets light/dark 390x844 and 1280x800 layout with 2.0x textScale and accessibility guidelines',
      (tester) async {
        final seeded = _samplePolicies();
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
                key: ValueKey<String>(
                  '${viewport.width}_${theme.brightness}',
                ),
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: viewport,
                    textScaler: const TextScaler.linear(2.0),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: WpsDiversityDashboardCard(
                        initialPolicies: seeded,
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
                const ValueKey<String>('wps_diversity_dashboard_card'),
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
            await expectLater(
              tester,
              meetsGuideline(textContrastGuideline),
            );
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
