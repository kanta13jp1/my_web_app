import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('Notification')
external JSAny? get _notificationApi;

class BrowserReminderPlatform {
  bool get supported => _notificationApi != null && web.window.isSecureContext;
  String get permission =>
      supported ? web.Notification.permission : 'unsupported';

  Future<String> requestPermission() {
    if (!supported) return Future.value('unsupported');
    // Invoke immediately, in the user's click stack; never at app startup.
    return web.Notification.requestPermission()
        .toDart
        .then((value) => value.toDart);
  }

  Future<void> showReminder() async {
    if (permission != 'granted') {
      throw StateError('Notification permission lost');
    }
    web.Notification(
      '手は机へ',
      web.NotificationOptions(
        body: '髪に手が伸びていたら、そっと机に戻しましょう。',
        tag: 'hands-on-desk-reminder',
      ),
    );
  }
}
