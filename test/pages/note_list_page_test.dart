@TestOn('browser')

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
    this.collectionRows = const <Map<String, dynamic>>[],
  });

  @override
  final _FakeGoTrueClient auth = _FakeGoTrueClient();

  final List<Map<String, dynamic>> noteRows;
  final List<Map<String, dynamic>> collectionRows;
  final List<(int, int)> noteRanges = <(int, int)>[];

  @override
  SupabaseQueryBuilder from(String table) {
    if (table == 'notes') {
      return _FakeSupabaseQueryBuilder(rows: noteRows, ranges: noteRanges);
    }
    if (table == 'note_collections') {
      return _FakeSupabaseQueryBuilder(rows: collectionRows);
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
    this.ranges,
  });

  final List<Map<String, dynamic>> rows;
  final List<(int, int)>? ranges;

  @override
  _FakePostgrestFilterBuilder select([
    String? columns = '*',
  ]) {
    return _FakePostgrestFilterBuilder(rows: rows, ranges: ranges);
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
    this.ranges,
    Map<String, Object>? filters,
    this.rangeFrom,
    this.rangeTo,
  }) : _filters = filters ?? <String, Object>{};

  final List<Map<String, dynamic>> rows;
  final List<(int, int)>? ranges;
  final Map<String, Object> _filters;
  final int? rangeFrom;
  final int? rangeTo;

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

  @override
  _FakePostgrestFilterBuilder range(
    int from,
    int to, {
    String? referencedTable,
  }) {
    ranges?.add((from, to));
    return _FakePostgrestFilterBuilder(
      rows: rows,
      ranges: ranges,
      filters: _filters,
      rangeFrom: from,
      rangeTo: to,
    );
  }

  List<Map<String, dynamic>> _filtered() {
    final filtered = rows
        .where((row) {
          return _filters.entries
              .every((entry) => row[entry.key] == entry.value);
        })
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
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

class _FakeSemanticSearchService implements NoteSemanticSearchDataSource {
  _FakeSemanticSearchService(this.response);

  final NoteSemanticSearchResponse response;
  String? lastQuery;

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
    lastQuery = query;
    return response;
  }
}

