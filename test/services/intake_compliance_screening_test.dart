import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/intake_compliance_screening_service.dart';
import 'package:my_web_app/widgets/intake_compliance_review_panel.dart';

class _FakeIntakeComplianceRepository implements IntakeComplianceRepository {
  _FakeIntakeComplianceRepository({
    required List<IntakeComplianceScreeningItem> seed,
  }) : items = List<IntakeComplianceScreeningItem>.from(seed);

  final List<IntakeComplianceScreeningItem> items;
  bool shouldThrowOnList = false;

  @override
  Future<List<IntakeComplianceScreeningItem>> listScreenings({
    bool onlyRequiresVerification = false,
    int limit = 50,
  }) async {
    if (shouldThrowOnList) {
      throw StateError('simulated list failure');
    }
    return items
        .where(
          (item) => !onlyRequiresVerification || item.requiresVerification,
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<IntakeComplianceScreeningItem> screenAndSave({
    required String title,
    required String content,
    IntakeSource source = IntakeSource.manual,
  }) async {
    final result = IntakeComplianceClassifier.classify(
      title: title,
      content: content,
    );
    final created = IntakeComplianceScreeningItem(
      id: 'scr-${items.length + 1}',
      userId: 'user-1',
      intakeSource: source,
      title: title,
      contentExcerpt: content,
      riskCategory: result.riskCategory,
      riskScore: result.riskScore,
      matchedKeywords: result.matchedKeywords,
      requiresVerification: result.requiresVerification,
      reviewStatus: result.suggestedReviewStatus,
      createdAt: DateTime.utc(2026, 11, 24),
      updatedAt: DateTime.utc(2026, 11, 24),
    );
    items.insert(0, created);
    return created;
  }

  @override
  Future<IntakeComplianceScreeningItem> updateReviewStatus({
    required String id,
    required ComplianceReviewStatus status,
  }) async {
    final idx = items.indexWhere((item) => item.id == id);
    final cur = items[idx];
    final updated = IntakeComplianceScreeningItem(
      id: cur.id,
      userId: cur.userId,
      intakeSource: cur.intakeSource,
      title: cur.title,
      contentExcerpt: cur.contentExcerpt,
      riskCategory: cur.riskCategory,
      riskScore: cur.riskScore,
      matchedKeywords: cur.matchedKeywords,
      requiresVerification: status != ComplianceReviewStatus.verifiedSafe,
      reviewStatus: status,
      createdAt: cur.createdAt,
      updatedAt: DateTime.utc(2026, 11, 24, 2),
    );
    items[idx] = updated;
    return updated;
  }
}

List<IntakeComplianceScreeningItem> _sampleScreenings() =>
    <IntakeComplianceScreeningItem>[
      IntakeComplianceScreeningItem(
        id: 'scr-risk-1',
        userId: 'user-1',
        intakeSource: IntakeSource.notebooklm,
        title: 'APAC 企業結合規制レビュー',
        contentExcerpt: 'オーストラリア競争消費者法改正と独占禁止法リスクの確認',
        riskCategory: ComplianceRiskCategory.antitrust,
        riskScore: 75,
        matchedKeywords: const <String>['独占禁止法', '企業結合規制', '競争消費者法'],
        requiresVerification: true,
        reviewStatus: ComplianceReviewStatus.pending,
        createdAt: DateTime.utc(2026, 11, 24),
      ),
      IntakeComplianceScreeningItem(
        id: 'scr-safe-2',
        userId: 'user-1',
        intakeSource: IntakeSource.githubIssue,
        title: 'UI 余白調整ガイド',
        contentExcerpt: 'デザインシステムのカード角丸と余白の整理メモ',
        riskCategory: ComplianceRiskCategory.none,
        riskScore: 0,
        matchedKeywords: const <String>[],
        requiresVerification: false,
        reviewStatus: ComplianceReviewStatus.verifiedSafe,
        createdAt: DateTime.utc(2026, 11, 23),
      ),
    ];

void main() {
  group('IntakeComplianceClassifier & Repository (#2595)', () {
    test(
      'flags antitrust/regulatory/financial text and passes benign text cleanly',
      () {
        final repo = SupabaseIntakeComplianceRepository();
        expect(repo, isNotNull);

        final benign = IntakeComplianceClassifier.classify(
          title: 'Markdown editor polish',
          content: 'Improve shortcut hint copy in toolbar.',
        );
        expect(benign.riskCategory, ComplianceRiskCategory.none);
        expect(benign.riskScore, 0);
        expect(benign.matchedKeywords, isEmpty);
        expect(benign.requiresVerification, isFalse);
        expect(
          benign.suggestedReviewStatus,
          ComplianceReviewStatus.verifiedSafe,
        );

        final risky = IntakeComplianceClassifier.classify(
          title: 'APAC M&A メモ',
          content: '企業結合規制および独占禁止法・財務予測の検証が必要',
        );
        expect(risky.riskCategory, ComplianceRiskCategory.antitrust);
        expect(risky.riskScore, greaterThan(0));
        expect(risky.matchedKeywords, contains('独占禁止法'));
        expect(risky.matchedKeywords, contains('企業結合規制'));
        expect(risky.matchedKeywords, contains('財務予測'));
        expect(risky.requiresVerification, isTrue);
        expect(risky.suggestedReviewStatus, ComplianceReviewStatus.pending);
      },
    );
  });

  group('IntakeComplianceReviewPanel UI & accessibility (#2595)', () {
    testWidgets(
      'filters requires_verification items and executes approve/hold transitions',
      (tester) async {
        final repo = _FakeIntakeComplianceRepository(seed: _sampleScreenings());

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: IntakeComplianceReviewPanel(repository: repo),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default filter shows only requires_verification == true items
        expect(
          find.byKey(const ValueKey<String>('compliance_item_scr-risk-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('compliance_item_scr-safe-2')),
          findsNothing,
        );

        // Toggle filter off -> both items visible
        await tester.tap(
          find.byKey(
            const ValueKey<String>('compliance_requires_verification_filter'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('compliance_item_scr-safe-2')),
          findsOneWidget,
        );

        // Hold scr-risk-1
        await tester.tap(
          find.byKey(const ValueKey<String>('compliance_hold_scr-risk-1')),
        );
        await tester.pumpAndSettle();
        expect(
          repo.items.first.reviewStatus,
          ComplianceReviewStatus.flaggedHold,
        );
        expect(repo.items.first.requiresVerification, isTrue);

        // Approve scr-risk-1 -> clears requiresVerification
        await tester.tap(
          find.byKey(const ValueKey<String>('compliance_approve_scr-risk-1')),
        );
        await tester.pumpAndSettle();
        expect(
          repo.items.first.reviewStatus,
          ComplianceReviewStatus.verifiedSafe,
        );
        expect(repo.items.first.requiresVerification, isFalse);

        // Error path on list failure
        repo.shouldThrowOnList = true;
        await tester.tap(
          find.byKey(const ValueKey<String>('compliance_refresh_btn')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('compliance_error_banner')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'meets light/dark 390x844 and 1280x800 layout with 2.0x textScale and accessibility guidelines',
      (tester) async {
        final seeded = _sampleScreenings();
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
                      child: IntakeComplianceReviewPanel(
                        initialScreenings: seeded,
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
                const ValueKey<String>('intake_compliance_review_panel'),
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
