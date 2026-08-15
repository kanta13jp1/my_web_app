import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rrule/rrule.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:my_web_app/services/calendar_ics_service.dart';
import 'package:my_web_app/services/calendar_timezone_service.dart';
import 'package:my_web_app/services/notification_service.dart';
import 'package:my_web_app/utils/web_text_downloader.dart';

/// カレンダーイベントページ
/// calendar-events Edge Function と連携してイベントを管理
/// table_calendar による月次ビュー + 日付別イベントリスト
class CalendarEventsPage extends StatefulWidget {
  const CalendarEventsPage({
    super.key,
    SupabaseClient? supabaseClient,
    NotificationService? notificationService,
  })  : _supabaseClient = supabaseClient,
        _notificationService = notificationService;

  final SupabaseClient? _supabaseClient;
  final NotificationService? _notificationService;

  @override
  State<CalendarEventsPage> createState() => _CalendarEventsPageState();
}

enum _CalendarView { month, week, day }

enum _CalendarRecurrencePreset { none, daily, weekly, monthly, yearly, custom }

enum _RecurrenceEditScope { thisEvent, following, all }

enum _CalendarIcsAction { export, import }

const String _defaultCalendarId = 'default';
const String _defaultCalendarName = 'Default';
const String _defaultCalendarColor = '#4285f4';
const int _maxExpandedOccurrences = 732;
const int _calendarDragSnapMinutes = 15;

