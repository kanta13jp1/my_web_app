import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/jev_expense_proxy_client.dart';
import 'package:my_web_app/widgets/expense_semantic_search.dart';

Map<String, dynamic> searchAnswer(double score) => {
      'answers': {
        'classification': {
          'type': 'choice',
          'choice': score >= 0.5 ? 'match' : 'not_match',
          'confidence': score >= 0.5 ? score : 1 - score,
          'probabilities': {'match': score, 'not_match': 1 - score},
        },
      },
    };

Widget host(
  JevExpenseProxyClient client, {
  String memo = '人工例：返金を依頼した。まだ未完了。',
  String period = '2026年10月',
  Key? accountKey,
  Stream<String?>? sessionIdentities,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExpenseSemanticSearch(
            key: accountKey,
            periodLabel: period,
            client: client,
            sessionIdentities: sessionIdentities,
            items: [
              {'title': memo, 'amount': 123456789, 'date': 'private-date'},
              const {'title': '人工例：返金完了。'},
            ],
          ),
        ),
      ),
    );

Future<void> expand(WidgetTester tester) async {
  await tester.tap(find.text('支出メモを条件で探す'));
  await tester.pumpAndSettle();
}

Future<void> ask(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final button = find.byKey(const Key('expense_search_ai_0'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main({Future<void> Function(String name)? capture}) {
  testWidgets(
      'Search sends one selected memo only after explicit action, AND NOT is visible',
      (tester) async {
    final sent = <Map<String, dynamic>>[];
    final client = JevExpenseProxyClient(
      semanticSearch: true,
      signedIn: () => true,
      invoke: (body) async {
        sent.add(body);
        return searchAnswer(sent.length == 1 ? 0.9 : 0.8);
      },
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(host(client));
    await expand(tester);
    await tester.enterText(
      find.byKey(const Key('expense_search_query')),
      '返金要求',
    );
    await tester.enterText(
      find.byKey(const Key('expense_search_exclude')),
      '完了',
    );
    expect(sent, isEmpty);
    expect(find.textContaining('TypeSafe AIへ送ります'), findsOneWidget);
    await ask(tester);
    expect(sent.length, 2);
    for (final body in sent) {
      expect(body.keys.toSet(), {'action', 'memo', 'consent'});
      expect(body['action'], 'expense.jev_search');
      expect(body['consent'], true);
      expect(body['memo'], contains('人工例：返金を依頼した'));
      expect(body['memo'], isNot(contains('123456789')));
      expect(body['memo'], isNot(contains('private-date')));
      expect(body['memo'], isNot(contains('人工例：返金完了。')));
    }
    expect(find.text('AI判定・要確認'), findsOneWidget);
    expect(find.text('条件に合わない候補'), findsOneWidget);
    expect(find.text('未確認'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    await capture?.call('semantic-search-ai-exclusion');
  });

  testWidgets(
      'Search failure is word matching, recovers, and remains readable at 320 pixels',
      (tester) async {
    var calls = 0;
    final client = JevExpenseProxyClient(
      semanticSearch: true,
      signedIn: () => true,
      invoke: (_) async {
        calls++;
        if (calls == 1) throw Exception('quota_exceeded');
        return searchAnswer(0.9);
      },
    );
    addTearDown(client.dispose);
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(client));
    await expand(tester);
    await tester.enterText(find.byKey(const Key('expense_search_query')), '返金');
    await ask(tester);
    expect(find.text('語句一致・AI判定ではありません'), findsOneWidget);
    expect(find.textContaining('AIの確信度ではありません'), findsOneWidget);
    expect(find.text('AI判定・要確認'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(tester.takeException(), isNull);
    await capture?.call('semantic-search-mobile-fallback');
    await ask(tester);
    expect(calls, 2);
    expect(find.text('AI判定・要確認'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Signed-out search remains local and never invokes the proxy',
      (tester) async {
    var calls = 0;
    final client = JevExpenseProxyClient(
      semanticSearch: true,
      signedIn: () => false,
      invoke: (_) async {
        calls++;
        return searchAnswer(1);
      },
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(host(client));
    await expand(tester);
    await tester.enterText(find.byKey(const Key('expense_search_query')), '返金');
    await tester.ensureVisible(find.text('語句で探す（送信なし）'));
    await tester.tap(find.text('語句で探す（送信なし）'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('語句一致・AI判定ではありません'), findsNWidgets(2));
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('expense_search_ai_0')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
      'Changing query, memo, month or account discards late results and cached views',
      (tester) async {
    var pending = Completer<Map<String, dynamic>>();
    final client = JevExpenseProxyClient(
      semanticSearch: true,
      signedIn: () => true,
      invoke: (_) => pending.future,
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(host(client));
    await expand(tester);
    await tester.enterText(find.byKey(const Key('expense_search_query')), '返金');
    final button = find.byKey(const Key('expense_search_ai_0'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('expense_search_query')),
      '交通費',
    );
    pending.complete(searchAnswer(1));
    await tester.pumpAndSettle();
    expect(find.text('AI判定・要確認'), findsNothing);
    pending = Completer<Map<String, dynamic>>();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pumpWidget(host(client, memo: '人工例：別のメモ', period: '2026年11月'));
    pending.complete(searchAnswer(1));
    await tester.pumpAndSettle();
    expect(find.text('AI判定・要確認'), findsNothing);
    pending = Completer<Map<String, dynamic>>()..complete(searchAnswer(1));
    await ask(tester);
    expect(find.text('AI判定・要確認'), findsOneWidget);
    await tester
        .pumpWidget(host(client, accountKey: const ValueKey('another-user')));
    await expand(tester);
    expect(find.text('AI判定・要確認'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('expense_search_query')))
          .controller!
          .text,
      isEmpty,
    );
  });
  testWidgets(
      'Account events clear displayed AI results and disable previous memos',
      (tester) async {
    final identities = StreamController<String?>();
    addTearDown(identities.close);
    var calls = 0;
    final client = JevExpenseProxyClient(
      semanticSearch: true,
      signedIn: () => true,
      invoke: (_) async {
        calls++;
        return searchAnswer(1);
      },
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(host(client, sessionIdentities: identities.stream));
    identities.add('first-user');
    await tester.pump();
    await expand(tester);
    await tester.tap(find.byKey(const Key('expense_search_examples')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expense_search_query')), '返金');
    await ask(tester);
    expect(find.text('AI判定・要確認'), findsOneWidget);
    identities.add('second-user');
    await tester.pumpAndSettle();
    expect(find.text('AI判定・要確認'), findsNothing);
    expect(find.byKey(const Key('expense_search_ai_0')), findsNothing);
    expect(find.textContaining('画面を開き直す'), findsOneWidget);
    expect(find.text('保存しない操作例 3件'), findsNothing);
    expect(calls, 1);
  });
  testWidgets('Examples stay separate from private memos and require explicit sending',
      (tester) async {
    final sent = <Map<String, dynamic>>[];
    final client = JevExpenseProxyClient(
      semanticSearch: true,
      signedIn: () => true,
      invoke: (body) async {
        sent.add(body);
        return searchAnswer(0.9);
      },
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(host(client, memo: '非公開の支出メモ'));
    await expand(tester);
    expect(find.text('非公開の支出メモ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('expense_search_examples')));
    await tester.pumpAndSettle();
    expect(find.text('非公開の支出メモ'), findsNothing);
    expect(find.text('保存しない操作例 3件'), findsOneWidget);
    expect(sent, isEmpty);
    await tester.enterText(
      find.byKey(const Key('expense_search_query')),
      '返金を求めている',
    );
    await ask(tester);
    expect(sent.length, 1);
    expect(sent.single['memo'], contains('例：商品の不具合'));
    expect(sent.single['memo'], isNot(contains('非公開')));
    expect(find.text('AI判定・要確認'), findsOneWidget);
    await capture?.call('semantic-search-examples');
    await tester.ensureVisible(find.byKey(const Key('expense_search_examples')));
    await tester.tap(find.byKey(const Key('expense_search_examples')));
    await tester.pumpAndSettle();
    expect(find.text('非公開の支出メモ'), findsOneWidget);
    expect(find.text('AI判定・要確認'), findsNothing);
    expect(sent.length, 1);
  });

}
