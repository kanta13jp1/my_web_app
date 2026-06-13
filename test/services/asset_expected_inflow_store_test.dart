import 'dart:convert';

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

    test('union-merges only mirror rows that are missing locally', () async {
      final store = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 12, 9, 0),
      );
      final local = await store.add(
        date: DateTime(2026, 6, 1),
        amount: 100,
        label: 'local',
      );

      final added = await store.mergeFromMirrorRows(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': local.single.id,
          'kind': 'one_time',
          'date': '2026-06-01',
          'amount': 100,
          'label': 'local',
        },
        <String, dynamic>{
          'id': 'inflow_remote_new',
          'kind': 'one_time',
          'date': '2026-06-20',
          'amount': 5000,
          'label': '別端末分',
        },
        <String, dynamic>{
          'id': 'rule_remote_new',
          'kind': 'rule',
          'day_of_month': 25,
          'amount': 280000,
          'label': '給料',
        },
      ]);

      expect(added, 2);
      expect(await store.loadAll(), hasLength(2));
      expect((await store.loadRules()).single.id, 'rule_remote_new');

      final secondRun = await store.mergeFromMirrorRows(
        const <Map<String, dynamic>>[],
      );
      expect(secondRun, 0);
    });

    test('records a tombstone on remove and never resurrects it on merge',
        () async {
      final store = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 12, 9, 0),
      );
      final added = await store.add(
        date: DateTime(2026, 6, 20),
        amount: 5000,
        label: '消す予定',
      );
      final removedId = added.single.id;
      await store.remove(removedId);

      expect(await store.loadDeletedIds(), contains(removedId));

      // サーバにまだ残っている削除済み行を統合しても復活しない。
      final mergedCount =
          await store.mergeFromMirrorRows(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': removedId,
          'kind': 'one_time',
          'date': '2026-06-20',
          'amount': 5000,
          'label': '消す予定',
        },
        <String, dynamic>{
          'id': 'inflow_fresh',
          'kind': 'one_time',
          'date': '2026-06-22',
          'amount': 1200,
          'label': '新規分',
        },
      ]);

      expect(mergedCount, 1);
      final items = await store.loadAll();
      expect(items.single.id, 'inflow_fresh');
      expect(items.map((e) => e.id), isNot(contains(removedId)));
    });

    test('tombstoned ids are excluded from empty-store restore too', () async {
      final store = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 12, 9, 0),
      );
      final added = await store.add(
        date: DateTime(2026, 6, 20),
        amount: 5000,
        label: '消す',
      );
      final removedId = added.single.id;
      await store.remove(removedId);
      // ローカルは空に戻った状態。
      expect(await store.loadAll(), isEmpty);

      final restored = await store.restoreFromMirrorRows(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': removedId,
          'kind': 'one_time',
          'date': '2026-06-20',
          'amount': 5000,
          'label': '消す',
        },
        <String, dynamic>{
          'id': 'inflow_keep',
          'kind': 'one_time',
          'date': '2026-06-21',
          'amount': 800,
          'label': '残す',
        },
      ]);

      expect(restored, isTrue);
      final items = await store.loadAll();
      expect(items.single.id, 'inflow_keep');
    });

    test(
        'applyRemoteDeletedIds removes matching local items and adds tombstones',
        () async {
      final store = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 12, 9, 0),
      );
      final added = await store.add(
        date: DateTime(2026, 6, 20),
        amount: 5000,
        label: '他端末で削除',
      );
      final id = added.single.id;

      final removed = await store.applyRemoteDeletedIds(<String>[id, '']);

      expect(removed, 1);
      expect(await store.loadAll(), isEmpty);
      expect(await store.loadDeletedIds(), contains(id));

      // 二度目は対象が無いので 0。
      expect(await store.applyRemoteDeletedIds(<String>[id]), 0);
    });

    test('previewMergeAdditions count matches mergeFromMirrorRows result',
        () async {
      final store = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 12, 9, 0),
      );
      final local = await store.add(
        date: DateTime(2026, 6, 1),
        amount: 100,
        label: 'local',
      );
      final removed = await store.add(
        date: DateTime(2026, 6, 2),
        amount: 200,
        label: 'will-delete',
      );
      final removedId = removed.firstWhere((e) => e.label == 'will-delete').id;
      await store.remove(removedId);

      final rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': local.first.id,
          'kind': 'one_time',
          'date': '2026-06-01',
          'amount': 100,
          'label': 'local',
        },
        <String, dynamic>{
          'id': removedId,
          'kind': 'one_time',
          'date': '2026-06-02',
          'amount': 200,
          'label': 'will-delete',
        },
        <String, dynamic>{
          'id': 'inflow_new',
          'kind': 'one_time',
          'date': '2026-06-20',
          'amount': 5000,
          'label': '新規',
        },
        <String, dynamic>{
          'id': 'rule_new',
          'kind': 'rule',
          'day_of_month': 25,
          'amount': 280000,
          'label': '給料',
        },
      ];

      final preview = await store.previewMergeAdditions(rows);
      // 既知(local)とトゥームストーン(will-delete)を除いた2件だけ。
      expect(
        preview.map((row) => row['id']),
        <String>['inflow_new', 'rule_new'],
      );

      final added = await store.mergeFromMirrorRows(rows);
      expect(added, preview.length);
    });

    test('expired tombstones are garbage-collected after the TTL', () async {
      var clock = DateTime(2026, 1, 1, 9);
      final store = AssetExpectedInflowStore(nowProvider: () => clock);
      final added = await store.add(
        date: DateTime(2026, 1, 5),
        amount: 5000,
        label: '消す',
      );
      final id = added.single.id;
      await store.remove(id);
      expect(await store.loadDeletedIds(), contains(id));

      // TTL (365日) を超えると GC され、復活し得る状態に戻る。
      clock = DateTime(2027, 1, 5, 9);
      expect(await store.loadDeletedIds(), isNot(contains(id)));

      final mergedBack = await store.mergeFromMirrorRows(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': id,
          'kind': 'one_time',
          'date': '2026-01-05',
          'amount': 5000,
          'label': '消す',
        },
      ]);
      expect(mergedBack, 1);
    });

    test('tombstones are capped to the most recent entries', () async {
      // 上限 (1000) を超える削除済み ID を直接シードし、GC で新しい順に
      // 残ることを確認する (古い id0 は破棄)。
      final seeded = <Map<String, String>>[
        for (var i = 0; i < 1005; i++)
          <String, String>{
            'id': 'tomb_$i',
            'at': DateTime(2026, 6, 13, 9).toUtc().toIso8601String(),
          },
      ];
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflow_deleted_ids_v1': jsonEncode(seeded),
      });
      final store = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 13, 9),
      );

      final ids = await store.loadDeletedIds();
      expect(ids, hasLength(1000));
      expect(ids, isNot(contains('tomb_0')));
      expect(ids, contains('tomb_1004'));
    });

    test('legacy plain-string tombstones remain effective', () async {
      // part 285 の旧形式 (["id",...]) を読み込めること。
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflow_deleted_ids_v1':
            jsonEncode(<String>['legacy_id']),
      });
      final store = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 13, 9),
      );

      expect(await store.loadDeletedIds(), contains('legacy_id'));
      final added = await store.mergeFromMirrorRows(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'legacy_id',
          'kind': 'one_time',
          'date': '2026-06-01',
          'amount': 100,
          'label': '旧削除',
        },
      ]);
      expect(added, 0);
    });

    test('encode/decode deleted-ids mirror round-trips', () {
      final mirror = AssetExpectedInflowStore.encodeDeletedIdsMirror(
        <String>['a', '', 'b'],
      );
      expect(mirror, <String, dynamic>{
        'ids': <String>['a', 'b'],
      });
      expect(
        AssetExpectedInflowStore.decodeDeletedIdsMirror(mirror),
        <String>['a', 'b'],
      );
      // 不正な形は空に倒す。
      expect(
        AssetExpectedInflowStore.decodeDeletedIdsMirror('nope'),
        isEmpty,
      );
      expect(
        AssetExpectedInflowStore.decodeDeletedIdsMirror(
          <String, dynamic>{'ids': 'x'},
        ),
        isEmpty,
      );
    });

    test('remote gc config tightens the cap and TTL', () async {
      var clock = DateTime(2026, 1, 1, 9);
      final store = AssetExpectedInflowStore(
        nowProvider: () => clock,
        gcConfig: const AssetTombstoneGcConfig(maxCount: 2, maxAgeDays: 10),
      );

      // 3件削除 → 上限2で古い1件が破棄される。
      // クロックを毎回進めて id 衝突 (同一 microsecond) を避ける。
      for (var i = 0; i < 3; i++) {
        clock = DateTime(2026, 1, 1, 9, 0, i);
        final added = await store.add(
          date: DateTime(2026, 1, 2 + i),
          amount: 1000.0 + i,
          label: 'x$i',
        );
        await store.remove(added.firstWhere((e) => e.label == 'x$i').id);
      }
      final ids = await store.loadDeletedIds();
      expect(ids, hasLength(2));

      // TTL=10日を超えると全て失効。
      clock = DateTime(2026, 2, 1, 9);
      expect(await store.loadDeletedIds(), isEmpty);
    });

    test('AssetTombstoneGcConfig.fromMirrorValue parses and clamps', () {
      const fallback = AssetTombstoneGcConfig();
      expect(
        AssetTombstoneGcConfig.fromMirrorValue(null).maxCount,
        fallback.maxCount,
      );

      final parsed = AssetTombstoneGcConfig.fromMirrorValue(
        <String, dynamic>{'max_count': 50, 'max_age_days': 30},
      );
      expect(parsed.maxCount, 50);
      expect(parsed.maxAgeDays, 30);

      // 0 以下は最小1へクランプ。
      final clamped = AssetTombstoneGcConfig.fromMirrorValue(
        <String, dynamic>{'max_count': 0, 'max_age_days': -5},
      );
      expect(clamped.maxCount, 1);
      expect(clamped.maxAgeDays, 1);
    });

    test('loadGcConfig/saveGcConfig round-trips local config', () async {
      expect(
        (await AssetExpectedInflowStore.loadGcConfig()).maxCount,
        const AssetTombstoneGcConfig().maxCount,
      );

      await AssetExpectedInflowStore.saveGcConfig(
        const AssetTombstoneGcConfig(maxCount: 42, maxAgeDays: 90),
      );
      final loaded = await AssetExpectedInflowStore.loadGcConfig();
      expect(loaded.maxCount, 42);
      expect(loaded.maxAgeDays, 90);
      expect(
        const AssetTombstoneGcConfig(maxCount: 42, maxAgeDays: 90)
            .toMirrorValue(),
        <String, dynamic>{'max_count': 42, 'max_age_days': 90},
      );
    });

    test('pruneDeletedIds removes expired tombstones and returns count',
        () async {
      var clock = DateTime(2026, 1, 1, 9);
      final store = AssetExpectedInflowStore(
        nowProvider: () => clock,
        gcConfig: const AssetTombstoneGcConfig(maxAgeDays: 10),
      );
      final added = await store.add(
        date: DateTime(2026, 1, 5),
        amount: 5000,
        label: '消す',
      );
      await store.remove(added.single.id);
      expect(await store.pruneDeletedIds(), 0); // 期限内

      clock = DateTime(2026, 2, 1, 9); // TTL 超過
      expect(await store.pruneDeletedIds(), 1);
      expect(await store.loadDeletedIds(), isEmpty);
    });

    test('aggregated inflow mirror build/parse round-trips', () {
      final value = AssetExpectedInflowStore.buildAggregatedInflowMirrorValue(
        deletedIds: <String>['a', '', 'b'],
        gcConfig: const AssetTombstoneGcConfig(maxCount: 50, maxAgeDays: 90),
      );
      expect(value['deleted_ids'], <String, dynamic>{
        'ids': <String>['a', 'b'],
      });
      expect(value['gc'], <String, dynamic>{
        'max_count': 50,
        'max_age_days': 90,
      });

      expect(
        AssetExpectedInflowStore.aggregatedInflowDeletedIds(value),
        <String>['a', 'b'],
      );
      final gc = AssetExpectedInflowStore.aggregatedInflowGcConfig(value);
      expect(gc.maxCount, 50);
      expect(gc.maxAgeDays, 90);

      // 不正値は安全側 (空 / 既定)。
      expect(
        AssetExpectedInflowStore.aggregatedInflowDeletedIds('nope'),
        isEmpty,
      );
      expect(
        AssetExpectedInflowStore.aggregatedInflowGcConfig(null).maxCount,
        const AssetTombstoneGcConfig().maxCount,
      );
    });
  });
}
