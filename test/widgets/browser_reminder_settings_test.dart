import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/browser_reminder_controller.dart';
import 'package:my_web_app/widgets/browser_reminder_settings.dart';

void main() {
  testWidgets('opening settings does not notify an ancestor during build', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrowserReminderSettingsTile())),
    );
    await tester.tap(find.text('「手は机へ」デスクトップ通知'));
    await tester.pumpAndSettle();
    expect(find.text('通知間隔'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screen supports start, test, stop without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var requests = 0;
    var shown = 0;
    final controller = BrowserReminderController(
      supported: true,
      readPermission: () => 'granted',
      requestPermission: () async {
        requests++;
        return 'granted';
      },
      showReminder: () async {
        shown++;
      },
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BrowserReminderSettings(controller: controller),
          ),
        ),
      ),
    );
    expect(requests, 0);
    expect(find.text('停止中'), findsOneWidget);
    await tester.tap(find.text('開始'));
    await tester.pump();
    expect(find.text('実行中・約5分おき'), findsOneWidget);
    await tester.tap(find.text('テスト通知'));
    await tester.pump();
    expect(shown, 1);
    await tester.tap(find.text('停止'));
    await tester.pump();
    expect(controller.running, false);
    expect(tester.takeException(), isNull);
  });
}
