import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/digital_product_store_pages.dart';
import 'package:my_web_app/services/shop_service.dart';

import '../support/fake_shop_community.dart';
import '../widgets/shop_product_community_test.dart' show product;

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
