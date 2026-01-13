import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/pages/emergency_meeting_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 型安全なモックを生成するための定義
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
    mockTransformBuilderMapNullable =
        MockPostgrestTransformBuilderMapNullable();

    // 基本設定
    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(mockGoTrueClient.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('test-user-id');
    when(mockSupabaseClient.functions).thenReturn(mockFunctionsClient);

    // from() は QueryBuilder を返す (FutureではないのでthenReturnでOK)
    when(mockSupabaseClient.from(any)).thenReturn(mockQueryBuilder);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: EmergencyMeetingPage(supabaseClient: mockSupabaseClient),
    );
  }

  // await (.then) をモックするためのヘルパー関数
  void setupAwait(Object mockBuilder, dynamic value) {
    if (mockBuilder is MockPostgrestFilterBuilderInt) {
      when(mockBuilder.then(any, onError: any)).thenAnswer((inv) {
        return (inv.positionalArguments[0] as Function(int))(value as int);
      });
      when(mockBuilder.catchError(any)).thenAnswer((inv) async => value as int);
    } else if (mockBuilder is MockPostgrestFilterBuilderList) {
      when(mockBuilder.then(any, onError: any)).thenAnswer((inv) {
        return (inv.positionalArguments[0] as Function(
            List<Map<String, dynamic>>))(
          value as List<Map<String, dynamic>>,
        );
      });
    } else if (mockBuilder is MockPostgrestTransformBuilderMapNullable) {
      when(mockBuilder.then(any, onError: any)).thenAnswer((inv) {
        return (inv.positionalArguments[0] as Function(Map<String, dynamic>?))(
          value as Map<String, dynamic>?,
        );
      });
    } else if (mockBuilder is MockPostgrestTransformBuilderMap) {
      when(mockBuilder.then(any, onError: any)).thenAnswer((inv) {
        return (inv.positionalArguments[0] as Function(Map<String, dynamic>))(
          value as Map<String, dynamic>,
        );
      });
    }
  }

  testWidgets('正常系: 招集ボタン押下でデータ収集・AI分析・保存が行われること', (WidgetTester tester) async {
    // --- 1. データ収集のモック ---

    // notes & subscriptions: count() -> eq() -> int (10)
    // 【重要】Builderを返すときは必ず thenAnswer を使う
    when(mockQueryBuilder.count(CountOption.exact))
        .thenAnswer((_) => mockFilterBuilderInt);
    when(mockFilterBuilderInt.eq(any, any))
        .thenAnswer((_) => mockFilterBuilderInt);
    setupAwait(mockFilterBuilderInt, 10);

    // user_stats: select() -> eq() -> maybeSingle() -> Map
    when(mockQueryBuilder.select()).thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.eq(any, any))
        .thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.maybeSingle())
        .thenAnswer((_) => mockTransformBuilderMapNullable);
    setupAwait(
      mockTransformBuilderMapNullable,
      {'total_points': 1000, 'current_level': 5},
    );

    // --- 2. AI分析のモック ---
    final aiResponse = {
      'success': true,
      'result': {
        'meeting_minutes': [
          {'role': 'CEO', 'speaker_name': 'Steve', 'content': '現状報告します。'},
        ],
        'conclusion': '今週末は休息が必要です。',
      },
    };
    final mockFuncResp = MockFunctionResponse();
    when(mockFuncResp.data).thenReturn(aiResponse);
    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: anyNamed('body'),
      ),
    ).thenAnswer((_) async => mockFuncResp);

    // --- 3. DB保存のモック ---

    // insert() -> select() -> single() -> Map (Meeting ID)
    when(mockQueryBuilder.insert(any)).thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.select())
        .thenAnswer((_) => mockTransformBuilderList);
    when(mockTransformBuilderList.single())
        .thenAnswer((_) => mockTransformBuilderMap);
    setupAwait(mockTransformBuilderMap, {'id': 'meeting-123'});

    // messages insert (void/List)
    // insert() 自体は mockFilterBuilderList を返すが、awaitで完了させるために空リストを返す設定
    // ※ setupAwaitは同じオブジェクトに対して上書きされるため、DB保存の直前ではなく
    //   このタイミング（他と被らないタイミング）か、一番最後に設定すると安全。
    //   ただし今回は mockFilterBuilderList.then が呼ばれるのはここだけなので大丈夫。
    setupAwait(mockFilterBuilderList, <Map<String, dynamic>>[]);

    // --- テスト実行 ---
    await tester.pumpWidget(createTestWidget());

    expect(find.text('緊急招集する'), findsOneWidget);

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

    // count
    when(mockQueryBuilder.count(any)).thenAnswer((_) => mockFilterBuilderInt);
    when(mockFilterBuilderInt.eq(any, any))
        .thenAnswer((_) => mockFilterBuilderInt);
    setupAwait(mockFilterBuilderInt, 0);

    // user_stats
    when(mockQueryBuilder.select()).thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.eq(any, any))
        .thenAnswer((_) => mockFilterBuilderList);
    when(mockFilterBuilderList.maybeSingle())
        .thenAnswer((_) => mockTransformBuilderMapNullable);
    setupAwait(mockTransformBuilderMapNullable, null);

    // AIエラーレスポンス
    final mockFuncResp = MockFunctionResponse();
    when(mockFuncResp.data).thenReturn({'success': false, 'error': 'AI Busy'});
    when(mockFunctionsClient.invoke(any, body: anyNamed('body')))
        .thenAnswer((_) async => mockFuncResp);

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('緊急招集する'));
    await tester.pumpAndSettle();

    // エラー表示確認
    expect(find.textContaining('会議エラー'), findsOneWidget);
  });
}
