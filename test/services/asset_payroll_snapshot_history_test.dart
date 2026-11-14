import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_history.dart';
import '../main_test.mocks.dart';

User _user(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01',
    );

Map<String, dynamic> _selection() => {
      'id': 1,
      'user_id': 'owner-a',
      'account_id': 'account-a',
      'payroll_month': '2026-10-01',
      'old_observation_id': null,
      'new_observation_id': 'observation-a',
      'reason': '本人確認',
      'changed_at': '2026-10-23T00:00:00Z',
    };

Map<String, dynamic> _observation() => {
      'id': 'observation-a',
      'user_id': 'owner-a',
      'account_id': 'account-a',
      'payroll_month': '2026-10-01',
      'balance_yen': 12345,
      'deposit_date': '2026-10-23',
      'source_note': '本人確認メモ',
    };

void main() {
  for (final scenario in ['scoped read', 'owner changes', 'foreign observation']) {
    test('payroll history transport: $scenario', () async {
      var owner = 'owner-a';
      final requests = <http.Request>[];
      final transport = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        accessToken: () async => 'synthetic-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          final isHistory = request.url.path
              .endsWith('/asset_payroll_balance_selection_history');
          final observation = _observation();
          if (scenario == 'foreign observation') {
            observation['account_id'] = 'account-b';
          }
          if (scenario == 'owner changes') owner = 'owner-b';
          return http.Response(
            jsonEncode([isHistory ? _selection() : observation]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(transport.dispose);
      final client = MockSupabaseClient();
      final auth = MockGoTrueClient();
      when(client.auth).thenReturn(auth);
      when(auth.currentUser).thenAnswer((_) => _user(owner));
      for (final table in [
        'asset_payroll_balance_selection_history',
        'asset_payroll_balance_observations',
      ]) {
        when(client.from(table)).thenAnswer((_) => transport.from(table));
      }
      final reader = SupabasePayrollSnapshotHistoryReader(client, 'owner-a');
      if (scenario == 'scoped read') {
        final page = await reader.read('account-a', DateTime(2026, 10, 23));
        expect(page.entries.single.record.balanceYen, 12345);
        expect(page.hasMore, isFalse);
        expect(requests, hasLength(2));
        expect(requests.first.url.queryParameters['limit'], '51');
        expect(requests.last.url.queryParameters['id'], contains('observation-a'));
      } else {
        await expectLater(
          reader.read('account-a', DateTime(2026, 10)),
          throwsStateError,
        );
        expect(requests, hasLength(scenario == 'owner changes' ? 1 : 2));
      }
      for (final request in requests) {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['user_id'], 'eq.owner-a');
        expect(request.url.queryParameters['account_id'], 'eq.account-a');
        expect(request.url.queryParameters['payroll_month'], 'eq.2026-10-01');
      }
    });
  }
}
