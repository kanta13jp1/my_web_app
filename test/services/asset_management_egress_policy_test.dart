import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_management_egress_policy.dart';

const _migrationPath =
    'supabase/migrations/20260721183000_bound_asset_management_history_reads.sql';

void main() {
  group('AssetManagementEgressPolicy', () {
    test('uses bounded query windows and result limits', () {
      expect(AssetManagementEgressPolicy.assetHistoryLookbackDays, 400);
      expect(AssetManagementEgressPolicy.queryPageSize, 500);
      expect(AssetManagementEgressPolicy.maxAssetHistoryRows, 10000);
      expect(AssetManagementEgressPolicy.recentFlowMonthWindow, 24);
      expect(AssetManagementEgressPolicy.maxRecentFlowRows, 2000);
      expect(AssetManagementEgressPolicy.maxImportDedupRows, 10000);
      expect(AssetManagementEgressPolicy.maxMonthlySnapshots, 120);
    });

    test('starts the recent-flow window at the first day 23 months ago', () {
      expect(
        AssetManagementEgressPolicy.recentFlowCutoff(
          DateTime.utc(2026, 7, 21, 12),
        ),
        DateTime(2024, 8).toUtc(),
      );
    });

    test('falls back only for missing RPC error codes', () {
      expect(
        AssetManagementEgressPolicy.isMissingAssetHistoryRpcCode('PGRST202'),
        isTrue,
      );
      expect(
        AssetManagementEgressPolicy.isMissingAssetHistoryRpcCode('42883'),
        isTrue,
      );
      expect(
        AssetManagementEgressPolicy.isMissingAssetHistoryRpcCode('PGRST301'),
        isFalse,
      );
    });

    test('reuses the first page and returns every bounded row once', () async {
      final requestedRanges = <(int, int)>[];
      final rows = await AssetManagementEgressPolicy.fetchBoundedPages<int>(
        maxRows: 5,
        pageSize: 2,
        firstPage: const <int>[0, 1],
        fetchPage: (from, to) async {
          requestedRanges.add((from, to));
          return <int>[
            for (var value = from; value <= to && value < 5; value++) value,
          ];
        },
      );

      expect(rows, <int>[0, 1, 2, 3, 4]);
      expect(requestedRanges, <(int, int)>[(2, 3), (4, 5)]);
    });

    test('rejects an overflowing result instead of returning partial data', () {
      expect(
        () => AssetManagementEgressPolicy.fetchBoundedPages<int>(
          maxRows: 3,
          pageSize: 2,
          fetchPage: (from, to) async => <int>[
            for (var value = from; value <= to; value++) value,
          ],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('asset-management bounded history migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('returns only the projected asset columns', () {
      expect(
        sql,
        contains(
          'returns table (\n  id bigint,\n  title text,\n  amount numeric,\n  created_at timestamp with time zone',
        ),
      );
      expect(sql, contains('from public.cfo_assets as asset'));
    });

    test('keeps recent rows and one pre-window anchor per account', () {
      expect(sql, contains('asset.created_at >= cutoff.value'));
      expect(sql, contains('select distinct on (asset.title)'));
      expect(sql, contains('asset.created_at < cutoff.value'));
      expect(sql, contains('union all'));
    });

    test('uses caller permissions and limits execution to signed-in users', () {
      expect(sql, contains('security invoker'));
      expect(sql, contains("set search_path = ''"));
      expect(sql, contains('asset.user_id = auth.uid()'));
      expect(
        sql,
        contains(
          'revoke all on function public.asset_management_recent_cfo_assets(integer)',
        ),
      );
      expect(sql, contains('to authenticated'));
    });
  });
}
