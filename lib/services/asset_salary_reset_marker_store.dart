import 'package:shared_preferences/shared_preferences.dart';

/// 「支払済みチェックを最後にリセット(=新サイクルへ切替)した給料サイクル」を
/// 永続化する。
///
/// 値は `yyyy-MM`(= `AssetLiabilityMonthlyStateStore.formatMonthKey` 形式)で、
/// 給料振込を検知した、またはユーザーが手動で「給料を受け取った」を承認した最新の
/// サイクルキーを保持する。ページはこのマーカーと当日サイクルキーを突き合わせ、
/// 一致していなければ「前サイクルの支払済みを表示しつつ残高更新を促す」状態にする。
///
/// 月次 state(`paidAccountNames` を含む blob)は端末間で **whole-blob union merge**
/// されるため、ここに混ぜると LWW で消える危険がある(#3474/#3498 の教訓)。そこで
/// マーカーは [AssetSalaryDayStore] と同様に **独立した pref キー + 独立した
/// `asset_pref_mirror` 1 行**で同期する。復元は [mergeLater] による **max-merge**
/// (新しいサイクルキーを常に優先)で、stale 端末がマーカーを巻き戻さないようにする。
class AssetSalaryResetMarkerStore {
  static const String prefsKey = 'asset_salary_reset_ack_cycle_v1';

  const AssetSalaryResetMarkerStore();

  Future<String?> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return _normalize(store.getString(prefsKey));
  }

  Future<void> save(String? cycleKey, {SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final normalized = _normalize(cycleKey);
    if (normalized == null) {
      await store.remove(prefsKey);
    } else {
      await store.setString(prefsKey, normalized);
    }
  }

  /// 当日サイクル [dateCycleKey] に対し、まだリセット(=新サイクルへの切替)が
  /// 承認されていないか。承認済みマーカーが null(初回未設定)のときは「保留でない」=
  /// 当日サイクルを採用する(初回起動でいきなり前サイクルへ退避させない)。
  static bool isResetPending({
    required String dateCycleKey,
    required String? ackedCycleKey,
  }) {
    return ackedCycleKey != null && ackedCycleKey != dateCycleKey;
  }

  /// 2 つのサイクルキーのうち新しい方(`yyyy-MM` 文字列比較で大きい方)を返す。
  /// 固定長ゼロ埋めなので文字列比較がそのまま時系列順になる。null は「無し」。
  static String? mergeLater(String? a, String? b) {
    final na = _normalize(a);
    final nb = _normalize(b);
    if (na == null) {
      return nb;
    }
    if (nb == null) {
      return na;
    }
    return na.compareTo(nb) >= 0 ? na : nb;
  }

  /// `asset_pref_mirror.value` (jsonb) 用に `{cycle: "yyyy-MM"}` へ変換する。
  static Map<String, dynamic> encodeMirrorValue(String cycleKey) {
    return <String, dynamic>{'cycle': cycleKey};
  }

  /// `asset_pref_mirror.value` (jsonb) からサイクルキーを復元する。
  /// 不正値は null。
  static String? decodeMirrorValue(dynamic value) {
    if (value is Map && value['cycle'] is String) {
      return _normalize(value['cycle'] as String);
    }
    return null;
  }

  static String? _normalize(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    return RegExp(r'^\d{4}-\d{2}$').hasMatch(trimmed) ? trimmed : null;
  }
}
