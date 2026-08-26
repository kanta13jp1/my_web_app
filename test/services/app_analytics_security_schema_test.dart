import 'dart:io';

import 'package:test/test.dart';

const _migrationPath =
    'supabase/migrations/20260827003000_harden_app_analytics_writes.sql';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(_migrationPath).readAsStringSync().toLowerCase();
  });

  test('keeps public reads while denying browser table mutations', () {
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
        'grant select on table public.app_analytics to anon, authenticated',
      ),
    );
    expect(sql, contains('create policy app_analytics_public_read'));
    expect(sql, contains('for select\nto anon, authenticated\nusing (true)'));
  });

  test('exposes only bounded security-definer write RPCs', () {
    for (final functionName in <String>[
      'increment_share_count',
      'increment_app_analytics_source_detail',
    ]) {
      expect(
        sql,
        contains('create or replace function public.$functionName'),
      );
    }

    expect(
      RegExp(
        r'create or replace function public\.increment_share_count\(\).*?'
        r"security definer\s+set search_path = ''",
        dotAll: true,
      ).hasMatch(sql),
      isTrue,
    );
    expect(
      RegExp(
        r'create or replace function '
        r'public\.increment_app_analytics_source_detail\(.*?'
        r"security definer\s+set search_path = ''",
        dotAll: true,
      ).hasMatch(sql),
      isTrue,
    );
    expect(sql, contains('p_share_increment > 1'));
    expect(sql, contains("'public_memo_share'"));
    expect(sql, contains("'touch_public_tracker'"));
    expect(sql, contains("'^touch_comparison_[a-z0-9_-]{1,64}\$'"));
    expect(
      sql,
      contains(
        'revoke all on function '
        'public.increment_app_analytics_source_detail',
      ),
    );
  });

  test('RPC fallback accepts every growth-hub acquisition signal', () {
    final growthHubSignals = File(
      'supabase/functions/growth-hub/acquisition_signals.ts',
    ).readAsStringSync();
    final allowlistBody = RegExp(
      r'const SUPPORTED_ACQUISITION_SIGNALS = new Set\(\[(.*?)\]\);',
      dotAll: true,
    ).firstMatch(growthHubSignals)?.group(1);

    expect(allowlistBody, isNotNull);
    final keys = RegExp(r'"([^"]+)"')
        .allMatches(allowlistBody!)
        .map((match) => match.group(1)!)
        .toSet();
    expect(keys, isNotEmpty);
    for (final key in keys) {
      expect(
        sql,
        contains("'$key'"),
        reason: '$key must remain available to the browser RPC fallback',
      );
    }
  });

  test('Flutter clients no longer mutate app_analytics directly', () {
    final rawMutation = RegExp(
      r"\.from\('app_analytics'\)\s*\.\s*"
      r'(?:insert|upsert|update|delete)\s*\(',
      dotAll: true,
    );

    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in dartFiles) {
      expect(
        rawMutation.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: '${file.path} must use a bounded RPC for analytics writes',
      );
    }

    for (final path in <String>[
      'lib/services/landing_share_service.dart',
      'lib/services/growth_acquisition_service.dart',
      'lib/services/public_memo_service.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('increment_app_analytics_source_detail'),
      );
    }
    expect(
      File('lib/pages/admin_analytics_page.dart').readAsStringSync(),
      isNot(contains('_resetAnalyticsData')),
    );
  });
}
