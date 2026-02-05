import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/admin_analytics_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final _queryBuilder = FakeSupabaseQueryBuilder();
  
  FakeSupabaseQueryBuilder get queryBuilder => _queryBuilder;

  @override
  SupabaseQueryBuilder from(String table) {
    return _queryBuilder;
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  dynamic _data;
  bool _shouldThrow = false;

  void setData(dynamic data) {
    _data = data;
    _shouldThrow = false;
  }
  
  void setShouldThrow(bool should) {
    _shouldThrow = should;
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([String? columns = '*']) {
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(_data, _shouldThrow);
  }

  @override
  SupabaseQueryBuilder order(String column, {bool ascending = false, bool nullsFirst = false}) => this;

  @override
  SupabaseQueryBuilder limit(int count) => this;
}

class FakePostgrestFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final T _value;
  final bool _shouldThrow;

  FakePostgrestFilterBuilder(this._value, this._shouldThrow);

  @override
  Future<U> then<U>(FutureOr<U> Function(T value) onValue, {Function? onError}) {
    return Future.delayed(const Duration(milliseconds: 1), () {
      if (_shouldThrow) {
        throw Exception('Supabase error');
      }
      return _value;
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

  testWidgets('AdminAnalyticsPage shows data after loading', (WidgetTester tester) async {
    // Setup mock data
    fakeSupabaseClient.queryBuilder.setData(sampleData);

    // Build the widget
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Expect data to be displayed
    expect(find.text('12.2%'), findsOneWidget);
    expect(find.text('180'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('150 人'), findsOneWidget);
    expect(find.text('20 人'), findsOneWidget);
    expect(find.text('10 人'), findsOneWidget);
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
      expect(find.text('50'), findsOneWidget);
  });

    testWidgets('Shows empty state when there is no data', (WidgetTester tester) async {
    // Setup empty data
    fakeSupabaseClient.queryBuilder.setData([]);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('0.0%'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3)); // views, conversions, shares
    expect(find.text('データなし'), findsOneWidget);
  });

  testWidgets('Handles Supabase error gracefully', (WidgetTester tester) async {
    // Setup error
    fakeSupabaseClient.queryBuilder.setShouldThrow(true);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Should not be loading anymore, but should not show data either
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // It should just show an empty state as the error is caught and it sets loading to false
    expect(find.text('0.0%'), findsOneWidget);
  });
}
