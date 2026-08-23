import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/hexciv_shop_page.dart';
import 'package:my_web_app/services/shop_service.dart';

/// HexCiv 商品ページの状態別の描き分けを固定する (2026-07-28 追加)。
///
/// 検証の主眼は**「買えるように見えて買えない」状態を作らないこと**。
/// 決済に関わる画面なので、どの状態でどの導線が出るかは実装の都合で
/// 揺らいでよい部分ではない。
///
/// Supabase を触らせないため、画面は `ShopGateway` にだけ依存させてある。
class _FakeGateway implements ShopGateway {
  _FakeGateway({
    this.product,
    this.purchased = false,
    this.signedIn = false,
    this.fetchError,
  });

  final ShopProduct? product;
  final bool purchased;
  final bool signedIn;
  final Exception? fetchError;

  int startCheckoutCalls = 0;
  int downloadCalls = 0;

  /// funnel の最終段を webhook 側で書くために渡される値。
  String? lastVisitorId;
  String? lastSource;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<List<ShopProduct>> fetchProducts({ShopProductType? type}) async {
    final value = product;
    if (value == null || (type != null && value.type != type)) return const [];
    return [value];
  }

  @override
  Future<ShopProduct?> fetchProduct(String productId) async {
    if (fetchError != null) throw fetchError!;
    return product;
  }

  @override
  Future<bool> hasPurchased(String productId) async => purchased;

  @override
  Future<List<ShopPurchase>> fetchPurchases() async => const [];

  @override
  Future<CheckoutStart> startCheckout(
    String productId, {
    String? visitorId,
    String? source,
  }) async {
    startCheckoutCalls++;
    lastVisitorId = visitorId;
    lastSource = source;
    return const CheckoutStart.redirect('https://checkout.example/session');
  }

  @override
  Future<DownloadTicket> requestDownloadUrl(String productId) async {
    downloadCalls++;
    return const DownloadTicket(
      url: 'https://storage.example/signed',
      expiresInSeconds: 300,
      version: '1.0',
      sha256: 'cc0e5caa',
      fileSizeBytes: 37572177,
      fileName: 'HexCiv-v1.0-win64.zip',
    );
  }
}

ShopProduct _product({bool purchasable = true}) => ShopProduct(
      id: 'hexciv-win64',
      nameJa: 'HexCiv (Windows 版)',
      summaryJa: '4X ストラテジー。',
      priceJpy: 500,
      version: '1.0',
      fileSizeBytes: 37572177,
      sha256:
          'cc0e5caae732fa123d26ed62c1827a923c4ccd777823190ed714ba178e97ed93',
      isPurchasable: purchasable,
      requirementsJa: 'Windows 10 / 11 (64bit)',
      formatLabel: 'Windows / ZIP',
      downloadFileName: 'HexCiv-v1.0-win64.zip',
    );

