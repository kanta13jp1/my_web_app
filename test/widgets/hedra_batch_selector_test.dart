import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/hedra_batch_selector.dart';

void main() {
  testWidgets('offers every supported value from 1 through 8', (tester) async {
    var selected = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HedraBatchSelector(
            value: selected,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('生成バリエーション数（1〜8）'), findsOneWidget);
    expect(find.text('1件'), findsOneWidget);
    await tester.tap(find.byKey(const Key('hedra-batch-size-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('8件'), findsOneWidget);
    await tester.tap(find.text('8件'));
    await tester.pumpAndSettle();
    expect(selected, 8);
  });
}
