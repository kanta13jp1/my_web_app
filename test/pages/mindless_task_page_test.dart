// ignore_for_file: must_be_immutable
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_web_app/pages/mindless_task_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  final FakeGoTrueClient auth = FakeGoTrueClient();

  @override
  SupabaseQueryBuilder from(String table) => FakeSupabaseQueryBuilder();
}

class FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => const User(
        id: 'test-user-id',
        appMetadata: <String, dynamic>{},
        userMetadata: <String, dynamic>{},
        aud: 'authenticated',
        createdAt: '2024-01-01',
      );
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String? columns = '*',
  ]) {
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
      <Map<String, dynamic>>[],
    );
  }
}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final T _value;

  FakePostgrestFilterBuilder(this._value);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    return this;
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future.value(_value).then(onValue, onError: onError);
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) {
    return Future.value(_value).catchError(onError, test: test);
  }
}

class StatefulSupabaseClient extends Fake implements SupabaseClient {
  @override
  final FakeGoTrueClient auth = FakeGoTrueClient();

  final List<Map<String, dynamic>> _mindlessTasks = <Map<String, dynamic>>[];

  int _idSeed = 1;
  int get taskCount => _mindlessTasks.length;

  @override
  SupabaseQueryBuilder from(String table) {
    if (table == 'mindless_tasks') {
      return StatefulSupabaseQueryBuilder(
        rows: _mindlessTasks,
        nextId: () => _idSeed++,
      );
    }
    return FakeSupabaseQueryBuilder();
  }
}

class StatefulSupabaseQueryBuilder extends Fake
    implements SupabaseQueryBuilder {
  final List<Map<String, dynamic>> rows;
  final int Function() nextId;

  StatefulSupabaseQueryBuilder({
    required this.rows,
    required this.nextId,
  });

  @override
  StatefulPostgrestFilterBuilder select([
    String? columns = '*',
  ]) {
    return StatefulPostgrestFilterBuilder(rows);
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
      copy.putIfAbsent('id', nextId);
      rows.add(copy);
    }
    return StatefulPostgrestFilterBuilder(rows);
  }
}

