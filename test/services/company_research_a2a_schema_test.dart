import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260815202000_company_research_a2a_routing.sql';

void main() {
  group('AI Company Builder research and routing schema', () {
    late String sql;

    setUpAll(() {
      sql = File(_migrationPath).readAsStringSync().toLowerCase();
    });

    test('isolates source, chunk, and routing rows by owner and company', () {
      expect(
        sql,
        contains('create table if not exists public.company_research_sources'),
      );
      expect(
        sql,
        contains('create table if not exists public.company_research_chunks'),
      );
      expect(
        sql,
        contains(
          'create table if not exists public.company_runtime_routing_profiles',
        ),
      );
      expect(sql, contains('using ((select auth.uid()) = user_id)'));
      expect(sql, contains('foreign key (source_id, user_id, company_id)'));
    });

    test('keeps writes and hybrid matching service-role only', () {
      expect(
        sql,
        contains(
          'revoke all on public.company_research_sources from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'revoke execute on function public.match_company_research_chunks',
        ),
      );
      expect(sql, contains('to service_role'));
      expect(sql, contains('security definer'));
      expect(sql, contains("set search_path = ''"));
    });

    test('combines full-text and pgvector scores with supporting indexes', () {
      expect(sql, contains('embedding vector(768)'));
      expect(sql, contains('search_vector tsvector generated always'));
      expect(sql, contains('using gin (search_vector)'));
      expect(sql, contains('using ivfflat (embedding vector_cosine_ops)'));
      expect(sql, contains('ranked.lexical_score * 0.45'));
      expect(sql, contains('ranked.vector_score * 0.55'));
      expect(sql, contains('company_vector_cosine_similarity'));
      expect(sql, contains("where extension.extname = 'vector'"));
      expect(sql, contains(r'operator(%1$i.<=>)'));
    });

    test('deduplicates concurrent A2A submissions by owner and message', () {
      expect(sql, contains('agent_tasks_company_a2a_message_uidx'));
      expect(sql, contains("where task_type = 'company_builder_a2a'"));
      expect(sql, contains("(metadata ->> 'company_id')"));
      expect(sql, contains("(metadata ->> 'a2a_message_id')"));
    });
  });
}
