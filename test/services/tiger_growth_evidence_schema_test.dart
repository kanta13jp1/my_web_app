import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260830190000_tiger_growth_evidence_summary.sql';

void main() {
  group('Tiger growth evidence aggregate', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('joins acquisition to D1, D7, D30, and paid outcomes', () {
      expect(sql, contains("event.stage = 'signup_complete'"));
      for (final day in <int>[1, 7, 30]) {
        final unit = day == 1 ? 'day' : 'days';
        expect(sql, contains("interval '$day $unit'"));
        expect(sql, contains("'d${day}eligibleusers'"));
        expect(sql, contains("'d${day}retainedusers'"));
      }
      expect(sql, contains("subscription.tier in ('pro', 'team')"));
      expect(sql, contains("'paidconvertedusers'"));
    });

    test('reports route reach, return use, and paid contribution', () {
      expect(sql, contains('from public.user_feature_usage as usage'));
      expect(sql, contains("'uniqueusers'"));
      expect(sql, contains("'returningusers'"));
      expect(sql, contains("'paidusers'"));
      expect(sql, contains('limit 50'));
    });

    test('keeps the aggregate RPC service-role only', () {
      expect(sql, contains('security invoker'));
      expect(sql, isNot(contains('security definer')));
      expect(sql, contains("set search_path = ''"));
      expect(
        sql,
        contains(
          'revoke all on function public.get_tiger_growth_evidence_summary(integer)\n'
          '  from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.get_tiger_growth_evidence_summary(integer)\n'
          '  to service_role',
        ),
      );
    });

    test('declares an identifier-free response contract', () {
      for (final marker in <String>[
        "'aggregateonly', true",
        "'containsuserids', false",
        "'containsvisitorids', false",
        "'containsemail', false",
        "'containsname', false",
        "'containsprompttext', false",
      ]) {
        expect(sql, contains(marker));
      }
      expect(sql, isNot(contains("'userid',")));
      expect(sql, isNot(contains("'authuserid',")));
      expect(sql, isNot(contains("'visitorid',")));
    });
  });
}
