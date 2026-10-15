import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_sync_status.dart';
import 'package:my_web_app/services/asset_sync_verification.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/services/mirror_tombstone_store.dart';

void main() {
  test('same-value tombstone add/remove invalidates an older observation',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const tombstones = MirrorTombstoneStore(storageKey: 'synthetic_deleted');
    final observed = MirrorTombstoneStore.mutationGeneration;
    await tombstones.addId(prefs, 'synthetic');
    await tombstones.removeId(prefs, 'synthetic');
    expect(tombstones.activeIds(prefs), isEmpty);
    final result = currentAssetSyncSources(
      observedOwnerId: 'synthetic-owner',
      currentOwnerId: 'synthetic-owner',
      sources: {AssetSyncDomain.watchlist: AssetSyncSource.synced},
      observedLocalValues: {AssetSyncDomain.watchlist: 'same'},
      currentLocalValues: {AssetSyncDomain.watchlist: 'same'},
      tombstoneObservationStable:
          observed == MirrorTombstoneStore.mutationGeneration,
    );
    expect(result[AssetSyncDomain.watchlist], AssetSyncSource.unverified);
  });

  test('queued dirty work is visible before persistence without changing data',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    final prefs = await SharedPreferences.getInstance();
    const dirty = AssetSyncDirtyKeysStore();
    final initialGeneration = AssetSyncDirtyKeysStore.mutationGeneration;
    final pending = dirty.markDirty('watchlist_entries', 'synthetic', prefs: prefs);
    expect(AssetSyncDirtyKeysStore.hasPendingMutations, isTrue);
    expect(AssetSyncDirtyKeysStore.mutationGeneration,
        greaterThan(initialGeneration));
    expect(
      verifyAssetPreferenceSync(
        loggedIn: true,
        ownerMatches: true,
        hasLocalData: true,
        remoteReadSucceeded: true,
        remoteRowExists: true,
        currentValue: 'same',
        remoteValue: 'same',
        observationStable: !AssetSyncDirtyKeysStore.hasPendingMutations,
      ),
      AssetSyncVerification.unverified,
    );
    await pending;
    expect(AssetSyncDirtyKeysStore.hasPendingMutations, isFalse);
    expect(dirty.readDirtySnapshot(prefs)['watchlist_entries'], {'synthetic'});
  });

  test('same-value edit and clear cannot reuse an older clean observation',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    final prefs = await SharedPreferences.getInstance();
    const dirty = AssetSyncDirtyKeysStore();
    final observedGeneration = AssetSyncDirtyKeysStore.mutationGeneration;
    await dirty.markDirty('watchlist_entries', 'synthetic', prefs: prefs);
    await dirty.clearDomain('watchlist_entries', prefs: prefs);
    expect(dirty.readDirtySnapshot(prefs), isEmpty);
    final result = currentAssetSyncSources(
      observedOwnerId: 'synthetic-owner',
      currentOwnerId: 'synthetic-owner',
      sources: {AssetSyncDomain.watchlist: AssetSyncSource.synced},
      observedLocalValues: {AssetSyncDomain.watchlist: 'same'},
      currentLocalValues: {AssetSyncDomain.watchlist: 'same'},
      observationStable: observedGeneration ==
              AssetSyncDirtyKeysStore.mutationGeneration &&
          !AssetSyncDirtyKeysStore.hasPendingMutations,
    );
    expect(result[AssetSyncDomain.watchlist], AssetSyncSource.unverified);
  });

  test('another owner cannot inherit verified saving evidence', () {
    final result = currentAssetSyncSources(
      observedOwnerId: 'synthetic-owner-a',
      currentOwnerId: 'synthetic-owner-b',
      sources: {AssetSyncDomain.mainAccount: AssetSyncSource.synced},
      observedLocalValues: {AssetSyncDomain.mainAccount: 'a'},
      currentLocalValues: {AssetSyncDomain.mainAccount: 'a'},
    );
    expect(result, isEmpty);
    expect(
      AssetSyncStatusSummary(loggedIn: true, sources: result).level,
      AssetSyncLevel.unverified,
    );
  });

  test('local change invalidates saved evidence before the next read returns',
      () {
    final result = currentAssetSyncSources(
      observedOwnerId: 'synthetic-owner',
      currentOwnerId: 'synthetic-owner',
      sources: {AssetSyncDomain.mainAccount: AssetSyncSource.synced},
      observedLocalValues: {AssetSyncDomain.mainAccount: 'old'},
      currentLocalValues: {AssetSyncDomain.mainAccount: 'edited'},
    );
    expect(result[AssetSyncDomain.mainAccount], AssetSyncSource.localOnly);
  });

  test('new data cannot retain a previously empty domain status', () {
    final result = currentAssetSyncSources(
      observedOwnerId: 'synthetic-owner',
      currentOwnerId: 'synthetic-owner',
      sources: {AssetSyncDomain.watchlist: AssetSyncSource.empty},
      observedLocalValues: {AssetSyncDomain.watchlist: <String>[]},
      currentLocalValues: {
        AssetSyncDomain.watchlist: ['synthetic-entry'],
      },
    );
    expect(result[AssetSyncDomain.watchlist], AssetSyncSource.localOnly);
  });

  AssetSyncVerification verify({
    bool owner = true,
    bool dirty = false,
    bool deleted = false,
    bool read = true,
    bool exists = true,
    bool local = true,
    Object? current = 'B',
    Object? remote = 'A',
  }) =>
      verifyAssetPreferenceSync(
        loggedIn: true,
        ownerMatches: owner,
        hasLocalData: local,
        remoteReadSucceeded: read,
        remoteRowExists: exists,
        currentValue: current,
        remoteValue: remote,
        hasDirtyKeys: dirty,
        hasPendingDeletion: deleted,
      );
  test('existing old remote row is not current payload acknowledgement', () {
    expect(verify(), AssetSyncVerification.localOnly);
    expect(verify(dirty: true), AssetSyncVerification.localOnly);
  });
  test('matching current payload verifies only without pending changes', () {
    expect(verify(current: 'A'), AssetSyncVerification.synced);
    expect(verify(current: 'A', dirty: true), AssetSyncVerification.localOnly);
  });
  test('pending deletion is not empty or synced', () {
    expect(
      verify(local: false, current: null, remote: null, deleted: true),
      AssetSyncVerification.localOnly,
    );
  });
  test('failed read or changed owner cannot prove remote state', () {
    expect(verify(read: false, current: 'A'), AssetSyncVerification.unverified);
    expect(
      verify(owner: false, current: 'A'),
      AssetSyncVerification.unverified,
    );
  });
  test('absent remote and empty local differs from unread remote', () {
    expect(verify(local: false, exists: false), AssetSyncVerification.empty);
    expect(verify(local: false, read: false), AssetSyncVerification.unverified);
  });
  test('remote only row is not acknowledgement of a restored local value', () {
    expect(
      verify(local: false, current: null),
      AssetSyncVerification.unverified,
    );
  });
  test('comparison respects JSON semantic boundaries', () {
    expect(
      assetSyncPayloadsEqual(
        {
          'a': 1,
          'b': [true, null],
        },
        {
          'b': [true, null],
          'a': 1.0,
        },
      ),
      isTrue,
    );
    expect(assetSyncPayloadsEqual([1, 2], [2, 1]), isFalse);
    expect(assetSyncPayloadsEqual({'a': null}, {}), isFalse);
    expect(assetSyncPayloadsEqual(double.infinity, double.infinity), isFalse);
    expect(assetSyncPayloadsEqual(DateTime(2026), DateTime(2026)), isFalse);
  });
}
