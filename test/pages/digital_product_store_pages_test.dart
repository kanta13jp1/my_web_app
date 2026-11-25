import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/pages/digital_product_store_pages.dart';
import 'package:my_web_app/services/shop_funnel_service.dart';
import 'package:my_web_app/services/shop_service.dart';

typedef _FunnelCall = ({
  String stage,
  String productId,
  String? source,
  String? campaign,
});

class _RecordingShopFunnelService extends ShopFunnelService {
  final List<_FunnelCall> calls = [];

  @override
  Future<String?> visitorId() async => 'visitor-test-1';

  @override
  Future<void> record(
    String stage, {
    required String productId,
    String? source,
    String? campaign,
  }) async {
    calls.add((
      stage: stage,
      productId: productId,
      source: source,
      campaign: campaign,
    ));
  }
}

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
  String? lastCheckoutSource;

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
    lastCheckoutSource = source;
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  group('UTM attribution route propagation', () {
    test(
      'buildShopProductRoute keeps utm params and drops unrelated params',
      () {
        final route = buildShopProductRoute(
          'hexciv-win64',
          Uri.parse(
            '/shop?utm_source=x&utm_campaign=h4_h7_pitch'
            '&utm_content=growth_game_t30_r1&ref=ignored&utm_medium= ',
          ),
        );
        final parsed = Uri.parse(route);
        expect(parsed.path, '/shop/product');
        expect(parsed.queryParameters, <String, String>{
          'product_id': 'hexciv-win64',
          'utm_source': 'x',
          'utm_campaign': 'h4_h7_pitch',
          'utm_content': 'growth_game_t30_r1',
        });
      },
    );

    testWidgets(
      'DigitalProductStorePage forwards UTM parameters to product route',
      (tester) async {
        final product = _product(
          'hexciv-win64',
          'HexCiv (Windows 版)',
          ShopProductType.game,
        );
        final gateway = _FakeShopGateway(products: [product]);
        final pushedRoutes = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            initialRoute:
                '/shop?utm_source=verify_pr5388&utm_campaign=p1_20261125',
            onGenerateRoute: (settings) {
              final uri = Uri.parse(settings.name ?? '/shop');
              if (uri.path == '/shop/product') {
                pushedRoutes.add(settings.name ?? '');
                return MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('DETAIL')),
                  settings: settings,
                );
              }
              return MaterialPageRoute(
                builder: (_) => DigitalProductStorePage(
                  service: gateway,
                  attributionUri: uri,
                ),
                settings: settings,
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('HexCiv (Windows 版)'));
        await tester.pumpAndSettle();

        expect(pushedRoutes, hasLength(1));
        final target = Uri.parse(pushedRoutes.single);
        expect(target.path, '/shop/product');
        expect(target.queryParameters['product_id'], 'hexciv-win64');
        expect(target.queryParameters['utm_source'], 'verify_pr5388');
        expect(target.queryParameters['utm_campaign'], 'p1_20261125');
      },
    );

    testWidgets(
      'DigitalProductPage records source and campaign from attributionUri',
      (tester) async {
        final product = _product(
          'hexciv-win64',
          'HexCiv (Windows 版)',
          ShopProductType.game,
        );
        final gateway = _FakeShopGateway(products: [product], signedIn: true);
        final funnel = _RecordingShopFunnelService();

        await _pump(
          tester,
          DigitalProductPage(
            productId: product.id,
            service: gateway,
            funnel: funnel,
            attributionUri: Uri.parse(
              '/shop/product?product_id=hexciv-win64'
              '&utm_source=x&utm_campaign=h4_h7_pitch',
            ),
            urlLauncher: (_, __) async => true,
          ),
        );

        expect(funnel.calls, hasLength(1));
        expect(funnel.calls.single.stage, ShopFunnelService.stageProductView);
        expect(funnel.calls.single.source, 'x');
        expect(funnel.calls.single.campaign, 'h4_h7_pitch');

        await tester.tap(find.text('¥800 で購入'));
        await tester.pumpAndSettle();

        expect(gateway.lastCheckoutSource, 'x');
      },
    );
  });
}
