import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260822074004_create_artifact_publishing_loop.sql';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      _migrationPath,
    ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
  });

  test('creates the complete provenance, check, run, and event model', () {
    for (final table in const [
      'artifact_candidates',
      'artifact_provenance',
      'artifact_checks',
      'artifact_publication_runs',
      'artifact_publication_events',
    ]) {
      expect(sql, contains('create table public.$table'));
      expect(
        sql,
        contains('alter table public.$table enable row level security;'),
      );
    }
    expect(sql, contains('artifact_sha256 text not null unique'));
    expect(sql, contains('function public.intake_artifact_candidate('));
    expect(sql, contains('on conflict (artifact_sha256) do update'));
    expect(sql, contains('security invoker'));
    expect(sql, contains('created_at timestamptz not null default now()'));
    expect(sql, contains('artifact_candidates_review_queue_idx'));
    expect(sql, contains("where stage not in ('published', 'rejected')"));
    expect(sql, contains('artifact_private_object_exists'));
    expect(sql, contains('from storage.objects as object'));
  });

  test('keeps candidates buyer-private and events append-only', () {
    for (final table in const [
      'artifact_candidates',
      'artifact_provenance',
      'artifact_checks',
      'artifact_publication_runs',
      'artifact_publication_events',
    ]) {
      expect(
        sql,
        contains('revoke all on table public.$table from anon, authenticated;'),
      );
    }
    expect(
      sql,
      isNot(
        contains(
          'grant select on table public.artifact_candidates to anon',
        ),
      ),
    );
    expect(
      sql,
      contains(
        'grant select on table public.artifact_publication_events to authenticated;',
      ),
    );
    expect(
      sql,
      isNot(
        contains(
          'grant insert on table public.artifact_publication_events to authenticated',
        ),
      ),
    );
    expect(sql, contains('public.is_user_admin((select auth.uid()))'));
  });

  test('derives approval, audits transitions, and blocks premature activation',
      () {
    expect(sql, contains('human_admin_approval_required'));
    expect(sql, contains('new.approved_by := actor'));
    expect(sql, contains('invalid_artifact_stage_transition'));
    expect(sql, contains('publication_hard_gates_not_satisfied'));
    expect(sql, contains('artifact_check_wrong_stage'));
    expect(sql, contains('chatgpt_voice_output_standalone_audio_blocked'));
    expect(sql, contains('linked_artifact_product_not_publication_ready'));
    expect(sql, contains('shop_products_artifact_activation_guard'));
    expect(
      sql,
      contains('event_type, from_value, to_value, details, actor_id'),
    );
  });

  test('privileged trigger functions stay private and non-callable', () {
    expect(
      sql,
      isNot(contains('function public.seed_and_audit_artifact_candidate')),
    );
    expect(
      sql,
      isNot(contains('function public.audit_artifact_candidate_transition')),
    );
    expect(
      sql,
      contains(
        'revoke execute on function private.seed_and_audit_artifact_candidate()',
      ),
    );
    expect(sql, contains("security definer\nset search_path = ''"));
    expect(sql, isNot(contains('grant execute on function private.')));
  });
}
