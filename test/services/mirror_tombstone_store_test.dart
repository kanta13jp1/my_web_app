import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/mirror_tombstone_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MirrorTombstoneStore (generic)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

    test('encode/decode mirror round-trips and rejects bad shapes', () {
      final encoded = MirrorTombstoneStore.encodeMirror(<String>['a', '', 'b']);
      expect(encoded, <String, dynamic>{
        'ids': <String>['a', 'b'],
      });
      expect(MirrorTombstoneStore.decodeMirror(encoded), <String>['a', 'b']);
      expect(MirrorTombstoneStore.decodeMirror('nope'), isEmpty);
      expect(
        MirrorTombstoneStore.decodeMirror(<String, dynamic>{'ids': 5}),
        isEmpty,
      );
    });

    test('addId records and activeIds reads back (any key)', () async {
      final store = MirrorTombstoneStore(
        storageKey: 'display_mode_section_deleted_v1',
        nowProvider: () => DateTime(2026, 6, 13, 9),
      );
      final sp = await prefs();
      await store.addId(sp, 'chart');
      await store.addId(sp, 'flow');
      await store.addId(sp, ''); // 空は無視される

      expect(store.activeIds(sp), <String>{'chart', 'flow'});
    });

    test('mergeRemoteIds returns merged set and unions tombstones', () async {
      final store = MirrorTombstoneStore(
        storageKey: 'k',
        nowProvider: () => DateTime(2026, 6, 13, 9),
      );
      final sp = await prefs();
      await store.addId(sp, 'local');

      final merged = await store.mergeRemoteIds(sp, <String>['remote', '']);
      expect(merged, <String>{'remote'});
      expect(store.activeIds(sp), <String>{'local', 'remote'});

      // 空入力は no-op。
      expect(await store.mergeRemoteIds(sp, <String>['']), isEmpty);
    });

    test('GC honors maxCount and maxAgeDays', () async {
      var clock = DateTime(2026, 1, 1, 9);
      final store = MirrorTombstoneStore(
        storageKey: 'k',
        gcConfig: const AssetTombstoneGcConfig(maxCount: 2, maxAgeDays: 10),
        nowProvider: () => clock,
      );
      final sp = await prefs();
      for (var i = 0; i < 3; i++) {
        clock = DateTime(2026, 1, 1, 9, 0, i);
        await store.addId(sp, 'id$i');
      }
      expect(store.activeIds(sp), hasLength(2));
      expect(store.activeIds(sp), isNot(contains('id0')));

      clock = DateTime(2026, 2, 1, 9);
      expect(store.activeIds(sp), isEmpty);
    });

    test('GC keeps the newest by timestamp, not by list position', () async {
      // 上限超過時は「末尾(挿入位置)」ではなく削除時刻('at')の新しい順で残す。
      // 保存順では newer が先・older が後だが、上限1なら newer が残るべき。
      // 旧挙動(tail keep)だと末尾の older を残し、新しい newer を取りこぼした。
      SharedPreferences.setMockInitialValues(<String, Object>{
        'k': jsonEncode(<Map<String, String>>[
          {
            'id': 'newer',
            'at': DateTime(2026, 6, 13, 12).toUtc().toIso8601String(),
          },
          {
            'id': 'older',
            'at': DateTime(2026, 6, 13, 9).toUtc().toIso8601String(),
          },
        ]),
      });
      final store = MirrorTombstoneStore(
        storageKey: 'k',
        gcConfig: const AssetTombstoneGcConfig(maxCount: 1, maxAgeDays: 3650),
        nowProvider: () => DateTime(2026, 6, 14, 9),
      );
      final sp = await prefs();
      expect(store.activeIds(sp), <String>{'newer'});
    });

    test('reads legacy plain-string format', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'k': jsonEncode(<String>['legacy']),
      });
      final store = MirrorTombstoneStore(
        storageKey: 'k',
        nowProvider: () => DateTime(2026, 6, 13, 9),
      );
      final sp = await prefs();
      expect(store.activeIds(sp), contains('legacy'));
    });

    test('removeId clears a tombstone (id reuse)', () async {
      final store = MirrorTombstoneStore(
        storageKey: 'k',
        nowProvider: () => DateTime(2026, 6, 13, 9),
      );
      final sp = await prefs();
      await store.addId(sp, 'chart');
      expect(store.activeIds(sp), contains('chart'));

      await store.removeId(sp, 'chart');
      expect(store.activeIds(sp), isNot(contains('chart')));
    });

    test('prune removes expired entries and returns the count', () async {
      var clock = DateTime(2026, 1, 1, 9);
      final store = MirrorTombstoneStore(
        storageKey: 'k',
        gcConfig: const AssetTombstoneGcConfig(maxAgeDays: 10),
        nowProvider: () => clock,
      );
      final sp = await prefs();
      await store.addId(sp, 'old');
      clock = DateTime(2026, 1, 1, 9, 0, 1);
      await store.addId(sp, 'fresh-ish');

      // 期限内なら掃除ゼロ。
      expect(await store.prune(sp), 0);

      // TTL 超過後は古い 2 件が掃除される。
      clock = DateTime(2026, 1, 20, 9);
      expect(await store.prune(sp), 2);
      expect(store.activeIds(sp), isEmpty);
    });

    test('works as 3rd consumer: debt payment day override key', () async {
      // #part293: 入金/表示設定に続く 3 例目 = 支払日上書き削除トゥームストーン。
      final store = MirrorTombstoneStore(
        storageKey: 'debt_payment_day_override_deleted_v1',
        nowProvider: () => DateTime(2026, 6, 13, 9),
      );
      final sp = await prefs();
      await store.addId(sp, 'debt_row_1');
      expect(store.activeIds(sp), contains('debt_row_1'));

      // 支払日を再設定 → トゥームストーン解除。
      await store.removeId(sp, 'debt_row_1');
      expect(store.activeIds(sp), isNot(contains('debt_row_1')));
    });

    test('concurrent add/remove stays atomic (no lost update)', () async {
      // 不変条件ガード: 各 write は同期 getString 読み→計算→setString 書きで
      // read↔write 間に await が無く、legacy SharedPreferences は setString 時
      // 点で cache を同期更新する。よって await を挟まず並行発火 (= 各削除/編集
      // サイトの unawaited パターン) しても各 RMW は同期区間で原子的に完了し、
      // 先発の効果を後発が踏み潰す lost-update は起きない (= 書き込み直列化ロック
      // 不要)。read↔write 間に await が入る将来の改修や SharedPreferencesAsync
      // (同期 cache 無し) 移行でこの原子性が崩れたら本テストが落ちる。
      final store = MirrorTombstoneStore(
        storageKey: 'revolving_credit_deleted_v1',
        nowProvider: () => DateTime(2026, 6, 19, 9),
      );
      final sp = await prefs();
      await store.addId(sp, 'keep'); // 既存トゥームストーン

      // delete→addId と edit→removeId を別 future で同時発火する
      // (asset_management_page の _recordRevolvingTombstone /
      // _recordWatchlistTombstone と同じ unawaited パターン)。
      await Future.wait(<Future<void>>[
        store.addId(sp, 'rev_a'),
        store.addId(sp, 'rev_b'),
        store.removeId(sp, 'keep'),
      ]);

      // 'keep' は解除され 'rev_a'/'rev_b' は両方残る (= 取りこぼし無し)。
      expect(store.activeIds(sp), <String>{'rev_a', 'rev_b'});
    });

    test('concurrent non-void writes stay atomic and return correct results',
        () async {
      // 非 void 戻り値 (prune=Future<int> / mergeRemoteIds=Future<Set>) も
      // 同じ同期原子性ガード下にある: 並行発火しても取りこぼさず、各呼び出し元へ
      // 正しい結果が返る。3 操作を await を挟まず同時に発火する。
      final store = MirrorTombstoneStore(
        storageKey: 'watchlist_entries_deleted_v1',
        nowProvider: () => DateTime(2026, 6, 19, 9),
      );
      final sp = await prefs();
      await store.addId(sp, 'w_seed');

      final addFuture = store.addId(sp, 'w_new');
      final mergeFuture = store.mergeRemoteIds(sp, <String>['w_remote', '']);
      final pruneFuture = store.prune(sp);
      await addFuture;
      final merged = await mergeFuture;
      final pruned = await pruneFuture;

      expect(merged, <String>{'w_remote'}); // 取り込んだ非空 ID 集合
      expect(pruned, 0); // 期限内・上限内なので掃除ゼロ
      // 全 tombstone が取りこぼされず残る。
      expect(store.activeIds(sp), <String>{'w_seed', 'w_new', 'w_remote'});
    });
  });
}
