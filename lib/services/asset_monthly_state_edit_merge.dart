import 'package:flutter/foundation.dart';

import '../models/asset_liability_persistence.dart';
import 'asset_liability_monthly_state_store.dart';

/// Apply only this device's edits, preserving unrelated remote changes.
/// A same-field conflict needs review; do not silently overwrite either copy.
AssetLiabilityMonthlyState mergeAssetMonthlyStateEdits({
  required String monthKey,
  required AssetLiabilityMonthlyState base,
  required AssetLiabilityMonthlyState edited,
  required AssetLiabilityMonthlyState remote,
}) {
  Map<String, Object?> encode(AssetLiabilityMonthlyState state) =>
      AssetLiabilityMonthlyStatePayload.fromState(
        monthKey: monthKey,
        state: state,
      ).toSupabaseJson(userId: '');

  final before = encode(base)..remove('state_updated_at');
  final after = encode(edited)..remove('state_updated_at');
  final current = encode(remote)..remove('state_updated_at');
  final merged = Map<String, Object?>.from(
    _merge(before, after, current) as Map,
  );
  final timestamp = AssetLiabilityMonthlyState.laterUpdatedAt(
    edited.updatedAt,
    remote.updatedAt,
  );
  if (timestamp != null) {
    merged['state_updated_at'] = timestamp.toUtc().toIso8601String();
  }
  return AssetLiabilityMonthlyStatePayload.fromSupabaseJson(merged).toState();
}

const _missing = Object();

bool _equal(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _equal(a[key], b[key]));
  }
  if (a is List && b is List) {
    return listEquals(a, b) ||
        (a.length == b.length &&
            Iterable<int>.generate(a.length).every((i) => _equal(a[i], b[i])));
  }
  return a == b;
}

Object? _merge(Object? base, Object? edited, Object? remote) {
  if (_equal(base, edited)) return remote;
  if (_equal(base, remote) || _equal(edited, remote)) return edited;
  if (base is Map && edited is Map && remote is Map) {
    final result = Map<Object?, Object?>.from(remote);
    for (final key in {...base.keys, ...edited.keys}) {
      final next = _merge(
        base.containsKey(key) ? base[key] : _missing,
        edited.containsKey(key) ? edited[key] : _missing,
        remote.containsKey(key) ? remote[key] : _missing,
      );
      if (identical(next, _missing)) {
        result.remove(key);
      } else {
        result[key] = next;
      }
    }
    return result;
  }
  if (base is List && edited is List && remote is List) {
    if ([...base, ...edited, ...remote].every((v) => v is String)) {
      // Paid/confirmed sets: additions and explicit removals are per account.
      return (<Object?>{...remote, ...edited.where((v) => !base.contains(v))}
            ..removeAll(base.where((v) => !edited.contains(v))))
          .toList();
    }
    if ([...base, ...edited, ...remote]
        .every((v) => v is Map && v['id'] is String)) {
      Map<Object?, Object?> index(List values) => {
            for (final value in values) (value as Map)['id']: value,
          };
      return (_merge(index(base), index(edited), index(remote)) as Map)
          .values
          .toList();
    }
  }
  throw StateError('Monthly state changed on another device; review required');
}
