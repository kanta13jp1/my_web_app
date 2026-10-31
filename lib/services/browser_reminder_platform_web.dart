import 'dart:async';
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
    final notification = web.Notification(
      '手は机へ',
      web.NotificationOptions(
        body: '髪に手が伸びていたら、そっと机に戻しましょう。',
        tag: 'hands-on-desk-reminder',
        renotify: true,
      ),
    );
    // Construction is only a request. Browser/platform failures arrive later.
    final shown = Completer<void>();
    final onShow = ((web.Event _) {
      if (!shown.isCompleted) shown.complete();
    }).toJS;
    final onError = ((web.Event _) {
      if (!shown.isCompleted) {
        shown.completeError(StateError('Browser notification error event'));
      }
    }).toJS;
    notification.addEventListener('show', onShow);
    notification.addEventListener('error', onError);
    try {
      await shown.future.timeout(const Duration(seconds: 8));
    } finally {
      notification.removeEventListener('show', onShow);
      notification.removeEventListener('error', onError);
    }
  }
}
