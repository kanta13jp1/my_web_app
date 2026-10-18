import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/echo_pump_incident.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    VoidCallback done, {
    bool reduced = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(body: EchoPumpIncident(onFinished: done)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('three shots finish once even if skip follows the final frame', (
    tester,
  ) async {
    var done = 0;
    await show(tester, () => done++);
    expect(find.text('設備異常 1 / 3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('設備異常 2 / 3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('設備異常 3 / 3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(done, 1);
    await tester.tap(find.text('スキップして探索へ'));
    expect(done, 1);
  });

  testWidgets('early skip completes only once and stops the clock', (
    tester,
  ) async {
    var done = 0;
    await show(tester, () => done++);
    await tester.tap(find.text('スキップして探索へ'));
    await tester.tap(find.text('スキップして探索へ'));
    await tester.pump(const Duration(seconds: 12));
    expect(done, 1);
  });

  testWidgets('user pause survives background and foreground until resumed', (
    tester,
  ) async {
    var done = 0;
    await show(tester, () => done++);
    await tester.tap(find.text('演出を一時停止'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 12));
    expect(done, 0);
    expect(find.text('設備異常 1 / 3'), findsOneWidget);
    await tester.tap(find.text('演出を再開'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(done, 1);
  });

  testWidgets(
    'reduced motion keeps a static view and large text fits a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(body: EchoPumpIncident(onFinished: () {})),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('スキップして探索へ'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 12));
      expect(tester.takeException(), isNull);
    },
  );
}
