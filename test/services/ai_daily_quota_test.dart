import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_daily_quota_service.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/widgets/ai_daily_quota_guard_banner.dart';

void main() {
  group('AiDailyQuotaStatus, exception parsing, and block UI (#2699)', () {
    test('parses quota status JSON for free and enterprise tiers', () {
      final freeStatus = AiDailyQuotaStatus.fromJson(<String, dynamic>{
        'plan': 'free',
        'used': 50,
        'daily_limit': 50,
        'remaining': 0,
        'quota_date': '2026-11-24',
        'reset_at': '2026-11-24T15:00:00Z',
        'allowed': false,
      });
      expect(freeStatus.plan, 'free');
      expect(freeStatus.isLimitReached, isTrue);
      expect(freeStatus.usageRatio, 1.0);

      final entStatus = AiDailyQuotaStatus.fromJson(<String, dynamic>{
        'plan': 'enterprise',
        'used': 250,
        'daily_limit': 2000,
        'remaining': 1750,
        'quota_date': '2026-11-24',
        'allowed': true,
      });
      expect(entStatus.plan, 'enterprise');
      expect(entStatus.isLimitReached, isFalse);
      expect(entStatus.remaining, 1750);
    });

    test(
        'AiHubChatService raises AiDailyQuotaExceededException on daily_quota_exceeded payload',
        () async {
      final service = AiHubChatService(
        invoker: (_) async => <String, dynamic>{
          'success': false,
          'status': 'dailyQuotaExceeded',
          'code': 'daily_quota_exceeded',
          'plan': 'free',
          'used': 50,
          'daily_limit': 50,
          'remaining': 0,
          'reset_at': '2026-11-24T15:00:00Z',
          'message': '本日のプラン別 AI 利用上限 (50 回) に達しました。',
        },
      );

      await expectLater(
        () => service.sendProviderChat(message: 'hello'),
        throwsA(isA<AiDailyQuotaExceededException>()),
      );
      AiHubChatQuotaGuard.resetForTesting();
    });

    testWidgets(
      'enables action when remaining > 0 and blocks AI button when daily limit reached',
      (tester) async {
        var executedCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: AiDailyQuotaActionGate(
                  status: const AiDailyQuotaStatus(
                    plan: 'pro',
                    used: 120,
                    dailyLimit: 1000,
                    remaining: 880,
                    quotaDate: '2026-11-24',
                    allowed: true,
                  ),
                  actionLabel: 'AI分析を実行',
                  onExecute: () => executedCount += 1,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('ai_daily_quota_ok_text')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('ai_daily_quota_execute_button')),
        );
        expect(executedCount, 1);

        // Now render exhausted free tier and confirm button is disabled/blocked
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: AiDailyQuotaActionGate(
                  status: const AiDailyQuotaStatus(
                    plan: 'free',
                    used: 50,
                    dailyLimit: 50,
                    remaining: 0,
                    quotaDate: '2026-11-24',
                    allowed: false,
                  ),
                  actionLabel: 'AI分析を実行',
                  onExecute: () => executedCount += 1,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('ai_daily_quota_blocked_text')),
          findsOneWidget,
        );
        final btn = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('ai_daily_quota_execute_button')),
        );
        expect(btn.onPressed, isNull);
        await tester.tap(
          find.byKey(const ValueKey<String>('ai_daily_quota_execute_button')),
          warnIfMissed: false,
        );
        expect(executedCount, 1);
      },
    );

    testWidgets(
      'passes light/dark layout, 2.0x text scaling, and accessibility guidelines',
      (tester) async {
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
                      child: AiDailyQuotaActionGate(
                        status: const AiDailyQuotaStatus(
                          plan: 'free',
                          used: 50,
                          dailyLimit: 50,
                          remaining: 0,
                          quotaDate: '2026-11-24',
                          allowed: false,
                        ),
                        actionLabel: 'AI分析を実行',
                        onExecute: () {},
                        onRefresh: () {},
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
