import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const List<String> calendarTimezoneOptions = [
  'UTC',
  'Asia/Tokyo',
  'Asia/Singapore',
  'Europe/London',
  'Europe/Paris',
  'America/New_York',
  'America/Los_Angeles',
  'Australia/Sydney',
];

bool _timeZonesInitialized = false;

void ensureCalendarTimeZonesInitialized() {
  if (_timeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _timeZonesInitialized = true;
}

String calendarDefaultTimezone({DateTime? now, String? timeZoneName}) {
  ensureCalendarTimeZonesInitialized();
  final probe = now ?? DateTime.now();
  final name = (timeZoneName ?? probe.timeZoneName).toUpperCase();
  switch (name) {
    case 'UTC':
    case 'GMT':
      return 'UTC';
    case 'JST':
    case 'TOKYO STANDARD TIME':
      return 'Asia/Tokyo';
    case 'SGT':
    case 'SINGAPORE STANDARD TIME':
      return 'Asia/Singapore';
    case 'BST':
    case 'GMT STANDARD TIME':
      return 'Europe/London';
    case 'CET':
    case 'CEST':
    case 'W. EUROPE STANDARD TIME':
    case 'ROMANCE STANDARD TIME':
      return 'Europe/Paris';
    case 'EST':
    case 'EDT':
    case 'EASTERN STANDARD TIME':
      return 'America/New_York';
    case 'PST':
    case 'PDT':
    case 'PACIFIC STANDARD TIME':
      return 'America/Los_Angeles';
    case 'AEST':
    case 'AEDT':
    case 'AUS EASTERN STANDARD TIME':
      return 'Australia/Sydney';
  }

  final offset = probe.timeZoneOffset;
  if (offset == const Duration(hours: 9)) return 'Asia/Tokyo';
  if (offset == const Duration(hours: 8)) return 'Asia/Singapore';
  if (offset == Duration.zero) return 'UTC';
  if (offset == const Duration(hours: 1) ||
      offset == const Duration(hours: 2)) {
    return 'Europe/Paris';
  }
  if (offset == const Duration(hours: -5) ||
      offset == const Duration(hours: -4)) {
    return 'America/New_York';
  }
  if (offset == const Duration(hours: -8) ||
      offset == const Duration(hours: -7)) {
    return 'America/Los_Angeles';
  }
  if (offset == const Duration(hours: 10) ||
      offset == const Duration(hours: 11)) {
    return 'Australia/Sydney';
  }
  return 'UTC';
}

String normalizeCalendarTimezone(Object? value) {
  ensureCalendarTimeZonesInitialized();
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty || raw == 'null' || raw == 'undefined') {
    return calendarDefaultTimezone();
  }
  try {
    return tz.getLocation(raw).name;
  } catch (_) {
    return calendarDefaultTimezone();
  }
}

List<String> calendarTimezoneDropdownOptions(String selectedTimezone) {
  final normalized = normalizeCalendarTimezone(selectedTimezone);
  return [
    normalized,
    for (final option in calendarTimezoneOptions)
      if (option != normalized) option,
  ];
}

DateTime calendarWallTimeToUtc({
  required DateTime date,
  required int hour,
  required int minute,
  required String timezone,
}) {
  ensureCalendarTimeZonesInitialized();
  final location = tz.getLocation(normalizeCalendarTimezone(timezone));
  return tz.TZDateTime(
    location,
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  ).toUtc();
}

DateTime? calendarEventDateTimeForDisplay(
  Map<String, dynamic> event,
  String key, {
  bool showOriginalTimezone = false,
}) {
  final value = event[key]?.toString() ?? '';
  if (value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  if (!showOriginalTimezone) return parsed.toLocal();

  ensureCalendarTimeZonesInitialized();
  final location = tz.getLocation(calendarEventTimezone(event));
  return tz.TZDateTime.from(parsed, location);
}

String calendarEventTimezone(Map<String, dynamic> event) {
  return normalizeCalendarTimezone(event['timezone']);
}

String calendarTimezoneAbbreviation(String timezone, {DateTime? at}) {
  ensureCalendarTimeZonesInitialized();
  final location = tz.getLocation(normalizeCalendarTimezone(timezone));
  return tz.TZDateTime.from(at ?? DateTime.now(), location).timeZoneName;
}
