import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// AI エージェント カンバンボードのデータ供給。
///
/// `wbs_tasks` を RLS 下で直接読み、Supabase Realtime で変更を購読する。
/// 購読が張れない環境 (publication 無効など) でも壊れないよう、60 秒の
/// フォールバック再取得を常に併走させる。
class AgentBoardService {
  AgentBoardService({SupabaseClient? client}) : _injected = client;

  // テストでサブクラスが差し替えられるよう、Supabase.instance は遅延解決する。
  final SupabaseClient? _injected;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  RealtimeChannel? _channel;
  Timer? _fallbackTimer;

  /// ログイン済みか (WBS はログイン済みユーザー限定)。
  bool get isSignedIn => _client.auth.currentSession != null;

  /// 盤面に必要な列だけを取得する。
  ///
  /// 完了タスクは全件だと数千行になるため、直近ぶんに絞ってから取得する
  /// (盤面側でも 24 時間窓で再度絞り込む)。
  Future<List<Map<String, dynamic>>> fetchRows() async {
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: 48))
        .toIso8601String();

    // 未完了は全件、完了は直近のみ。PostgREST の or フィルタで 1 往復にする。
    final data = await _client
        .from('wbs_tasks')
        .select(
          'id,title,status,progress,priority,category_icon,instance,'
          'owner_instance,updated_at,github_issue_number,github_issue_url',
        )
        .or('status.neq.completed,updated_at.gte.$since')
        .order('updated_at', ascending: false)
        .limit(400);

    return List<Map<String, dynamic>>.from(data as List);
  }

  /// 変更の購読を開始する。
  ///
  /// [onChange] は Realtime の通知時とフォールバックタイマーの双方から呼ばれる
  /// (呼び出し側で再取得する)。購読に失敗してもフォールバックは動き続ける。
  void subscribe(void Function() onChange) {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => onChange(),
    );

    try {
      _channel = _client
          .channel('public:wbs_tasks:agent_board')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'wbs_tasks',
            callback: (_) => onChange(),
          )
          .subscribe();
    } catch (_) {
      // Realtime が使えない環境ではフォールバックのみで動作する。
      _channel = null;
    }
  }

  /// 購読とタイマーを解放する。
  Future<void> dispose() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await _client.removeChannel(channel);
      } catch (_) {
        // 解放時のエラーは握りつぶす (画面遷移を妨げない)。
      }
    }
  }
}