Future<void> _pump(
  WidgetTester tester,
  _FakeGateway gateway, {
  String? purchaseResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HexcivShopPage(
        service: gateway,
        purchaseResult: purchaseResult,
        urlLauncher: (_, __) async => true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('HexcivShopPage の状態別の描き分け', () {
    testWidgets('商品が取れないときは購入導線を出さず準備中と伝える', (tester) async {
      // RLS により is_active=false の商品は読めない。準備中と未存在は同じ扱い。
      await _pump(tester, _FakeGateway(product: null));

      expect(find.text('準備中です'), findsOneWidget);
      expect(find.textContaining('で購入'), findsNothing);
      expect(find.text('ダウンロード'), findsNothing);
    });

    testWidgets('Stripe の Price 未設定なら購入ボタンを出さない', (tester) async {
      // ここで購入ボタンを出すと、押した先で必ず失敗する。
      await _pump(
        tester,
        _FakeGateway(product: _product(purchasable: false), signedIn: true),
      );

      expect(find.text('販売準備中です'), findsOneWidget);
      expect(find.textContaining('で購入'), findsNothing);
    });

    testWidgets('未ログインなら購入ではなくログインへ誘導する', (tester) async {
      await _pump(tester, _FakeGateway(product: _product()));

      expect(find.text('ログインして購入'), findsOneWidget);
      expect(find.text('¥500 で購入'), findsNothing);
    });

    testWidgets('ログイン済み・未購入なら価格つきの購入ボタンを出す', (tester) async {
      final gateway = _FakeGateway(product: _product(), signedIn: true);
      await _pump(tester, gateway);

      expect(find.text('¥500 で購入'), findsOneWidget);
      expect(find.text('ダウンロード'), findsNothing);

      await tester.ensureVisible(find.text('¥500 で購入'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('¥500 で購入'));
      await tester.pump();
      expect(gateway.startCheckoutCalls, 1);
    });

    testWidgets('購入済みならダウンロードボタンを出す', (tester) async {
      final gateway = _FakeGateway(
        product: _product(),
        signedIn: true,
        purchased: true,
      );
      await _pump(tester, gateway);

      expect(find.text('ダウンロード'), findsOneWidget);
      expect(find.textContaining('で購入'), findsNothing);
    });

    testWidgets('決済直後で購入行が未反映なら購入ボタンを再表示しない', (tester) async {
      // Stripe の webhook 処理は数秒遅れることがある。ここで購入ボタンを
      // 出し直すと二重購入を誘発するため、反映待ちであることを明示する。
      final gateway = _FakeGateway(product: _product(), signedIn: true);
      await _pump(tester, gateway, purchaseResult: 'success');

      expect(find.text('決済を確認しています'), findsOneWidget);
      expect(find.text('¥500 で購入'), findsNothing);
      expect(gateway.startCheckoutCalls, 0);
    });

    testWidgets('購入中断の戻りでは中断を伝えたうえで再購入できる', (tester) async {
      await _pump(
        tester,
        _FakeGateway(product: _product(), signedIn: true),
        purchaseResult: 'canceled',
      );

      expect(find.text('購入は完了していません'), findsOneWidget);
      expect(find.text('¥500 で購入'), findsOneWidget);
    });

    testWidgets('読み込み失敗は原因を出して再試行できる', (tester) async {
      await _pump(
        tester,
        _FakeGateway(fetchError: Exception('relation does not exist')),
      );

      expect(find.text('商品情報を読み込めませんでした'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });

    testWidgets('実ゲーム画面3枚を購入ボタンより先に表示する', (tester) async {
      await _pump(tester, _FakeGateway(product: _product(), signedIn: true));

      expect(find.text('ゲーム画面'), findsOneWidget);
      expect(find.text('ターン30'), findsOneWidget);
      expect(find.text('ターン80'), findsOneWidget);
      expect(find.text('ターン150'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('ゲーム画面')).dy,
        lessThan(tester.getTopLeft(find.text('¥500 で購入')).dy),
      );
    });

    testWidgets('スクリーンショットのサムネイルで説明を切り替えられる', (tester) async {
      await _pump(tester, _FakeGateway(product: _product(), signedIn: true));

      expect(find.textContaining('序盤。'), findsOneWidget);
      expect(find.textContaining('終盤。'), findsNothing);

      await tester.ensureVisible(find.text('ターン150'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ターン150'));
      await tester.pumpAndSettle();

      expect(find.textContaining('終盤。'), findsOneWidget);
      expect(find.textContaining('序盤。'), findsNothing);
    });

    testWidgets('非公開商品ではゲーム画面を表示しない', (tester) async {
      await _pump(tester, _FakeGateway(product: null));

      expect(find.text('ゲーム画面'), findsNothing);
      expect(find.text('ターン30'), findsNothing);
    });

    testWidgets('製品情報に SHA256 と容量を出す', (tester) async {
      // 落としたファイルの同一性を購入者自身が確認できるようにするための表示。
      await _pump(tester, _FakeGateway(product: _product(), signedIn: true));

      expect(find.text('SHA256'), findsOneWidget);
      expect(find.textContaining('35.8 MB'), findsOneWidget);
      expect(find.text('Windows 10 / 11 (64bit)'), findsOneWidget);
    });
  });
}
