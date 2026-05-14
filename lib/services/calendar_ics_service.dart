import 'package:flutter/foundation.dart';

const String _icsProductId = '-//Jibun Inc//Calendar Events//EN';
const String _icsDomain = 'my-web-app.local';

class CalendarIcsParseResult {
  const CalendarIcsParseResult({
    required this.events,
    required this.skippedDuplicateCount,
    required this.invalidEventCount,
  });

  final List<Map<String, dynamic>> events;
  final int skippedDuplicateCount;
  final int invalidEventCount;
}

@visibleForTesting
String normalizeCalendarIcsUid(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return '';
  return raw.length > 512 ? raw.substring(0, 512) : raw;
}

Set<String> calendarIcsUidsFromEvents(Iterable<Map<String, dynamic>> events) {
  return {
    for (final event in events)
      if (normalizeCalendarIcsUid(event['ical_uid'] ?? event['uid']).isNotEmpty)
        normalizeCalendarIcsUid(event['ical_uid'] ?? event['uid']),
  };
}

String buildCalendarEventsIcs(
  Iterable<Map<String, dynamic>> events, {
  DateTime? generatedAt,
}) {
  final now = (generatedAt ?? DateTime.now()).toUtc();
  final buffer = StringBuffer();
  final seenUids = <String>{};

  _appendIcsLine(buffer, 'BEGIN:VCALENDAR');
  _appendIcsLine(buffer, 'VERSION:2.0');
  _appendIcsLine(buffer, 'PRODID:$_icsProductId');
  _appendIcsLine(buffer, 'CALSCALE:GREGORIAN');
  _appendIcsLine(buffer, 'METHOD:PUBLISH');

  for (final rawEvent in events) {
    final event = _canonicalExportEvent(rawEvent);
    final uid = _eventUid(event);
    if (uid.isEmpty || !seenUids.add(uid)) continue;

    final start = _eventDateTime(event, 'start_at');
    if (start == null) continue;
    final end =
        _eventDateTime(event, 'end_at') ??
        start.add(
          _eventIsAllDay(event)
              ? const Duration(days: 1)
              : const Duration(hours: 1),
        );
    final allDay = _eventIsAllDay(event);
    final title = _eventTitle(event);
    final description = event['description']?.toString() ?? '';
    final color = _eventColorHex(event);
    final calendarId = _nonEmptyString(event['calendar_id']);
    final calendarName = _nonEmptyString(event['calendar_name']);
    final reminder = _nonEmptyString(event['reminder_min']);
    final rrule = _nonEmptyString(event['rrule']);
    final timezone = _nonEmptyString(event['timezone']);

    _appendIcsLine(buffer, 'BEGIN:VEVENT');
    _appendIcsLine(buffer, 'UID:${_escapeIcsText(uid)}');
    _appendIcsLine(buffer, 'DTSTAMP:${_formatUtcIcsDateTime(now)}');
    if (allDay) {
      _appendIcsLine(buffer, 'DTSTART;VALUE=DATE:${_formatIcsDate(start)}');
      _appendIcsLine(
        buffer,
        'DTEND;VALUE=DATE:${_formatIcsDate(_exclusiveAllDayEnd(start, end))}',
      );
    } else {
      _appendIcsLine(buffer, 'DTSTART:${_formatUtcIcsDateTime(start.toUtc())}');
      _appendIcsLine(buffer, 'DTEND:${_formatUtcIcsDateTime(end.toUtc())}');
    }
    _appendIcsLine(buffer, 'SUMMARY:${_escapeIcsText(title)}');
    if (description.isNotEmpty) {
      _appendIcsLine(buffer, 'DESCRIPTION:${_escapeIcsText(description)}');
    }
    if (rrule.isNotEmpty) {
      _appendIcsLine(
        buffer,
        rrule.toUpperCase().startsWith('RRULE:') ? rrule : 'RRULE:$rrule',
      );
    }
    _appendIcsLine(buffer, 'X-MYWEBAPP-COLOR:$color');
    if (calendarId.isNotEmpty) {
      _appendIcsLine(
        buffer,
        'X-MYWEBAPP-CALENDAR-ID:${_escapeIcsText(calendarId)}',
      );
    }
    if (calendarName.isNotEmpty) {
      _appendIcsLine(
        buffer,
        'X-MYWEBAPP-CALENDAR-NAME:${_escapeIcsText(calendarName)}',
      );
    }
    if (timezone.isNotEmpty) {
      _appendIcsLine(buffer, 'X-MYWEBAPP-TIMEZONE:${_escapeIcsText(timezone)}');
    }
    if (reminder.isNotEmpty && reminder != 'null') {
      _appendIcsLine(buffer, 'X-MYWEBAPP-REMINDER-MIN:$reminder');
    }
    _appendIcsLine(buffer, 'END:VEVENT');
  }

  _appendIcsLine(buffer, 'END:VCALENDAR');
  return buffer.toString();
}

