import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20260804100000_add_notes_inbox_capture.sql',
  ).readAsStringSync().toLowerCase();

  test('adds an explicit Inbox lifecycle to existing owner-scoped notes', () {
    expect(sql, contains('add column if not exists capture_status text'));
    expect(sql, contains('add column if not exists capture_source text'));
    expect(
      sql,
      contains('add column if not exists inbox_saved_at timestamptz'),
    );
    expect(sql, contains('alter column capture_status set not null'));
    expect(sql, contains('alter column capture_source set not null'));
    expect(
      sql,
      contains("capture_status in ('inbox', 'organized', 'archived')"),
    );
    expect(sql, contains("where capture_status = 'inbox'"));
  });

  test('does not add privileged RPC or broaden table access', () {
    expect(sql, isNot(contains('security definer')));
    expect(sql, isNot(contains('grant execute')));
    expect(sql, isNot(contains('grant all')));
    expect(sql, isNot(contains('disable row level security')));
  });
}
