import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/offline_secure_mode_settings_service.dart';
import 'package:my_web_app/widgets/ai_compliance_guardrail_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AiHubChatQuotaGuard.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('AiHubChatService compliance guardrails (#2736)', () {
    test('throws AiComplianceGuardrailException when input is blocked',
        () async {
      final service = AiHubChatService(
        offlineSettingsService: const OfflineSecureModeSettingsService(),
        invoker: (body) async => <String, dynamic>{
          'success': false,
          'status': 'guardrailBlocked',
          'code': 'compliance_guardrail_blocked',
          'stage': 'input',
          'categories': <String>['pii_credit_card', 'pii_credential'],
          'trace_id': 'trace-guard-001',
          'message': '入力プロンプトに保護対象の個人情報・認証情報が含まれるためブロックしました。',
        },
      );

      expect(
        () => service.sendProviderChat(message: 'masked test request'),
        throwsA(
          isA<AiComplianceGuardrailException>()
              .having((e) => e.stage, 'stage', 'input')
              .having(
                (e) => e.categories,
                'categories',
                containsAll(<String>['pii_credit_card', 'pii_credential']),
              )
              .having((e) => e.traceId, 'traceId', 'trace-guard-001')
              .having(
                (e) => e.categoryLabels,
                'categoryLabels',
                containsAll(<String>['クレジットカード番号', '認証キー/秘密情報']),
              ),
        ),
      );
    });

    test('throws AiComplianceGuardrailException when output is blocked',
        () async {
      final service = AiHubChatService(
        invoker: (body) async => <String, dynamic>{
          'success': false,
          'status': 'guardrailBlocked',
          'code': 'compliance_guardrail_blocked',
          'stage': 'output',
          'categories': <String>['toxic_cyber_abuse'],
          'trace_id': 'trace-guard-002',
          'message': 'AI応答に安全ガイドライン違反が検出されたためブロックしました。',
        },
      );

      expect(
        () => service.sendProviderChat(message: 'test prompt'),
        throwsA(
          isA<AiComplianceGuardrailException>()
              .having((e) => e.stage, 'stage', 'output')
              .having(
                (e) => e.categoryLabels,
                'categoryLabels',
                contains('サイバー攻撃/不正利用'),
              ),
        ),
      );
    });
  });

  group('AiComplianceGuardrailAlert widget & a11y (#2736)', () {
    testWidgets(
        'renders stage/categories/trace and passes 2.0x light/dark accessibility checks',
        (tester) async {
      final configs = <(Size, ThemeData)>[
        (const Size(390, 844), ThemeData.light()),
        (const Size(1280, 800), ThemeData.dark()),
      ];
      for (final (viewport, theme) in configs) {
        var edited = false;
        var dismissed = false;
        const exception = AiComplianceGuardrailException(
          stage: 'output',
          categories: <String>['pii_my_number', 'toxic_violence'],
          traceId: 'trace-audit-42',
          userMessage: '保護対象データまたは有害表現が検出されたため出力を停止しました。',
        );
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
                    child: AiComplianceGuardrailAlert(
                      exception: exception,
                      onEditPrompt: () => edited = true,
                      onDismiss: () => dismissed = true,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey<String>('ai_compliance_guardrail_alert')),
            findsOneWidget,
          );
          expect(find.text('AI出力チェックで検出'), findsOneWidget);
          expect(find.text('マイナンバー'), findsOneWidget);
          expect(find.text('暴力的表現/危険物作成'), findsOneWidget);
          expect(find.text('監査トレースID: trace-audit-42'), findsOneWidget);

          await tester.tap(
            find.byKey(
                const ValueKey<String>('ai_compliance_edit_prompt_button')),
          );
          await tester.tap(
            find.byKey(const ValueKey<String>('ai_compliance_dismiss_button')),
          );
          expect(edited, isTrue);
          expect(dismissed, isTrue);

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        } finally {
          handle.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      }
    });
  });
}
