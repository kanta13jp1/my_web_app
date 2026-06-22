// fake_async は flutter_test が推移的に提供する (FakeAsync zone の制御に必要)。
// pubspec を触ると release-notes-data チェックを誘発するため direct 宣言せず
// 推移依存を利用する。
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `AssetSyncDirtyKeysStore` の process-wide `static _writeLock` が
/// testWidgets / FakeAsync zone を跨いで orphan 化する罠を **決定的に再現** し、
/// [AssetSyncDirtyKeysStore.resetWriteLockForTest] がそれを解消することを実証する。
///
/// PR #3507 では「未ログイン smoke が write 経路を踏まない」ため dormant な保険
/// として reset hook を入れたが、本テストは実際に orphan を起こして hook の有効性
/// を能動的に証明する (= MirrorTombstoneStore で smoke を赤化させた同型の罠)。
///
/// 再現の鍵: ある zone で write を開始し microtask を flush せずに zone を破棄
/// すると、`_writeLock` はその死んだ zone 由来の未完了 future を指したまま残る。
/// 次の zone の write は `_writeLock.then(...)` でその死んだ future に連結され、
/// 自分の zone をいくら進めても永久に完了しない (hang)。
///
/// 副作用 (setString) を踏まない `clearDomain(<空ドメイン>)` を使うことで、
/// SharedPreferences プラグインの非同期タイミングに依存せず `_loadAll` の
/// microtask だけで write を完了させ、判定を安定させる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = AssetSyncDirtyKeysStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
  });

  tearDown(AssetSyncDirtyKeysStore.resetWriteLockForTest);

  test(
    'static _writeLock orphans a later FakeAsync zone, and reset recovers it',
    () async {
      final sp = await SharedPreferences.getInstance();

      // --- zone A: write を開始するが flush せず _writeLock を pending のまま残す。
      fakeAsync((async) {
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        // clearDomain は _runLocked 経由で action を microtask へ積む。flush
        // しないので _writeLock は zone A 由来の未完了 future のまま zone A 破棄。
        store.clearDomain('domA', prefs: sp);
      });

      // --- zone B (reset 無し): 後続 write は死んだ zone A の future に連結され、
      //     自 zone を進めても完了しない (= orphan)。
      var doneWithoutReset = false;
      fakeAsync((async) {
        store
            .clearDomain('domB', prefs: sp)
            .then((_) => doneWithoutReset = true);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
      });
      expect(
        doneWithoutReset,
        isFalse,
        reason: 'orphan: 破棄済み zone A の future に連結され、後続 zone で永久に hang',
      );

      // --- zone C (reset 有り): lock を現在 zone の完了済み future へ戻すと完了する。
      var doneWithReset = false;
      fakeAsync((async) {
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        store.clearDomain('domC', prefs: sp).then((_) => doneWithReset = true);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
      });
      expect(
        doneWithReset,
        isTrue,
        reason: 'reset が lock を live zone の完了 future へ戻し、hang を解消',
      );
    },
  );
}
