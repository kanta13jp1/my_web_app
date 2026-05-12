// ignore_for_file: must_be_immutable
@TestOn('browser')

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/board_meeting.dart';
import 'package:my_web_app/pages/emergency_meeting_page.dart';
import 'package:my_web_app/services/emergency_meeting_pdca_service.dart';
import 'package:my_web_app/services/notification_service.dart';
// import 'package:my_web_app/services/ai_model_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// import 'emergency_meeting_page_test.mocks.dart';

// --- Fake Classes Definition (Supabase) ---

class FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  final FakeGoTrueClient auth = FakeGoTrueClient();
  final Map<String, FakeSupabaseQueryBuilder> _tables = {};
  FakeSupabaseQueryBuilder getTable(String tableName) =>
      _tables.putIfAbsent(tableName, () => FakeSupabaseQueryBuilder());
  @override
  SupabaseQueryBuilder from(String table) => getTable(table);
}

class FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => const User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2023-01-01',
      );
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  dynamic _data;
  void setData(dynamic data) => _data = data;

  @override
  PostgrestFilterBuilder<int> count([CountOption? option]) =>
      FakePostgrestFilterBuilder<int>(_data as int? ?? 0);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String? columns = '*',
  ]) =>
      FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
        _data as List<Map<String, dynamic>>? ?? [],
      );

  @override
  PostgrestFilterBuilder<dynamic> insert(
    Object? values, {
    bool? defaultToNull = true,
  }) =>
      FakePostgrestFilterBuilder<dynamic>(_data);
}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final T _value;
  FakePostgrestFilterBuilder(this._value);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) =>
      Future.value(_value).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) =>
      Future.value(_value).catchError(onError, test: test);

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    if (_value is List && (_value as List).isNotEmpty) {
      return FakePostgrestTransformBuilder<Map<String, dynamic>?>(
        (_value as List).first as Map<String, dynamic>,
      );
    }
    return FakePostgrestTransformBuilder<Map<String, dynamic>?>(null);
  }

  @override
  PostgrestTransformBuilder<List<Map<String, dynamic>>> select([
    String? columns = '*',
  ]) {
    return FakePostgrestTransformBuilder<List<Map<String, dynamic>>>(
      _value as List<Map<String, dynamic>>,
    );
  }
}

class FakePostgrestTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  final T _value;
  FakePostgrestTransformBuilder(this._value);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) =>
      Future.value(_value).then(onValue, onError: onError);
  @override
  PostgrestTransformBuilder<Map<String, dynamic>> single() {
    if (_value is List && (_value as List).isNotEmpty) {
      return FakePostgrestTransformBuilder<Map<String, dynamic>>(
        (_value as List).first as Map<String, dynamic>,
      );
    }
    return FakePostgrestTransformBuilder<Map<String, dynamic>>(
      _value as Map<String, dynamic>,
    );
  }
}

