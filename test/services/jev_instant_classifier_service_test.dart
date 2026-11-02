import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/jev_client.dart';
import 'package:my_web_app/services/jev_instant_classifier_service.dart';

void main() {
  group('JevInstantClassifierService', () {
    test('初期状態およびデフォルトカテゴリの検証', () {
      final service = JevInstantClassifierService();
      expect(
        service.isAvailable,
        isFalse,
      );
      expect(
        JevInstantClassifierService.defaultCategories.length,
        greaterThanOrEqualTo(10),
      );
      expect(
        JevInstantClassifierService.defaultCategories
            .any((c) => c.id == 'food'),
        isTrue,
      );
      expect(
        JevInstantClassifierService.defaultCategories
            .any((c) => c.id == 'transport'),
        isTrue,
      );
    });

    test('空入力のハンドリング', () async {
      final service = JevInstantClassifierService();
      final prediction = await service.predictCategory('   ');

      expect(prediction.categoryId, 'other');
      expect(prediction.confidence, 0.0);
      expect(prediction.isFallback, isTrue);
      expect(prediction.source, 'empty_input');
    });

    group('ローカルルールベース・フォールバック (Fail-Open)', () {
      final service = JevInstantClassifierService(
        client: JevClient(apiKey: null), // 未設定
      );

      test('カフェキーワード（スタバ）のマッチング', () async {
        final prediction = await service.predictCategory('スターバックス カフェラテ');
        expect(prediction.categoryId, 'cafe_snack');
        expect(prediction.categoryLabel, 'カフェ・間食');
        expect(prediction.confidence, 0.85);
        expect(prediction.isFallback, isTrue);
        expect(prediction.source, 'local_rule');
      });

      test('コンビニキーワード（セブン）のマッチング', () async {
        final prediction = await service.predictCategory('セブンイレブン おにぎり');
        expect(prediction.categoryId, 'convenience');
        expect(prediction.categoryLabel, 'コンビニ');
        expect(prediction.isFallback, isTrue);
      });

      test('交通費キーワード（Suica）のマッチング', () async {
        final prediction = await service.predictCategory('Suicaチャージ');
        expect(prediction.categoryId, 'transport');
        expect(prediction.categoryLabel, '交通費');
        expect(prediction.isFallback, isTrue);
      });

      test('光熱費キーワード（東京電力）のマッチング', () async {
        final prediction = await service.predictCategory('東京電力 8月分');
        expect(prediction.categoryId, 'utilities');
        expect(prediction.categoryLabel, '水道・光熱費');
        expect(prediction.isFallback, isTrue);
      });

      test('未知キーワード時のデフォルトフォールバック', () async {
        final prediction = await service.predictCategory('謎の支払アイテムXYZ');
        expect(prediction.categoryId, 'other');
        expect(prediction.categoryLabel, 'その他支出');
        expect(prediction.confidence, 0.30);
        expect(prediction.isFallback, isTrue);
        expect(prediction.source, 'local_default');
      });
    });

    group('Jev API 正常系連携', () {
      test('Jev から高確信度レスポンス受領時の即時反映', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), JevClient.defaultEndpoint);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['state'], '成城石井の高級チーズ');
          final questions = body['questions'] as Map<String, dynamic>;
          final question = questions['classification'] as Map<String, dynamic>;
          final criteria = question['criteria'] as Map<String, dynamic>;
          expect(criteria, contains('food'));

          return http.Response(
            jsonEncode(<String, dynamic>{
              'answers': {
                'classification': {
                  'type': 'choice',
                  'choice': 'food',
                  'confidence': 0.94,
                  'probabilities': <String, dynamic>{
                    for (final id in criteria.keys) id: 0.0,
                    'food': 0.94,
                    'dining_out': 0.04,
                    'other': 0.02,
                  },
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final jevClient = JevClient(
          apiKey: 'test_key_live_123',
          httpClient: mockClient,
        );
        final service = JevInstantClassifierService(
          client: jevClient,
          isEnabled: true,
        );

        expect(service.isAvailable, isTrue);

        final prediction = await service.predictCategory('成城石井の高級チーズ');
        expect(prediction.categoryId, 'food');
        expect(prediction.categoryLabel, '食費・食材');
        expect(prediction.confidence, 0.94);
        expect(prediction.isHighConfidence, isTrue);
        expect(prediction.isFallback, isFalse);
        expect(prediction.source, 'jev');
        expect(prediction.scores['food'], 0.94);
      });
    });

    group('Jev API 障害時の完全 Fail-Open', () {
      test('500 エラー時でも例外を投げずローカルルールへ退避すること', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        final jevClient = JevClient(
          apiKey: 'test_key_live_123',
          httpClient: mockClient,
        );
        final service = JevInstantClassifierService(
          client: jevClient,
          isEnabled: true,
        );

        final prediction = await service.predictCategory('ドトールコーヒー');
        expect(prediction.categoryId, 'cafe_snack');
        expect(prediction.isFallback, isTrue);
        expect(prediction.source, 'local_rule');
      });

      test('通信タイムアウト時でもローカルルールへ即座に退避すること', () async {
        final mockClient = MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response('OK', 200);
        });

        final jevClient = JevClient(
          apiKey: 'test_key_live_123',
          timeout: const Duration(milliseconds: 10), // 極小タイムアウト
          httpClient: mockClient,
        );
        final service = JevInstantClassifierService(
          client: jevClient,
          isEnabled: true,
        );

        final prediction = await service.predictCategory('ファミリーマート');
        expect(prediction.categoryId, 'convenience');
        expect(prediction.isFallback, isTrue);
        expect(prediction.source, 'local_rule');
      });
    });

    test('ExpenseCategoryPrediction のシリアライズ検証', () {
      const prediction = ExpenseCategoryPrediction(
        categoryId: 'transport',
        categoryLabel: '交通費',
        confidence: 0.92,
        isFallback: false,
        source: 'jev',
        latencyMs: 51,
        scores: <String, double>{'transport': 0.92},
      );

      final json = prediction.toJson();
      expect(json['category_id'], 'transport');
      expect(json['confidence'], 0.92);
      expect(json['latency_ms'], 51);
      expect(json['source'], 'jev');
      expect(prediction.toString(), contains('92.0%'));
    });
  });
}