const Map<int, String> _weekdayLabels = {
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

String _formatClock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

DateTime? _eventDateTime(
  Map<String, dynamic> event,
  String key, {
  bool showOriginalTimezone = false,
}) {
  return calendarEventDateTimeForDisplay(
    event,
    key,
    showOriginalTimezone: showOriginalTimezone,
  );
}

bool _eventIsAllDay(Map<String, dynamic> event) => event['all_day'] == true;

String _eventTitle(Map<String, dynamic> event) =>
    event['title']?.toString().trim().isNotEmpty == true
        ? event['title'].toString()
        : 'Untitled';

String _eventTimeLabel(
  Map<String, dynamic> event, {
  bool showOriginalTimezone = false,
}) {
  if (_eventIsAllDay(event)) return 'All-day';
  final start = _eventDateTime(
    event,
    'start_at',
    showOriginalTimezone: showOriginalTimezone,
  );
  final end = _eventDateTime(
    event,
    'end_at',
    showOriginalTimezone: showOriginalTimezone,
  );
  if (start == null) return '';
  if (end == null) return _formatClock(start);
  return '${_formatClock(start)} - ${_formatClock(end)}';
}

String _formatDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

String _formatDateTime(DateTime d) => '${_formatDate(d)} ${_formatClock(d)}';

String _eventDateTimeLabel(
  Map<String, dynamic> event, {
  bool showOriginalTimezone = false,
}) {
  final start = _eventDateTime(
    event,
    'start_at',
    showOriginalTimezone: showOriginalTimezone,
  );
  final end = _eventDateTime(
    event,
    'end_at',
    showOriginalTimezone: showOriginalTimezone,
  );
  if (start == null) return 'No start time';
  if (_eventIsAllDay(event)) return '${_formatDate(start)} All-day';
  if (end == null) return _formatDateTime(start);
  final endLabel =
      start.year == end.year && start.month == end.month && start.day == end.day
          ? _formatClock(end)
          : _formatDateTime(end);
  return '${_formatDateTime(start)} - $endLabel';
}

String _eventTimezoneLabel(Map<String, dynamic> event) {
  final timezone = calendarEventTimezone(event);
  return '$timezone (${calendarTimezoneAbbreviation(timezone)})';
}

String _eventColorHex(Map<String, dynamic> event) {
  final raw = event['color']?.toString().trim();
  if (raw == null || raw.isEmpty) return _defaultCalendarColor;
  final normalized = raw.startsWith('#') ? raw : '#$raw';
  final lower = normalized.toLowerCase();
  return RegExp(r'^#[0-9a-f]{6}$').hasMatch(lower)
      ? lower
      : _defaultCalendarColor;
}

@visibleForTesting
String calendarEventCalendarId(Map<String, dynamic> event) {
  final id = event['calendar_id']?.toString().trim() ?? '';
  return id.isEmpty ? _defaultCalendarId : id;
}

@visibleForTesting
String calendarEventCalendarName(Map<String, dynamic> event) {
  final name = event['calendar_name']?.toString().trim() ?? '';
  return name.isEmpty ? _defaultCalendarName : name;
}

const List<int> _calendarReminderOptions = [-1, 0, 5, 10, 15, 30, 60];

@visibleForTesting
int? normalizeCalendarReminderMinutes(Object? value) {
  if (value == null) return null;
  final minutes = value is int ? value : int.tryParse(value.toString());
  if (minutes == null) return null;
  return _calendarReminderOptions.contains(minutes) && minutes >= 0
      ? minutes
      : null;
}

@visibleForTesting
int? calendarEventReminderMinutes(Map<String, dynamic> event) {
  return normalizeCalendarReminderMinutes(event['reminder_min']);
}

@visibleForTesting
String? normalizeCalendarEventRRule(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  final candidate = raw.toUpperCase().startsWith('RRULE:') ? raw : 'RRULE:$raw';
  try {
    return RecurrenceRule.fromString(
      candidate,
      options: const RecurrenceRuleFromStringOptions.lenient(),
    ).toString();
  } catch (_) {
    return null;
  }
}

@visibleForTesting
String? calendarEventRRule(Map<String, dynamic> event) {
  return normalizeCalendarEventRRule(event['rrule']);
}

@visibleForTesting
String calendarEventSeriesId(Map<String, dynamic> event) {
  final seriesId = event['series_event_id']?.toString().trim() ?? '';
  if (seriesId.isNotEmpty) return seriesId;
  return event['event_id']?.toString().trim() ?? '';
}

@visibleForTesting
bool calendarEventIsRecurrenceOccurrence(Map<String, dynamic> event) {
  return event['is_occurrence'] == true &&
      (event['series_event_id']?.toString().trim().isNotEmpty ?? false);
}

@visibleForTesting
String calendarEventRecurrenceLabel(Map<String, dynamic> event) {
  final rrule = calendarEventRRule(event);
  if (rrule == null) return 'Does not repeat';
  try {
    final rule = RecurrenceRule.fromString(
      rrule,
      options: const RecurrenceRuleFromStringOptions.lenient(),
    );
    final hasCustomParts = rule.count != null ||
        rule.until != null ||
        rule.hasByWeekDays ||
        rule.hasByMonthDays ||
        rule.hasByMonths;
    if (hasCustomParts) return 'Custom recurrence';
    return switch (rule.frequency) {
      Frequency.daily => 'Daily',
      Frequency.weekly => 'Weekly',
      Frequency.monthly => 'Monthly',
      Frequency.yearly => 'Yearly',
      _ => 'Custom recurrence',
    };
  } catch (_) {
    return 'Custom recurrence';
  }
}

@visibleForTesting
List<Map<String, dynamic>> expandRecurringCalendarEventsForRange(
  Iterable<Map<String, dynamic>> events, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final expanded = <Map<String, dynamic>>[];

  for (final event in events) {
    final rrule = calendarEventRRule(event);
    final start = _eventDateTime(event, 'start_at');
    if (rrule == null || start == null) {
      expanded.add(event);
      continue;
    }

    final end = _eventDateTime(event, 'end_at');
    final duration = _eventDuration(event, start, end);
    final seriesId = calendarEventSeriesId(event);
    if (seriesId.isEmpty) {
      expanded.add(event);
      continue;
    }

    try {
      final rule = RecurrenceRule.fromString(
        rrule,
        options: const RecurrenceRuleFromStringOptions.lenient(),
      );
      final recurrenceStartUtc = start.toUtc();
      final afterCandidate = rangeStart.subtract(duration).toUtc();
      final afterUtc = afterCandidate.isAfter(recurrenceStartUtc)
          ? afterCandidate
          : recurrenceStartUtc;
      final beforeUtc = rangeEnd.toUtc();
      if (beforeUtc.isBefore(recurrenceStartUtc)) continue;
      final starts = rule
          .getInstances(
            start: recurrenceStartUtc,
            after: rule.count == null ? afterUtc : null,
            includeAfter: true,
            before: beforeUtc,
          )
          .take(_maxExpandedOccurrences);

      for (final occurrenceUtc in starts) {
        final occurrenceStart = occurrenceUtc.toLocal();
        final occurrenceEnd = occurrenceStart.add(duration);
        if (!_eventRangeOverlaps(
          occurrenceStart,
          occurrenceEnd,
          rangeStart,
          rangeEnd,
        )) {
          continue;
        }
        expanded.add({
          ...event,
          'event_id': '$seriesId@${occurrenceUtc.toIso8601String()}',
          'series_event_id': seriesId,
          'series_start_at': event['start_at'],
          'series_end_at': event['end_at'],
          'is_occurrence': true,
          'occurrence_start_at': occurrenceStart.toIso8601String(),
          'start_at': occurrenceStart.toIso8601String(),
          'end_at': occurrenceEnd.toIso8601String(),
          'rrule': rrule,
        });
      }
    } catch (_) {
      expanded.add(event);
    }
  }

  return expanded;
}

String _calendarReminderLabel(int? minutes) {
  if (minutes == null || minutes < 0) return 'No reminder';
  if (minutes == 0) return 'At start time';
  if (minutes == 60) return '1 hour before';
  return '$minutes minutes before';
}

Duration _eventDuration(
  Map<String, dynamic> event,
  DateTime start,
  DateTime? end,
) {
  final fallback = _eventIsAllDay(event)
      ? const Duration(days: 1)
      : const Duration(hours: 1);
  if (end == null) return fallback;
  final duration = end.difference(start);
  return duration > Duration.zero ? duration : fallback;
}

bool _eventRangeOverlaps(
  DateTime start,
  DateTime end,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final safeEnd =
      end.isAfter(start) ? end : start.add(const Duration(hours: 1));
  return safeEnd.isAfter(rangeStart) && start.isBefore(rangeEnd);
}

@visibleForTesting
DateTime snapCalendarEventStartToGrid(
  DateTime value, {
  int granularityMinutes = _calendarDragSnapMinutes,
}) {
  final safeGranularity =
      granularityMinutes <= 0 ? _calendarDragSnapMinutes : granularityMinutes;
  final dayStart = DateTime(value.year, value.month, value.day);
  final minutes = value.difference(dayStart).inMinutes;
  final snappedMinutes = (minutes / safeGranularity).round() * safeGranularity;
  final clampedMinutes = _clampInt(
    snappedMinutes,
    0,
    24 * 60 - safeGranularity,
  );
  return dayStart.add(Duration(minutes: clampedMinutes));
}

@visibleForTesting
({DateTime startAt, DateTime endAt}) rescheduleCalendarEventTimes(
  Map<String, dynamic> event,
  DateTime targetStart,
) {
  final snappedStart = snapCalendarEventStartToGrid(targetStart);
  final currentStart = _eventDateTime(event, 'start_at') ?? snappedStart;
  final currentEnd = _eventDateTime(event, 'end_at');
  final duration = _eventDuration(event, currentStart, currentEnd);
  return (startAt: snappedStart, endAt: snappedStart.add(duration));
}

_CalendarRecurrencePreset _recurrencePresetForRRule(String? rrule) {
  if (rrule == null) return _CalendarRecurrencePreset.none;
  try {
    final rule = RecurrenceRule.fromString(
      rrule,
      options: const RecurrenceRuleFromStringOptions.lenient(),
    );
    final hasCustomParts = rule.count != null ||
        rule.until != null ||
        rule.hasByWeekDays ||
        rule.hasByMonthDays ||
        rule.hasByMonths;
    if (hasCustomParts) return _CalendarRecurrencePreset.custom;
    return switch (rule.frequency) {
      Frequency.daily => _CalendarRecurrencePreset.daily,
      Frequency.weekly => _CalendarRecurrencePreset.weekly,
      Frequency.monthly => _CalendarRecurrencePreset.monthly,
      Frequency.yearly => _CalendarRecurrencePreset.yearly,
      _ => _CalendarRecurrencePreset.custom,
    };
  } catch (_) {
    return _CalendarRecurrencePreset.custom;
  }
}

DateTime? _recurrenceUntilForRRule(String? rrule) {
  if (rrule == null) return null;
  try {
    return RecurrenceRule.fromString(
      rrule,
      options: const RecurrenceRuleFromStringOptions.lenient(),
    ).until?.toLocal();
  } catch (_) {
    return null;
  }
}

int? _recurrenceCountForRRule(String? rrule) {
  if (rrule == null) return null;
  try {
    return RecurrenceRule.fromString(
      rrule,
      options: const RecurrenceRuleFromStringOptions.lenient(),
    ).count;
  } catch (_) {
    return null;
  }
}

Set<int> _recurrenceWeekdaysForRRule(String? rrule, DateTime fallback) {
  if (rrule == null) return {fallback.weekday};
  try {
    final rule = RecurrenceRule.fromString(
      rrule,
      options: const RecurrenceRuleFromStringOptions.lenient(),
    );
    final weekdays = rule.byWeekDays.map((entry) => entry.day).toSet();
    return weekdays.isEmpty ? {fallback.weekday} : weekdays;
  } catch (_) {
    return {fallback.weekday};
  }
}

String _recurrencePresetLabel(_CalendarRecurrencePreset preset) {
  return switch (preset) {
    _CalendarRecurrencePreset.none => 'Does not repeat',
    _CalendarRecurrencePreset.daily => 'Daily',
    _CalendarRecurrencePreset.weekly => 'Weekly',
    _CalendarRecurrencePreset.monthly => 'Monthly',
    _CalendarRecurrencePreset.yearly => 'Yearly',
    _CalendarRecurrencePreset.custom => 'Custom',
  };
}

Frequency _frequencyForPreset(_CalendarRecurrencePreset preset) {
  return switch (preset) {
    _CalendarRecurrencePreset.daily => Frequency.daily,
    _CalendarRecurrencePreset.weekly => Frequency.weekly,
    _CalendarRecurrencePreset.monthly => Frequency.monthly,
    _CalendarRecurrencePreset.yearly => Frequency.yearly,
    _ => Frequency.weekly,
  };
}

DateTime _rruleUntilDate(DateTime date) {
  return DateTime.utc(date.year, date.month, date.day, 23, 59, 59);
}

String? _buildCalendarRRule({
  required _CalendarRecurrencePreset preset,
  required DateTime eventDate,
  DateTime? untilDate,
  int? count,
  Set<int> weekdays = const {},
}) {
  if (preset == _CalendarRecurrencePreset.none) return null;
  final normalizedCount = count != null && count > 0 ? count : null;
  final normalizedUntil = normalizedCount == null && untilDate != null
      ? _rruleUntilDate(untilDate)
      : null;
  final selectedWeekdays = weekdays.isEmpty ? {eventDate.weekday} : weekdays;
  final byWeekDays = selectedWeekdays.map(ByWeekDayEntry.new).toList()..sort();
  final rule = RecurrenceRule(
    frequency: _frequencyForPreset(preset),
    until: normalizedUntil,
    count: normalizedCount,
    byWeekDays:
        preset == _CalendarRecurrencePreset.custom ? byWeekDays : const [],
  );
  return rule.toString();
}

@visibleForTesting
List<Map<String, dynamic>> sortCalendarEventsForDisplay(
  Iterable<Map<String, dynamic>> events,
) {
  return events.toList()..sort(_compareCalendarEventsForDisplay);
}

@visibleForTesting
List<Map<String, dynamic>> searchCalendarEventsForDisplay(
  Iterable<Map<String, dynamic>> events,
  String query,
) {
  final sorted = sortCalendarEventsForDisplay(events);
  final terms = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList();
  if (terms.isEmpty) return sorted;

  return sorted.where((event) {
    final searchable = [
      _eventTitle(event),
      event['description']?.toString() ?? '',
    ].join(' ').toLowerCase();
    return terms.every(searchable.contains);
  }).toList();
}

int _compareCalendarEventsForDisplay(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final aAllDay = _eventIsAllDay(a);
  final bAllDay = _eventIsAllDay(b);
  if (aAllDay != bAllDay) return aAllDay ? -1 : 1;

  final byStart = _compareNullableDateTime(
    _eventDateTime(a, 'start_at'),
    _eventDateTime(b, 'start_at'),
  );
  if (byStart != 0) return byStart;

  final byEnd = _compareNullableDateTime(
    _eventDateTime(a, 'end_at'),
    _eventDateTime(b, 'end_at'),
  );
  if (byEnd != 0) return byEnd;

  return _eventTitle(a).compareTo(_eventTitle(b));
}

int _compareNullableDateTime(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

int _clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

class _CalendarListItem {
  const _CalendarListItem({
    required this.id,
    required this.name,
    required this.color,
    this.isDefault = false,
  });

  factory _CalendarListItem.fromMap(Map<String, dynamic> data) {
    final id = data['calendar_id']?.toString().trim() ?? '';
    final name = data['calendar_name']?.toString().trim() ?? '';
    return _CalendarListItem(
      id: id.isEmpty ? _defaultCalendarId : id,
      name: name.isEmpty ? _defaultCalendarName : name,
      color: _eventColorHex({'color': data['color']}),
      isDefault: data['is_default'] == true,
    );
  }

  final String id;
  final String name;
  final String color;
  final bool isDefault;
}

@visibleForTesting
class CalendarQuickAddDraft {
  const CalendarQuickAddDraft({
    required this.title,
    required this.date,
    required this.timeOfDay,
    this.durationMinutes = 60,
  });

  final String title;
  final DateTime date;
  final TimeOfDay? timeOfDay;
  final int durationMinutes;

  bool get allDay => timeOfDay == null;

  DateTime get wallStartAt {
    if (allDay) return DateTime(date.year, date.month, date.day);
    return DateTime(
      date.year,
      date.month,
      date.day,
      timeOfDay!.hour,
      timeOfDay!.minute,
    );
  }

  DateTime get wallEndAt => allDay
      ? wallStartAt
      : wallStartAt.add(Duration(minutes: durationMinutes));

  String get dateLabel => _formatDate(date);

  String get timeLabel => allDay
      ? 'All-day'
      : '${_formatClock(wallStartAt)} - ${_formatClock(wallEndAt)}';

  DateTime startAtForTimezone(String timezone) {
    if (allDay) return DateTime(date.year, date.month, date.day);
    return calendarWallTimeToUtc(
      date: date,
      hour: timeOfDay!.hour,
      minute: timeOfDay!.minute,
      timezone: timezone,
    );
  }

  DateTime? endAtForTimezone(String timezone) {
    if (allDay) return null;
    final end = wallEndAt;
    return calendarWallTimeToUtc(
      date: DateTime(end.year, end.month, end.day),
      hour: end.hour,
      minute: end.minute,
      timezone: timezone,
    );
  }
}

const Map<String, int> _quickAddWeekdayAliases = {
  '月曜': DateTime.monday,
  '月曜日': DateTime.monday,
  '火曜': DateTime.tuesday,
  '火曜日': DateTime.tuesday,
  '水曜': DateTime.wednesday,
  '水曜日': DateTime.wednesday,
  '木曜': DateTime.thursday,
  '木曜日': DateTime.thursday,
  '金曜': DateTime.friday,
  '金曜日': DateTime.friday,
  '土曜': DateTime.saturday,
  '土曜日': DateTime.saturday,
  '日曜': DateTime.sunday,
  '日曜日': DateTime.sunday,
};

@visibleForTesting
CalendarQuickAddDraft? parseCalendarQuickAddText(
  String input, {
  DateTime? now,
}) {
  var working = input.trim();
  if (working.isEmpty) return null;

  final baseNow = now ?? DateTime.now();
  final baseDate = DateTime(baseNow.year, baseNow.month, baseNow.day);
  var date = baseDate;

  void removeToken(String token) {
    working = working.replaceFirst(token, ' ');
  }

  final slashDateMatch = RegExp(r'(\d{1,2})/(\d{1,2})').firstMatch(working);
  final monthDayMatch = RegExp(r'(\d{1,2})月(\d{1,2})日?').firstMatch(working);
  if (slashDateMatch != null || monthDayMatch != null) {
    final match = slashDateMatch ?? monthDayMatch!;
    final month = int.tryParse(match.group(1) ?? '');
    final day = int.tryParse(match.group(2) ?? '');
    final parsed = month == null || day == null
        ? null
        : _quickAddMonthDayDate(month, day, baseDate);
    if (parsed == null) return null;
    date = parsed;
    removeToken(match.group(0)!);
  } else {
    final weekdayMatch = RegExp(
      r'(来週)?(月曜日|月曜|火曜日|火曜|水曜日|水曜|木曜日|木曜|金曜日|金曜|土曜日|土曜|日曜日|日曜)',
    ).firstMatch(working);
    if (weekdayMatch != null) {
      final weekday = _quickAddWeekdayAliases[weekdayMatch.group(2)]!;
      date = _quickAddWeekdayDate(
        baseDate,
        weekday,
        nextWeek: weekdayMatch.group(1) != null,
      );
      removeToken(weekdayMatch.group(0)!);
    } else if (working.contains('明後日')) {
      date = baseDate.add(const Duration(days: 2));
      removeToken('明後日');
    } else if (working.contains('明日')) {
      date = baseDate.add(const Duration(days: 1));
      removeToken('明日');
    } else if (working.contains('今日')) {
      removeToken('今日');
    } else if (working.contains('本日')) {
      removeToken('本日');
    }
  }

  final timeOfDay = _parseQuickAddTime(working);
  if (timeOfDay.token.isNotEmpty) removeToken(timeOfDay.token);

  return CalendarQuickAddDraft(
    title: _quickAddTitleFromRemainder(working),
    date: date,
    timeOfDay: timeOfDay.time,
  );
}

DateTime? _quickAddMonthDayDate(int month, int day, DateTime baseDate) {
  final candidate = DateTime(baseDate.year, month, day);
  if (candidate.month != month || candidate.day != day) return null;
  if (candidate.isBefore(baseDate)) {
    return DateTime(baseDate.year + 1, month, day);
  }
  return candidate;
}

DateTime _quickAddWeekdayDate(
  DateTime baseDate,
  int weekday, {
  required bool nextWeek,
}) {
  if (nextWeek) {
    final currentWeekMonday = baseDate.subtract(
      Duration(days: baseDate.weekday - DateTime.monday),
    );
    return currentWeekMonday
        .add(const Duration(days: 7))
        .add(Duration(days: weekday - DateTime.monday));
  }
  final delta = (weekday - baseDate.weekday) % DateTime.daysPerWeek;
  return baseDate.add(Duration(days: delta));
}

({TimeOfDay? time, String token}) _parseQuickAddTime(String input) {
  final clockMatch = RegExp(r'([01]?\d|2[0-3]):([0-5]\d)').firstMatch(input);
  if (clockMatch != null) {
    return (
      time: TimeOfDay(
        hour: int.parse(clockMatch.group(1)!),
        minute: int.parse(clockMatch.group(2)!),
      ),
      token: clockMatch.group(0)!,
    );
  }

  final japaneseTimeMatch = RegExp(
    r'(午前|午後)?\s*(\d{1,2})時(?:(\d{1,2})分|半)?',
  ).firstMatch(input);
  if (japaneseTimeMatch != null) {
    final ampm = japaneseTimeMatch.group(1);
    var hour = int.parse(japaneseTimeMatch.group(2)!);
    final minute = japaneseTimeMatch.group(0)!.contains('半')
        ? 30
        : int.tryParse(japaneseTimeMatch.group(3) ?? '') ?? 0;
    if (ampm == '午後' && hour < 12) hour += 12;
    if (ampm == '午前' && hour == 12) hour = 0;
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return (
        time: TimeOfDay(hour: hour, minute: minute),
        token: japaneseTimeMatch.group(0)!,
      );
    }
  }

  const namedTimes = {
    '朝': TimeOfDay(hour: 9, minute: 0),
    '昼': TimeOfDay(hour: 12, minute: 0),
    '正午': TimeOfDay(hour: 12, minute: 0),
    '夕方': TimeOfDay(hour: 17, minute: 0),
    '夜': TimeOfDay(hour: 19, minute: 0),
  };
  for (final entry in namedTimes.entries) {
    if (input.contains(entry.key)) {
      return (time: entry.value, token: entry.key);
    }
  }
  return (time: null, token: '');
}

String _quickAddTitleFromRemainder(String input) {
  var title = input
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s,、。・:：]+|[\s,、。・:：]+$'), '')
      .trim();
  title = title
      .replaceFirst(RegExp(r'^(に|で|から)\s*'), '')
      .replaceFirst(RegExp(r'\s*(に|で|から|まで)$'), '')
      .trim();
  return title.isEmpty ? '予定' : title;
}

