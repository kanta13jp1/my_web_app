import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final captureSql = File(
    'supabase/migrations/20260804100000_add_notes_inbox_capture.sql',
  ).readAsStringSync().toLowerCase();
  final classificationSql = File(
    'supabase/migrations/20260903093000_add_notes_ai_classification.sql',
  ).readAsStringSync().toLowerCase();

  test('adds an explicit Inbox lifecycle to existing owner-scoped notes', () {
    expect(
        captureSql, contains('add column if not exists capture_status text'));
    expect(
        captureSql, contains('add column if not exists capture_source text'));
    expect(
      captureSql,
      contains('add column if not exists inbox_saved_at timestamptz'),
    );
    expect(captureSql, contains('alter column capture_status set not null'));
    expect(captureSql, contains('alter column capture_source set not null'));
    expect(
      captureSql,
      contains("capture_status in ('inbox', 'organized', 'archived')"),
    );
    expect(captureSql, contains("where capture_status = 'inbox'"));
  });

  test('adds a constrained background classification lifecycle', () {
    expect(
      classificationSql,
      contains('add column if not exists classification_status text'),
    );
    expect(
      classificationSql,
      contains('add column if not exists classification_category text'),
    );
    expect(
      classificationSql,
      contains('add column if not exists classification_source text'),
    );
    expect(
      classificationSql,
      contains("classification_status in ('pending', 'classified', 'failed')"),
    );
    expect(
      classificationSql,
      contains("where capture_source = 'quick_inbox'"),
    );
  });

  test('does not add privileged RPC or broaden table access', () {
    for (final sql in <String>[captureSql, classificationSql]) {
      expect(sql, isNot(contains('security definer')));
      expect(sql, isNot(contains('grant execute')));
      expect(sql, isNot(contains('grant all')));
      expect(sql, isNot(contains('disable row level security')));
    }
  });
}
