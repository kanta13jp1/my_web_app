// admin_analytics_page.dart transitively imports dart:js_interop via
// home_tool_catalog → election_victory_page → package:web — browser only.
@TestOn('browser')

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/admin_analytics_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ignore_for_file: must_be_immutable

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final _queryBuilder = FakeSupabaseQueryBuilder();
  final Map<String, dynamic> _rpcResponses = <String, dynamic>{};

  FakeSupabaseQueryBuilder get queryBuilder => _queryBuilder;

  void setRpcResponse(String functionName, dynamic data) {
    _rpcResponses[functionName] = data;
  }

  @override
  SupabaseQueryBuilder from(String table) {
    _queryBuilder.setTable(table);
    return _queryBuilder;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #rpc) {
      final functionName = invocation.positionalArguments.isEmpty
          ? ''
          : invocation.positionalArguments.first.toString();
      return FakePostgrestFilterBuilder<dynamic>(
        _rpcResponses[functionName] ?? <String, dynamic>{},
        false,
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final Map<String, List<Map<String, dynamic>>> _tableData =
      <String, List<Map<String, dynamic>>>{};
  bool _shouldThrow = false;
  String _table = '';

  List<Map<String, dynamic>> get _activeData =>
      _tableData[_table] ?? <Map<String, dynamic>>[];

  void setTable(String table) {
    _table = table;
  }

  void setData(dynamic data, {String table = 'app_analytics'}) {
    if (data is List) {
      _tableData[table] = data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      _tableData[table] = <Map<String, dynamic>>[];
    }
    _shouldThrow = false;
  }

  void setShouldThrow(bool should) {
    _shouldThrow = should;
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String? columns = '*',
  ]) {
    final data = _activeData;
    final count =
        _table == 'user_profiles' ? _resolveUserCount(data) : data.length;
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
      data,
      _shouldThrow,
      count: count,
    );
  }

  int _resolveUserCount(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 0;
    final first = data.first;
    final userCount = first['user_count'];
    if (userCount is num) return userCount.toInt();
    return data.length;
  }

  SupabaseQueryBuilder order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
  }) =>
      this;

  SupabaseQueryBuilder limit(int count) => this;
}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final T _value;
  final bool _shouldThrow;
  final int _count;

  FakePostgrestFilterBuilder(
    this._value,
    this._shouldThrow, {
    int count = 0,
  }) : _count = count;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future.delayed(const Duration(milliseconds: 1), () {
      if (_shouldThrow) {
        throw Exception('Supabase error');
      }
      return _value;
    }).then(onValue, onError: onError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #order ||
        invocation.memberName == #limit ||
        invocation.memberName == #gte ||
        invocation.memberName == #lte ||
        invocation.memberName == #eq) {
      return this;
    }
    if (invocation.memberName == #count) {
      return FakeResponsePostgrestBuilder<T>(
        value: _value,
        shouldThrow: _shouldThrow,
        count: _count,
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeResponsePostgrestBuilder<T> extends Fake
    implements ResponsePostgrestBuilder<PostgrestResponse<T>, T, T> {
  final T value;
  final bool shouldThrow;
  final int count;

  FakeResponsePostgrestBuilder({
    required this.value,
    required this.shouldThrow,
    required this.count,
  });

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestResponse<T> value) onValue, {
    Function? onError,
  }) {
    return Future.delayed(const Duration(milliseconds: 1), () {
      if (shouldThrow) {
        throw Exception('Supabase error');
      }
      return PostgrestResponse<T>(data: value, count: count);
    }).then(onValue, onError: onError);
  }
}

