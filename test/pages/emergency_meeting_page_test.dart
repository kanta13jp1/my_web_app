import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/pages/emergency_meeting_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'emergency_meeting_page_test.mocks.dart';

@GenerateMocks(
  [
    SupabaseClient,
    GoTrueClient,
    FunctionsClient,
    SupabaseQueryBuilder,
    User,
    FunctionResponse,
  ],
  customMocks: [
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
  ],
)
void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late MockFunctionsClient mockFunctionsClient;
  late MockUser mockUser;

  late MockSupabaseQueryBuilder mockCommonBuilder;
  late MockSupabaseQueryBuilder mockStatsBuilder;
  late MockSupabaseQueryBuilder mockMeetingBuilder;
  late MockSupabaseQueryBuilder mockMessageBuilder;

  late MockPostgrestFilterBuilderInt mockFilterBuilderInt;
  late MockPostgrestFilterBuilderList mockFilterBuilderList;
  late MockPostgrestTransformBuilderList mockTransformBuilderList;
  late MockPostgrestTransformBuilderMap mockTransformBuilderMap;
  late MockPostgrestTransformBuilderMapNullable mockTransformBuilderMapNullable;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockFunctionsClient = MockFunctionsClient();
    mockUser = MockUser();

    mockCommonBuilder = MockSupabaseQueryBuilder();
    mockStatsBuilder = MockSupabaseQueryBuilder();
    mockMeetingBuilder = MockSupabaseQueryBuilder();
    mockMessageBuilder = MockSupabaseQueryBuilder();

    mockFilterBuilderInt = MockPostgrestFilterBuilderInt();
    mockFilterBuilderList = MockPostgrestFilterBuilderList();
    mockTransformBuilderList = MockPostgrestTransformBuilderList();
    mockTransformBuilderMap = MockPostgrestTransformBuilderMap();
    mockTransformBuilderMapNullable = MockPostgrestTransformBuilderMapNullable();

    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(mockGoTrueClient.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('test-user-id');
    when(mockSupabaseClient.functions).thenReturn(mockFunctionsClient);

    when(mockSupabaseClient.from(any)).thenAnswer((_) => mockCommonBuilder);
    when(mockSupabaseClient.from('user_stats')).thenAnswer((_) => mockStatsBuilder);
    when(mockSupabaseClient.from('board_meetings')).thenAnswer((_) => mockMeetingBuilder);
    when(mockSupabaseClient.from('board_meeting_messages')).thenAnswer((_) => mockMessageBuilder);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: EmergencyMeetingPage(supabaseClient: mockSupabaseClient),
    );
  }

  testWidgets('正常系: 招集ボタン押下でデータ収集・AI分析・保存が行われること', (WidgetTester tester) async {
    // --- 1. データ収集 ---
    when(mockCommonBuilder.count(any)).thenAnswer((_) => mockFilterBuilderInt);
    when(mockFilterBuilderInt.eq(any, any)).thenAnswer((_) => mockFilterBuilderInt);
    
    when(mockFilterBuilderInt.then(any, onError: anyNamed('onError')))
        .thenAnswer((Invocation inv) {
      final callback = inv.positionalArguments[0] as Function(int);
      return callback(10);
    });
    when(mockFilterBuilderInt.catchError(any, test: anyNamed('test')))
        .thenAnswer((_) async => 10);

    // --- 2. ユーザー統計 ---
    when(mockStatsBuilder.select()).thenAnswer((_) => mockFilterBuilderList);
    when(mockStatsBuilder.select(any)).thenAnswer((_) => mockFilterBuilderList);

    when(mockFilterBuilderList.eq(any, any)).thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.maybeSingle())
        .thenAnswer((_) => mockTransformBuilderMapNullable);
    
    when(mockTransformBuilderMapNullable.then(any, onError: anyNamed('onError')))
        .thenAnswer((Invocation inv) {
      final callback =
          inv.positionalArguments[0] as Function(Map<String, dynamic>?);
      return callback({'total_points': 1000, 'current_level': 5});
    });
    when(mockTransformBuilderMapNullable.catchError(any, test: anyNamed('test')))
        .thenAnswer((_) async => {'total_points': 1000, 'current_level': 5});

    // --- 3. AI分析 ---
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

    // invokeのモック
    when(mockFunctionsClient.invoke('ai-assistant', body: anyNamed('body')))
        .thenAnswer((_) async => realFuncResp);
        
    // 【追加】invokeのcatchError対応（ここが漏れていた可能性があります）
    // invokeはFuture<FunctionResponse>を返すため、もし.catchErrorを使っているならスタブが必要
    // ただしMockitoの制限でFuture型のメソッドに対するcatchErrorスタブは書きにくい場合があるため
    // まずは通常invokeが成功するように設定し、エラーハンドリングが邪魔しないように祈ります。
    // （FunctionResponseが返れば通常catchErrorには行かないはず）

    // --- 4. 会議保存 ---
    final mockMeetingInsertFilter = MockPostgrestFilterBuilderList();
    when(mockMeetingBuilder.insert(any))
        .thenAnswer((_) => mockMeetingInsertFilter);
    
    when(mockMeetingInsertFilter.select())
        .thenAnswer((_) => mockTransformBuilderList);
    when(mockMeetingInsertFilter.select(any))
        .thenAnswer((_) => mockTransformBuilderList);
        
    when(mockTransformBuilderList.single())
        .thenAnswer((_) => mockTransformBuilderMap);
    
    when(mockTransformBuilderMap.then(any, onError: anyNamed('onError')))
        .thenAnswer((Invocation inv) {
      final callback =
          inv.positionalArguments[0] as Function(Map<String, dynamic>);
      return callback({'id': 'meeting-123'});
    });
    when(mockTransformBuilderMap.catchError(any, test: anyNamed('test')))
        .thenAnswer((_) async => {'id': 'meeting-123'});

    // --- 5. メッセージ保存 ---
    final mockMessageInsertFilter = MockPostgrestFilterBuilderList();
    when(mockMessageBuilder.insert(any))
        .thenAnswer((_) => mockMessageInsertFilter);
    
    when(mockMessageInsertFilter.then(any, onError: anyNamed('onError')))
        .thenAnswer((Invocation inv) {
      final callback = inv.positionalArguments[0] as Function(dynamic);
      return callback([]);
    });
    when(mockMessageInsertFilter.catchError(any, test: anyNamed('test')))
        .thenAnswer((_) async => []);

    // --- テスト実行 ---
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('緊急招集する'));
    
    // 【修正点】段階的に時間を進めて状態遷移を促す
    // データ収集完了待ち
    await tester.pump(const Duration(seconds: 1));
    // AI分析待ち
    await tester.pump(const Duration(seconds: 2));
    // DB保存待ち
    await tester.pump(const Duration(seconds: 2));

    // デバッグ出力
    if (find.text('STRATEGIC DECISION').evaluate().isEmpty) {
      debugPrint('--- TEST FAILED: Current Widgets on Screen ---');
      find.byType(Text).evaluate().forEach((element) {
        final textWidget = element.widget as Text;
        debugPrint('Text: "${textWidget.data}"');
      });
      debugPrint('--------------------------------------------');
    }

    // 結果確認
    expect(find.text('STRATEGIC DECISION'), findsOneWidget);
    expect(find.text('今週末は休息が必要です。'), findsOneWidget);
  });

  testWidgets('異常系: AIがエラーを返した場合', (WidgetTester tester) async {
    // 1. Data Collection
    when(mockCommonBuilder.count(any)).thenAnswer((_) => mockFilterBuilderInt);
    when(mockFilterBuilderInt.eq(any, any)).thenAnswer((_) => mockFilterBuilderInt);
    
    when(mockFilterBuilderInt.then(any, onError: anyNamed('onError')))
        .thenAnswer((Invocation inv) {
      return (inv.positionalArguments[0] as Function(int))(0);
    });
    when(mockFilterBuilderInt.catchError(any, test: anyNamed('test')))
        .thenAnswer((_) async => 0);

    // 2. User Stats
    when(mockStatsBuilder.select()).thenAnswer((_) => mockFilterBuilderList);
    when(mockStatsBuilder.select(any)).thenAnswer((_) => mockFilterBuilderList);
    
    when(mockFilterBuilderList.eq(any, any)).thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.maybeSingle())
        .thenAnswer((_) => mockTransformBuilderMapNullable);
    
    when(mockTransformBuilderMapNullable.then(any, onError: anyNamed('onError')))
        .thenAnswer((Invocation inv) {
      return (inv.positionalArguments[0] as Function(Map<String, dynamic>?))(
          null);
    });
    when(mockTransformBuilderMapNullable.catchError(any, test: anyNamed('test')))
        .thenAnswer((_) async => null);

    // 3. AI Error
    final realErrResp = FunctionResponse(
      data: {'success': false, 'error': 'AI Busy'},
      status: 200,
    );

    when(mockFunctionsClient.invoke(any, body: anyNamed('body')))
        .thenAnswer((_) async => realErrResp);

    // Execute
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('緊急招集する'));
    
    // 【修正点】段階的に時間を進める
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('会議エラー'), findsOneWidget);
  });
}