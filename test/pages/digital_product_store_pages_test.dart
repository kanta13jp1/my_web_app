import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/pages/digital_product_store_pages.dart';
import 'package:my_web_app/services/shop_service.dart';
import 'package:my_web_app/theme/design_tokens.dart';

class _FakeShopGateway implements ShopGateway {
  _FakeShopGateway({
    this.products = const [],
    this.purchases = const [],
    this.signedIn = false,
    this.pendingProduct,
    this.pendingCheckout,
    this.productError,
    this.checkoutError,
    this.downloadError,
  });

  final List<ShopProduct> products;
  final List<ShopPurchase> purchases;
  final bool signedIn;
  final Completer<ShopProduct?>? pendingProduct;
  final Completer<CheckoutStart>? pendingCheckout;
  Object? productError;
  Object? checkoutError;
  Object? downloadError;

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
    if (productError != null) throw productError!;
    if (pendingProduct != null) return pendingProduct!.future;
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
    if (checkoutError != null) throw checkoutError!;
    if (pendingCheckout != null) return pendingCheckout!.future;
    return const CheckoutStart.redirect('https://checkout.example/session');
  }

  @override
  Future<DownloadTicket> requestDownloadUrl(String productId) async {
    downloadCalls++;
    if (downloadError != null) throw downloadError!;
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

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
}

void _expectButtonContrast(WidgetTester tester, String label) {
  final finder = _filledButtonWithText(label);
  final button = tester.widget<FilledButton>(finder);
  final states = <WidgetState>{
    if (button.onPressed == null) WidgetState.disabled,
  };
  final background = button.style!.backgroundColor!.resolve(states)!;
  final text = tester.widget<RichText>(
    find.descendant(of: find.text(label), matching: find.byType(RichText)),
  );
  expect(
    _contrast(text.text.style!.color!, background),
    greaterThanOrEqualTo(4.5),
  );
}

