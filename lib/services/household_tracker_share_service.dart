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

import 'asset_debt_trend_analyzer.dart';

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

  /// 給料日が既定値ではなく、本人の保存済み設定から取得できたか。
  ///
  /// false のスナップショットは「実運用データ」として定期投稿しない。
  final bool salaryDayConfigured;

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
    required this.salaryDayConfigured,
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

/// すべての件数を同じ幅へ丸め、合計と内訳の引き算でも小セルを復元できない
/// ようにする。
///
/// 単一世帯の公開投稿では、金額・口座名を除くだけでは再識別リスクが残る。
/// 0件だけは「該当なし」として公開し、正の値は一律のレンジで公開する。
String anonymizedHouseholdCount(int value) {
  final safe = value < 0 ? 0 : value;
  if (safe == 0) return '0件';
  if (safe < 3) return '1〜2件';
  if (safe < 6) return '3〜5件';
  if (safe < 11) return '6〜10件';
  return '11件以上';
}

/// 給料日の絶対日を公開せず、現在のサイクル局面だけを返す。
String salaryCyclePhase(DateTime now, int salaryDay) {
  final remaining = daysUntilSalaryDay(now, salaryDay);
  if (remaining <= 3) return '給料日まで3日以内';
  if (remaining <= 7) return '給料日まで1週間以内';
  if (remaining <= 14) return '給料日まで1〜2週間';
  return '給料日まで2週間超';
}

/// スコアボード形式の投稿本文を決定的に合成する(post A と同型: 取得日時/主要
/// 数値/内訳/アラート/カウントダウン)。金額は一切含まない。
String buildHouseholdTrackerText(HouseholdTrackerSnapshot s) {
  final d = s.now;
  final dateLabel = '${d.year}/${_two(d.month)}/${_two(d.day)}';
  final lines = <String>[
    '家計トラッカー $dateLabel（自分株式会社・匿名集計）',
    '',
    '集計日: $dateLabel',
    'トレンド検出口座: ${anonymizedHouseholdCount(s.monitoredAccounts)}',
    '負債トレンド検出: ${anonymizedHouseholdCount(s.totalFindings)}',
    '内訳: 残高増加 ${anonymizedHouseholdCount(s.balanceIncreasing)} / '
        '利息超過 ${anonymizedHouseholdCount(s.negativeAmortization)} / '
        '長期化 ${anonymizedHouseholdCount(s.slowPayoff)}',
    if (s.criticalCount > 0 || s.warningCount > 0)
      'アラート: 🔴${anonymizedHouseholdCount(s.criticalCount)} / '
          '🟡${anonymizedHouseholdCount(s.warningCount)}'
    else
      'アラート: なし',
    '給料日サイクル: ${s.salaryDayConfigured ? salaryCyclePhase(s.now, s.salaryDay) : '未設定'}',
    '',
    '※金額・口座名・給料日の絶対日は非公開。件数は幅表示。',
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
    'utmContent': 'household_tracker',
    'route': '/asset-management',
    'promptProfile': 'household_tracker_scoreboard_v2',
    'contentKind': 'data_report',
    'contentArchetype': 'data_report',
    'experimentKey': 'x_first_user_growth_10k',
    'linkInReply': false,
  };
}

/// `asset_pref_mirror` に保存する公開候補スナップショットのキー。
/// 保存対象は投稿本文の allowlist 数値だけで、金額・口座名は入らない。
const String householdTrackerPublishMirrorKey =
    'household_tracker_publish_snapshot';
const String householdTrackerPublishConsentMirrorKey =
    'household_tracker_publish_consent';

class HouseholdTrackerPublishMirror {
  final HouseholdTrackerSnapshot snapshot;

  const HouseholdTrackerPublishMirror({
    required this.snapshot,
  });
}

