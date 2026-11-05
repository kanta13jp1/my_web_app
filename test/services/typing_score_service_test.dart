import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/models/typing_game.dart';
import 'package:my_web_app/services/typing_score_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String session(String owner) => jsonEncode({
      'access_token': 'header.payload.signature',
      'refresh_token': 'refresh-fixture',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': owner,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
        'created_at': '2026-11-05T00:00:00Z',
      },
    });

void main() {
  http.Response response(String body) => http.Response(
        body,
        200,
        headers: {'content-type': 'application/json'},
      );
  TypingRunReport report() {
    final game = TypingGame()..start();
    game.type(game.guide[0]);
    game.updateElapsed(TypingGame.duration);
    return TypingRunReport.fromGame(game);
  }

  test('report snapshots one finished run with a stable retry ID', () {
    final game = TypingGame()..start();
    expect(() => TypingRunReport.fromGame(game), throwsStateError);
    game.type(game.guide[0]);
    game.updateElapsed(TypingGame.duration);
    final saved = TypingRunReport.fromGame(game);
    final json = saved.toJson();
    game.start();
    expect(saved.toJson(), json);
    expect(json['correct'], 1);
    expect(json.keys, isNot(contains('score')));
    expect(json.keys, isNot(contains('owner_id')));
    expect(saved.id, isNot(report().id));
  });

  test(
      'RPC saves privately, reloads through a fresh client and publishes separately',
      () async {
    final calls = <Map<String, dynamic>>[];
    final records = <Map<String, dynamic>>[];
    final transport = MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/typing_game_records');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      calls.add(body);
      final data = Map<String, dynamic>.from(body['p_data'] as Map);
      if (body['p_action'] == 'save') {
        records.add(
          {...data, 'score': (data['correct'] as int) * 10, 'alias': null},
        );
        return response('{"saved":true}');
      }
      if (body['p_action'] == 'mine') {
        return response(jsonEncode(records));
      }
      return response('{}');
    });
    Future<SupabaseClient> client() async {
      final client = SupabaseClient(
        'https://example.invalid',
        'fixture-key',
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await client.auth
          .recoverSession(session('00000000-0000-0000-0000-000000000001'));
      addTearDown(client.dispose);
      return client;
    }

    final store = SupabaseTypingScoreStore(await client());
    final run = report();
    await store.save(run);
    expect(calls.single['p_action'], 'save');
    expect(calls.single['p_data'], run.toJson());
    final restored = SupabaseTypingScoreStore(await client());
    expect((await restored.mine()).single['id'], run.id);
    await restored.publish(run.id, 'TypingFan');
    await restored.withdraw(run.id);
    await restored.delete(run.id);
    expect(
      calls.map((c) => c['p_action']),
      ['save', 'mine', 'publish', 'withdraw', 'delete'],
    );
  });

  test(
      'unauthenticated and changed accounts cannot receive another account result',
      () async {
    var requests = 0;
    late SupabaseClient client;
    client = SupabaseClient(
      'https://example.invalid',
      'fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async {
        requests++;
        await client.auth
            .recoverSession(session('00000000-0000-0000-0000-000000000002'));
        return response('[]');
      }),
    );
    addTearDown(client.dispose);
    final store = SupabaseTypingScoreStore(client);
    await expectLater(store.mine(), throwsStateError);
    expect(requests, 0);
    await client.auth
        .recoverSession(session('00000000-0000-0000-0000-000000000001'));
    await expectLater(store.mine(), throwsStateError);
    expect(requests, 1);
  });
}
