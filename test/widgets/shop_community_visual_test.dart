// Rendered UI evidence with fixture data; never a production review submission.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/shop_community.dart';
import 'package:my_web_app/widgets/shop_product_community.dart';

import '../support/fake_shop_community.dart';
import 'shop_product_community_test.dart' show product;

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/shop-community-evidence/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final width in [1040.0, 360.0]) {
    testWidgets('render release history, reviews and editor at ${width.toInt()}px', (tester) async {
      await tester.runAsync(() async {
        final loader = FontLoader('NotoSansJP')
          ..addFont(rootBundle.load('web/assets/fonts/NotoSansJP-Regular.ttf'));
        await loader.load();
      });
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeShopCommunity()
        ..releaseItems = const [ShopProductRelease(id: 'version', version: '1.0',
          title: '配布内容のご案内', notes: '通常4Xとウルク編を収録。これは表示確認用のサンプルです。', sha256: 'abc')]
        ..publicItems.add(FakeShopCommunity.review('fixture', rating: 4,
          body: '【表示確認用・架空の口コミ】最初の都市を育てる流れが楽しめました。'));
      addTearDown(repository.sessions.close);
      final screen = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: screen, child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'NotoSansJP'),
        home: Scaffold(body: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.all(20),
          child: ShopProductCommunity(product: product, repository: repository),
        ))),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, screen, 'community-${width.toInt()}');
      await tester.ensureVisible(find.text('口コミ・評価を書く'));
      await tester.pumpAndSettle();
      await capture(tester, screen, 'reviews-${width.toInt()}');
      await tester.tap(find.text('口コミ・評価を書く'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('review-star-4')));
      await tester.pumpAndSettle();
      await capture(tester, screen, 'editor-${width.toInt()}');
      expect(tester.takeException(), isNull);
    });
  }
}
