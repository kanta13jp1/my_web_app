import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// schedule_task_runs の直近履歴を1回だけ取得して使い回す共有リポジトリ。
///
/// SelfDevinControlTowerCard と ScheduleTaskMonitorCard がほぼ同一クエリを
/// initState で各自発行していた二重取得を、短 TTL の memoized Future 共有で
/// 1リクエストに畳む。列は両カードの必要列の和集合。
class ScheduleTaskRunsRepository {
  ScheduleTaskRunsRepository._();

  /// 同一初期表示バースト内の共有が目的なので TTL は短くてよい。
  static const Duration _ttl = Duration(seconds: 30);

  static Future<List<Map<String, dynamic>>>? _inflight;
  static DateTime? _fetchedAt;

  /// [force] は手動 Refresh ボタン用: TTL 内でもキャッシュを無効化して
  /// 再取得する (memoization は初期表示バーストの共有だけが目的で、明示的な
  /// ユーザー操作まで吸収しない)。
  static Future<List<Map<String, dynamic>>> fetch({
    SupabaseClient? supabaseClient,
    bool force = false,
  }) {
    final now = DateTime.now();
    final cached = _inflight;
    final at = _fetchedAt;
    if (!force && cached != null && at != null && now.difference(at) < _ttl) {
      return cached;
    }
    final client = supabaseClient ?? Supabase.instance.client;
    late final Future<List<Map<String, dynamic>>> future;
    future = _load(client).catchError((Object error, StackTrace stackTrace) {
      // 失敗した Future をキャッシュし続けると TTL 内の再試行まで
      // 全 consumer が同じエラーを見るため、即座に無効化する。
      if (identical(_inflight, future)) {
        _inflight = null;
        _fetchedAt = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
    _inflight = future;
    _fetchedAt = now;
    return future;
  }

  static Future<List<Map<String, dynamic>>> _load(
    SupabaseClient supabase,
  ) async {
    final data = await supabase
        .from('schedule_task_runs')
        .select(
          'task_id, status, started_at, finished_at, summary, error_message',
        )
        .order('started_at', ascending: false)
        .limit(120);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// テスト用: memoization を破棄する。
  @visibleForTesting
  static void reset() {
    _inflight = null;
    _fetchedAt = null;
  }
}
