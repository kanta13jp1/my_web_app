import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Fakeクラスを使用するためにインポート
import 'package:my_web_app/pages/emergency_meeting_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Fake Classes Definition ---

/// SupabaseClient の Fake
class FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  final FakeGoTrueClient auth = FakeGoTrueClient();
  @override
  final FakeFunctionsClient functions = FakeFunctionsClient();

  final Map<String, FakeSupabaseQueryBuilder> _tables = {};

  // テスト用にテーブルごとのBuilderを取得・設定するヘルパー
  FakeSupabaseQueryBuilder getTable(String tableName) {
    return _tables.putIfAbsent(tableName, () => FakeSupabaseQueryBuilder());
  }

  @override
  SupabaseQueryBuilder from(String table) {
    return getTable(table);
  }
}

/// GoTrueClient (Auth) の Fake
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

/// FunctionsClient (Edge Functions) の Fake
class FakeFunctionsClient extends Fake implements FunctionsClient {
  FunctionResponse? nextResponse;

  @override
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, String>? headers,
    Object? body,
    Iterable<MultipartFile>? files,
    Map<String, dynamic>? queryParameters,
    HttpMethod? method = HttpMethod.post,
    String? region,
  }) async {
    return nextResponse ?? FunctionResponse(data: {}, status: 200);
  }
}

/// QueryBuilder の Fake
/// select, insert, count などの起点
class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  dynamic _data; // このテーブルが返す予定のデータ

  void setData(dynamic data) {
    _data = data;
  }

  @override
  PostgrestFilterBuilder<int> count([CountOption? option = CountOption.exact]) {
    // count() は int を返す Builder を生成
    return FakePostgrestFilterBuilder<int>(_data as int? ?? 0);
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String? columns = '*',
  ]) {
    // select() は List<Map> を返す Builder を生成
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
      _data as List<Map<String, dynamic>>? ?? [],
    );
  }

  @override
  PostgrestFilterBuilder<dynamic> insert(
    Object? values, {
    bool? defaultToNull = true,
  }) {
    // insert() は通常、挿入されたデータを返す Builder に繋がる
    // ここでは _data に設定された「挿入後のデータ（List<Map>）」を渡す
    return FakePostgrestFilterBuilder<dynamic>(_data);
  }
}

/// FilterBuilder の Fake (eq, catchError, then などを処理)
class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final T _value;

  FakePostgrestFilterBuilder(this._value);

  // --- Filter Methods (Chain) ---
  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  // --- Future Implementation ---
  // await されたときに呼ばれる
  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future.value(_value).then(onValue, onError: onError);
  }

  // catchError の実装
  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) {
    return Future.value(_value).catchError(onError, test: test);
  }

  // --- Transform Methods ---
  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    // List<Map> から Map? への変換をシミュレート
    if (_value is List) {
      final list = _value as List;
      return FakePostgrestTransformBuilder<Map<String, dynamic>?>(
        list.isNotEmpty ? list.first as Map<String, dynamic> : null,
      );
    }
    return FakePostgrestTransformBuilder<Map<String, dynamic>?>(null);
  }

  @override
  PostgrestTransformBuilder<List<Map<String, dynamic>>> select([
    String? columns = '*',
  ]) {
    // insert(...).select() のパターン
    return FakePostgrestTransformBuilder<List<Map<String, dynamic>>>(
      _value as List<Map<String, dynamic>>,
    );
  }
}

/// TransformBuilder の Fake (single, maybeSingle などの結果)
class FakePostgrestTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  final T _value;

  FakePostgrestTransformBuilder(this._value);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future.value(_value).then(onValue, onError: onError);
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>> single() {
    // List<Map> から Map への変換 (insert().select().single())
    if (_value is List) {
      final list = _value as List;
      if (list.isNotEmpty) {
        return FakePostgrestTransformBuilder<Map<String, dynamic>>(
          list.first as Map<String, dynamic>,
        );
      }
    }
    // フォールバック
    return FakePostgrestTransformBuilder<Map<String, dynamic>>(
      _value as Map<String, dynamic>,
    );
  }
}

// --- Test Main ---

void main() {
  late FakeSupabaseClient fakeSupabaseClient;

  setUp(() {
    fakeSupabaseClient = FakeSupabaseClient();
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: EmergencyMeetingPage(supabaseClient: fakeSupabaseClient),
    );
  }

  testWidgets('正常系: 招集ボタン押下でデータ収集・AI分析・保存が行われること', (WidgetTester tester) async {
    // 1. データ収集のモック設定
    fakeSupabaseClient.getTable('notes').setData(10); // count
    fakeSupabaseClient.getTable('subscriptions').setData(5); // count
    fakeSupabaseClient.getTable('user_stats').setData([
      {'total_points': 1000, 'current_level': 5},
    ]); // select -> maybeSingle

    // 2. AI分析のモック設定
    final aiResponseData = {
      'success': true,
      'result': {
        'meeting_minutes': [
          {'role': 'CEO', 'speaker_name': 'Steve', 'content': '現状報告します。'},
        ],
        'conclusion': '今週末は休息が必要です。',
      },
    };
    fakeSupabaseClient.functions.nextResponse =
        FunctionResponse(data: aiResponseData, status: 200);

    // 3. 保存処理のモック設定
    // insert -> select -> single で返されるデータ
    fakeSupabaseClient.getTable('board_meetings').setData([
      {'id': 'meeting-123', 'conclusion': '今週末は休息が必要です。'},
    ]);
    fakeSupabaseClient.getTable('board_messages').setData([]); // insert

    // --- テスト実行 ---
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('緊急招集する'));

    // 非同期処理の完了を待つ
    await tester.pump(const Duration(milliseconds: 500)); // データ収集 & AI
    await tester.pump(const Duration(milliseconds: 500)); // 保存 & UI更新
    await tester.pumpAndSettle();

    // 検証
    expect(find.text('STRATEGIC DECISION'), findsOneWidget);
    expect(find.text('今週末は休息が必要です。'), findsOneWidget);
  });

  testWidgets('異常系: AIがエラーを返した場合', (WidgetTester tester) async {
    // 1. データ収集 (正常)
    fakeSupabaseClient.getTable('notes').setData(0);
    fakeSupabaseClient.getTable('subscriptions').setData(0);
    fakeSupabaseClient.getTable('user_stats').setData([]); // null (maybeSingle)

    // 2. AI分析 (エラー)
    fakeSupabaseClient.functions.nextResponse = FunctionResponse(
      data: {'success': false, 'error': 'AI Busy'},
      status: 200,
    );

    // --- テスト実行 ---
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('緊急招集する'));

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 検証: SnackBarのエラーメッセージ
    expect(find.textContaining('会議エラー'), findsOneWidget);
  });
}
