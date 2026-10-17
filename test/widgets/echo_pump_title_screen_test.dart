import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/echo_pump_title_screen.dart';

void main() {
  testWidgets('start is keyboard accessible', (tester) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EchoPumpTitleScreen(onStart: () => starts++),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing artwork keeps the start control usable', (tester) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EchoPumpTitleScreen(
          onStart: () => starts++,
          backgroundAsset: 'missing-opening.png',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('echo-background-fallback')), findsOneWidget);
    await tester.tap(find.byKey(const Key('echo-start')));
    expect(starts, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short narrow screen with large text scrolls to start',
      (tester) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: EchoPumpTitleScreen(onStart: () => starts++),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('echo-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('echo-start')));
    expect(starts, 1);
    expect(tester.takeException(), isNull);
  });
}
