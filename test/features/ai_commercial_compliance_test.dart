import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/ai_commercial_compliance/ai_commercial_compliance_container.dart';
import 'package:my_web_app/features/ai_commercial_compliance/application/ai_commercial_compliance_controller.dart';
import 'package:my_web_app/features/ai_commercial_compliance/data/supabase_ai_commercial_compliance_repository.dart';
import 'package:my_web_app/features/ai_commercial_compliance/domain/ai_commercial_compliance_models.dart';

class _FakeAiComplianceRepository implements AiCommercialComplianceRepository {
  _FakeAiComplianceRepository({
    required this.isAdmin,
    required this.rules,
  });

  final bool isAdmin;
  final List<AiComplianceRule> rules;
  final List<AiCommercialAssetSubmission> submissions =
      <AiCommercialAssetSubmission>[];
  final List<AiComplianceConsentAuditLog> auditLogs =
      <AiComplianceConsentAuditLog>[];

  @override
  Future<AiComplianceDashboardData> fetchDashboardData() async {
    return AiComplianceDashboardData(
      isAdmin: isAdmin,
      rules: List<AiComplianceRule>.from(rules),
      submissions: List<AiCommercialAssetSubmission>.from(submissions),
      auditLogs: List<AiComplianceConsentAuditLog>.from(auditLogs),
    );
  }

  @override
  Future<AiCommercialAssetSubmission> submitComplianceConsent(
    final SubmitCommercialComplianceInput input,
  ) async {
    final AiCommercialAssetSubmission created = AiCommercialAssetSubmission(
      id: 'sub-${submissions.length + 1}',
      assetTitle: input.assetTitle.trim(),
      aiProvider: input.aiProvider,
      planTier: input.planTier,
      commercialLicenseVerified: input.commercialLicenseVerified,
      copyrightNonSimilarityConfirmed: input.copyrightNonSimilarityConfirmed,
      publishStatus: 'cleared',
      createdAt: DateTime.utc(2026, 11, 25, 2, 20),
    );
    submissions.insert(0, created);
    final List<String> keys = rules
        .where(
          (final AiComplianceRule r) => input.acceptedRuleIds.contains(r.id),
        )
        .map((final AiComplianceRule r) => r.ruleKey)
        .toList();
    auditLogs.insert(
      0,
      AiComplianceConsentAuditLog(
        id: 'log-${auditLogs.length + 1}',
        submissionId: created.id,
        userId: 'usr-test-1',
        acceptedRuleKeys: keys,
        consentedAt: DateTime.utc(2026, 11, 25, 2, 20),
      ),
    );
    return created;
  }

  @override
  Future<AiComplianceRule> upsertChecklistRule(
    final UpsertComplianceRuleInput input,
  ) async {
    final AiComplianceRule saved = AiComplianceRule(
      id: 'rule-${rules.length + 1}',
      ruleKey: input.ruleKey.trim().toLowerCase(),
      aiProvider: input.aiProvider,
      title: input.title.trim(),
      disclaimerBody: input.disclaimerBody.trim(),
      isRequired: input.isRequired,
      isActive: input.isActive,
      sortOrder: input.sortOrder,
      termsVersion: input.termsVersion,
    );
    rules.add(saved);
    return saved;
  }
}

class _DelayedAiComplianceRepository
    implements AiCommercialComplianceRepository {
  final Completer<AiComplianceDashboardData> dashboardCompleter =
      Completer<AiComplianceDashboardData>();
  final Completer<AiCommercialAssetSubmission> submitCompleter =
      Completer<AiCommercialAssetSubmission>();
  final Completer<AiComplianceRule> upsertCompleter =
      Completer<AiComplianceRule>();

  @override
  Future<AiComplianceDashboardData> fetchDashboardData() =>
      dashboardCompleter.future;

  @override
  Future<AiCommercialAssetSubmission> submitComplianceConsent(
    final SubmitCommercialComplianceInput input,
  ) =>
      submitCompleter.future;

  @override
  Future<AiComplianceRule> upsertChecklistRule(
    final UpsertComplianceRuleInput input,
  ) =>
      upsertCompleter.future;
}

