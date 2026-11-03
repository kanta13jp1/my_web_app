import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260823181844_create_user_writer_knowledge_graphs.sql';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      _migrationPath,
    ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
  });

  test('creates owner-scoped graph and document metadata tables', () {
    for (final table in const <String>[
      'user_writer_knowledge_graphs',
      'user_writer_knowledge_graph_documents',
    ]) {
      expect(sql, contains('create table public.$table'));
      expect(
        sql,
        contains('alter table public.$table enable row level security;'),
      );
      expect(
        sql,
        contains('revoke all on table public.$table from anon, authenticated;'),
      );
      expect(
        sql,
        contains('grant select on table public.$table to authenticated;'),
      );
    }
    expect(sql, contains('using ((select auth.uid()) = user_id)'));
    expect(sql, contains('on delete cascade'));
  });

  test('keeps client writes and sensitive payloads out of Postgres', () {
    expect(sql, isNot(contains('grant insert')));
    expect(sql, isNot(contains('grant update')));
    expect(sql, isNot(contains('grant delete')));
    expect(sql, isNot(contains('api_key text')));
    expect(sql, isNot(contains('file_content')));
    expect(sql, isNot(contains('file_base64')));
  });

  test('indexes the owner lookup and enforces the shared 4 MB limit', () {
    expect(
      sql,
      contains(
        'user_writer_knowledge_graph_documents (user_id, created_at desc)',
      ),
    );
    expect(sql, contains('size_bytes > 0 and size_bytes <= 4194304'));
    expect(sql, contains('unique (user_id, writer_file_id)'));
  });
}
