import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  /// 姉妹の MirrorTombstoneStore と異なり本ストアは read↔write 間に
  /// `await _loadAll` を挟む (= RMW が原子的でない) ため、このロックは
  /// production では必須であり撤去できない。
  ///
  /// 🔴 testWidgets での注意 (= FakeAsync zone-orphan): production は単一の
  /// root zone で走るため static でも正しく直列化されるが、`testWidgets` は
  /// 各テストを個別の FakeAsync zone で実行する。あるテスト (zone A) の write が
  /// `_writeLock` に未完了 future を残したまま zone A が破棄されると、次のテスト
  /// (zone B) の `_writeLock.then(...)` は死んだ zone A の future に連結されて
  /// 永久に完了せず hang する (= 単体 pass / 全 suite fail という cross-test
  /// static state の典型症状。MirrorTombstoneStore へ同型ロックを移植した際に
  /// 実証済み)。よって write 経路を踏む widget テストは setUp で
  /// [resetWriteLockForTest] を呼び lock を現在の zone で再初期化すること。
  ///
  /// 現状の資産管理 page smoke は未ログイン (`auth.currentUser == null`) で
  /// mirror upsert が早期 return し write 経路 (markDirty/clearDomain) を踏まない
  /// ため dormant (= 安全) だが、将来ログイン状態の編集 smoke を足す場合に備え
  /// 既に smoke の setUp で reset 済み。
  static Future<void> _writeLock = Future<void>.value();

  /// [_writeLock] を現在の zone の完了済み future に再初期化する (テスト専用)。
  /// FakeAsync zone を跨いだ static future の orphan-hang を防ぐ (上記参照)。
  @visibleForTesting
  static void resetWriteLockForTest() {
    _writeLock = Future<void>.value();
  }

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

  /// [prefKey] の dirty 集合を 1 回のロック区間で差分更新する。
  /// 同じ論理IDの add/remove のように、相反する操作を入れ替える用途で使う。
  Future<void> updateDirty(
    String prefKey, {
    Iterable<String> addKeys = const <String>[],
    Iterable<String> removeKeys = const <String>[],
    SharedPreferences? prefs,
  }) {
    final additions = addKeys.where((key) => key.isNotEmpty).toSet();
    final removals = removeKeys.where((key) => key.isNotEmpty).toSet();
    if (additions.isEmpty && removals.isEmpty) {
      return Future<void>.value();
    }
    return _runLocked(() async {
      final store = prefs ?? await SharedPreferences.getInstance();
      final all = await _loadAll(store);
      final dirty = all[prefKey] ?? <String>{};
      dirty.removeAll(removals);
      dirty.addAll(additions);
      if (dirty.isEmpty) {
        all.remove(prefKey);
      } else {
        all[prefKey] = dirty;
      }
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
