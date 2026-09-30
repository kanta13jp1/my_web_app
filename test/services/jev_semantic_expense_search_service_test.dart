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

    test('Jev API で excludeQuery (AND NOT) が高い確率のアイテムを除外する', () async {
      final MockClient mockHttpClient =
          MockClient((http.Request request) async {
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        final String input =
            body['input'] as String? ?? body['state'] as String? ?? '';

        if (input.contains('返済完了') && input.contains('カード')) {
          // カード関連 -> match
          return http.Response(
            jsonEncode(<String, dynamic>{
              'answers': {
                'classification': {
                  'type': 'choice',
                  'choice': 'match',
                  'confidence': 0.92,
                  'probabilities': <String, dynamic>{
                    'match': 0.92,
                    'not_match': 0.08,
                  },
                },
              },
            }),
            200,
          );
        } else if (input.contains('返済完了') && input.contains('手続き完了')) {
          // 手続き完了命題 -> match (除外対象)
          return http.Response(
            jsonEncode(<String, dynamic>{
              'answers': {
                'classification': {
                  'type': 'choice',
                  'choice': 'match',
                  'confidence': 0.90,
                  'probabilities': <String, dynamic>{
                    'match': 0.90,
                    'not_match': 0.10,
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
                  'confidence': 0.85,
                  'probabilities': <String, dynamic>{
                    'match': 0.15,
                    'not_match': 0.85,
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
        meaningQuery: 'カード関連',
        excludeQuery: '手続き完了',
      );

      final SemanticSearchResult cardItem = results.firstWhere(
        (SemanticSearchResult r) =>
            r.item['title'].toString().contains('三井住友カード'),
      );
      // 除外スコアが高いため isMatch は false
      expect(cardItem.isMatch, isFalse);
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
    });
  });
}
