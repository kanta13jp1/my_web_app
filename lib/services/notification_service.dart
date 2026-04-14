import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const int saturdayReminderId = 0;
  static const int abstinenceReminderId = 1001;
  static const int abstinenceRecoveryReminderId = 1002;

  Future<void> init() async {
    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  Future<void> scheduleSaturdayReminder() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'someday_tasks_reminder_channel',
      'Someday Tasks Reminder',
      channelDescription:
          'Reminds you to check your stocked tasks every Saturday.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: saturdayReminderId,
      title: '今週もお疲れ様でした！',
      body: '「いつかやる」タスクを見直して、来週の計画を立てませんか？',
      scheduledDate: _nextInstanceOfSaturdayTenAM(),
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelSaturdayReminder() async {
    await flutterLocalNotificationsPlugin.cancel(id: saturdayReminderId);
  }

  Future<void> scheduleDailyAbstinenceReminder({
    int id = abstinenceReminderId,
    int hour = 21,
    int minute = 0,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'abstinence_guard_reminder_channel',
      'Abstinence Guard Reminder',
      channelDescription:
          'Daily reminder for abstinence rules and continuation review.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: '禁欲ガード チェック',
      body: '今日の禁欲ルール実行と継続アクションの進捗を確認しましょう。',
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAbstinenceReminder({int id = abstinenceReminderId}) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> scheduleAbstinenceRecoveryReminder({
    int id = abstinenceRecoveryReminderId,
    DateTime? dueAt,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'abstinence_recovery_reminder_channel',
      'Abstinence Recovery Reminder',
      channelDescription:
          'Recovery reminder for immediate abstinence fallback actions.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = dueAt == null
        ? now.add(const Duration(minutes: 9))
        : tz.TZDateTime.from(
            dueAt.subtract(const Duration(minutes: 1)),
            tz.local,
          );
    final effectiveDate = scheduledDate.isAfter(now)
        ? scheduledDate
        : now.add(const Duration(seconds: 30));

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: '禁欲ガード 即時リカバリー',
      body: '残り時間が少なくなっています。10分以内に回復行動とロック再設定を完了しましょう。',
      scheduledDate: effectiveDate,
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelAbstinenceRecoveryReminder({
    int id = abstinenceRecoveryReminderId,
  }) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  tz.TZDateTime _nextInstanceOfSaturdayTenAM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);

    // If today is Saturday and it's already past 10 AM, schedule for next week
    if (scheduledDate.weekday == DateTime.saturday &&
        now.isAfter(scheduledDate)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    // Find the next Saturday
    while (scheduledDate.weekday != DateTime.saturday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
