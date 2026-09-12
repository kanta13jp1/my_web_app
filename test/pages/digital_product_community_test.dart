import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/pages/digital_product_store_pages.dart';
import 'package:my_web_app/services/shop_funnel_service.dart';
import 'package:my_web_app/services/shop_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_shop_community.dart';
import '../widgets/shop_product_community_test.dart' show product, tapText;

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

void main() {
  // Create/dispose the SDK outside testWidgets' fake-async zone. The client's
  // initialization and cleanup use real asynchronous work.
  late Completer<void> attempted;
  final telemetry = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: MockClient((request) async {
      expect(request.url.path, '/functions/v1/shop-funnel');
      if (!attempted.isCompleted) attempted.complete();
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
    attempted = Completer<void>();
    final community = FakeShopCommunity();
    addTearDown(community.sessions.close);
    final store = _Store();
    Uri? downloaded;
    await tester.pumpWidget(
      MaterialApp(
        home: DigitalProductPage(
          productId: product.id,
          service: store,
          funnel: ShopFunnelService(client: telemetry),
          communityRepository: community,
          urlLauncher: (uri, external) async {
            downloaded = uri;
            return true;
          },
        ),
      ),
    );
    // Flush fetchProduct/visitorId continuations before waiting in real async.
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await attempted.future.timeout(const Duration(seconds: 5));
    });
    expect(tester.takeException(), isNull);
    expect(attempted.isCompleted, isTrue);
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
