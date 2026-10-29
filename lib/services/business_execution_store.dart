import 'package:shared_preferences/shared_preferences.dart';

abstract class BusinessExecutionStore {
  Future<String?> read(String userId);
  Future<void> write(String userId, String? expected, String value);
}

/// Personal device storage; intentionally excluded from financial pref mirroring.
class LocalBusinessExecutionStore implements BusinessExecutionStore {
  const LocalBusinessExecutionStore();

  static String keyFor(String userId) {
    if (userId.isEmpty) throw StateError('ログインが必要です。');
    return 'business_execution_v1:$userId';
  }

  @override
  Future<String?> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(keyFor(userId));
  }

  @override
  Future<void> write(String userId, String? expected, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = keyFor(userId);
    if (prefs.getString(key) != expected) {
      throw StateError('別画面で記録が変更されました。再読み込みしてください。');
    }
    if (!await prefs.setString(key, value)) {
      throw StateError('端末への保存に失敗しました。');
    }
  }
}