Finder _filledButtonWithText(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is FilledButton),
  );
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
    testWidgets('loading is announced and cleared on completion',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final pending = Completer<ShopProduct?>();
        await tester.pumpWidget(
          MaterialApp(
            home: DigitalProductPage(
              productId: 'fixture',
              service: _FakeShopGateway(pendingProduct: pending),
            ),
          ),
        );
        await tester.pump();

        expect(find.bySemanticsLabel('商品情報を読み込み中'), findsOneWidget);
        final loading = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == '商品情報を読み込み中',
          ),
        );
        expect(loading.properties.liveRegion, isTrue);
        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.color, DesignTokens.orange);
        expect(
          _contrast(indicator.color!, DesignTokens.background),
          greaterThanOrEqualTo(3),
        );
        pending.complete(null);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('商品情報を読み込み中'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('product title remains legible with a light app bar theme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            appBarTheme: const AppBarTheme(
              titleTextStyle: TextStyle(color: Colors.black),
            ),
          ),
          home: DigitalProductPage(
            productId: 'fixture',
            service: _FakeShopGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final titleText = tester.widget<RichText>(
        find.descendant(
          of: find.text('デジタル商品'),
          matching: find.byType(RichText),
        ),
      );
      expect(titleText.text.style!.color, DesignTokens.textPrimary);
      final contrast = (DesignTokens.textPrimary.computeLuminance() + 0.05) /
          (DesignTokens.surface1.computeLuminance() + 0.05);
      expect(contrast, greaterThanOrEqualTo(4.5));
    });

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
      _expectButtonContrast(tester, '¥800 で購入');
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
      expect(find.textContaining('お支払いは完了しています'), findsNothing);
      expect(find.text('¥800 で購入'), findsNothing);
      expect(gateway.checkoutCalls, 0);
    });

    testWidgets('guest purchase action has readable text', (tester) async {
      final product = _product('writing', '文章素材', ShopProductType.writing);
      await _pump(
        tester,
        DigitalProductPage(
          productId: product.id,
          service: _FakeShopGateway(products: [product]),
        ),
      );
      _expectButtonContrast(tester, 'ログインして購入');
    });

    testWidgets('working checkout remains readable and prevents another press',
        (tester) async {
      final product = _product('writing', '文章素材', ShopProductType.writing);
      final pending = Completer<CheckoutStart>();
      final gateway = _FakeShopGateway(
        products: [product],
        signedIn: true,
        pendingCheckout: pending,
      );
      await _pump(
        tester,
        DigitalProductPage(
          productId: product.id,
          service: gateway,
          urlLauncher: (_, __) async => true,
        ),
      );
      await tester.tap(find.text('¥800 で購入'));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        _filledButtonWithText('手続き中…'),
      );
      expect(button.onPressed, isNull);
      _expectButtonContrast(tester, '手続き中…');
      await tester.tap(find.text('手続き中…'));
      await tester.pump();
      expect(gateway.checkoutCalls, 1);
      pending.complete(const CheckoutStart.redirect('https://checkout.example'));
      await tester.pumpAndSettle();
      expect(find.text('手続き中…'), findsNothing);
    });

    testWidgets('product error hides internal details and retry recovers',
        (tester) async {
      final product = _product('writing', '文章素材', ShopProductType.writing);
      final gateway = _FakeShopGateway(
        products: [product],
        productError: StateError('private_table token=fixture-secret'),
      );
      await _pump(
        tester,
        DigitalProductPage(productId: product.id, service: gateway),
      );
      expect(find.text('商品情報を読み込めませんでした'), findsOneWidget);
      expect(find.textContaining('通信状況を確認して'), findsOneWidget);
      expect(find.textContaining('private_table'), findsNothing);
      expect(find.textContaining('fixture-secret'), findsNothing);
      gateway.productError = null;
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(find.text(product.nameJa), findsOneWidget);
      expect(find.text('商品情報を読み込めませんでした'), findsNothing);
    });

    testWidgets('checkout error gives safe recovery guidance and can retry',
        (tester) async {
      final product = _product('writing', '文章素材', ShopProductType.writing);
      final gateway = _FakeShopGateway(
        products: [product],
        signedIn: true,
        checkoutError: StateError('FunctionException fixture-secret'),
      );
      Uri? launched;
      await _pump(
        tester,
        DigitalProductPage(
          productId: product.id,
          service: gateway,
          urlLauncher: (uri, _) async {
            launched = uri;
            return true;
          },
        ),
      );
      await tester.tap(find.text('¥800 で購入'));
      await tester.pumpAndSettle();
      expect(find.text('購入手続きを開始できませんでした'), findsOneWidget);
      expect(find.textContaining('先に「購入済み」'), findsOneWidget);
      expect(find.textContaining('fixture-secret'), findsNothing);
      expect(find.textContaining('FunctionException'), findsNothing);
      expect(launched, isNull);
      gateway.checkoutError = null;
      await tester.ensureVisible(find.text('¥800 で購入'));
      await tester.tap(find.text('¥800 で購入'));
      await tester.pumpAndSettle();
      expect(gateway.checkoutCalls, 2);
      expect(launched, Uri.parse('https://checkout.example/session'));
      expect(find.text('購入手続きを開始できませんでした'), findsNothing);
    });

    testWidgets('download error explains retry without offering repurchase',
        (tester) async {
      final product = _product('writing', '文章素材', ShopProductType.writing);
      final gateway = _FakeShopGateway(
        products: [product],
        purchases: [
          ShopPurchase(
            id: 'fixture-purchase',
            product: product,
            purchasedAt: DateTime.utc(2026, 8, 20),
          ),
        ],
        signedIn: true,
        downloadError: StateError('signed_url fixture-secret'),
      );
      await _pump(
        tester,
        DigitalProductPage(productId: product.id, service: gateway),
      );
      _expectButtonContrast(tester, 'ダウンロード');
      await tester.tap(find.text('ダウンロード'));
      await tester.pumpAndSettle();
      expect(find.text('ダウンロードを準備できませんでした'), findsOneWidget);
      expect(find.textContaining('再購入は不要です'), findsOneWidget);
      expect(find.textContaining('fixture-secret'), findsNothing);
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
