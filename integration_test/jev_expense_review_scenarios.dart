import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/jev_client.dart';
import 'package:my_web_app/services/jev_expense_proxy_client.dart';
import 'package:my_web_app/services/jev_instant_classifier_service.dart';
import 'package:my_web_app/widgets/expense_classification_review.dart';

http.Response answer(String category, {double confidence = 0.96}) =>
    http.Response(
      jsonEncode({
        'answers': {
          'classification': {
            'type': 'choice',
            'choice': category,
            'confidence': confidence,
            'probabilities': {
              for (final choice
                  in JevInstantClassifierService.defaultCategories)
                choice.id: choice.id == category ? 1.0 : 0.0,
            },
          },
        },
      }),
      200,
    );

Widget host(String memo, {JevClient? client}) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExpenseClassificationReview(memo: memo, client: client),
        ),
      ),
    );

void main({Future<void> Function(String name)? capture}) {
  testWidgets('Uniform AI response does not promote the first category',
      (tester) async {
    var calls = 0;
    final client = JevClient(
      endpoint: 'http://127.0.0.1:8081/v1/systemone',
      httpClient: MockClient((request) async {
        calls++;
        const categories = JevInstantClassifierService.defaultCategories;
        return http.Response(
          jsonEncode({
          'answers': {
            'classification': {
              'type': 'choice',
              'choice': 'food',
              'confidence': 2.220446049250313e-16,
              'probabilities': {
                for (final category in categories)
                  category.id: 1.0 / categories.length,
              },
            },
          },
          }),
          200,
        );
      }),
    );
    addTearDown(client.dispose);
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host('電車の切符を買った', client: client));
    await tester.ensureVisible(find.text('AIにも候補を聞く'));
    await tester.tap(find.text('AIにも候補を聞く'));
    await tester.pumpAndSettle();
    expect(find.text('候補を絞れませんでした'), findsOneWidget);
    expect(find.text('候補：食費・食材'), findsNothing);
    expect(find.textContaining('先頭の候補を表示していません'), findsOneWidget);
    expect(find.textContaining('0%（正答率ではありません）'), findsOneWidget);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
    await capture?.call('uniform-ai-review');
  });

  testWidgets('Confidence help is available before any AI request', (
    tester,
  ) async {
    var calls = 0;
    final client = JevClient(
      endpoint: 'http://127.0.0.1:8081/v1/systemone',
      httpClient: MockClient((request) async {
        calls++;
        return answer('food');
      }),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(host('電気代', client: client));
    await tester.tap(find.text('確信度の読み方'));
    await tester.pumpAndSettle();
    expect(find.textContaining('100%でも'), findsOneWidget);
    expect(find.textContaining('モデルの確信度：'), findsNothing);
    expect(calls, 0);
    if (capture != null) await capture('confidence-before-request');
    await tester.pumpWidget(host('水道代', client: client));
    await tester.pumpAndSettle();
    expect(find.textContaining('100%でも'), findsNothing);
    expect(find.text('確信度の読み方'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets(
      'Cloud candidates require explicit action and recover after quota failure',
      (tester) async {
    var calls = 0;
    final client = JevExpenseProxyClient(
      signedIn: () => true,
      invoke: (body) async {
        calls++;
        expect(body['memo'], 'スタバ');
        if (calls == 1) {
          throw Exception('quota_exceeded');
        }
        return jsonDecode(answer('food').body);
      },
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(host('スタバ', client: client));
    expect(calls, 0);
    expect(find.textContaining('TypeSafe AIへ送信'), findsOneWidget);
    await tester.tap(find.text('AIにも候補を聞く'));
    await tester.pumpAndSettle();
    expect(find.text('端末内ルール'), findsOneWidget);
    expect(find.textContaining('取得できなかった'), findsOneWidget);
    await tester.tap(find.text('AIにも候補を聞く'));
    await tester.pumpAndSettle();
    expect(find.text('AI候補'), findsOneWidget);
    expect(find.text('接続先：クラウドAI'), findsOneWidget);
    expect(find.textContaining('応答時間：'), findsOneWidget);
    expect(find.textContaining('モデル内部の推論時間ではありません'), findsOneWidget);
    expect(find.text('候補：食費・食材'), findsOneWidget);
    expect(find.text('要確認'), findsOneWidget);
    expect(find.textContaining('自動で変更しません'), findsOneWidget);
  });

  testWidgets('A certain wrong candidate stays read-only with an explanation',
      (tester) async {
    var requests = 0;
    final client = JevClient(
      endpoint: 'http://127.0.0.1:8081/v1/systemone',
      httpClient: MockClient((request) async {
        requests++;
        // Deliberately wrong: an electricity bill is not food.
        return answer('food', confidence: 1.0);
      }),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(host('電気代', client: client));
    expect(find.text('候補：水道・光熱費'), findsOneWidget);
    expect(requests, 0);
    await tester.tap(find.text('AIにも候補を聞く'));
    await tester.pumpAndSettle();
    expect(find.text('候補：食費・食材'), findsOneWidget);
    expect(find.textContaining('100%（正答率ではありません）'), findsOneWidget);
    expect(find.text('要確認'), findsOneWidget);
    expect(find.textContaining('自動で変更しません'), findsOneWidget);
    expect(find.text('接続先：ローカルAI'), findsOneWidget);
    expect(find.textContaining('応答時間：'), findsOneWidget);
    await capture?.call('confidence-collapsed');
    await tester.tap(find.text('確信度の読み方'));
    await tester.pumpAndSettle();
    expect(find.textContaining('正解や保存の許可を意味しません'), findsOneWidget);
    await capture?.call('confidence-expanded');
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture?.call('confidence-narrow-320');
    await tester.binding.setSurfaceSize(null);
    await tester.pumpAndSettle();
    expect(requests, 1);
    await tester.pumpWidget(host('水道代', client: client));
    expect(find.text('候補：水道・光熱費'), findsOneWidget);
    expect(find.text('確信度の読み方'), findsOneWidget);
    expect(find.textContaining('100%'), findsNothing);
    expect(find.textContaining('応答時間：'), findsNothing);
    await capture?.call('confidence-edited');
    expect(requests, 1);
  });

  testWidgets('An unknown category is rejected and a retry recovers',
      (tester) async {
    var requests = 0;
    final client = JevClient(
      endpoint: 'http://127.0.0.1:8081/v1/systemone',
      httpClient: MockClient((request) async {
        requests++;
        return answer(
          requests == 1 ? 'not_a_category' : 'utilities',
          confidence: 1.0,
        );
      }),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(host('電気代', client: client));
    await tester.tap(find.text('AIにも候補を聞く'));
    await tester.pumpAndSettle();
    expect(find.text('端末内ルール'), findsOneWidget);
    expect(find.text('候補：水道・光熱費'), findsOneWidget);
    expect(find.textContaining('取得できなかった'), findsOneWidget);
    expect(find.text('確信度の読み方'), findsOneWidget);
    await tester.tap(find.text('AIにも候補を聞く'));
    await tester.pumpAndSettle();
    expect(find.text('AI候補'), findsOneWidget);
    expect(find.text('候補：水道・光熱費'), findsOneWidget);
    expect(find.text('要確認'), findsOneWidget);
    expect(find.textContaining('取得できなかった'), findsNothing);
    expect(requests, 2);
  });

  testWidgets('Rule candidates are read-only and never claim accuracy', (
    tester,
  ) async {
    var requests = 0;
    final client = JevClient(
      endpoint: 'http://127.0.0.1:8081/v1/systemone',
      httpClient: MockClient((request) async {
        requests++;
        return answer('food');
      }),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(host('スタバ', client: client));
    expect(find.text('候補：カフェ・間食'), findsOneWidget);
    expect(find.text('端末内ルール'), findsOneWidget);
    expect(find.text('要確認'), findsOneWidget);
    expect(find.textContaining('自動で変更しません'), findsOneWidget);
    expect(find.textContaining('85%'), findsNothing);
    expect(requests, 0);

    await tester.pumpWidget(host('用途不明の買い物', client: client));
    expect(find.text('候補を絞れませんでした'), findsOneWidget);
    expect(find.text('候補：その他支出'), findsNothing);
    expect(requests, 0);

    await tester.pumpWidget(host('  ', client: client));
    expect(find.text('内容を入力'), findsOneWidget);
    expect(find.text('AIにも候補を聞く'), findsNothing);
    expect(find.text('要確認'), findsNothing);
  });

  testWidgets('AI is explicit, failure keeps rules, retry remains a suggestion',
      (
    tester,
  ) async {
    var requests = 0;
    final client = JevClient(
      endpoint: 'http://127.0.0.1:8081/v1/systemone',
      httpClient: MockClient((request) async {
        requests++;
        expect(request.body, contains('スタバ'));
        return requests == 1
            ? http.Response('unavailable', 503)
            : answer('food');
      }),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(host('スタバ', client: client));
    expect(requests, 0);
    expect(find.textContaining('ローカルAI（127.0.0.1）'), findsOneWidget);
    await tester.tap(find.text('AIにも候補を聞く'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.textContaining('取得できなかった'), findsOneWidget);
    expect(find.text('候補：カフェ・間食'), findsOneWidget);
    await tester.tap(find.text('AIに接続できないとき'));
    await tester.pumpAndSettle();
    expect(find.textContaining('指定したモデルの準備'), findsOneWidget);
    expect(find.textContaining('時間切れを区別できません'), findsOneWidget);
    expect(requests, 1);
    await capture?.call('local-connection-failure-help');
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture?.call('local-connection-failure-help-320');
    await tester.binding.setSurfaceSize(null);
    await tester.pumpAndSettle();
    expect(requests, 1);
    await tester.tap(find.text('AIにも候補を聞く'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('AI候補'), findsOneWidget);
    expect(find.text('候補：食費・食材'), findsOneWidget);
    expect(find.text('要確認'), findsOneWidget);
    expect(find.textContaining('96%（正答率ではありません）'), findsOneWidget);
    expect(find.textContaining('取得できなかった'), findsNothing);
    expect(find.text('AIに接続できないとき'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Edited memo rejects stale AI results and dispose is safe', (
    tester,
  ) async {
    final pending = <Completer<http.Response>>[];
    final client = JevClient(
      endpoint: 'http://127.0.0.1:8081/v1/systemone',
      httpClient: MockClient((request) {
        final response = Completer<http.Response>();
        pending.add(response);
        return response.future;
      }),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(host('スタバ', client: client));
    await tester.tap(find.text('AIにも候補を聞く'));
    await tester.pump();
    expect(find.text('AIに確認中…'), findsOneWidget);
    await tester.pumpWidget(host('電気代', client: client));
    pending.first.complete(answer('food'));
    await tester.pumpAndSettle();
    expect(find.text('候補：水道・光熱費'), findsOneWidget);
    expect(find.text('AI候補'), findsNothing);
    await tester.tap(find.text('AIにも候補を聞く'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.last.complete(answer('food'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unconfigured AI is hidden and narrow enlarged text wraps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: ExpenseClassificationReview(memo: 'スタバ'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('候補：カフェ・間食'), findsOneWidget);
    expect(find.text('AIにも候補を聞く'), findsNothing);
    await tester.tap(find.text('確信度の読み方'));
    await tester.pumpAndSettle();
    expect(find.textContaining('100%でも'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
