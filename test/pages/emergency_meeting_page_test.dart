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
  // 戻り値の型ごとに専用のMockクラスを生成
  MockSpec<PostgrestFilterBuilder<int>>(as: #MockPostgrestFilterBuilderInt),
  MockSpec<PostgrestFilterBuilder<List<Map<String, dynamic>>>>(
      as: #MockPostgrestFilterBuilderList),
  MockSpec<PostgrestTransformBuilder<List<Map<String, dynamic>>>>(
      as: #MockPostgrestTransformBuilderList),
  MockSpec<PostgrestTransformBuilder<Map<String, dynamic>>>(
      as: #MockPostgrestTransformBuilderMap),
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

  // 型付きモック
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
    mockTransformBuilderMapNullable =
        MockPostgrestTransformBuilderMapNullable();

    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(mockGoTrueClient.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('test-user-id');
    when(mockSupabaseClient.functions).thenReturn(mockFunctionsClient);
    // fromはFutureではないのでthenReturnでOK
    when(mockSupabaseClient.from(any)).thenReturn(mockQueryBuilder);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: EmergencyMeetingPage(supabaseClient: mockSupabaseClient),
    );
  }

  testWidgets('正常系: 招集ボタン押下でデータ収集・AI分析・保存が行われること', (WidgetTester tester) async {
    // --- 1. データ収集のモック ---

    // notes & subscriptions: count() -> eq() -> int (10)
    // ビルダーを返す部分には thenAnswer を使用
    when(mockQueryBuilder.count(CountOption.exact))
        .thenAnswer((_) => mockFilterBuilderInt);
    when(mockFilterBuilderInt.eq(any, any))
        .thenAnswer((_) => mockFilterBuilderInt);

    // await (.then) された際に、コールバックを実行して値を返す (10)
    when(mockFilterBuilderInt.then(any, onError: any))
        .thenAnswer((Invocation inv) {
      final callback = inv.positionalArguments[0] as Function(int);
      return callback(10);
    });

    // user_stats: select() -> eq() -> maybeSingle() -> Map
    when(mockQueryBuilder.select()).thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.eq(any, any))
        .thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.maybeSingle())
        .thenAnswer((_) => mockTransformBuilderMapNullable);

    // maybeSingle()のawait対応
    when(mockTransformBuilderMapNullable.then(any, onError: any))
        .thenAnswer((Invocation inv) {
      final callback =
          inv.positionalArguments[0] as Function(Map<String, dynamic>?);
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

    // 【修正箇所】MockFunctionResponseを使わず、本物のFunctionResponseを使う
    // これにより "thenReturn should not be used to return a Future" エラーを回避
    final realFuncResp = FunctionResponse(data: aiResponse, status: 200);

    // Edge Functionsの呼び出し (Futureを返すのでthenAnswer)
    when(mockFunctionsClient.invoke(
      'ai-assistant',
      body: anyNamed('body'),
    )).thenAnswer((_) async => realFuncResp);

    // --- 3. DB保存のモック ---

    // insert() -> select() -> single() -> Map (Meeting ID)
    when(mockQueryBuilder.insert(any)).thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.select())
        .thenAnswer((_) => mockTransformBuilderList);
    when(mockTransformBuilderList.single())
        .thenAnswer((_) => mockTransformBuilderMap);

    // single()のawait対応
    when(mockTransformBuilderMap.then(any, onError: any))
        .thenAnswer((Invocation inv) {
      final callback =
          inv.positionalArguments[0] as Function(Map<String, dynamic>);
      return callback({'id': 'meeting-123'});
    });

    // messages insert (void/List)
    // insert()自体は mockFilterBuilderList を返すが、await完了用に空リストを返す
    // 注意: mockFilterBuilderList.then は上で定義していないのでここで定義
    when(mockFilterBuilderList.then(any, onError: any))
        .thenAnswer((Invocation inv) {
      final callback = inv.positionalArguments[0] as Function(dynamic);
      return callback([]);
    });

    // --- テスト実行 ---
    await tester.pumpWidget(createTestWidget());

    // 初期表示確認
    expect(find.text('緊急招集する'), findsOneWidget);

    // ボタンタップ
    await tester.tap(find.text('緊急招集する'));
    await tester.pump(); // ローディング開始
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle(); // 処理完了

    // 結果確認
    expect(find.text('STRATEGIC DECISION'), findsOneWidget);
    expect(find.text('今週末は休息が必要です。'), findsOneWidget);
    expect(find.text('Steve'), findsOneWidget);
  });

  testWidgets('異常系: AIがエラーを返した場合', (WidgetTester tester) async {
    // データ収集 (0件 / null)

    when(mockQueryBuilder.count(any)).thenAnswer((_) => mockFilterBuilderInt);
    when(mockFilterBuilderInt.eq(any, any))
        .thenAnswer((_) => mockFilterBuilderInt);

    // await -> 0
    when(mockFilterBuilderInt.then(any, onError: any))
        .thenAnswer((Invocation inv) {
      return (inv.positionalArguments[0] as Function(int))(0);
    });

    when(mockQueryBuilder.select()).thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.eq(any, any))
        .thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.maybeSingle())
        .thenAnswer((_) => mockTransformBuilderMapNullable);

    // await -> null
    when(mockTransformBuilderMapNullable.then(any, onError: any))
        .thenAnswer((Invocation inv) {
      return (inv.positionalArguments[0] as Function(
          Map<String, dynamic>?))(null);
    });

    // AIエラーレスポンス
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
