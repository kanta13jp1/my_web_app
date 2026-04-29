---
title: "Flutter Local Notifications — Scheduled and Rich Notifications with flutter_local_notifications"
tags: flutter,ai,indiedev,automation
published: true
---

# Flutter Local Notifications — Scheduled and Rich Notifications with flutter_local_notifications

No push server needed — local notifications can re-engage users on their own. Here are the key implementation patterns.

## Setup

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
  tz.setLocalLocation(tz.getLocation('America/New_York'));

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await notifications.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (details) {
      handleNotificationTap(details.payload);
    },
  );
}
```

## Immediate Notification

```dart
Future<void> showNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'default_channel',
      'Default Notifications',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );
  await notifications.show(0, title, body, details, payload: payload);
}
```

## Scheduled Notification (Daily Reminder)

```dart
Future<void> scheduleDailyReminder({
  required int id,
  required String title,
  required String body,
  required Time time,
}) async {
  await notifications.zonedSchedule(
    id,
    title,
    body,
    _nextInstanceOfTime(time),
    const NotificationDetails(
      android: AndroidNotificationDetails('reminder', 'Reminders'),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time, // repeat daily
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

## Summary

```
Immediate         → notifications.show()
Scheduled         → notifications.zonedSchedule() + matchDateTimeComponents
Daily repeat      → DateTimeComponents.time
Tap handler       → onDidReceiveNotificationResponse + payload
```

Local notifications are the lowest-cost way to maintain engagement — no push server required.
