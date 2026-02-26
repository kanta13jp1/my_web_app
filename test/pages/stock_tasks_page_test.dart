// ignore_for_file: must_be_immutable
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/stock_tasks_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  final _FakeGoTrueClient auth = _FakeGoTrueClient();

  final List<Map<String, dynamic>> somedayRows = <Map<String, dynamic>>[];
  int _idSeed = 1;

  @override
  SupabaseQueryBuilder from(String table) {
    if (table == 'someday_tasks') {
      return _FakeSupabaseQueryBuilder(
        rows: somedayRows,
        nextId: () => (_idSeed++).toString(),
      );
    }
    return _FakeSupabaseQueryBuilder(
      rows: <Map<String, dynamic>>[],
      nextId: () => (_idSeed++).toString(),
    );
  }
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => const User(
        id: 'test-user-id',
        appMetadata: <String, dynamic>{},
        userMetadata: <String, dynamic>{},
        aud: 'authenticated',
        createdAt: '2024-01-01',
      );
}

class _FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final List<Map<String, dynamic>> rows;
  final String Function() nextId;

  _FakeSupabaseQueryBuilder({
    required this.rows,
    required this.nextId,
  });

  @override
  _FakePostgrestFilterBuilder select([
    String? columns = '*',
  ]) {
    return _FakePostgrestFilterBuilder(rows: rows);
  }

  @override
  PostgrestFilterBuilder<dynamic> insert(
    Object values, {
    bool defaultToNull = true,
  }) {
    final List<Map<String, dynamic>> inserts;
    if (values is List) {
      inserts = values.whereType<Map<String, dynamic>>().toList();
    } else if (values is Map<String, dynamic>) {
      inserts = <Map<String, dynamic>>[values];
    } else {
      inserts = <Map<String, dynamic>>[];
    }

    for (final row in inserts) {
      final copy = Map<String, dynamic>.from(row);
      copy.putIfAbsent('id', () => nextId());
      copy.putIfAbsent('created_at', () => DateTime.now().toIso8601String());
      rows.add(copy);
    }
    return _FakePostgrestFilterBuilder(rows: rows);
  }
}

class _FakePostgrestFilterBuilder extends Fake
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  final List<Map<String, dynamic>> rows;
  final Map<String, Object> _filters = <String, Object>{};

  _FakePostgrestFilterBuilder({
    required this.rows,
  });

  @override
  _FakePostgrestFilterBuilder eq(String column, Object value) {
    _filters[column] = value;
    return this;
  }

  @override
  _FakePostgrestFilterBuilder order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    return this;
  }

  List<Map<String, dynamic>> _filtered() {
    return rows.where((row) {
      return _filters.entries.every((entry) => row[entry.key] == entry.value);
    }).toList();
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) {
    final payload =
        _filtered().map((row) => Map<String, dynamic>.from(row)).toList();
    return Future.value(payload).then(onValue, onError: onError);
  }

  @override
  Future<List<Map<String, dynamic>>> catchError(
    Function onError, {
    bool Function(Object)? test,
  }) {
    final payload =
        _filtered().map((row) => Map<String, dynamic>.from(row)).toList();
    return Future.value(payload).catchError(onError, test: test);
  }
}

void main() {
  testWidgets('can stock thinking topic and action task with different modes', (
    WidgetTester tester,
  ) async {
    final client = _FakeSupabaseClient();
    await tester.pumpWidget(
      MaterialApp(
        home: StockTasksPage(
          supabaseClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('時間があるときのストック'), findsOneWidget);
    expect(find.text('脳に余裕があるときに考えるネタ'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '抽象化の切り口を考える');
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pumpAndSettle();

    expect(client.somedayRows.length, 1);
    expect(client.somedayRows.first['category'], 'thinking_topic');
    expect(find.text('抽象化の切り口を考える'), findsOneWidget);

    await tester.tap(find.text('行動タスク').last);
    await tester.pumpAndSettle();
    expect(find.text('次に時間があるときにやること'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '資料フォルダを整理する');
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pumpAndSettle();

    expect(client.somedayRows.length, 2);
    expect(client.somedayRows.last['category'], 'action_task');
    expect(find.text('資料フォルダを整理する'), findsOneWidget);
  });
}
