// ignore_for_file: must_be_immutable
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_web_app/pages/mindless_task_page.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ja');
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
}
