import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/note_list_page.dart';
import 'package:my_web_app/services/note_semantic_search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  _FakeSupabaseClient({
    required this.noteRows,
    this.shouldFailUpdate = false,
  });

  @override
  final _FakeGoTrueClient auth = _FakeGoTrueClient();

  final List<Map<String, dynamic>> noteRows;
  final bool shouldFailUpdate;
  final List<
      ({
        Map<String, dynamic> values,
        Map<String, Object> filters,
      })> updates = <({
    Map<String, dynamic> values,
    Map<String, Object> filters,
  })>[];

  @override
  SupabaseQueryBuilder from(String table) {
    if (table == 'notes') {
      return _FakeSupabaseQueryBuilder(
        rows: noteRows,
        updates: updates,
        shouldFailUpdate: shouldFailUpdate,
      );
    }
    return _FakeSupabaseQueryBuilder(
      rows: <Map<String, dynamic>>[],
      updates: updates,
      shouldFailUpdate: false,
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
  _FakeSupabaseQueryBuilder({
    required this.rows,
    required this.updates,
    required this.shouldFailUpdate,
  });

  final List<Map<String, dynamic>> rows;
  final List<
      ({
        Map<String, dynamic> values,
        Map<String, Object> filters,
      })> updates;
  final bool shouldFailUpdate;

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
      updates: updates,
      shouldFailUpdate: shouldFailUpdate,
    );
  }
}

class _FakePostgrestFilterBuilder extends Fake
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  _FakePostgrestFilterBuilder({
    required this.rows,
    Map<String, Object>? filters,
    List<({String column, bool ascending})>? orders,
    this.rangeFrom,
    this.rangeTo,
  })  : _filters = filters ?? <String, Object>{},
        _orders = orders ?? <({String column, bool ascending})>[];

  final List<Map<String, dynamic>> rows;
  final Map<String, Object> _filters;
  final List<({String column, bool ascending})> _orders;
  final int? rangeFrom;
  final int? rangeTo;

  @override
  _FakePostgrestFilterBuilder eq(String column, Object value) {
    final nextFilters = Map<String, Object>.from(_filters)..[column] = value;
    return _FakePostgrestFilterBuilder(
      rows: rows,
      filters: nextFilters,
      orders: _orders,
      rangeFrom: rangeFrom,
      rangeTo: rangeTo,
    );
  }

  @override
  _FakePostgrestFilterBuilder order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    final nextOrders = List<({String column, bool ascending})>.from(_orders)
      ..add((column: column, ascending: ascending));
    return _FakePostgrestFilterBuilder(
      rows: rows,
      filters: _filters,
      orders: nextOrders,
      rangeFrom: rangeFrom,
      rangeTo: rangeTo,
    );
  }

  @override
  _FakePostgrestFilterBuilder range(
    int from,
    int to, {
    String? referencedTable,
  }) {
    return _FakePostgrestFilterBuilder(
      rows: rows,
      filters: _filters,
      orders: _orders,
      rangeFrom: from,
      rangeTo: to,
    );
  }

  static int _compareValues(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is bool && b is bool) {
      if (a == b) return 0;
      return a ? 1 : -1;
    }
    return a.toString().compareTo(b.toString());
  }

  List<Map<String, dynamic>> _filtered() {
    final filtered = rows
        .where(
          (row) => _filters.entries.every(
            (entry) => row[entry.key] == entry.value,
          ),
        )
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    if (_orders.isNotEmpty) {
      filtered.sort((a, b) {
        for (final spec in _orders) {
          final raw = _compareValues(a[spec.column], b[spec.column]);
          if (raw != 0) {
            return spec.ascending ? raw : -raw;
          }
        }
        return 0;
      });
    }

    final from = rangeFrom ?? 0;
    if (from >= filtered.length) return <Map<String, dynamic>>[];
    final requestedTo = (rangeTo ?? (filtered.length - 1)) + 1;
    final exclusiveTo =
        requestedTo < filtered.length ? requestedTo : filtered.length;
    return filtered.sublist(from, exclusiveTo);
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) {
    return Future<List<Map<String, dynamic>>>.value(_filtered())
        .then(onValue, onError: onError);
  }

  @override
  Future<List<Map<String, dynamic>>> catchError(
    Function onError, {
    bool Function(Object)? test,
  }) {
    return Future<List<Map<String, dynamic>>>.value(_filtered())
        .catchError(onError, test: test);
  }
}

