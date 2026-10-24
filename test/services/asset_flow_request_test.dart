import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/asset_flow_request.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('marker survives CRUD serialization without leaking to legacy requests',
      () async {
    final requests = <http.Request>[];
    final mock = MockClient((request) async {
      requests.add(request);
      return http.Response(
        '[]',
        request.method == 'POST' ? 201 : 200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    final client = SupabaseClient(
      'http://localhost:9999',
      'synthetic-public-key',
      httpClient: mock,
    );
    addTearDown(client.dispose);
    await AssetFlowRequest.table(client)
        .select('id,action_type,amount')
        .eq('user_id', 'synthetic-owner');
    await AssetFlowRequest.table(client).insert(<String, dynamic>{
      'action_type': 'borrowing',
      'amount': 10000,
      'user_id': 'synthetic-owner',
    });
    await AssetFlowRequest.table(client)
        .update(<String, dynamic>{'action_type': 'conquer'}).eq('id', -1);
    await AssetFlowRequest.table(client).delete().eq('id', -1);
    await client.from('wealth_struggles').select('id').eq('id', -1);

    expect(
      requests.map((request) => request.method),
      <String>['GET', 'POST', 'PATCH', 'DELETE', 'GET'],
    );
    for (final request in requests.take(4)) {
      expect(request.url.path, '/rest/v1/wealth_struggles');
      expect(
        request.headers[AssetFlowRequest.headerName],
        AssetFlowRequest.headerValue,
      );
      expect(request.headers['apikey'], 'synthetic-public-key');
      expect(
        request.headers['authorization'],
        requests.last.headers['authorization'],
      );
    }
    expect(requests.last.headers.containsKey(AssetFlowRequest.headerName),
        isFalse,
    );
    expect(requests.first.url.queryParameters['user_id'], 'eq.synthetic-owner');
    expect(requests[2].url.queryParameters['id'], 'eq.-1');
    expect(requests[3].url.queryParameters['id'], 'eq.-1');
    expect(jsonDecode(requests[1].body), <String, dynamic>{
      'action_type': 'borrowing',
      'amount': 10000,
      'user_id': 'synthetic-owner',
    });
    expect(jsonDecode(requests[2].body), <String, dynamic>{
      'action_type': 'conquer',
    });
  });
}
