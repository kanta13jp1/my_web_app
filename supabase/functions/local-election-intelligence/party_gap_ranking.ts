// R28: 国民民主×立憲 都道府県地力差ランキング系列
// (docs/X_TRACKER_SERIES_PLAYBOOK.md step 2 / 水平展開第2号)。
// データ資産 = 日次 snapshot に既に揃っている両党の県別実数
// (currentMembers = 国民民主公式 / cdpLocalMembers = 立憲参考)。追加
// スクレイピング不要で、政治クラスタの別角度(比較・ギャップ枠)を取る。
//
// LLM 不使用の決定的合成のみ。candidate_key は ISO 週キー=日次 cron から
// 呼ばれても週1回だけ候補が作られる(insertPostCandidate の冪等性)。
// 立憲参考データ未同期(全県0)や県数欠損の日は null(候補を作らない)。

import { buildXPostCandidateMetadata } from "../growth-hub/x_post_candidate.ts";
import type {
  CanonicalLocalElectionSnapshot,
  CanonicalPrefecture,
} from "./snapshot_history.ts";

type JsonRecord = Record<string, unknown>;

export const PARTY_GAP_VARIANT = "party_gap_ranking";
const MIN_PREFECTURES = 40;
const EVEN_GAP_THRESHOLD = 2;
const TOP_LINES = 5;

/// assets/data/cdp_local_members.json (週次 update_cdp_benchmark.mjs が正本)
/// を EF 側で使える形へ正規化する。snapshot の cdpLocalMembers は EF では
/// 常に 0 ハードコード(index.ts のコメント参照)のため、この asset が本番で
/// 唯一の立憲実数源(レビュー F1: これ無しでは系列が一度も生成されない)。
/// 形式: { prefectures: { "北海道": 57, "青森": 25, ... } } — キーは
/// 都府県サフィックス無し(北海道のみ「道」付き)。
export function normalizeCdpBenchmark(
  raw: unknown,
): Record<string, number> | null {
  const record = raw as JsonRecord | null;
  const prefectures = record && typeof record === "object"
    ? (record as JsonRecord).prefectures
    : null;
  if (
    typeof prefectures !== "object" || prefectures === null ||
    Array.isArray(prefectures)
  ) {
    return null;
  }
  const result: Record<string, number> = {};
  for (const [name, value] of Object.entries(prefectures as JsonRecord)) {
    const count = typeof value === "number" && Number.isFinite(value)
      ? Math.max(0, Math.trunc(value))
      : null;
    if (name.trim() === "" || count === null) continue;
    result[name.trim()] = count;
  }
  return Object.keys(result).length > 0 ? result : null;
}

/// snapshot の県名(東京都/京都府/香川県)を asset キー(東京/京都/香川)へ
/// 名寄せする。北海道は「道」がクラス外なのでそのまま一致する。
function cdpBenchmarkFor(
  cdpByPrefecture: Record<string, number>,
  prefectureName: string,
): number | null {
  const direct = cdpByPrefecture[prefectureName];
  if (typeof direct === "number") return direct;
  const stripped = prefectureName.replace(/[都府県]$/, "");
  const bySuffix = cdpByPrefecture[stripped];
  return typeof bySuffix === "number" ? bySuffix : null;
}

/// ISO 週キー (例: 2026-W28)。週次冪等の candidate_key に使う。
export function isoWeekKey(observedAtIso: string): string | null {
  const parsed = Date.parse(observedAtIso);
  if (!Number.isFinite(parsed)) return null;
  // ISO 8601: 週の起点は月曜、第1週はその年の最初の木曜を含む週。
  const date = new Date(parsed);
  const target = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
  const dayOfWeek = target.getUTCDay() || 7;
  target.setUTCDate(target.getUTCDate() + 4 - dayOfWeek);
  const isoYear = target.getUTCFullYear();
  const yearStart = Date.UTC(isoYear, 0, 1);
  const week = Math.ceil(
    ((target.getTime() - yearStart) / 86400000 + 1) / 7,
  );
  return `${isoYear}-W${String(week).padStart(2, "0")}`;
}

