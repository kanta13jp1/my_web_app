import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// R35: flutter_local_notifications はローカル通知の **スケジュール** を web で
/// サポートせず、`zonedSchedule()` は `UnsupportedError` を投げる。
/// main.dart は起動時に既定 true (`stock_tasks_saturday_reminder_enabled`) で
/// `scheduleSaturdayReminder()` を呼ぶため、**web では毎回の起動で
/// 例外→`FlutterError.reportError`→auto_error_report** が発生し、
/// コンソールと hub_data のエラーログ (第5弾の可視化カードが読む先) を、
/// web では原理的に成功し得ない条件で汚し続けていた。
/// web ではスケジュール系を静かに no-op する (機能自体が web に存在しない)。
bool get notificationSchedulingSupported => !kIsWeb;

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const int saturdayReminderId = 0;
  static const int abstinenceReminderId = 1001;
  static const int abstinenceRecoveryReminderId = 1002;
  static const int _calendarReminderBaseId = 200000;
  static const int _noteFeatureReminderBaseId = 1100000000;
  Future<void>? _initFuture;
  bool _initialized = false;

  Future<void> init() {
    if (_initialized) return Future<void>.value();
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    try {
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
      _initialized = true;
    } finally {
      if (!_initialized) {
        _initFuture = null;
      }
    }
  }

  Future<void> scheduleSaturdayReminder() async {
    // R35: web はスケジュール未対応 (zonedSchedule が UnsupportedError)。
    if (!notificationSchedulingSupported) return;
    await init();
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
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

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
    await init();
    await flutterLocalNotificationsPlugin.cancel(id: saturdayReminderId);
  }

  Future<void> scheduleDailyAbstinenceReminder({
    int id = abstinenceReminderId,
    int hour = 21,
    int minute = 0,
  }) async {
    // R35: web はスケジュール未対応 (zonedSchedule が UnsupportedError)。
    if (!notificationSchedulingSupported) return;
    await init();
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
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

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
    await init();
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> scheduleAbstinenceRecoveryReminder({
    int id = abstinenceRecoveryReminderId,
    DateTime? dueAt,
  }) async {
    // R35: web はスケジュール未対応 (zonedSchedule が UnsupportedError)。
    if (!notificationSchedulingSupported) return;
    await init();
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
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

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
    await init();
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> scheduleNoteFeatureReminder({
    required String sourceKey,
    required String title,
    required String body,
    required DateTime notifyAt,
  }) async {
    if (!notificationSchedulingSupported) return;
    final normalizedKey = sourceKey.trim();
    if (normalizedKey.isEmpty) return;

    await init();
    final notificationId = noteFeatureReminderIdForSource(normalizedKey);
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = tz.TZDateTime.from(notifyAt, tz.local);
    if (!scheduledDate.isAfter(now)) return;

    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'note_feature_reminder_channel',
      'Task and note reminders',
      channelDescription: 'Reminders for Tasks and notes.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const iosPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'note-feature:$normalizedKey',
    );
  }

  Future<void> cancelNoteFeatureReminder({
    required String sourceKey,
  }) async {
    if (!notificationSchedulingSupported) return;
    final normalizedKey = sourceKey.trim();
    if (normalizedKey.isEmpty) return;
    await init();
    await flutterLocalNotificationsPlugin.cancel(
      id: noteFeatureReminderIdForSource(normalizedKey),
    );
  }

  static int noteFeatureReminderIdForSource(String sourceKey) {
    var hash = 0;
    for (final unit in sourceKey.codeUnits) {
      hash = ((hash * 31) + unit) & 0x3fffffff;
    }
    return _noteFeatureReminderBaseId + (hash % 800000000);
  }

  Future<void> scheduleCalendarEventReminder({
    required String eventId,
    required String title,
    required DateTime startAt,
    required int reminderMinutes,
  }) async {
    if (!notificationSchedulingSupported) return;
    final normalizedId = eventId.trim();
    if (normalizedId.isEmpty) return;

    await init();
    final notificationId = calendarReminderIdForEvent(normalizedId);
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = tz.TZDateTime.from(
      startAt.subtract(Duration(minutes: reminderMinutes)),
      tz.local,
    );
    if (!scheduledDate.isAfter(now)) return;

    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'calendar_event_reminder_channel',
      'Calendar Event Reminders',
      channelDescription: 'Reminders before scheduled calendar events.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const iosPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Calendar reminder',
      body: reminderMinutes == 0
          ? '$title starts now'
          : '$title starts in $reminderMinutes minutes',
      scheduledDate: scheduledDate,
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelCalendarEventReminder({required String eventId}) async {
    final normalizedId = eventId.trim();
    if (normalizedId.isEmpty) return;
    await init();
    await flutterLocalNotificationsPlugin.cancel(
      id: calendarReminderIdForEvent(normalizedId),
    );
  }

  static int calendarReminderIdForEvent(String eventId) {
    var hash = 0;
    for (final unit in eventId.codeUnits) {
      hash = ((hash * 31) + unit) & 0x3fffffff;
    }
    return _calendarReminderBaseId + (hash % 800000000);
  }

  tz.TZDateTime _nextInstanceOfSaturdayTenAM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      10,
    );

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
    await init();
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
