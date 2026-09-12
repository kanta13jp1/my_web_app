import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/models/asset_interest_history.dart';
import 'package:my_web_app/services/asset_interest_repository.dart';
import '../main_test.mocks.dart';

void main() {
  test('server roundtrip scopes owner and key; stale revision cannot overwrite', () async {
    Map<String, dynamic>? stored;
    final requests = <http.Request>[];
    final transport = SupabaseClient('https://example.supabase.co', 'test-key',
      accessToken: () async => 'user-a-jwt', httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          if (stored != null) return http.Response('{"code":"23505","message":"duplicate"}', 409);
          stored = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          return http.Response('', 201);
        }
        if (request.method == 'PATCH') {
          if (request.url.queryParameters['updated_at'] != 'eq.${stored!['updated_at']}') {
            return http.Response('[]', 200, headers: {'content-type': 'application/json'});
          }
          stored = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          return http.Response(jsonEncode([{'pref_key': stored!['pref_key']}]), 200,
            headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode(stored == null ? [] : [stored]), 200,
          headers: {'content-type': 'application/json'});
      }));
    addTearDown(transport.dispose);
    final client = MockSupabaseClient();
    final auth = MockGoTrueClient();
    when(client.auth).thenReturn(auth);
    when(auth.currentUser).thenReturn(User(id: 'user-a', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: '2026-01-01'));
    when(client.from('asset_pref_mirror')).thenAnswer((_) => transport.from('asset_pref_mirror'));
    final repository = SupabaseAssetInterestRepository(client, 'user-a');
    final record = AssetInterestMonth(month: '2026-08', amounts: {'A': 100}, complete: true, evidence: 'statement');
    await repository.save(record);
    final restored = (await repository.load()).single;
    expect(restored.toJson(), record.toJson());
    expect(restored.revision, isNotNull);
    await expectLater(repository.save(record), throwsA(isA<PostgrestException>()));
    await expectLater(repository.save(AssetInterestMonth(month: record.month, amounts: {'A': 1}, complete: true, evidence: 'statement', revision: 'stale')), throwsStateError);
    expect((await repository.load()).single.total, 100);
    await repository.save(AssetInterestMonth(month: record.month, amounts: {'A': 80}, complete: true, evidence: 'statement', revision: restored.revision));
    expect((await repository.load()).single.total, 80);
    for (final request in requests) {
      expect(request.url.path, '/rest/v1/asset_pref_mirror');
      expect(request.headers['authorization'], 'Bearer user-a-jwt');
      if (request.method != 'POST') expect(request.url.queryParameters['user_id'], 'eq.user-a');
      if (request.method == 'GET') expect(request.url.queryParameters['pref_key'], r'like.interest\_paid\_v1\_%');
    }
    when(auth.currentUser).thenReturn(null);
    final count = requests.length;
    await expectLater(repository.load(), throwsStateError);
    await expectLater(repository.save(record), throwsStateError);
    expect(requests.length, count);
  });
}
