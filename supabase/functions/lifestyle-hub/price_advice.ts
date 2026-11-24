import { extractFirstJsonObject } from "./journal_analysis.ts";

export interface PriceLogRow {
  price: unknown;
  fetched_at?: string | null;
}

export interface PriceProductInput {
  id?: unknown;
  product_name?: unknown;
  current_price?: unknown;
  target_price?: unknown;
  lowest_price?: unknown;
  highest_price?: unknown;
}

export type PriceAdviceVerdict = "buy" | "wait" | "hold";

export interface PriceAdviceStats {
  sample_count: number;
  current_price: number | null;
  target_price: number | null;
  min_price: number | null;
  max_price: number | null;
  avg_price: number | null;
  latest_log_price: number | null;
  previous_log_price: number | null;
  recent_delta_pct: number | null;
  delta_from_avg_pct: number | null;
  delta_from_target_pct: number | null;
  is_at_or_below_target: boolean;
}

export interface StructuredPriceAdvice {
  verdict: PriceAdviceVerdict;
  verdict_label: string;
  summary: string;
  reasons: string[];
  stats: PriceAdviceStats;
  grounded_on_observed_logs_only: true;
  source: "llm" | "statistical_fallback";
  cache_ttl_hours: 24;
}

export function verdictLabelFor(verdict: PriceAdviceVerdict): string {
  switch (verdict) {
    case "buy":
      return "🎯 買い時";
    case "wait":
      return "⏳ 待機推奨";
    case "hold":
      return "⚖️ 様子見";
  }
}

function toPositiveInt(value: unknown): number | null {
  if (typeof value === "number") {
    return Number.isFinite(value) && value > 0 ? Math.round(value) : null;
  }
  if (typeof value === "string") {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) && parsed > 0 ? Math.round(parsed) : null;
  }
  return null;
}

function roundOneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}

function percentDelta(current: number, baseline: number): number | null {
  if (!Number.isFinite(current) || !Number.isFinite(baseline) || baseline <= 0) {
    return null;
  }
  return roundOneDecimal(((current - baseline) / baseline) * 100);
}

export function computePriceLogStats(
  product: PriceProductInput,
  logs: readonly PriceLogRow[],
): PriceAdviceStats {
  const validLogPrices: number[] = [];
  for (const row of logs) {
    const parsed = toPositiveInt(row.price);
    if (parsed !== null) {
      validLogPrices.push(parsed);
    }
  }

  const targetPrice = toPositiveInt(product.target_price);
  const recordedCurrent = toPositiveInt(product.current_price);
  const latestLogPrice = validLogPrices.length > 0 ? validLogPrices[0] : null;
  const previousLogPrice = validLogPrices.length > 1 ? validLogPrices[1] : null;
  const currentPrice = recordedCurrent ?? latestLogPrice;

  const productLowest = toPositiveInt(product.lowest_price);
  const productHighest = toPositiveInt(product.highest_price);

  const minFromLogs = validLogPrices.length > 0
    ? Math.min(...validLogPrices)
    : null;
  const maxFromLogs = validLogPrices.length > 0
    ? Math.max(...validLogPrices)
    : null;

  const minPrice = minFromLogs !== null && productLowest !== null
    ? Math.min(minFromLogs, productLowest)
    : (minFromLogs ?? productLowest);
  const maxPrice = maxFromLogs !== null && productHighest !== null
    ? Math.max(maxFromLogs, productHighest)
    : (maxFromLogs ?? productHighest);

  const avgPrice = validLogPrices.length > 0
    ? Math.round(
      validLogPrices.reduce((sum, p) => sum + p, 0) / validLogPrices.length,
    )
    : currentPrice;

  const recentDeltaPct = latestLogPrice !== null && previousLogPrice !== null
    ? percentDelta(latestLogPrice, previousLogPrice)
    : null;
  const deltaFromAvgPct = currentPrice !== null && avgPrice !== null
    ? percentDelta(currentPrice, avgPrice)
    : null;
  const deltaFromTargetPct = currentPrice !== null && targetPrice !== null
    ? percentDelta(currentPrice, targetPrice)
    : null;
  const isAtOrBelowTarget = currentPrice !== null && targetPrice !== null &&
    currentPrice <= targetPrice;

  return {
    sample_count: validLogPrices.length,
    current_price: currentPrice,
    target_price: targetPrice,
    min_price: minPrice,
    max_price: maxPrice,
    avg_price: avgPrice,
    latest_log_price: latestLogPrice,
    previous_log_price: previousLogPrice,
    recent_delta_pct: recentDeltaPct,
    delta_from_avg_pct: deltaFromAvgPct,
    delta_from_target_pct: deltaFromTargetPct,
    is_at_or_below_target: isAtOrBelowTarget,
  };
}

