import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/asset_legacy_fixed_cost_read_boundary.dart';

void main() {
  for (final width in <double>[390, 1200]) {
    testWidgets('failed legacy read can retry without losing input at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final status = ValueNotifier<int>(0);
      addTearDown(status.dispose);
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<int>(
                valueListenable: status,
                builder: (context, state, child) {
                  return AssetLegacyFixedCostReadBoundary(
                    isLoading: state == 1,
                    hasError: state == 2,
                    onRetry: () {
                      retries += 1;
                      status.value = 1;
                    },
                    child: const TextField(
                      decoration: InputDecoration(labelText: '編集中のメモ'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '入力を保持する');
      expect(find.text('旧固定費を再読込'), findsNothing);
      status.value = 2;
      await tester.pump();
      expect(find.text('旧固定費を読み取れませんでした'), findsOneWidget);
      expect(find.textContaining('未登録や0円とは確定できません'), findsOneWidget);
      expect(find.text('入力を保持する'), findsOneWidget);
      await tester.tap(find.text('旧固定費を再読込'));
      await tester.pump();
      expect(retries, 1);
      expect(find.text('旧固定費を確認中です'), findsOneWidget);
      expect(find.text('旧固定費を再読込'), findsNothing);
      expect(find.text('入力を保持する'), findsOneWidget);
      status.value = 0;
      await tester.pump();
      expect(find.textContaining('旧固定費を'), findsNothing);
      expect(find.text('入力を保持する'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
