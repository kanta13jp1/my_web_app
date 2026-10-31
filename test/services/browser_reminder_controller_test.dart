import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/browser_reminder_controller.dart';

void main() {
  late String permission;
  late int requests;
  late int shown;
  late BrowserReminderController controller;

  setUp(() {
    permission = 'default';
    requests = 0;
    shown = 0;
    controller = BrowserReminderController(
      supported: true,
      readPermission: () => permission,
      requestPermission: () async {
        requests++;
        return permission = 'granted';
      },
      showReminder: () async {
        shown++;
      },
    );
  });
  tearDown(() => controller.dispose());

  testWidgets(
      'initially off, no unsolicited permission, every five minutes then stop',
      (tester) async {
    expect(controller.running, false);
    expect(requests, 0);
    await controller.start();
    expect(requests, 1);
    expect(shown, 0);
    await tester.pump(const Duration(minutes: 4));
    expect(shown, 0);
    await tester.pump(const Duration(minutes: 1));
    expect(shown, 1);
    await controller.start(); // no duplicate timer
    await tester.pump(const Duration(minutes: 5));
    expect(shown, 2);
    controller.stop();
    await tester.pump(const Duration(minutes: 20));
    expect(shown, 2);
  });

  testWidgets(
      'interval change replaces schedule and permission revocation stops',
      (tester) async {
    permission = 'granted';
    await controller.start();
    controller.setInterval(10);
    await tester.pump(const Duration(minutes: 5));
    expect(shown, 0);
    await tester.pump(const Duration(minutes: 5));
    expect(shown, 1);
    permission = 'denied';
    await tester.pump(const Duration(minutes: 10));
    expect(shown, 1);
    expect(controller.running, false);
  });

  test('test notification is immediate but does not start reminder', () async {
    await controller.testNotification();
    expect(shown, 1);
    expect(controller.running, false);
    expect(controller.message, contains('表示応答'));
  });

  test('blocked permission is not requested repeatedly', () async {
    permission = 'denied';
    await controller.start();
    expect(controller.running, false);
    expect(requests, 0);
    expect(shown, 0);
    expect(controller.message, contains('ブロック'));
  });

  test('late permission failure cannot overwrite explicit stop', () async {
    final prompt = Completer<String>();
    final pending = BrowserReminderController(
      supported: true,
      readPermission: () => 'default',
      requestPermission: () => prompt.future,
      showReminder: () async {},
    );
    final start = pending.start();
    pending.stop();
    prompt.completeError(StateError('permission failed after stop'));
    await start;
    expect(pending.message, '停止中です。');
    expect(pending.running, false);
    pending.dispose();
  });

  test('stop while permission prompt pending cannot enable later', () async {
    final prompt = Completer<String>();
    final pending = BrowserReminderController(
      supported: true,
      readPermission: () => 'default',
      requestPermission: () => prompt.future,
      showReminder: () async {
        shown++;
      },
    );
    final start = pending.start();
    pending.stop();
    prompt.complete('granted');
    await start;
    expect(pending.running, false);
    expect(pending.busy, false);
    pending.dispose();
  });

  testWidgets('platform failure stops timer and reports failure',
      (tester) async {
    final failing = BrowserReminderController(
      supported: true,
      readPermission: () => 'granted',
      requestPermission: () async => 'granted',
      showReminder: () async => throw StateError('platform failure'),
    );
    await failing.start();
    await tester.pump(const Duration(minutes: 5));
    expect(failing.running, false);
    expect(failing.message, contains('停止'));
    failing.dispose();
  });
  for (final timeout in [false, true]) {
    test(
        'test notification surfaces ${timeout ? 'timeout' : 'async error'} without success time',
        () async {
      final failing = BrowserReminderController(
        supported: true,
        readPermission: () => 'granted',
        requestPermission: () async => 'granted',
        showReminder: () async {
          if (timeout) throw TimeoutException('show not confirmed');
          throw StateError('asynchronous notification error');
        },
      );
      await failing.testNotification();
      expect(failing.message, contains(timeout ? '8秒以内' : '表示できません'));
      expect(failing.lastRequestedAt, isNull);
      expect(failing.busy, false);
      expect(failing.running, false);
      failing.dispose();
    });
  }
}
