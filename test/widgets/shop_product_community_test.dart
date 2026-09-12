import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/shop_community.dart';
import 'package:my_web_app/services/shop_service.dart';
import 'package:my_web_app/widgets/shop_product_community.dart';

import '../support/fake_shop_community.dart';

const product = ShopProduct(
  id: 'test',
  nameJa: 'テスト用アプリ',
  summaryJa: '説明',
  priceJpy: 500,
  version: '1.0',
  fileSizeBytes: 1024,
  sha256: 'abc',
  isPurchasable: true,
);

Future<void> pumpCommunity(
  WidgetTester tester,
  FakeShopCommunity repository, {
  double width = 1000,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(repository.sessions.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ShopProductCommunity(
              product: product,
              repository: repository,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows application version, verified release and unknown date',
      (tester) async {
    final repo = FakeShopCommunity()
      ..releaseItems = const [
        ShopProductRelease(
          id: 'r',
          version: '1.0',
          title: '確認済みの配布内容',
          notes: '更新の説明',
          sha256: 'abc',
        ),
      ];
    await pumpCommunity(tester, repo);
    expect(find.text('現在の配布版：v1.0'), findsOneWidget);
    expect(find.textContaining('サイト上部のバージョン番号とは別'), findsOneWidget);
    expect(find.textContaining('現在の配布内容 ・ 公開日：未記録'), findsOneWidget);
    expect(find.text('更新の説明'), findsOneWidget);
    expect(find.text('評価はまだありません（0件）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unpaid visitor can read but not open the editor',
      (tester) async {
    final repo = FakeShopCommunity()..paid = false;
    await pumpCommunity(tester, repo);
    expect(find.text('口コミ・評価を書く'), findsNothing);
    expect(find.textContaining('購入が確認できたアカウント'), findsOneWidget);
  });
  testWidgets('logged-out visitor sees login instead of write', (tester) async {
    await pumpCommunity(tester, FakeShopCommunity()..signedIn = false);
    expect(find.text('ログイン'), findsOneWidget);
    expect(find.text('口コミ・評価を書く'), findsNothing);
  });
  testWidgets('mobile write, edit, reload and confirmed delete',
      (tester) async {
    final repo = FakeShopCommunity();
    await pumpCommunity(tester, repo, width: 360);
    await tapText(tester, '口コミ・評価を書く');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '公開して保存'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('review-star-5')));
    await tester.enterText(
      find.byKey(const ValueKey('review-body')),
      '分かりやすいゲームです。',
    );
    await tapText(tester, '公開して保存');
    expect(repo.saved!.rating, 5);
    expect(find.text('分かりやすいゲームです。'), findsOneWidget);
    await tapText(tester, '自分の口コミを編集');
    await tester.tap(find.byKey(const ValueKey('review-star-3')));
    await tester.enterText(
      find.byKey(const ValueKey('review-body')),
      '追記しました。',
    );
    await tapText(tester, '公開して保存');
    expect(repo.saved!.rating, 3);
    await tapText(tester, '更新情報と口コミを再読み込み');
    expect(find.text('追記しました。'), findsOneWidget);
    await tapText(tester, '自分の口コミを削除');
    await tapText(tester, 'キャンセル');
    expect(repo.deletes, 0);
    await tapText(tester, '自分の口コミを削除');
    await tapText(tester, '削除する');
    expect(repo.deletes, 1);
    expect(find.text('評価はまだありません（0件）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('service failure has a retry and never displays zero',
      (tester) async {
    final repo = FakeShopCommunity()..failRead = true;
    await pumpCommunity(tester, repo);
    expect(find.text('口コミ・評価を読み込めませんでした。'), findsOneWidget);
    expect(find.textContaining('private-internal'), findsNothing);
    expect(find.text('評価はまだありません（0件）'), findsNothing);
    repo.failRead = false;
    await tapText(tester, '更新情報と口コミを再読み込み');
    expect(find.text('評価はまだありません（0件）'), findsOneWidget);
  });
  testWidgets('long content remains readable at 360px', (tester) async {
    final repo = FakeShopCommunity()
      ..publicItems
          .add(FakeShopCommunity.review('long', body: '詳細な口コミです。' * 100));
    await pumpCommunity(tester, repo, width: 360);
    expect(find.textContaining('投稿時の配布版 v1.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('account switching removes previous text from the open editor',
      (tester) async {
    final repo = FakeShopCommunity()
      ..saved = FakeShopCommunity.review('own', body: '前のアカウントの本文');
    await pumpCommunity(tester, repo);
    await tapText(tester, '自分の口コミを編集');
    repo.signedIn = false;
    repo.sessions.add(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-body')), findsNothing);
    expect(find.text('ログイン状態が変わりました'), findsOneWidget);
  });
}
