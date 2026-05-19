import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260517093000_extend_ai_hub_provider_choice_reason.sql';

void main() {
  group('ai_hub provider choice reason migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('adds nullable provider routing evidence columns', () {
      expect(
        sql,
        contains('ADD COLUMN IF NOT EXISTS provider_choice_reason text'),
      );
      expect(sql, contains('ADD COLUMN IF NOT EXISTS routing_use_case text'));
      expect(sql, contains('ai_hub_chat_logs_routing_use_case_idx'));
    });

    test('documents the no-PII logging boundary', () {
      expect(sql, contains('must not include PII'));
      expect(sql, contains('raw balances'));
      expect(sql, contains('routing use case'));
    });
  });
}
