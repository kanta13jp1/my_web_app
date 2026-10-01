import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hedra batch migration keeps history behind the service-role boundary',
      () {
    final sql = File(
      'supabase/migrations/20260903115000_add_hedra_batch_generations.sql',
    ).readAsStringSync();

    expect(sql, contains('batch_generation_id text'));
    expect(sql, contains('user_id uuid references auth.users(id)'));
    expect(sql, contains('batch_size between 1 and 8'));
    expect(sql, contains("batch_results jsonb not null default '[]'::jsonb"));
    expect(sql, contains('from public, anon, authenticated'));
    expect(sql, contains('grant all privileges'));
    expect(sql, contains('to service_role'));
  });
}