class _FakePostgrestMutationBuilder extends Fake
    implements PostgrestFilterBuilder<dynamic> {
  _FakePostgrestMutationBuilder({
    required this.rows,
    required this.updateValues,
    required this.updates,
    required this.shouldFailUpdate,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> updateValues;
  final List<
      ({
        Map<String, dynamic> values,
        Map<String, Object> filters,
      })> updates;
  final bool shouldFailUpdate;
  final Map<String, Object> _filters = <String, Object>{};

  @override
  _FakePostgrestMutationBuilder eq(String column, Object value) {
    _filters[column] = value;
    return this;
  }

  void _applyUpdate() {
    updates.add(
      (
        values: Map<String, dynamic>.from(updateValues),
        filters: Map<String, Object>.from(_filters),
      ),
    );
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
    if (shouldFailUpdate) {
      return Future<dynamic>.error(
        Exception('Simulated pin update failure'),
      ).then(onValue, onError: onError);
    }
    _applyUpdate();
    return Future<dynamic>.value(null).then(onValue, onError: onError);
  }

  @override
  Future<dynamic> catchError(
    Function onError, {
    bool Function(Object)? test,
  }) {
    if (shouldFailUpdate) {
      return Future<dynamic>.error(
        Exception('Simulated pin update failure'),
      ).catchError(onError, test: test);
    }
    _applyUpdate();
    return Future<dynamic>.value(null).catchError(onError, test: test);
  }
}

class _FakeSemanticSearchService implements NoteSemanticSearchDataSource {
  @override
  Future<void> indexNote(String noteId) async {}

  @override
  Future<List<NoteSearchResult>> relatedNotes({
    required String noteId,
    required String title,
    required String content,
    int limit = 5,
  }) async {
    return const <NoteSearchResult>[];
  }

  @override
  Future<NoteSemanticSearchResponse> search(
    String query, {
    int limit = 20,
  }) async {
    return const NoteSemanticSearchResponse(
      searchMode: 'text_fallback',
      results: <NoteSearchResult>[],
    );
  }
}

Map<String, dynamic> _noteRow({
  required String id,
  required String title,
  required bool isPinned,
  String createdAt = '2026-11-01T09:00:00.000Z',
  bool isFavorite = false,
}) {
  return <String, dynamic>{
    'id': id,
    'user_id': 'test-user-id',
    'title': title,
    'content': '$title body',
    'created_at': createdAt,
    'updated_at': createdAt,
    'is_pinned': isPinned,
    'is_favorite': isFavorite,
    'is_archived': false,
    'reminder_date': null,
    'tags': <String>[],
    'capture_status': 'organized',
    'capture_source': 'editor',
    'inbox_saved_at': null,
    'notebook_collection_id': null,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'unpins and re-pins from the card menu at mobile width with undo support',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeSupabaseClient(
        noteRows: <Map<String, dynamic>>[
          _noteRow(
            id: 'pinned-old',
            title: '古いピン留めメモ',
            isPinned: true,
            createdAt: '2026-11-01T09:00:00.000Z',
          ),
          _noteRow(
            id: 'newer-normal',
            title: '新しい通常メモ',
            isPinned: false,
            createdAt: '2026-11-23T09:00:00.000Z',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NoteListPage(
            supabaseClient: client,
            semanticSearchService: _FakeSemanticSearchService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('古いピン留めメモ')).dy,
        lessThan(tester.getTopLeft(find.text('新しい通常メモ')).dy),
      );

      final menuFinder = find.byKey(
        const ValueKey<String>('note_list_menu_pinned-old'),
      );
      await tester.ensureVisible(menuFinder);
      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      final unpinMenuItem = find.byKey(
        const ValueKey<String>('note_list_menu_toggle_pin_pinned-old'),
      );
      expect(
        find.descendant(of: unpinMenuItem, matching: find.text('ピン留め解除')),
        findsOneWidget,
      );
      await tester.tap(unpinMenuItem);
      await tester.pumpAndSettle();

      expect(client.updates, hasLength(1));
      expect(client.updates.last.values['is_pinned'], isFalse);
      expect(client.updates.last.filters['id'], 'pinned-old');
      expect(client.updates.last.filters['user_id'], 'test-user-id');
      expect(find.text('ピン留めを解除しました'), findsOneWidget);
      expect(find.text('元に戻す'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('新しい通常メモ')).dy,
        lessThan(tester.getTopLeft(find.text('古いピン留めメモ')).dy),
      );

      await tester.tap(find.text('元に戻す'));
      await tester.pumpAndSettle();

      expect(client.updates, hasLength(2));
      expect(client.updates.last.values['is_pinned'], isTrue);
      expect(client.updates.last.filters['id'], 'pinned-old');
      expect(
        tester.getTopLeft(find.text('古いピン留めメモ')).dy,
        lessThan(tester.getTopLeft(find.text('新しい通常メモ')).dy),
      );

      final normalMenuFinder = find.byKey(
        const ValueKey<String>('note_list_menu_newer-normal'),
      );
      await tester.ensureVisible(normalMenuFinder);
      await tester.tap(normalMenuFinder);
      await tester.pumpAndSettle();

      final pinMenuItem = find.byKey(
        const ValueKey<String>('note_list_menu_toggle_pin_newer-normal'),
      );
      expect(
        find.descendant(of: pinMenuItem, matching: find.text('ピン留め')),
        findsOneWidget,
      );
      await tester.tap(pinMenuItem);
      await tester.pumpAndSettle();

      expect(client.updates, hasLength(3));
      expect(client.updates.last.values['is_pinned'], isTrue);
      expect(client.updates.last.filters['id'], 'newer-normal');
      expect(find.text('メモをピン留めしました'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unpins via leading pin icon with >=44px tap target at 320x568 2.0x scale',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeSupabaseClient(
        noteRows: <Map<String, dynamic>>[
          _noteRow(
            id: 'pinned-1',
            title: '狭幅テスト用ピン留めメモ',
            isPinned: true,
          ),
        ],
      );

      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            builder: (BuildContext context, Widget? child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: child!,
              );
            },
            home: NoteListPage(
              supabaseClient: client,
              semanticSearchService: _FakeSemanticSearchService(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final leadingFinder = find.byKey(
          const ValueKey<String>('note_list_unpin_leading_pinned-1'),
        );
        expect(leadingFinder, findsOneWidget);

        final size = tester.getSize(leadingFinder);
        expect(size.width, greaterThanOrEqualTo(44.0));
        expect(size.height, greaterThanOrEqualTo(44.0));

        final semantics = tester.getSemantics(leadingFinder);
        expect(
          '${semantics.label} ${semantics.tooltip}',
          contains('ピン留め解除'),
        );

        await tester.ensureVisible(leadingFinder);
        await tester.tap(leadingFinder);
        await tester.pumpAndSettle();

        expect(client.updates, hasLength(1));
        expect(client.updates.last.values['is_pinned'], isFalse);
        expect(client.updates.last.filters['id'], 'pinned-1');
        expect(client.updates.last.filters['user_id'], 'test-user-id');
        expect(leadingFinder, findsNothing);
        expect(find.text('ピン留めを解除しました'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'shows an error snackbar and preserves pin state when unpin fails',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeSupabaseClient(
        noteRows: <Map<String, dynamic>>[
          _noteRow(
            id: 'pinned-1',
            title: '失敗時の保持確認メモ',
            isPinned: true,
          ),
        ],
        shouldFailUpdate: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NoteListPage(
            supabaseClient: client,
            semanticSearchService: _FakeSemanticSearchService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final leadingFinder = find.byKey(
        const ValueKey<String>('note_list_unpin_leading_pinned-1'),
      );
      expect(leadingFinder, findsOneWidget);

      await tester.tap(leadingFinder);
      await tester.pumpAndSettle();

      expect(client.updates, isEmpty);
      expect(find.textContaining('ピン留めの更新に失敗しました'), findsOneWidget);
      expect(leadingFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
