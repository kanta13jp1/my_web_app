import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
  });

  test('serializes delayed delete then re-add through snapshot and ack',
      () async {
    const prefKey = 'recurring_fixed_costs_deleted';
    final prefs = await SharedPreferences.getInstance();
    final deleteService = AssetRecurringTombstoneSyncService.shared;
    final readdService = AssetRecurringTombstoneSyncService.shared;
    expect(identical(deleteService, readdService), isTrue);
    final firstRpcStarted = Completer<void>();
    final releaseFirstRpc = Completer<void>();
    final serverIds = <String>{};
    var rpcCalls = 0;

    Future<void> fakeRpc(
      List<String> additions,
      List<String> removals,
    ) async {
      rpcCalls += 1;
      if (rpcCalls == 1) {
        firstRpcStarted.complete();
        await releaseFirstRpc.future;
      }
      serverIds.addAll(additions);
      serverIds.removeAll(removals);
    }

    await deleteService.queue(
      prefKey,
      'sub_xbox',
      deleted: true,
      prefs: prefs,
    );
    final deleteSync = deleteService.sync(
      prefKey: prefKey,
      prefs: prefs,
      rpc: fakeRpc,
    );
    await firstRpcStarted.future;

    await readdService.queue(
      prefKey,
      'sub_xbox',
      deleted: false,
      prefs: prefs,
    );
    final readdSync = readdService.sync(
      prefKey: prefKey,
      prefs: prefs,
      rpc: fakeRpc,
    );
    await Future<void>.delayed(Duration.zero);
    expect(rpcCalls, 1, reason: 'the re-add RPC must wait for delete ack');

    releaseFirstRpc.complete();
    expect(await deleteSync, isTrue);
    expect(await readdSync, isTrue);

    expect(rpcCalls, 2);
    expect(serverIds, isNot(contains('sub_xbox')));
    expect(
      await const AssetSyncDirtyKeysStore().loadDirty(
        prefKey,
        prefs: prefs,
      ),
      isEmpty,
    );
  });

  test('a failed RPC keeps dirty state and does not poison the queue',
      () async {
    const prefKey = 'recurring_fixed_costs_deleted';
    final prefs = await SharedPreferences.getInstance();
    final service = AssetRecurringTombstoneSyncService();
    var attempts = 0;

    await service.queue(
      prefKey,
      'sub_retry',
      deleted: true,
      prefs: prefs,
    );
    final failed = await service.sync(
      prefKey: prefKey,
      prefs: prefs,
      rpc: (_, __) async {
        attempts += 1;
        throw StateError('offline');
      },
    );
    expect(failed, isFalse);
    expect(
      await const AssetSyncDirtyKeysStore().loadDirty(
        prefKey,
        prefs: prefs,
      ),
      contains('add:sub_retry'),
    );

    final serverIds = <String>{};
    final retried = await service.sync(
      prefKey: prefKey,
      prefs: prefs,
      rpc: (additions, removals) async {
        attempts += 1;
        serverIds.addAll(additions);
        serverIds.removeAll(removals);
      },
    );
    expect(retried, isTrue);
    expect(attempts, 2);
    expect(serverIds, contains('sub_retry'));
    expect(
      await const AssetSyncDirtyKeysStore().loadDirty(
        prefKey,
        prefs: prefs,
      ),
      isEmpty,
    );
  });

  test('a failed current-mirror step keeps tombstone work retryable', () async {
    const prefKey = 'recurring_fixed_costs_deleted';
    final prefs = await SharedPreferences.getInstance();
    final service = AssetRecurringTombstoneSyncService();
    var rpcCalls = 0;
    var currentMirrorCalls = 0;

    await service.queue(
      prefKey,
      'sub_current_retry',
      deleted: false,
      prefs: prefs,
    );
    final failed = await service.sync(
      prefKey: prefKey,
      prefs: prefs,
      rpc: (_, __) async {
        rpcCalls += 1;
      },
      afterSync: () async {
        currentMirrorCalls += 1;
        throw StateError('current mirror offline');
      },
    );
    expect(failed, isFalse);
    expect(
      await const AssetSyncDirtyKeysStore().loadDirty(
        prefKey,
        prefs: prefs,
      ),
      contains('remove:sub_current_retry'),
    );

    final retried = await service.sync(
      prefKey: prefKey,
      prefs: prefs,
      rpc: (_, __) async {
        rpcCalls += 1;
      },
      afterSync: () async {
        currentMirrorCalls += 1;
      },
    );
    expect(retried, isTrue);
    expect(rpcCalls, 2);
    expect(currentMirrorCalls, 2);
    expect(
      await const AssetSyncDirtyKeysStore().loadDirty(
        prefKey,
        prefs: prefs,
      ),
      isEmpty,
    );
  });
}
