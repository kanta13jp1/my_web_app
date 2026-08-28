import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/shop_service.dart';
import 'package:my_web_app/ui/features/live_commerce/data/live_commerce_gateway.dart';
import 'package:my_web_app/ui/features/live_commerce/domain/live_commerce_models.dart';
import 'package:my_web_app/ui/features/live_commerce/live_commerce_feature.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile preview keeps video before commerce and sends locally', (
    tester,
  ) async {
    await _setViewport(tester, const Size(420, 1000));
    await tester.pumpWidget(
      _app(
        gateway: PreviewLiveCommerceGateway(),
        shopGateway: _FakeShopGateway(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('live-commerce-compact')), findsOneWidget);
    expect(find.byKey(const Key('live-commerce-wide')), findsNothing);
    expect(find.text('プレビュー'), findsOneWidget);
    expect(find.byKey(const Key('live-commerce-video')), findsOneWidget);
    expect(
      find.byKey(const Key('live-commerce-product-overlay')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('live-commerce-host-push')), findsNothing);

    final input = find.byKey(const Key('live-commerce-question-input'));
    await tester.ensureVisible(input);
    await tester.enterText(input, '買い切りですか？');
    await tester.pump();
    final send = find.byKey(const Key('live-commerce-send-question'));
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(find.text('買い切りですか？'), findsOneWidget);
    expect(find.text('あなた（プレビュー）'), findsOneWidget);
    expect(find.textContaining('本番には送信されていません'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop host layout exposes reversible host controls', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1200, 1000));
    await tester.pumpWidget(
      _app(
        gateway: PreviewLiveCommerceGateway(role: LiveCommerceRole.host),
        shopGateway: _FakeShopGateway(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('live-commerce-wide')), findsOneWidget);
    expect(find.byKey(const Key('live-commerce-compact')), findsNothing);
    expect(find.text('配信者モード'), findsOneWidget);
    expect(find.byKey(const Key('live-commerce-host-push')), findsOneWidget);
    expect(find.byTooltip('注目表示を解除'), findsOneWidget);

    await tester.tap(find.byTooltip('注目表示を解除'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('質問を注目表示'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('purchase action opens the existing product route', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1000, 900));
    await tester.pumpWidget(
      _app(
        gateway: PreviewLiveCommerceGateway(),
        shopGateway: _FakeShopGateway(),
        productRoute: const Scaffold(body: Text('既存の商品詳細')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('live-commerce-checkout')));
    await tester.pumpAndSettle();

    expect(find.text('既存の商品詳細'), findsOneWidget);
  });
}

Widget _app({
  required LiveCommerceGateway gateway,
  required ShopGateway shopGateway,
  Widget? productRoute,
}) {
  return MaterialApp(
    onGenerateRoute: (settings) {
      if (settings.name?.startsWith('/shop/product') ?? false) {
        return MaterialPageRoute<void>(
          builder: (_) => productRoute ?? const SizedBox(),
          settings: settings,
        );
      }
      return null;
    },
    home: LiveCommerceFeature(
      gateway: gateway,
      shopGateway: shopGateway,
      initialUri: Uri.parse(
        'https://example.test/live-commerce?room_id=room-1&product_id=product-1',
      ),
    ),
  );
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _FakeShopGateway implements ShopGateway {
  final product = const ShopProduct(
    id: 'product-1',
    nameJa: 'ライブ限定制作キット',
    summaryJa: '制作に使える買い切りのデジタル商品です。',
    priceJpy: 1200,
    version: '1.0.0',
    fileSizeBytes: 1024,
    sha256: 'abc',
    isPurchasable: true,
  );

  @override
  bool get isSignedIn => true;

  @override
  Future<List<ShopProduct>> fetchProducts({ShopProductType? type}) async =>
      <ShopProduct>[product];

  @override
  Future<ShopProduct?> fetchProduct(String productId) async =>
      productId == product.id ? product : null;

  @override
  Future<bool> hasPurchased(String productId) async => false;

  @override
  Future<List<ShopPurchase>> fetchPurchases() async => const <ShopPurchase>[];

  @override
  Future<CheckoutStart> startCheckout(
    String productId, {
    String? visitorId,
    String? source,
  }) async =>
      const CheckoutStart.redirect('https://checkout.example.test');

  @override
  Future<DownloadTicket> requestDownloadUrl(String productId) {
    throw UnimplementedError();
  }
}
