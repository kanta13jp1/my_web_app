import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/jev_client.dart';
import 'package:my_web_app/services/jev_semantic_expense_search_service.dart';

void main() {
  group('JevSemanticExpenseSearchService Tests', () {
    final List<Map<String, dynamic>> testExpenses = <Map<String, dynamic>>[
      <String, dynamic>{
        'title': '居酒屋 魚金 渋谷店',
        'category': '交際費',
        'amount': 6500,
        'date': '2026-09-18',
      },
      <String, dynamic>{
        'title': 'マネーフォワード 年額プラン',
        'category': '固定費',
        'amount': 5500,
        'date': '2026-09-12',
      },
      <String, dynamic>{
        'title': 'セブンイレブン おにぎりとお茶',
        'category': '食費',
        'amount': 380,
        'date': '2026-09-19',
      },
      <String, dynamic>{
        'title': '三井住友カード 返済完了',
        'category': '負債返済',
        'amount': 35000,
        'date': '2026-09-10',
      },
    ];

    test('空クエリ時は全アイテムをスコア1.0で返却する', () async {
      final JevSemanticExpenseSearchService service =
          JevSemanticExpenseSearchService(
        client: JevClient(apiKey: null), // 未設定
      );

      final List<SemanticSearchResult> results = await service.search(
        items: testExpenses,
        meaningQuery: '',
      );

      expect(results.length, equals(testExpenses.length));
      expect(results.every((SemanticSearchResult r) => r.isMatch), isTrue);
      expect(results.first.source, equals('empty_query'));
    });

    test('Jev未設定時はローカルキーワード部分一致検索へFail-Openフォールバックする', () async {
      final JevSemanticExpenseSearchService service =
          JevSemanticExpenseSearchService(
        client: JevClient(apiKey: null),
      );

      final List<SemanticSearchResult> results = await service.search(
        items: testExpenses,
        meaningQuery: '居酒屋',
      );

      expect(results.length, equals(testExpenses.length));
      final SemanticSearchResult first = results.first;
      expect(first.isMatch, isTrue);
      expect(first.item['title'], contains('居酒屋'));
      expect(first.source, equals('local_fallback'));
    });

    test('ローカルフォールバック時でも excludeQuery (AND NOT) が正常に機能する', () async {
      final JevSemanticExpenseSearchService service =
          JevSemanticExpenseSearchService(
        client: JevClient(apiKey: null),
      );

      final List<SemanticSearchResult> results = await service.search(
        items: testExpenses,
        meaningQuery: 'カード',
        excludeQuery: '完了',
      );

      // '三井住友カード 返済完了' は '完了' が含まれるため isMatch が false になる
      final SemanticSearchResult cardItem = results.firstWhere(
        (SemanticSearchResult r) =>
            r.item['title'].toString().contains('三井住友カード'),
      );
      expect(cardItem.isMatch, isFalse);
    });

    test('Jev API モック連携で命題判定スコアが正常に反映される', () async {
      final MockClient mockHttpClient =
          MockClient((http.Request request) async {
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        final String input =
            body['input'] as String? ?? body['state'] as String? ?? '';

        if (input.contains('魚金')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'answers': {
                'classification': {
                  'type': 'choice',
                  'choice': 'match',
                  'confidence': 0.95,
                  'probabilities': <String, dynamic>{
                    'match': 0.95,
                    'not_match': 0.05,
                  },
                },
              },
            }),
            200,
          );
        } else {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'answers': {
                'classification': {
                  'type': 'choice',
                  'choice': 'not_match',
                  'confidence': 0.88,
                  'probabilities': <String, dynamic>{
                    'match': 0.12,
                    'not_match': 0.88,
                  },
                },
              },
            }),
            200,
          );
        }
      });

      final JevClient client = JevClient(
        apiKey: 'test-api-key',
        httpClient: mockHttpClient,
      );

      final JevSemanticExpenseSearchService service =
          JevSemanticExpenseSearchService(
        client: client,
      );

      final List<SemanticSearchResult> results = await service.search(
        items: testExpenses,
        meaningQuery: '飲み会・外食',
      );

      expect(results.length, equals(testExpenses.length));
      final SemanticSearchResult topMatch = results.first;
      expect(topMatch.item['title'], equals('居酒屋 魚金 渋谷店'));
      expect(topMatch.score, equals(0.95));
      expect(topMatch.isMatch, isTrue);
      expect(topMatch.source, equals('jev'));
    });

    test('Jev API で肯定と除外の質問を別々に判定する', () async {
      final List<String> queries = <String>[];
      final MockClient mockHttpClient =
          MockClient((http.Request request) async {
        final String query = _queryFrom(request);
        queries.add(query);
        return _response(query == 'カード関連' ? 0.92 : 0.90);
      });
      final JevSemanticExpenseSearchService service =
          JevSemanticExpenseSearchService(
        client: JevClient(apiKey: 'test-api-key', httpClient: mockHttpClient),
      );
      final List<SemanticSearchResult> results = await service.search(
        items: <Map<String, dynamic>>[testExpenses.last],
        meaningQuery: 'カード関連',
        excludeQuery: '手続き完了',
      );
      expect(queries, <String>['カード関連', '手続き完了']);
      expect(results.single.score, 0.92);
      expect(results.single.isMatch, isFalse);
      expect(results.single.source, 'jev');
    });

    test('通信例外発生時でもエラーを外へ投げずFail-Openで安全にフォールバックする', () async {
      final MockClient failingClient = MockClient((http.Request request) async {
        throw Exception('Network unreachable');
      });

      final JevClient client = JevClient(
        apiKey: 'test-api-key',
        httpClient: failingClient,
      );

      final JevSemanticExpenseSearchService service =
          JevSemanticExpenseSearchService(
        client: client,
      );

      final List<SemanticSearchResult> results = await service.search(
        items: testExpenses,
        meaningQuery: 'セブンイレブン',
      );

      expect(results.length, equals(testExpenses.length));
      final SemanticSearchResult match = results.firstWhere(
        (SemanticSearchResult r) =>
            r.item['title'].toString().contains('セブンイレブン'),
      );
      expect(match.isMatch, isTrue);
      expect(match.source, 'local_fallback');
    });
    test('旧endpointの空scoresは従来どおりconfidenceで補完する', () async {
      final MockClient mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'best_choice_id': 'match',
            'confidence': 0.85,
            'scores': <String, double>{},
          }),
          200,
        );
      });
      final JevSemanticExpenseSearchService service =
          JevSemanticExpenseSearchService(
        client: JevClient(
          apiKey: 'test-api-key',
          endpoint: 'https://example.test/classify',
          httpClient: mock,
        ),
      );
      final List<SemanticSearchResult> results = await service.search(
        items: <Map<String, dynamic>>[testExpenses.last],
        meaningQuery: 'カード',
      );
      expect(results.single.source, 'jev');
      expect(results.single.score, 0.85);
      expect(results.single.isMatch, isTrue);
    });

    for (final String failure in <String>[
      'HTTP 503',
      '空の応答',
      '不正なJSON',
      '通信例外',
    ]) {
      test('$failureでは代替検索と表示し、回復時に再試行する', () async {
        int requests = 0;
        final MockClient mock = MockClient((http.Request request) async {
          requests++;
          if (requests == 1) {
            switch (failure) {
              case 'HTTP 503':
                return http.Response('', 503);
              case '空の応答':
                return http.Response('{"answers":{}}', 200);
              case '不正なJSON':
                return http.Response('{', 200);
              default:
                throw Exception('Network unreachable');
            }
          }
          return _response(0.20);
        });
        final JevSemanticExpenseSearchService service =
            JevSemanticExpenseSearchService(
          client: JevClient(apiKey: 'test-api-key', httpClient: mock),
        );
        const List<Map<String, dynamic>> items = <Map<String, dynamic>>[
          <String, dynamic>{'title': 'COFFEE'},
        ];
        final SemanticSearchResult fallback = (await service.search(
          items: items,
          meaningQuery: 'coffee',
        ))
            .single;
        expect(fallback.source, 'local_fallback');
        expect(fallback.isMatch, isTrue);
        expect(fallback.score, 0.90);

        final SemanticSearchResult recovered = (await service.search(
          items: items,
          meaningQuery: 'coffee',
        ))
            .single;
        expect(recovered.source, 'jev');
        expect(recovered.isMatch, isFalse);
        expect(recovered.score, 0.20);
        final SemanticSearchResult cached = (await service.search(
          items: items,
          meaningQuery: 'coffee',
        ))
            .single;
        expect(cached.toJson(), recovered.toJson());
        expect(requests, 2);
      });
    }

    test('除外判定だけ失敗した場合も全条件を代替検索し、回復時に再試行する', () async {
      final List<String> queries = <String>[];
      int exclusions = 0;
      final MockClient mock = MockClient((http.Request request) async {
        final String query = _queryFrom(request);
        queries.add(query);
        if (query == '完了') {
          exclusions++;
          if (exclusions == 1) return http.Response('', 503);
          return _response(0.10);
        }
        return _response(0.85);
      });
      final JevSemanticExpenseSearchService service =
          JevSemanticExpenseSearchService(
        client: JevClient(apiKey: 'test-api-key', httpClient: mock),
      );
      final SemanticSearchResult fallback = (await service.search(
        items: <Map<String, dynamic>>[testExpenses.last],
        meaningQuery: 'カード',
        excludeQuery: '完了',
      ))
          .single;
      expect(fallback.source, 'local_fallback');
      expect(fallback.score, 0.90);
      expect(fallback.isMatch, isFalse);
      final SemanticSearchResult recovered = (await service.search(
        items: <Map<String, dynamic>>[testExpenses.last],
        meaningQuery: 'カード',
        excludeQuery: '完了',
      ))
          .single;
      expect(recovered.source, 'jev');
      expect(recovered.score, 0.85);
      expect(recovered.isMatch, isTrue);
      expect(queries, <String>['カード', '完了', '完了']);
    });

    for (final double positive in <double>[0.49, 0.50]) {
      for (final double exclusion in <double>[0.59, 0.60]) {
        test('肯定$positive・除外$exclusionの閾値境界を判定する', () async {
          final List<String> queries = <String>[];
          final MockClient mock = MockClient((http.Request request) async {
            final String query = _queryFrom(request);
            queries.add(query);
            return _response(query == 'カード' ? positive : exclusion);
          });
          final JevSemanticExpenseSearchService service =
              JevSemanticExpenseSearchService(
            client: JevClient(apiKey: 'test-api-key', httpClient: mock),
          );
          final SemanticSearchResult result = (await service.search(
            items: <Map<String, dynamic>>[testExpenses.last],
            meaningQuery: 'カード',
            excludeQuery: '完了',
          ))
              .single;
          expect(result.source, 'jev');
          expect(result.score, positive);
          expect(result.isMatch, positive >= 0.50 && exclusion < 0.60);
          expect(
            queries,
            positive < 0.50 ? <String>['カード'] : <String>['カード', '完了'],
          );
        });
      }
    }
  });
}

String _queryFrom(http.Request request) {
  final Map<String, dynamic> body =
      jsonDecode(request.body) as Map<String, dynamic>;
  final String state = body['state'] as String;
  return RegExp(r'判定命題: この支出は「(.*)」に該当するか？').firstMatch(state)!.group(1)!;
}

http.Response _response(double match) {
  final bool selectedMatch = match >= 0.50;
  return http.Response(
    jsonEncode(<String, dynamic>{
      'answers': <String, dynamic>{
        'classification': <String, dynamic>{
          'type': 'choice',
          'choice': selectedMatch ? 'match' : 'not_match',
          'confidence': selectedMatch ? match : 1.0 - match,
          'probabilities': <String, double>{
            'match': match,
            'not_match': 1.0 - match,
          },
        },
      },
    }),
    200,
  );
}
