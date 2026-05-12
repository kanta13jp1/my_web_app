@TestOn('browser')

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

  @override
  _FakePostgrestMutationBuilder update(Map values) {
    return _FakePostgrestMutationBuilder(
      rows: rows,
      updateValues: Map<String, dynamic>.from(values),
    );
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

class _FakePostgrestMutationBuilder extends Fake
    implements PostgrestFilterBuilder<dynamic> {
  _FakePostgrestMutationBuilder({
    required this.rows,
    required this.updateValues,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> updateValues;
  final Map<String, Object> _filters = <String, Object>{};

  @override
  _FakePostgrestMutationBuilder eq(String column, Object value) {
    _filters[column] = value;
    return this;
  }

  void _applyUpdate() {
    for (final row in rows) {
      final matches = _filters.entries.every(
        (entry) => row[entry.key] == entry.value,
      );
      if (matches) {
        row.addAll(updateValues);
      }
    }
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    _applyUpdate();
    return Future.value(null).then(onValue, onError: onError);
  }

  @override
  Future<dynamic> catchError(
    Function onError, {
    bool Function(Object)? test,
  }) {
    _applyUpdate();
    return Future.value(null).catchError(onError, test: test);
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
    final title = tester.widget<Text>(
      find.byKey(const Key('note_list_page_title')),
    );
    expect(title.data, contains('CKO OFFICE'));
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

    expect(find.text('Regular note'), findsNothing);
    expect(find.byIcon(Icons.list_alt), findsOneWidget);
  });

  testWidgets('archives a note from the popup delete action', (
    WidgetTester tester,
  ) async {
    final rows = <Map<String, dynamic>>[
      _noteRow(id: 'delete-note', title: 'Delete me', isFavorite: false),
    ];
    final client = _FakeSupabaseClient(noteRows: rows);

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListPage(supabaseClient: client),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete me'), findsOneWidget);

    await tester.tap(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(rows.first['is_archived'], isTrue);
    expect(find.text('Delete me'), findsNothing);
  });
}
