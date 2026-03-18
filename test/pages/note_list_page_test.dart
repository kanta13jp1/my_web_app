import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/note_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  _FakeSupabaseClient({
    required this.noteRows,
  });

  @override
  final _FakeGoTrueClient auth = _FakeGoTrueClient();

  final List<Map<String, dynamic>> noteRows;

  @override
  SupabaseQueryBuilder from(String table) {
    if (table == 'notes') {
      return _FakeSupabaseQueryBuilder(rows: noteRows);
    }
    return _FakeSupabaseQueryBuilder(rows: <Map<String, dynamic>>[]);
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
  _FakeSupabaseQueryBuilder({
    required this.rows,
  });

  final List<Map<String, dynamic>> rows;

  @override
  _FakePostgrestFilterBuilder select([
    String? columns = '*',
  ]) {
    return _FakePostgrestFilterBuilder(rows: rows);
  }
}

class _FakePostgrestFilterBuilder extends Fake
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  _FakePostgrestFilterBuilder({
    required this.rows,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, Object> _filters = <String, Object>{};

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
    return rows
        .where((row) {
          return _filters.entries.every((entry) => row[entry.key] == entry.value);
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

Map<String, dynamic> _noteRow({
  required String id,
  required String title,
  required bool isFavorite,
  String userId = 'test-user-id',
}) {
  return <String, dynamic>{
    'id': id,
    'user_id': userId,
    'title': title,
    'content': '$title body',
    'created_at': '2026-03-18T09:00:00.000Z',
    'is_pinned': false,
    'is_favorite': isFavorite,
    'is_archived': false,
    'reminder_date': null,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('filters the list down to favorite notes', (
    WidgetTester tester,
  ) async {
    final client = _FakeSupabaseClient(
      noteRows: <Map<String, dynamic>>[
        _noteRow(id: 'favorite-note', title: 'Favorite note', isFavorite: true),
        _noteRow(id: 'regular-note', title: 'Regular note', isFavorite: false),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListPage(supabaseClient: client),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Favorite note'), findsOneWidget);
    expect(find.text('Regular note'), findsOneWidget);

    await tester.tap(find.byKey(const Key('note_list_page_favorites_filter')));
    await tester.pumpAndSettle();

    expect(find.text('Favorite note'), findsOneWidget);
    expect(find.text('Regular note'), findsNothing);
    expect(find.text('CKO OFFICE (お気に入り)'), findsOneWidget);
  });

  testWidgets('shows the dedicated empty state when no favorites exist', (
    WidgetTester tester,
  ) async {
    final client = _FakeSupabaseClient(
      noteRows: <Map<String, dynamic>>[
        _noteRow(id: 'regular-note', title: 'Regular note', isFavorite: false),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListPage(supabaseClient: client),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note_list_page_favorites_filter')));
    await tester.pumpAndSettle();

    expect(find.text('お気に入りのメモはまだありません'), findsOneWidget);
    expect(find.text('すべてのメモを見る'), findsOneWidget);
  });
}
