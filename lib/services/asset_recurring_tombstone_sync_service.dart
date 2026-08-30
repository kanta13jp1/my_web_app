import 'package:flutter/foundation.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef AssetRecurringTombstoneRpc = Future<void> Function(
  List<String> additions,
  List<String> removals,
);

/// Serializes recurring-fixed-cost tombstone synchronization application-wide.
///
/// Each scheduled operation loads its own pending snapshot only after the
/// previous RPC has acknowledged its snapshot. This prevents a delayed delete
/// RPC from arriving after a later re-add RPC and restoring the wrong server
/// state.
class AssetRecurringTombstoneSyncService {
  AssetRecurringTombstoneSyncService({
    AssetSyncDirtyKeysStore dirtyKeysStore = const AssetSyncDirtyKeysStore(),
  }) : _dirtyKeysStore = dirtyKeysStore;

  static const String addPrefix = 'add:';
  static const String removePrefix = 'remove:';
  static AssetRecurringTombstoneSyncService _shared =
      AssetRecurringTombstoneSyncService();

  /// App-scoped queue so a replaced page cannot overlap an older page's RPC.
  static AssetRecurringTombstoneSyncService get shared => _shared;

  @visibleForTesting
  static void resetSharedForTest() {
    _shared = AssetRecurringTombstoneSyncService();
  }

  final AssetSyncDirtyKeysStore _dirtyKeysStore;
  Future<void>? _tail;

  static String operation(String id, {required bool deleted}) =>
      '${deleted ? addPrefix : removePrefix}$id';

  static Set<String> operationIds(Set<String> operations, String prefix) =>
      <String>{
        for (final operation in operations)
          if (operation.startsWith(prefix) && operation.length > prefix.length)
            operation.substring(prefix.length),
      };

  Future<void> queue(
    String prefKey,
    String id, {
    required bool deleted,
    required SharedPreferences prefs,
  }) {
    return _dirtyKeysStore.updateDirty(
      prefKey,
      addKeys: <String>[operation(id, deleted: deleted)],
      removeKeys: <String>[operation(id, deleted: !deleted)],
      prefs: prefs,
    );
  }

  /// Runs snapshot -> RPC -> exact-snapshot acknowledgement in FIFO order.
  Future<bool> sync({
    required String prefKey,
    required SharedPreferences prefs,
    required AssetRecurringTombstoneRpc rpc,
    Future<void> Function()? afterSync,
  }) {
    return runSerialized(
      () => syncNow(
        prefKey: prefKey,
        prefs: prefs,
        rpc: rpc,
        afterSync: afterSync,
      ),
    );
  }

  /// Adds [operation] to the same application-wide FIFO as tombstone RPCs.
  Future<T> runSerialized<T>(Future<T> Function() operation) {
    final scheduled = (_tail ?? Future<void>.value()).then(
      (_) => operation(),
    );
    _tail = scheduled.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return scheduled;
  }

  /// Executes one sync while the caller already owns [runSerialized].
  Future<bool> syncNow({
    required String prefKey,
    required SharedPreferences prefs,
    required AssetRecurringTombstoneRpc rpc,
    required Future<void> Function()? afterSync,
  }) async {
    try {
      final pending = await _dirtyKeysStore.loadDirty(
        prefKey,
        prefs: prefs,
      );
      final additions = operationIds(pending, addPrefix);
      final removals = operationIds(pending, removePrefix);
      if (additions.isEmpty && removals.isEmpty) return true;

      final sortedAdditions = additions.toList(growable: false)..sort();
      final sortedRemovals = removals.toList(growable: false)..sort();
      await rpc(sortedAdditions, sortedRemovals);
      if (afterSync != null) {
        await afterSync();
      }
      await _dirtyKeysStore.updateDirty(
        prefKey,
        removeKeys: <String>[
          for (final id in additions) operation(id, deleted: true),
          for (final id in removals) operation(id, deleted: false),
        ],
        prefs: prefs,
      );
      return true;
    } catch (error) {
      debugPrint('recurring fixed cost tombstone mirror upsert failed: $error');
      return false;
    }
  }
}
