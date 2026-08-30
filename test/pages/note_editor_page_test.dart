import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/note_editor_page.dart';
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
  });

  @override
  final _FakeGoTrueClient auth = _FakeGoTrueClient();

  final Map<String, dynamic> noteRow;

  /// true にすると `_loadNote` の select が失敗する (= サーバー基準値が無い状態)。
  final bool failSelect;
  final Completer<void>? updateGate;
  final List<Map<String, dynamic>> updates = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> inserts = <Map<String, dynamic>>[];

  @override
  SupabaseQueryBuilder from(String table) {
    return _FakeSupabaseQueryBuilder(client: this, table: table);
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
  _FakeSupabaseQueryBuilder({required this.client, required this.table});

  final _RecordingSupabaseClient client;
  final String table;

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) {
    return _FakeSelectBuilder(
      rows: <Map<String, dynamic>>[client.noteRow],
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
    );
  }

  @override
  PostgrestFilterBuilder<dynamic> insert(
    Object values, {
    bool defaultToNull = true,
  }) {
    if (table == 'notes' && values is Map) {
      client.inserts.add(Map<String, dynamic>.from(values));
    }
    return _FakeMutationBuilder(idValue: client.noteRow['id']);
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
  _FakeMutationBuilder({required this.idValue, this.waitFor});

  final Object? idValue;
  final Future<void>? waitFor;

  @override
  _FakeMutationBuilder eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) {
    return _FakeInsertSelectBuilder(idValue: idValue);
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    return _FakeMaybeSingleBuilder(row: <String, dynamic>{'id': idValue});
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    return (waitFor ?? Future<void>.value())
        .then<dynamic>((_) => null)
        .then(onValue, onError: onError);
  }

  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object)? test}) {
    return Future<dynamic>.value(null).catchError(onError, test: test);
  }
}

/// `.insert(...).select('id')` の戻り値。`.maybeSingle()` で新規 id を返す。
class _FakeInsertSelectBuilder extends Fake
    implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {
  _FakeInsertSelectBuilder({required this.idValue});

  final Object? idValue;

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    return _FakeMaybeSingleBuilder(row: <String, dynamic>{'id': idValue});
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
  _FakeMaybeSingleBuilder({required this.row});

  final Map<String, dynamic>? row;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(Map<String, dynamic>? value) onValue, {
    Function? onError,
  }) {
    return Future<Map<String, dynamic>?>.value(row)
        .then(onValue, onError: onError);
  }

  @override
  Future<Map<String, dynamic>?> catchError(
    Function onError, {
    bool Function(Object)? test,
  }) {
    return Future<Map<String, dynamic>?>.value(row)
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
}) {
  return <String, dynamic>{
    'id': '429',
    'user_id': 'test-user-id',
    'title': title,
    'content': content,
    'reminder_date': null,
    'is_favorite': false,
    'tags': <String>['Evernote'],
    'created_at': '2026-07-19T09:00:00.000Z',
    'updated_at': '2026-07-19T09:00:00.000Z',
  };
}

Future<void> _pumpPage(
  WidgetTester tester,
  _RecordingSupabaseClient client, {
  NoteSemanticSearchDataSource? semanticSearchService,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeService>(
      create: (_) => ThemeService(),
      child: MaterialApp(
        home: NoteEditorPage(
          noteId: '429',
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

  group('note editor autosave', () {
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
}
