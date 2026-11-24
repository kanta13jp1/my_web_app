import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/growth_mission_service.dart';

const _cronMigrationPath =
    'supabase/migrations/20261123031500_schedule_site_statistics_pg_cron.sql';
const _servicePath = 'lib/services/growth_mission_service.dart';

void main() {
  group('site statistics pg_cron migration (#4081)', () {
    late final String sql;
    late final String serviceSource;

    setUpAll(() {
      sql = File(_cronMigrationPath)
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .toLowerCase();
      serviceSource =
          File(_servicePath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('revokes client execute and grants only service_role', () {
      expect(
        sql,
        contains(
          'revoke all on function public.update_site_statistics() '
          'from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.update_site_statistics() '
          'to service_role',
        ),
      );
    });

    test('schedules update_site_statistics via pg_cron every 15 minutes', () {
      expect(sql, contains('create extension if not exists pg_cron'));
      expect(sql, contains("where jobname = 'site_statistics_15m'"));
      expect(sql, contains("cron.schedule(\n    'site_statistics_15m'"));
      expect(sql, contains("'*/15 * * * *'"));
      expect(sql, contains('select public.update_site_statistics();'));
    });

    test('removes browser-initiated maintenance RPC calls from client',
        () async {
      expect(serviceSource, isNot(contains("rpc('update_site_statistics')")));
      expect(serviceSource, isNot(contains("rpc('cleanup_old_presence')")));

      await expectLater(
        const GrowthMissionService().refreshAggregateMetrics(force: true),
        completes,
      );
    });
  });
}
