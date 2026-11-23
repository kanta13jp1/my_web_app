import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/price_tracker_page.dart';
import 'package:my_web_app/services/price_advice_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _sampleProduct({
  String id = 'prod-1',
  String name = 'ロジクール MX Master 3S',
  int currentPrice = 16500,
  int targetPrice = 13800,
  int lowestPrice = 13200,
  int highestPrice = 16800,
}) {
  return <String, dynamic>{
    'id': id,
    'product_name': name,
    'store_domain': 'amazon.co.jp',
    'current_price': currentPrice,
    'target_price': targetPrice,
    'lowest_price': lowestPrice,
    'highest_price': highestPrice,
  };
}

Map<String, dynamic> _waitResponsePayload({
  int currentPrice = 16500,
  int targetPrice = 13800,
  String summary = '直近3件の観測平均より高く推移しているため待機推奨です。',
  String source = 'llm',
}) {
  return <String, dynamic>{
    'success': true,
    'verdict': 'wait',
    'verdict_label': '⏳ 待機推奨',
    'summary': summary,
    'reasons': <String>[
      '直近の観測価格が平均 ¥14,800 を上回っています',
      '目標価格 ¥13,800 より +19.6% 高い状態です',
    ],
    'stats': <String, dynamic>{
      'sample_count': 4,
      'current_price': currentPrice,
      'target_price': targetPrice,
      'min_price': 13200,
      'max_price': 16800,
      'avg_price': 14800,
      'recent_delta_pct': 11.5,
      'delta_from_avg_pct': 11.5,
      'delta_from_target_pct': 19.6,
      'is_at_or_below_target': false,
    },
    'grounded_on_observed_logs_only': true,
    'source': source,
    'cache_ttl_hours': 24,
    'model': 'groq:llama-3.3-70b',
  };
}

void main() {
  group('PriceAdviceCacheService (#1385)', () {
    test('caches structured advice for 24h and hits cache on subsequent reads',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var now = DateTime.utc(2026, 11, 24, 6, 0);
      var invokeCount = 0;

      final service = PriceAdviceCacheService(
        clock: () => now,
        invoker: (productId) async {
          invokeCount++;
          return _waitResponsePayload();
        },
      );

      final product = _sampleProduct();
      final first = await service.getAdvice(product: product);
      expect(invokeCount, 1);
      expect(first.fromCache, isFalse);
      expect(first.verdict, PriceAdviceVerdict.wait);
      expect(first.verdictLabel, '⏳ 待機推奨');
      expect(first.stats.avgPrice, 14800);
      expect(first.groundedOnObservedLogsOnly, isTrue);

      now = now.add(const Duration(hours: 12));
      final second = await service.getAdvice(product: product);
      expect(invokeCount, 1);
      expect(second.fromCache, isTrue);
      expect(second.summary, first.summary);

      // Expires after 24h.
      now = now.add(const Duration(hours: 13));
      final third = await service.getAdvice(product: product);
      expect(invokeCount, 2);
      expect(third.fromCache, isFalse);
    });

    test('invalidates cache on price change or forceRefresh', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final now = DateTime.utc(2026, 11, 24, 6, 0);
      var invokeCount = 0;

      final service = PriceAdviceCacheService(
        clock: () => now,
        invoker: (productId) async {
          invokeCount++;
          return _waitResponsePayload(
            currentPrice: invokeCount == 1 ? 16500 : 13500,
          );
        },
      );

      await service.getAdvice(product: _sampleProduct(currentPrice: 16500));
      expect(invokeCount, 1);

      final forced = await service.getAdvice(
        product: _sampleProduct(currentPrice: 16500),
        forceRefresh: true,
      );
      expect(invokeCount, 2);
      expect(forced.fromCache, isFalse);

      final priceChanged = await service.getAdvice(
        product: _sampleProduct(currentPrice: 13400),
      );
      expect(invokeCount, 3);
      expect(priceChanged.fromCache, isFalse);
    });

    test('fails open on corrupted JSON and supports legacy plain advice map',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        '${PriceAdviceCacheService.cacheKeyPrefix}prod-legacy': '{corrupt-json',
      });
      var invokeCount = 0;
      final service = PriceAdviceCacheService(
        invoker: (productId) async {
          invokeCount++;
          return <String, dynamic>{
            'success': true,
            'advice': '🎯 買い時: 観測履歴で最安値に到達しています。',
            'model': 'groq:llama-3.3-70b',
          };
        },
      );

      final res = await service.getAdvice(
        product: _sampleProduct(id: 'prod-legacy'),
      );
      expect(invokeCount, 1);
      expect(res.verdict, PriceAdviceVerdict.buy);
      expect(res.verdictLabel, '🎯 買い時');
      expect(res.summary, contains('最安値'));
    });
  });

  group('PriceTrackerPage AI advice UI & accessibility (#1385)', () {
    testWidgets(
        'displays structured advice, updates card cache badge, and refreshes',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var invokeCount = 0;
      final service = PriceAdviceCacheService(
        invoker: (productId) async {
          invokeCount++;
          return _waitResponsePayload(
            summary: invokeCount == 1
                ? '直近価格が観測平均を上回るため待機推奨です。'
                : '最新ログを含めて再評価しました。',
            source: invokeCount == 1 ? 'llm' : 'statistical_fallback',
          );
        },
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: PriceTrackerPage(
            adviceService: service,
            initialProducts: <Map<String, dynamic>>[_sampleProduct()],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('price_advice_button_prod-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('price_advice_verdict_badge')),
        findsOneWidget,
      );
      expect(find.text('⏳ 待機推奨'), findsOneWidget);
      expect(find.text('直近価格が観測平均を上回るため待機推奨です。'), findsOneWidget);
      expect(find.text('実測ログ統計のみで算出 (未観測セール・在庫推測なし)'), findsOneWidget);
      expect(invokeCount, 1);

      // Force refresh inside sheet
      await tester.tap(
        find.byKey(const ValueKey<String>('price_advice_refresh_button')),
      );
      await tester.pumpAndSettle();
      expect(invokeCount, 2);
      expect(find.text('最新ログを含めて再評価しました。'), findsOneWidget);
      expect(find.text('統計フォールバック'), findsOneWidget);

      // Close sheet and confirm product card displays cached verdict banner
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('price_card_advice_prod-1')),
        findsOneWidget,
      );
      expect(find.text('24hキャッシュ'), findsOneWidget);

      // Re-open hits 24h cache without extra invocation
      await tester.tap(
        find.byKey(const ValueKey<String>('price_advice_button_prod-1')),
      );
      await tester.pumpAndSettle();
      expect(invokeCount, 2);
    });

    testWidgets(
        'supports mobile/desktop at 2.0x scale in light/dark themes and passes semantics guidelines',
        (tester) async {
      final configs = <(Size, ThemeData)>[
        (const Size(390, 844), ThemeData.dark()),
        (const Size(1280, 800), ThemeData.light()),
      ];
      for (final (viewport, theme) in configs) {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final service = PriceAdviceCacheService(
          invoker: (productId) async => _waitResponsePayload(),
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
                child: PriceTrackerPage(
                  adviceService: service,
                  initialProducts: <Map<String, dynamic>>[_sampleProduct()],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final adviceButton = find.byKey(
            const ValueKey<String>('price_advice_button_prod-1'),
          );
          await tester.ensureVisible(adviceButton);
          await tester.tap(adviceButton);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

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
