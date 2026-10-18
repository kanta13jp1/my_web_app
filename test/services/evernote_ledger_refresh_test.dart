import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/evernote_migration_ledger_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('older refresh cannot publish success, error, or loading completion', () {
    final generation = EvernoteLedgerRefreshGeneration();
    final first = generation.begin('owner-a');
    final second = generation.begin('owner-a');
    expect(generation.isCurrent(first, 'owner-a'), isFalse);
    expect(generation.isCurrent(second, 'owner-a'), isTrue);
    expect(generation.isCurrent(second, 'owner-b'), isFalse);
    expect(generation.isCurrent(second, null), isFalse);
    generation.begin('owner-b');
    expect(generation.isCurrent(second, 'owner-a'), isFalse);
  });

  for (final failedTable in ['evernote_migration_batches', 'evernote_migration_items']) {
    test('snapshot handles early $failedTable failure while other query waits', () async {
      final release = Completer<void>();
      final failureSent = Completer<void>();
      final client = SupabaseClient(
        'https://fixture.invalid',
        'fixture-key',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/$failedTable')) {
            failureSent.complete();
            return http.Response(
              '{"message":"synthetic failure","code":"P0001"}',
              400,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          await release.future;
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final result = expectLater(
        EvernoteMigrationLedgerService(client: client).loadSnapshot(userId: 'owner-a'),
        throwsA(isA<PostgrestException>()),
      );
      await failureSent.future;
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await result;
    });
  }
}
