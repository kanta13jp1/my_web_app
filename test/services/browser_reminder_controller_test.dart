import 'dart:async';
import 'package:fake_async/fake_async.dart';
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
      requestPermission: () async { requests++; return permission = 'granted'; },
      showReminder: () async { shown++; },
    );
  });
  tearDown(() => controller.dispose());

  test('initially off, no unsolicited permission, every five minutes then stop', () {
    fakeAsync((clock) {
      expect(controller.running, false);
      expect(requests, 0);
      controller.start();
      clock.flushMicrotasks();
      expect(requests, 1);
      expect(shown, 0);
      clock.elapse(const Duration(minutes: 4));
      expect(shown, 0);
      clock.elapse(const Duration(minutes: 1));
      expect(shown, 1);
      controller.start(); // no duplicate timer
      clock.elapse(const Duration(minutes: 5));
      expect(shown, 2);
      controller.stop();
      clock.elapse(const Duration(minutes: 20));
      expect(shown, 2);
    });
  });

  test('interval change replaces schedule and permission revocation stops', () {
    fakeAsync((clock) {
      permission = 'granted';
      controller.start();
      clock.flushMicrotasks();
      controller.setInterval(10);
      clock.elapse(const Duration(minutes: 5));
      expect(shown, 0);
      clock.elapse(const Duration(minutes: 5));
      expect(shown, 1);
      permission = 'denied';
      clock.elapse(const Duration(minutes: 10));
      expect(shown, 1);
      expect(controller.running, false);
    });
  });

  test('test notification is immediate but does not start reminder', () async {
    await controller.testNotification();
    expect(shown, 1);
    expect(controller.running, false);
    expect(controller.message, contains('要求'));
  });

  test('blocked permission is not requested repeatedly', () async {
    permission = 'denied';
    await controller.start();
    expect(controller.running, false);
    expect(requests, 0);
    expect(shown, 0);
    expect(controller.message, contains('ブロック'));
  });

  test('stop while permission prompt pending cannot enable later', () async {
    final prompt = Completer<String>();
    final pending = BrowserReminderController(
      supported: true,
      readPermission: () => 'default',
      requestPermission: () => prompt.future,
      showReminder: () async { shown++; },
    );
    final start = pending.start();
    pending.stop();
    prompt.complete('granted');
    await start;
    expect(pending.running, false);
    expect(pending.busy, false);
    pending.dispose();
  });

  test('platform failure stops timer and reports failure', () {
    fakeAsync((clock) {
      final failing = BrowserReminderController(
        supported: true,
        readPermission: () => 'granted',
        requestPermission: () async => 'granted',
        showReminder: () async => throw StateError('platform failure'),
      );
      failing.start();
      clock.flushMicrotasks();
      clock.elapse(const Duration(minutes: 5));
      expect(failing.running, false);
      expect(failing.message, contains('停止'));
      failing.dispose();
    });
  });
}