List<AiComplianceRule> _seedRules() {
  return const <AiComplianceRule>[
    AiComplianceRule(
      id: 'rule-elevenlabs',
      ruleKey: 'elevenlabs_paid_at_generation',
      aiProvider: ComplianceAiProvider.elevenlabs,
      title: 'ElevenLabs 生成時点の有料プラン契約確認',
      disclaimerBody: 'Free プラン生成物および Beta 機能は商用利用不可です。',
      isRequired: true,
      isActive: true,
      sortOrder: 10,
      termsVersion: '2026-11',
    ),
    AiComplianceRule(
      id: 'rule-copyright',
      ruleKey: 'copyright_non_similarity_no_reliance',
      aiProvider: ComplianceAiProvider.general,
      title: '著作権侵害（依拠性・類似性）非該当の確認',
      disclaimerBody: '既存著作物との実質的類似性および依拠性がないことを確認します。',
      isRequired: true,
      isActive: true,
      sortOrder: 30,
      termsVersion: '2026-11',
    ),
  ];
}

void main() {
  group('AiCommercialCompliance domain & controller lifecycle', () {
    test('blocks Free plan tier and incomplete checklist items fail-closed',
        () async {
      final _FakeAiComplianceRepository repo = _FakeAiComplianceRepository(
        isAdmin: false,
        rules: _seedRules(),
      );
      final AiCommercialComplianceController controller =
          AiCommercialComplianceController(repository: repo);
      addTearDown(controller.dispose);
      await controller.loadDashboard();

      controller.setProvider(ComplianceAiProvider.elevenlabs);
      controller.setPlanTier(GenerationPlanTier.free);
      controller.setCommercialLicenseVerified(true);
      controller.setCopyrightNonSimilarityConfirmed(true);
      controller.toggleRuleAcceptance('rule-elevenlabs', true);
      controller.toggleRuleAcceptance('rule-copyright', true);

      expect(controller.state.isReadyToSubmit, isFalse);
      final bool freeBlocked =
          await controller.submitConsent(assetTitle: 'テスト音声');
      expect(freeBlocked, isFalse);
      expect(repo.submissions, isEmpty);

      controller.setPlanTier(GenerationPlanTier.paid);
      controller.toggleRuleAcceptance('rule-copyright', false);
      expect(controller.state.isReadyToSubmit, isFalse);
      final bool partialBlocked =
          await controller.submitConsent(assetTitle: 'テスト音声');
      expect(partialBlocked, isFalse);
      expect(repo.submissions, isEmpty);

      controller.toggleRuleAcceptance('rule-copyright', true);
      expect(controller.state.isReadyToSubmit, isTrue);
      final bool allowed = await controller.submitConsent(assetTitle: '商用紹介音声');
      expect(allowed, isTrue);
      expect(repo.submissions.length, 1);
      expect(repo.auditLogs.length, 1);
      const List<String> expectedKeys = <String>[
        'elevenlabs_paid_at_generation',
        'copyright_non_similarity_no_reliance',
      ];
      expect(repo.auditLogs.first.acceptedRuleKeys, containsAll(expectedKeys));
    });

    test('disposes safely without throwing when Completers complete mid-flight',
        () async {
      final _DelayedAiComplianceRepository delayedRepo =
          _DelayedAiComplianceRepository();
      final AiCommercialComplianceController controller =
          AiCommercialComplianceController(repository: delayedRepo);

      final Future<void> loadFuture = controller.loadDashboard();
      controller.dispose();

      delayedRepo.dashboardCompleter.complete(
        AiComplianceDashboardData(
          isAdmin: false,
          rules: _seedRules(),
          submissions: const <AiCommercialAssetSubmission>[],
          auditLogs: const <AiComplianceConsentAuditLog>[],
        ),
      );
      await loadFuture;
      expect(controller.state.isLoading, isTrue);
    });
  });

  group('AiCommercialComplianceContainer widget & a11y', () {
    Future<void> pumpViewport(
      final WidgetTester tester, {
      required final Size size,
      required final Brightness brightness,
      required final AiCommercialComplianceController controller,
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
                child: AiCommercialComplianceContainer(
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
      'blocks publish until all checkboxes checked, logs consent, and passes Light/Dark a11y',
      (final WidgetTester tester) async {
        final SemanticsHandle semanticsHandle = tester.ensureSemantics();
        final _FakeAiComplianceRepository repo = _FakeAiComplianceRepository(
          isAdmin: false,
          rules: _seedRules(),
        );
        final AiCommercialComplianceController controller =
            AiCommercialComplianceController(repository: repo);

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
            find.byKey(const ValueKey<String>('compliance-admin-editor')),
            findsNothing,
          );

          final Finder submitBtn = find.byKey(
            const ValueKey<String>('compliance-submit-button'),
          );
          await tester.ensureVisible(submitBtn);
          expect(
            tester.widget<FilledButton>(submitBtn).onPressed,
            isNull,
          );

          final Finder commercialSwitch = find.byKey(
            const ValueKey<String>('compliance-commercial-switch'),
          );
          await tester.ensureVisible(commercialSwitch);
          await tester.tap(commercialSwitch);
          await tester.pumpAndSettle();

          final Finder copyrightSwitch = find.byKey(
            const ValueKey<String>('compliance-copyright-switch'),
          );
          await tester.ensureVisible(copyrightSwitch);
          await tester.tap(copyrightSwitch);
          await tester.pumpAndSettle();

          for (final String keyName in const <String>[
            'compliance-rule-checkbox-elevenlabs_paid_at_generation',
            'compliance-rule-checkbox-copyright_non_similarity_no_reliance',
          ]) {
            final Finder cb = find.byKey(ValueKey<String>(keyName));
            await tester.ensureVisible(cb);
            await tester.tap(cb);
            await tester.pumpAndSettle();
          }

          await tester.ensureVisible(submitBtn);
          expect(
            tester.widget<FilledButton>(submitBtn).onPressed,
            isNotNull,
          );
          await tester.tap(submitBtn);
          await tester.pumpAndSettle();

          final Finder clearedBanner = find.byKey(
            const ValueKey<String>('compliance-cleared-banner'),
          );
          await tester.ensureVisible(clearedBanner);
          expect(clearedBanner, findsOneWidget);
          expect(repo.auditLogs.length, 1);

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

          await pumpViewport(
            tester,
            size: const Size(1280, 800),
            brightness: Brightness.dark,
            controller: controller,
          );
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
      },
    );

    testWidgets(
      'allows admin to dynamically add compliance rule without redeploy',
      (final WidgetTester tester) async {
        final SemanticsHandle semanticsHandle = tester.ensureSemantics();
        final _FakeAiComplianceRepository repo = _FakeAiComplianceRepository(
          isAdmin: true,
          rules: _seedRules(),
        );
        final AiCommercialComplianceController controller =
            AiCommercialComplianceController(repository: repo);

        try {
          await controller.loadDashboard();

          await pumpViewport(
            tester,
            size: const Size(1280, 800),
            brightness: Brightness.light,
            controller: controller,
          );

          final Finder adminEditor = find.byKey(
            const ValueKey<String>('compliance-admin-editor'),
          );
          await tester.ensureVisible(adminEditor);
          await tester.pumpAndSettle();
          expect(adminEditor, findsOneWidget);

          final Finder ruleKeyField = find.byKey(
            const ValueKey<String>('admin-rule-key-input'),
          );
          await tester.ensureVisible(ruleKeyField);
          await tester.pumpAndSettle();
          await tester.enterText(ruleKeyField, 'elevenlabs_beta_ban');

          final Finder ruleTitleField = find.byKey(
            const ValueKey<String>('admin-rule-title-input'),
          );
          await tester.ensureVisible(ruleTitleField);
          await tester.pumpAndSettle();
          await tester.enterText(ruleTitleField, 'Beta 音声生成機能の商用除外確認');

          final Finder ruleBodyField = find.byKey(
            const ValueKey<String>('admin-rule-body-input'),
          );
          await tester.ensureVisible(ruleBodyField);
          await tester.pumpAndSettle();
          await tester.enterText(
            ruleBodyField,
            'ElevenLabs Beta 機能は商用本番アセットに含めません。',
          );

          final Finder saveRuleBtn = find.byKey(
            const ValueKey<String>('admin-save-rule-button'),
          );
          await tester.ensureVisible(saveRuleBtn);
          await tester.pumpAndSettle();
          await tester.tap(saveRuleBtn);
          await tester.pumpAndSettle();

          expect(
            repo.rules.any(
              (final AiComplianceRule r) => r.ruleKey == 'elevenlabs_beta_ban',
            ),
            isTrue,
          );
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
