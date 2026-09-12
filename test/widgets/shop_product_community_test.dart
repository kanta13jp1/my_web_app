import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/shop_community.dart';
import 'package:my_web_app/services/shop_service.dart';
import 'package:my_web_app/theme/design_tokens.dart';
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
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(repository.sessions.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
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
  test('community colors meet text and essential icon contrast thresholds', () {
    double contrast(Color first, Color second) {
      final a = first.computeLuminance();
      final b = second.computeLuminance();
      return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
    }

    expect(
      contrast(DesignTokens.textPrimary, DesignTokens.surface1),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(DesignTokens.textSecondary, DesignTokens.surface1),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(DesignTokens.background, DesignTokens.orange),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(DesignTokens.orange, DesignTokens.surface1),
      greaterThanOrEqualTo(3),
    );
  });
  testWidgets('stars have 44px targets, labels and a live selection status',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpCommunity(tester, FakeShopCommunity(), width: 360);
      await tapText(tester, '口コミ・評価を書く');
      final first = find.byKey(const ValueKey('review-star-1'));
      for (var value = 1; value <= 5; value++) {
        final star = find.byKey(ValueKey('review-star-$value'));
        expect(tester.getSize(star).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(star).height, greaterThanOrEqualTo(44));
        expect(tester.getTopLeft(star).dy, tester.getTopLeft(first).dy);
        expect(tester.getSemantics(star).label, contains('星$valueを選択'));
      }
      await tester.tap(find.byKey(const ValueKey('review-star-4')));
      await tester.pumpAndSettle();
      expect(find.text('選択中：星4 / 5'), findsOneWidget);
      final status = tester.getSemantics(
        find.byKey(const ValueKey('review-rating-status')),
      );
      expect(status.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('keyboard selects stars in order and Escape closes the editor',
      (tester) async {
    await pumpCommunity(tester, FakeShopCommunity());
    await tapText(tester, '口コミ・評価を書く');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('選択中：星1 / 5'), findsOneWidget);
    for (var value = 2; value <= 5; value++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('選択中：星$value / 5'), findsOneWidget);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-body')), findsNothing);
  });
  testWidgets('mobile editor preserves usable actions at 200 percent text',
      (tester) async {
    final repo = FakeShopCommunity();
    await pumpCommunity(tester, repo, width: 360, textScale: 2);
    await tapText(tester, '口コミ・評価を書く');
    await tester.ensureVisible(find.byKey(const ValueKey('review-star-5')));
    await tester.tap(find.byKey(const ValueKey('review-star-5')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('review-body')), '拡大して入力');
    await tapText(tester, '公開して保存');
    expect(repo.saved?.body, '拡大して入力');
    expect(repo.saved?.rating, 5);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Escape cannot dismiss an in-flight save', (tester) async {
    final gate = Completer<void>();
    final repo = FakeShopCommunity()..writeGate = gate;
    try {
      await pumpCommunity(tester, repo);
      await tapText(tester, '口コミ・評価を書く');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tapText(tester, '公開して保存');
      expect(find.text('保存中…'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-body')), findsOneWidget);
      expect(repo.saved, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.saved?.rating, 1);
      expect(find.byKey(const ValueKey('review-body')), findsNothing);
    } finally {
      if (!gate.isCompleted) gate.complete();
    }
  });
  testWidgets('save error is announced and keeps input for recovery',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final repo = FakeShopCommunity()..failWrite = true;
      await pumpCommunity(tester, repo);
      await tapText(tester, '口コミ・評価を書く');
      await tester.tap(find.byKey(const ValueKey('review-star-3')));
      await tester.enterText(
        find.byKey(const ValueKey('review-body')),
        '消えない本文',
      );
      await tapText(tester, '公開して保存');
      expect(find.text('消えない本文'), findsOneWidget);
      expect(find.text('選択中：星3 / 5'), findsOneWidget);
      expect(find.text('口コミ・評価を保存しました。'), findsNothing);
      final error = tester.getSemantics(
        find.byKey(const ValueKey('review-save-error')),
      );
      expect(error.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(error.label, contains('保存内容を確認できませんでした'));
      expect(find.textContaining('private-internal'), findsNothing);
      repo.failWrite = false;
      await tapText(tester, '公開して保存');
      expect(repo.saved?.body, '消えない本文');
    } finally {
      semantics.dispose();
    }
  });
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
