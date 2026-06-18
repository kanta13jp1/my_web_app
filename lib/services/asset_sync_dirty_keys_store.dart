import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 集約 pref ドメインごとに「ローカルで編集したがまだサーバへ同期できていない
/// キー」(= dirty キー) を記録する。
///
/// authoritative reads (フラグ `ASSET_MIRROR_READS_AUTHORITATIVE` = ON) の
/// last-write-wins はドメイン全体の `updated_at` を見るため、別キーの更新で
/// ミラーが新しくなると、ローカルで編集した別キーまで巻き添えでサーバ値に
/// 上書きされ得る (#3415)。マージ時にこの dirty キーをローカル優先で保護する
/// ことで、その巻き添え上書き (= 無音のデータ喪失) を防ぐ保守的ガード。
///
/// dirty キーは「ローカル編集サイト」で `markDirty`、ミラーへの全量 upsert が
/// 成功した時点で `clearDomain` する (= 全キーが同期済みになるため)。よって
/// dirty が残るのはオフライン等で同期できなかった編集のみ。
///
/// 注意: 本機能導入より前に保存された既存ローカル値は dirty 記録が無いため、
/// フラグ ON 時の保護対象外 (= 旧来の whole-domain LWW の制限が残る)。これは
/// per-key LWW タイムスタンプ化 (#3415 本改修) で解消予定の dormant な残課題。
class AssetSyncDirtyKeysStore {
  static const String prefsKey = 'asset_sync_dirty_keys_v1';

  const AssetSyncDirtyKeysStore();

  /// 全ての write (markDirty / clearDomain) を直列化する process-wide ロック。
  /// 単一 pref blob への read-modify-write が並行 (= 各サイト unawaited) で
  /// 交錯し、別ドメイン/別キーの dirty マークを取りこぼす lost-update を防ぐ。
  static Future<void> _writeLock = Future<void>.value();

  /// [action] を前の write 完了後に直列実行する。action の結果/例外は戻り値の
  /// future へ伝播するが、ロック鎖は失敗で途切れさせない。
  Future<void> _runLocked(Future<void> Function() action) {
    final run = _writeLock.then((_) => action());
    _writeLock = run.catchError((_) {});
    return run;
  }

  Future<Map<String, Set<String>>> _loadAll(SharedPreferences store) async {
    final raw = store.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return <String, Set<String>>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, Set<String>>{};
      }
      final result = <String, Set<String>>{};
      decoded.forEach((key, value) {
        if (key is String && value is List) {
          result[key] = <String>{
            for (final entry in value)
              if ((entry?.toString() ?? '').isNotEmpty) entry.toString(),
          };
        }
      });
      return result;
    } catch (_) {
      return <String, Set<String>>{};
    }
  }

  Future<void> _writeAll(
    SharedPreferences store,
    Map<String, Set<String>> all,
  ) async {
    all.removeWhere((_, value) => value.isEmpty);
    await store.setString(
      prefsKey,
      jsonEncode(<String, List<String>>{
        for (final entry in all.entries) entry.key: entry.value.toList(),
      }),
    );
  }

  /// [prefKey] ドメインの dirty キー集合を返す (読み取りはロック不要)。
  Future<Set<String>> loadDirty(
    String prefKey, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return (await _loadAll(store))[prefKey] ?? <String>{};
  }

  /// [key] をローカル編集済み (未同期) として記録する。
  Future<void> markDirty(
    String prefKey,
    String key, {
    SharedPreferences? prefs,
  }) {
    if (key.isEmpty) {
      return Future<void>.value();
    }
    return _runLocked(() async {
      final store = prefs ?? await SharedPreferences.getInstance();
      final all = await _loadAll(store);
      (all[prefKey] ??= <String>{}).add(key);
      await _writeAll(store, all);
    });
  }

  /// [prefKey] ドメインの全 dirty キーを消す (= 全量 upsert 成功で同期済み)。
  Future<void> clearDomain(
    String prefKey, {
    SharedPreferences? prefs,
  }) {
    return _runLocked(() async {
      final store = prefs ?? await SharedPreferences.getInstance();
      final all = await _loadAll(store);
      if (all.remove(prefKey) != null) {
        await _writeAll(store, all);
      }
    });
  }
}
