import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 口座（負債）ごとの月末残高を月キー単位で蓄積するローカルストア。
///
/// 既存の月次スナップショット同期（過去に LWW でのデータ消失バグあり）には触れず、
/// 独立した SharedPreferences キーへ自動蓄積する。これにより
/// [AssetDebtTrendAnalyzer] の「前月比で残高が増えたか」判定に必要な
/// 前月末残高を、マイグレーションや edge deploy 無しで供給できる。
///
/// 保存形式: `{ "yyyy-MM": { accountId: balanceMagnitude(正の値) } }`。
class AssetAccountBalanceHistoryStore {
  static const String prefsKey = 'asset_account_balance_history_v1';

  /// 保持する月数の上限（古い月から間引く）。
  static const int maxMonths = 13;

  const AssetAccountBalanceHistoryStore();

  static String formatMonthKey(DateTime month) {
    return '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}';
  }

  /// 指定月の口座別残高を保存（同じ月キーは上書き）。
  ///
  /// [balancesByAccountId] は accountId -> 利用残高の絶対額（正の値）。
  Future<void> recordMonth(
    DateTime month,
    Map<String, double> balancesByAccountId, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final history = _decode(store.getString(prefsKey));
    final monthKey = formatMonthKey(month);
    final sanitized = <String, double>{
      for (final entry in balancesByAccountId.entries)
        if (entry.key.trim().isNotEmpty && entry.value.isFinite)
          entry.key.trim(): entry.value.abs(),
    };
    if (sanitized.isEmpty) {
      // 負債が無い月でも「空である」事実を残すと前月比が壊れるため、
      // 空マップでも上書き記録する（負債が消えた=完済の検出にも使える）。
      history[monthKey] = <String, double>{};
    } else {
      history[monthKey] = sanitized;
    }
    _pruneOldMonths(history);
    await store.setString(prefsKey, jsonEncode(history));
  }

  /// 指定月より前で「残高データがある」最も新しい月の口座別残高を返す（無ければ空）。
  ///
  /// 負債ゼロの月は空マップで記録されるため、それを飛ばして実データのある
  /// 直近の月まで遡る。これにより「先月は完済 → 今月新規借入」でも前月比を
  /// 取りこぼさない（空マップを返すと残高増加検出が壊れるのを防ぐ）。
  Future<Map<String, double>> priorMonthBalances(
    DateTime month, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final history = _decode(store.getString(prefsKey));
    final currentKey = formatMonthKey(month);
    final priorKeys =
        history.keys.where((key) => key.compareTo(currentKey) < 0).toList()
          ..sort();
    for (final key in priorKeys.reversed) {
      final balances = history[key]!;
      if (balances.isNotEmpty) {
        return Map<String, double>.unmodifiable(balances);
      }
    }
    return const <String, double>{};
  }

  /// 蓄積済みの全月キー（昇順）。デバッグ・テスト用。
  Future<List<String>> recordedMonthKeys({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final history = _decode(store.getString(prefsKey));
    return history.keys.toList()..sort();
  }

  void _pruneOldMonths(Map<String, Map<String, double>> history) {
    if (history.length <= maxMonths) {
      return;
    }
    final keys = history.keys.toList()..sort();
    final removeCount = history.length - maxMonths;
    for (var i = 0; i < removeCount; i++) {
      history.remove(keys[i]);
    }
  }

  Map<String, Map<String, double>> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, Map<String, double>>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, Map<String, double>>{};
      }
      final result = <String, Map<String, double>>{};
      decoded.forEach((monthKey, value) {
        if (monthKey is! String || value is! Map) {
          return;
        }
        final balances = <String, double>{};
        value.forEach((accountId, balance) {
          if (accountId is! String) {
            return;
          }
          final parsed = balance is num
              ? balance.toDouble()
              : double.tryParse(balance.toString());
          // 残高は絶対値（正の値）で保存する契約。負値は破損データとして拒否する。
          if (parsed != null && parsed.isFinite && parsed >= 0) {
            balances[accountId] = parsed;
          }
        });
        result[monthKey] = balances;
      });
      return result;
    } catch (_) {
      return <String, Map<String, double>>{};
    }
  }
}
