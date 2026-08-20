// 参謀室ブリーフィングを、X で実測 8K インプを出した「データレポート型
// (スコアボード)」で共有するための純合成ロジック(household_tracker と同型)。
//
// 設計原則:
// - 決定的合成(LLM 不使用)。テンプレートに実データを流し込むだけで捏造を構造的に
//   不可能にする(R23 G2 / Qiita 無審査停止の教訓)。
// - プライバシー規律: 公開するのは「稼働の有無・部署数のレンジ・重大度の有無・
//   方向」のみ。円金額・残高・口座名・具体日付は絶対に出力しない。
// - 投稿は growth-hub x.post 経由(variant=advisory_room /
//   contentArchetype=data_report)で学習ループの計測対象にする。

import 'asset_advisory_briefing_service.dart';

/// 参謀室ブリーフィングの公開スナップショット(件数の生値を持たない)。
class AdvisoryBriefingSnapshot {
  /// 参謀室が 1 件でもアクションを出したか。
  final bool active;

  /// 対応に加わった部署数(公開時はレンジへ丸める)。
  final int engagedDepartments;

  /// 🔴 クリティカルが 1 件以上あるか。
  final bool hasCritical;

  /// 🟡 要注意が 1 件以上あるか。
  final bool hasWarning;

  /// 資金繰り予測データが揃っていたか。
  final bool forecastAvailable;

  /// 予測期間内に資金ショート見込みがあるか。
  final bool hasShortfall;

  /// ショート時期の局面(絶対日は出さない)。
  /// none / this_month / within_3m / within_6m / beyond_6m / unknown。
  final String shortfallPhase;

  /// 負債トレンドで要対応(警告以上)の検出があったか。
  final bool debtTrendFlagged;

  /// 「借金しない宣言」違反があったか。
  final bool disciplineViolation;

  /// 集計時刻(JST 前提の DateTime を渡す)。
  final DateTime now;

  const AdvisoryBriefingSnapshot({
    required this.active,
    required this.engagedDepartments,
    required this.hasCritical,
    required this.hasWarning,
    required this.forecastAvailable,
    required this.hasShortfall,
    required this.shortfallPhase,
    required this.debtTrendFlagged,
    required this.disciplineViolation,
    required this.now,
  });
}

String _two(int v) => v.toString().padLeft(2, '0');

/// 部署数を再識別しにくいレンジへ丸める。
String anonymizedDepartmentCount(int value) {
  final safe = value < 0 ? 0 : value;
  if (safe == 0) return '0部署';
  if (safe <= 2) return '1〜2部署';
  return '3部署以上';
}

/// ショート局面を公開向けの一文へ変換する(絶対日は出さない)。
String shortfallPhaseLabel(AdvisoryBriefingSnapshot s) {
  if (!s.forecastAvailable) return '予測データ不足';
  switch (s.shortfallPhase) {
    case 'this_month':
      return '今月内にショート見込み';
    case 'within_3m':
      return '3ヶ月以内に要注意';
    case 'within_6m':
      return '半年以内に要注意';
    case 'beyond_6m':
      return '半年超は要観察';
    case 'none':
      return '当面クリア';
    default:
      return '予測データ不足';
  }
}

/// スコアボード形式の投稿本文を決定的に合成する。金額・口座名・具体日は含まない。
String buildAdvisoryBriefingText(AdvisoryBriefingSnapshot s) {
  final d = s.now;
  final dateLabel = '${d.year}/${_two(d.month)}/${_two(d.day)}';
  final lines = <String>[
    'AI参謀室ブリーフィング $dateLabel（自分株式会社・匿名集計）',
    '',
    '集計日: $dateLabel',
    '参謀室: ${s.active ? '稼働' : '待機（赤信号なし）'}',
    '対応部署: ${anonymizedDepartmentCount(s.engagedDepartments)}',
    'アラート: 🔴${s.hasCritical ? 'あり' : 'なし'} / 🟡${s.hasWarning ? 'あり' : 'なし'}',
    '資金繰り予測: ${shortfallPhaseLabel(s)}',
    '負債トレンド: ${s.debtTrendFlagged ? '要対応の検出あり' : '赤信号なし'}',
    '借金しない宣言: ${s.disciplineViolation ? '違反あり' : '達成'}',
    '',
    '個人の実データ(資金繰り予測 × 負債トレンド)を6部署が1つの状況として裁定。',
    '※金額・口座名・具体日は非公開。件数はレンジ表示。',
  ];
  return lines.join('\n');
}

/// growth-hub x.post へ渡す payload(純関数)。household_tracker と同型の
/// variant/archetype タグ付けで学習ループ(variant ranking / Archetype lift)の
/// 計測対象にする。
Map<String, dynamic> buildAdvisoryBriefingPostPayload(
  AdvisoryBriefingSnapshot snapshot,
) {
  return {
    'action': 'x.post',
    'text': buildAdvisoryBriefingText(snapshot),
    'source': 'advisory_room',
    'variant': 'advisory_room',
    'utmContent': 'advisory_room',
    'route': '/asset-management',
    'promptProfile': 'advisory_room_scoreboard_v1',
    'contentKind': 'data_report',
    'contentArchetype': 'data_report',
    'experimentKey': 'x_first_user_growth_10k',
    'linkInReply': false,
  };
}

/// firstShortfallDate と now から公開向けのショート局面キーを決定する。
String advisoryShortfallPhase({
  required bool forecastAvailable,
  DateTime? firstShortfallDate,
  required DateTime now,
}) {
  if (!forecastAvailable) return 'unknown';
  if (firstShortfallDate == null) return 'none';
  final monthsDiff = (firstShortfallDate.year * 12 + firstShortfallDate.month) -
      (now.year * 12 + now.month);
  if (monthsDiff <= 0) return 'this_month';
  if (monthsDiff <= 3) return 'within_3m';
  if (monthsDiff <= 6) return 'within_6m';
  return 'beyond_6m';
}

/// [AdvisoryBriefing] から公開スナップショットを組み立てる純ヘルパ
/// (金額・具体日は一切読まない)。[firstShortfallDate] はショート局面の
/// バケット判定のみに使い、スナップショットには保存しない。
AdvisoryBriefingSnapshot advisoryBriefingSnapshotFrom(
  AdvisoryBriefing briefing, {
  DateTime? firstShortfallDate,
  required DateTime now,
}) {
  bool hasSignal(String key) => briefing.actions.any((a) => a.signalKey == key);

  final forecastAvailable =
      briefing.actions.any((a) => a.signalKey.startsWith('cashflow_'));
  final hasShortfall = hasSignal('cashflow_shortfall');
  final debtTrendFlagged = briefing.actions.any(
    (a) => a.signalKey == 'debt_trend' && a.severity != AdvisorySeverity.info,
  );

  return AdvisoryBriefingSnapshot(
    active: !briefing.isEmpty,
    engagedDepartments: briefing.engagedDepartmentCount,
    hasCritical: briefing.criticalCount > 0,
    hasWarning: briefing.warningCount > 0,
    forecastAvailable: forecastAvailable,
    hasShortfall: hasShortfall,
    shortfallPhase: advisoryShortfallPhase(
      forecastAvailable: forecastAvailable,
      firstShortfallDate: hasShortfall ? firstShortfallDate : null,
      now: now,
    ),
    debtTrendFlagged: debtTrendFlagged,
    disciplineViolation: hasSignal('discipline_violation'),
    now: now,
  );
}
