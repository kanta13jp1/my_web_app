import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/jev_expense_proxy_client.dart';
import 'package:my_web_app/services/jev_instant_classifier_service.dart';

void main() {
  const choices = JevInstantClassifierService.defaultCategories;
  Map<String, dynamic> response() => {
        'answers': {
          'classification': {
            'type': 'choice',
            'choice': 'food',
            'confidence': 0.9,
            'probabilities': {
              for (final c in choices) c.id: c.id == 'food' ? 1.0 : 0.0,
            },
          },
        },
      };
  test('only authenticated explicit calls send memo through ai-hub', () async {
    var signedIn = false;
    var calls = 0;
    final client = JevExpenseProxyClient(
      signedIn: () => signedIn,
      invoke: (body) async {
        calls++;
        expect(
          body,
          {'action': 'expense.jev_suggest', 'memo': '食材', 'consent': true},
        );
        return response();
      },
    );
    addTearDown(client.dispose);
    expect(await client.classify(input: '食材', choices: choices), isNull);
    expect(calls, 0);
    signedIn = true;
    final result = await client.classify(input: '食材', choices: choices);
    expect(result?.bestChoiceId, 'food');
    expect(calls, 1);
    expect(client.apiKey, isNull);
  });
  test('oversized input and invalid response preserve fallback', () async {
    var calls = 0;
    final client = JevExpenseProxyClient(
      signedIn: () => true,
      invoke: (_) async {
        calls++;
        final data = response();
        ((data['answers'] as Map)['classification'] as Map)['confidence'] = 2;
        return data;
      },
    );
    addTearDown(client.dispose);
    expect(await client.classify(input: 'a' * 501, choices: choices), isNull);
    expect(calls, 0);
    expect(await client.classify(input: '食材', choices: choices), isNull);
    final prediction = await JevInstantClassifierService(client: client)
        .predictCategory('スタバ');
    expect(prediction.source, 'local_rule');
  });
  test('network failure and sign out during response produce no AI result',
      () async {
    var signedIn = true;
    final client = JevExpenseProxyClient(
      signedIn: () => signedIn,
      invoke: (_) async {
        signedIn = false;
        return response();
      },
    );
    addTearDown(client.dispose);
    expect(await client.classify(input: '食材', choices: choices), isNull);
    final failing = JevExpenseProxyClient(
      signedIn: () => true,
      invoke: (_) async => throw Exception('network'),
    );
    addTearDown(failing.dispose);
    expect(await failing.classify(input: '食材', choices: choices), isNull);
  });
}
