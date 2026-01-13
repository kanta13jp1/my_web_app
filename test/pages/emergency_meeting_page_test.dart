import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/pages/emergency_meeting_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 型安全なモック定義
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  FunctionsClient,
  SupabaseQueryBuilder,
  User,
  FunctionResponse,
], customMocks: [
  // count() 用
  MockSpec<PostgrestFilterBuilder<int>>(as: #MockPostgrestFilterBuilderInt),
  // select() 用
  MockSpec<PostgrestFilterBuilder<List<Map<String, dynamic>>>>(
      as: #MockPostgrestFilterBuilderList),
  // insert().select() 用
  MockSpec<PostgrestTransformBuilder<List<Map<String, dynamic>>>>(
      as: #MockPostgrestTransformBuilderList),
  // single() 用
  MockSpec<PostgrestTransformBuilder<Map<String, dynamic>>>(
      as: #MockPostgrestTransformBuilderMap),
  // maybeSingle() 用
  MockSpec<PostgrestTransformBuilder<Map<String, dynamic>?>>(
      as: #MockPostgrestTransformBuilderMapNullable),
])
import 'emergency_meeting_page_test.mocks.dart';

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late MockFunctionsClient mockFunctionsClient;
  late MockUser mockUser;
  late MockSupabaseQueryBuilder mockQueryBuilder;

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
    mockQueryBuilder = MockSupabaseQueryBuilder();

    mockFilterBuilderInt = MockPostgrestFilterBuilderInt();
    mockFilterBuilderList = MockPostgrestFilterBuilderList();
    mockTransformBuilderList = MockPostgrestTransformBuilderList();
    mockTransformBuilderMap = MockPostgrestTransformBuilderMap();
    mockTransformBuilderMapNullable = MockPostgrestTransformBuilderMapNullable();

    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(mockGoTrueClient.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('test-user-id');
    when(mockSupabaseClient.functions).thenReturn(mockFunctionsClient);
    // from()はFutureではないのでthenReturnでOK
    when(mockSupabaseClient.from(any)).thenReturn(mockQueryBuilder);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: EmergencyMeetingPage(supabaseClient: mockSupabaseClient),
    );
  }

  testWidgets('正常系: 招集ボタン押下でデータ収集・AI分析・保存が行われること', (WidgetTester tester) async {
    // --- 1. データ収集のモック ---

    // count() -> thenAnswerでビルダーを返す
    when(mockQueryBuilder.count(CountOption.exact))
        .thenAnswer((_) => mockFilterBuilderInt);
    // eq() -> thenAnswerでビルダーを返す
    when(mockFilterBuilderInt.eq(any, any))
        .thenAnswer((_) => mockFilterBuilderInt);
    
    // awaitされたときの挙動 (.then)
    when(mockFilterBuilderInt.then(any, onError: any)).thenAnswer((invocation) {
      final callback = invocation.positionalArguments[0] as Function(int);
      return callback(10); // 10件
    });
    // catchError対策
    when(mockFilterBuilderInt.catchError(any)).thenAnswer((invocation) async => 10);

    // select() -> thenAnswer
    when(mockQueryBuilder.select())
        .thenAnswer((_) => mockFilterBuilderList);
    // eq() -> thenAnswer
    when(mockFilterBuilderList.eq(any, any))
        .thenAnswer((_) => mockFilterBuilderList);
    // maybeSingle() -> thenAnswer
    when(mockFilterBuilderList.maybeSingle())
        .thenAnswer((_) => mockTransformBuilderMapNullable);
    
    // maybeSingle()のawait
    when(mockTransformBuilderMapNullable.then(any, onError: any)).thenAnswer((invocation) {
      final callback = invocation.positionalArguments[0] as Function(Map<String, dynamic>?);
      return callback({'total_points': 1000, 'current_level': 5});
    });

    // --- 2. AI分析のモック ---
    final aiResponse = {
      'success': true,
      'result': {
        'meeting_minutes': [
          {'role': 'CEO', 'speaker_name': 'Steve', 'content': '現状報告します。'}
        ],
        'conclusion': '今週末は休息が必要です。'
      }
    };
    final mockFuncResp = MockFunctionResponse();
    when(mockFuncResp.data).thenReturn(aiResponse);
    
    // AI呼び出しはFutureなのでthenAnswer
    when(mockFunctionsClient.invoke(
      'ai-assistant',
      body: anyNamed('body'),
    )).thenAnswer((_) async => mockFuncResp);

    // --- 3. DB保存のモック ---
    
    // insert() -> select() -> single()
    when(mockQueryBuilder.insert(any))
        .thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.select())
        .thenAnswer((_) => mockTransformBuilderList);
    when(mockTransformBuilderList.single())
        .thenAnswer((_) => mockTransformBuilderMap);
    
    // single()のawait (Meeting IDを返す)
    when(mockTransformBuilderMap.then(any, onError: any)).thenAnswer((invocation) {
      final callback = invocation.positionalArguments[0] as Function(Map<String, dynamic>);
      return callback({'id': 'meeting-123'});
    });

    // messages insert (void/List)
    // insert()自体は mockFilterBuilderList を返すが、awaitで完了させるために空リストを返す設定
    // 注意: 上記でmockFilterBuilderList.thenは設定していないのでここで設定
    when(mockFilterBuilderList.then(any, onError: any)).thenAnswer((invocation) {
      final callback = invocation.positionalArguments[0] as Function(dynamic);
      return callback([]); // 完了
    });

    // --- テスト実行 ---
    await tester.pumpWidget(createTestWidget());

    expect(find.text('緊急招集する'), findsOneWidget);

    await tester.tap(find.text('緊急招集する'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('STRATEGIC DECISION'), findsOneWidget);
    expect(find.text('今週末は休息が必要です。'), findsOneWidget);
    expect(find.text('Steve'), findsOneWidget);
  });

  testWidgets('異常系: AIがエラーを返した場合', (WidgetTester tester) async {
    // --- データ収集モック (0件 / null) ---
    
    when(mockQueryBuilder.count(any))
        .thenAnswer((_) => mockFilterBuilderInt);
    when(mockFilterBuilderInt.eq(any, any))
        .thenAnswer((_) => mockFilterBuilderInt);
    // await -> 0
    when(mockFilterBuilderInt.then(any, onError: any)).thenAnswer((invocation) {
      return (invocation.positionalArguments[0] as Function(int))(0);
    });
    when(mockFilterBuilderInt.catchError(any)).thenAnswer((invocation) async => 0);

    when(mockQueryBuilder.select())
        .thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.eq(any, any))
        .thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.maybeSingle())
        .thenAnswer((_) => mockTransformBuilderMapNullable);
    // await -> null
    when(mockTransformBuilderMapNullable.then(any, onError: any)).thenAnswer((invocation) {
      return (invocation.positionalArguments[0] as Function(Map<String, dynamic>?))(null);
    });

    // --- AIエラーレスポンス ---
    final mockFuncResp = MockFunctionResponse();
    when(mockFuncResp.data).thenReturn({'success': false, 'error': 'AI Busy'});
    when(mockFunctionsClient.invoke(any, body: anyNamed('body')))
        .thenAnswer((_) async => mockFuncResp);

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('緊急招集する'));
    await tester.pumpAndSettle();

    expect(find.textContaining('会議エラー'), findsOneWidget);
  });
}