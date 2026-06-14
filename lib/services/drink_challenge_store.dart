import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'drink_challenge_service.dart';

/// 飲み我慢チャレンジの記録(日付→状態)をローカル永続化する。
/// v1 はローカルのみ。複数端末同期は将来の別 Issue で扱う。
class DrinkChallengeStore {
  static const String prefsKey = 'drink_challenge_records_v1';

  const DrinkChallengeStore();

  Future<Map<String, DrinkRecordStatus>> load({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return <String, DrinkRecordStatus>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, DrinkRecordStatus>{};
      }
      final result = <String, DrinkRecordStatus>{};
      decoded.forEach((key, value) {
        if (key is! String) {
          return;
        }
        if (value == 'abstained') {
          result[key] = DrinkRecordStatus.abstained;
        } else if (value == 'drank') {
          result[key] = DrinkRecordStatus.drank;
        }
      });
      return result;
    } catch (_) {
      return <String, DrinkRecordStatus>{};
    }
  }

  Future<void> save(
    Map<String, DrinkRecordStatus> records, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    if (records.isEmpty) {
      await store.remove(prefsKey);
      return;
    }
    final encoded = jsonEncode(<String, String>{
      for (final entry in records.entries)
        entry.key:
            entry.value == DrinkRecordStatus.abstained ? 'abstained' : 'drank',
    });
    await store.setString(prefsKey, encoded);
  }
}