class _CalendarEventsPageState extends State<CalendarEventsPage> {
  late final SupabaseClient _supabase =
      widget._supabaseClient ?? Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;

  // キー: 'YYYY-MM-DD', 値: イベントリスト
  final Map<String, List<Map<String, dynamic>>> _eventsByDate = {};
  final Map<String, Timer> _reminderTimers = {};
  final List<_CalendarListItem> _calendars = [
    const _CalendarListItem(
      id: _defaultCalendarId,
      name: _defaultCalendarName,
      color: _defaultCalendarColor,
      isDefault: true,
    ),
  ];
  final Set<String> _visibleCalendarIds = {_defaultCalendarId};

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  _CalendarView _calendarView = _CalendarView.month;
  bool _hasLoadedCalendars = false;
  bool _showOriginalTimezone = false;

  // 選択日のイベントリスト
  List<Map<String, dynamic>> get _selectedDayEvents {
    final key = _dateKey(_selectedDay);
    return sortCalendarEventsForDisplay(_eventsByDate[key] ?? []);
  }

  List<Map<String, dynamic>> get _allEvents {
    return sortCalendarEventsForDisplay(
      _eventsByDate.values.expand((events) {
        return events;
      }),
    );
  }

  _CalendarListItem get _defaultCalendar => _calendars.firstWhere(
        (calendar) => calendar.id == _defaultCalendarId,
        orElse: () => const _CalendarListItem(
          id: _defaultCalendarId,
          name: _defaultCalendarName,
          color: _defaultCalendarColor,
          isDefault: true,
        ),
      );

  _CalendarListItem _calendarForId(String id) {
    return _calendars.firstWhere(
      (calendar) => calendar.id == id,
      orElse: () => _defaultCalendar,
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Color _eventColor(Map<String, dynamic> event) {
    final hex = _eventColorHex(event).replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  NotificationService? _readNotificationService() {
    if (widget._notificationService != null) {
      return widget._notificationService;
    }
    try {
      return context.read<NotificationService>();
    } catch (_) {
      return null;
    }
  }

  void _rescheduleLoadedReminders() {
    for (final timer in _reminderTimers.values) {
      timer.cancel();
    }
    _reminderTimers.clear();
    for (final event in _allEvents) {
      _scheduleInAppReminderTimer(event);
    }
  }

  void _scheduleInAppReminderTimer(Map<String, dynamic> event) {
    final eventId = event['event_id']?.toString() ?? '';
    if (eventId.isEmpty) return;
    _reminderTimers.remove(eventId)?.cancel();

    final reminderMinutes = calendarEventReminderMinutes(event);
    final start = _eventDateTime(event, 'start_at');
    if (reminderMinutes == null || start == null) return;

    final dueAt = start.subtract(Duration(minutes: reminderMinutes));
    final delay = dueAt.difference(DateTime.now());
    if (delay <= Duration.zero) return;

    _reminderTimers[eventId] = Timer(delay, () {
      _reminderTimers.remove(eventId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_eventTitle(event)} - ${_calendarReminderLabel(reminderMinutes)}',
          ),
        ),
      );
    });
  }

  void _cancelInAppReminderTimer(String eventId) {
    _reminderTimers.remove(eventId)?.cancel();
  }

  void _setOriginalTimezoneDisplay(bool value) {
    if (_showOriginalTimezone == value) return;
    setState(() => _showOriginalTimezone = value);
    _fetchMonth(_focusedDay);
  }

