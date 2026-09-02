import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260817151738_create_asset_chat_tables.sql';

void main() {
  group('asset chat schema migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('defines normalized thread and message records', () {
      final thread = _createTableBlock(sql, 'asset_chat_threads');
      final message = _createTableBlock(sql, 'asset_chat_messages');

      expect(thread, contains('id uuid primary key default gen_random_uuid()'));
      expect(
        thread,
        contains(
          'user_id uuid not null references auth.users(id) on delete cascade',
        ),
      );
      expect(thread, contains('title text not null'));
      expect(
        thread,
        contains('last_message_at timestamptz not null default now()'),
      );

      expect(
        message,
        contains('id uuid primary key default gen_random_uuid()'),
      );
      expect(
        message,
        contains('references public.asset_chat_threads(id) on delete cascade'),
      );
      expect(message, contains('role text not null'));
      expect(message, contains('content text not null'));
      expect(message, contains('tokens_in integer not null default 0'));
      expect(message, contains('tokens_out integer not null default 0'));
      expect(message, contains('model text'));
    });

    test('guards role, content size, timestamps, and token counts', () {
      expect(sql, contains("check (role in ('user', 'assistant'))"));
      expect(
        sql,
        contains('check (length(btrim(content)) between 1 and 50000)'),
      );
      expect(sql, contains('check (tokens_in >= 0)'));
      expect(sql, contains('check (tokens_out >= 0)'));
      expect(sql, contains('check (last_message_at >= created_at)'));
    });

    test('indexes bounded thread and ordered message reads', () {
      expect(sql, contains('asset_chat_threads_user_activity_idx'));
      expect(
        sql,
        contains(
          'on public.asset_chat_threads (\n'
          '    user_id,\n'
          '    last_message_at desc,\n'
          '    id\n'
          '  )',
        ),
      );
      expect(sql, contains('asset_chat_messages_thread_created_idx'));
      expect(
        sql,
        contains('on public.asset_chat_messages (thread_id, created_at, id)'),
      );
    });

    test('removes public grants and exposes only authenticated CRUD', () {
      expect(
        sql,
        contains(
          'revoke all privileges on table\n'
          '  public.asset_chat_threads,\n'
          '  public.asset_chat_messages\n'
          'from public, anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'grant select, insert, update, delete on table\n'
          '  public.asset_chat_threads,\n'
          '  public.asset_chat_messages\n'
          'to authenticated;',
        ),
      );
      expect(sql, isNot(contains('to anon;')));
    });

    test('enforces owner-only RLS on threads and parent-owned messages', () {
      for (final table in ['asset_chat_threads', 'asset_chat_messages']) {
        expect(
          sql,
          contains('alter table public.$table enable row level security;'),
        );
        for (final operation in ['select', 'insert', 'update', 'delete']) {
          expect(sql, contains('create policy ${table}_${operation}_own'));
          expect(sql, contains('for $operation\n  to authenticated'));
        }
      }

      expect(sql, contains('using ((select auth.uid()) = user_id)'));
      expect(sql, contains('with check ((select auth.uid()) = user_id)'));
      expect(
        RegExp(
          r'thread_row\.user_id = \(select auth\.uid\(\)\)',
        ).allMatches(sql).length,
        greaterThanOrEqualTo(5),
      );
    });
  });
}

String _createTableBlock(String sql, String table) {
  final start = sql.indexOf('create table if not exists public.$table');
  expect(start, isNonNegative, reason: 'missing create table for $table');

  final end = sql.indexOf('\n);', start);
  expect(
    end,
    isNonNegative,
    reason: 'missing create table terminator for $table',
  );

  return sql.substring(start, end);
}
