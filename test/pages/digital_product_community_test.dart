import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/models/shop_community.dart';
import 'package:my_web_app/pages/digital_product_store_pages.dart';
import 'package:my_web_app/services/shop_funnel_service.dart';
import 'package:my_web_app/services/shop_service.dart';
import 'package:my_web_app/services/universal_x_share_service.dart';
import 'package:my_web_app/widgets/universal_ai_share_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_shop_community.dart';
import '../widgets/shop_product_community_test.dart' show product, tapText;

class _ReloadableCommunity extends FakeShopCommunity {
  int reads = 0;

  @override
  Future<List<ShopProductRelease>> releases(String productId) {
    reads++;
    return super.releases(productId);
  }
}

class _Store implements ShopGateway {
  int downloads = 0;
  @override
  bool get isSignedIn => true;
  @override
  Future<List<ShopProduct>> fetchProducts({ShopProductType? type}) async =>
      [product];
  @override
  Future<ShopProduct?> fetchProduct(String id) async => product;
  @override
  Future<bool> hasPurchased(String id) async => true;
  @override
  Future<List<ShopPurchase>> fetchPurchases() async => [];
  @override
  Future<CheckoutStart> startCheckout(
    String id, {
    String? visitorId,
    String? source,
  }) async =>
      const CheckoutStart.alreadyPurchased();
  @override
  Future<DownloadTicket> requestDownloadUrl(String id) async {
    downloads++;
    return const DownloadTicket(
      url: 'https://example.invalid/download',
      expiresInSeconds: 60,
      version: '1.0',
      sha256: 'abc',
      fileSizeBytes: 1024,
      fileName: 'test.zip',
    );
  }
}

// Observe the real service without replacing its storage or HTTP behavior.
// Assertions belong outside record(), which intentionally catches all errors.
class _ObservedFunnel extends ShopFunnelService {
  _ObservedFunnel({required super.client});

  bool started = false;
  bool visitorResolved = false;
  String? visitor;
  final completed = Completer<void>();

  @override
  Future<String?> visitorId() async {
    visitor = await super.visitorId();
    visitorResolved = true;
    return visitor;
  }

  @override
  Future<void> record(
    String stage, {
    required String productId,
    String? source,
    String? campaign,
  }) async {
    started = true;
    try {
      await super.record(
        stage,
        productId: productId,
        source: source,
        campaign: campaign,
      );
    } finally {
      if (!completed.isCompleted) completed.complete();
    }
  }
}

