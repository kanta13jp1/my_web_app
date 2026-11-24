import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/early_access_feature_service.dart';
import 'package:my_web_app/widgets/early_access_hub_panel.dart';

void main() {
  group('EarlyAccessPolicyEvaluator', () {
    test(
      'unlocks feature flags progressively by verified tier and blocks monetized flags',
      () {
        const List<EarlyAccessFeatureFlag> catalog =
            EarlyAccessPolicyEvaluator.defaultCatalog;

        expect(
          EarlyAccessPolicyEvaluator.unlockedFlagsFor(
            EarlyAccessTier.standard,
            catalog,
          ).map((EarlyAccessFeatureFlag f) => f.flagKey),
          equals(<String>['offline_vault_prefetch']),
        );
        expect(
          EarlyAccessPolicyEvaluator.unlockedFlagsFor(
            EarlyAccessTier.insider,
            catalog,
          ).map((EarlyAccessFeatureFlag f) => f.flagKey),
          equals(<String>['offline_vault_prefetch', 'ai_voice_macro_v2']),
        );
        expect(
          EarlyAccessPolicyEvaluator.unlockedFlagsFor(
            EarlyAccessTier.vip,
            catalog,
          ).length,
          4,
        );

        const EarlyAccessFeatureFlag paidFlag = EarlyAccessFeatureFlag(
          flagKey: 'paid_experimental',
          title: '有償実験機能',
          description: 'テスト用フラグ',
          minTier: EarlyAccessTier.standard,
          monetizationEnabled: true,
        );
        expect(
          EarlyAccessPolicyEvaluator.isFlagUnlocked(
            EarlyAccessTier.vip,
            paidFlag,
          ),
          isFalse,
        );
      },
    );

    test(
      'reads tier strictly from admin app_metadata and builds structured GitHub issue payload',
      () {
        expect(
          EarlyAccessPolicyEvaluator.parseTierFromAppMetadata(
            const <String, Object?>{'early_access_tier': 'supporter'},
          ),
          EarlyAccessTier.supporter,
        );
        expect(
          EarlyAccessPolicyEvaluator.parseTierFromAppMetadata(
            const <String, Object?>{'early_access_tier': 'invalid_value'},
          ),
          EarlyAccessTier.standard,
        );

        final Map<String, Object?> payload =
            EarlyAccessPolicyEvaluator.buildGitHubIssuePayload(
          const EarlyAccessFeedbackDraft(
            flagKey: 'ai_voice_macro_v2',
            flagTitle: '音声コマンド・マクロ v2 (Insider)',
            feedbackLabel: 'early-access-insider',
            tier: EarlyAccessTier.insider,
            category: EarlyAccessFeedbackCategory.enhancement,
            title: '短文確定ボタンの改善提案',
            body: '音声認識確定後にワンタップで再試行できるボタンを追加してほしいです。',
          ),
        );
        expect(
          payload['title'],
          '[Early Access: ai_voice_macro_v2] 短文確定ボタンの改善提案',
        );
        expect(
          payload['labels'],
          containsAll(
            <String>[
              'early-access',
              'early-access-insider',
              'enhancement',
            ],
          ),
        );
        expect(payload['body'], contains('`ai_voice_macro_v2`'));
      },
    );
  });

  group('EarlyAccessFeatureService', () {
    test(
      'enforces tier lock on opt-in toggles, persists cache, and handles disposal',
      () async {
        String activeTier = 'standard';
        final InMemoryEarlyAccessCacheStore cache =
            InMemoryEarlyAccessCacheStore();
        final EarlyAccessFeatureService service = EarlyAccessFeatureService(
          cacheStore: cache,
          appMetadataResolver: () => <String, Object?>{
            'early_access_tier': activeTier,
          },
          issueDispatcher: (EarlyAccessFeedbackDraft draft) async {
            return const GitHubIssueDispatchResult(
              issueNumber: 9001,
              issueUrl: 'https://github.com/kanta13jp1/my_web_app/issues/9001',
              dispatchedToGitHub: true,
            );
          },
        );
        addTearDown(service.dispose);

        await service.loadInitialData();
        expect(service.effectiveTier, EarlyAccessTier.standard);
        expect(
          await service.toggleFeatureFlag('ai_voice_macro_v2', true),
          isFalse,
        );
        expect(service.isFlagOptedIn('ai_voice_macro_v2'), isFalse);

        activeTier = 'insider';
        service.refreshAppMetadataAccess();
        expect(service.effectiveTier, EarlyAccessTier.insider);
        expect(
          await service.toggleFeatureFlag('ai_voice_macro_v2', true),
          isTrue,
        );
        expect(service.isFlagOptedIn('ai_voice_macro_v2'), isTrue);
        expect(await cache.readJson(), contains('ai_voice_macro_v2'));

        service.dispose();
        service.refreshAppMetadataAccess();
      },
    );

    test('queues failed GitHub dispatch offline and retries cleanly', () async {
      bool shouldFail = true;
      final EarlyAccessFeatureService service = EarlyAccessFeatureService(
        cacheStore: InMemoryEarlyAccessCacheStore(),
        appMetadataResolver: () => const <String, Object?>{
          'early_access_tier': 'insider',
        },
        issueDispatcher: (EarlyAccessFeedbackDraft draft) async {
          if (shouldFail) {
            throw StateError('network unavailable');
          }
          return const GitHubIssueDispatchResult(
            issueNumber: 9002,
            issueUrl: 'https://github.com/kanta13jp1/my_web_app/issues/9002',
            dispatchedToGitHub: true,
          );
        },
      );
      addTearDown(service.dispose);

      await service.loadInitialData();
      final EarlyAccessFeedbackRecord? invalid = await service.submitFeedback(
        flagKey: 'ai_voice_macro_v2',
        category: EarlyAccessFeedbackCategory.bug,
        title: '短',
        body: '詳細も短い',
      );
      expect(invalid, isNull);

      final EarlyAccessFeedbackRecord? queued = await service.submitFeedback(
        flagKey: 'ai_voice_macro_v2',
        category: EarlyAccessFeedbackCategory.bug,
        title: 'オフライン送信フォールバック確認',
        body: '一時的なネットワーク遮断時にも入力内容が失われず再送できることを確認したいです。',
      );
      expect(queued, isNotNull);
      expect(queued!.syncStatus, EarlyAccessSyncStatus.queuedOffline);

      shouldFail = false;
      final int syncedCount = await service.retryPendingFeedback();
      expect(syncedCount, 1);
      expect(service.feedbackRecords.first.githubIssueNumber, 9002);
      expect(
        service.feedbackRecords.first.syncStatus,
        EarlyAccessSyncStatus.synced,
      );
    });
  });

  group('EarlyAccessHubPanel', () {
    testWidgets(
      'unlocks flags dynamically from app_metadata and dispatches GitHub feedback',
      (WidgetTester tester) async {
        String tier = 'standard';
        EarlyAccessFeedbackDraft? capturedDraft;
        final EarlyAccessFeatureService service = EarlyAccessFeatureService(
          cacheStore: InMemoryEarlyAccessCacheStore(),
          appMetadataResolver: () => <String, Object?>{
            'early_access_tier': tier,
          },
          issueDispatcher: (EarlyAccessFeedbackDraft draft) async {
            capturedDraft = draft;
            return const GitHubIssueDispatchResult(
              issueNumber: 9123,
              issueUrl: 'https://github.com/kanta13jp1/my_web_app/issues/9123',
              dispatchedToGitHub: true,
            );
          },
        );
        addTearDown(service.dispose);
        await service.loadInitialData();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme:
                  ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A)),
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: EarlyAccessHubPanel(service: service),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('STANDARD'), findsOneWidget);
        final Switch lockedInsiderSwitch = tester.widget<Switch>(
          find.byKey(const ValueKey<String>('flag-switch-ai_voice_macro_v2')),
        );
        expect(lockedInsiderSwitch.onChanged, isNull);

        tier = 'insider';
        final Finder refreshBtn = find.byKey(
          const ValueKey<String>('refresh-tier-button'),
        );
        await tester.ensureVisible(refreshBtn);
        await tester.pumpAndSettle();
        await tester.tap(refreshBtn);
        await tester.pumpAndSettle();

        expect(find.text('INSIDER'), findsOneWidget);
        final Switch unlockedInsiderSwitch = tester.widget<Switch>(
          find.byKey(const ValueKey<String>('flag-switch-ai_voice_macro_v2')),
        );
        expect(unlockedInsiderSwitch.onChanged, isNotNull);

        final Finder selectFeedbackBtn = find.byKey(
          const ValueKey<String>('flag-feedback-btn-ai_voice_macro_v2'),
        );
        await tester.ensureVisible(selectFeedbackBtn);
        await tester.pumpAndSettle();
        await tester.tap(selectFeedbackBtn);
        await tester.pumpAndSettle();

        final Finder titleField = find.byKey(
          const ValueKey<String>('feedback-title-field'),
        );
        await tester.ensureVisible(titleField);
        await tester.pumpAndSettle();
        await tester.enterText(titleField, '音声マクロ v2 の候補表示改善');

        final Finder bodyField = find.byKey(
          const ValueKey<String>('feedback-body-field'),
        );
        await tester.ensureVisible(bodyField);
        await tester.pumpAndSettle();
        await tester.enterText(
          bodyField,
          '音声認識後に生成されるタスク候補を一覧から一括編集できるようにしてほしいです。',
        );

        final Finder submitBtn = find.byKey(
          const ValueKey<String>('feedback-submit-button'),
        );
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(capturedDraft, isNotNull);
        expect(capturedDraft!.flagKey, 'ai_voice_macro_v2');
        expect(capturedDraft!.tier, EarlyAccessTier.insider);
        expect(find.text('Issue #9123'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'passes responsive and WCAG accessibility audit across light/dark modes at 2.0x textScale',
      (WidgetTester tester) async {
        const List<Size> viewports = <Size>[
          Size(320, 568),
          Size(390, 844),
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

            final EarlyAccessFeatureService service = EarlyAccessFeatureService(
              cacheStore: InMemoryEarlyAccessCacheStore(),
              appMetadataResolver: () => const <String, Object?>{
                'early_access_tier': 'supporter',
              },
              issueDispatcher: (EarlyAccessFeedbackDraft draft) async {
                return const GitHubIssueDispatchResult(
                  issueNumber: 9200,
                  issueUrl:
                      'https://github.com/kanta13jp1/my_web_app/issues/9200',
                  dispatchedToGitHub: true,
                );
              },
            );
            await service.loadInitialData();

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
                        child: EarlyAccessHubPanel(service: service),
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
              await expectLater(tester, meetsGuideline(textContrastGuideline));
            } finally {
              semanticsHandle.dispose();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
              service.dispose();
            }
          }
        }
      },
    );
  });
}
