---
title: "Flutter ローカル通知 — flutter_local_notifications でスケジュール・リッチ通知"
tags: flutter,AI,個人開発,automation
published: true
---

# Flutter ローカル通知 — flutter_local_notifications でスケジュール・リッチ通知

プッシュ通知不要でもローカル通知でユーザーをリエンゲージできる。実装パターンをまとめる。

## セットアップ

```yaml
# pubspec.yaml
dependencies:
  flutter_local_notifications: ^17.0.0
  timezone: ^0.9.0
```

```dart
// main.dart
final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await notifications.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (details) {
      // 通知タップ時の処理
      handleNotificationTap(details.payload);
    },
  );
}
```

## 即時通知

```dart
Future<void> showNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'default_channel',
      'デフォルト通知',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );
  await notifications.show(0, title, body, details, payload: payload);
}
```

## スケジュール通知 (毎日リマインダー)

```dart
Future<void> scheduleDailyReminder({
  required int id,
  required String title,
  required String body,
  required Time time, // flutter_local_notifications の Time
}) async {
  await notifications.zonedSchedule(
    id,
    title,
    body,
    _nextInstanceOfTime(time),
    const NotificationDetails(
      android: AndroidNotificationDetails('reminder', 'リマインダー'),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time, // 毎日繰り返し
  );
}

TZDateTime _nextInstanceOfTime(Time time) {
  final now = tz.TZDateTime.now(tz.local);
  var scheduled = tz.TZDateTime(
    tz.local, now.year, now.month, now.day, time.hour, time.minute,
  );
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}
```

## まとめ

```
即時通知       → notifications.show()
スケジュール   → notifications.zonedSchedule() + matchDateTimeComponents
毎日繰り返し   → DateTimeComponents.time
タップ処理     → onDidReceiveNotificationResponse + payload
```

ローカル通知は「プッシュ通知サーバー不要」でエンゲージメントを維持できる最小コスト手段。
