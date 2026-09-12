import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/shop_community_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_shop_community.dart';

SupabaseShopCommunityRepository repositoryWith(
    Future<http.Response> Function(http.Request) respond) {
  final client = SupabaseClient('https://example.supabase.co', 'test-anon-key',
      httpClient: MockClient(respond),
      authOptions: const AuthClientOptions(autoRefreshToken: false));
  addTearDown(client.dispose);
  return SupabaseShopCommunityRepository(client: client);
}

http.Response jsonResponse(Object? body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

void main() {
  test('release request selects only public fields and limits the history', () async {
    final repository = repositoryWith((request) async {
      expect(request.url.path, '/rest/v1/shop_product_releases');
      expect(request.url.queryParameters['product_id'], 'eq.test');
      expect(request.url.queryParameters['limit'], '20');
      expect(request.url.queryParameters['select'], isNot(contains('user_id')));
      return jsonResponse([{'id':'r','version':'1.2','title_ja':'更新',
        'notes_ja':'内容','sha256':null,'published_at':null}]);
    });
    final releases = await repository.releases('test');
    expect(releases.single.version, '1.2');
    expect(releases.single.publishedAt, isNull);
  });
  test('public review RPC includes the keyset cursor without user identifiers', () async {
    final before = FakeShopCommunity.review('cursor');
    final repository = repositoryWith((request) async {
      expect(request.url.path, '/rest/v1/rpc/get_shop_product_reviews');
      expect(jsonDecode(request.body), {
        'p_product_id':'test','p_before_created_at':before.createdAt.toUtc().toIso8601String(),
        'p_before_id':'cursor',
      });
      return jsonResponse({'count':0,'average':null,'items':[]});
    });
    final page = await repository.reviews('test', before: before);
    expect(page.count, 0);
    expect(page.average, isNull);
  });
  test('write uses the invoker RPC and does not send owner, version or moderation flags', () async {
    final repository = repositoryWith((request) async {
      expect(request.url.path, '/rest/v1/rpc/save_shop_product_review');
      expect(jsonDecode(request.body), {'p_product_id':'test','p_rating':4,'p_body':'文章'});
      return http.Response('', 204);
    });
    await repository.saveReview('test', 4, '文章');
  });
  test('delete scopes by product and ID and requires a returned row', () async {
    final repository = repositoryWith((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.queryParameters['product_id'], 'eq.test');
      expect(request.url.queryParameters['id'], 'eq.review');
      return jsonResponse([]);
    });
    await expectLater(repository.deleteReview('test', 'review'), throwsStateError);
  });
  test('logged-out own-review lookup does not call the API', () async {
    final repository = repositoryWith((_) async => throw StateError('unexpected request'));
    expect((await repository.ownReview('test')).canReview, isFalse);
  });
}
