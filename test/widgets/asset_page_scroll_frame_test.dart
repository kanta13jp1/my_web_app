import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/asset_page_scroll_frame.dart';

Widget harness(ScrollController controller, {bool compact = false}) {
  return MaterialApp(
    home: Scaffold(
      body: AssetPageScrollFrame(
        controller: controller,
        compact: compact,
        child: SingleChildScrollView(
          controller: controller,
          child: const SizedBox(height: 12000, width: double.infinity),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('desktop thumb drag moves the long page without losing position',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(harness(controller));
    await tester.pump();
    final frame = tester.widget<Scrollbar>(
      find.byKey(const Key('asset_page_scrollbar')),
    );
    expect(frame.controller, same(controller));
    expect(frame.thumbVisibility, isTrue);
    final rect = tester.getRect(find.byKey(const Key('asset_page_scrollbar')));
    final gesture = await tester.startGesture(
      Offset(rect.right - 5, rect.top + 18),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 160));
    await gesture.up();
    await tester.pump();
    expect(controller.offset, greaterThan(0));
    final reached = controller.offset;
    await tester.pumpWidget(harness(controller));
    await tester.pump();
    expect(controller.offset, closeTo(reached, 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('compact layout keeps scrolling with no persistent track',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(harness(controller, compact: true));
    final frame = tester.widget<Scrollbar>(
      find.byKey(const Key('asset_page_scrollbar')),
    );
    expect(frame.thumbVisibility, isFalse);
    expect(frame.trackVisibility, isFalse);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
