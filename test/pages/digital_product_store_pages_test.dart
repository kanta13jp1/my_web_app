import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/digital_product_store_pages.dart';
import 'package:my_web_app/services/shop_service.dart';

class _FakeShopGateway implements ShopGateway {
  _FakeShopGateway({
    this.products = const [],
    this.purchases = const [],
    this.signedIn = false,
  });

  final List<ShopProduct> products;
  final List<ShopPurchase> purchases;
  final bool signedIn;

  int checkoutCalls = 0;
  int downloadCalls = 0;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<List<ShopProduct>> fetchProducts({ShopProductType? type}) async {
    if (type == null) return products;
    return products.where((product) => product.type == type).toList();
  }

  @override
  Future<ShopProduct?> fetchProduct(String productId) async {
    for (final product in products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  @override
  Future<bool> hasPurchased(String productId) async {
    return purchases.any((purchase) => purchase.product.id == productId);
  }

  @override
  Future<List<ShopPurchase>> fetchPurchases() async => purchases;

  @override
  Future<CheckoutStart> startCheckout(
    String productId, {
    String? visitorId,
    String? source,
  }) async {
    checkoutCalls++;
    return const CheckoutStart.redirect('https://checkout.example/session');
  }

  @override
  Future<DownloadTicket> requestDownloadUrl(String productId) async {
    downloadCalls++;
    return const DownloadTicket(
      url: 'https://storage.example/signed',
      expiresInSeconds: 300,
      version: '1.0',
      sha256: 'abc',
      fileSizeBytes: 1024,
      fileName: 'asset.zip',
    );
  }
}

ShopProduct _product(
  String id,
  String name,
  ShopProductType type, {
  bool purchasable = true,
}) {
  return ShopProduct(
    id: id,
    nameJa: name,
    summaryJa: '$name の概要',
    priceJpy: 800,
    version: '1.0',
    fileSizeBytes: 1024,
    sha256: 'abc',
    isPurchasable: purchasable,
    type: type,
    formatLabel: 'ZIP',
    requirementsJa: '一般的なPC・スマートフォン',
    licenseSummaryJa: '購入者本人のみ利用できます。',
    downloadFileName: '$id.zip',
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(900, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

void main() {
  group('DigitalProductStorePage', () {
    testWidgets('9種別を表示し、選択した種別だけに絞り込む', (tester) async {
      final image = _product('image-pack', '画像素材集', ShopProductType.image);
      final game = _product('game-pack', 'ゲーム本体', ShopProductType.game);
      final gateway = _FakeShopGateway(products: [image, game]);

      await _pump(tester, DigitalProductStorePage(service: gateway));

      for (final type in ShopProductType.values) {
        expect(find.text(type.labelJa), findsAtLeastNWidgets(1));
      }
      expect(find.text('画像素材集'), findsOneWidget);
      expect(find.text('ゲーム本体'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, '画像'));
      await tester.pump();

      expect(find.text('画像素材集'), findsOneWidget);
      expect(find.text('ゲーム本体'), findsNothing);
    });

    testWidgets('狭い画面でも商品カードがオーバーフローしない', (tester) async {
      final gateway = _FakeShopGateway(
        products: [_product('prompt', 'プロンプト集', ShopProductType.prompt)],
      );

      await _pump(
        tester,
        DigitalProductStorePage(service: gateway),
        size: const Size(360, 760),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('プロンプト集'), findsOneWidget);
    });
  });

  group('DigitalProductPage', () {
    testWidgets('ログイン済みなら商品別Checkoutへ進める', (tester) async {
      final product = _product(
        'template-pack',
        '事業計画テンプレート',
        ShopProductType.template,
      );
      final gateway = _FakeShopGateway(products: [product], signedIn: true);
      Uri? launched;
      bool? external;

      await _pump(
        tester,
        DigitalProductPage(
          productId: product.id,
          service: gateway,
          urlLauncher: (uri, isExternal) async {
            launched = uri;
            external = isExternal;
            return true;
          },
        ),
      );

      expect(find.text('¥800 で購入'), findsOneWidget);
      await tester.tap(find.text('¥800 で購入'));
      await tester.pumpAndSettle();

      expect(gateway.checkoutCalls, 1);
      expect(launched, Uri.parse('https://checkout.example/session'));
      expect(external, isFalse);
    });

    testWidgets('決済成功直後は購入ボタンを再表示しない', (tester) async {
      final product = _product('audio', '音声素材', ShopProductType.audio);
      final gateway = _FakeShopGateway(products: [product], signedIn: true);

      await _pump(
        tester,
        DigitalProductPage(
          productId: product.id,
          purchaseResult: 'success',
          service: gateway,
          urlLauncher: (_, __) async => true,
        ),
      );

      expect(find.text('決済を確認しています'), findsOneWidget);
      expect(find.text('¥800 で購入'), findsNothing);
      expect(gateway.checkoutCalls, 0);
    });
  });

  group('ShopDownloadsPage', () {
    testWidgets('未ログインでは購入履歴を見せずログインへ誘導する', (tester) async {
      await _pump(tester, ShopDownloadsPage(service: _FakeShopGateway()));

      expect(find.text('ログインが必要です'), findsOneWidget);
      expect(find.text('ダウンロード'), findsNothing);
    });

    testWidgets('本人の購入済み商品を再ダウンロードできる', (tester) async {
      final product = _product('writing', '文章テンプレート', ShopProductType.writing);
      final purchase = ShopPurchase(
        id: 'purchase-1',
        product: product,
        purchasedAt: DateTime.utc(2026, 8, 20),
      );
      final gateway = _FakeShopGateway(
        products: [product],
        purchases: [purchase],
        signedIn: true,
      );
      bool? external;

      await _pump(
        tester,
        ShopDownloadsPage(
          service: gateway,
          urlLauncher: (_, isExternal) async {
            external = isExternal;
            return true;
          },
        ),
      );

      expect(find.text('文章テンプレート'), findsOneWidget);
      await tester.tap(find.text('ダウンロード'));
      await tester.pumpAndSettle();

      expect(gateway.downloadCalls, 1);
      expect(external, isTrue);
    });
  });
}
