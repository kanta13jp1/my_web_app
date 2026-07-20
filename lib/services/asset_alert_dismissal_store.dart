import 'package:shared_preferences/shared_preferences.dart';

/// 統合アラートパネル (Issue #2475) で dismiss したアラート id を永続化する。
///
/// ローカル (SharedPreferences) を一次ストアとする軽量な集合ストア。アラート id は
/// 発生事象ごとに安定 (期日など状態が変われば別値) なので、解消後に再発した事象は
/// 新しい id で再表示される。集合が肥大しないよう、[prune] で「現存する id」以外を
/// 掃除できる。
class AssetAlertDismissalStore {
  static const String prefsKey = 'asset_alert_dismissed_ids_v1';

  const AssetAlertDismissalStore();

  Future<Set<String>> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getStringList(prefsKey);
    if (raw == null) {
      return <String>{};
    }
    return raw.where((id) => id.trim().isNotEmpty).toSet();
  }

  Future<Set<String>> dismiss(String id, {SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final current = await load(prefs: store);
    if (id.trim().isEmpty || current.contains(id)) {
      return current;
    }
    final next = {...current, id};
    await store.setStringList(prefsKey, next.toList());
    return next;
  }

  Future<Set<String>> restore(String id, {SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final current = await load(prefs: store);
    if (!current.contains(id)) {
      return current;
    }
    final next = {...current}..remove(id);
    await store.setStringList(prefsKey, next.toList());
    return next;
  }

  /// [liveIds] に含まれない dismiss 済み id を削除する (集合の肥大防止)。
  /// 返り値は掃除後の集合。
  Future<Set<String>> prune(
    Set<String> liveIds, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final current = await load(prefs: store);
    final next = current.intersection(liveIds);
    if (next.length == current.length) {
      return current;
    }
    await store.setStringList(prefsKey, next.toList());
    return next;
  }
}
