import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/rls_ai_search/application/rls_ai_search_controller.dart';
import 'package:my_web_app/features/rls_ai_search/domain/rls_ai_search_models.dart';
import 'package:my_web_app/features/rls_ai_search/rls_ai_search_container.dart';

class _InMemoryRlsAiSearchRepository implements RlsAiSearchRepository {
  _InMemoryRlsAiSearchRepository({this.throwOnSearch = false});

  final bool throwOnSearch;

  bool _financeAuthorized = true;
  bool _restrictedAuthorized = false;
  int _financeVersion = 2;
  int _restrictedVersion = 4;

  @override
  Future<RlsAiSearchResult> searchAuthorizedDocuments({
    required String query,
    int limit = 10,
  }) async {
    if (throwOnSearch) {
      throw StateError('rls search backend unavailable');
    }

    final String q = query.trim().toLowerCase();
    final List<RlsAiDocumentHit> allDocs = <RlsAiDocumentHit>[
      const RlsAiDocumentHit(
        documentId: 'doc-roadmap',
        externalSourceKey: 'drive://roadmap-2026',
        title: '製品ロードマップ 2026',
        contentExcerpt: 'RLS検索と外部権限即時同期',
        aclVersion: 1,
        permissionSource: RlsAccessLevel.owner,
        similarityScore: 0.92,
      ),
      if (_financeAuthorized)
        RlsAiDocumentHit(
          documentId: 'doc-finance',
          externalSourceKey: 'notion://q4-budget-plan',
          title: 'Q4 予算配分計画',
          contentExcerpt: '部門別のAI投資枠と上限管理',
          aclVersion: _financeVersion,
          permissionSource: RlsAccessLevel.viewer,
          similarityScore: 0.96,
        ),
      if (_restrictedAuthorized)
        RlsAiDocumentHit(
          documentId: 'doc-secret',
          externalSourceKey: 'drive://executive-private',
          title: '非公開役員会議事録',
          contentExcerpt: '役員向け機密ドラフト',
          aclVersion: _restrictedVersion,
          permissionSource: RlsAccessLevel.viewer,
          similarityScore: 0.98,
        ),
    ];

    final List<RlsAiDocumentHit> hits = allDocs.where((RlsAiDocumentHit doc) {
      if (q.isEmpty) {
        return true;
      }
      final String hay =
          '${doc.title} ${doc.contentExcerpt} ${doc.externalSourceKey}'
              .toLowerCase();
      return hay.contains(q);
    }).toList(growable: false);

    final int excludedCount =
        (_financeAuthorized ? 0 : 1) + (_restrictedAuthorized ? 0 : 1);

    final List<RlsDocumentAclEntry> acls = <RlsDocumentAclEntry>[
      RlsDocumentAclEntry(
        id: 'acl-finance-1',
        documentId: 'doc-finance',
        externalSourceKey: 'notion://q4-budget-plan',
        documentTitle: 'Q4 予算配分計画',
        granteeLabel: 'alice',
        permissionLevel:
            _financeAuthorized ? RlsAccessLevel.viewer : RlsAccessLevel.revoked,
        isActive: _financeAuthorized,
        ownerUserId: 'alice',
        canManage: true,
        aclVersion: _financeVersion,
      ),
      RlsDocumentAclEntry(
        id: 'acl-secret-2',
        documentId: 'doc-secret',
        externalSourceKey: 'drive://executive-private',
        documentTitle: '非公開役員会議事録',
        granteeLabel: 'alice',
        permissionLevel: _restrictedAuthorized
            ? RlsAccessLevel.viewer
            : RlsAccessLevel.revoked,
        isActive: _restrictedAuthorized,
        ownerUserId: 'other-owner',
        canManage: false,
        aclVersion: _restrictedVersion,
      ),
    ];

    final String prompt = hits.isEmpty
        ? '該当なし'
        : hits
            .map(
              (RlsAiDocumentHit h) =>
                  '[${h.externalSourceKey}] ${h.title}: ${h.contentExcerpt}',
            )
            .join('\n');

    return RlsAiSearchResult(
      hits: hits,
      aclEntries: acls,
      excludedUnauthorizedCount: excludedCount,
      promptContextPreview: prompt,
    );
  }

  @override
  Future<RlsDocumentAclEntry> setAclAccess({
    required RlsDocumentAclEntry entry,
    required bool grantAccess,
    RlsAccessLevel level = RlsAccessLevel.viewer,
  }) async {
    if (entry.documentId == 'doc-finance') {
      _financeAuthorized = grantAccess;
      _financeVersion += 1;
      return entry.copyWith(
        permissionLevel: grantAccess ? level : RlsAccessLevel.revoked,
        isActive: grantAccess,
        aclVersion: _financeVersion,
        revokedAtIso: grantAccess ? null : '2026-11-24T08:45:00Z',
      );
    }
    _restrictedAuthorized = grantAccess;
    _restrictedVersion += 1;
    return entry.copyWith(
      permissionLevel: grantAccess ? level : RlsAccessLevel.revoked,
      isActive: grantAccess,
      aclVersion: _restrictedVersion,
      revokedAtIso: grantAccess ? null : '2026-11-24T08:45:00Z',
    );
  }
}

