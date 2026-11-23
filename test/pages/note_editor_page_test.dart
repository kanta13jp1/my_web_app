import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/note_editor_page.dart';
import 'package:my_web_app/pages/ai_search_page.dart';
import 'package:my_web_app/services/note_semantic_search_service.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 記録用の Fake Supabase。`notes` への update / insert を全件記録し、
/// 「本当に PATCH が飛んだか」をテストから検証できるようにする。
class _RecordingSupabaseClient extends Fake implements SupabaseClient {
  _RecordingSupabaseClient({
    required this.noteRow,
    this.failSelect = false,
    this.updateGate,
    this.noteInsertGate,
    this.historyRows = const [],
    this.failVersionInsert = false,
    this.versionInsertGate,
  });

  @override
  final _FakeGoTrueClient auth = _FakeGoTrueClient();

  final Map<String, dynamic> noteRow;
  final List<Map<String, dynamic>> historyRows;
  final bool failVersionInsert;
  final Completer<void>? versionInsertGate;
  final versionInserts = <Map<String, dynamic>>[];
  int versionCompletions = 0;

  /// true にすると `_loadNote` の select が失敗する (= サーバー基準値が無い状態)。
  final bool failSelect;
  final Completer<void>? updateGate;
  final Completer<void>? noteInsertGate;
  final List<Map<String, dynamic>> updates = <Map<String, dynamic>>[];
  final completedUpdates = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> inserts = <Map<String, dynamic>>[];

  @override
  SupabaseQueryBuilder from(String table) {
    return _FakeSupabaseQueryBuilder(client: this, table: table);
  }
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

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
  _FakeSupabaseQueryBuilder({required this.client, required this.table});

  final _RecordingSupabaseClient client;
  final String table;

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) {
    return _FakeSelectBuilder(
      rows: table == 'note_versions'
          ? client.historyRows
          : <Map<String, dynamic>>[client.noteRow],
      shouldFail: client.failSelect && table == 'notes',
    );
  }

  /// コメント購読 (note_comments) は本テストの対象外なので空ストリームを返す。
  @override
  SupabaseStreamFilterBuilder stream({
    required List<String> primaryKey,
    bool private = false,
  }) {
    return _FakeStreamBuilder();
  }

  @override
  PostgrestFilterBuilder<dynamic> update(Map values) {
    if (table == 'notes') {
      client.updates.add(Map<String, dynamic>.from(values));
    }
    return _FakeMutationBuilder(
      idValue: client.noteRow['id'],
      waitFor: client.updateGate?.future,
      onComplete: table == 'notes'
          ? () => client.completedUpdates.add(Map<String, dynamic>.from(values))
          : null,
    );
  }

  @override
  PostgrestFilterBuilder<dynamic> insert(
    Object values, {
    bool defaultToNull = true,
  }) {
    if (table == 'note_versions' && values is Map) {
      if (client.failVersionInsert) {
        throw StateError('Synthetic backup failure');
      }
      client.versionInserts.add(Map<String, dynamic>.from(values));
      return _FakeMutationBuilder(
        idValue: client.noteRow['id'],
        waitFor: client.versionInsertGate?.future,
        onComplete: () => client.versionCompletions++,
      );
    }
    if (table == 'notes' && values is Map) {
      client.inserts.add(Map<String, dynamic>.from(values));
    }
    return _FakeMutationBuilder(
      idValue: client.noteRow['id'],
      waitFor: client.noteInsertGate?.future,
    );
  }
}

class _FakeStreamBuilder extends Fake implements SupabaseStreamFilterBuilder {
  @override
  SupabaseStreamBuilder eq(String column, Object value) => this;

  @override
  Stream<S> map<S>(S Function(List<Map<String, dynamic>> event) convert) {
    return const Stream<Never>.empty().cast<S>();
  }
}

/// `.select(...)` の戻り値。`.eq().single()` / `.eq().order()` を受ける。
class _FakeSelectBuilder extends Fake
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  _FakeSelectBuilder({required this.rows, this.shouldFail = false});

  final List<Map<String, dynamic>> rows;
  final bool shouldFail;

  @override
  _FakeSelectBuilder eq(String column, Object value) => this;

  @override
  _FakeSelectBuilder limit(int count, {String? referencedTable}) => this;

  @override
  _FakeSelectBuilder order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      this;

  @override
  PostgrestTransformBuilder<Map<String, dynamic>> single() {
    return _FakeSingleBuilder(
      row: rows.isEmpty ? null : rows.first,
      shouldFail: shouldFail,
    );
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    return _FakeMaybeSingleBuilder(row: rows.isEmpty ? null : rows.first);
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) {
    return Future<List<Map<String, dynamic>>>.value(rows)
        .then(onValue, onError: onError);
  }

  @override
  Future<List<Map<String, dynamic>>> catchError(
    Function onError, {
    bool Function(Object)? test,
  }) {
    return Future<List<Map<String, dynamic>>>.value(rows)
        .catchError(onError, test: test);
  }
}