function yenText(value: number | null): string {
  return value === null ? "未観測" : `¥${value.toLocaleString("en-US")}`;
}

export function buildStatisticalPriceAdviceFallback(
  product: PriceProductInput,
  stats: PriceAdviceStats,
): StructuredPriceAdvice {
  const name = String(product.product_name ?? "対象商品").trim() || "対象商品";
  const reasons: string[] = [];
  let verdict: PriceAdviceVerdict = "hold";
  let summary = "";

  if (stats.is_at_or_below_target && stats.current_price !== null) {
    verdict = "buy";
    summary =
      `目標価格 (${yenText(stats.target_price)}) 以下の ${yenText(stats.current_price)} まで下がっているため買い時です。`;
    reasons.push(
      `現在価格 ${yenText(stats.current_price)} が目標価格 ${yenText(stats.target_price)} 以下`,
    );
    if (stats.avg_price !== null && stats.delta_from_avg_pct !== null) {
      reasons.push(
        `直近${stats.sample_count}件の観測平均 ${yenText(stats.avg_price)} に対して ${stats.delta_from_avg_pct > 0 ? "+" : ""}${stats.delta_from_avg_pct}%`,
      );
    }
  } else if (
    (stats.recent_delta_pct !== null && stats.recent_delta_pct >= 8) ||
    (stats.delta_from_avg_pct !== null && stats.delta_from_avg_pct >= 10)
  ) {
    verdict = "wait";
    summary =
      `直近の観測価格が平均水準より上振れしているため待機推奨です。`;
    if (stats.recent_delta_pct !== null && stats.recent_delta_pct >= 8) {
      reasons.push(
        `前回ログ比 +${stats.recent_delta_pct}% の価格上昇を観測 (${yenText(stats.previous_log_price)} → ${yenText(stats.latest_log_price)})`,
      );
    }
    if (stats.avg_price !== null && stats.delta_from_avg_pct !== null) {
      reasons.push(
        `観測平均 ${yenText(stats.avg_price)} より ${stats.delta_from_avg_pct > 0 ? "+" : ""}${stats.delta_from_avg_pct}% 高い水準 (最安 ${yenText(stats.min_price)})`,
      );
    }
  } else if (
    stats.sample_count >= 2 &&
    stats.current_price !== null &&
    stats.min_price !== null &&
    stats.current_price <= stats.min_price
  ) {
    verdict = "buy";
    summary =
      `${name} は観測履歴 ${stats.sample_count}件中の最安値 (${yenText(stats.min_price)}) と一致しており買い時です。`;
    reasons.push(
      `現在価格 ${yenText(stats.current_price)} が観測最安値 ${yenText(stats.min_price)} に一致`,
    );
    if (stats.avg_price !== null) {
      reasons.push(`観測平均 ${yenText(stats.avg_price)} / 最高値 ${yenText(stats.max_price)}`);
    }
  } else if (
    stats.sample_count >= 2 &&
    stats.delta_from_avg_pct !== null &&
    stats.delta_from_avg_pct <= -5
  ) {
    verdict = "buy";
    summary =
      `現在価格 ${yenText(stats.current_price)} が観測平均 ${yenText(stats.avg_price)} より ${Math.abs(stats.delta_from_avg_pct)}% 安く買い時水準です。`;
    reasons.push(
      `観測平均 ${yenText(stats.avg_price)} 比 ${stats.delta_from_avg_pct}% (${stats.sample_count}件の価格ログ)`,
    );
    if (stats.target_price !== null) {
      reasons.push(`目標価格 ${yenText(stats.target_price)} との比較を維持中`);
    }
  } else {
    verdict = "hold";
    summary = stats.sample_count < 2
      ? `観測ログが ${stats.sample_count}件のため価格推移を追加記録しつつ様子見が妥当です。`
      : `現在価格 ${yenText(stats.current_price)} は観測平均 (${yenText(stats.avg_price)}) 付近で推移しており様子見推奨です。`;
    reasons.push(
      `観測統計 (${stats.sample_count}件): 最安 ${yenText(stats.min_price)} / 平均 ${yenText(stats.avg_price)} / 最高 ${yenText(stats.max_price)}`,
    );
    if (stats.target_price !== null && stats.delta_from_target_pct !== null) {
      reasons.push(
        `目標価格 ${yenText(stats.target_price)} まであと ${stats.delta_from_target_pct > 0 ? "+" : ""}${stats.delta_from_target_pct}%`,
      );
    }
  }

  return {
    verdict,
    verdict_label: verdictLabelFor(verdict),
    summary,
    reasons: reasons.slice(0, 3),
    stats,
    grounded_on_observed_logs_only: true,
    source: "statistical_fallback",
    cache_ttl_hours: 24,
  };
}

