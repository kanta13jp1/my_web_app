import 'dart:io';

import 'package:test/test.dart';

const _migrationPath =
    'supabase/migrations/20260827025642_add_notion_vault_manifest_staging.sql';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      _migrationPath,
    ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
  });

  test('stores manifests separately from Notion source-deletion items', () {
    expect(
      sql,
      contains('create table public.notion_migration_vault_manifests'),
    );
    expect(sql, contains('create table public.notion_migration_vault_entries'));
    expect(sql, isNot(contains('source_kind text')));
    expect(
      sql,
      contains(
        "category text not null check (category in ('note', 'attachment'))",
      ),
    );
    expect(
      sql,
      contains("migration_action in ('auto_stage', 'review_required')"),
    );
    expect(
      sql,
      contains("structure_metadata - array['referenced_by']::text[]"),
    );
    expect(sql, isNot(contains("'body'")));
    expect(sql, isNot(contains("'property_values'")));
    expect(
      sql,
      contains(r"relative_path !~ '(^/|(^|/)\.\.(/|$)|^[a-za-z]:)'"),
    );
  });

  test('enforces manifest counts, digest, and completed staging state', () {
    expect(sql, contains("source_manifest_sha256 ~ '^[0-9a-f]{64}\$'"));
    expect(
      sql,
      contains(
        'check (file_count = auto_stage_count + review_required_count + excluded_count)',
      ),
    );
    expect(
      sql,
      contains(
        'and staged_entry_count = auto_stage_count + review_required_count',
      ),
    );
    expect(sql, contains('unique (batch_id, source_manifest_sha256)'));
    expect(sql, contains('unique (manifest_id, relative_path)'));
  });

  test('binds child rows to the same batch and owner', () {
    expect(
      sql,
      contains(
        'foreign key (batch_id, user_id)\n'
        '    references public.notion_migration_batches(id, user_id)',
      ),
    );
    expect(
      sql,
      contains(
        'foreign key (manifest_id, batch_id, user_id)\n'
        '    references public.notion_migration_vault_manifests(id, batch_id, user_id)',
      ),
    );
  });

  test('RLS exposes owned rows to authenticated users without delete', () {
    for (final table in <String>[
      'notion_migration_vault_manifests',
      'notion_migration_vault_entries',
    ]) {
      expect(
        sql,
        contains('alter table public.$table enable row level security'),
      );
      expect(
        RegExp(
          'create policy ${table}_select_own.*?'
          r'for select to authenticated\s+'
          r'using \(\(select auth\.uid\(\)\) = user_id\)',
          dotAll: true,
        ).hasMatch(sql),
        isTrue,
      );
      expect(
        RegExp('create policy ${table}_delete_own').hasMatch(sql),
        isFalse,
      );
      expect(
        sql,
        contains(
          'grant select, insert, update\n'
          '  on table public.$table to authenticated',
        ),
      );
      expect(sql, isNot(contains('on table public.$table to anon')));
    }
  });
}
