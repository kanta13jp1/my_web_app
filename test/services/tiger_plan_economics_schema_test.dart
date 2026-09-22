import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260831090000_tiger_plan_economics_summary.sql';

void main() {
  group('Tiger plan economics aggregate', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('groups measured billing and AI usage sources by plan', () {
      expect(sql, contains("values ('pro'::text, 980::integer)"));
      expect(sql, contains("('team'::text, 2980::integer)"));
      expect(
        sql,
        contains('from public.billing_subscriptions as subscription'),
      );
      expect(sql, contains('left join public.ai_usage_log as usage'));
      for (final marker in <String>[
        "'activepaidcustomers'",
        "'listpricemrryen'",
        "'aiusagerows'",
        "'inputtokens'",
        "'outputtokens'",
        "'rawcostestimate'",
      ]) {
        expect(sql, contains(marker));
      }
    });

    test('keeps unsupported decision metrics null and explains gaps', () {
      for (final metric in <String>[
        "'grossmarginrate', null",
        "'customeracquisitioncostyen', null",
        "'paybackmonths', null",
        "'monthlychurnrate', null",
        "'lifetimevalueyen', null",
      ]) {
        expect(sql, contains(metric));
      }
      expect(sql, contains("'missinginputs'"));
      expect(sql, contains('currency and complete ai request coverage'));
      expect(sql, contains('subscription state history'));
      expect(sql, contains('not collected revenue'));
    });

    test('keeps the aggregate RPC service-role only and identifier-free', () {
      expect(sql, contains('security invoker'));
      expect(sql, isNot(contains('security definer')));
      expect(sql, contains("set search_path = ''"));
      expect(sql, contains("'aggregateonly', true"));
      expect(sql, contains("'containsuserids', false"));
      expect(sql, contains("'containscustomerids', false"));
      expect(sql, contains("'containsemail', false"));
      expect(sql, contains("'containsprompttext', false"));
      expect(
        sql,
        contains(
          'grant execute on function public.get_tiger_plan_economics_summary(integer)\n'
          '  to service_role',
        ),
      );
    });
  });
}
