import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/services/asset_must_task_repository.dart';
import '../main_test.mocks.dart';

void main() {
  test('owner scoped roundtrip rejects failure and zero rows before recovery',
      () async {
    final requests = <http.Request>[];
    var fail = false;
    var zero = false;
    var completed = false;
    final transport = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      accessToken: () async => 'synthetic-token',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (fail) {
          return http.Response('{"message":"offline"}', 503,
              headers: {'content-type': 'application/json'},);
        }
        if (request.method == 'PATCH' && !zero) {
          completed = (jsonDecode(request.body) as Map)['is_completed'] == true;
        }
        return http.Response(
            jsonEncode(zero
                ? []
                : [
                    {
                      'id': 'task-a',
                      'user_id': 'user-a',
                      'title': 'Synthetic task',
                      'deadline': '2026-10-25T00:00:00Z',
                      'is_completed': completed,
                    },
                  ],),
            200,
            headers: {'content-type': 'application/json'},);
      }),
    );
    addTearDown(transport.dispose);
    final client = MockSupabaseClient();
    final auth = MockGoTrueClient();
    when(client.auth).thenReturn(auth);
    when(auth.currentUser).thenReturn(const User(
      id: 'user-a',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01',
    ),);
    when(client.from('must_tasks'))
        .thenAnswer((_) => transport.from('must_tasks'));
    final repository = SupabaseAssetMustTaskRepository(client);
    expect((await repository.load()).single['is_completed'], false);
    expect(requests.last.url.queryParameters['user_id'], 'eq.user-a');
    fail = true;
    await expectLater(repository.add('Synthetic task', DateTime(2026, 10, 25)),
        throwsA(isA<Exception>()),);
    await expectLater(
        repository.setCompleted('task-a', true), throwsA(isA<Exception>()),);
    expect(completed, false);
    fail = false;
    zero = true;
    await expectLater(
        repository.setCompleted('task-a', true), throwsStateError,);
    await expectLater(repository.add('Synthetic task', DateTime(2026, 10, 25)),
        throwsStateError,);
    zero = false;
    await repository.add('Synthetic task', DateTime(2026, 10, 25));
    expect((jsonDecode(requests.last.body) as Map)['user_id'], 'user-a');
    await repository.setCompleted('task-a', true);
    expect(requests.last.url.queryParameters['id'], 'eq.task-a');
    expect(requests.last.url.queryParameters['user_id'], 'eq.user-a');
    expect((await repository.load()).single['is_completed'], true);
    when(auth.currentUser).thenReturn(null);
    final count = requests.length;
    await expectLater(repository.load(), throwsStateError,);
    await expectLater(
        repository.setCompleted('task-a', false), throwsStateError,);
    expect(requests.length, count);
  });
}
