import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/pages/emergency_meeting_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'emergency_meeting_page_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<FunctionsClient>(),
  MockSpec<SupabaseQueryBuilder>(),
  MockSpec<User>(),
  MockSpec<FunctionResponse>(),
  MockSpec<PostgrestFilterBuilder<int>>(as: #MockPostgrestFilterBuilderInt),
  MockSpec<PostgrestFilterBuilder<List<Map<String, dynamic>>>>(
    as: #MockPostgrestFilterBuilderList,
  ),
  MockSpec<PostgrestTransformBuilder<List<Map<String, dynamic>>>>(
    as: #MockPostgrestTransformBuilderList,
  ),
  MockSpec<PostgrestTransformBuilder<Map<String, dynamic>>>(
    as: #MockPostgrestTransformBuilderMap,
  ),
  MockSpec<PostgrestTransformBuilder<Map<String, dynamic>?>>(
    as: #MockPostgrestTransformBuilderMapNullable,
  ),
])
void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late MockFunctionsClient mockFunctionsClient;
  late MockUser mockUser;

  late MockSupabaseQueryBuilder mockNotesBuilder;
  late MockSupabaseQueryBuilder mockSubsBuilder;
  late MockSupabaseQueryBuilder mockStatsBuilder;
  late MockSupabaseQueryBuilder mockMeetingBuilder;
  late MockSupabaseQueryBuilder mockMessageBuilder;

  late MockPostgrestFilterBuilderInt mockNotesFilter;
  late MockPostgrestFilterBuilderInt mockSubsFilter;
  late MockPostgrestFilterBuilderList mockFilterBuilderList;
  late MockPostgrestTransformBuilderList mockTransformBuilderList;
  late MockPostgrestTransformBuilderMap mockTransformBuilderMap;
  late MockPostgrestTransformBuilderMapNullable mockTransformBuilderMapNullable;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockFunctionsClient = MockFunctionsClient();
    mockUser = MockUser();

    mockNotesBuilder = MockSupabaseQueryBuilder();
    mockSubsBuilder = MockSupabaseQueryBuilder();
    mockStatsBuilder = MockSupabaseQueryBuilder();
    mockMeetingBuilder = MockSupabaseQueryBuilder();
    mockMessageBuilder = MockSupabaseQueryBuilder();

    mockNotesFilter = MockPostgrestFilterBuilderInt();
    mockSubsFilter = MockPostgrestFilterBuilderInt();
    mockFilterBuilderList = MockPostgrestFilterBuilderList();
    mockTransformBuilderList = MockPostgrestTransformBuilderList();
    mockTransformBuilderMap = MockPostgrestTransformBuilderMap();
    mockTransformBuilderMapNullable = MockPostgrestTransformBuilderMapNullable();

    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(mockGoTrueClient.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('test-user-id');
    when(mockSupabaseClient.functions).thenReturn(mockFunctionsClient);

    // テーブル定義 (上書き順序を考慮)
    when(mockSupabaseClient.from(any)).thenReturn(mockNotesBuilder);
    when(mockSupabaseClient.from('notes')).thenReturn(mockNotesBuilder);
    when(mockSupabaseClient.from('subscriptions')).thenReturn(mockSubsBuilder);
    when(mockSupabaseClient.from('user_stats')).thenReturn(mockStatsBuilder);
    when(mockSupabaseClient.from('board_meetings')).thenReturn(mockMeetingBuilder);
    when(mockSupabaseClient.from('board_messages')).thenReturn(mockMessageBuilder);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: EmergencyMeetingPage(supabaseClient: mockSupabaseClient),
    );
  }

  testWidgets('正常系: 招集ボタン押下でデータ収集・AI分析・保存が行われること', (WidgetTester tester) async {
    // --- 1. Notes (CKO) ---
    // count() -> eq() -> Future<int>
    // 【修正】thenAnswerで Future.value を返すことで、awaitで即座に値が取れるようにする
    when(mockNotesBuilder.count(any)).thenReturn(mockNotesFilter);
    when(mockNotesFilter.eq(any, any)).thenReturn(mockNotesFilter);
    when(mockNotesFilter.then(any, onError: anyNamed('onError')))
        .thenAnswer((Invocation inv) async {
      final callback = inv.positionalArguments[0] as Function(int);
      return callback(10);
    });

    // --- 2. Subscriptions (CFO) ---
    when(mockSubsBuilder.count(any)).thenReturn(mockSubsFilter);
    when(mockSubsFilter.eq(any, any)).thenReturn(mockSubsFilter);
    // catchError -> Future<int>
    when(mockSubsFilter.catchError(any, test: any)) // test引数を緩和
        .thenAnswer((_) async => 5);

    // --- 3. User Stats (CHRO) ---
    when(mockStatsBuilder.select(any)).thenReturn(mockFilterBuilderList);
    when(mockFilterBuilderList.eq(any, any)).thenReturn(mockFilterBuilderList);
    when(mockFilterBuilderList.maybeSingle())
        .thenReturn(mockTransformBuilderMapNullable);
    
    when(mockTransformBuilderMapNullable.then(any, onError: anyNamed('onError')))
        .thenAnswer((Invocation inv) async {
      final callback =
          inv.positionalArguments[0] as Function(Map<String, dynamic>?);
      return callback({'total_points': 1000, 'current_level': 5});
    });

    // --- 4. AI分析 (invoke) ---
    final aiResponse = {
      'success': true,
      'result': {
        'meeting_minutes': [
          {'role': 'CEO', 'speaker_name': 'Steve', 'content': '現状報告します。'},
        ],
        'conclusion': '今週末は休息が必要です。',
      },
    };
    final realFuncResp = FunctionResponse(data: aiResponse, status: 200);

    when(mockFunctionsClient.invoke(
      any,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
      method: anyNamed('method'),
    )).thenAnswer((_) async => realFuncResp);

    // --- 5. 会議保存 ---
    final mockMeetingInsertFilter = MockPostgrestFilterBuilderList();
    when(mockMeetingBuilder.insert(any)).thenReturn(mockMeetingInsertFilter);
    
    when(mockMeetingInsertFilter.select(any)).thenReturn(mockTransformBuilderList);
    when(mockTransformBuilderList.single()).thenReturn(mockTransformBuilderMap);
    
    when(mockTransformBuilderMap.then(any, onError: anyNamed('onError')))
        .thenAnswer((Invocation inv) async {
      final callback =
          inv.positionalArguments[0] as Function(Map<String, dynamic>);
      return callback({'id': 'meeting-123'});
    });

    // --- 6. メッセージ保存 ---
    final mockMessageInsertFilter = MockPostgrestFilterBuilderList();
    when(mockMessageBuilder.insert(any)).thenReturn(mockMessageInsertFilter);
    
    when(mockMessageInsertFilter.then(any, onError: anyNamed('onError')))
        .thenAnswer((Invocation inv) async {
      final callback = inv.positionalArguments[0] as Function(dynamic);
      return callback([]);
    });

    // --- テスト実行 ---
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('緊急招集する'));
    
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));

    if (find.text('STRATEGIC DECISION').evaluate().isEmpty) {
      debugPrint('--- DEBUG: Widgets on screen ---');
      find.byType(Text).evaluate().forEach((e) {
        debugPrint((e.widget as Text).data);
      });
    }

    expect(find.text('STRATEGIC DECISION'), findsOneWidget);
    expect(find.text('今週末は休息が必要です。'), findsOneWidget);
  });

  testWidgets('異常系: AIがエラーを返した場合', (WidgetTester tester) async {
    // 1. Notes
    when(mockNotesBuilder.count(any)).thenReturn(mockNotesFilter);
    when(mockNotesFilter.eq(any, any)).thenReturn(mockNotesFilter);
    when(mockNotesFilter.then(any, onError: anyNamed('onError')))
        .thenAnswer((inv) async => (inv.positionalArguments[0] as Function(int))(0));

    // 2. Subscriptions
    when(mockSubsBuilder.count(any)).thenReturn(mockSubsFilter);
    when(mockSubsFilter.eq(any, any)).thenReturn(mockSubsFilter);
    when(mockSubsFilter.catchError(any, test: any)).thenAnswer((_) async => 0);

    // 3. User Stats
    when(mockStatsBuilder.select(any)).thenReturn(mockFilterBuilderList);
    when(mockFilterBuilderList.eq(any, any)).thenReturn(mockFilterBuilderList);
    when(mockFilterBuilderList.maybeSingle())
        .thenReturn(mockTransformBuilderMapNullable);
    when(mockTransformBuilderMapNullable.then(any, onError: anyNamed('onError')))
        .thenAnswer((inv) async => (inv.positionalArguments[0] as Function(Map<String, dynamic>?))(null));

    // 4. AI Error
    final realErrResp = FunctionResponse(
      data: {'success': false, 'error': 'AI Busy'},
      status: 200,
    );
    when(mockFunctionsClient.invoke(
      any,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
      method: anyNamed('method'),
    )).thenAnswer((_) async => realErrResp);

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('緊急招集する'));
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('会議エラー'), findsOneWidget);
  });
}