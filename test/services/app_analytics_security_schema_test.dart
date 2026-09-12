import 'dart:io';

import 'package:test/test.dart';

const _migrationPath =
    'supabase/migrations/20260827003000_harden_app_analytics_writes.sql';
const _launchAllowlistMigrationPath =
    'supabase/migrations/20260903053600_allow_producthunt_hackernews_analytics_signals.sql';

void main() {
  late String sql;
  late String launchAllowlistSql;

  setUpAll(() {
    sql = File(_migrationPath).readAsStringSync().toLowerCase();
    launchAllowlistSql = File(
      _launchAllowlistMigrationPath,
    ).readAsStringSync().toLowerCase();
  });

  test('exposes only aggregate rows and columns to browser roles', () {
    expect(
      sql,
      contains('alter table public.app_analytics enable row level security'),
    );
    expect(
      sql,
      contains(
        'drop policy if exists "allow public access" '
        'on public.app_analytics',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all privileges on table public.app_analytics\n'
        'from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'grant select (\n'
        '  date,\n'
        '  landing_views,\n'
        '  conversions,\n'
        '  share_count,\n'
        '  source_details\n'
        ') on table public.app_analytics to anon, authenticated',
      ),
    );
    expect(sql, contains('create policy app_analytics_public_read'));
    expect(sql, contains('source is null'));
    expect(sql, contains("coalesce(metadata, '{}'::jsonb) = '{}'::jsonb"));
    expect(
      sql,
      contains(
        'revoke all privileges on table '
        'public.app_analytics_event_receipts\n'
        'from public, anon, authenticated',
      ),
    );
  });

  test('browser writes cross an idempotent service-role-only boundary', () {
    expect(
      RegExp(
        r'create or replace function public\.record_app_analytics_event\(.*?'
        r"security definer\s+set search_path = ''",
        dotAll: true,
      ).hasMatch(sql),
      isTrue,
    );
    expect(sql, contains('primary key (event_date, source_key, actor_hash)'));
    expect(sql, contains('on conflict do nothing'));
    expect(sql, contains('get diagnostics v_inserted = row_count'));
    expect(sql, contains('if v_inserted = 0 then'));
    expect(sql, contains('pg_advisory_xact_lock'));
    expect(sql, contains(') >= 32 then'));
    expect(sql, contains("p_actor_hash !~ '^[0-9a-f]{64}\$'"));
    expect(sql, contains('p_share_increment > 1'));
    expect(sql, contains('2147483647'));

    for (final signaturePattern in <String>[
      r'public\.record_app_analytics_event\s*\(\s*text\s*,\s*date\s*,\s*integer\s*,\s*text\s*\)',
      r'public\.increment_share_count\s*\(\s*\)',
      r'public\.increment_app_analytics_source_detail\s*\(\s*text\s*,\s*date\s*,\s*integer\s*\)',
    ]) {
      expect(
        RegExp(
          'revoke\\s+all\\s+on\\s+function\\s+$signaturePattern'
          r'\s+from\s+public\s*,\s*anon\s*,\s*authenticated',
        ).hasMatch(sql),
        isTrue,
        reason: 'browser roles must not execute $signaturePattern',
      );
      expect(
        RegExp(
          'grant\\s+execute\\s+on\\s+function\\s+$signaturePattern'
          r'\s+to\s+service_role',
        ).hasMatch(sql),
        isTrue,
        reason: 'service_role must execute $signaturePattern',
      );
    }
  });

  test('SQL allowlist covers every static Edge analytics signal', () {
    final growthHubSignals = File(
      'supabase/functions/growth-hub/acquisition_signals.ts',
    ).readAsStringSync();
    final allowlistBody = RegExp(
      r'const SUPPORTED_ACQUISITION_SIGNALS = new Set\(\[(.*?)\]\);',
      dotAll: true,
    ).firstMatch(growthHubSignals)?.group(1);

    expect(allowlistBody, isNotNull);
    final keys = RegExp(
      r'"([^"]+)"',
    ).allMatches(allowlistBody!).map((match) => match.group(1)!).toSet();
    expect(keys, isNotEmpty);
    for (final key in keys) {
      expect(
        launchAllowlistSql,
        contains("'$key'"),
        reason: '$key must be allowed by the latest SQL function definition',
      );
    }
  });

  test('launch allowlist preserves the service-role-only function boundary',
      () {
    expect(
      launchAllowlistSql,
      contains(
        'create or replace function '
        'public.is_app_analytics_source_key_allowed',
      ),
    );
    expect(
      launchAllowlistSql,
      contains(
        'revoke all on function '
        'public.is_app_analytics_source_key_allowed(text)\n'
        'from public, anon, authenticated',
      ),
    );
    expect(
      launchAllowlistSql,
      contains(
        'grant execute on function '
        'public.is_app_analytics_source_key_allowed(text)\n'
        'to service_role',
      ),
    );
  });

  test('Landing auth diagnostics stay aligned with the SQL allowlist', () {
    final landingService = File(
      'lib/services/landing_share_service.dart',
    ).readAsStringSync();
    final keys = RegExp(
      r"'(funnel_[a-z0-9_]+)'",
    ).allMatches(landingService).map((match) => match.group(1)!).toSet();

    expect(keys, isNotEmpty);
    for (final key in keys) {
      expect(
        launchAllowlistSql,
        contains("'$key'"),
        reason:
            '$key must remain allowed by the latest SQL function definition',
      );
    }
  });

  test(
    'Flutter clients use Edge and never mutate analytics through PostgREST',
    () {
      final rawMutation = RegExp(
        r"\.from\('app_analytics'\)\s*\.\s*"
        r'(?:insert|upsert|update|delete)\s*\(',
        dotAll: true,
      );
      final directWriteRpc = RegExp(
        r"\.rpc\(\s*'(?:increment_share_count|"
        r"increment_app_analytics_source_detail)'",
      );

      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        expect(
          rawMutation.hasMatch(source),
          isFalse,
          reason: '${file.path} must not mutate app_analytics directly',
        );
        expect(
          directWriteRpc.hasMatch(source),
          isFalse,
          reason: '${file.path} must use the Edge idempotency boundary',
        );
      }

      for (final path in <String>[
        'lib/services/landing_share_service.dart',
        'lib/services/growth_acquisition_service.dart',
        'lib/services/public_memo_service.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains("'action': 'acquisition.signal'"));
      }
      expect(
        File('lib/services/public_memo_service.dart').readAsStringSync(),
        isNot(contains("'action': 'share.track'")),
      );
      expect(
        File('lib/pages/admin_analytics_page.dart').readAsStringSync(),
        isNot(contains('_resetAnalyticsData')),
      );
    },
  );
}