class StatefulPostgrestFilterBuilder extends Fake
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  final List<Map<String, dynamic>> _sourceRows;
  final Map<String, Object> _filters = <String, Object>{};

  StatefulPostgrestFilterBuilder(this._sourceRows);

  @override
  StatefulPostgrestFilterBuilder eq(String column, Object value) {
    _filters[column] = value;
    return this;
  }

  @override
  StatefulPostgrestFilterBuilder order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    return this;
  }

  List<Map<String, dynamic>> _filtered() {
    return _sourceRows
        .where((row) {
          return _filters.entries
              .every((entry) => row[entry.key] == entry.value);
        })
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) {
    return Future.value(_filtered()).then(onValue, onError: onError);
  }

  @override
  Future<List<Map<String, dynamic>>> catchError(
    Function onError, {
    bool Function(Object)? test,
  }) {
    return Future.value(_filtered()).catchError(onError, test: test);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ja');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders timebox panel and can start moving session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MindlessTaskPage(
          supabaseClient: FakeSupabaseClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.hourglass_bottom), findsOneWidget);
    expect(find.byIcon(Icons.directions_run), findsOneWidget);

    await tester.ensureVisible(find.byIcon(Icons.directions_run));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.directions_run));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Write post');

    final confirmButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );
    await tester.tap(confirmButton.first);
    await tester.pumpAndSettle();

    expect(find.textContaining(': Write post'), findsOneWidget);
  });

  testWidgets('can quick start reading album session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MindlessTaskPage(
          supabaseClient: FakeSupabaseClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.library_music), findsOneWidget);

    await tester.ensureVisible(find.byIcon(Icons.library_music));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.library_music));
    await tester.pump();

    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    expect(find.textContaining('読書:'), findsOneWidget);
  });

  testWidgets('shows 100-task controls and opens batch add dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MindlessTaskPage(
          supabaseClient: FakeSupabaseClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('100タスク量産モード'), findsOneWidget);
    expect(find.textContaining('/ 100 完了'), findsOneWidget);

    await tester.ensureVisible(find.text('5件バッチ追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5件バッチ追加'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('5件バッチを追加'), findsOneWidget);
  });

  testWidgets('shows phone detox panel and opens detox template dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MindlessTaskPage(
          supabaseClient: FakeSupabaseClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('スマホ禁欲プロトコル'), findsOneWidget);
    expect(find.textContaining('8項目を追加'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('8項目を追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('8項目を追加'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('スマホ禁欲8項目を追加'), findsOneWidget);
  });

  testWidgets('can switch to flowchart todo view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MindlessTaskPage(
          supabaseClient: FakeSupabaseClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('時系列リスト'), findsOneWidget);
    expect(find.text('フローチャート'), findsOneWidget);

    await tester.tap(find.text('フローチャート'));
    await tester.pumpAndSettle();

    expect(find.text('フローチャートToDo'), findsNothing);
    expect(
      find.text('タスクを追加すると、ここにフローチャート形式で導線を表示します。'),
      findsOneWidget,
    );
  });

  testWidgets('detox template insert is diff-based across repeated runs', (
    WidgetTester tester,
  ) async {
    final client = StatefulSupabaseClient();
    await tester.pumpWidget(
      MaterialApp(
        home: MindlessTaskPage(
          supabaseClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('8項目を追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('8項目を追加'));
    await tester.pumpAndSettle();

    final addInDialogFirst = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('追加'),
    );
    await tester.tap(addInDialogFirst.first);
    await tester.pumpAndSettle();

    expect(find.textContaining('スマホ禁欲項目を8件追加しました。'), findsOneWidget);
    expect(client.taskCount, 8);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('8項目を追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('8項目を追加'));
    await tester.pumpAndSettle();

    final addInDialogSecond = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('追加'),
    );
    await tester.tap(addInDialogSecond.first);
    await tester.pumpAndSettle();

    expect(find.text('すでに追加済みです。'), findsOneWidget);
    expect(client.taskCount, 8);
  });

  testWidgets('critical lock blocks optional start flows until completion', (
    WidgetTester tester,
  ) async {
    final client = StatefulSupabaseClient();
    await tester.pumpWidget(
      MaterialApp(
        home: MindlessTaskPage(
          supabaseClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日の必須タスク・ロック'), findsOneWidget);

    await tester.ensureVisible(find.text('必須タスクを展開'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('必須タスクを展開'));
    await tester.pumpAndSettle();

    expect(find.textContaining('必須タスクを4件追加しました。'), findsOneWidget);
    expect(client.taskCount, 4);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('動くを開始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('動くを開始'));
    await tester.pumpAndSettle();

    expect(find.text('先に必須タスクを完了してください。'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('phone lock auto-syncs detox tasks and starts lock timer', (
    WidgetTester tester,
  ) async {
    final client = StatefulSupabaseClient();
    await tester.pumpWidget(
      MaterialApp(
        home: MindlessTaskPage(
          supabaseClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('物理ロック90分'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('物理ロック90分'));
    await tester.pump();

    expect(find.textContaining('スマホ禁欲項目を8件自動追加しました。'), findsOneWidget);
    expect(find.textContaining('物理ロック:'), findsOneWidget);
    expect(client.taskCount, 8);
  });

  testWidgets('defense guide shows checklist and can add a target', (
    WidgetTester tester,
  ) async {
    final client = StatefulSupabaseClient();
    await tester.pumpWidget(
      MaterialApp(
        home: MindlessTaskPage(
          supabaseClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('必須タスクを展開'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('必須タスクを展開'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('「朝10分の防衛チェック'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('「朝10分の防衛チェック'));
    await tester.pumpAndSettle();

    expect(find.text('チェック対象TODO'), findsOneWidget);
    expect(find.text('メール: メイン受信箱'), findsOneWidget);
    expect(find.text('SMS'), findsOneWidget);
    expect(find.text('DM'), findsOneWidget);

    await tester.tap(find.text('チェック対象を追加'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'メール: 副業用Gmail');
    final addButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('追加'),
    );
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('メール: 副業用Gmail'), findsOneWidget);
  });

  testWidgets('flowchart nodes show edit controls for manual linking', (
    WidgetTester tester,
  ) async {
    final client = StatefulSupabaseClient();
    await tester.pumpWidget(
      MaterialApp(
        home: MindlessTaskPage(
          supabaseClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('必須タスクを展開'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('必須タスクを展開'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('フローチャート'));
    await tester.pumpAndSettle();

    expect(find.text('自動整列'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
  });
}
