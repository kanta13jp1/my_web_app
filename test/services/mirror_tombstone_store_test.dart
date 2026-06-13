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
  });
}