/// `.update(...)` / `.insert(...)` の戻り値。
class _FakeMutationBuilder extends Fake
    implements PostgrestFilterBuilder<dynamic> {
  _FakeMutationBuilder({required this.idValue, this.waitFor, this.onComplete});

  final Object? idValue;
  final Future<void>? waitFor;
  final void Function()? onComplete;

  @override
  _FakeMutationBuilder eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) {
    return _FakeInsertSelectBuilder(idValue: idValue, waitFor: waitFor);
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    return _FakeMaybeSingleBuilder(
      row: <String, dynamic>{'id': idValue},
      waitFor: waitFor,
    );
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    return (waitFor ?? Future<void>.value()).then<dynamic>((_) {
      onComplete?.call();
      return null;
    }).then(onValue, onError: onError);
  }

  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object)? test}) {
    return Future<dynamic>.value(null).catchError(onError, test: test);
  }
}

/// `.insert(...).select('id')` の戻り値。`.maybeSingle()` で新規 id を返す。
class _FakeInsertSelectBuilder extends Fake
    implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {
  _FakeInsertSelectBuilder({required this.idValue, this.waitFor});

  final Object? idValue;
  final Future<void>? waitFor;

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    return _FakeMaybeSingleBuilder(
      row: <String, dynamic>{'id': idValue},
      waitFor: waitFor,
    );
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) {
    return Future<List<Map<String, dynamic>>>.value(
      <Map<String, dynamic>>[
        <String, dynamic>{'id': idValue},
      ],
    ).then(onValue, onError: onError);
  }
}

class _FakeSingleBuilder extends Fake
    implements PostgrestTransformBuilder<Map<String, dynamic>> {
  _FakeSingleBuilder({required this.row, this.shouldFail = false});

  final Map<String, dynamic>? row;
  final bool shouldFail;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(Map<String, dynamic> value) onValue, {
    Function? onError,
  }) {
    if (shouldFail) {
      return Future<Map<String, dynamic>>.error(
        Exception('network down'),
      ).then(onValue, onError: onError);
    }
    return Future<Map<String, dynamic>>.value(
      row ?? <String, dynamic>{},
    ).then(onValue, onError: onError);
  }

  @override
  Future<Map<String, dynamic>> catchError(
    Function onError, {
    bool Function(Object)? test,
  }) {
    return Future<Map<String, dynamic>>.value(
      row ?? <String, dynamic>{},
    ).catchError(onError, test: test);
  }
}

class _FakeMaybeSingleBuilder extends Fake
    implements PostgrestTransformBuilder<Map<String, dynamic>?> {
  _FakeMaybeSingleBuilder({required this.row, this.waitFor});

  final Map<String, dynamic>? row;
  final Future<void>? waitFor;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(Map<String, dynamic>? value) onValue, {
    Function? onError,
  }) {
    return (waitFor ?? Future<void>.value())
        .then((_) => row)
        .then(onValue, onError: onError);
  }

  @override
  Future<Map<String, dynamic>?> catchError(
    Function onError, {
    bool Function(Object)? test,
  }) {
    return (waitFor ?? Future<void>.value())
        .then((_) => row)
        .catchError(onError, test: test);
  }
}

class _RecordingSemanticSearchService implements NoteSemanticSearchDataSource {
  int indexCalls = 0;
  int relatedCalls = 0;

  @override
  Future<void> indexNote(String noteId) async {
    indexCalls += 1;
  }

  @override
  Future<List<NoteSearchResult>> relatedNotes({
    required String noteId,
    required String title,
    required String content,
    int limit = 5,
  }) async {
    relatedCalls += 1;
    return const <NoteSearchResult>[];
  }

  @override
  Future<NoteSemanticSearchResponse> search(
    String query, {
    int limit = 20,
  }) async {
    return const NoteSemanticSearchResponse(
      results: <NoteSearchResult>[],
      searchMode: 'text_fallback',
    );
  }
}

