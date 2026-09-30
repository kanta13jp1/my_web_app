import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/ai_search_page.dart';

Object result(String title) => {
      'results': [
        {'title': title, 'content': '合成ノート', 'tags': <String>[]},
      ],
      'searchMode': 'text',
    };

Future<void> submit(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
}

void main() {
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
          find.text('「query」の検索: 検索に時間がかかっています。もう一度お試しください。'), findsOneWidget);
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
