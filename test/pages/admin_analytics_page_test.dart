import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/admin_analytics_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ignore_for_file: must_be_immutable

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final _queryBuilder = FakeSupabaseQueryBuilder();

  FakeSupabaseQueryBuilder get queryBuilder => _queryBuilder;

  @override
  SupabaseQueryBuilder from(String table) {
    _queryBuilder.setTable(table);
    return _queryBuilder;
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  List<Map<String, dynamic>> _data = <Map<String, dynamic>>[];
  bool _shouldThrow = false;
  String _table = '';

  void setTable(String table) {
    _table = table;
  }

  void setData(dynamic data) {
    if (data is List) {
      _data = data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      _data = <Map<String, dynamic>>[];
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
    final count =
        _table == 'user_profiles' ? _resolveUserCount() : _data.length;
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
      _data,
      _shouldThrow,
      count: count,
    );
  }

  int _resolveUserCount() {
    if (_data.isEmpty) return 0;
    final first = _data.first;
    final userCount = first['user_count'];
    if (userCount is num) return userCount.toInt();
    return _data.length;
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
    if (invocation.memberName == #order || invocation.memberName == #limit) {
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

  setUp(() {
    fakeSupabaseClient = FakeSupabaseClient();
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: AdminAnalyticsPage(supabaseClient: fakeSupabaseClient),
    );
  }

  final sampleData = [
    {
      'date': '2023-10-27',
      'landing_views': 100,
      'conversions': 10,
      'share_count': 5,
      'source_details': {'direct': 80, 'x_share': 20},
    },
    {
      'date': '2023-10-26',
      'landing_views': 80,
      'conversions': 12,
      'share_count': 3,
      'source_details': {'direct': 70, 'google': 10},
    },
  ];

  testWidgets('AdminAnalyticsPage shows data after loading',
      (WidgetTester tester) async {
    // Setup mock data
    fakeSupabaseClient.queryBuilder.setData(sampleData);

    // Build the widget
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Expect data to be displayed
    expect(find.text('12.2'), findsOneWidget);
    expect(find.text('180'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });

  testWidgets('Refresh button reloads the data', (WidgetTester tester) async {
    // Initial data
    fakeSupabaseClient.queryBuilder.setData(sampleData);
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify initial data
    expect(find.text('180'), findsOneWidget);

    // New data for refresh
    final newData = [
      {
        'date': '2023-10-28',
        'landing_views': 50,
        'conversions': 5,
        'share_count': 2,
        'source_details': {'direct': 50},
      },
    ];
    fakeSupabaseClient.queryBuilder.setData(newData);

    // Tap refresh button
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    // Verify new data
    expect(find.text('50'), findsWidgets);
  });

  testWidgets('Shows empty state when there is no data',
      (WidgetTester tester) async {
    // Setup empty data
    fakeSupabaseClient.queryBuilder.setData([]);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('0.0'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('Handles Supabase error gracefully', (WidgetTester tester) async {
    // Setup error
    fakeSupabaseClient.queryBuilder.setShouldThrow(true);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Should not be loading anymore, but should not show data either
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // It should just show an empty state as the error is caught and it sets loading to false
    expect(find.text('0.0'), findsOneWidget);
  });
}
