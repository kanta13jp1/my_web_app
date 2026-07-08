// R16: /admin 経営分析ダッシュボードのアクションカード状態機械の純ロジック。
// admin_analytics_page.dart は supabase/url_launcher 等の重い(web専用 JS interop を
// 含む)依存を持ち VM テストで直接コンパイルできないため、テスト可能な純ロジックだけ
// をこの依存ゼロのファイルへ切り出す(edge の x_today_status.ts と同じ抽出パターン)。

/// 今日の X 投稿状況(growth-hub x.today_status)から決まるアクションカードの状態。
enum AdminXPostedTodayCta {
  /// 今日未投稿 or status 未取得 → 従来の「X投稿を作る」へフォールバック。
  none,

  /// spend-cap ブロック中 → console.x.com で上限確認。
  blocked,

  /// 投稿後60分以内 → ゴールデンアワー(投稿を開いて手動リプ/poll確認)。
  goldenHour,

  /// 投稿後60分超 → 計測待ち(再投稿せずアカウント導線へ)。
  measuring,
}

/// x.today_status のマップと現在時刻から CTA 状態を純粋に決める。blocked を最優先し、
/// 次に「今日投稿済みか」、そして投稿からの経過時間(<=60分でゴールデンアワー)で分岐。
AdminXPostedTodayCta adminXPostedTodayCta(
  Map<String, dynamic>? status,
  DateTime now,
) {
  if (status == null) return AdminXPostedTodayCta.none;
  if (status['blocked'] == true) return AdminXPostedTodayCta.blocked;
  final rawCount = status['postedTodayCount'];
  final count = rawCount is int
      ? rawCount
      : int.tryParse(rawCount?.toString() ?? '') ?? 0;
  if (count <= 0) return AdminXPostedTodayCta.none;
  final postedAt =
      DateTime.tryParse(status['lastPostedAt']?.toString() ?? '')?.toLocal();
  if (postedAt != null && now.difference(postedAt).inMinutes <= 60) {
    return AdminXPostedTodayCta.goldenHour;
  }
  return AdminXPostedTodayCta.measuring;
}
