import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AssetSyncDirtyKeysStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    Future<SharedPreferences> prefs() => SharedPreferences.getInstance();
    const store = AssetSyncDirtyKeysStore();

    test('markDirty records per domain and loadDirty reads back', () async {
      final sp = await prefs();
      await store.markDirty('domA', 'k1', prefs: sp);
      await store.markDirty('domA', 'k2', prefs: sp);
      await store.markDirty('domB', 'x', prefs: sp);
      await store.markDirty('domA', '', prefs: sp); // 空は無視

      expect(await store.loadDirty('domA', prefs: sp), <String>{'k1', 'k2'});
      expect(await store.loadDirty('domB', prefs: sp), <String>{'x'});
      expect(await store.loadDirty('none', prefs: sp), isEmpty);
    });

    test('clearDomain removes only that domain', () async {
      final sp = await prefs();
      await store.markDirty('domA', 'k1', prefs: sp);
      await store.markDirty('domB', 'x', prefs: sp);

      await store.clearDomain('domA', prefs: sp);

      expect(await store.loadDirty('domA', prefs: sp), isEmpty);
      expect(await store.loadDirty('domB', prefs: sp), <String>{'x'});
    });

    test('updateDirty atomically replaces opposing operation keys', () async {
      final sp = await prefs();
      await store.markDirty('tombstones', 'add:item', prefs: sp);

      await store.updateDirty(
        'tombstones',
        addKeys: const <String>['remove:item'],
        removeKeys: const <String>['add:item'],
        prefs: sp,
      );

      expect(
        await store.loadDirty('tombstones', prefs: sp),
        <String>{'remove:item'},
      );
      await store.updateDirty(
        'tombstones',
        removeKeys: const <String>['remove:item'],
        prefs: sp,
      );
      expect(await store.loadDirty('tombstones', prefs: sp), isEmpty);
    });

    test('tolerates malformed json', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetSyncDirtyKeysStore.prefsKey: 'not json',
      });
      final sp = await prefs();
      expect(await store.loadDirty('domA', prefs: sp), isEmpty);
    });

    test('serializes concurrent writes without losing marks', () async {
      final sp = await prefs();
      // 各編集サイトと同様に await を挟まず並行発火する。直列化ロックが無いと
      // read-modify-write が交錯し一部のマークを取りこぼす (review medium)。
      await Future.wait(<Future<void>>[
        store.markDirty('domA', 'a', prefs: sp),
        store.markDirty('domB', 'b', prefs: sp),
        store.markDirty('domC', 'c', prefs: sp),
      ]);
      expect(await store.loadDirty('domA', prefs: sp), <String>{'a'});
      expect(await store.loadDirty('domB', prefs: sp), <String>{'b'});
      expect(await store.loadDirty('domC', prefs: sp), <String>{'c'});
    });

    test('concurrent clearDomain does not drop another domain mark', () async {
      final sp = await prefs();
      await store.markDirty('keep', 'k1', prefs: sp);
      // 別ドメインの clear と keep への mark を並行発火 → keep は失われない。
      await Future.wait(<Future<void>>[
        store.clearDomain('other', prefs: sp),
        store.markDirty('keep', 'k2', prefs: sp),
      ]);
      expect(await store.loadDirty('keep', prefs: sp), <String>{'k1', 'k2'});
    });

    test('resetWriteLockForTest leaves the lock usable for a fresh write',
        () async {
      final sp = await prefs();
      // FakeAsync zone 跨ぎ対策の reset hook。reset 後も write が完了し読み戻せる
      // (= lock を壊さない) ことを担保する。
      AssetSyncDirtyKeysStore.resetWriteLockForTest();
      await store.markDirty('domA', 'k1', prefs: sp);
      expect(await store.loadDirty('domA', prefs: sp), <String>{'k1'});
    });

    test('serialization invariant holds after resetWriteLockForTest', () async {
      final sp = await prefs();
      AssetSyncDirtyKeysStore.resetWriteLockForTest();
      // reset 直後でも並行 unawaited write が交錯せず全マークが残る。
      await Future.wait(<Future<void>>[
        store.markDirty('domA', 'a', prefs: sp),
        store.markDirty('domB', 'b', prefs: sp),
        store.markDirty('domC', 'c', prefs: sp),
      ]);
      expect(await store.loadDirty('domA', prefs: sp), <String>{'a'});
      expect(await store.loadDirty('domB', prefs: sp), <String>{'b'});
      expect(await store.loadDirty('domC', prefs: sp), <String>{'c'});
    });
  });
}
