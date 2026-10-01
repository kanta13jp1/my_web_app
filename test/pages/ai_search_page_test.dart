import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/ai_search_page.dart';
import 'package:my_web_app/pages/note_editor_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Object result(String title) => {
      'results': [
        {'id': 42, 'title': title, 'content': '合成ノート', 'tags': <String>[]},
      ],
      'searchMode': 'text',
    };

Future<void> submit(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
}

void main() {
  testWidgets('guest and sample controls scroll at 320px with large text and keyboard', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _SessionClient();
    addTearDown(client.auth.events.close);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
          viewInsets: const EdgeInsets.only(bottom: 220),
        ),
        child: child!,
      ),
      home: AiSearchPage(supabaseClient: client, search: (_) async => result('private')),
    ));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('サンプルで試す'));
    await tester.tap(find.text('サンプルで試す'));
    await tester.pump();
    await tester.ensureVisible(find.byType(TextField));
    await submit(tester, 'Flutter');
    await tester.pump(const Duration(milliseconds: 601));
    await tester.ensureVisible(find.text('Flutter学習メモ'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the result id and returns to the retained query', (tester) async {
    String? opened;
    await tester.pumpWidget(MaterialApp(home: AiSearchPage(
      search: (_) async => result('開けるノート'),
      notePageBuilder: (id) {
        opened = id;
        return Scaffold(appBar: AppBar(title: const Text('開いたノート')), body: Text('本文 $id'));
      },
    )));
    await submit(tester, 'メモ');
    await tester.tap(find.text('開けるノート'));
    await tester.pumpAndSettle();
    expect(opened, '42');
    expect(find.text('本文 42'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('「メモ」の結果（1件）'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'メモ'), findsOneWidget);
    expect(find.text('開けるノート'), findsOneWidget);
  });

  testWidgets('guest has a login action and sample search opens read-only notes', (tester) async {
    final client = _SessionClient();
    addTearDown(client.auth.events.close);
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
      routes: {'/login': (_) => Scaffold(appBar: AppBar(title: const Text('ログイン入口')))},
      home: AiSearchPage(supabaseClient: client, search: (_) async {
        requests++;
        return result('private');
      }),
    ));
    expect(find.text('ログインして検索'), findsOneWidget);
    expect(find.text('再試行'), findsNothing);
    await submit(tester, 'メモ');
    expect(requests, 0);
    await tester.tap(find.text('ログインして検索'));
    await tester.pumpAndSettle();
    expect(find.text('ログイン入口'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('サンプルで試す'));
    await tester.pump();
    await submit(tester, '買い物');
    await tester.pump(const Duration(milliseconds: 601));
    expect(find.text('週末の買い物'), findsOneWidget);
    await tester.tap(find.text('週末の買い物'));
    await tester.pumpAndSettle();
    expect(find.text('架空のノート・閲覧専用'), findsOneWidget);
    expect(find.byType(NoteEditorPage), findsNothing);
    expect(requests, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('「買い物」の結果（1件）'), findsOneWidget);
    await tester.tap(find.text('自分のノートに戻る'));
    await tester.pump();
    expect(find.text('週末の買い物'), findsNothing);
    expect(find.text('ログインして検索'), findsOneWidget);
  });

  testWidgets('logout clears results and rejects an old-account completion', (tester) async {
    final client = _SessionClient();
    client.auth.user = _user('account-a');
    addTearDown(client.auth.events.close);
    final pending = Completer<Object?>();
    await tester.pumpWidget(MaterialApp(home: AiSearchPage(
      supabaseClient: client,
      search: (q) => q == 'first' ? Future.value(result('以前のノート')) : pending.future,
    )));
    await submit(tester, 'first');
    await submit(tester, 'slow');
    client.auth.user = null;
    client.auth.events.add(AuthState(AuthChangeEvent.signedOut, null));
    await tester.pump();
    pending.complete(result('遅れてきた非公開ノート'));
    await tester.pump();
    expect(find.text('以前のノート'), findsNothing);
    expect(find.text('遅れてきた非公開ノート'), findsNothing);
    expect(find.text('ログインして検索'), findsOneWidget);
  });

  testWidgets('expired session offers login instead of repeating a failing request', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AiSearchPage(
      search: (_) async => throw const FunctionException(status: 401, details: 'Unauthorized'),
    )));
    await submit(tester, 'メモ');
    expect(find.text('ログインして検索'), findsOneWidget);
    expect(find.text('再試行'), findsNothing);
    expect(find.text('検索語を入力して検索してください'), findsNothing);
  });

  testWidgets('result without an id cannot accidentally create a new note', (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(home: AiSearchPage(
      search: (_) async => {'results': [{'title': 'IDなし', 'content': '抜粋'}]},
      notePageBuilder: (_) { opened = true; return const SizedBox(); },
    )));
    await submit(tester, 'メモ');
    await tester.tap(find.text('IDなし'));
    await tester.pump();
    expect(opened, isFalse);
    expect(find.text('この結果は開けません。もう一度検索してください。'), findsOneWidget);
  });

  testWidgets(
    'keeps prior results and only the newest response wins',
    (tester) async {
      final requests = <String, Completer<Object?>>{};
      await tester.pumpWidget(
        MaterialApp(
          home: AiSearchPage(
            search: (query) {
              final request = Completer<Object?>();
              requests[query] = request;
              return request.future;
            },
          ),
        ),
      );
      await submit(tester, 'first');
      requests['first']!.complete(result('最初のノート'));
      await tester.pump();
      await submit(tester, 'slow');
      expect(find.text('最初のノート'), findsOneWidget);
      expect(find.text('前の結果:「first」（1件）'), findsOneWidget);
      await submit(tester, 'new');
      requests['new']!.complete(result('最新のノート'));
      await tester.pump();
      requests['slow']!.complete(result('古いノート'));
      await tester.pump();
      expect(find.text('最新のノート'), findsOneWidget);
      expect(find.text('古いノート'), findsNothing);
      expect(find.text('「new」の結果（1件）'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'old failure cannot clear a newer pending request',
    (tester) async {
      final requests = <String, Completer<Object?>>{};
      await tester.pumpWidget(
        MaterialApp(
          home: AiSearchPage(
            search: (query) {
              return (requests[query] = Completer<Object?>()).future;
            },
          ),
        ),
      );
      await submit(tester, 'old');
      await submit(tester, 'new');
      requests['old']!.completeError(Exception('old failed'));
      await tester.pump();
      expect(find.text('「new」を検索中…'), findsOneWidget);
      expect(find.text('再試行'), findsNothing);
      requests['new']!.complete(result('新しい結果'));
      await tester.pump();
      expect(find.text('新しい結果'), findsOneWidget);
    },
  );

  testWidgets(
    'deduplicates pending query and invalidates on clear',
    (tester) async {
      var calls = 0;
      final request = Completer<Object?>();
      await tester.pumpWidget(
        MaterialApp(
          home: AiSearchPage(
            search: (_) {
              calls++;
              return request.future;
            },
          ),
        ),
      );
      await submit(tester, 'query');
      await submit(tester, ' query ');
      expect(calls, 1);
      await tester.tap(find.byTooltip('検索をクリア'));
      await tester.pump();
      request.complete(result('消した検索の応答'));
      await tester.pump();
      expect(find.text('消した検索の応答'), findsNothing);
      expect(find.text('検索語を入力して検索してください'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps last success after failure and retries the failed query',
    (tester) async {
      final queries = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: AiSearchPage(
            search: (query) async {
              queries.add(query);
              if (queries.length == 2) throw Exception('offline');
              return result(query == 'first' ? '前のノート' : '回復したノート');
            },
          ),
        ),
      );
      await submit(tester, 'first');
      await submit(tester, 'retry');
      expect(find.text('前のノート'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'not submitted');
      await tester.tap(find.text('再試行'));
      await tester.pump();
      expect(queries, ['first', 'retry', 'retry']);
      expect(find.text('回復したノート'), findsOneWidget);
      expect(find.text('前の結果:「retry」（1件）'), findsOneWidget);
    },
  );

  testWidgets(
    'empty results and unsubmitted text are distinguished',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AiSearchPage(
            search: (_) async => {'results': []},
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'draft');
      await tester.pump();
      expect(find.text('検索語を入力して検索してください'), findsOneWidget);
      await submit(tester, 'empty');
      expect(find.text('「empty」に該当するノートはありません'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'next');
      await tester.pump();
      expect(find.text('前の結果:「empty」（0件）'), findsOneWidget);
    },
  );

  testWidgets(
    'malformed response is recoverable and does not erase results',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AiSearchPage(
            search: (_) async {
              return ++calls == 2 ? {'unexpected': true} : result('確定ノート');
            },
          ),
        ),
      );
      await submit(tester, 'first');
      await submit(tester, 'broken');
      expect(find.text('確定ノート'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    },
  );

  testWidgets(
    'timeout permits retry and ignores the timed out completion',
    (tester) async {
      final request = Completer<Object?>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AiSearchPage(
            search: (_) {
              return ++calls == 1
                  ? request.future
                  : Future.value(result('再試行成功'));
            },
          ),
        ),
      );
      await submit(tester, 'query');
      await tester.pump(const Duration(seconds: 31));
      expect(
        find.text('「query」の検索: 検索に時間がかかっています。もう一度お試しください。'),
        findsOneWidget,
      );
      await tester.tap(find.text('再試行'));
      await tester.pump();
      request.complete(result('タイムアウトした結果'));
      await tester.pump();
      expect(find.text('再試行成功'), findsOneWidget);
      expect(find.text('タイムアウトした結果'), findsNothing);
    },
  );

  testWidgets(
    'long query keeps recovery usable on a narrow large-text screen',
    (tester) async {
      tester.view.physicalSize = const Size(393, 851);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: AiSearchPage(search: (_) async => throw Exception('offline')),
        ),
      );
      await submit(tester, '長い検索語' * 80);
      expect(find.text('再試行'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'completion after disposal cannot update the removed page',
    (tester) async {
      final request = Completer<Object?>();
      await tester.pumpWidget(
        MaterialApp(
          home: AiSearchPage(
            search: (_) => request.future,
          ),
        ),
      );
      await submit(tester, 'query');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      request.complete(result('late'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

User _user(String id) => User(id: id, appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '2026-10-02');

class _SessionClient extends Fake implements SupabaseClient {
  @override
  final _SessionAuth auth = _SessionAuth();
}

class _SessionAuth extends Fake implements GoTrueClient {
  final events = StreamController<AuthState>.broadcast();
  User? user;
  @override
  User? get currentUser => user;
  @override
  Stream<AuthState> get onAuthStateChange => events.stream;
}
