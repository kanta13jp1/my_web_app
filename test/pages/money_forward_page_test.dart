import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/money_forward_page.dart';

void main() {
  testWidgets(
      'discloses note-only import without promising account restoration', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MoneyForwardPage()));
    expect(find.textContaining('復元する機能ではありません'), findsOneWidget);
    expect(find.textContaining('今すぐ収支データを反映'), findsNothing);
    expect(find.text('接続する'), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('CSVをXLSXへ変換'),
      300,
    );
    expect(find.textContaining('「内容」'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final route in ['/import', '/user-manual']) {
    testWidgets('guidance button opens $route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const MoneyForwardPage(),
          routes: {
            '/import': (_) => const Scaffold(body: Text('Import destination')),
            '/user-manual': (_) =>
                const Scaffold(body: Text('Manual destination')),
          },
        ),
      );
      final button = find.text(
        route == '/import' ? 'インポート画面を開く' : 'マニュアルで詳しい手順を見る',
      );
      await tester.scrollUntilVisible(button, 300);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.text(
            route == '/import' ? 'Import destination' : 'Manual destination'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
