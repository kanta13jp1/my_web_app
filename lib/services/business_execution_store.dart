import 'package:shared_preferences/shared_preferences.dart';

import 'business_execution_lock.dart';

abstract class BusinessExecutionStore {
  Future<String?> read(String userId);
  Future<void> write(
    String userId,
    String? expected,
    String value, {
    required bool Function() isCurrent,
  });
}

/// Personal device storage; intentionally excluded from financial pref mirroring.
class LocalBusinessExecutionStore implements BusinessExecutionStore {
  const LocalBusinessExecutionStore({
    this.withLock = withBusinessExecutionLock,
  });

  final Future<void> Function(String, Future<void> Function()) withLock;

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
  Future<void> write(
    String userId,
    String? expected,
    String value, {
    required bool Function() isCurrent,
  }) async {
    await withLock('business-execution:$userId', () async {
      if (!isCurrent()) throw StateError('アカウントが変更されました。');
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final key = keyFor(userId);
      if (prefs.getString(key) != expected) {
        throw StateError('別画面で記録が変更されました。再読み込みしてください。');
      }
      // Recheck after every wait and immediately before starting the write.
      if (!isCurrent()) throw StateError('アカウントが変更されました。');
      if (!await prefs.setString(key, value)) {
        throw StateError('端末への保存に失敗しました。');
      }
      await prefs.reload();
      if (prefs.getString(key) != value) {
        throw StateError('排他保存後の読み戻しが一致しません。');
      }
    });
  }
}