void main() {
  group('RlsAiSearchController', () {
    test(
      'excludes unauthorized and revoked documents immediately from prompt context',
      () async {
        final _InMemoryRlsAiSearchRepository repo =
            _InMemoryRlsAiSearchRepository();
        final RlsAiSearchController controller =
            RlsAiSearchController(repository: repo);
        addTearDown(controller.dispose);

        await controller.runAuthorizedSearch();
        expect(controller.hits.length, 2);
        expect(controller.excludedUnauthorizedCount, 1);
        expect(
          controller.promptContextPreview,
          isNot(contains('非公開役員会議事録')),
        );
        expect(controller.promptContextPreview, contains('Q4 予算配分計画'));

        final RlsDocumentAclEntry financeEntry = controller.aclEntries.first;
        final bool revoked = await controller.toggleAclAccess(
          entry: financeEntry,
          grantAccess: false,
        );
        expect(revoked, isTrue);
        expect(controller.excludedUnauthorizedCount, 2);
        expect(
          controller.promptContextPreview,
          isNot(contains('Q4 予算配分計画')),
        );

        final RlsDocumentAclEntry readOnlyEntry = controller.aclEntries.last;
        expect(readOnlyEntry.canManage, isFalse);
        final bool granteeAttempt = await controller.toggleAclAccess(
          entry: readOnlyEntry,
          grantAccess: true,
        );
        expect(granteeAttempt, isFalse);
        expect(controller.errorMessage, contains('所有者権限'));

        final RlsDocumentAclEntry parsedJoined = RlsDocumentAclEntry.fromJson(
          <String, Object?>{
            'id': 'acl-99',
            'document_id': 'doc-99',
            'grantee_user_id': 'user-bob',
            'permission_level': 'editor',
            'revoked_at': null,
            'rls_ai_documents': <String, Object?>{
              'owner_user_id': 'user-owner-1',
              'external_source_key': 'drive://spec-v9',
              'title': '設計仕様書',
              'acl_version': 5,
            },
          },
          currentUserId: 'user-bob',
        );
        expect(parsedJoined.externalSourceKey, 'drive://spec-v9');
        expect(parsedJoined.documentTitle, '設計仕様書');
        expect(parsedJoined.aclVersion, 5);
        expect(parsedJoined.canManage, isFalse);

        final RlsDocumentAclEntry parsedOwner = RlsDocumentAclEntry.fromJson(
          <String, Object?>{
            'id': 'acl-99',
            'document_id': 'doc-99',
            'grantee_user_id': 'user-bob',
            'permission_level': 'editor',
            'revoked_at': null,
            'rls_ai_documents': <String, Object?>{
              'owner_user_id': 'user-owner-1',
              'external_source_key': 'drive://spec-v9',
              'title': '設計仕様書',
              'acl_version': 5,
            },
          },
          currentUserId: 'user-owner-1',
        );
        expect(parsedOwner.canManage, isTrue);

        final _InMemoryRlsAiSearchRepository failingRepo =
            _InMemoryRlsAiSearchRepository(throwOnSearch: true);
        final RlsAiSearchController failingController =
            RlsAiSearchController(repository: failingRepo);
        addTearDown(failingController.dispose);
        await failingController.runAuthorizedSearch();
        expect(failingController.errorMessage, isNotEmpty);

        controller.dispose();
        controller.dispose();
      },
    );
  });

  group('RlsAiSearchContainer', () {
    testWidgets(
      'revokes ACL access and excludes revoked document from AI context card immediately',
      (WidgetTester tester) async {
        final _InMemoryRlsAiSearchRepository repo =
            _InMemoryRlsAiSearchRepository();
        final RlsAiSearchController controller =
            RlsAiSearchController(repository: repo);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1E3A8A),
              ),
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RlsAiSearchContainer(
                  controller: controller,
                  autoLoad: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder contextCard = find.byKey(
          const ValueKey<String>('rls-prompt-context-card'),
        );
        expect(
          find.descendant(
            of: contextCard,
            matching: find.textContaining('Q4 予算配分計画'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: contextCard,
            matching: find.textContaining('非公開役員会議事録'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey<String>('rls-acl-toggle-drive://executive-private'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey<String>(
              'rls-acl-readonly-drive://executive-private',
            ),
          ),
          findsOneWidget,
        );

        final Finder revokeBtn = find.byKey(
          const ValueKey<String>('rls-acl-toggle-notion://q4-budget-plan'),
        );
        await tester.ensureVisible(revokeBtn);
        await tester.pumpAndSettle();
        await tester.tap(revokeBtn);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: contextCard,
            matching: find.textContaining('Q4 予算配分計画'),
          ),
          findsNothing,
        );

        final Finder queryField = find.byKey(
          const ValueKey<String>('rls-search-query-field'),
        );
        await tester.ensureVisible(queryField);
        await tester.enterText(queryField, 'ロードマップ');

        final Finder searchBtn = find.byKey(
          const ValueKey<String>('rls-search-submit-button'),
        );
        await tester.ensureVisible(searchBtn);
        await tester.pumpAndSettle();
        await tester.tap(searchBtn);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: contextCard,
            matching: find.textContaining('製品ロードマップ 2026'),
          ),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'passes responsive and WCAG accessibility audit at 360x800 and 1280x800 in light/dark modes with 2.0x textScale',
      (WidgetTester tester) async {
        const List<Size> viewports = <Size>[
          Size(360, 800),
          Size(1280, 800),
        ];
        const List<Brightness> modes = <Brightness>[
          Brightness.light,
          Brightness.dark,
        ];

        for (final Size viewport in viewports) {
          for (final Brightness mode in modes) {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;

            final _InMemoryRlsAiSearchRepository repo =
                _InMemoryRlsAiSearchRepository();
            final RlsAiSearchController controller =
                RlsAiSearchController(repository: repo);

            final SemanticsHandle semanticsHandle = tester.ensureSemantics();
            try {
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>('${viewport.width}_${mode.name}'),
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: mode,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFF1E3A8A),
                      brightness: mode,
                    ),
                  ),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: viewport,
                      textScaler: const TextScaler.linear(2.0),
                    ),
                    child: Scaffold(
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: RlsAiSearchContainer(
                          controller: controller,
                          autoLoad: true,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
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
              controller.dispose();
            }
          }
        }
      },
    );
  });
}
