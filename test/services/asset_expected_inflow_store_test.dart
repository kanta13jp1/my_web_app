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
  });
}