Map<String, dynamic> encodeHouseholdTrackerPublishMirror(
  HouseholdTrackerSnapshot snapshot,
) {
  return <String, dynamic>{
    'schema_version': 1,
    'observed_at': snapshot.now.toUtc().toIso8601String(),
    'monitored_accounts': snapshot.monitoredAccounts,
    'balance_increasing': snapshot.balanceIncreasing,
    'negative_amortization': snapshot.negativeAmortization,
    'slow_payoff': snapshot.slowPayoff,
    'critical_count': snapshot.criticalCount,
    'warning_count': snapshot.warningCount,
    'salary_day': snapshot.salaryDay,
    'salary_day_configured': snapshot.salaryDayConfigured,
  };
}

/// 不正な/旧形式の公開候補は fail-closed で null にする。
HouseholdTrackerPublishMirror? decodeHouseholdTrackerPublishMirror(
  dynamic value,
) {
  if (value is! Map || value['schema_version'] != 1) return null;

  int? nonNegative(String key) {
    final raw = value[key];
    if (raw is! num) return null;
    final parsed = raw.toInt();
    return parsed >= 0 && parsed <= 999 ? parsed : null;
  }

  final observedAt = DateTime.tryParse('${value['observed_at'] ?? ''}');
  final monitoredAccounts = nonNegative('monitored_accounts');
  final balanceIncreasing = nonNegative('balance_increasing');
  final negativeAmortization = nonNegative('negative_amortization');
  final slowPayoff = nonNegative('slow_payoff');
  final criticalCount = nonNegative('critical_count');
  final warningCount = nonNegative('warning_count');
  final salaryDayRaw = value['salary_day'];
  if (observedAt == null ||
      monitoredAccounts == null ||
      balanceIncreasing == null ||
      negativeAmortization == null ||
      slowPayoff == null ||
      criticalCount == null ||
      warningCount == null ||
      salaryDayRaw is! num) {
    return null;
  }
  final salaryDay = salaryDayRaw.toInt();
  if (salaryDay < 1 || salaryDay > 28) return null;

  return HouseholdTrackerPublishMirror(
    snapshot: HouseholdTrackerSnapshot(
      monitoredAccounts: monitoredAccounts,
      balanceIncreasing: balanceIncreasing,
      negativeAmortization: negativeAmortization,
      slowPayoff: slowPayoff,
      criticalCount: criticalCount,
      warningCount: warningCount,
      salaryDay: salaryDay,
      salaryDayConfigured: value['salary_day_configured'] == true,
      now: observedAt,
    ),
  );
}

/// 投稿同意はスナップショットと別キーに保存する。古い集計の遅延同期が停止操作を
/// enabled=true へ戻せないようにするため、背景同期はこの値へ触れない。
Map<String, dynamic> encodeHouseholdTrackerPublishConsent(bool enabled) =>
    <String, dynamic>{
      'schema_version': 1,
      'enabled': enabled,
    };

bool? decodeHouseholdTrackerPublishConsent(dynamic value) {
  if (value is! Map || value['schema_version'] != 1) return null;
  if (value['enabled'] is! bool) return null;
  return value['enabled'] as bool;
}

/// 負債トレンド insights から Snapshot を組み立てる純ヘルパ(金額は一切読まない)。
/// monitoredAccounts は insights 内の distinct 口座数(=検出対象口座)。
HouseholdTrackerSnapshot householdSnapshotFromInsights(
  List<AssetDebtTrendInsight> insights, {
  required int salaryDay,
  required bool salaryDayConfigured,
  required DateTime now,
}) {
  int countBy(AssetDebtTrendCategory c) =>
      insights.where((i) => i.category == c).length;
  int severity(AssetDebtTrendSeverity sv) =>
      insights.where((i) => i.severity == sv).length;
  return HouseholdTrackerSnapshot(
    monitoredAccounts: insights.map((i) => i.accountId).toSet().length,
    balanceIncreasing: countBy(AssetDebtTrendCategory.balanceIncreasing),
    negativeAmortization: countBy(AssetDebtTrendCategory.negativeAmortization),
    slowPayoff: countBy(AssetDebtTrendCategory.slowPayoff),
    criticalCount: severity(AssetDebtTrendSeverity.critical),
    warningCount: severity(AssetDebtTrendSeverity.warning),
    salaryDay: salaryDay,
    salaryDayConfigured: salaryDayConfigured,
    now: now,
  );
}
