import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260717220000_eval_approval_automation_idempotency.sql';

void main() {
  group('Eval approval automation idempotency migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('uniquely identifies each approved downstream item', () {
      expect(
        sql,
        contains(
          'create unique index if not exists '
          'hub_data_eval_automation_item_unique',
        ),
      );
      expect(sql, contains("(metadata ->> 'user_id')"));
      expect(sql, contains("(metadata ->> 'approval_request_id')"));
      expect(sql, contains("(metadata ->> 'automation_item_key')"));
    });

    test('does not constrain unrelated hub task or calendar rows', () {
      expect(sql, contains("source in ('team_task', 'calendar_event')"));
      expect(sql, contains("metadata ->> 'source' = 'eval_approval'"));
      expect(
        sql,
        contains("coalesce(metadata ->> 'automation_item_key', '') <> ''"),
      );
    });
  });
}
