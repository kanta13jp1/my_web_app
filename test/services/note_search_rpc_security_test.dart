import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260731093000_harden_note_search_rpc_scope.sql';

void main() {
  group('note search RPC security migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath)
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .toLowerCase();
    });

    const functionSignatures = <String>[
      'public.sync_note_search_index_text(uuid)',
      'public.upsert_note_search_embedding(integer, real[])',
      'public.search_note_index_hybrid(uuid, text, integer, real[])',
    ];

    test('removes direct execution from client roles', () {
      for (final signature in functionSignatures) {
        expect(
          sql,
          contains(
            'revoke execute on function $signature\n'
            '  from public, anon, authenticated;',
          ),
          reason: '$signature must not accept a caller-supplied user scope',
        );
      }
    });

    test('keeps the authenticated ai-hub service-role boundary', () {
      for (final signature in functionSignatures) {
        expect(
          sql,
          contains(
            'grant execute on function $signature\n'
            '  to service_role;',
          ),
          reason: '$signature must remain callable from ai-hub',
        );
      }
    });
  });
}
