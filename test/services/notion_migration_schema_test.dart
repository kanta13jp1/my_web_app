import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../routes/app_route_names.dart';

const _migrationPath =
    'supabase/migrations/20260823032746_create_notion_migration_control_plane.sql';
const _retiredAnalyticsRouteMigrationPath =
    'supabase/migrations/20260826233134_remove_retired_app_analytics_route.sql';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      _migrationPath,
    ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
  });

  test('creates owner-scoped batch, item, verification, and capability records',
      () {
    for (final table in const [
      'notion_migration_batches',
      'notion_migration_items',
      'notion_migration_checks',
      'notion_migration_capabilities',
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
    }

    expect(sql, contains('foreign key (batch_id, user_id)'));
    expect(sql, contains('foreign key (item_id, user_id)'));
    expect(sql, contains('with (security_invoker = true)'));
  });

  test('requires all seven verification dimensions before source deletion', () {
    for (final key in const [
      'backup',
      'content',
      'hierarchy',
      'properties',
      'attachments',
      'comments',
      'permissions',
    ]) {
      expect(sql, contains("'$key'"));
    }

    expect(sql, contains('if passed_checks <> 7 then'));
    expect(sql, contains('notion_migration_seven_checks_required'));
    expect(sql, contains('notion_migration_invalid_item_transition'));
    expect(sql, contains('notion_migration_destination_evidence_required'));
    expect(
      sql,
      contains('notion_migration_verification_timestamp_required'),
    );
    expect(
      sql,
      contains('notion_migration_deletion_authorization_required'),
    );
    expect(sql, contains('notion_migration_source_deletion_not_ready'));
    expect(sql, contains("old.status <> 'ready_for_source_deletion'"));
  });

  test('keeps hard delete and trigger execution away from clients', () {
    expect(
      sql,
      isNot(
        contains(
          'grant select, insert, update, delete on table '
          'public.notion_migration_items\n  to authenticated',
        ),
      ),
    );
    expect(
      sql,
      contains(
        'revoke execute on function public.'
        'notion_migration_guard_item_status()\n  from public, anon, authenticated;',
      ),
    );
    expect(sql, contains('security invoker'));
    expect(sql, isNot(contains('security definer')));
  });

  test('does not allow an empty or partially deleted batch to complete', () {
    expect(sql, contains('notion_migration_batch_items_incomplete'));
    expect(
      sql,
      contains("item.status <> 'source_deleted'"),
    );
  });

  test('seeds the full parity registry and requires every capability', () {
    for (final key in const [
      'page_tree_blocks',
      'rich_text_embeds',
      'page_history_trash',
      'wiki_verified_pages',
      'database_data_sources',
      'database_properties_relations_formulas',
      'table_list_gallery_views',
      'board_calendar_timeline_views',
      'chart_dashboard_map_feed_views',
      'projects_tasks_sprints',
      'templates',
      'forms',
      'comments_mentions_notifications',
      'realtime_collaboration_presence',
      'sharing_permissions_guests_teamspaces',
      'search_backlinks',
      'files_media',
      'import_export_backup',
      'offline_mobile',
      'automations_buttons_webhooks',
      'integrations_api_mcp',
      'public_sites_domains_seo',
      'ai_writing_database',
      'ai_agent_search_research',
      'meeting_notes_transcription',
      'analytics_audit_sso_scim',
      'calendar_mail_connections',
    ]) {
      expect(sql, contains("'$key'"));
    }

    expect(sql, contains('notion_migration_seed_capabilities'));
    expect(sql, contains('notion_migration_capabilities_incomplete'));
    expect(sql, contains("capability.status <> 'verified'"));
    expect(
      sql,
      contains('create view public.notion_migration_capability_progress'),
    );
  });

  test('maps every seeded capability route to a registered site route', () {
    final seedStart = sql.indexOf('notion_migration_seed_capabilities');
    final guardStart = sql.indexOf(
      'notion_migration_guard_item_status',
      seedStart,
    );
    expect(seedStart, greaterThanOrEqualTo(0));
    expect(guardStart, greaterThan(seedStart));

    final seedSql = sql.substring(seedStart, guardStart);
    final routes = RegExp(
      r"'/[^']+'",
    ).allMatches(seedSql).map(
          (match) => match.group(0)!.substring(1, match.group(0)!.length - 1),
        );

    expect(routes, isNotEmpty);
    for (final route in routes) {
      expect(
        kAllAppRoutes,
        contains(route),
        reason: '$route must be registered before it can be parity evidence',
      );
    }
  });

  test('removes the retired analytics route from parity evidence', () {
    final retirementSql = File(
      _retiredAnalyticsRouteMigrationPath,
    ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();

    expect(
      retirementSql,
      contains(
        'new.site_routes := array_remove(\n'
        '    new.site_routes,\n'
        "    '/app-analytics-dashboard'\n"
        '  );',
      ),
    );
    expect(
      retirementSql,
      contains(
        'before insert or update of site_routes\n'
        '  on public.notion_migration_capabilities',
      ),
    );
    expect(
      retirementSql,
      contains(
        'revoke execute on function\n'
        '  public.notion_migration_strip_retired_site_routes()\n'
        '  from public, anon, authenticated;',
      ),
    );
    expect(
      retirementSql,
      contains(
        "set site_routes = array_remove(site_routes, '/app-analytics-dashboard')",
      ),
    );
  });

  test('keeps lossless WBS staging owner-readable and service-write-only', () {
    expect(
      sql,
      contains('create table public.notion_migration_wbs_staging'),
    );
    expect(
      sql,
      contains(
        'alter table public.notion_migration_wbs_staging enable row level security;',
      ),
    );
    expect(sql, contains('source_page_id text not null'));
    expect(sql, contains('duplicate_ordinal integer not null'));
    expect(sql, contains('source_payload jsonb not null'));
    expect(sql, contains('unique (batch_id, source_page_id)'));
    expect(
      sql,
      contains(
        'grant select on table public.notion_migration_wbs_staging to authenticated;',
      ),
    );
    expect(
      sql,
      isNot(
        contains(
          'grant select, insert, update on table public.notion_migration_wbs_staging',
        ),
      ),
    );
    expect(
      sql,
      contains('create view public.notion_migration_wbs_stage_progress'),
    );
  });
}
