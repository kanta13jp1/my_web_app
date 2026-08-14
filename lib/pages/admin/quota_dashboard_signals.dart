// R21: AI クォータ監視ダッシュボードの純ロジック(依存ゼロ・VM テスト可能)。
// quota_dashboard_page.dart は supabase 依存を含むため、バッジ状態・コスト表示の
// 判定だけをこのファイルへ切り出す(admin_dashboard_signals.dart と同じ
// 抽出パターン / part321 の教訓)。

/// ツールカードのバッジ状態。R17/R19 の誠実性規律: 未計測(行なし)や計測停止を
/// 「正常」と捏造しない。
enum QuotaToolStatus {
  /// quota.latest にそのツールの行が1件も無い = quota-monitor が計測していない
  /// (APIキー未設定 or 計測ステップ失敗で書き込みスキップ)。健全とは言えない。
  unmeasured,

  /// 最新行の alert フラグが真。
  alert,

  /// 最新行はあるが checked_at が staleDays 超え = 日次計測 cron が止まっている
  /// 可能性。古い「正常」を今の「正常」に見せない。
  stale,

  /// 最新行があり、alert でも stale でもない。
  ok,
}

/// quota.latest の行有無・alert フラグ・checked_at 鮮度からバッジ状態を決める。
/// checked_at は quota-monitor.yml (日次 cron / 09:00 JST) が書く日付文字列。
/// 正常時の最大 age は約1日なので staleDays 既定は2日(48h)。パース不能な
/// checked_at は鮮度を主張できないため stale 扱いにする。
QuotaToolStatus resolveQuotaToolStatus({
  required bool hasRow,
  required bool alert,
  required String? checkedAt,
  required DateTime now,
  int staleDays = 2,
}) {
  if (!hasRow) return QuotaToolStatus.unmeasured;
  if (alert) return QuotaToolStatus.alert;
  final checked = DateTime.tryParse(checkedAt ?? '');
  if (checked == null) return QuotaToolStatus.stale;
  final age = now.difference(checked);
  if (age.inDays >= staleDays) return QuotaToolStatus.stale;
  return QuotaToolStatus.ok;
}

/// バッジ文言。
String quotaStatusBadgeLabel(QuotaToolStatus status) {
  switch (status) {
    case QuotaToolStatus.unmeasured:
      return '未計測';
    case QuotaToolStatus.alert:
      return 'アラート';
    case QuotaToolStatus.stale:
      return '計測停止?';
    case QuotaToolStatus.ok:
      return '正常';
  }
}

/// usage_json の実測コスト。cost_usd → cost_usd_est の順で読む(quota-monitor の
/// openai step は cost_usd_est を書く)。どちらも無い場合は null を返し、UI は
/// 「$0.00」を捏造せず「コスト未取得」を表示する(測った $0 と未取得の区別)。
double? quotaCostUsd(Map<String, dynamic> usageJson) {
  final cost = usageJson['cost_usd'] ?? usageJson['cost_usd_est'];
  if (cost is num) return cost.toDouble();
  return null;
}

/// checked_at からの経過日数。パース不能は null。表示側は staleDays 以上のとき
/// 「(N日前)」を後置して古さを明示する。
int? quotaCheckedAgeDays(String? checkedAt, DateTime now) {
  final checked = DateTime.tryParse(checkedAt ?? '');
  if (checked == null) return null;
  final days = now.difference(checked).inDays;
  return days < 0 ? 0 : days;
}
