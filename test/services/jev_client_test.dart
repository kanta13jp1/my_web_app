import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/asset_management_ai_provider_router.dart';
import 'package:my_web_app/services/jev_client.dart';

void main() {
  group('JevClient', () {
    const choices = [
      JevChoice(id: 'lightweight', label: 'Lightweight'),
      JevChoice(id: 'performance', label: 'Performance'),
      JevChoice(id: 'premium', label: 'Premium'),
    ];

    test('returns null when API key is not configured (fail-open)', () async {
      final client = JevClient(apiKey: null);
      final result = await client.classify(
        input: 'Hello',
        choices: choices,
      );
      expect(result, isNull);
    });

    test('returns null when empty choices provided', () async {
      final client = JevClient(apiKey: 'ts_live_mock_key');
      final result = await client.classify(
        input: 'Hello',
        choices: const [],
      );
      expect(result, isNull);
    });

    test('parses successful high-confidence response correctly', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.toString(), JevClient.defaultEndpoint);
        expect(request.headers['Authorization'], 'Bearer ts_live_mock_key');
        expect(request.headers['x-api-key'], 'ts_live_mock_key');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['input'], 'Format summary as bullets');
        expect((body['choices'] as List).length, 3);

        return http.Response(
          jsonEncode({
            'best_choice_id': 'lightweight',
            'confidence': 0.98,
            'scores': {
              'lightweight': 0.98,
              'performance': 0.015,
              'premium': 0.005,
            },
            'latency_ms': 310,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = JevClient(
        apiKey: 'ts_live_mock_key',
        httpClient: mockHttp,
      );

      final result = await client.classify(
        input: 'Format summary as bullets',
        choices: choices,
      );

      expect(result, isNotNull);
      expect(result!.bestChoiceId, 'lightweight');
      expect(result.bestChoice?.label, 'Lightweight');
      expect(result.confidence, 0.98);
      expect(result.isHighConfidence, isTrue);
      expect(result.shouldFallbackToHeavyLlm, isFalse);
      expect(result.scores['lightweight'], 0.98);
    });

    test('identifies low-confidence response as fallback recommended',
        () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'best_choice_id': 'premium',
            'confidence': 0.38,
            'scores': {
              'lightweight': 0.30,
              'performance': 0.32,
              'premium': 0.38,
            },
            'latency_ms': 420,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = JevClient(
        apiKey: 'ts_live_mock_key',
        httpClient: mockHttp,
      );

      final result = await client.classify(
        input: 'Ambiguous question about portfolio risk and tax strategy',
        choices: choices,
      );

      expect(result, isNotNull);
      expect(result!.confidence, 0.38);
      expect(result.isHighConfidence, isFalse);
      expect(result.shouldFallbackToHeavyLlm, isTrue);
    });

    test('handles HTTP 500 error gracefully by returning null (fail-open)',
        () async {
      final mockHttp = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final client = JevClient(
        apiKey: 'ts_live_mock_key',
        httpClient: mockHttp,
      );

      final result = await client.classify(
        input: 'Test input',
        choices: choices,
      );

      expect(result, isNull);
    });
  });

  group('AssetManagementAiProviderRouter with Jev', () {
    test('routes to lightweight model first when Jev decides lightweight',
        () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'best_choice_id': 'lightweight',
            'confidence': 0.97,
            'scores': {
              'lightweight': 0.97,
              'performance': 0.02,
              'premium': 0.01,
            },
          }),
          200,
        );
      });

      final jevClient = JevClient(
        apiKey: 'test-key',
        httpClient: mockHttp,
      );

      final router = AssetManagementAiProviderRouter(
        routingEnabled: true,
        jevEnabled: true,
        jevClient: jevClient,
      );

      final decision = await router.routeForWithJev(
        useCase: AssetManagementAiProviderUseCase.summary,
        prompt: 'Give me a brief single-sentence summary of my balance.',
      );

      expect(
          decision.primaryExternalCandidate?.providerId, 'google_flash_lite');
      expect(
          decision.primaryExternalCandidate?.modelId, 'gemini-2.5-flash-lite');
      expect(decision.jevClassification?.isHighConfidence, isTrue);
      expect(decision.reason, contains('jev classified as lightweight'));
    });

    test('falls back to default chain when Jev confidence is low (<= 0.40)',
        () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'best_choice_id': 'lightweight',
            'confidence': 0.35,
            'scores': {
              'lightweight': 0.35,
              'performance': 0.33,
              'premium': 0.32,
            },
          }),
          200,
        );
      });

      final jevClient = JevClient(
        apiKey: 'test-key',
        httpClient: mockHttp,
      );

      final router = AssetManagementAiProviderRouter(
        routingEnabled: true,
        jevEnabled: true,
        jevClient: jevClient,
      );

      final decision = await router.routeForWithJev(
        useCase: AssetManagementAiProviderUseCase.riskExplanation,
        prompt: 'Explain the multi-variable tail risk of my options hedge.',
      );

      // 低確信度の場合はデフォルトチェーンの先頭（Claude Opus 4.7）に安全フォールバック
      expect(decision.primaryExternalCandidate?.providerId, 'anthropic');
      expect(decision.primaryExternalCandidate?.modelId, 'claude-opus-4-7');
      expect(decision.reason, contains('jev fallback'));
    });

    test('falls back safely when Jev is disabled or offline', () async {
      const router = AssetManagementAiProviderRouter(
        routingEnabled: true,
        jevEnabled: false,
      );

      final decision = await router.routeForWithJev(
        useCase: AssetManagementAiProviderUseCase.summary,
        prompt: 'Any prompt',
      );

      expect(decision.primaryExternalCandidate?.providerId, 'anthropic');
      expect(decision.jevClassification, isNull);
    });
  });
}