CalendarIcsParseResult parseCalendarEventsIcs(
  String content, {
  Set<String> existingUids = const {},
}) {
  final lines = _unfoldIcsLines(content);
  final events = <Map<String, dynamic>>[];
  final seenUids = existingUids
      .map(normalizeCalendarIcsUid)
      .where((uid) => uid.isNotEmpty)
      .toSet();
  var skippedDuplicates = 0;
  var invalidEvents = 0;
  Map<String, List<_IcsProperty>>? current;

  void finishEvent() {
    final fields = current;
    if (fields == null) return;
    current = null;

    final uid = normalizeCalendarIcsUid(_firstValue(fields, 'UID'));
    final startProp = _firstProperty(fields, 'DTSTART');
    if (uid.isEmpty || startProp == null) {
      invalidEvents += 1;
      return;
    }
    if (seenUids.contains(uid)) {
      skippedDuplicates += 1;
      return;
    }

    final allDay = _isAllDayProperty(startProp);
    final start = _parseIcsDateTime(startProp.value, allDay: allDay);
    if (start == null) {
      invalidEvents += 1;
      return;
    }
    final endProp = _firstProperty(fields, 'DTEND');
    final parsedEnd = endProp == null
        ? null
        : _parseIcsDateTime(endProp.value, allDay: _isAllDayProperty(endProp));
    final end =
        parsedEnd ??
        start.add(allDay ? const Duration(days: 1) : const Duration(hours: 1));

    final timezone = _unescapeIcsText(
      _firstValue(fields, 'X-MYWEBAPP-TIMEZONE'),
    ).trim();

    seenUids.add(uid);
    events.add({
      'ical_uid': uid,
      'uid': uid,
      'title': _unescapeIcsText(_firstValue(fields, 'SUMMARY')).trim().isEmpty
          ? 'Untitled'
          : _unescapeIcsText(_firstValue(fields, 'SUMMARY')).trim(),
      'description': _unescapeIcsText(_firstValue(fields, 'DESCRIPTION')),
      'start_at': start.toIso8601String(),
      'end_at': end.toIso8601String(),
      'all_day': allDay,
      'color': _normalizeIcsColor(_firstValue(fields, 'X-MYWEBAPP-COLOR')),
      'calendar_id': _unescapeIcsText(
        _firstValue(fields, 'X-MYWEBAPP-CALENDAR-ID'),
      ).trim(),
      'calendar_name': _unescapeIcsText(
        _firstValue(fields, 'X-MYWEBAPP-CALENDAR-NAME'),
      ).trim(),
      if (timezone.isNotEmpty) 'timezone': timezone,
      'reminder_min': int.tryParse(
        _firstValue(fields, 'X-MYWEBAPP-REMINDER-MIN').trim(),
      ),
      'rrule': _normalizeImportedRRule(_firstValue(fields, 'RRULE')),
      'source': 'ical_import',
    });
  }

  for (final rawLine in lines) {
    final property = _parseIcsProperty(rawLine);
    if (property == null) continue;
    if (property.name == 'BEGIN' && property.value.toUpperCase() == 'VEVENT') {
      current = <String, List<_IcsProperty>>{};
      continue;
    }
    if (property.name == 'END' && property.value.toUpperCase() == 'VEVENT') {
      finishEvent();
      continue;
    }
    if (current == null) continue;
    current!.putIfAbsent(property.name, () => []).add(property);
  }
  finishEvent();

  return CalendarIcsParseResult(
    events: events,
    skippedDuplicateCount: skippedDuplicates,
    invalidEventCount: invalidEvents,
  );
}

Map<String, dynamic> _canonicalExportEvent(Map<String, dynamic> event) {
  if (event['series_event_id']?.toString().trim().isNotEmpty != true) {
    return event;
  }
  return {
    ...event,
    'event_id': event['series_event_id'],
    'start_at': event['series_start_at'] ?? event['start_at'],
    'end_at': event['series_end_at'] ?? event['end_at'],
  };
}

String _eventUid(Map<String, dynamic> event) {
  final stored = normalizeCalendarIcsUid(event['ical_uid'] ?? event['uid']);
  if (stored.isNotEmpty) return stored;
  final id = normalizeCalendarIcsUid(
    event['series_event_id'] ?? event['event_id'] ?? event['id'],
  );
  return id.isEmpty ? '' : '$id@$_icsDomain';
}

String _eventTitle(Map<String, dynamic> event) {
  final title = event['title']?.toString().trim() ?? '';
  return title.isEmpty ? 'Untitled' : title;
}

bool _eventIsAllDay(Map<String, dynamic> event) => event['all_day'] == true;