export function buildPriceAdvicePrompt(
  product: PriceProductInput,
  stats: PriceAdviceStats,
  logs: readonly PriceLogRow[],
): string {
  const series = logs
    .slice(0, 30)
    .map((l) => `${String(l.fetched_at ?? "").slice(0, 10) || "unknown"}: ${yenText(toPositiveInt(l.price))}`)
    .join(" / ");
  const avgDiffText = stats.delta_from_avg_pct === null
    ? "不明"
    : `${stats.delta_from_avg_pct > 0 ? "+" : ""}${stats.delta_from_avg_pct}%`;
  const recentDiffText = stats.recent_delta_pct === null
    ? "不明"
    : `${stats.recent_delta_pct > 0 ? "+" : ""}${stats.recent_delta_pct}%`;

  return [
    `商品名: ${String(product.product_name ?? "対象商品")}`,
    `現在価格: ${yenText(stats.current_price)}`,
    `目標価格: ${yenText(stats.target_price)}`,
    `観測統計 (${stats.sample_count}件): 最小 ${yenText(stats.min_price)} / 平均 ${yenText(stats.avg_price)} / 最大 ${yenText(stats.max_price)}`,
    `平均比: ${avgDiffText} / 直近変化率: ${recentDiffText}`,
    `直近観測ログ (最大30件): ${series || "履歴なし"}`,
    "",
    "重要制約: 上記の観測済み price_logs と記録済み価格統計のみに基づいて判断してください。未観測のセール日程・将来の値下げ予定・在庫残数・外部相場は推測して書かないでください。",
    '次の厳密なJSONオブジェクトのみを出力してください: {"verdict":"buy|wait|hold","summary":"120字以内の結論","reasons":["観測値に基づく根拠1","観測値に基づく根拠2"]}',
  ].join("\n");
}

function normalizeVerdict(raw: unknown): PriceAdviceVerdict | null {
  const value = String(raw ?? "").trim().toLowerCase();
  if (value === "buy" || value.includes("買い時")) return "buy";
  if (value === "wait" || value.includes("待機")) return "wait";
  if (value === "hold" || value.includes("様子見")) return "hold";
  return null;
}

export function coercePriceAdvice(
  rawTextOrObject: string | Record<string, unknown> | null,
  fallback: StructuredPriceAdvice,
  source: "llm" | "statistical_fallback",
): StructuredPriceAdvice {
  const parsed = typeof rawTextOrObject === "string"
    ? extractFirstJsonObject(rawTextOrObject)
    : rawTextOrObject;
  if (!parsed) {
    return { ...fallback, source };
  }

  const verdict = normalizeVerdict(parsed.verdict) ?? fallback.verdict;
  const rawSummary = String(parsed.summary ?? parsed.advice ?? "").trim();
  const summary = rawSummary.length > 0 ? rawSummary : fallback.summary;

  const rawReasons = Array.isArray(parsed.reasons)
    ? parsed.reasons
      .map((item) => String(item ?? "").trim())
      .filter((item) => item.length > 0)
      .slice(0, 3)
    : [];
  const reasons = rawReasons.length > 0 ? rawReasons : fallback.reasons;

  return {
    verdict,
    verdict_label: verdictLabelFor(verdict),
    summary,
    reasons,
    stats: fallback.stats,
    grounded_on_observed_logs_only: true,
    source,
    cache_ttl_hours: 24,
  };
}

export function formatPriceAdviceText(advice: StructuredPriceAdvice): string {
  const lines = [`${advice.verdict_label}: ${advice.summary}`];
  for (const reason of advice.reasons) {
    lines.push(`・${reason}`);
  }
  return lines.join("\n");
}
