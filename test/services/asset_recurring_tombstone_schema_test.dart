import 'dart:io';

import 'package:test/test.dart';

const _migrationPath =
    'supabase/migrations/20260828164000_atomic_recurring_fixed_cost_tombstones.sql';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(_migrationPath).readAsStringSync().toLowerCase();
  });

  test('uses an authenticated fixed-key RPC and guards direct writes', () {
    expect(
      sql,
      contains(
        'create or replace function public.apply_recurring_fixed_cost_tombstones',
      ),
    );
    expect(sql, contains('security definer'));
    expect(sql, contains('v_user_id uuid := auth.uid()'));
    expect(sql, contains("'recurring_fixed_costs_deleted'"));
    expect(sql, isNot(contains('p_pref_key')));
    expect(
      sql,
      contains(
        'grant execute on function public.apply_recurring_fixed_cost_tombstones(text[], text[])\n'
        '  to authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function public.apply_recurring_fixed_cost_tombstones(text[], text[])\n'
        '  from anon',
      ),
    );
    expect(
      sql,
      contains('create trigger guard_recurring_fixed_cost_tombstone_writes'),
    );
    expect(
      sql,
      contains("current_setting('app.recurring_tombstone_rpc', true)"),
    );
    expect(sql, contains('security invoker'));
    expect(sql, contains('before insert or update or delete'));
    expect(sql, contains("old.pref_key = 'recurring_fixed_costs_deleted'"));
    expect(sql, contains("new.pref_key = 'recurring_fixed_costs_deleted'"));
    expect(sql, contains('current_user is distinct from v_rpc_owner'));
    expect(sql, contains("if tg_op = 'delete' then"));
  });

  test('atomically unions current and incoming IDs before explicit removal',
      () {
    expect(sql, contains('on conflict (user_id, pref_key) do update'));
    expect(sql, contains("jsonb_typeof(mirror.value -> 'ids') = 'array'"));
    expect(sql, contains("jsonb_typeof(excluded.value -> 'ids') = 'array'"));
    expect(sql, contains('select distinct btrim(source.id) as id'));
    expect(sql, contains('coalesce(p_remove_ids, array[]::text[])'));
    expect(sql, contains('and not exists'));
    expect(sql, contains('where removed.id is not null'));
    expect(
      sql,
      contains(
        "jsonb_typeof(v_existing -> 'ids') is distinct from 'array'",
      ),
    );
    expect(sql, contains('pg_catalog.jsonb_array_elements'));
    expect(
      sql,
      contains("jsonb_typeof(element.value) is distinct from 'string'"),
    );
    expect(sql, contains('v_previous_guard text'));
    expect(
      RegExp(
        r"coalesce\s*\(\s*v_previous_guard,\s*''\s*\)",
        caseSensitive: false,
        multiLine: true,
      ).allMatches(sql).length,
      greaterThanOrEqualTo(2),
    );
    expect(sql, contains('returning mirror.value into v_value'));
  });

  test('Flutter calls the RPC instead of replacing the tombstone blob', () {
    final source = File(
      'lib/pages/asset_management_page.dart',
    ).readAsStringSync();
    expect(
      RegExp(
        r"\.rpc\(\s*'apply_recurring_fixed_cost_tombstones'\s*,\s*params\s*:",
      ).hasMatch(source),
      isTrue,
    );

    final method = source
        .split('Future<bool> _mirrorRecurringFixedCostsDeleted({')[1]
        .split('Future<void> _pullRecurringFixedCostDeleted()')[0];
    expect(method, isNot(contains(".from('asset_pref_mirror').upsert")));
    expect(method, contains('_recurringTombstoneSyncService.sync'));

    final syncService = File(
      'lib/services/asset_recurring_tombstone_sync_service.dart',
    ).readAsStringSync();
    expect(syncService, contains('(_tail ?? Future<void>.value()).then'));
    expect(syncService, contains('_dirtyKeysStore.loadDirty'));
    expect(syncService, contains('_dirtyKeysStore.updateDirty'));
    expect(syncService, contains('await afterSync()'));
  });
}