void main() {
  late FakeSupabaseClient fakeSupabaseClient;

  String formatDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  List<Map<String, dynamic>> sampleData() {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    return [
      {
        'date': formatDate(today),
        'landing_views': 100,
        'conversions': 10,
        'share_count': 5,
        'source_details': {
          'direct': 80,
          'x_share': 20,
          'funnel_trial_run': 40,
          'funnel_save_cta': 18,
          'funnel_magic_link_send': 12,
          'funnel_inbox_open': 8,
          'funnel_billing_view': 30,
          'funnel_upgrade_click': 9,
          'funnel_checkout_success': 6,
          'funnel_checkout_cancel': 2,
        },
      },
      {
        'date': formatDate(yesterday),
        'landing_views': 80,
        'conversions': 12,
        'share_count': 3,
        'source_details': {'direct': 70, 'google': 10},
      },
    ];
  }

  List<Map<String, dynamic>> profileData({
    required int todayRegistrations,
    required int previousRegistrations,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    final yesterday = today.subtract(const Duration(days: 1));
    return [
      for (var i = 0; i < todayRegistrations; i++)
        {'created_at': today.toIso8601String()},
      for (var i = 0; i < previousRegistrations; i++)
        {'created_at': yesterday.toIso8601String()},
    ];
  }

  setUp(() {
    fakeSupabaseClient = FakeSupabaseClient();
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: AdminAnalyticsPage(supabaseClient: fakeSupabaseClient),
    );
  }

  testWidgets('AdminAnalyticsPage shows data after loading',
      (WidgetTester tester) async {
    fakeSupabaseClient.queryBuilder
      ..setData(sampleData())
      ..setData(
        profileData(todayRegistrations: 10, previousRegistrations: 12),
        table: 'user_profiles',
      );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('今日CVR (実登録ベース)'), findsOneWidget);
    expect(find.text('10.0'), findsOneWidget);
    expect(find.text('今日Magic Link送信'), findsOneWidget);
    expect(find.text('登録管理の追加指標'), findsOneWidget);
    expect(find.text('今日の登録ファネル'), findsOneWidget);
    expect(find.text('過去30日の登録ファネル'), findsOneWidget);
    expect(find.text('過去30日の課金ファネル'), findsOneWidget);
    expect(find.text('獲得元別コホート判断証拠'), findsOneWidget);
    expect(find.text('プラン別ユニットエコノミクス'), findsOneWidget);
    expect(find.text('集計信号 150'), findsOneWidget);
    expect(find.textContaining('ユーザーコホート人数として扱いません'), findsWidgets);
    expect(find.byKey(const Key('plan_economics_empty')), findsOneWidget);
    final billingCard = find.byKey(const Key('billing_funnel_card'));
    final billingMetrics = tester
        .widgetList<RichText>(
          find.descendant(of: billingCard, matching: find.byType(RichText)),
        )
        .map((widget) => widget.text.toPlainText())
        .toList();
    expect(billingMetrics, contains('課金ページ表示 30'));
    expect(billingMetrics, contains('アップグレードクリック 9'));
    expect(billingMetrics, contains('決済成功 6'));
    expect(billingMetrics, contains('決済キャンセル 2'));
    expect(billingMetrics, contains('表示→クリック 30.0%'));
    expect(billingMetrics, contains('クリック→成功 66.7%'));
  });

  testWidgets('Shows funnel-based action when trial has not started',
      (WidgetTester tester) async {
    fakeSupabaseClient.queryBuilder
      ..setData([
        {
          'date': formatDate(DateTime.now()),
          'landing_views': 1,
          'share_count': 0,
          'source_details': {
            'direct': 1,
          },
        },
      ])
      ..setData(
        profileData(todayRegistrations: 0, previousRegistrations: 0),
        table: 'user_profiles',
      );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('診断 体験未実行', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('今やる単独改善アクション'), findsOneWidget);
    expect(find.text('AI改善で体験導線改善'), findsOneWidget);
    expect(find.text('登録管理の追加指標'), findsOneWidget);
    expect(find.text('今日の登録ファネル'), findsOneWidget);
    expect(
      find.textContaining('目標達成に必要な送信', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Refresh button reloads the data', (WidgetTester tester) async {
    fakeSupabaseClient.queryBuilder
      ..setData(sampleData())
      ..setData(
        profileData(todayRegistrations: 10, previousRegistrations: 12),
        table: 'user_profiles',
      );
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('10.0'), findsOneWidget);

    final newData = [
      {
        'date': formatDate(DateTime.now()),
        'landing_views': 50,
        'share_count': 2,
        'source_details': {
          'direct': 50,
          'funnel_trial_run': 10,
          'funnel_save_cta': 5,
          'funnel_magic_link_send': 2,
        },
      },
    ];
    fakeSupabaseClient.queryBuilder
      ..setData(newData)
      ..setData(
        profileData(todayRegistrations: 2, previousRegistrations: 0),
        table: 'user_profiles',
      );

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('4.0'), findsOneWidget);
  });

  testWidgets('Shows paid conversion metrics from admin billing summary',
      (WidgetTester tester) async {
    fakeSupabaseClient.setRpcResponse(
      'get_billing_paid_conversion_summary',
      [
        {'paid_customers': 2, 'mrr_yen': 3960},
      ],
    );
    fakeSupabaseClient.queryBuilder
      ..setData(sampleData())
      ..setData(
        profileData(todayRegistrations: 2, previousRegistrations: 18),
        table: 'user_profiles',
      );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('有料転換'), findsOneWidget);
    expect(find.text('課金ユーザー数'), findsOneWidget);
    expect(find.text('MRR'), findsOneWidget);
    expect(find.text('free→paid CVR'), findsOneWidget);
    expect(find.text('¥3,960'), findsOneWidget);
    expect(find.text('10.0%'), findsWidgets);
  });

  testWidgets('Shows empty state when there is no data',
      (WidgetTester tester) async {
    fakeSupabaseClient.queryBuilder
      ..setData([])
      ..setData([], table: 'user_profiles');

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('0.0'), findsOneWidget);
    expect(find.text('今日の登録目標'), findsOneWidget);
    expect(find.text('有料転換'), findsOneWidget);
    expect(find.text('過去30日の課金ファネル'), findsOneWidget);
    expect(find.byKey(const Key('acquisition_evidence_empty')), findsOneWidget);
    expect(find.byKey(const Key('plan_economics_empty')), findsOneWidget);
    expect(find.text('¥0'), findsOneWidget);
  });

  testWidgets('Handles Supabase error gracefully', (WidgetTester tester) async {
    fakeSupabaseClient.queryBuilder.setShouldThrow(true);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('0.0'), findsOneWidget);
  });
}