void main() {
  // Create/dispose the SDK outside testWidgets' fake-async zone. The client's
  // initialization and cleanup use real asynchronous work.
  final requests = <http.Request>[];
  final telemetry = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(
        '{"error":"fixture-telemetry-outage"}',
        503,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  tearDownAll(telemetry.dispose);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('telemetry outage preserves review saving and owned download',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    requests.clear();
    final funnel = _ObservedFunnel(client: telemetry);
    final community = FakeShopCommunity();
    addTearDown(community.sessions.close);
    final store = _Store();
    Uri? downloaded;
    await tester.pumpWidget(
      MaterialApp(
        home: DigitalProductPage(
          productId: product.id,
          service: store,
          funnel: funnel,
          communityRepository: community,
          urlLauncher: (uri, external) async {
            downloaded = uri;
            return true;
          },
        ),
      ),
    );
    // The SDK crosses native-isolate and fake-async continuations. Waiting
    // only in runAsync starves the latter even after HTTP responds. Yield real
    // work AND pump fake microtasks until the real service handles the 503.
    final deadline = Stopwatch()..start();
    while (!funnel.completed.isCompleted) {
      if (deadline.elapsed >= const Duration(seconds: 5)) {
        fail(
          'Telemetry stalled: started=${funnel.started}, '
          'visitorResolved=${funnel.visitorResolved}, '
          'visitorPresent=${funnel.visitor != null}, '
          'httpRequests=${requests.length}',
        );
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    deadline.stop();
    expect(tester.takeException(), isNull);
    expect(funnel.started, isTrue);
    expect(funnel.visitorResolved, isTrue);
    expect(funnel.visitor, isNotNull);
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/functions/v1/shop-funnel');
    expect(requests.single.method, 'POST');
    expect(jsonDecode(requests.single.body), {
      'visitor_id': funnel.visitor,
      'product_id': product.id,
      'stage': ShopFunnelService.stageProductView,
      'source': 'direct',
      'campaign': '',
    });
    await tester.pumpAndSettle();
    expect(find.text('配布版 v1.0'), findsOneWidget);
    await tapText(tester, '口コミ・評価を書く');
    await tester.tap(find.byKey(const ValueKey('review-star-4')));
    await tester.enterText(
      find.byKey(const ValueKey('review-body')),
      '表示検証用の架空口コミ',
    );
    await tapText(tester, '公開して保存');
    expect(community.saves, 1);
    expect(community.saved?.rating, 4);
    expect(community.saved?.body, '表示検証用の架空口コミ');
    expect(find.text('表示検証用の架空口コミ'), findsOneWidget);
    await tapText(tester, 'ダウンロード');
    expect(store.downloads, 1);
    expect(downloaded, Uri.parse('https://example.invalid/download'));
    expect(tester.takeException(), isNull);
  });

  for (final width in [1040.0, 360.0]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('footer clears real overlay at $width with scale $textScale',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previousPage = universalAiShareRouteObserver.currentPage.value;
        universalAiShareRouteObserver.currentPage.value =
            UniversalSharePageContext.fromRouteName('/shop/product');
        addTearDown(() {
          universalAiShareRouteObserver.currentPage.value = previousPage;
        });
        final community = _ReloadableCommunity();
        addTearDown(community.sessions.close);
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                padding: const EdgeInsets.only(bottom: 24),
                viewPadding: const EdgeInsets.only(bottom: 24),
              ),
              child: UniversalAiShareShell(
                navigatorKey: navigatorKey,
                isLoggedInOverride: true,
                child: child!,
              ),
            ),
            home: DigitalProductPage(
              productId: product.id,
              service: _Store(),
              communityRepository: community,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scroll = find.descendant(
          of: find.byKey(const ValueKey('product-detail-scroll')),
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scroll).position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        final reload = find.widgetWithText(
          TextButton,
          '更新情報と口コミを再読み込み',
        );
        final inbox = find.byKey(const Key('universal_inbox_capture_button'));
        expect(inbox, findsOneWidget);
        expect(reload.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(reload).bottom,
          lessThan(tester.getRect(inbox).top),
        );
        if (width >= kAiShareFabMinScreenWidth) {
          final share = find.byTooltip('AIシェア');
          expect(share, findsOneWidget);
          expect(
            tester.getRect(reload).bottom,
            lessThan(tester.getRect(share).top),
          );
        }
        final before = community.reads;
        await tester.tap(reload);
        await tester.pumpAndSettle();
        expect(community.reads, before + 1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('version and section navigation preserve downloads at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final community = FakeShopCommunity();
      addTearDown(community.sessions.close);
      final store = _Store();
      Uri? downloadUrl;
      await tester.pumpWidget(
        MaterialApp(
          home: DigitalProductPage(
            productId: product.id,
            service: store,
            communityRepository: community,
            urlLauncher: (uri, external) async {
              downloadUrl = uri;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('配布版 v1.0'), findsOneWidget);
      final reviews = find.byKey(const ValueKey('product-reviews-link'));
      await tester.ensureVisible(reviews);
      await tester.tap(reviews);
      await tester.pumpAndSettle();
      expect(find.text('評価はまだありません（0件）').hitTestable(), findsOneWidget);
      final download = find.text('ダウンロード');
      await tester.ensureVisible(download);
      await tester.pumpAndSettle();
      await tester.tap(download);
      await tester.pumpAndSettle();
      expect(store.downloads, 1);
      expect(downloadUrl, Uri.parse('https://example.invalid/download'));
      expect(tester.takeException(), isNull);
    });
  }
}
