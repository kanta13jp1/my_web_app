import 'dart:convert';

import 'package:my_web_app/models/asset_external_points.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 外部ポイント記録（京王ポイント・Vポイント等）を端末内へ永続化する。
///
/// ローカル (`SharedPreferences`) を一次ストアとし、端末間同期は資産管理ページが
/// `asset_pref_mirror` (`pref_key`: `external_points_v1`) へ 1 行 jsonb で
/// ミラーする (`MIRROR_PREF_SCHEMA.md` 参照)。
/// [encodeMirrorValue] / [decodeMirrorValue] がローカルとミラー双方で使う共通の
/// 往復ロジックで、保存形は `{'version': 1, 'records': [...]}`。
/// 記録された外部ポイント残高やポイント対象金額は純資産・手元現金・月次支出には
/// 合算しない。
class AssetExternalPointsStore {
  static const String mirrorPrefKey = 'external_points_v1';

  final String? ownerId;

  const AssetExternalPointsStore.forOwner(this.ownerId);

  String get storageKey {
    final owner = ownerId?.trim();
    if (owner == null || owner.isEmpty) {
      throw StateError('Sign in required for external points');
    }
    return 'asset_external_points_v1_${Uri.encodeComponent(owner)}';
  }

  Future<bool> hasSavedSetting({SharedPreferences? prefs}) async {
    final key = storageKey;
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(key);
    if (raw == null || raw.isEmpty) {
      return false;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map && decoded['records'] is List;
    } catch (_) {
      return false;
    }
  }

  Future<List<AssetExternalPointRecord>> load({
    SharedPreferences? prefs,
  }) async {
    final key = storageKey;
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(key);
    if (raw == null || raw.isEmpty) {
      return <AssetExternalPointRecord>[];
    }
    try {
      return decodeMirrorValue(jsonDecode(raw));
    } catch (_) {
      return <AssetExternalPointRecord>[];
    }
  }

  Future<void> save(
    List<AssetExternalPointRecord> records, {
    SharedPreferences? prefs,
  }) async {
    final key = storageKey;
    final store = prefs ?? await SharedPreferences.getInstance();
    final encoded = encodeMirrorValue(records);
    if (!await store.setString(key, jsonEncode(encoded))) {
      throw StateError('Could not save external points');
    }
  }

  /// 外部ポイント記録リストを `asset_pref_mirror.value` (jsonb) 形へ変換する。
  static Map<String, dynamic> encodeMirrorValue(
    List<AssetExternalPointRecord> records,
  ) {
    final sorted = sortExternalPointRecords(records);
    return <String, dynamic>{
      'version': 1,
      'records': sorted.map((e) => e.toJson()).toList(),
    };
  }

  /// `asset_pref_mirror` 行から所有者一致を確認した上で外部ポイント記録を復元する。
  /// [owner] が空または `row['user_id'] != owner` なら `null` を返す。
  static List<AssetExternalPointRecord>? decodeOwnedMirrorRow(
    Map<String, dynamic> row,
    String owner,
  ) {
    if (owner.trim().isEmpty || row['user_id'] != owner) {
      return null;
    }
    return decodeMirrorValue(row['value']);
  }

  /// `asset_pref_mirror.value` (jsonb) または保存済み JSON から外部ポイント記録へ
  /// 寛容に復元し、`observedAt` 降順・`id` 昇順へ整列して返す。
  static List<AssetExternalPointRecord> decodeMirrorValue(dynamic value) {
    if (value is! Map) {
      return <AssetExternalPointRecord>[];
    }
    final rawRecords = value['records'];
    if (rawRecords is! List) {
      return <AssetExternalPointRecord>[];
    }
    final parsed = <AssetExternalPointRecord>[];
    for (final entry in rawRecords) {
      final record = AssetExternalPointRecord.fromJson(entry);
      if (record != null) {
        parsed.add(record);
      }
    }
    return sortExternalPointRecords(parsed);
  }
}