DateTime? _eventDateTime(Map<String, dynamic> event, String key) {
  final value = event[key]?.toString() ?? '';
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String _eventColorHex(Map<String, dynamic> event) {
  final raw = event['color']?.toString().trim() ?? '';
  final normalized = raw.startsWith('#') ? raw : '#$raw';
  final lower = normalized.toLowerCase();
  return RegExp(r'^#[0-9a-f]{6}$').hasMatch(lower) ? lower : '#4285f4';
}

String _nonEmptyString(Object? value) => value?.toString().trim() ?? '';

DateTime _exclusiveAllDayEnd(DateTime start, DateTime end) {
  final startDate = DateTime(start.year, start.month, start.day);
  final endDate = DateTime(end.year, end.month, end.day);
  return endDate.isAfter(startDate)
      ? endDate
      : startDate.add(const Duration(days: 1));
}

String _formatIcsDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';
}

String _formatUtcIcsDateTime(DateTime value) {
  final utc = value.toUtc();
  return '${_formatIcsDate(utc)}T'
      '${utc.hour.toString().padLeft(2, '0')}'
      '${utc.minute.toString().padLeft(2, '0')}'
      '${utc.second.toString().padLeft(2, '0')}Z';
}

void _appendIcsLine(StringBuffer buffer, String line) {
  const max = 75;
  if (line.length <= max) {
    buffer.write(line);
    buffer.write('\r\n');
    return;
  }
  var remaining = line;
  var first = true;
  while (remaining.isNotEmpty) {
    final take = first ? max : max - 1;
    final part = remaining.length <= take
        ? remaining
        : remaining.substring(0, take);
    buffer.write(first ? part : ' $part');
    buffer.write('\r\n');
    remaining = remaining.length <= take ? '' : remaining.substring(take);
    first = false;
  }
}

String _escapeIcsText(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', r'\n')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,');
}

String _unescapeIcsText(String value) {
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i += 1) {
    final char = value[i];
    if (char != '\\' || i == value.length - 1) {
      buffer.write(char);
      continue;
    }
    final next = value[++i];
    switch (next) {
      case 'n':
      case 'N':
        buffer.write('\n');
        break;
      case '\\':
        buffer.write('\\');
        break;
      case ',':
        buffer.write(',');
        break;
      case ';':
        buffer.write(';');
        break;
      default:
        buffer.write(next);
        break;
    }
  }
  return buffer.toString();
}

List<String> _unfoldIcsLines(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = <String>[];
  for (final line in normalized.split('\n')) {
    if ((line.startsWith(' ') || line.startsWith('\t')) && lines.isNotEmpty) {
      lines[lines.length - 1] += line.substring(1);
    } else if (line.trim().isNotEmpty) {
      lines.add(line);
    }
  }
  return lines;
}

class _IcsProperty {
  const _IcsProperty({
    required this.name,
    required this.params,
    required this.value,
  });

  final String name;
  final Map<String, String> params;
  final String value;
}

_IcsProperty? _parseIcsProperty(String line) {
  final colon = line.indexOf(':');
  if (colon <= 0) return null;
  final left = line.substring(0, colon);
  final value = line.substring(colon + 1);
  final parts = left.split(';');
  final name = parts.first.trim().toUpperCase();
  if (name.isEmpty) return null;
  final params = <String, String>{};
  for (final part in parts.skip(1)) {
    final equals = part.indexOf('=');
    if (equals <= 0) continue;
    params[part.substring(0, equals).trim().toUpperCase()] = part
        .substring(equals + 1)
        .trim();
  }
  return _IcsProperty(name: name, params: params, value: value);
}

_IcsProperty? _firstProperty(
  Map<String, List<_IcsProperty>> fields,
  String name,
) {
  final values = fields[name.toUpperCase()];
  return values == null || values.isEmpty ? null : values.first;
}

String _firstValue(Map<String, List<_IcsProperty>> fields, String name) {
  return _firstProperty(fields, name)?.value ?? '';
}

bool _isAllDayProperty(_IcsProperty property) {
  return property.params['VALUE']?.toUpperCase() == 'DATE' ||
      RegExp(r'^\d{8}$').hasMatch(property.value);
}

DateTime? _parseIcsDateTime(String value, {required bool allDay}) {
  final raw = value.trim();
  if (RegExp(r'^\d{8}$').hasMatch(raw)) {
    return DateTime(
      int.parse(raw.substring(0, 4)),
      int.parse(raw.substring(4, 6)),
      int.parse(raw.substring(6, 8)),
    );
  }
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})?(Z)?$',
  ).firstMatch(raw);
  if (match == null) return DateTime.tryParse(raw);
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.tryParse(match.group(6) ?? '0') ?? 0;
  if (match.group(7) == 'Z') {
    return DateTime.utc(year, month, day, hour, minute, second).toLocal();
  }
  return DateTime(year, month, day, hour, minute, second);
}

String _normalizeIcsColor(String value) {
  return _eventColorHex({'color': value});
}

String? _normalizeImportedRRule(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.toUpperCase().startsWith('RRULE:')
      ? trimmed
      : 'RRULE:$trimmed';
}
