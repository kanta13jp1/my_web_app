// R24: ポストA型「独自データ資産」の家計/build-in-public 版。2026-07-12 実測で
// データレポート型(独自集計の実数を密に並べる)が 3.2K imp とニュース要約(517)
// ・製品転換(28)を 6-114 倍上回った。このモジュールは x_post_log の実測値
// **のみ**から、ポストAと同じ構造(取得日時→主要実数→基準との差分→内訳→
// 増加履歴→アラート)の X 投稿パッケージを決定的に組み立てる。LLM を使わない
// (=ポストA自体がテンプレ生成だったことを踏襲。数値の捏造が構造的に不可能)。
//
// 数値の出所は全て perf rows(x_post_log 由来の実測)。実測 3 件未満の週は
// null を返して投稿自体を見送る(薄いデータで「実測レポート」を名乗らない)。

import { computeOwnDataFacts } from "./x_post_archetype.ts";

/// buildXPerformanceContextFromLogs が返す rows の、このレポートが使う部分形。
export type GrowthReportRow = {
  archetype: string;
  variant: string;
  impressions: number | null;
  score: number;
  bookmarkCount: number;
  text: string;
  createdAt: string;
};

export type GrowthDataReport = {
  text: string;
  replyTexts: string[];
  measuredCount: number;
  medianImpressions: number;
  bestImpressions: number;
};

const IMPRESSION_TARGET = 10000;

function jstDateLabel(now: Date): string {
  const jst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  return `${jst.getUTCFullYear()}/${jst.getUTCMonth() + 1}/${jst.getUTCDate()}`;
}

function compactHook(text: string, max = 48): string {
  const clean = (text ?? "").replace(/\s+/g, " ").trim();
  return clean.length <= max ? clean : `${clean.slice(0, max - 1)}…`;
}

/// x_post_log の実測 rows からポストA型の週次実測レポートを組み立てる。
/// 実測(impressions 非 null)3 件未満は null(投稿見送り)。
export function buildGrowthDataReport(
  rows: readonly GrowthReportRow[],
  now: Date,
  targetUrl: string,
): GrowthDataReport | null {
  const facts = computeOwnDataFacts(rows, (row) => row.impressions);
  if (facts === null) return null;

  const weekAgoMs = now.getTime() - 7 * 24 * 60 * 60 * 1000;
  const recent7 = rows.filter((row) => {
    const created = Date.parse(row.createdAt);
    return Number.isFinite(created) && created >= weekAgoMs;
  }).length;

  // 実測上位(リードの可変トークン+リプの内訳で使う)。
  const top = rows
    .filter((row) => typeof row.impressions === "number")
    .sort((a, b) => (b.impressions ?? 0) - (a.impressions ?? 0))
    .slice(0, 3);

  // リード: ポストAと同じ「取得日時→主要実数→基準との差分→残り」の骨格。
  // 「基準10,000との差分」の語形は classifyPostArchetype の強シグナルと一致
  // させ、このレポート自身が data_report に分類されることを保証する。
  // 「今週の実測トップ」行はリード唯一の自由テキスト=週替わりの可変トークン。
  // 固定テンプレ+数字だけだと前週リードとの正規化類似度が近似重複ガードの
  // 閾値(0.9)を超え得る(レビュー実測 0.93-0.95)。それでも統計が完全に
  // 横ばいの週はガードに拒否させ、workflow 側で「変化なし週はスキップ」として
  // 正常終了する(重複投稿しないのが正しい挙動)。
  const gap = IMPRESSION_TARGET - facts.best;
  const lead = [
    `自分株式会社 X運用実測レポート ${jstDateLabel(now)}`,
    "",
    `取得日時: ${now.toISOString()}`,
    `計測済み投稿数: ${facts.count}件`,
    `中央値インプレッション: ${facts.median}`,
    `最高インプレッション: ${facts.best}`,
    `基準10,000との差分: ${gap > 0 ? `-${gap}` : `+${-gap}`}`,
    `10,000まで残り: ${Math.max(0, gap)}`,
    `直近7日の計測対象: ${recent7}件`,
    ...(top.length > 0
      ? [
        `今週の実測トップ: ${top[0].impressions} — 「${
          compactHook(top[0].text)
        }」`,
      ]
      : []),
    "",
    "数字は全て自分のX投稿ログの実測値。集計はアプリが自動生成しています。",
  ].join("\n");

  const replies: string[] = [];

  // 型別実測(アーキタイプ内訳)。集計行ビルダーを再利用しつつ、表向きは
  // 日本語の内訳リストで出す。
  const buckets = new Map<string, { total: number; n: number }>();
  for (const row of rows) {
    const key = row.archetype || "unknown";
    const current = buckets.get(key) ?? { total: 0, n: 0 };
    current.total += row.score;
    current.n += 1;
    buckets.set(key, current);
  }
  const bucketLabel: Record<string, string> = {
    data_report: "データレポート型",
    news_briefing: "ニュース要約型",
    product_promo: "製品紹介型",
    general: "その他",
    unknown: "分類前(旧ログ)",
  };
  const bucketLines = [...buckets.entries()]
    .sort((a, b) => b[1].total / b[1].n - a[1].total / a[1].n)
    .map(([key, { total, n }]) => {
      const label = bucketLabel[key] ?? key;
      const avg = Math.round(total / Math.max(1, n));
      return n >= 2
        ? `${label} 平均スコア${avg} (${n}件)`
        : `${label} 実測不足 (${n}件)`;
    });
  if (bucketLines.length > 0) {
    replies.push(["投稿の型別実測", "", ...bucketLines].join("\n"));
  }

  // 実測上位(増加履歴に相当)。impressions のある行だけを上位3件。
  if (top.length > 0) {
    replies.push(
      [
        "インプレッション上位",
        "",
        ...top.map((row) =>
          `${row.impressions} — 「${compactHook(row.text)}」`
        ),
      ].join("\n"),
    );
  }

  // アラート(実測から機械的に導出できるものだけ)。
  const alerts: string[] = [];
  if (recent7 === 0) {
    alerts.push("🔴 直近7日の計測対象が0件(投稿または計測が止まっています)");
  }
  const thinBuckets = [...buckets.entries()]
    .filter(([key, { n }]) => key !== "unknown" && n < 2)
    .map(([key]) => bucketLabel[key] ?? key);
  if (thinBuckets.length > 0) {
    alerts.push(`🟡 実測不足の型: ${thinBuckets.join("、")}`);
  }
  const fallbackCount =
    rows.filter((row) => row.variant.endsWith("_fallback")).length;
  if (rows.length > 0 && fallbackCount * 2 >= rows.length) {
    alerts.push(
      `🟡 定型文フォールバック比率が高い: ${fallbackCount}/${rows.length}件`,
    );
  }
  replies.push(
    ["アラート", "", ...(alerts.length > 0 ? alerts : ["今週のアラートなし"])]
      .join("\n"),
  );

  // 最終リプライ: URL は実測の勝ち構造(link-in-reply)に従い末尾のみ。
  replies.push(
    [
      "この実測レポートは毎週、アプリのX投稿ログから自動集計しています。",
      "同じ「実測を並べる」仕組みを家計側では給料日サイクルと負債トレンドが担います。",
      targetUrl,
    ].join("\n"),
  );

  return {
    text: lead,
    replyTexts: replies,
    measuredCount: facts.count,
    medianImpressions: facts.median,
    bestImpressions: facts.best,
  };
}
