import 'asset_sync_status.dart';

/// Discard another owner's evidence and invalidate a previously observed value
/// immediately after a local edit, including while a remote read is pending.
Map<AssetSyncDomain, AssetSyncSource> currentAssetSyncSources({
  required String? observedOwnerId,
  required String? currentOwnerId,
  required Map<AssetSyncDomain, AssetSyncSource> sources,
  required Map<AssetSyncDomain, Object?> observedLocalValues,
  required Map<AssetSyncDomain, Object?> currentLocalValues,
  bool observationStable = true,
  bool tombstoneObservationStable = true,
}) {
  if (observedOwnerId != currentOwnerId) return {};
  if (!observationStable || !tombstoneObservationStable) {
    return {
      for (final domain in sources.keys) domain: AssetSyncSource.unverified,
    };
  }
  return {
    for (final entry in sources.entries)
      entry.key: currentLocalValues.containsKey(entry.key) &&
              !assetSyncPayloadsEqual(
                currentLocalValues[entry.key],
                observedLocalValues[entry.key],
              )
          ? AssetSyncSource.localOnly
          : entry.value,
  };
}

/// Read-only verification of the current preference payload against one
/// successfully observed remote row. No write or retry is performed here.
enum AssetSyncVerification { unverified, empty, localOnly, synced }

AssetSyncVerification verifyAssetPreferenceSync({
  required bool loggedIn,
  required bool ownerMatches,
  required bool hasLocalData,
  required bool remoteReadSucceeded,
  required bool remoteRowExists,
  required Object? currentValue,
  required Object? remoteValue,
  bool hasDirtyKeys = false,
  bool hasPendingDeletion = false,
  bool observationStable = true,
}) {
  if (!ownerMatches || !observationStable) {
    return AssetSyncVerification.unverified;
  }
  if (hasDirtyKeys || hasPendingDeletion) {
    return AssetSyncVerification.localOnly;
  }
  if (!loggedIn) {
    return hasLocalData
        ? AssetSyncVerification.localOnly
        : AssetSyncVerification.empty;
  }
  if (!remoteReadSucceeded) return AssetSyncVerification.unverified;
  if (!remoteRowExists) {
    return hasLocalData
        ? AssetSyncVerification.localOnly
        : AssetSyncVerification.empty;
  }
  if (!assetSyncPayloadsEqual(currentValue, remoteValue)) {
    return hasLocalData
        ? AssetSyncVerification.localOnly
        : AssetSyncVerification.unverified;
  }
  return hasLocalData
      ? AssetSyncVerification.synced
      : AssetSyncVerification.empty;
}

/// JSON object key order is irrelevant; list order and missing/null keys are
/// retained. Numerically equal finite int/double values represent the same JSON
/// number. Non-JSON values never establish a verified state.
bool assetSyncPayloadsEqual(Object? left, Object? right) {
  if (left == null || right == null) return left == null && right == null;
  if (left is num && right is num) {
    return left.isFinite && right.isFinite && left == right;
  }
  if (left is String && right is String) return left == right;
  if (left is bool && right is bool) return left == right;
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!assetSyncPayloadsEqual(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final key in left.keys) {
      if (key is! String ||
          !right.containsKey(key) ||
          !assetSyncPayloadsEqual(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  return false;
}
