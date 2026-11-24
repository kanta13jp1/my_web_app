import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/external_regulation_tracker_service.dart';
import 'package:my_web_app/widgets/external_regulation_tracker_panel.dart';

Widget _buildTestHarness({
  required ExternalRegulationTrackerService service,
  required Brightness brightness,
}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E40AF),
        brightness: brightness,
      ),
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ExternalRegulationTrackerPanel(service: service),
      ),
    ),
  );
}

void main() {
  group('ExternalRegulationValidator', () {
    test(
      'defaults to pending_fact_check and awaitingFactCheck=true',
      () {
        final ExternalRegulationValidationResult result =
            ExternalRegulationValidator.validate(
          const ExternalRegulationImpactDraft(
            jurisdictionCode: 'cn',
            factorCategory: RegulationFactorCategory.economicEmbargo,
            title: '水産物輸入規制措置の拡大確認',
            affectedProductArea: 'Cross-border Commerce',
            impactLevel: RegulationImpactLevel.high,
            sourceReference: 'https://example.go.jp/official/embargo-notice',
            effectiveDate: '2026-11-24',
            stakeholders: '@supply-lead, qa-owner',
          ),
        );

        expect(result.isValid, isTrue);
        expect(result.normalizedRecord, isNotNull);
        expect(
          result.normalizedRecord!.verificationStatus,
          FactCheckStatus.pendingFactCheck,
        );
        expect(result.normalizedRecord!.awaitingFactCheck, isTrue);
        expect(result.normalizedRecord!.jurisdictionCode, 'CN');
        expect(result.normalizedRecord!.requiresAlertWorkflow, isTrue);
        expect(
          result.normalizedRecord!.stakeholders,
          const <String>['supply-lead', 'qa-owner'],
        );
      },
    );

    test(
      'rejects bad required fields, dates, and flag mismatches',
      () {
        final ExternalRegulationValidationResult result =
            ExternalRegulationValidator.validate(
          const ExternalRegulationImpactDraft(
            jurisdictionCode: 'invalid-123!',
            factorCategory: RegulationFactorCategory.politicalClaim,
            title: '   ',
            affectedProductArea: '',
            impactLevel: RegulationImpactLevel.medium,
            sourceReference: '',
            effectiveDate: '2026-02-30',
            verificationStatus: FactCheckStatus.pendingFactCheck,
            awaitingFactCheck: false,
          ),
        );

        expect(result.isValid, isFalse);
        expect(result.normalizedRecord, isNull);
        expect(result.errors.length, greaterThanOrEqualTo(5));
      },
    );

    test('fromJson preserves pending_fact_check default cleanly', () {
      final ExternalRegulationImpact impact = ExternalRegulationImpact.fromJson(
        const <String, Object?>{
          'id': 'reg-1',
          'jurisdiction_code': 'EU',
          'factor_category': 'regulation',
          'title': 'AI規制ガイドライン改定',
          'affected_product_area': 'Compliance',
          'impact_level': 'low',
          'source_reference': 'EU-REG-2026-11',
        },
      );

      expect(impact.verificationStatus, FactCheckStatus.pendingFactCheck);
      expect(impact.awaitingFactCheck, isTrue);
      expect(impact.requiresAlertWorkflow, isFalse);

      final Map<String, Object?> insertPayload = impact.toInsertPayload('u-1');
      expect(insertPayload['user_id'], 'u-1');
      expect(insertPayload['verification_status'], 'pending_fact_check');
      expect(insertPayload['awaiting_fact_check'], isTrue);

      final Map<String, Object?> dispatchPayload =
          impact.toRepositoryDispatchPayload();
      expect(dispatchPayload['event_type'], 'external-regulation-high-impact');
    });
  });

  group('ExternalRegulationTrackerService & Panel', () {
    test(
      'skips GitHub Actions alert for low impact records',
      () async {
        int dispatchCount = 0;
        final ExternalRegulationTrackerService service =
            ExternalRegulationTrackerService(
          alertDispatcher: (ExternalRegulationImpact impact) async {
            dispatchCount++;
            return const RegulationAlertDispatchResult(
              triggered: true,
              message: 'should not trigger',
            );
          },
        );

        final ExternalRegulationValidationResult result =
            await service.submitImpact(
          const ExternalRegulationImpactDraft(
            jurisdictionCode: 'JP',
            factorCategory: RegulationFactorCategory.regulation,
            title: '表示ガイドライン補足確認',
            affectedProductArea: 'Documentation',
            impactLevel: RegulationImpactLevel.low,
            sourceReference: 'https://example.go.jp/guideline',
          ),
        );

        expect(result.isValid, isTrue);
        expect(dispatchCount, 0);
        expect(service.items.length, 1);
        expect(service.pendingFactCheckCount, 1);
      },
    );

    testWidgets(
      'shows validation errors and escalates high impact records',
      (WidgetTester tester) async {
        final List<ExternalRegulationImpact> dispatched =
            <ExternalRegulationImpact>[];
        final ExternalRegulationTrackerService service =
            ExternalRegulationTrackerService(
          alertDispatcher: (ExternalRegulationImpact impact) async {
            dispatched.add(impact);
            return const RegulationAlertDispatchResult(
              triggered: true,
              message: 'GitHub Actions で通知 Issue を作成しました。',
              issueUrl: 'https://github.com/kanta13jp1/my_web_app/issues/9999',
            );
          },
        );

        await tester.pumpWidget(
          _buildTestHarness(service: service, brightness: Brightness.light),
        );
        await tester.pumpAndSettle();

        final Finder submitButton = find.byKey(
          const ValueKey<String>('regulation-submit-button'),
        );
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('regulation-validation-errors')),
          findsOneWidget,
        );
        expect(dispatched, isEmpty);

        await tester.enterText(
          find.byKey(const ValueKey<String>('regulation-title-field')),
          '輸入停止措置に伴う供給網見直し',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('regulation-product-area-field')),
          'Supply Chain Workflow',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('regulation-source-field')),
          'https://example.go.jp/official/update',
        );

        final Finder highChip = find.byKey(
          const ValueKey<String>('regulation-impact-high'),
        );
        await tester.ensureVisible(highChip);
        await tester.tap(highChip);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('regulation-escalation-preview')),
          findsOneWidget,
        );

        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(dispatched.length, 1);
        expect(dispatched.first.impactLevel, RegulationImpactLevel.high);
        expect(
          dispatched.first.verificationStatus,
          FactCheckStatus.pendingFactCheck,
        );
        expect(find.text('事実確認待ち'), findsWidgets);
        expect(
          find.textContaining(
            'https://github.com/kanta13jp1/my_web_app/issues/9999',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'passes responsive and WCAG guidelines at 2.0x textScale',
      (WidgetTester tester) async {
        const List<Size> viewports = <Size>[Size(390, 844), Size(1280, 800)];
        const List<Brightness> modes = <Brightness>[
          Brightness.light,
          Brightness.dark,
        ];

        for (final Size viewport in viewports) {
          for (final Brightness mode in modes) {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            final ExternalRegulationTrackerService service =
                ExternalRegulationTrackerService(
              initialItems: const <ExternalRegulationImpact>[
                ExternalRegulationImpact(
                  id: 'sample-1',
                  jurisdictionCode: 'CN',
                  factorCategory: RegulationFactorCategory.economicEmbargo,
                  title: '対象品目の輸入停止措置確認',
                  affectedProductArea: 'Supply Chain',
                  impactLevel: RegulationImpactLevel.high,
                  sourceReference: 'https://example.go.jp/official/notice',
                  escalationIssueUrl:
                      'https://github.com/kanta13jp1/my_web_app/issues/2586',
                ),
              ],
            );

            final SemanticsHandle semanticsHandle = tester.ensureSemantics();
            try {
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>('${viewport.width}_${mode.name}'),
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: mode,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFF1E40AF),
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
                        child: ExternalRegulationTrackerPanel(service: service),
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
            }
          }
        }
      },
    );
  });
}