Map<String, dynamic> _noteRow({
  required String id,
  required String title,
  required bool isFavorite,
  String captureStatus = 'organized',
  String userId = 'test-user-id',
  List<String> tags = const <String>[],
  int? notebookCollectionId,
}) {
  return <String, dynamic>{
    'id': id,
    'user_id': userId,
    'title': title,
    'content': '$title body',
    'created_at': '2026-03-18T09:00:00.000Z',
    'updated_at': '2026-03-18T10:00:00.000Z',
    'is_pinned': false,
    'is_favorite': isFavorite,
    'is_archived': false,
    'reminder_date': null,
    'tags': <String>[
      if (captureStatus == 'inbox') 'inbox',
      ...tags,
    ],
    'capture_status': captureStatus,
    'capture_source': captureStatus == 'inbox' ? 'quick_inbox' : 'editor',
    'inbox_saved_at':
        captureStatus == 'inbox' ? '2026-03-18T09:00:00.000Z' : null,
    'notebook_collection_id': notebookCollectionId,
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
    expect(find.text('すべてのメモを見る'), findsOneWidget);
  });

  testWidgets('lists Inbox notes first and filters out organized notes', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _FakeSupabaseClient(
      noteRows: <Map<String, dynamic>>[
        _noteRow(
          id: 'inbox-note',
          title: 'Captured thought',
          isFavorite: false,
          captureStatus: 'inbox',
        ),
        _noteRow(
          id: 'organized-note',
          title: 'Organized note',
          isFavorite: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: NoteListPage(supabaseClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inbox（未整理）'), findsOneWidget);
    expect(find.text('Captured thought'), findsOneWidget);
    expect(find.text('Organized note'), findsOneWidget);

    await tester.tap(find.byKey(const Key('note_list_page_inbox_filter')));
    await tester.pumpAndSettle();

    expect(find.text('Captured thought'), findsOneWidget);
    expect(find.text('Organized note'), findsNothing);
    final title = tester.widget<Text>(
      find.byKey(const Key('note_list_page_title')),
    );
    expect(title.data, contains('Inbox'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('moves an Inbox note to the organized list', (
    WidgetTester tester,
  ) async {
    final rows = <Map<String, dynamic>>[
      _noteRow(
        id: 'inbox-note',
        title: 'Sort this later',
        isFavorite: false,
        captureStatus: 'inbox',
      ),
    ];
    final client = _FakeSupabaseClient(noteRows: rows);

    await tester.pumpWidget(
      MaterialApp(home: NoteListPage(supabaseClient: client)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('整理済みにする'));
    await tester.pumpAndSettle();

    expect(rows.first['capture_status'], 'organized');
    expect(rows.first['tags'], isEmpty);
    expect(find.text('Inbox（未整理）'), findsNothing);
    expect(find.text('Sort this later'), findsOneWidget);
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

  testWidgets('uses semantic results for a natural-language query', (
    WidgetTester tester,
  ) async {
    final client = _FakeSupabaseClient(
      noteRows: <Map<String, dynamic>>[
        _noteRow(id: 'decision', title: 'Project decision', isFavorite: false),
        _noteRow(id: 'shopping', title: 'Shopping list', isFavorite: false),
      ],
    );
    final semanticSearch = _FakeSemanticSearchService(
      const NoteSemanticSearchResponse(
        searchMode: 'ai',
        results: <NoteSearchResult>[
          NoteSearchResult(
            id: 'decision',
            title: 'Project decision',
            content: 'Project decision body',
            score: 0.9,
            matchReason: 'vector',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListPage(
          supabaseClient: client,
          semanticSearchService: semanticSearch,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('note_list_page_search_field')),
      'what did we decide last week',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(semanticSearch.lastQuery, 'what did we decide last week');
    expect(find.text('Project decision'), findsOneWidget);
    expect(find.text('Shopping list'), findsNothing);
    expect(find.textContaining('意味検索'), findsOneWidget);
  });

  testWidgets('shows a semantic result that was not in the loaded note rows', (
    WidgetTester tester,
  ) async {
    final client = _FakeSupabaseClient(
      noteRows: <Map<String, dynamic>>[
        _noteRow(id: 'shopping', title: 'Shopping list', isFavorite: false),
      ],
    );
    final semanticSearch = _FakeSemanticSearchService(
      const NoteSemanticSearchResponse(
        searchMode: 'ai',
        results: <NoteSearchResult>[
          NoteSearchResult(
            id: 'older-decision',
            title: 'Older project decision',
            content: 'Use the second option.',
            createdAt: '2025-01-10T09:00:00.000Z',
            isPinned: false,
            isFavorite: false,
            score: 0.95,
            matchReason: 'vector',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListPage(
          supabaseClient: client,
          semanticSearchService: semanticSearch,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note_list_page_search_field')),
      'the old decision about our project',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Older project decision'), findsOneWidget);
    expect(find.text('Shopping list'), findsNothing);
  });

  testWidgets('loads notes with stable range pagination', (
    WidgetTester tester,
  ) async {
    final client = _FakeSupabaseClient(
      noteRows: List<Map<String, dynamic>>.generate(
        501,
        (index) => _noteRow(
          id: '$index',
          title: 'Memo $index',
          isFavorite: false,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: NoteListPage(supabaseClient: client)),
    );
    await tester.pumpAndSettle();

    expect(client.noteRanges, <(int, int)>[(0, 499), (500, 999)]);
  });

  testWidgets('カードのタグで一覧を絞り込み、解除できる', (tester) async {
    final client = _FakeSupabaseClient(
      noteRows: <Map<String, dynamic>>[
        _noteRow(
          id: 'work-note',
          title: 'Work note',
          isFavorite: false,
          tags: const <String>['Work'],
        ),
        _noteRow(
          id: 'private-note',
          title: 'Private note',
          isFavorite: false,
          tags: const <String>['Private'],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: NoteListPage(supabaseClient: client)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('note_list_tag_work-note_Work')),
    );
    await tester.pump();

    expect(find.text('Work note'), findsOneWidget);
    expect(find.text('Private note'), findsNothing);

    await tester.tap(find.byKey(const Key('note_list_tag_filter_clear')));
    await tester.pump();

    expect(find.text('Work note'), findsOneWidget);
    expect(find.text('Private note'), findsOneWidget);
  });

  testWidgets('タグ名もローカル検索の対象になる', (tester) async {
    final client = _FakeSupabaseClient(
      noteRows: <Map<String, dynamic>>[
        _noteRow(
          id: 'migration-note',
          title: 'Untitled record',
          isFavorite: false,
          tags: const <String>['Evernote移行'],
        ),
        _noteRow(
          id: 'other-note',
          title: 'Another record',
          isFavorite: false,
        ),
      ],
    );
    final semanticSearch = _FakeSemanticSearchService(
      const NoteSemanticSearchResponse(
        searchMode: 'text_fallback',
        results: <NoteSearchResult>[],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListPage(
          supabaseClient: client,
          semanticSearchService: semanticSearch,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note_list_page_search_field')),
      'Evernote移行',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Untitled record'), findsOneWidget);
    expect(find.text('Another record'), findsNothing);
  });

  testWidgets('applies saved-search query and tag when opened from navigation',
      (tester) async {
    final client = _FakeSupabaseClient(
      noteRows: <Map<String, dynamic>>[
        _noteRow(
          id: 'project-note',
          title: 'Project decision',
          isFavorite: false,
          tags: const <String>['Work'],
        ),
        _noteRow(
          id: 'private-note',
          title: 'Private journal',
          isFavorite: false,
          tags: const <String>['Private'],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListPage(
          supabaseClient: client,
          initialSearchQuery: 'Project',
          initialTag: 'Work',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchField = tester.widget<TextField>(
      find.byKey(const Key('note_list_page_search_field')),
    );
    expect(searchField.controller?.text, 'Project');
    expect(find.text('Project decision'), findsOneWidget);
    expect(find.text('Private journal'), findsNothing);
    expect(find.text('Work'), findsWidgets);
  });

  testWidgets(
      'executes supported Evernote search syntax without semantic search',
      (tester) async {
    final semanticSearch = _FakeSemanticSearchService(
      const NoteSemanticSearchResponse(
        searchMode: 'ai',
        results: <NoteSearchResult>[],
      ),
    );
    final client = _FakeSupabaseClient(
      collectionRows: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 10,
          'parent_id': null,
          'collection_type': 'stack',
          'name': 'Company',
        },
        <String, dynamic>{
          'id': 11,
          'parent_id': 10,
          'collection_type': 'notebook',
          'name': 'Finance Book',
        },
        <String, dynamic>{
          'id': 12,
          'parent_id': null,
          'collection_type': 'notebook',
          'name': 'Personal',
        },
      ],
      noteRows: <Map<String, dynamic>>[
        _noteRow(
          id: 'matching',
          title: 'Quarterly plan',
          isFavorite: false,
          tags: const <String>['Work'],
          notebookCollectionId: 11,
        ),
        _noteRow(
          id: 'outside',
          title: 'Quarterly personal',
          isFavorite: false,
          tags: const <String>['Work'],
          notebookCollectionId: 12,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListPage(
          supabaseClient: client,
          semanticSearchService: semanticSearch,
          initialSearchQuery:
              'intitle:Quarter* tag:Work notebook:"Finance Book" '
              'stack:Company updated:20260318',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(semanticSearch.lastQuery, isNull);
    expect(find.text('Quarterly plan'), findsOneWidget);
    expect(find.text('Quarterly personal'), findsNothing);
    expect(find.textContaining('Evernote高度検索'), findsOneWidget);
  });

  testWidgets('surfaces unsupported Evernote operators without false filtering',
      (tester) async {
    final semanticSearch = _FakeSemanticSearchService(
      const NoteSemanticSearchResponse(
        searchMode: 'ai',
        results: <NoteSearchResult>[],
      ),
    );
    final client = _FakeSupabaseClient(
      noteRows: <Map<String, dynamic>>[
        _noteRow(id: 'one', title: 'One note', isFavorite: false),
        _noteRow(id: 'two', title: 'Two note', isFavorite: false),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListPage(
          supabaseClient: client,
          semanticSearchService: semanticSearch,
          initialSearchQuery: 'resource:application/pdf',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(semanticSearch.lastQuery, isNull);
    expect(find.text('One note'), findsOneWidget);
    expect(find.text('Two note'), findsOneWidget);
    expect(find.textContaining('未対応のEvernote演算子'), findsOneWidget);
    expect(find.textContaining('resource'), findsOneWidget);
  });

  testWidgets('opens a notebook or stack shortcut with descendant filtering',
      (tester) async {
    final client = _FakeSupabaseClient(
      collectionRows: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 10,
          'parent_id': null,
          'collection_type': 'stack',
        },
        <String, dynamic>{
          'id': 11,
          'parent_id': 10,
          'collection_type': 'notebook',
        },
      ],
      noteRows: <Map<String, dynamic>>[
        _noteRow(
          id: 'inside',
          title: 'Inside stack',
          isFavorite: false,
          notebookCollectionId: 11,
        ),
        _noteRow(
          id: 'outside',
          title: 'Outside stack',
          isFavorite: false,
          notebookCollectionId: 12,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteListPage(
          supabaseClient: client,
          initialCollectionId: 10,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inside stack'), findsOneWidget);
    expect(find.text('Outside stack'), findsNothing);
  });
}
