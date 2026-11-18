import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/synthetic_auth_boundary_guide.dart';

void main() {
  for (final width in [360.0, 1024.0]) {
    testWidgets('架空の中継例を切り替える ($width px)', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(children: const [SyntheticAuthBoundaryGuide()]),
          ),
        ),
      );

      expect(find.text('中継先：経由しない'), findsOneWidget);
      expect(find.text('送信先：架空の認証文字列を受け取る'), findsOneWidget);

      await tester.tap(find.text('中継して転送'));
      await tester.pumpAndSettle();
      expect(find.text('中継先：架空の認証文字列を受け取る'), findsOneWidget);
      expect(find.text('送信先：架空の認証文字列を受け取る'), findsOneWidget);

      await tester.tap(find.text('中継で除去'));
      await tester.pumpAndSettle();
      expect(find.text('中継先：架空の認証文字列を受け取る'), findsOneWidget);
      expect(find.text('送信先：認証文字列は届かない'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
