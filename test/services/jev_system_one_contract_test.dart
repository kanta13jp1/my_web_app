import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/jev_client.dart';

void main() {
  const choices = [
    JevChoice(id: 'food', label: 'Food', description: 'Meals'),
    JevChoice(id: 'travel', label: 'Travel'),
  ];
  Map<String, dynamic> answer() => {
        'type': 'choice',
        'choice': 'food',
        'probabilities': {'food': 0.75, 'travel': 0.25},
        // Normalized entropy confidence is not the winning probability.
        'confidence': 0.1887,
      };

  test('sends System One questions and reads nested choice answer', () async {
    final transport = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.keys, unorderedEquals(['model', 'state', 'questions']));
      expect(body['model'], 'jev-latest');
      expect(body['state'], 'Lunch');
      expect(body['questions'], {
        'classification': {
          'type': 'choice',
          'instructions': 'Choose an expense category.',
          'criteria': {'food': 'Food: Meals', 'travel': 'Travel'},
        },
      });
      return http.Response(
        jsonEncode({
          'answers': {'classification': answer()},
        }),
        200,
      );
    });
    addTearDown(transport.close);
    final client = JevClient(
      endpoint: JevClient.defaultLocalJevEndpoint,
      httpClient: transport,
    );
    final result = await client.classify(
      input: 'Lunch',
      choices: choices,
      context: 'Choose an expense category.',
    );
    expect(result?.bestChoiceId, 'food');
    expect(result?.confidence, 0.1887);
    expect(result?.scores['food'], 0.75);
    expect(result?.shouldFallbackToHeavyLlm, isTrue);
  });

  for (final invalid in <Map<String, dynamic>>[
    {},
    {...answer(), 'type': 'score'},
    {...answer(), 'choice': 'unknown'},
    {...answer(), 'confidence': 1.5},
    {
      ...answer(),
      'probabilities': {'food': 0.75},
    },
    {
      ...answer(),
      'probabilities': {'food': 0.75, 'unknown': 0.25},
    },
    {
      ...answer(),
      'probabilities': {'food': 0.1, 'travel': 0.1},
    },
  ]) {
    test('rejects invalid answer ${jsonEncode(invalid)}', () async {
      final transport = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'answers': {'classification': invalid},
          }),
          200,
        ),
      );
      addTearDown(transport.close);
      final client = JevClient(
        endpoint: JevClient.defaultLocalJevEndpoint,
        httpClient: transport,
      );
      expect(await client.classify(input: 'Lunch', choices: choices), isNull);
    });
  }

  test('does not bypass authentication for localhost in remote URL', () {
    for (final endpoint in [
      'https://localhost.example.com/v1/systemone',
      'https://example.com/127.0.0.1/v1/systemone',
    ]) {
      final client = JevClient(endpoint: endpoint);
      addTearDown(client.dispose);
      expect(client.isLocalMode, isFalse);
      expect(client.isConfigured, isFalse);
    }
  });

  test('returns null when local inference exceeds configured timeout',
      () async {
    final transport = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return http.Response(
        jsonEncode({
          'answers': {'classification': answer()},
        }),
        200,
      );
    });
    addTearDown(transport.close);
    final client = JevClient(
      endpoint: JevClient.defaultLocalJevEndpoint,
      timeout: const Duration(milliseconds: 1),
      httpClient: transport,
    );
    expect(await client.classify(input: 'Lunch', choices: choices), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 40));
  });
}
