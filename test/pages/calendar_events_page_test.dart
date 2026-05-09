import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/pages/calendar_events_page.dart';
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

  void stubCalendarList(List<Map<String, dynamic>> events) {
    when(
      mockFunctionsClient.invoke('app-hub', body: {'action': 'calendar.list'}),
    ).thenAnswer(
      (_) async => mockResponse({'success': true, 'events': events}),
    );
  }

  Widget testWidget() {
    return MaterialApp(
      home: CalendarEventsPage(supabaseClient: mockSupabaseClient),
    );
  }

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

  testWidgets('event tap opens detail sheet and edit saves calendar.update', (
    tester,
  ) async {
    final today = DateTime.now();
    final startAt = DateTime(today.year, today.month, today.day, 14);
    final endAt = DateTime(today.year, today.month, today.day, 15);
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
          'start_at': startAt.toIso8601String(),
          'end_at': endAt.toIso8601String(),
          'all_day': false,
          'color': '#ea4335',
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
          'start_at': startAt.toIso8601String(),
          'end_at': endAt.toIso8601String(),
          'all_day': false,
          'color': '#ea4335',
        },
      ),
    ).called(1);
  });
}
