import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_expected_inflow_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AssetExpectedInflowStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('adds inflows sorted by date with sane defaults', () async {
      final store = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 12, 9, 0),
      );

      await store.add(date: DateTime(2026, 6, 25), amount: 280000, label: '給料');
      final entries = await store.add(
        date: DateTime(2026, 6, 10, 23, 59),
        amount: 5000,
        label: '   ',
      );

      expect(entries, hasLength(2));
      expect(entries.first.date, DateTime(2026, 6, 10));
      expect(entries.first.label, '入金予定');
      expect(entries.last.amount, 280000);

      final reloaded = await store.loadAll();
      expect(reloaded, hasLength(2));
    });

    test('removes an inflow by id', () async {
      final store = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 12, 9, 0),
      );
      final entries = await store.add(
        date: DateTime(2026, 6, 25),
        amount: 1000,
        label: '副収入',
      );

      final remaining = await store.remove(entries.single.id);

      expect(remaining, isEmpty);
      expect(await store.loadAll(), isEmpty);
    });

    test('filters inflows to a single month', () {
      final inflows = <AssetExpectedInflow>[
        AssetExpectedInflow(
          id: 'a',
          date: DateTime(2026, 6, 25),
          amount: 1,
          label: 'a',
        ),
        AssetExpectedInflow(
          id: 'b',
          date: DateTime(2026, 7, 1),
          amount: 2,
          label: 'b',
        ),
      ];

      final june = AssetExpectedInflowStore.monthInflows(
        inflows,
        DateTime(2026, 6),
      );

      expect(june, hasLength(1));
      expect(june.single.id, 'a');
    });

    test('rejects non-positive amounts and tolerates corrupt storage',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflows_v1': '{bad json',
      });
      final store = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 12, 9, 0),
      );

      expect(await store.loadAll(), isEmpty);
      await expectLater(
        store.add(date: DateTime(2026, 6, 25), amount: 0, label: 'x'),
        throwsArgumentError,
      );
    });

    test('adds and removes monthly recurring rules', () async {
      final store = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 12, 9, 0),
      );

      final rules = await store.addRule(
        dayOfMonth: 25,
        amount: 280000,
        label: '給料',
      );
      expect(rules.single.dayOfMonth, 25);
      expect(await store.loadRules(), hasLength(1));

      final cleared = await store.removeRule(rules.single.id);
      expect(cleared, isEmpty);

      await expectLater(
        store.addRule(dayOfMonth: 0, amount: 100, label: 'x'),
        throwsArgumentError,
      );
    });

    test('materializes rules into a month with end-of-month clamping', () {
      const rule = AssetExpectedInflowRule(
        id: 'r1',
        dayOfMonth: 31,
        amount: 280000,
        label: '給料',
      );
      final oneTime = <AssetExpectedInflow>[
        AssetExpectedInflow(
          id: 'a',
          date: DateTime(2026, 2, 10),
          amount: 5000,
          label: '単発',
        ),
        AssetExpectedInflow(
          id: 'b',
          date: DateTime(2026, 3, 1),
          amount: 9999,
          label: '対象外',
        ),
      ];

      final entries = AssetExpectedInflowStore.materializeMonth(
        oneTime: oneTime,
        rules: const <AssetExpectedInflowRule>[rule],
        month: DateTime(2026, 2),
      );

      expect(entries, hasLength(2));
      expect(entries.first.id, 'a');
      expect(entries.first.sourceRuleId, isNull);
      expect(entries.last.date, DateTime(2026, 2, 28));
      expect(entries.last.sourceRuleId, 'r1');
      expect(entries.last.id, 'rule_r1_202602');
    });

    test('restores mirror rows only into an empty local store', () async {
      const store = AssetExpectedInflowStore();
      final rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'inflow_a',
          'kind': 'one_time',
          'date': '2026-06-20',
          'amount': 5000,
          'label': '振込',
        },
        <String, dynamic>{
          'id': 'rule_b',
          'kind': 'rule',
          'day_of_month': 25,
          'amount': 280000,
          'label': '給料',
        },
        <String, dynamic>{'id': '', 'kind': 'one_time', 'amount': 1},
      ];

      final restored = await store.restoreFromMirrorRows(rows);

      expect(restored, isTrue);
      final items = await store.loadAll();
      final rules = await store.loadRules();
      expect(items.single.id, 'inflow_a');
      expect(items.single.date, DateTime(2026, 6, 20));
      expect(rules.single.dayOfMonth, 25);
    });

    test('refuses mirror restore when local data already exists', () async {
      final store = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 12, 9, 0),
      );
      await store.add(date: DateTime(2026, 6, 1), amount: 100, label: 'x');

      final restored = await store.restoreFromMirrorRows(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'inflow_remote',
          'kind': 'one_time',
          'date': '2026-06-21',
          'amount': 999,
          'label': 'remote',
        },
      ]);

      expect(restored, isFalse);
      final items = await store.loadAll();
      expect(items.single.label, 'x');
    });
  });
}
