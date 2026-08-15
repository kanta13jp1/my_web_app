import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/pages/calendar_events_page.dart';
import 'package:my_web_app/services/calendar_timezone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateMocks([SupabaseClient, FunctionsClient, FunctionResponse])
import 'calendar_events_page_test.mocks.dart';

class _FakeUser extends Fake implements User {
  @override
  String get id => 'calendar-user-id';
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => _FakeUser();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabaseClient;
  late MockFunctionsClient mockFunctionsClient;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockSupabaseClient = MockSupabaseClient();
    mockFunctionsClient = MockFunctionsClient();
    when(mockSupabaseClient.functions).thenReturn(mockFunctionsClient);
    when(mockSupabaseClient.auth).thenReturn(_FakeGoTrueClient());
  });

  FunctionResponse mockResponse(Object? data) {
    final response = MockFunctionResponse();
    when(response.data).thenReturn(data);
    when(response.status).thenReturn(200);
    return response;
  }

  void stubCalendarList(
    List<Map<String, dynamic>> events, {
    List<Map<String, dynamic>> calendars = const [
      {
        'calendar_id': 'default',
        'calendar_name': 'Default',
        'color': '#4285f4',
        'is_default': true,
      },
    ],
  }) {
    when(
      mockFunctionsClient.invoke(
        'app-hub',
        body: {'action': 'calendar.list_calendars'},
      ),
    ).thenAnswer(
      (_) async => mockResponse({'success': true, 'calendars': calendars}),
    );
    when(
      mockFunctionsClient.invoke('app-hub', body: {'action': 'calendar.list'}),
    ).thenAnswer(
      (_) async => mockResponse({'success': true, 'events': events}),
    );
  }

  test('sortCalendarEventsForDisplay orders events chronologically', () {
    Map<String, dynamic> event(
      String title,
      DateTime start,
      DateTime end, {
      bool allDay = false,
    }) {
      return {
        'title': title,
        'start_at': start.toIso8601String(),
        'end_at': end.toIso8601String(),
        'all_day': allDay,
      };
    }

    final day = DateTime(2026, 5, 9);
    final sorted = sortCalendarEventsForDisplay([
      event(
        'Late event',
        DateTime(2026, 5, 9, 16, 15),
        DateTime(2026, 5, 9, 16, 30),
      ),
      event(
        'Earlier event',
        DateTime(2026, 5, 9, 15, 30),
        DateTime(2026, 5, 9, 16),
      ),
      event('All day event', day, day, allDay: true),
    ]);

    expect(sorted.map((event) => event['title']), [
      'All day event',
      'Earlier event',
      'Late event',
    ]);
  });

  test('searchCalendarEventsForDisplay matches title and description', () {
    Map<String, dynamic> event(
      String title,
      String description,
      DateTime start,
    ) {
      return {
        'title': title,
        'description': description,
        'start_at': start.toIso8601String(),
        'end_at': start.add(const Duration(hours: 1)).toIso8601String(),
      };
    }

    final day = DateTime(2026, 5, 9);
    final matches = searchCalendarEventsForDisplay(
      [
        event(
          'Budget review',
          'Revise forecast',
          day.add(const Duration(hours: 9)),
        ),
        event('Dentist', 'Annual cleaning', day.add(const Duration(hours: 13))),
        event('Planning', 'Weekly roadmap', day.add(const Duration(hours: 10))),
      ],
      'annual cleaning',
    );

    expect(matches.map((event) => event['title']), ['Dentist']);
  });

  test('calendarEventReminderMinutes normalizes allowed reminder metadata', () {
    expect(calendarEventReminderMinutes({'reminder_min': 15}), 15);
    expect(calendarEventReminderMinutes({'reminder_min': '30'}), 30);
    expect(calendarEventReminderMinutes({'reminder_min': 7}), isNull);
    expect(calendarEventReminderMinutes({'reminder_min': null}), isNull);
  });

  test('calendar helpers normalize default calendar metadata', () {
    expect(calendarEventCalendarId({}), 'default');
    expect(calendarEventCalendarName({}), 'Default');
    expect(
      calendarEventCalendarId({'calendar_id': 'work-calendar'}),
      'work-calendar',
    );
    expect(calendarEventCalendarName({'calendar_name': 'Work'}), 'Work');
  });

  test('calendar timezone helpers convert original wall time', () {
    expect(
      calendarDefaultTimezone(timeZoneName: 'Tokyo Standard Time'),
      'Asia/Tokyo',
    );
    final startUtc = calendarWallTimeToUtc(
      date: DateTime(2026, 5, 15),
      hour: 14,
      minute: 30,
      timezone: 'Asia/Tokyo',
    );

    expect(startUtc.isUtc, isTrue);
    expect(startUtc, DateTime.utc(2026, 5, 15, 5, 30));
    expect(calendarEventTimezone({'timezone': 'Asia/Tokyo'}), 'Asia/Tokyo');
    final originalTime = calendarEventDateTimeForDisplay(
      {'start_at': startUtc.toIso8601String(), 'timezone': 'Asia/Tokyo'},
      'start_at',
      showOriginalTimezone: true,
    );
    expect(originalTime?.year, 2026);
    expect(originalTime?.month, 5);
    expect(originalTime?.day, 15);
    expect(originalTime?.hour, 14);
    expect(originalTime?.minute, 30);
  });

  test('quick add parser handles Japanese date and time patterns', () {
    final tomorrow = parseCalendarQuickAddText(
      '明日 14:00 ミーティング',
      now: DateTime(2026, 5, 14, 8),
    );

    expect(tomorrow, isNotNull);
    expect(tomorrow!.title, 'ミーティング');
    expect(tomorrow.date, DateTime(2026, 5, 15));
    expect(tomorrow.timeOfDay, const TimeOfDay(hour: 14, minute: 0));
    expect(tomorrow.allDay, isFalse);

    final nextMonday = parseCalendarQuickAddText(
      '来週月曜 午後2時半 企画会議',
      now: DateTime(2026, 5, 15, 8),
    );

    expect(nextMonday, isNotNull);
    expect(nextMonday!.title, '企画会議');
    expect(nextMonday.date, DateTime(2026, 5, 18));
    expect(nextMonday.timeOfDay, const TimeOfDay(hour: 14, minute: 30));

    final namedTime = parseCalendarQuickAddText(
      '5/20 夕方 1on1',
      now: DateTime(2026, 5, 14, 8),
    );

    expect(namedTime, isNotNull);
    expect(namedTime!.title, '1on1');
    expect(namedTime.date, DateTime(2026, 5, 20));
    expect(namedTime.timeOfDay, const TimeOfDay(hour: 17, minute: 0));
  });

  test('recurrence helpers normalize and expand weekly RRULE metadata', () {
    final rrule = normalizeCalendarEventRRule('FREQ=WEEKLY;COUNT=3');
    expect(rrule, 'RRULE:FREQ=WEEKLY;COUNT=3');

    final startAt = DateTime(2026, 5, 11, 9);
    final endAt = DateTime(2026, 5, 11, 10);
    final expanded = expandRecurringCalendarEventsForRange(
      [
        {
          'event_id': 'series-1',
          'title': 'Weekly planning',
          'start_at': startAt.toIso8601String(),
          'end_at': endAt.toIso8601String(),
          'all_day': false,
          'rrule': rrule,
        },
      ],
      rangeStart: DateTime(2026, 5),
      rangeEnd: DateTime(2026, 6),
    );

    expect(expanded, hasLength(3));
    expect(expanded.map((event) => event['series_event_id']).toSet(), {
      'series-1',
    });
    expect(
      expanded.map((event) => DateTime.parse(event['start_at'] as String).day),
      [11, 18, 25],
    );
  });

  test('drag helpers snap to 15 minutes and preserve event duration', () {
    final originalStart = DateTime(2026, 5, 14, 9);
    final originalEnd = DateTime(2026, 5, 14, 10, 30);
    final moved = rescheduleCalendarEventTimes(
      {
        'start_at': originalStart.toIso8601String(),
        'end_at': originalEnd.toIso8601String(),
        'all_day': false,
      },
      DateTime(2026, 5, 14, 13, 8),
    );

    expect(moved.startAt, DateTime(2026, 5, 14, 13, 15));
    expect(moved.endAt, DateTime(2026, 5, 14, 14, 45));
    expect(
      snapCalendarEventStartToGrid(DateTime(2026, 5, 14, 23, 58)),
      DateTime(2026, 5, 14, 23, 45),
    );
  });

  Widget testWidget() {
    return MaterialApp(
      home: CalendarEventsPage(supabaseClient: mockSupabaseClient),
    );
  }

  testWidgets('CalendarEventsPage exposes iCal import export menu', (
    tester,
  ) async {
    stubCalendarList(const []);

    await tester.pumpWidget(testWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar_events_ics_menu')));
    await tester.pumpAndSettle();

    expect(find.text('Export .ics'), findsOneWidget);
    expect(find.text('Import .ics'), findsOneWidget);
  });

  testWidgets('CalendarEventsPage quick add previews and creates event', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    stubCalendarList(const []);
    when(
      mockFunctionsClient.invoke(
        'app-hub',
        body: argThat(
          isA<Map<String, dynamic>>().having(
            (body) => body['action'],
            'action',
            'calendar.create',
          ),
          named: 'body',
        ),
      ),
    ).thenAnswer(
      (_) async => mockResponse({
        'success': true,
        'event': {'event_id': 'quick-add-event'},
      }),
    );

    const input = '12/31 14:00 作戦会議';
    final expectedDraft = parseCalendarQuickAddText(input)!;
    final timezone = calendarDefaultTimezone();

    await tester.pumpWidget(testWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar_events_quick_add_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar_quick_add_field')),
      input,
    );
    await tester.tap(
      find.byKey(const Key('calendar_quick_add_preview_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview event'), findsOneWidget);
    expect(find.text('作戦会議'), findsOneWidget);
    expect(find.text(expectedDraft.dateLabel), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar_quick_add_create_button')));
    await tester.pumpAndSettle();

    final captured = verify(
      mockFunctionsClient.invoke('app-hub', body: captureAnyNamed('body')),
    ).captured;
    final createBody = captured.whereType<Map<String, dynamic>>().lastWhere(
          (body) => body['action'] == 'calendar.create',
        );

    expect(createBody['title'], '作戦会議');
    expect(createBody['all_day'], isFalse);
    expect(createBody['calendar_id'], 'default');
    expect(createBody['timezone'], timezone);
    expect(
      createBody['start_at'],
      expectedDraft.startAtForTimezone(timezone).toIso8601String(),
    );
    expect(
      createBody['end_at'],
      expectedDraft.endAtForTimezone(timezone)!.toIso8601String(),
    );
  });

  testWidgets('CalendarEventsPage switches to day timeline grid', (
    tester,
  ) async {
    stubCalendarList(const []);

    await tester.pumpWidget(testWidget());
    await tester.pumpAndSettle();

    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pump();
    expect(find.text('Day view'), findsNothing);

    await tester.tap(find.text('Day'));
    await tester.pump();

    expect(find.text('Day view'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('23:00'), findsOneWidget);
  });

  testWidgets('day timeline drag and drop moves event to snapped slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final today = DateTime.now();
    final selectedDay = DateTime(today.year, today.month, today.day);
    final startAt = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      9,
    );
    final endAt = startAt.add(const Duration(hours: 1));
    final movedStart = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      10,
      15,
    );
    final movedEnd = movedStart.add(const Duration(hours: 1));
    final event = {
      'event_id': 'event-drag',
      'title': 'Move me',
      'description': 'Drag this card',
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'all_day': false,
      'color': '#4285f4',
    };
    stubCalendarList([event]);
    when(
      mockFunctionsClient.invoke(
        'app-hub',
        body: {
          'action': 'calendar.update',
          'id': 'event-drag',
          'title': 'Move me',
          'description': 'Drag this card',
          'start_at': movedStart.toIso8601String(),
          'end_at': movedEnd.toIso8601String(),
          'all_day': false,
          'color': '#4285f4',
          'reminder_min': null,
          'calendar_id': 'default',
          'rrule': null,
          'timezone': calendarDefaultTimezone(),
        },
      ),
    ).thenAnswer((_) async => mockResponse({'success': true}));

    await tester.pumpWidget(testWidget());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    final target = find.byKey(const Key('calendar_drop_slot_615'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Move me')),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    verify(
      mockFunctionsClient.invoke(
        'app-hub',
        body: {
          'action': 'calendar.update',
          'id': 'event-drag',
          'title': 'Move me',
          'description': 'Drag this card',
          'start_at': movedStart.toIso8601String(),
          'end_at': movedEnd.toIso8601String(),
          'all_day': false,
          'color': '#4285f4',
          'reminder_min': null,
          'calendar_id': 'default',
          'rrule': null,
          'timezone': calendarDefaultTimezone(),
        },
      ),
    ).called(1);
  });

  testWidgets(
    'CalendarEventsPage searches loaded events and jumps to result day',
    (tester) async {
      final today = DateTime.now();
      final selectedDay = DateTime(today.year, today.month, today.day);
      final tomorrow = selectedDay.add(const Duration(days: 1));
      final budgetStart = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
        9,
      );
      final dentistStart = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        13,
      );
      stubCalendarList([
        {
          'event_id': 'event-budget',
          'title': 'Budget review',
          'description': 'Revise forecast',
          'start_at': budgetStart.toIso8601String(),
          'end_at': budgetStart.add(const Duration(hours: 1)).toIso8601String(),
          'all_day': false,
          'color': '#4285f4',
        },
        {
          'event_id': 'event-dentist',
          'title': 'Dentist',
          'description': 'Annual cleaning',
          'start_at': dentistStart.toIso8601String(),
          'end_at':
              dentistStart.add(const Duration(hours: 1)).toIso8601String(),
          'all_day': false,
          'color': '#34a853',
        },
      ]);

      await tester.pumpWidget(testWidget());
      await tester.pumpAndSettle();

      expect(find.text('Budget review'), findsOneWidget);

      await tester.tap(find.byKey(const Key('calendar_events_search_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'cleaning');
      await tester.pumpAndSettle();

      expect(find.text('Dentist'), findsOneWidget);

      await tester.tap(find.text('Dentist'));
      await tester.pumpAndSettle();

      expect(find.text('Dentist'), findsOneWidget);
      expect(find.text('Budget review'), findsNothing);
    },
  );

  testWidgets('event tap opens detail sheet and edit saves calendar.update', (
    tester,
  ) async {
    final today = DateTime.now();
    final startAt = DateTime(today.year, today.month, today.day, 14);
    final endAt = DateTime(today.year, today.month, today.day, 15);
    final timezone = calendarDefaultTimezone();
    final updateStartAt = calendarWallTimeToUtc(
      date: startAt,
      hour: startAt.hour,
      minute: startAt.minute,
      timezone: timezone,
    );
    final updateEndAt = calendarWallTimeToUtc(
      date: endAt,
      hour: endAt.hour,
      minute: endAt.minute,
      timezone: timezone,
    );
    final event = {
      'event_id': 'event-1',
      'title': 'Budget review',
      'description': 'Revise forecast',
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'all_day': false,
      'color': '#ea4335',
    };
    stubCalendarList([event]);
    when(
      mockFunctionsClient.invoke(
        'app-hub',
        body: {
          'action': 'calendar.update',
          'id': 'event-1',
          'title': 'Budget review v2',
          'description': 'Revise forecast',
          'start_at': updateStartAt.toIso8601String(),
          'end_at': updateEndAt.toIso8601String(),
          'all_day': false,
          'color': '#ea4335',
          'reminder_min': null,
          'calendar_id': 'default',
          'rrule': null,
          'timezone': timezone,
        },
      ),
    ).thenAnswer((_) async => mockResponse({'success': true}));

    await tester.pumpWidget(testWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Budget review'));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Metadata'), findsOneWidget);
    expect(find.text('event_id'), findsOneWidget);
    expect(find.text('event-1'), findsOneWidget);
    expect(find.text('Budget review'), findsWidgets);
    expect(find.text('Revise forecast'), findsWidgets);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Budget review v2');
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    verify(
      mockFunctionsClient.invoke(
        'app-hub',
        body: {
          'action': 'calendar.update',
          'id': 'event-1',
          'title': 'Budget review v2',
          'description': 'Revise forecast',
          'start_at': updateStartAt.toIso8601String(),
          'end_at': updateEndAt.toIso8601String(),
          'all_day': false,
          'color': '#ea4335',
          'reminder_min': null,
          'calendar_id': 'default',
          'rrule': null,
          'timezone': timezone,
        },
      ),
    ).called(1);
  });

  testWidgets('add event dialog saves recurrence RRULE metadata', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    stubCalendarList(const []);
    when(
      mockFunctionsClient.invoke(
        'app-hub',
        body: argThat(
          isA<Map<String, dynamic>>().having(
            (body) => body['action'],
            'action',
            'calendar.create',
          ),
          named: 'body',
        ),
      ),
    ).thenAnswer(
      (_) async => mockResponse({
        'success': true,
        'event': {'event_id': 'event-daily'},
      }),
    );

    await tester.pumpWidget(testWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_timezone_dropdown')), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Daily standup');
    final recurrenceDropdown = find.byKey(
      const Key('calendar_recurrence_dropdown'),
    );
    await tester.ensureVisible(recurrenceDropdown);
    await tester.pumpAndSettle();
    await tester.tap(recurrenceDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    final captured = verify(
      mockFunctionsClient.invoke('app-hub', body: captureAnyNamed('body')),
    ).captured;
    expect(
      captured.whereType<Map<String, dynamic>>().any(
            (body) =>
                body['action'] == 'calendar.create' &&
                body['rrule'] == 'RRULE:FREQ=DAILY' &&
                body['timezone'] == calendarDefaultTimezone(),
          ),
      isTrue,
    );
  });

  testWidgets('recurring event edit asks for edit scope before form', (
    tester,
  ) async {
    final today = DateTime.now();
    final startAt = DateTime(today.year, today.month, today.day, 9);
    stubCalendarList([
      {
        'event_id': 'series-1',
        'title': 'Recurring planning',
        'start_at': startAt.toIso8601String(),
        'end_at': startAt.add(const Duration(hours: 1)).toIso8601String(),
        'all_day': false,
        'color': '#4285f4',
        'rrule': 'RRULE:FREQ=DAILY;COUNT=2',
      },
    ]);

    await tester.pumpWidget(testWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recurring planning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('This event only'), findsOneWidget);
    expect(find.text('This and following events'), findsOneWidget);
    expect(find.text('All events'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar_edit_scope_all')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar_recurrence_dropdown')),
      findsOneWidget,
    );
  });

  testWidgets('calendar drawer toggles visible calendars', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final today = DateTime.now();
    final startAt = DateTime(today.year, today.month, today.day, 10);
    final calendars = [
      {
        'calendar_id': 'default',
        'calendar_name': 'Default',
        'color': '#4285f4',
        'is_default': true,
      },
      {
        'calendar_id': 'work',
        'calendar_name': 'Work',
        'color': '#ea4335',
        'is_default': false,
      },
    ];
    final defaultEvent = {
      'event_id': 'event-default',
      'title': 'Default standup',
      'start_at': startAt.toIso8601String(),
      'end_at': startAt.add(const Duration(hours: 1)).toIso8601String(),
      'all_day': false,
      'color': '#4285f4',
      'calendar_id': 'default',
      'calendar_name': 'Default',
    };
    final workEvent = {
      'event_id': 'event-work',
      'title': 'Work review',
      'start_at': startAt.toIso8601String(),
      'end_at': startAt.add(const Duration(hours: 1)).toIso8601String(),
      'all_day': false,
      'color': '#ea4335',
      'calendar_id': 'work',
      'calendar_name': 'Work',
    };
    stubCalendarList([defaultEvent, workEvent], calendars: calendars);
    when(
      mockFunctionsClient.invoke(
        'app-hub',
        body: {
          'action': 'calendar.list',
          'calendar_ids': ['default'],
        },
      ),
    ).thenAnswer(
      (_) async => mockResponse({
        'success': true,
        'events': [defaultEvent],
      }),
    );

    await tester.pumpWidget(testWidget());
    await tester.pumpAndSettle();

    expect(find.text('Default standup'), findsOneWidget);
    expect(find.text('Work review'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar_original_timezone_toggle')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('calendar_toggle_work')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Calendars'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Default standup'), findsOneWidget);
    expect(find.text('Work review'), findsNothing);
    verify(
      mockFunctionsClient.invoke(
        'app-hub',
        body: {
          'action': 'calendar.list',
          'calendar_ids': ['default'],
        },
      ),
    ).called(1);
  });
}
