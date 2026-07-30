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
  Future<ShopProduct?> fetchProduct(String productId) async {
    if (fetchError != null) throw fetchError!;
    return product;
  }

  @override
  Future<bool> hasPurchased(String productId) async => purchased;

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
    );

Future<void> _pump(
  WidgetTester tester,
  _FakeGateway gateway, {
  String? purchaseResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HexcivShopPage(service: gateway, purchaseResult: purchaseResult),
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

      // ギャラリーが入って購入ボタンは初期表示の外にある (意図どおり: 判断材料を
      // 決断より上に置いている)。押す前に可視化する。
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

    testWidgets('スクリーンショットを3枚出し、購入ボタンより上に置く', (tester) async {
      // ゲームは見た目を見ないと買う判断ができない。判断材料が決断より
      // 下にあると、多くの人は見ないまま離脱する。
      await _pump(tester, _FakeGateway(product: _product(), signedIn: true));

      expect(find.text('ターン30'), findsOneWidget);
      expect(find.text('ターン80'), findsOneWidget);
      expect(find.text('ターン150'), findsOneWidget);

      final galleryY = tester.getTopLeft(find.text('ターン30')).dy;
      final buttonY = tester.getTopLeft(find.text('¥500 で購入')).dy;
      expect(
        galleryY,
        lessThan(buttonY),
        reason: '判断材料 (画面) は決断 (購入ボタン) より上に置く',
      );
    });

    testWidgets('サムネイルを押すと大きく出す絵が切り替わる', (tester) async {
      await _pump(tester, _FakeGateway(product: _product(), signedIn: true));

      // 初期はターン30 の説明が出ている
      expect(find.textContaining('序盤。'), findsOneWidget);
      expect(find.textContaining('終盤。'), findsNothing);

      // 既定のテストビューポート(800x600)ではサムネイルが画面外にあるため、
      // 先に可視化する。warnIfMissed を切って誤魔化すと、押せていないのに
      // 通るテストになってしまう。
      await tester.ensureVisible(find.text('ターン150'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ターン150'));
      await tester.pumpAndSettle();

      expect(find.textContaining('終盤。'), findsOneWidget);
      expect(find.textContaining('序盤。'), findsNothing);
    });

    testWidgets('準備中のときはギャラリーも出さない', (tester) async {
      // 買えない商品の画面を見せる意味はない。
      await _pump(tester, _FakeGateway(product: null));

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
