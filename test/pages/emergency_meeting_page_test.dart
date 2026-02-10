// ignore_for_file: must_be_immutable
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/emergency_meeting_page.dart';
// import 'package:my_web_app/services/ai_model_service.dart';
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
      createdAt: '2023-01-01',);
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  dynamic _data;
  void setData(dynamic data) => _data = data;

  @override
  PostgrestFilterBuilder<int> count([CountOption? option]) =>
      FakePostgrestFilterBuilder<int>(_data as int? ?? 0);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select(
          [String? columns = '*',]) =>
      FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
          _data as List<Map<String, dynamic>>? ?? [],);

  @override
  PostgrestFilterBuilder<dynamic> insert(Object? values,
          {bool? defaultToNull = true,}) =>
      FakePostgrestFilterBuilder<dynamic>(_data);
}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final T _value;
  FakePostgrestFilterBuilder(this._value);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  Future<U> then<U>(FutureOr<U> Function(T value) onValue,
          {Function? onError,}) =>
      Future.value(_value).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) =>
      Future.value(_value).catchError(onError, test: test);

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    if (_value is List && (_value as List).isNotEmpty) {
      return FakePostgrestTransformBuilder<Map<String, dynamic>?>(
          (_value as List).first as Map<String, dynamic>,);
    }
    return FakePostgrestTransformBuilder<Map<String, dynamic>?>(null);
  }

  @override
  PostgrestTransformBuilder<List<Map<String, dynamic>>> select(
      [String? columns = '*',]) {
    return FakePostgrestTransformBuilder<List<Map<String, dynamic>>>(
        _value as List<Map<String, dynamic>>,);
  }
}

class FakePostgrestTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  final T _value;
  FakePostgrestTransformBuilder(this._value);

  @override
  Future<U> then<U>(FutureOr<U> Function(T value) onValue,
          {Function? onError,}) =>
      Future.value(_value).then(onValue, onError: onError);
  @override
  PostgrestTransformBuilder<Map<String, dynamic>> single() {
    if (_value is List && (_value as List).isNotEmpty) {
      return FakePostgrestTransformBuilder<Map<String, dynamic>>(
          (_value as List).first as Map<String, dynamic>,);
    }
    return FakePostgrestTransformBuilder<Map<String, dynamic>>(
        _value as Map<String, dynamic>,);
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

  Widget createTestWidget() {
    return MaterialApp(
      home: EmergencyMeetingPage(supabaseClient: fakeSupabaseClient),
    );
  }

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