Map<String, dynamic> _noteRow({
  String title = '読書について',
  String content = '思索\n\n1\n\n数量がいかに豊かでも',
  bool isPinned = false,
}) {
  return <String, dynamic>{
    'id': '429',
    'user_id': 'test-user-id',
    'title': title,
    'content': content,
    'reminder_date': null,
    'is_favorite': false,
    'is_pinned': isPinned,
    'tags': <String>['Evernote'],
    'created_at': '2026-07-19T09:00:00.000Z',
    'updated_at': '2026-07-19T09:00:00.000Z',
  };
}

Future<void> _pumpPage(
  WidgetTester tester,
  _RecordingSupabaseClient client, {
  NoteSemanticSearchDataSource? semanticSearchService,
  String? noteId = '429',
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeService>(
      create: (_) => ThemeService(),
      child: MaterialApp(
        home: NoteEditorPage(
          noteId: noteId,
          supabaseClient: client,
          semanticSearchService: semanticSearchService,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<_RecordingSupabaseClient> _pumpEditor(WidgetTester tester) async {
  final client = _RecordingSupabaseClient(noteRow: _noteRow());
  await _pumpPage(tester, client);
  client.updates.clear();
  client.inserts.clear();
  return client;
}

TextEditingController _contentController(WidgetTester tester) {
  return tester
      .widget<TextField>(find.byKey(const Key('note_editor_content_field')))
      .controller!;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'search opens the saved note in the real editor without overwriting it',
      (tester) async {
    final client = _RecordingSupabaseClient(noteRow: _noteRow());
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeService>(
        create: (_) => ThemeService(),
        child: MaterialApp(
          home: AiSearchPage(
            supabaseClient: client,
            search: (_) async => {
              'results': [
                {'id': 429, 'title': '検索の抜粋', 'content': '短縮された内容'},
              ],
              'searchMode': 'text',
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '読書');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('検索の抜粋'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NoteEditorPage>(find.byType(NoteEditorPage)).noteId,
      '429',
    );
    expect(_contentController(tester).text, _noteRow()['content']);
    expect(client.inserts, isEmpty);
    expect(client.updates, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('「読書」の結果（1件）'), findsOneWidget);
    expect(find.text('検索の抜粋'), findsOneWidget);
  });

  group('note editor autosave', () {
    testWidgets(
        'editing during initial insert creates one note then saves latest',
        (tester) async {
      final gate = Completer<void>();
      final client = _RecordingSupabaseClient(
        noteRow: _noteRow(),
        noteInsertGate: gate,
      );
      await _pumpPage(tester, client, noteId: null);
      await tester.enterText(
        find.byKey(const Key('note_editor_content_field')),
        'First draft for a new note',
      );
      await tester.pump(const Duration(seconds: 3));
      expect(client.inserts, hasLength(1));
      await tester.enterText(
        find.byKey(const Key('note_editor_content_field')),
        'Latest draft during initial insert',
      );
      await tester.pump(const Duration(seconds: 3));
      expect(client.inserts, hasLength(1));
      expect(client.updates, isEmpty);
      gate.complete();
      await tester.pumpAndSettle();
      expect(client.inserts, hasLength(1));
      expect(
        client.completedUpdates.single['content'],
        'Latest draft during initial insert',
      );
      expect(
        _contentController(tester).text,
        'Latest draft during initial insert',
      );
    });
    testWidgets('キャレット移動 (選択範囲のみの変更) では PATCH を送らない', (tester) async {
      final client = await _pumpEditor(tester);

      final controller = _contentController(tester);
      final originalText = controller.text;

      // 本文は一切変えず、カーソル位置だけを動かす
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();
      controller.selection = const TextSelection.collapsed(offset: 7);
      await tester.pump();

      // デバウンス (2秒) を十分に超えて待つ
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(controller.text, originalText);
      expect(
        client.updates,
        isEmpty,
        reason: 'キャレット移動だけで notes への update が発生している',
      );
    });

    testWidgets('本文を実際に編集したときは PATCH を1回だけ送る', (tester) async {
      final client = await _pumpEditor(tester);

      await tester.enterText(
        find.byKey(const Key('note_editor_content_field')),
        '編集後の本文',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(client.updates, hasLength(1));
      expect(client.updates.single['content'], '編集後の本文');
    });

    testWidgets('読み込んだタグを追加して自動保存できる', (tester) async {
      final client = await _pumpEditor(tester);

      await tester.tap(find.byKey(const Key('note_editor_tags_button')));
      await tester.pumpAndSettle();
      expect(find.text('Evernote'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('note_tags_input')),
        '移行済み',
      );
      await tester.tap(find.byKey(const Key('note_tags_add_button')));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(client.updates, hasLength(1));
      expect(client.updates.single['tags'], <String>['Evernote', '移行済み']);
    });

    testWidgets('autosave does not embed while manual save indexes once', (
      tester,
    ) async {
      final client = _RecordingSupabaseClient(noteRow: _noteRow());
      final semanticSearch = _RecordingSemanticSearchService();
      await _pumpPage(
        tester,
        client,
        semanticSearchService: semanticSearch,
      );
      client.updates.clear();

      await tester.enterText(
        find.byKey(const Key('note_editor_content_field')),
        'updated content for semantic indexing',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(client.updates, hasLength(1));
      expect(semanticSearch.indexCalls, 0);

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(semanticSearch.indexCalls, 1);
    });

    testWidgets('保存後にキャレットを動かしても PATCH は重複しない', (tester) async {
      final client = await _pumpEditor(tester);

      await tester.enterText(
        find.byKey(const Key('note_editor_content_field')),
        '一度だけ保存されるべき本文',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(client.updates, hasLength(1));

      _contentController(tester).selection =
          const TextSelection.collapsed(offset: 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(client.updates, hasLength(1));
    });

    testWidgets('updated_at は UTC (オフセット付き) で送信される', (tester) async {
      final client = await _pumpEditor(tester);

      await tester.enterText(
        find.byKey(const Key('note_editor_content_field')),
        'タイムゾーン検証用の本文',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(client.updates, hasLength(1));
      final updatedAt = client.updates.single['updated_at'] as String;
      expect(
        updatedAt.endsWith('Z'),
        isTrue,
        reason: 'updated_at がローカル時刻 (オフセットなし) で送信されている: $updatedAt',
      );
      expect(DateTime.parse(updatedAt).isUtc, isTrue);
    });

    testWidgets('保存の待機中に追加入力すると最終内容が続けて保存される', (tester) async {
      final updateGate = Completer<void>();
      final client = _RecordingSupabaseClient(
        noteRow: _noteRow(),
        updateGate: updateGate,
      );
      await _pumpPage(tester, client);
      client.updates.clear();

      await tester.enterText(
        find.byKey(const Key('note_editor_content_field')),
        '最初の保存内容',
      );
      await tester.pump(const Duration(seconds: 3));
      expect(client.updates, hasLength(1));

      await tester.enterText(
        find.byKey(const Key('note_editor_content_field')),
        '保存中に追加した最終内容',
      );
      await tester.pump();

      updateGate.complete();
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('note_editor_draft_429'),
        isNotNull,
        reason: '保存中に追加された内容の下書きを先行リクエストが削除している',
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(client.updates, hasLength(2));
      expect(client.updates.last['content'], '保存中に追加した最終内容');
      expect(prefs.getString('note_editor_draft_429'), isNull);
    });

    for (final returnToBaseline in [false, true]) {
      testWidgets('closing sends final draft last; baseline=$returnToBaseline',
          (tester) async {
        final gate = Completer<void>();
        final client = _RecordingSupabaseClient(
          noteRow: _noteRow(),
          updateGate: gate,
        );
        await _pumpPage(tester, client);
        final finalContent = returnToBaseline
            ? client.noteRow['content'] as String
            : 'Final draft captured on exit';
        await tester.enterText(
          find.byKey(const Key('note_editor_content_field')),
          'Earlier request still in flight',
        );
        await tester.pump(const Duration(seconds: 3));
        expect(client.updates, hasLength(1));
        await tester.enterText(
          find.byKey(const Key('note_editor_content_field')),
          finalContent,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(client.updates, hasLength(1));
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pump();
        expect(client.updates, hasLength(1));
        gate.complete();
        await tester.pumpAndSettle();
        expect(client.updates, hasLength(2));
        expect(
          client.completedUpdates.map((row) => row['content']).toList(),
          ['Earlier request still in flight', finalContent],
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('note_editor_draft_429'), isNotNull);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('デバウンス中にエディタを閉じても編集がサーバーに送られる', (tester) async {
      final client = await _pumpEditor(tester);

      await tester.enterText(
        find.byKey(const Key('note_editor_content_field')),
        'デバウンス待ちのまま閉じる本文',
      );
      // 2秒のデバウンスが切れる前に破棄する
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(
        client.updates,
        hasLength(1),
        reason: '閉じるのが早いと編集がサーバーに届かない',
      );
      expect(client.updates.single['content'], 'デバウンス待ちのまま閉じる本文');
    });
  });

  group('note editor local draft', () {
    testWidgets('サーバーの方が新しいとき下書きを黙って復元しない', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'note_editor_draft_429': jsonEncode(<String, dynamic>{
          'title': '古いローカル下書き',
          'content': '古いローカル本文',
          'reminder_date': null,
          'is_favorite': false,
          'saved_at': '2026-07-19T00:00:00.000Z',
        }),
      });

      final client = _RecordingSupabaseClient(
        noteRow: _noteRow()..['updated_at'] = '2026-07-19T12:00:00.000Z',
      );
      await _pumpPage(tester, client);

      expect(find.text('未送信の下書きがあります'), findsOneWidget);
      expect(_contentController(tester).text, isNot('古いローカル本文'));
    });

    testWidgets('競合ダイアログを選択せず閉じても下書きを保持する', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'note_editor_draft_429': jsonEncode(<String, dynamic>{
          'title': '古いローカル下書き',
          'content': '消してはいけないローカル本文',
          'reminder_date': null,
          'is_favorite': false,
          'saved_at': '2026-07-19T00:00:00.000Z',
        }),
      });

      final client = _RecordingSupabaseClient(
        noteRow: _noteRow()..['updated_at'] = '2026-07-19T12:00:00.000Z',
      );
      await _pumpPage(tester, client);

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);

      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('note_editor_draft_429'),
        isNotNull,
        reason: '明示的な選択なしに競合ダイアログを閉じると下書きが削除される',
      );
    });

    testWidgets('復元した下書きは入力を待たずサーバーへ送られる', (tester) async {
      // 下書きはサーバー更新より後 = 端末側が最新なので黙って復元される
      SharedPreferences.setMockInitialValues(<String, Object>{
        'note_editor_draft_429': jsonEncode(<String, dynamic>{
          'title': '読書について',
          'content': '未送信のローカル本文',
          'reminder_date': null,
          'is_favorite': false,
          'saved_at': '2026-07-19T23:00:00.000Z',
        }),
      });

      final client = _RecordingSupabaseClient(
        noteRow: _noteRow()..['updated_at'] = '2026-07-19T09:00:00.000Z',
      );
      await _pumpPage(tester, client);

      expect(find.text('未送信の下書きがあります'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(
        client.updates,
        hasLength(1),
        reason: '復元した下書きが「保存済み」表示のままサーバーに届いていない',
      );
      expect(client.updates.single['content'], '未送信のローカル本文');
    });

    testWidgets('メモの読み込みに失敗したときは空の本文で上書きしない', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'note_editor_draft_429': jsonEncode(<String, dynamic>{
          'title': '下書きタイトル',
          'content': '下書き本文',
          'reminder_date': null,
          'is_favorite': false,
          'saved_at': '2026-07-19T23:00:00.000Z',
        }),
      });

      final client = _RecordingSupabaseClient(
        noteRow: _noteRow(),
        failSelect: true,
      );
      await _pumpPage(tester, client);
      await tester.enterText(
        find.byKey(const Key('note_editor_content_field')),
        '読み込み失敗後の入力',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(
        client.updates,
        isEmpty,
        reason: 'サーバー基準値が無いまま自動保存すると既存メモを潰す',
      );
    });
  });

  group('note history restore backup', () {
    for (final changeWhileWaiting in [false, true]) {
      testWidgets(
          'restore waits for prior save; newer edit=$changeWhileWaiting',
          (tester) async {
        final gate = Completer<void>();
        final client = _RecordingSupabaseClient(
          noteRow: _noteRow(),
          updateGate: gate,
          historyRows: [
            {
              'id': '22222222-2222-4222-8222-222222222222',
              'title': 'Historical title',
              'content': 'Historical body',
              'saved_at': '2026-01-01T00:00:00Z',
              'source_system': 'native',
              'source_verified_at': null,
            }
          ],
        );
        await _pumpPage(tester, client);
        await tester.enterText(
          find.byKey(const Key('note_editor_content_field')),
          'Draft being saved before restore',
        );
        await tester.pump(const Duration(seconds: 3));
        expect(client.updates, hasLength(1));
        await tester.tap(find.byTooltip('バージョン履歴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Historical title'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('このタイトル・本文を復元'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('復元'));
        await tester.pumpAndSettle();
        expect(client.versionInserts, isEmpty);
        expect(
          _contentController(tester).text,
          'Draft being saved before restore',
        );
        if (changeWhileWaiting) {
          _contentController(tester).text =
              'Newer draft while waiting for save';
        }
        gate.complete();
        await tester.pumpAndSettle();
        if (changeWhileWaiting) {
          expect(client.versionInserts, isEmpty);
          expect(
            _contentController(tester).text,
            'Newer draft while waiting for save',
          );
          expect(find.text('復元を中止しました'), findsOneWidget);
          await tester.tap(find.text('閉じる'));
          await tester.pumpAndSettle();
        } else {
          expect(
            client.versionInserts.single['content'],
            'Draft being saved before restore',
          );
          expect(_contentController(tester).text, 'Historical body');
        }
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(
          client.completedUpdates.last['content'],
          changeWhileWaiting
              ? 'Newer draft while waiting for save'
              : 'Historical body',
        );
      });
    }
    testWidgets('editing during the backup never overwrites the newer draft',
        (tester) async {
      final gate = Completer<void>();
      final client = _RecordingSupabaseClient(
        noteRow: _noteRow(),
        versionInsertGate: gate,
        historyRows: [
          {
            'id': '22222222-2222-4222-8222-222222222222',
            'title': 'Historical title',
            'content': 'Historical body',
            'saved_at': '2026-01-01T00:00:00Z',
            'source_system': 'native',
            'source_verified_at': null,
          }
        ],
      );
      await _pumpPage(tester, client);
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(NoteEditorPage)),
      );
      messenger.clearSnackBars();
      await tester.pumpAndSettle();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('別の操作についての既存通知'),
          duration: Duration(minutes: 1),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('バージョン履歴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Historical title'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('このタイトル・本文を復元'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('復元'));
      await tester.pumpAndSettle();
      expect(client.versionInserts, hasLength(1));
      expect(gate.isCompleted, isFalse);
      _contentController(tester).text = 'New edit while backup is pending';
      gate.complete();
      // The request/Future chain can complete without scheduling a frame.
      // Observe the operation's own result before waiting for global idleness.
      final abortMessage = find.text('保全中に編集内容またはログイン状態が変わったため、復元を中止しました。');
      for (var frame = 0;
          frame < 10 && abortMessage.evaluate().isEmpty;
          frame++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(
        _contentController(tester).text,
        'New edit while backup is pending',
      );
      expect(client.versionCompletions, 1);
      expect(abortMessage, findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        client.updates.every((row) => row['content'] != 'Historical body'),
        isTrue,
      );
    });

    for (final failBackup in [false, true]) {
      testWidgets(
          'history backup failure=$failBackup preserves current content',
          (tester) async {
        final client = _RecordingSupabaseClient(
          noteRow: _noteRow(),
          failVersionInsert: failBackup,
          historyRows: [
            {
              'id': '22222222-2222-4222-8222-222222222222',
              'title': 'Historical title',
              'content': 'Historical body',
              'saved_at': '2026-01-01T00:00:00Z',
              'source_system': 'native',
              'source_verified_at': null,
            }
          ],
        );
        await _pumpPage(tester, client);
        final before = _contentController(tester).text;
        await tester.tap(find.byTooltip('バージョン履歴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Historical title'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('このタイトル・本文を復元'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('復元'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        if (failBackup) {
          expect(_contentController(tester).text, before);
          expect(client.updates, isEmpty);
          expect(find.text('現在の内容を履歴に保全できなかったため、復元を中止しました。'), findsOneWidget);
        } else {
          expect(client.versionInserts.single['content'], before);
          expect(_contentController(tester).text, 'Historical body');
          expect(client.updates.last['content'], 'Historical body');
          expect(client.updates.last['tags'], ['Evernote']);
        }
      });
    }
  });

  group('note editor slash command bar', () {
    testWidgets('折りたたみ状態が次回の起動でも保持される', (tester) async {
      await _pumpEditor(tester);

      // 既定 (デスクトップ幅) は展開。折りたたむ。
      expect(
        find.byKey(const Key('note_editor_slash_command_field')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('note_editor_slash_command_toggle')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('note_editor_slash_command_field')),
        findsNothing,
      );

      // 開き直しても折りたたんだままであること
      await _pumpEditor(tester);
      expect(
        find.byKey(const Key('note_editor_slash_command_field')),
        findsNothing,
        reason: 'メモを開き直すたびにスラッシュ欄が再展開している',
      );
    });
  });

  group('note editor mobile clipboard bar', () {
    String? mockClipboard;

    void installClipboardMock() {
      mockClipboard = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>?;
          mockClipboard = args?['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          if (mockClipboard == null) return null;
          return <String, dynamic>{'text': mockClipboard};
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
    }

    Future<void> clearSnackBars(WidgetTester tester) async {
      final scaffold = tester.element(
        find.byKey(const Key('note_editor_page_scaffold')),
      );
      ScaffoldMessenger.of(scaffold).clearSnackBars();
      await tester.pumpAndSettle();
    }

    testWidgets('行選択→コピーと選択切り取り・全文コピーが動作する', (tester) async {
      installClipboardMock();
      const body = 'line1\nhttps://mightylink-app.com/\nline3';
      final client = _RecordingSupabaseClient(
        noteRow: _noteRow(content: body),
      );
      await _pumpPage(tester, client);
      await clearSnackBars(tester);

      final controller = _contentController(tester);
      final comIndex = body.indexOf('com/');
      controller.selection = TextSelection(
        baseOffset: comIndex,
        extentOffset: comIndex + 4,
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('note_editor_select_line_button')));
      await tester.pump();
      expect(
        controller.selection.textInside(controller.text),
        'https://mightylink-app.com/',
      );

      await tester.tap(find.byKey(const Key('note_editor_copy_button')));
      await tester.pumpAndSettle();
      expect(mockClipboard, 'https://mightylink-app.com/');

      await tester.tap(find.byKey(const Key('note_editor_cut_button')));
      await tester.pumpAndSettle();
      expect(mockClipboard, 'https://mightylink-app.com/');
      expect(controller.text, 'line1\n\nline3');

      await tester.tap(find.byKey(const Key('note_editor_copy_all_button')));
      await tester.pumpAndSettle();
      expect(mockClipboard, 'line1\n\nline3');
    });

    testWidgets('貼り付けボタンおよび空クリップボード時の手動貼り付けが動作する', (tester) async {
      installClipboardMock();
      final client = _RecordingSupabaseClient(
        noteRow: _noteRow(content: '先頭 '),
      );
      await _pumpPage(tester, client);
      await clearSnackBars(tester);

      final controller = _contentController(tester);
      controller.selection = const TextSelection.collapsed(offset: 3);
      mockClipboard = '貼り付けテスト';
      await tester.tap(find.byKey(const Key('note_editor_paste_button')));
      await tester.pumpAndSettle();
      expect(controller.text, '先頭 貼り付けテスト');

      // クリップボードが空/取得不可の場合は手動貼り付けダイアログへフォールバック
      mockClipboard = null;
      await tester.tap(find.byKey(const Key('note_editor_paste_button')));
      await tester.pumpAndSettle();
      expect(find.text('手動貼り付け'), findsOneWidget);

      await tester.tap(find.text('手動貼り付け'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('note_editor_manual_paste_dialog')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('note_editor_manual_paste_field')),
        '・追記テキスト',
      );
      await tester.tap(
        find.byKey(const Key('note_editor_manual_paste_confirm')),
      );
      await tester.pumpAndSettle();
      expect(controller.text, '先頭 貼り付けテスト・追記テキスト');
    });

    testWidgets('狭幅かつキーボード表示中でもオーバーフローせず操作バーが見える', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpEditor(tester);
      expect(
        find.byKey(const Key('note_editor_clipboard_bar')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('スラッシュ欄展開+キーボード表示でも本文が表示されオーバーフローしない', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'note_editor_slash_bar_expanded': true,
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpEditor(tester);
      expect(
        find.byKey(const Key('note_editor_content_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('note_editor_clipboard_bar')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('値を選択ボタンでハイフン付きパスワード全体を選択・コピーできる', (tester) async {
      installClipboardMock();
      const body = 'ユーザー名: ml_user\nパスワード: t-C22P7VKxxh-6ihKPuWJ';
      final client = _RecordingSupabaseClient(
        noteRow: _noteRow(content: body),
      );
      await _pumpPage(tester, client);
      await clearSnackBars(tester);

      final controller = _contentController(tester);
      final partIdx = body.indexOf('6ihKPuWJ');
      controller.selection = TextSelection(
        baseOffset: partIdx,
        extentOffset: partIdx + 8,
      );
      await tester.pump();

      final selectValueBtn = find.byKey(
        const Key('note_editor_select_value_button'),
      );
      await tester.tap(selectValueBtn);
      await tester.pump();
      expect(
        controller.selection.textInside(controller.text),
        't-C22P7VKxxh-6ihKPuWJ',
      );

      await tester.tap(find.byKey(const Key('note_editor_copy_button')));
      await tester.pumpAndSettle();
      expect(mockClipboard, 't-C22P7VKxxh-6ihKPuWJ');
    });

    testWidgets('範囲選択ボタンから範囲選択画面を開き調整範囲を反映できる', (tester) async {
      installClipboardMock();
      const body = 'パスワード: abcdef-xyz';
      final client = _RecordingSupabaseClient(
        noteRow: _noteRow(content: body),
      );
      await _pumpPage(tester, client);
      await clearSnackBars(tester);

      final controller = _contentController(tester);
      controller.selection = const TextSelection(
        baseOffset: 7,
        extentOffset: 17,
      );
      await tester.pump();

      final rangeBtn = find.byKey(
        const Key('note_editor_range_select_button'),
      );
      await tester.tap(rangeBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note_range_select_page')), findsOneWidget);

      await tester.tap(find.byKey(const Key('note_range_mode_precision')));
      await tester.pumpAndSettle();

      final startPlus = find.byKey(const Key('note_range_start_plus_1'));
      await tester.ensureVisible(startPlus);
      await tester.tap(startPlus);
      await tester.pump();

      final applyBtn = find.byKey(
        const Key('note_range_precision_apply_button'),
      );
      await tester.ensureVisible(applyBtn);
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      expect(controller.selection.textInside(controller.text), 'bcdef-xyz');
    });
  });

  group('note editor pin toggle', () {
    testWidgets('スマホ幅でピン留め済みメモをピンボタンから解除・再保存できる', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _RecordingSupabaseClient(
        noteRow: _noteRow(isPinned: true),
      );
      await _pumpPage(tester, client);
      client.updates.clear();

      final pinButton = find.byKey(const Key('note_editor_pin_button'));
      expect(pinButton, findsOneWidget);
      expect(
        find.descendant(of: pinButton, matching: find.text('ピン留め解除')),
        findsOneWidget,
      );
      final size = tester.getSize(pinButton);
      expect(size.width, greaterThanOrEqualTo(44.0));
      expect(size.height, greaterThanOrEqualTo(44.0));

      await tester.ensureVisible(pinButton);
      await tester.tap(pinButton);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(client.updates, hasLength(1));
      expect(client.updates.single['is_pinned'], isFalse);
      expect(
        find.descendant(of: pinButton, matching: find.text('ピン留め')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('/pin スラッシュコマンドでピン留めを切り替えて保存できる', (tester) async {
      final client = _RecordingSupabaseClient(
        noteRow: _noteRow(isPinned: false),
      );
      await _pumpPage(tester, client);
      client.updates.clear();

      await tester.enterText(
        find.byKey(const Key('note_editor_slash_command_field')),
        '/pin',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(client.updates, hasLength(1));
      expect(client.updates.single['is_pinned'], isTrue);
      expect(
        find.descendant(
          of: find.byKey(const Key('note_editor_pin_button')),
          matching: find.text('ピン留め解除'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is_pinned を含まない旧形式ローカル下書きの復元でピン留め状態を維持する', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'note_editor_draft_429': jsonEncode(<String, dynamic>{
          'title': '読書について',
          'content': '下書きから復元した本文',
          'reminder_date': null,
          'is_favorite': false,
          'saved_at': '2026-07-20T00:00:00.000Z',
        }),
      });

      final client = _RecordingSupabaseClient(
        noteRow: _noteRow(isPinned: true),
      );
      await _pumpPage(tester, client);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(_contentController(tester).text, '下書きから復元した本文');
      expect(client.updates, hasLength(1));
      expect(client.updates.single['is_pinned'], isTrue);
      expect(
        find.descendant(
          of: find.byKey(const Key('note_editor_pin_button')),
          matching: find.text('ピン留め解除'),
        ),
        findsOneWidget,
      );
    });
  });
}