// --- Test Main ---
// @GenerateMocks([AIModelService])
void main() {
  late FakeSupabaseClient fakeSupabaseClient;
  // late MockAIModelService mockAIModelService;

  setUp(() {
    fakeSupabaseClient = FakeSupabaseClient();
    // mockAIModelService = MockAIModelService();
    // AIModelService.setInstance(mockAIModelService);

    // Provide a dummy API key to pass the initial check
    SharedPreferences.setMockInitialValues({
      'gemini_api_key': 'test-api-key',
    });
  });

  // ignore: unused_element
  Widget createTestWidget({
    BoardMeetingLog? initialLog,
    List<String> initialContinuationPlan = const <String>[],
    List<String> initialAbstinenceRules = const <String>[],
    EmergencyMeetingPdcaMetrics? initialMetrics,
  }) {
    return Provider<NotificationService>.value(
      value: NotificationService(),
      child: MaterialApp(
        home: EmergencyMeetingPage(
          supabaseClient: fakeSupabaseClient,
          initialLog: initialLog,
          initialContinuationPlan: initialContinuationPlan,
          initialAbstinenceRules: initialAbstinenceRules,
          initialMetrics: initialMetrics,
        ),
      ),
    );
  }

  BoardMeetingLog buildSeedLog() {
    final now = DateTime.parse('2026-04-02T12:00:00.000Z');
    return BoardMeetingLog(
      id: 'meeting-seed',
      userId: 'test-user-id',
      topic: '緊急役員会議',
      conclusion: '最重要タスクを固定し、禁欲を崩さず前進する。',
      messages: <BoardMessage>[
        BoardMessage(
          id: 'm1',
          speakerName: 'AI CFO',
          role: 'CFO',
          content: '固定費を見直してください。',
          timestamp: now,
        ),
        BoardMessage(
          id: 'm2',
          speakerName: 'AI CKO',
          role: 'CKO',
          content: '25分で初手まで進めてください。',
          timestamp: now,
        ),
      ],
      createdAt: now,
    );
  }

  testWidgets('seeded meeting shows new continuation and deterrence controls',
      (WidgetTester tester) async {
    final log = buildSeedLog();
    const metrics = EmergencyMeetingPdcaMetrics(
      continuationCompletedCount: 0,
      continuationTotalCount: 3,
      continuationCompletionRatePercent: 0,
      continuationPriorityDeclaredCount: 1,
      continuationQuickStartCount: 1,
      continuationFocusSprint25Count: 1,
      continuationTimeBlockReservedCount: 1,
      continuationProgressLogCount: 0,
      abstinenceViolationCount: 0,
      abstinenceNoViolationDays: 2,
      abstinenceRuleCompletedCount: 1,
      abstinenceRuleTotalCount: 3,
      abstinenceRuleCompletionRatePercent: 33,
      abstinenceRecoveredWithin10mCount: 0,
      abstinenceRecoveryWindowMissedCount: 0,
      deepWorkSessionCount: 0,
      weeklyPriorityReviewCount: 0,
      accountabilityShareCount: 0,
      abstinenceRecoveryActionCount: 0,
      reminderEnabled: true,
      deterrenceLockEnabledCount: 1,
      deterrenceStrictModeBlockCount: 0,
      deterrenceDisableAttemptBlockedCount: 0,
      deterrenceLockCoveragePercent: 33,
      abstinenceRecoveryReminderScheduledCount: 0,
      activeDeterrenceLocks: <String>['SNS制限ロック'],
    );

    await tester.pumpWidget(
      createTestWidget(
        initialLog: log,
        initialContinuationPlan: const <String>[
          '今日中に最重要タスクを1件だけ決め、25分で初手まで進める。',
          '次の48時間のカレンダーに、継続案件の固定ブロックを最低1枠入れる。',
          '会議の結論を1人に共有し、完了条件と期限を先に宣言する。',
        ],
        initialAbstinenceRules: const <String>[
          '今日中に 1 つだけ防止ロックを有効化する。',
          '回復フローを維持し、次回も 10 分以内の立て直しを続ける。',
          '今日中にリマインダーを 1 件だけ設定する。',
        ],
        initialMetrics: metrics,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日の最重要1件'), findsOneWidget);
    expect(
      find.byKey(const Key('continuation_focus_sprint_25_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('continuation_pin_priority_button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('continuation_pin_action_0')), findsOneWidget);
    expect(find.textContaining('抑止準備度:'), findsOneWidget);
    expect(find.text('次回会議の検証指標'), findsOneWidget);
  });

  testWidgets('pinning and starting focus sprint updates the continuation lane',
      (WidgetTester tester) async {
    final log = buildSeedLog();
    const metrics = EmergencyMeetingPdcaMetrics(
      continuationCompletedCount: 0,
      continuationTotalCount: 3,
      continuationCompletionRatePercent: 0,
      continuationPriorityDeclaredCount: 0,
      continuationQuickStartCount: 0,
      continuationFocusSprint25Count: 0,
      continuationTimeBlockReservedCount: 0,
      continuationProgressLogCount: 0,
      abstinenceViolationCount: 0,
      abstinenceNoViolationDays: 0,
      abstinenceRuleCompletedCount: 0,
      abstinenceRuleTotalCount: 3,
      abstinenceRuleCompletionRatePercent: 0,
      abstinenceRecoveredWithin10mCount: 0,
      abstinenceRecoveryWindowMissedCount: 0,
      deepWorkSessionCount: 0,
      weeklyPriorityReviewCount: 0,
      accountabilityShareCount: 0,
      abstinenceRecoveryActionCount: 0,
      reminderEnabled: false,
      deterrenceLockEnabledCount: 0,
      deterrenceStrictModeBlockCount: 0,
      deterrenceDisableAttemptBlockedCount: 0,
      deterrenceLockCoveragePercent: 0,
      abstinenceRecoveryReminderScheduledCount: 0,
      activeDeterrenceLocks: <String>[],
    );

    await tester.pumpWidget(
      createTestWidget(
        initialLog: log,
        initialContinuationPlan: const <String>[
          'Aを進める',
          'Bを進める',
          'Cを進める',
        ],
        initialAbstinenceRules: const <String>[
          'ルール1',
          'ルール2',
          'ルール3',
        ],
        initialMetrics: metrics,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('continuation_pin_action_1')));
    await tester.pumpAndSettle();

    expect(find.text('最重要: Bを進める'), findsOneWidget);

    await tester
        .tap(find.byKey(const Key('continuation_focus_sprint_25_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('25分着手を開始しました: Bを進める'), findsOneWidget);
    expect(find.textContaining('最重要宣言: 1回 / 25分着手: 1回'), findsOneWidget);
  });

  /*
  testWidgets('正常系: 招集ボタン押下でデータ収集・AI分析・保存が行われること', (WidgetTester tester) async {
    // 1. データ収集のモック設定
    fakeSupabaseClient.getTable('notes').setData(10);
    fakeSupabaseClient.getTable('subscriptions').setData(5);
    fakeSupabaseClient.getTable('user_stats').setData([
      {'total_points': 1000, 'current_level': 5},
    ]);

    // 2. AI分析のモック設定
    final aiResponseJson = {
      'messages': [
        {'role': 'CEO', 'speaker_name': 'Steve', 'content': '現状報告します。'},
      ],
      'conclusion': '今週末は休息が必要です。',
    };
    when(mockAIModelService.generateContent(
            model: anyNamed('model'),
            apiKey: anyNamed('apiKey'),
            prompt: anyNamed('prompt'),),)
        .thenAnswer((_) async => jsonEncode(aiResponseJson));

    // 3. 保存処理のモック設定
    fakeSupabaseClient.getTable('board_meetings').setData([
      {'id': 'meeting-123', 'conclusion': '今週末は休息が必要です。'},
    ]);
    fakeSupabaseClient.getTable('board_messages').setData([]);

    // --- テスト実行 ---
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('緊急招集する'));
    await tester.pumpAndSettle();

    // 検証
    expect(find.text('STRATEGIC DECISION'), findsOneWidget);
    expect(find.text('今週末は休息が必要です。'), findsOneWidget);
  });

  testWidgets('異常系: AIがエラーを返した場合', (WidgetTester tester) async {
    // 1. データ収集 (正常)
    fakeSupabaseClient.getTable('notes').setData(0);
    fakeSupabaseClient.getTable('subscriptions').setData(0);
    fakeSupabaseClient.getTable('user_stats').setData(<Map<String, dynamic>>[]); // null (maybeSingle)

    // 2. AI分析 (エラー)
    when(mockAIModelService.generateContent(
            model: anyNamed('model'),
            apiKey: anyNamed('apiKey'),
            prompt: anyNamed('prompt'),),)
        .thenThrow(Exception('AI Busy'));

    // --- テスト実行 ---
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('緊急招集する'));
    await tester.pumpAndSettle();

    // 検証: エラーメッセージ
    expect(find.textContaining('会議エラー: Exception: AI Busy'), findsOneWidget);
  });
  */
}
