import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/calendar_ics_service.dart';

void main() {
  test('buildCalendarEventsIcs exports event metadata and RRULE', () {
    final ics = buildCalendarEventsIcs(
      [
        {
          'event_id': 'event-1',
          'title': 'Budget review',
          'description': 'Revise forecast, cash; debt',
          'start_at': DateTime.utc(2026, 5, 14, 9).toIso8601String(),
          'end_at': DateTime.utc(2026, 5, 14, 10).toIso8601String(),
          'all_day': false,
          'color': '#34a853',
          'calendar_id': 'finance',
          'calendar_name': 'Finance',
          'reminder_min': 15,
          'rrule': 'RRULE:FREQ=WEEKLY;COUNT=2',
          'timezone': 'Asia/Tokyo',
        },
      ],
      generatedAt: DateTime.utc(2026, 5, 14, 8),
    );

    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, contains('BEGIN:VEVENT'));
    expect(ics, contains('UID:event-1@my-web-app.local'));
    expect(ics, contains('SUMMARY:Budget review'));
    expect(ics, contains(r'DESCRIPTION:Revise forecast\, cash\; debt'));
    expect(ics, contains('RRULE:FREQ=WEEKLY;COUNT=2'));
    expect(ics, contains('X-MYWEBAPP-COLOR:#34a853'));
    expect(ics, contains('X-MYWEBAPP-CALENDAR-ID:finance'));
    expect(ics, contains('X-MYWEBAPP-TIMEZONE:Asia/Tokyo'));
  });

  test('parseCalendarEventsIcs imports events and skips duplicate UID', () {
    const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:event-1@example.com
DTSTART:20260514T090000Z
DTEND:20260514T100000Z
SUMMARY:Budget review
DESCRIPTION:Revise forecast\\, cash\\; debt
X-MYWEBAPP-COLOR:#34A853
X-MYWEBAPP-CALENDAR-ID:finance
X-MYWEBAPP-CALENDAR-NAME:Finance
X-MYWEBAPP-TIMEZONE:Asia/Tokyo
X-MYWEBAPP-REMINDER-MIN:15
END:VEVENT
BEGIN:VEVENT
UID:event-1@example.com
DTSTART:20260514T110000Z
SUMMARY:Duplicate
END:VEVENT
END:VCALENDAR
''';

    final parsed = parseCalendarEventsIcs(ics);

    expect(parsed.events, hasLength(1));
    expect(parsed.skippedDuplicateCount, 1);
    expect(parsed.invalidEventCount, 0);
    expect(parsed.events.single['ical_uid'], 'event-1@example.com');
    expect(parsed.events.single['title'], 'Budget review');
    expect(parsed.events.single['description'], 'Revise forecast, cash; debt');
    expect(parsed.events.single['color'], '#34a853');
    expect(parsed.events.single['calendar_id'], 'finance');
    expect(parsed.events.single['calendar_name'], 'Finance');
    expect(parsed.events.single['timezone'], 'Asia/Tokyo');
    expect(parsed.events.single['reminder_min'], 15);
  });

  test('parseCalendarEventsIcs skips UIDs already present locally', () {
    const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:existing@example.com
DTSTART;VALUE=DATE:20260514
DTEND;VALUE=DATE:20260515
SUMMARY:Existing event
END:VEVENT
END:VCALENDAR
''';

    final parsed = parseCalendarEventsIcs(
      ics,
      existingUids: {'existing@example.com'},
    );

    expect(parsed.events, isEmpty);
    expect(parsed.skippedDuplicateCount, 1);
  });
}
