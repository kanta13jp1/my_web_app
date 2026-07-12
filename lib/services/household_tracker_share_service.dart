// R24b: 家計ドメインの独自データ資産を、X で実測 8K インプを出した「データ
// レポート型(スコアボード)」で定期投稿するための純合成ロジック。
//
// 設計原則:
// - 決定的合成(LLM 不使用)。post A(選挙集計)と同じく、テンプレートに実データを
//   流し込むだけにして捏造を構造的に不可能にする(R23 G2 教訓)。
// - プライバシー規律: 公開するのは「件数・日数・方向・重大度」のみ。
//   円金額・残高絶対値・口座名は絶対に出力しない。
// - 投稿は growth-hub x.post 経由(variant=household_tracker /
//   contentArchetype=data_report)で学習ループの計測対象にする。

/// 家計トラッカー投稿の入力(すべて件数/日数/方向 — 金額は受け取らない)。
class HouseholdTrackerSnapshot {
  /// 監視対象の負債口座数。
  final int monitoredAccounts;

  /// 負債トレンド検出件数(内訳の合計と一致させる)。
  final int balanceIncreasing;
  final int negativeAmortization;
  final int slowPayoff;

  /// 重大度別件数。
  final int criticalCount;
  final int warningCount;

  /// 給料日設定(毎月 N 日)。
  final int salaryDay;

  /// 集計時刻(JST 前提の DateTime を渡す)。
  final DateTime now;

  const HouseholdTrackerSnapshot({
    required this.monitoredAccounts,
    required this.balanceIncreasing,
    required this.negativeAmortization,
    required this.slowPayoff,
    required this.criticalCount,
    required this.warningCount,
    required this.salaryDay,
    required this.now,
  });

  int get totalFindings =>
      balanceIncreasing + negativeAmortization + slowPayoff;
}

/// 次の給料日まで残り日数(当日は 0)。salaryDay は 1..28 の前提
/// (AssetSalaryDayStore.clampDay 済みの値を渡す)。
int daysUntilSalaryDay(DateTime now, int salaryDay) {
  final today = DateTime(now.year, now.month, now.day);
  var next = DateTime(now.year, now.month, salaryDay);
  if (next.isBefore(today)) {
    next = DateTime(now.year, now.month + 1, salaryDay);
  }
  return next.difference(today).inDays;
}

String _two(int v) => v.toString().padLeft(2, '0');

/// スコアボード形式の投稿本文を決定的に合成する(post A と同型: 取得日時/主要
/// 数値/内訳/アラート/カウントダウン)。金額は一切含まない。
String buildHouseholdTrackerText(HouseholdTrackerSnapshot s) {
  final d = s.now;
  final dateLabel = '${d.year}/${_two(d.month)}/${_two(d.day)}';
  final timestamp = '$dateLabel ${_two(d.hour)}:${_two(d.minute)}';
  final remaining = daysUntilSalaryDay(s.now, s.salaryDay);
  final lines = <String>[
    '家計トラッカー $dateLabel（自分株式会社・実運用データ）',
    '',
    '取得日時: $timestamp',
    '監視口座数: ${s.monitoredAccounts}',
    '負債トレンド検出: ${s.totalFindings}件',
    '内訳: 残高増加 ${s.balanceIncreasing} / 利息超過 ${s.negativeAmortization} / 長期化 ${s.slowPayoff}',
    if (s.criticalCount > 0 || s.warningCount > 0)
      'アラート: 🔴${s.criticalCount}件 / 🟡${s.warningCount}件'
    else
      'アラート: なし',
    '給料日まで: あと$remaining日（毎月${s.salaryDay}日起点）',
    '',
    '※公開は件数・日数・方向のみ（金額は非公開）',
  ];
  return lines.join('\n');
}

/// growth-hub x.post へ渡す payload(純関数)。選挙トラッカー(R24)と同型の
/// variant/archetype タグ付けで学習ループ(variant ranking / Archetype lift)の
/// 計測対象にする。
Map<String, dynamic> buildHouseholdTrackerPostPayload(
  HouseholdTrackerSnapshot snapshot,
) {
  return {
    'action': 'x.post',
    'text': buildHouseholdTrackerText(snapshot),
    'source': 'household_tracker',
    'variant': 'household_tracker',
    'contentArchetype': 'data_report',
    'experimentKey': 'x_first_user_growth_10k',
  };
}