  Future<void> _syncDeviceReminder({
    required String eventId,
    required String title,
    required DateTime startAt,
    required int? reminderMinutes,
    bool cancelWhenNone = false,
  }) async {
    if (eventId.isEmpty || kIsWeb) return;
    final notificationService = _readNotificationService();
    if (notificationService == null) return;
    try {
      if (reminderMinutes == null) {
        if (cancelWhenNone) {
          await notificationService.cancelCalendarEventReminder(
            eventId: eventId,
          );
        }
        return;
      }
      await notificationService.scheduleCalendarEventReminder(
        eventId: eventId,
        title: title,
        startAt: startAt,
        reminderMinutes: reminderMinutes,
      );
    } catch (e) {
      debugPrint('Calendar reminder sync failed: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    ensureCalendarTimeZonesInitialized();
    _fetchMonth(_focusedDay);
  }

  @override
  void dispose() {
    for (final timer in _reminderTimers.values) {
      timer.cancel();
    }
    _reminderTimers.clear();
    super.dispose();
  }

  Future<void> _fetchCalendars() async {
    final res = await _supabase.functions.invoke(
      'app-hub',
      body: {'action': 'calendar.list_calendars'},
    );
    final data = res.data;
    final rawCalendars =
        data is Map<String, dynamic> && data['calendars'] is List
            ? data['calendars'] as List
            : <dynamic>[];
    final nextCalendars = <_CalendarListItem>[];
    for (final raw in rawCalendars) {
      if (raw is! Map) continue;
      nextCalendars.add(
        _CalendarListItem.fromMap(Map<String, dynamic>.from(raw)),
      );
    }
    if (nextCalendars.every((calendar) => calendar.id != _defaultCalendarId)) {
      nextCalendars.insert(
        0,
        const _CalendarListItem(
          id: _defaultCalendarId,
          name: _defaultCalendarName,
          color: _defaultCalendarColor,
          isDefault: true,
        ),
      );
    }
    final knownIds = nextCalendars.map((calendar) => calendar.id).toSet();
    setState(() {
      final shouldSelectAll = !_hasLoadedCalendars ||
          (_visibleCalendarIds.length == _calendars.length &&
              _calendars.every(
                (calendar) => _visibleCalendarIds.contains(calendar.id),
              ));
      _calendars
        ..clear()
        ..addAll(nextCalendars);
      _hasLoadedCalendars = true;
      _visibleCalendarIds
        ..removeWhere((id) => !knownIds.contains(id))
        ..addAll(
          shouldSelectAll || _visibleCalendarIds.isEmpty
              ? knownIds
              : const <String>{},
        );
      if (_visibleCalendarIds.isEmpty) {
        _visibleCalendarIds.add(_defaultCalendarId);
      }
    });
  }

  Future<void> _fetchMonth(DateTime month) async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _fetchCalendars();
      final res = await _supabase.functions.invoke(
        'app-hub',
        body: _visibleCalendarIds.length == _calendars.length
            ? {'action': 'calendar.list'}
            : {
                'action': 'calendar.list',
                'calendar_ids': _visibleCalendarIds.toList(),
              },
      );
      final data = res.data;
      final rawEvents = data is Map<String, dynamic> && data['events'] is List
          ? data['events'] as List
          : <dynamic>[];

      final monthStart = DateTime(month.year, month.month);
      final visibleRangeStart = monthStart.subtract(const Duration(days: 7));
      final visibleRangeEnd = DateTime(
        month.year,
        month.month + 1,
      ).add(const Duration(days: 7));
      final newMap = <String, List<Map<String, dynamic>>>{};
      final parsedEvents = <Map<String, dynamic>>[];
      for (final raw in rawEvents) {
        if (raw is Map) parsedEvents.add(Map<String, dynamic>.from(raw));
      }
      for (final ev in expandRecurringCalendarEventsForRange(
        parsedEvents,
        rangeStart: visibleRangeStart,
        rangeEnd: visibleRangeEnd,
      )) {
        final startAt = ev['start_at']?.toString() ?? '';
        if (startAt.isEmpty) continue;
        final date = _eventDateTime(
          ev,
          'start_at',
          showOriginalTimezone: _showOriginalTimezone,
        );
        if (date == null) continue;
        final key = _dateKey(date);
        newMap.putIfAbsent(key, () => []).add(ev);
      }

      if (mounted) {
        setState(() {
          _eventsByDate
            ..clear()
            ..addAll(newMap);
        });
        _rescheduleLoadedReminders();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'イベントの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createEvent({
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    String description = '',
    bool allDay = false,
    String color = '#4285f4',
    int? reminderMinutes,
    String calendarId = _defaultCalendarId,
    String? rrule,
    String? timezone,
  }) async {
    try {
      final normalizedTimezone = normalizeCalendarTimezone(timezone);
      final end =
          allDay ? startAt : (endAt ?? startAt.add(const Duration(hours: 1)));
      final res = await _supabase.functions.invoke(
        'app-hub',
        body: {
          'action': 'calendar.create',
          'title': title,
          'description': description,
          'start_at': startAt.toIso8601String(),
          'end_at': end.toIso8601String(),
          'all_day': allDay,
          'color': color,
          'reminder_min': reminderMinutes,
          'calendar_id': calendarId,
          'rrule': rrule,
          'timezone': normalizedTimezone,
        },
      );
      final data = res.data;
      final savedEvent = data is Map ? data['event'] : null;
      final eventId =
          savedEvent is Map ? savedEvent['event_id']?.toString() ?? '' : '';
      if (eventId.isNotEmpty && reminderMinutes != null) {
        _scheduleInAppReminderTimer({
          'event_id': eventId,
          'title': title,
          'start_at': startAt.toIso8601String(),
          'end_at': end.toIso8601String(),
          'all_day': allDay,
          'reminder_min': reminderMinutes,
          'calendar_id': calendarId,
          'calendar_name': _calendarForId(calendarId).name,
          'rrule': rrule,
          'timezone': normalizedTimezone,
        });
        await _syncDeviceReminder(
          eventId: eventId,
          title: title,
          startAt: startAt,
          reminderMinutes: reminderMinutes,
        );
      }
      await _fetchMonth(_focusedDay);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'イベントの作成に失敗しました: $e');
      }
    }
  }

  Future<void> _updateEvent({
    required String eventId,
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    String description = '',
    bool allDay = false,
    String color = '#4285f4',
    int? reminderMinutes,
    String calendarId = _defaultCalendarId,
    String? rrule,
    String? timezone,
    bool cancelReminderWhenNone = false,
  }) async {
    if (eventId.isEmpty) {
      setState(() => _errorMessage = 'Event id is missing.');
      return;
    }
    try {
      final normalizedTimezone = normalizeCalendarTimezone(timezone);
      final end =
          allDay ? startAt : (endAt ?? startAt.add(const Duration(hours: 1)));
      await _supabase.functions.invoke(
        'app-hub',
        body: {
          'action': 'calendar.update',
          'id': eventId,
          'title': title,
          'description': description,
          'start_at': startAt.toIso8601String(),
          'end_at': end.toIso8601String(),
          'all_day': allDay,
          'color': color,
          'reminder_min': reminderMinutes,
          'calendar_id': calendarId,
          'rrule': rrule,
          'timezone': normalizedTimezone,
        },
      );
      if (reminderMinutes == null) {
        if (cancelReminderWhenNone) {
          _cancelInAppReminderTimer(eventId);
        }
      } else {
        _scheduleInAppReminderTimer({
          'event_id': eventId,
          'title': title,
          'start_at': startAt.toIso8601String(),
          'end_at': end.toIso8601String(),
          'all_day': allDay,
          'reminder_min': reminderMinutes,
          'calendar_id': calendarId,
          'calendar_name': _calendarForId(calendarId).name,
          'rrule': rrule,
          'timezone': normalizedTimezone,
        });
      }
      await _syncDeviceReminder(
        eventId: eventId,
        title: title,
        startAt: startAt,
        reminderMinutes: reminderMinutes,
        cancelWhenNone: cancelReminderWhenNone,
      );
      await _fetchMonth(_focusedDay);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to update event: $e');
      }
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'calendar.delete', 'id': eventId},
      );
      _cancelInAppReminderTimer(eventId);
      await _syncDeviceReminder(
        eventId: eventId,
        title: '',
        startAt: DateTime.now(),
        reminderMinutes: null,
        cancelWhenNone: true,
      );
      await _fetchMonth(_focusedDay);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'イベントの削除に失敗しました: $e');
      }
    }
  }

  Future<void> _handleIcsAction(_CalendarIcsAction action) async {
    switch (action) {
      case _CalendarIcsAction.export:
        await _exportCalendarIcs();
        break;
      case _CalendarIcsAction.import:
        await _importCalendarIcs();
        break;
    }
  }

  Future<void> _exportCalendarIcs() async {
    final ics = buildCalendarEventsIcs(_allEvents);
    if (!ics.contains('BEGIN:VEVENT')) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No events to export')));
      return;
    }

    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = 'calendar-events-$stamp.ics';
    if (kIsWeb) {
      downloadTextFile(ics, fileName, mimeType: 'text/calendar;charset=utf-8');
    } else {
      final bytes = Uint8List.fromList(utf8.encode(ics));
      final file = XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'text/calendar',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [fileName],
          subject: fileName,
          text: 'Calendar events export',
        ),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Exported $fileName')));
  }

  Future<void> _importCalendarIcs() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['ics', 'ical'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null) {
        throw StateError('Selected .ics file could not be read.');
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final parsed = parseCalendarEventsIcs(
        content,
        existingUids: calendarIcsUidsFromEvents(_allEvents),
      );
      if (parsed.events.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              parsed.skippedDuplicateCount > 0
                  ? 'All imported events were duplicates.'
                  : 'No importable events found in the .ics file.',
            ),
          ),
        );
        return;
      }

      final res = await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'calendar.bulk_create', 'events': parsed.events},
      );
      final data = res.data;
      final createdCount = data is Map
          ? (data['created_count'] as num?)?.toInt() ?? parsed.events.length
          : parsed.events.length;
      final backendSkipped = data is Map
          ? (data['skipped_duplicate_count'] as num?)?.toInt() ?? 0
          : 0;
      await _fetchMonth(_focusedDay);

      if (!mounted) return;
      final skipped = parsed.skippedDuplicateCount + backendSkipped;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            skipped > 0
                ? 'Imported $createdCount events. Skipped $skipped duplicates.'
                : 'Imported $createdCount events.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to import .ics file: $e');
      }
    }
  }

  Future<void> _createCalendar({
    required String name,
    required String color,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      final res = await _supabase.functions.invoke(
        'app-hub',
        body: {
          'action': 'calendar.create_calendar',
          'calendar_name': trimmed,
          'color': color,
        },
      );
      final data = res.data;
      final calendar = data is Map ? data['calendar'] : null;
      final calendarId =
          calendar is Map ? calendar['calendar_id']?.toString() ?? '' : '';
      if (calendarId.isNotEmpty) {
        _visibleCalendarIds.add(calendarId);
      }
      await _fetchMonth(_focusedDay);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to add calendar: $e');
    }
  }

  Future<void> _deleteCalendar(String calendarId) async {
    if (calendarId == _defaultCalendarId) return;
    try {
      await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'calendar.delete_calendar', 'calendar_id': calendarId},
      );
      _visibleCalendarIds.remove(calendarId);
      await _fetchMonth(_focusedDay);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to delete calendar: $e');
      }
    }
  }

  void _toggleCalendarVisibility(String calendarId, bool visible) {
    setState(() {
      if (visible) {
        _visibleCalendarIds.add(calendarId);
      } else if (_visibleCalendarIds.length > 1) {
        _visibleCalendarIds.remove(calendarId);
      }
    });
    _fetchMonth(_focusedDay);
  }

  List<Map<String, dynamic>> _eventsLoader(DateTime day) {
    return sortCalendarEventsForDisplay(_eventsByDate[_dateKey(day)] ?? []);
  }

  void _setCalendarView(_CalendarView view) {
    setState(() {
      _calendarView = view;
      _calendarFormat = view == _CalendarView.week
          ? CalendarFormat.week
          : CalendarFormat.month;
      if (view == _CalendarView.day) {
        _focusedDay = _selectedDay;
      }
    });
  }

  void _moveSelectedDay(int deltaDays) {
    final next = _selectedDay.add(Duration(days: deltaDays));
    setState(() {
      _selectedDay = next;
      _focusedDay = next;
    });
    _fetchMonth(next);
  }

  Future<void> _moveTimedEvent(
    Map<String, dynamic> event,
    DateTime targetStart,
  ) async {
    final eventId = calendarEventSeriesId(event);
    if (eventId.isEmpty ||
        _eventIsAllDay(event) ||
        calendarEventIsRecurrenceOccurrence(event)) {
      return;
    }
    final nextTimes = rescheduleCalendarEventTimes(event, targetStart);
    await _updateEvent(
      eventId: eventId,
      title: _eventTitle(event),
      description: event['description']?.toString() ?? '',
      startAt: nextTimes.startAt,
      endAt: nextTimes.endAt,
      allDay: false,
      color: _eventColorHex(event),
      reminderMinutes: calendarEventReminderMinutes(event),
      calendarId: calendarEventCalendarId(event),
      rrule: calendarEventRRule(event),
      timezone: calendarEventTimezone(event),
    );
  }

  Future<void> _showEventSearch() async {
    final selectedEvent = await showSearch<Map<String, dynamic>?>(
      context: context,
      delegate: _CalendarEventSearchDelegate(events: _allEvents),
    );
    if (selectedEvent == null || !mounted) return;
    final start = _eventDateTime(selectedEvent, 'start_at');
    if (start == null) return;
    final selected = DateTime(start.year, start.month, start.day);
    setState(() {
      _selectedDay = selected;
      _focusedDay = selected;
    });
  }

  void _confirmDeleteEvent(BuildContext context, Map<String, dynamic> event) {
    final eventId = calendarEventSeriesId(event);
    if (eventId.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${_eventTitle(event)}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteEvent(eventId);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  String _eventDetailsText(Map<String, dynamic> event) {
    final buffer = StringBuffer()
      ..writeln(_eventTitle(event))
      ..writeln(
        _eventDateTimeLabel(event, showOriginalTimezone: _showOriginalTimezone),
      );
    final description = event['description']?.toString().trim() ?? '';
    if (description.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(description);
    }
    buffer
      ..writeln()
      ..writeln('Calendar: ${calendarEventCalendarName(event)}')
      ..writeln('Timezone: ${_eventTimezoneLabel(event)}')
      ..writeln('Repeats: ${calendarEventRecurrenceLabel(event)}')
      ..writeln('Color: ${_eventColorHex(event)}');
    final eventId = event['event_id']?.toString() ?? '';
    if (eventId.isNotEmpty) {
      buffer.writeln('Event ID: $eventId');
    }
    return buffer.toString().trim();
  }

  String _metadataValue(Object? value) {
    if (value == null) return '-';
    if (value is DateTime) return value.toIso8601String();
    return value.toString();
  }

  List<({String label, String value})> _eventMetadataRows(
    Map<String, dynamic> event,
  ) {
    final entries = event.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return [
      for (final entry in entries)
        (label: entry.key, value: _metadataValue(entry.value)),
    ];
  }

  Future<void> _copyEventDetails(
    BuildContext context,
    Map<String, dynamic> event,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _eventDetailsText(event)));
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Event details copied')),
    );
  }

  Future<void> _shareEventDetails(Map<String, dynamic> event) async {
    await SharePlus.instance.share(
      ShareParams(text: _eventDetailsText(event), subject: _eventTitle(event)),
    );
  }

  void _showEventDetailsSheet(
    BuildContext context,
    Map<String, dynamic> event,
  ) {
    final color = _eventColor(event);
    final description = event['description']?.toString().trim() ?? '';
    final metadataRows = _eventMetadataRows(event);
    final rrule = calendarEventRRule(event);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.16),
                      child: Icon(Icons.event, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _eventTitle(event),
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _eventDateTimeLabel(
                              event,
                              showOriginalTimezone: _showOriginalTimezone,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Chip(
                            avatar: _ColorDot(
                              colorHex: _calendarForId(
                                calendarEventCalendarId(event),
                              ).color,
                            ),
                            label: Text(calendarEventCalendarName(event)),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (rrule != null)
                            Chip(
                              avatar: const Icon(Icons.repeat, size: 18),
                              label: Text(calendarEventRecurrenceLabel(event)),
                              visualDensity: VisualDensity.compact,
                            ),
                          Chip(
                            avatar: const Icon(Icons.public, size: 18),
                            label: Text(_eventTimezoneLabel(event)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Description', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(description, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _eventColorHex(event),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _showEditEventDialog(context, event);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _confirmDeleteEvent(context, event);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.content_copy),
                      label: const Text('Copy'),
                      onPressed: () => _copyEventDetails(sheetContext, event),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share'),
                      onPressed: () => _shareEventDetails(event),
                    ),
                  ],
                ),
                if (metadataRows.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Metadata', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        for (final row in metadataRows)
                          _EventMetadataRow(label: row.label, value: row.value),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final usesTimeline = _calendarView == _CalendarView.day ||
        _calendarView == _CalendarView.week;

    return Scaffold(
      drawer: _CalendarFilterDrawer(
        calendars: _calendars,
        visibleCalendarIds: _visibleCalendarIds,
        showOriginalTimezone: _showOriginalTimezone,
        onToggle: _toggleCalendarVisibility,
        onToggleOriginalTimezone: _setOriginalTimezoneDisplay,
        onAddCalendar: () => _showAddCalendarDialog(context),
        onDeleteCalendar: _confirmDeleteCalendar,
      ),
      appBar: AppBar(
        title: const Text('カレンダー'),
        actions: [
          IconButton(
            key: const Key('calendar_events_quick_add_button'),
            icon: const Icon(Icons.flash_on),
            tooltip: 'Quick add event',
            onPressed: () => _showQuickAddDialog(context),
          ),
          IconButton(
            key: const Key('calendar_events_search_button'),
            icon: const Icon(Icons.search),
            tooltip: 'Search events',
            onPressed: _showEventSearch,
          ),
          PopupMenuButton<_CalendarIcsAction>(
            key: const Key('calendar_events_ics_menu'),
            tooltip: 'Import or export iCal',
            icon: const Icon(Icons.more_vert),
            onSelected: _handleIcsAction,
            itemBuilder: (context) => const [
              PopupMenuItem<_CalendarIcsAction>(
                key: Key('calendar_events_export_ics'),
                value: _CalendarIcsAction.export,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.file_download_outlined),
                  title: Text('Export .ics'),
                ),
              ),
              PopupMenuItem<_CalendarIcsAction>(
                key: Key('calendar_events_import_ics'),
                value: _CalendarIcsAction.import,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.file_upload_outlined),
                  title: Text('Import .ics'),
                ),
              ),
            ],
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '更新',
              onPressed: () => _fetchMonth(_focusedDay),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _CalendarViewSwitcher(
            selectedView: _calendarView,
            onChanged: _setCalendarView,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            MaterialBanner(
              content: Text(_errorMessage!),
              backgroundColor: const Color(0xFFFFEBEE),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _errorMessage = null),
                  child: const Text('閉じる'),
                ),
              ],
            ),
          if (_calendarView != _CalendarView.day)
            TableCalendar<Map<String, dynamic>>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              eventLoader: _eventsLoader,
              startingDayOfWeek: StartingDayOfWeek.monday,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                  _calendarView = format == CalendarFormat.week
                      ? _CalendarView.week
                      : _CalendarView.month;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _fetchMonth(focusedDay);
              },
              calendarStyle: CalendarStyle(
                markerDecoration: const BoxDecoration(
                  color: Color(0xFF4285F4),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            )
          else
            _DayViewHeader(
              selectedDay: _selectedDay,
              onPreviousDay: () => _moveSelectedDay(-1),
              onNextDay: () => _moveSelectedDay(1),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_selectedDay.month}月${_selectedDay.day}日のイベント',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${_selectedDayEvents.length}件',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: usesTimeline
                ? _DayTimelineView(
                    selectedDay: _selectedDay,
                    events: _selectedDayEvents,
                    showOriginalTimezone: _showOriginalTimezone,
                    onTap: (event) => _showEventDetailsSheet(context, event),
                    onDelete: (event) => _confirmDeleteEvent(context, event),
                    onMove: _moveTimedEvent,
                  )
                : _selectedDayEvents.isEmpty
                    ? Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 48,
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'この日のイベントはありません',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _selectedDayEvents.length,
                        itemBuilder: (context, index) {
                          final event = _selectedDayEvents[index];
                          return _EventCard(
                            event: event,
                            color: _eventColor(event),
                            showOriginalTimezone: _showOriginalTimezone,
                            onTap: () => _showEventDetailsSheet(context, event),
                            onDelete: () {
                              final eventId = calendarEventSeriesId(event);
                              if (eventId.isEmpty) return;
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('削除確認'),
                                  content: Text('「${event['title']}」を削除しますか？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('キャンセル'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFE53935),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _deleteEvent(eventId);
                                      },
                                      child: const Text('削除'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(context),
        tooltip: 'イベントを追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEventDialog(BuildContext context) {
    _showEventDialog(context);
  }

  void _showQuickAddDialog(BuildContext context) {
    final textCtrl = TextEditingController();
    String? errorText;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Quick add event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('calendar_quick_add_field'),
                controller: textCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Example: 明日 14:00 ミーティング',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bolt),
                ),
                onSubmitted: (_) {
                  final draft = parseCalendarQuickAddText(textCtrl.text);
                  if (draft == null) {
                    setDialogState(
                      () => errorText = 'Enter an event title, date, or time.',
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  _showQuickAddPreviewDialog(context, draft);
                },
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              key: const Key('calendar_quick_add_preview_button'),
              icon: const Icon(Icons.visibility),
              label: const Text('Preview'),
              onPressed: () {
                final draft = parseCalendarQuickAddText(textCtrl.text);
                if (draft == null) {
                  setDialogState(
                    () => errorText = 'Enter an event title, date, or time.',
                  );
                  return;
                }
                Navigator.pop(ctx);
                _showQuickAddPreviewDialog(context, draft);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAddPreviewDialog(
    BuildContext context,
    CalendarQuickAddDraft draft,
  ) {
    final timezone = calendarDefaultTimezone();
    final calendar = _defaultCalendar;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Preview event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(draft.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _EventMetadataRow(label: 'Date', value: draft.dateLabel),
            _EventMetadataRow(label: 'Time', value: draft.timeLabel),
            _EventMetadataRow(label: 'Calendar', value: calendar.name),
            _EventMetadataRow(
              label: 'Timezone',
              value: '$timezone (${calendarTimezoneAbbreviation(timezone)})',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            key: const Key('calendar_quick_add_create_button'),
            icon: const Icon(Icons.add),
            label: const Text('Create'),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedDay = draft.date;
                _focusedDay = draft.date;
              });
              _createEvent(
                title: draft.title,
                startAt: draft.startAtForTimezone(timezone),
                endAt: draft.endAtForTimezone(timezone),
                allDay: draft.allDay,
                color: calendar.color,
                calendarId: calendar.id,
                timezone: timezone,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddCalendarDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final colors = ['#4285f4', '#ea4335', '#34a853', '#fbbc05', '#9334e6'];
    var selectedColor = colors.first;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add calendar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('calendar_name_field'),
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Calendar name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final color in colors)
                    GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: _ColorDot(
                        colorHex: color,
                        selected: selectedColor == color,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                _createCalendar(name: name, color: selectedColor);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCalendar(_CalendarListItem calendar) {
    if (calendar.isDefault) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete calendar'),
        content: Text(
          'Delete "${calendar.name}"? Existing events move to Default.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCalendar(calendar.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditEventDialog(
    BuildContext context,
    Map<String, dynamic> event,
  ) async {
    var scope = _RecurrenceEditScope.all;
    if (calendarEventRRule(event) != null) {
      final selectedScope = await _chooseRecurrenceEditScope(context, event);
      if (!context.mounted || selectedScope == null) return;
      scope = selectedScope;
      if (scope != _RecurrenceEditScope.all) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This recurrence scope needs series exception support. Choose all events for now.',
            ),
          ),
        );
        return;
      }
    }
    if (!context.mounted) return;
    _showEventDialog(context, event: event, recurrenceScope: scope);
  }

  Future<_RecurrenceEditScope?> _chooseRecurrenceEditScope(
    BuildContext context,
    Map<String, dynamic> event,
  ) {
    return showDialog<_RecurrenceEditScope>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit recurring event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('calendar_edit_scope_this'),
              leading: const Icon(Icons.event),
              title: const Text('This event only'),
              subtitle: Text(
                _eventDateTimeLabel(
                  event,
                  showOriginalTimezone: _showOriginalTimezone,
                ),
              ),
              onTap: () => Navigator.pop(ctx, _RecurrenceEditScope.thisEvent),
            ),
            ListTile(
              key: const Key('calendar_edit_scope_following'),
              leading: const Icon(Icons.update),
              title: const Text('This and following events'),
              onTap: () => Navigator.pop(ctx, _RecurrenceEditScope.following),
            ),
            ListTile(
              key: const Key('calendar_edit_scope_all'),
              leading: const Icon(Icons.repeat),
              title: const Text('All events'),
              onTap: () => Navigator.pop(ctx, _RecurrenceEditScope.all),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _eventForRecurrenceEdit(
    Map<String, dynamic> event,
    _RecurrenceEditScope scope,
  ) {
    if (scope != _RecurrenceEditScope.all ||
        !calendarEventIsRecurrenceOccurrence(event)) {
      return event;
    }
    return {
      ...event,
      'event_id': calendarEventSeriesId(event),
      'start_at': event['series_start_at'] ?? event['start_at'],
      'end_at': event['series_end_at'] ?? event['end_at'],
      'is_occurrence': false,
    };
  }

  void _showEventDialog(
    BuildContext context, {
    Map<String, dynamic>? event,
    _RecurrenceEditScope recurrenceScope = _RecurrenceEditScope.all,
  }) {
    final isEditing = event != null;
    final editEvent =
        event == null ? null : _eventForRecurrenceEdit(event, recurrenceScope);
    final eventId = editEvent == null ? '' : calendarEventSeriesId(editEvent);
    final initialStart = editEvent == null
        ? _selectedDay
        : (_eventDateTime(editEvent, 'start_at', showOriginalTimezone: true) ??
            _selectedDay);
    final initialEnd = editEvent == null
        ? initialStart.add(const Duration(hours: 1))
        : (_eventDateTime(editEvent, 'end_at', showOriginalTimezone: true) ??
            initialStart.add(const Duration(hours: 1)));
    final titleCtrl = TextEditingController(
      text: editEvent?['title']?.toString() ?? '',
    );
    final descCtrl = TextEditingController(
      text: editEvent?['description']?.toString() ?? '',
    );
    var eventDate = DateTime(
      initialStart.year,
      initialStart.month,
      initialStart.day,
    );
    var allDay = editEvent == null ? false : _eventIsAllDay(editEvent);
    var startTime = TimeOfDay.fromDateTime(initialStart);
    var endTime = TimeOfDay.fromDateTime(initialEnd);
    final colors = ['#4285f4', '#ea4335', '#34a853', '#fbbc05', '#9334e6'];
    var selectedColor =
        editEvent == null ? colors.first : _eventColorHex(editEvent);
    if (!colors.contains(selectedColor)) {
      selectedColor = colors.first;
    }
    var selectedCalendarId = calendarEventCalendarId(editEvent ?? {});
    if (_calendars.every((calendar) => calendar.id != selectedCalendarId)) {
      selectedCalendarId = _defaultCalendarId;
    }
    var selectedTimezone = editEvent == null
        ? calendarDefaultTimezone()
        : calendarEventTimezone(editEvent);
    var selectedReminder = calendarEventReminderMinutes(editEvent ?? {}) ?? -1;
    final initialRRule = calendarEventRRule(editEvent ?? {});
    var selectedRecurrence = _recurrencePresetForRRule(initialRRule);
    var recurrenceUntil = _recurrenceUntilForRRule(initialRRule);
    final recurrenceCountCtrl = TextEditingController(
      text: _recurrenceCountForRRule(initialRRule)?.toString() ?? '',
    );
    var selectedWeekdays = _recurrenceWeekdaysForRRule(
      initialRRule,
      initialStart,
    );

    String fmtTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'イベントを編集' : 'イベントを追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'タイトル *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: '説明',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('calendar_calendar_dropdown'),
                  initialValue: selectedCalendarId,
                  decoration: const InputDecoration(
                    labelText: 'Calendar',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  items: [
                    for (final calendar in _calendars)
                      DropdownMenuItem<String>(
                        value: calendar.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ColorDot(colorHex: calendar.color),
                            const SizedBox(width: 8),
                            Flexible(child: Text(calendar.name)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    final calendar = _calendarForId(value);
                    setDialogState(() {
                      selectedCalendarId = value;
                      selectedColor = calendar.color;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: eventDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => eventDate = picked);
                        }
                      },
                      child: Text(
                        '${eventDate.year}/${eventDate.month}/${eventDate.day}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('calendar_timezone_dropdown'),
                  initialValue: selectedTimezone,
                  decoration: const InputDecoration(
                    labelText: 'Timezone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.public),
                  ),
                  items: [
                    for (final timezone in calendarTimezoneDropdownOptions(
                      selectedTimezone,
                    ))
                      DropdownMenuItem<String>(
                        value: timezone,
                        child: Text(timezone),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedTimezone = value);
                  },
                ),
                Row(
                  children: [
                    Checkbox(
                      value: allDay,
                      onChanged: (v) =>
                          setDialogState(() => allDay = v ?? false),
                    ),
                    const Text('終日'),
                  ],
                ),
                if (!allDay) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 18),
                      const SizedBox(width: 8),
                      const Text('開始'),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: startTime,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              startTime = picked;
                              final startMinutes =
                                  picked.hour * 60 + picked.minute;
                              final endMinutes =
                                  endTime.hour * 60 + endTime.minute;
                              if (endMinutes <= startMinutes) {
                                final next = startMinutes + 60;
                                endTime = TimeOfDay(
                                  hour: (next ~/ 60) % 24,
                                  minute: next % 60,
                                );
                              }
                            });
                          }
                        },
                        child: Text(fmtTime(startTime)),
                      ),
                      const SizedBox(width: 8),
                      const Text('終了'),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: endTime,
                          );
                          if (picked != null) {
                            setDialogState(() => endTime = picked);
                          }
                        },
                        child: Text(fmtTime(endTime)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: const Key('calendar_reminder_dropdown'),
                  initialValue: selectedReminder,
                  decoration: const InputDecoration(
                    labelText: 'Reminder',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notifications_none),
                  ),
                  items: [
                    for (final minutes in _calendarReminderOptions)
                      DropdownMenuItem<int>(
                        value: minutes,
                        child: Text(
                          _calendarReminderLabel(minutes < 0 ? null : minutes),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedReminder = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_CalendarRecurrencePreset>(
                  key: const Key('calendar_recurrence_dropdown'),
                  initialValue: selectedRecurrence,
                  decoration: const InputDecoration(
                    labelText: 'Repeat',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  items: [
                    for (final preset in _CalendarRecurrencePreset.values)
                      DropdownMenuItem<_CalendarRecurrencePreset>(
                        value: preset,
                        child: Text(_recurrencePresetLabel(preset)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      selectedRecurrence = value;
                      if (selectedRecurrence ==
                          _CalendarRecurrencePreset.none) {
                        recurrenceUntil = null;
                        recurrenceCountCtrl.clear();
                      }
                      if (selectedWeekdays.isEmpty) {
                        selectedWeekdays = {eventDate.weekday};
                      }
                    });
                  },
                ),
                if (selectedRecurrence == _CalendarRecurrencePreset.custom) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final entry in _weekdayLabels.entries)
                        FilterChip(
                          key: Key('calendar_recurrence_weekday_${entry.key}'),
                          label: Text(entry.value),
                          selected: selectedWeekdays.contains(entry.key),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedWeekdays.add(entry.key);
                              } else if (selectedWeekdays.length > 1) {
                                selectedWeekdays.remove(entry.key);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('calendar_recurrence_until_button'),
                          icon: const Icon(Icons.event_available),
                          label: Text(
                            recurrenceUntil == null
                                ? 'Until date'
                                : 'Until ${_formatDate(recurrenceUntil!)}',
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: recurrenceUntil ?? eventDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDialogState(() => recurrenceUntil = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          key: const Key('calendar_recurrence_count_field'),
                          controller: recurrenceCountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Count',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                const Text('カラー:', style: TextStyle(fontSize: 13, height: 1.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: colors
                      .map(
                        (c) => GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                  'FF${c.replaceFirst('#', '')}',
                                  radix: 16,
                                ),
                              ),
                              shape: BoxShape.circle,
                              border: selectedColor == c
                                  ? Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      width: 2.5,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(ctx);
                final startDateTime = allDay
                    ? DateTime(eventDate.year, eventDate.month, eventDate.day)
                    : calendarWallTimeToUtc(
                        date: eventDate,
                        hour: startTime.hour,
                        minute: startTime.minute,
                        timezone: selectedTimezone,
                      );
                final endDateTime = allDay
                    ? null
                    : calendarWallTimeToUtc(
                        date: eventDate,
                        hour: endTime.hour,
                        minute: endTime.minute,
                        timezone: selectedTimezone,
                      );
                final reminderMinutes =
                    selectedReminder < 0 ? null : selectedReminder;
                final recurrenceCount = int.tryParse(
                  recurrenceCountCtrl.text.trim(),
                );
                final rrule = _buildCalendarRRule(
                  preset: selectedRecurrence,
                  eventDate: eventDate,
                  untilDate: recurrenceUntil,
                  count: recurrenceCount,
                  weekdays: selectedWeekdays,
                );
                if (isEditing) {
                  _updateEvent(
                    eventId: eventId,
                    title: title,
                    startAt: startDateTime,
                    endAt: endDateTime,
                    description: descCtrl.text.trim(),
                    allDay: allDay,
                    color: selectedColor,
                    reminderMinutes: reminderMinutes,
                    calendarId: selectedCalendarId,
                    rrule: rrule,
                    timezone: selectedTimezone,
                    cancelReminderWhenNone:
                        calendarEventReminderMinutes(editEvent ?? {}) != null,
                  );
                } else {
                  _createEvent(
                    title: title,
                    startAt: startDateTime,
                    endAt: endDateTime,
                    description: descCtrl.text.trim(),
                    allDay: allDay,
                    color: selectedColor,
                    reminderMinutes: reminderMinutes,
                    calendarId: selectedCalendarId,
                    rrule: rrule,
                    timezone: selectedTimezone,
                  );
                }
              },
              child: Text(isEditing ? '保存' : '追加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEventSearchDelegate
    extends SearchDelegate<Map<String, dynamic>?> {
  _CalendarEventSearchDelegate({required this.events})
      : super(searchFieldLabel: 'Search events');

  final List<Map<String, dynamic>> events;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Clear search',
          icon: const Icon(Icons.close),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildMatches(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final matches = searchCalendarEventsForDisplay(events, query);
    if (events.isEmpty) {
      return const Center(child: Text('No events loaded'));
    }
    if (matches.isEmpty) {
      return const Center(child: Text('No matching events'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = matches[index];
        return _SearchResultTile(
          event: event,
          color: _CalendarEventsPageState._eventColor(event),
          onTap: () => close(context, event),
        );
      },
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.event,
    required this.color,
    required this.onTap,
  });

  final Map<String, dynamic> event;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = event['description']?.toString().trim() ?? '';
    final start = _eventDateTime(event, 'start_at');
    final dateLabel = start == null ? 'No date' : _formatDate(start);
    final subtitle = [
      dateLabel,
      _eventTimeLabel(event),
      if (description.isNotEmpty) description,
    ].where((value) => value.isNotEmpty).join(' - ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(Icons.event, color: color, size: 20),
      ),
      title: Text(
        _eventTitle(event),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }
}

class _EventMetadataRow extends StatelessWidget {
  const _EventMetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.colorHex, this.selected = false});

  final String colorHex;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Color(
          int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16),
        ),
        shape: BoxShape.circle,
        border: selected
            ? Border.all(
                color: Theme.of(context).colorScheme.onSurface,
                width: 2.5,
              )
            : null,
      ),
    );
  }
}

class _CalendarFilterDrawer extends StatelessWidget {
  const _CalendarFilterDrawer({
    required this.calendars,
    required this.visibleCalendarIds,
    required this.showOriginalTimezone,
    required this.onToggle,
    required this.onToggleOriginalTimezone,
    required this.onAddCalendar,
    required this.onDeleteCalendar,
  });

  final List<_CalendarListItem> calendars;
  final Set<String> visibleCalendarIds;
  final bool showOriginalTimezone;
  final void Function(String calendarId, bool visible) onToggle;
  final ValueChanged<bool> onToggleOriginalTimezone;
  final VoidCallback onAddCalendar;
  final ValueChanged<_CalendarListItem> onDeleteCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Calendars'),
              trailing: IconButton(
                key: const Key('calendar_add_calendar_button'),
                icon: const Icon(Icons.add),
                tooltip: 'Add calendar',
                onPressed: onAddCalendar,
              ),
            ),
            SwitchListTile(
              key: const Key('calendar_original_timezone_toggle'),
              secondary: const Icon(Icons.public),
              title: const Text('Original timezone'),
              subtitle: Text(
                showOriginalTimezone
                    ? 'Show saved event timezone'
                    : 'Show this device timezone',
              ),
              value: showOriginalTimezone,
              onChanged: onToggleOriginalTimezone,
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: calendars.length,
                itemBuilder: (context, index) {
                  final calendar = calendars[index];
                  final visible = visibleCalendarIds.contains(calendar.id);
                  return CheckboxListTile(
                    key: Key('calendar_toggle_${calendar.id}'),
                    value: visible,
                    onChanged: (value) {
                      if (value == null) return;
                      onToggle(calendar.id, value);
                    },
                    secondary: _ColorDot(colorHex: calendar.color),
                    title: Text(calendar.name, overflow: TextOverflow.ellipsis),
                    subtitle: calendar.isDefault
                        ? Text('Default', style: theme.textTheme.bodySmall)
                        : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    tristate: false,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            for (final calendar in calendars.where((item) => !item.isDefault))
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_outline),
                title: Text(calendar.name, overflow: TextOverflow.ellipsis),
                onTap: () => onDeleteCalendar(calendar),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarViewSwitcher extends StatelessWidget {
  const _CalendarViewSwitcher({
    required this.selectedView,
    required this.onChanged,
  });

  final _CalendarView selectedView;
  final ValueChanged<_CalendarView> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <(_CalendarView, String, IconData)>[
      (_CalendarView.month, 'Month', Icons.calendar_month),
      (_CalendarView.week, 'Week', Icons.view_week),
      (_CalendarView.day, 'Day', Icons.view_day),
    ];

    return Material(
      color: theme.colorScheme.surface,
      child: SizedBox(
        height: 56,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (final item in items) ...[
                ChoiceChip(
                  avatar: Icon(item.$3, size: 18),
                  label: Text(item.$2),
                  selected: selectedView == item.$1,
                  onSelected: (_) => onChanged(item.$1),
                  showCheckmark: false,
                  selectedColor: theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: selectedView == item.$1
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DayViewHeader extends StatelessWidget {
  const _DayViewHeader({
    required this.selectedDay,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  final DateTime selectedDay;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous day',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPreviousDay,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${selectedDay.year}/${selectedDay.month}/${selectedDay.day}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  'Day view',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNextDay,
          ),
        ],
      ),
    );
  }
}

class _DayTimelineView extends StatelessWidget {
  const _DayTimelineView({
    required this.selectedDay,
    required this.events,
    required this.showOriginalTimezone,
    required this.onTap,
    required this.onDelete,
    required this.onMove,
  });

  static const double _hourHeight = 64;
  static const double _timeGutterWidth = 56;
  static const double _eventGap = 6;
  static const double _slotHeight = _hourHeight * _calendarDragSnapMinutes / 60;

  final DateTime selectedDay;
  final List<Map<String, dynamic>> events;
  final bool showOriginalTimezone;
  final ValueChanged<Map<String, dynamic>> onTap;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final void Function(Map<String, dynamic> event, DateTime startAt) onMove;

  @override
  Widget build(BuildContext context) {
    final allDayEvents = events.where(_eventIsAllDay).toList();
    final entries = _buildTimelineEntries(
      events,
      selectedDay,
      showOriginalTimezone,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        if (allDayEvents.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final event in allDayEvents)
                InputChip(
                  avatar: CircleAvatar(
                    backgroundColor: _CalendarEventsPageState._eventColor(
                      event,
                    ).withValues(alpha: 0.18),
                    child: Icon(
                      Icons.event,
                      size: 16,
                      color: _CalendarEventsPageState._eventColor(event),
                    ),
                  ),
                  label: Text(_eventTitle(event)),
                  onPressed: () => onTap(event),
                  onDeleted: () => onDelete(event),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth =
                constraints.maxWidth - _timeGutterWidth - (_eventGap * 2);
            final safeContentWidth = contentWidth < 0 ? 0.0 : contentWidth;

            return SizedBox(
              height: 24 * _hourHeight,
              child: Stack(
                children: [
                  for (var hour = 0; hour < 24; hour++)
                    Positioned(
                      top: hour * _hourHeight,
                      left: 0,
                      right: 0,
                      height: _hourHeight,
                      child: _HourSlot(hour: hour),
                    ),
                  for (var minute = 0;
                      minute < 24 * 60;
                      minute += _calendarDragSnapMinutes)
                    Positioned(
                      top: (minute / 60) * _hourHeight,
                      left: _timeGutterWidth,
                      right: 0,
                      height: _slotHeight,
                      child: _TimelineDropSlot(
                        key: Key('calendar_drop_slot_$minute'),
                        selectedDay: selectedDay,
                        minute: minute,
                        onMove: onMove,
                      ),
                    ),
                  for (final entry in entries)
                    _buildPositionedEvent(entry, safeContentWidth),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPositionedEvent(_TimelineEntry entry, double contentWidth) {
    final columnWidth = (contentWidth - (entry.columnCount - 1) * _eventGap) /
        entry.columnCount;
    final safeColumnWidth = columnWidth < 48 ? 48.0 : columnWidth;
    final top = (entry.startMinute / 60) * _hourHeight + 2;
    final height =
        ((entry.endMinute - entry.startMinute) / 60) * _hourHeight - 4;
    final safeHeight = height < 36 ? 36.0 : height;

    return Positioned(
      top: top,
      left: _timeGutterWidth +
          _eventGap +
          entry.column * (safeColumnWidth + _eventGap),
      width: safeColumnWidth,
      height: safeHeight,
      child: _DayTimelineEventTile(
        event: entry.event,
        color: _CalendarEventsPageState._eventColor(entry.event),
        showOriginalTimezone: showOriginalTimezone,
        onTap: () => onTap(entry.event),
        onDelete: () => onDelete(entry.event),
        draggable: _canDragEvent(entry.event),
      ),
    );
  }

  static bool _canDragEvent(Map<String, dynamic> event) {
    return !_eventIsAllDay(event) &&
        !calendarEventIsRecurrenceOccurrence(event) &&
        calendarEventSeriesId(event).isNotEmpty;
  }

  List<_TimelineEntry> _buildTimelineEntries(
    List<Map<String, dynamic>> rawEvents,
    DateTime day,
    bool showOriginalTimezone,
  ) {
    final candidates = <_TimelineEntry>[];
    for (final event in rawEvents) {
      if (_eventIsAllDay(event)) continue;
      final range = _timelineRange(
        event,
        day,
        showOriginalTimezone: showOriginalTimezone,
      );
      if (range == null) continue;
      candidates.add(
        _TimelineEntry(
          event: event,
          startMinute: range.startMinute,
          endMinute: range.endMinute,
        ),
      );
    }

    candidates.sort((a, b) {
      final byStart = a.startMinute.compareTo(b.startMinute);
      return byStart != 0 ? byStart : a.endMinute.compareTo(b.endMinute);
    });

    final entries = <_TimelineEntry>[];
    var group = <_TimelineEntry>[];
    var groupEnd = -1;

    void flushGroup() {
      if (group.isEmpty) return;
      final columns = <int>[];
      final laidOut = <_TimelineEntry>[];

      for (final candidate in group) {
        var column = columns.indexWhere(
          (endMinute) => endMinute <= candidate.startMinute,
        );
        if (column == -1) {
          column = columns.length;
          columns.add(candidate.endMinute);
        } else {
          columns[column] = candidate.endMinute;
        }
        laidOut.add(candidate.copyWith(column: column));
      }

      final columnCount = columns.length;
      entries.addAll(
        laidOut.map((entry) => entry.copyWith(columnCount: columnCount)),
      );
      group = <_TimelineEntry>[];
      groupEnd = -1;
    }

    for (final candidate in candidates) {
      if (group.isEmpty || candidate.startMinute < groupEnd) {
        group.add(candidate);
        if (candidate.endMinute > groupEnd) {
          groupEnd = candidate.endMinute;
        }
      } else {
        flushGroup();
        group.add(candidate);
        groupEnd = candidate.endMinute;
      }
    }
    flushGroup();

    return entries;
  }

  _TimelineRange? _timelineRange(
    Map<String, dynamic> event,
    DateTime day, {
    required bool showOriginalTimezone,
  }) {
    final start = _eventDateTime(
      event,
      'start_at',
      showOriginalTimezone: showOriginalTimezone,
    );
    if (start == null) return null;
    final end = _eventDateTime(
          event,
          'end_at',
          showOriginalTimezone: showOriginalTimezone,
        ) ??
        start.add(const Duration(hours: 1));

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    if (!end.isAfter(dayStart) || !start.isBefore(dayEnd)) return null;

    final clampedStart = start.isBefore(dayStart) ? dayStart : start;
    final clampedEnd = end.isAfter(dayEnd) ? dayEnd : end;
    final startMinute = _clampInt(
      clampedStart.difference(dayStart).inMinutes,
      0,
      1439,
    );
    final rawEndMinute = _clampInt(
      clampedEnd.difference(dayStart).inMinutes,
      1,
      1440,
    );
    final minimumEndMinute = _clampInt(startMinute + 30, 1, 1440);
    final endMinute =
        rawEndMinute < minimumEndMinute ? minimumEndMinute : rawEndMinute;

    return _TimelineRange(startMinute, endMinute);
  }
}

class _TimelineDropSlot extends StatelessWidget {
  const _TimelineDropSlot({
    super.key,
    required this.selectedDay,
    required this.minute,
    required this.onMove,
  });

  final DateTime selectedDay;
  final int minute;
  final void Function(Map<String, dynamic> event, DateTime startAt) onMove;

  DateTime get _startAt {
    final dayStart = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    return dayStart.add(Duration(minutes: minute));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) =>
          _DayTimelineView._canDragEvent(details.data),
      onAcceptWithDetails: (details) => onMove(details.data, _startAt),
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
                : Colors.transparent,
            border: active
                ? Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.55),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _HourSlot extends StatelessWidget {
  const _HourSlot({required this.hour});

  final int hour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _DayTimelineView._timeGutterWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayTimelineEventTile extends StatelessWidget {
  const _DayTimelineEventTile({
    required this.event,
    required this.color,
    required this.showOriginalTimezone,
    required this.onTap,
    required this.onDelete,
    required this.draggable,
  });

  final Map<String, dynamic> event;
  final Color color;
  final bool showOriginalTimezone;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = event['description']?.toString() ?? '';
    final tile = Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _eventTitle(event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        _eventTimeLabel(
                          event,
                          showOriginalTimezone: showOriginalTimezone,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!draggable) return tile;

    return LongPressDraggable<Map<String, dynamic>>(
      data: event,
      delay: const Duration(milliseconds: 350),
      feedback: _TimelineDragPreview(
        event: event,
        color: color,
        showOriginalTimezone: showOriginalTimezone,
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _TimelineDragPreview extends StatelessWidget {
  const _TimelineDragPreview({
    required this.event,
    required this.color,
    required this.showOriginalTimezone,
  });

  final Map<String, dynamic> event;
  final Color color;
  final bool showOriginalTimezone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(6),
      color: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240, minWidth: 180),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_with, size: 18, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _eventTitle(event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        _eventTimeLabel(
                          event,
                          showOriginalTimezone: showOriginalTimezone,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineRange {
  const _TimelineRange(this.startMinute, this.endMinute);

  final int startMinute;
  final int endMinute;
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.event,
    required this.startMinute,
    required this.endMinute,
    this.column = 0,
    this.columnCount = 1,
  });

  final Map<String, dynamic> event;
  final int startMinute;
  final int endMinute;
  final int column;
  final int columnCount;

  _TimelineEntry copyWith({int? column, int? columnCount}) {
    return _TimelineEntry(
      event: event,
      startMinute: startMinute,
      endMinute: endMinute,
      column: column ?? this.column,
      columnCount: columnCount ?? this.columnCount,
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.color,
    required this.showOriginalTimezone,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> event;
  final Color color;
  final bool showOriginalTimezone;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = event['title']?.toString() ?? 'タイトルなし';
    final description = event['description']?.toString() ?? '';
    final timeLabel = _eventTimeLabel(
      event,
      showOriginalTimezone: showOriginalTimezone,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.event, color: color, size: 20),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(timeLabel, style: const TextStyle(fontSize: 12, height: 1.5)),
            Text(
              _eventTimezoneLabel(event),
              style: const TextStyle(fontSize: 11, height: 1.4),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (description.isNotEmpty)
              Text(
                description,
                style: const TextStyle(fontSize: 12, height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Color(0xFFE53935)),
          tooltip: '削除',
          onPressed: onDelete,
        ),
      ),
    );
  }
}
