import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('process quality metrics are user-scoped and append-only', () {
    final sql = File(
      'supabase/migrations/20260903044000_create_process_quality_metrics.sql',
    ).readAsStringSync();

    expect(sql, contains('generated always as'));
    expect(sql, contains('review_density numeric'));
    expect(sql, contains('finding_density numeric'));
    expect(sql, contains('needs_attention boolean'));
    expect(sql, contains('enable row level security'));
    expect(sql, contains('grant select, insert'));
    expect(sql, isNot(contains('grant update')));
    expect(sql, isNot(contains('grant delete')));
    expect(sql, contains('using ((select auth.uid()) = user_id)'));
    expect(sql, contains('with check ((select auth.uid()) = user_id)'));
  });
}