function jstDateLabel(iso: string): string | null {
  const parsed = Date.parse(iso);
  if (!Number.isFinite(parsed)) return null;
  const jst = new Date(parsed + 9 * 60 * 60 * 1000);
  return `${jst.getUTCFullYear()}/${jst.getUTCMonth() + 1}/${jst.getUTCDate()}`;
}

function signed(value: number): string {
  return value > 0 ? `+${value}` : `${value}`;
}

type GapRow = {
  prefecture: string;
  kokumin: number;
  cdp: number;
  gap: number;
};

function gapLine(row: GapRow): string {
  return `${row.prefecture} ${signed(row.gap)}（${row.kokumin} vs ${row.cdp}）`;
}

/// 週次の地力差ランキング候補メタデータを合成する。生成不能条件は null:
/// 県数 < MIN_PREFECTURES(取得欠損)/ 立憲参考が全県 0(plan 未同期)/
/// observedAt 不正。
export function buildPartyGapCandidateMetadata(
  snapshot: CanonicalLocalElectionSnapshot,
  options: {
    snapshotObservationId: string;
    snapshotHash: string;
    datasetVersion: string;
    observedAt: string;
    datasetSource: string;
    dataset: string;
    targetUrl?: string;
    /// EF 側の立憲実数源(normalizeCdpBenchmark の結果)。未指定/null 時は
    /// snapshot の cdpLocalMembers へフォールバックする(EF snapshot では
    /// 常に 0 のため cdpTotal ゲートで自然に見送りになる)。
    cdpByPrefecture?: Record<string, number> | null;
  },
): JsonRecord | null {
  const prefectures: CanonicalPrefecture[] = snapshot.prefectures ?? [];
  if (prefectures.length < MIN_PREFECTURES) return null;
  const weekKey = isoWeekKey(options.observedAt);
  const dayLabel = jstDateLabel(options.observedAt);
  if (weekKey === null || dayLabel === null) return null;

  const cdpByPrefecture = options.cdpByPrefecture ?? null;
  const rows: GapRow[] = prefectures.map((prefecture) => {
    const cdp = cdpByPrefecture !== null
      ? cdpBenchmarkFor(cdpByPrefecture, prefecture.prefecture) ?? 0
      : prefecture.cdpLocalMembers;
    return {
      prefecture: prefecture.prefecture,
      kokumin: prefecture.currentMembers,
      cdp,
      gap: prefecture.currentMembers - cdp,
    };
  });
  const cdpTotal = rows.reduce((sum, row) => sum + row.cdp, 0);
  // 立憲参考が全県 0 = 参考データ未同期の日。比較レポートとして成立しない
  // ので候補を作らない(0 との比較は「実測」を名乗れない)。
  if (cdpTotal === 0) return null;
  const kokuminTotal = rows.reduce((sum, row) => sum + row.kokumin, 0);

  const kokuminLead = rows.filter((row) => row.gap > EVEN_GAP_THRESHOLD);
  const cdpLead = rows.filter((row) => row.gap < -EVEN_GAP_THRESHOLD);
  const even = rows.length - kokuminLead.length - cdpLead.length;
  const byGapDesc = [...rows].sort((left, right) => right.gap - left.gap);
  // 「リード上位」の掲載条件はサマリ行のリード定義(|gap| > EVEN_GAP_THRESHOLD)
  // と同一にする。gap>0 で拾うとサマリ「リード0県」の直後に互角圏(+1/+2)の
  // 県が「リード上位」として並ぶ自己矛盾レポートになる(レビュー F2)。
  const topKokumin = byGapDesc.slice(0, TOP_LINES).filter((row) =>
    row.gap > EVEN_GAP_THRESHOLD
  );
  const topCdp = [...byGapDesc].reverse().slice(0, TOP_LINES).filter((row) =>
    row.gap < -EVEN_GAP_THRESHOLD
  );

  const lead = [
    `国民民主党×立憲民主党 地方議員 地力差 ${dayLabel}`,
    "",
    `取得日時: ${options.observedAt}`,
    `国民民主 公式地方議員数: ${kokuminTotal}人`,
    `立憲民主 参考合計: ${cdpTotal}人`,
    `両党差分: ${signed(kokuminTotal - cdpTotal)}人`,
    `国民民主リード(差+${
      EVEN_GAP_THRESHOLD + 1
    }人以上): ${kokuminLead.length}県`,
    `立憲民主リード(差-${EVEN_GAP_THRESHOLD + 1}人以上): ${cdpLead.length}県`,
    `互角(±${EVEN_GAP_THRESHOLD}人): ${even}県`,
    "",
    "国民民主リード上位",
    ...(topKokumin.length > 0 ? topKokumin.map(gapLine) : ["(リード県なし)"]),
    "",
    "開拓余地(立憲民主リード上位)",
    ...(topCdp.length > 0 ? topCdp.map(gapLine) : ["(該当なし)"]),
    "",
    "数字は両党公式サイト掲載の現職一覧から自動集計した実測値です(立憲民主は参考値)。",
  ].join("\n");

  const replies: string[] = [];
  // 全47都道府県の内訳(ポストAの名簿相当=検索面)。
  replies.push(
    [
      "全都道府県の地力差(国民民主 vs 立憲民主参考)",
      "",
      ...byGapDesc.map(gapLine),
    ].join("\n"),
  );
  // アラート(実測から機械的に導出できるものだけ)。
  const alerts: string[] = [];
  const missingKokumin = rows.filter((row) => row.kokumin === 0);
  if (missingKokumin.length > 0) {
    alerts.push(
      `🔴 国民民主 議員不在 ${missingKokumin.length}県: ${
        missingKokumin.map((row) => row.prefecture).join("、")
      }`,
    );
  }
  const missingCdp = rows.filter((row) => row.cdp === 0);
  if (missingCdp.length > 0) {
    alerts.push(
      `🟡 立憲民主 参考データ0の県: ${missingCdp.length}県(参考値の欠落を含む可能性)`,
    );
  }
  replies.push(
    [
      "アラート",
      "",
      ...(alerts.length > 0 ? alerts : ["今週のアラートなし"]),
    ].join("\n"),
  );
  const targetUrl = options.targetUrl ??
    "https://my-web-app-b67f4.web.app/election-victory?utm_source=x&utm_medium=data_report&utm_campaign=first_user_growth&utm_content=party_gap_ranking";
  replies.push(
    [
      "この地力差レポートは毎週、両党公式サイトの自動巡回データから生成しています。",
      "全都道府県の内訳と現職名簿はダッシュボードで公開中です。",
      targetUrl,
    ].join("\n"),
  );

  const sourceUrls = Array.from(
    new Set(
      (snapshot.sources ?? [])
        .map((source) => source.url)
        .filter((url) => typeof url === "string" && url !== ""),
    ),
  ).slice(0, 10);

  const common = buildXPostCandidateMetadata({
    action: "x.post",
    text: lead,
    replyTexts: replies,
    source: options.datasetSource,
    route: "local-election-intelligence.partyGapRanking",
    variant: PARTY_GAP_VARIANT,
    contentKind: "party_gap_ranking",
    contentArchetype: "data_report",
    linkInReply: true,
    ownerUserId: "service_role",
  }, {
    candidateKey: `local-election:party-gap:${weekKey}`,
    candidateType: "party_gap_ranking",
    sourceKind: "local_election_snapshot",
    sourceUrls,
    createdBy: options.datasetSource,
    now: new Date(options.observedAt),
  });
  return {
    ...common,
    dataset: options.dataset,
    dataset_source: options.datasetSource,
    dataset_version: options.datasetVersion,
    snapshot_observation_id: options.snapshotObservationId,
    dataset_snapshot_hash: options.snapshotHash,
    observed_at: options.observedAt,
    requires_human_approval: true,
    auto_publish: false,
    gap_summary: {
      kokumin_total: kokuminTotal,
      cdp_total: cdpTotal,
      kokumin_lead_prefectures: kokuminLead.length,
      cdp_lead_prefectures: cdpLead.length,
      even_prefectures: even,
    },
  };
}
