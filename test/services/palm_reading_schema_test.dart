import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('palm history migration is owner scoped and uses a private bucket', () {
    final migration = File(
      'supabase/migrations/20260921041500_create_palm_reading_history.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('alter table public.palm_readings enable row level security'),
    );
    expect(migration, contains('using ((select auth.uid()) = user_id)'));
    expect(migration, contains('\'palm-readings\''));
    expect(migration, contains('false,\n  4194304'));
    expect(
      migration,
      contains('(storage.foldername(name))[1] = (select auth.uid())::text'),
    );
    expect(migration, contains('unique (user_id, request_id)'));
    expect(migration, contains("where feature_route = '/palm-reading'"));
    expect(migration, isNot(contains('grant insert')));
  });
}
