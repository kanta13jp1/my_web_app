import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildPriceAdvicePrompt,
  buildStatisticalPriceAdviceFallback,
  coercePriceAdvice,
  computePriceLogStats,
  formatPriceAdviceText,
} from "./price_advice.ts";

Deno.test("computePriceLogStats computes min max avg and deltas from valid rows", () => {
  const stats = computePriceLogStats(
    {
      product_name: "Noise Canceling Headphones",
      current_price: 24000,
      target_price: 25000,
      lowest_price: 22000,
      highest_price: 30000,
    },
    [
      { price: 24000, fetched_at: "2026-11-24T00:00:00Z" },
      { price: 26000, fetched_at: "2026-11-20T00:00:00Z" },
      { price: 28000, fetched_at: "2026-11-10T00:00:00Z" },
      { price: -10, fetched_at: "2026-11-01T00:00:00Z" },
    ],
  );

  assertEquals(stats.sample_count, 3);
  assertEquals(stats.min_price, 22000);
  assertEquals(stats.max_price, 30000);
  assertEquals(stats.avg_price, 26000);
  assertEquals(stats.is_at_or_below_target, true);
  assertEquals(stats.delta_from_avg_pct, -7.7);
  assertEquals(stats.recent_delta_pct, -7.7);
});

Deno.test("buildStatisticalPriceAdviceFallback returns wait on recent price spike", () => {
  const product = {
    product_name: "Mechanical Keyboard",
    current_price: 16500,
    target_price: 13000,
    lowest_price: 12800,
    highest_price: 16500,
  };
  const stats = computePriceLogStats(product, [
    { price: 16500, fetched_at: "2026-11-24T00:00:00Z" },
    { price: 14000, fetched_at: "2026-11-21T00:00:00Z" },
    { price: 13800, fetched_at: "2026-11-18T00:00:00Z" },
  ]);
  const fallback = buildStatisticalPriceAdviceFallback(product, stats);

  assertEquals(fallback.verdict, "wait");
  assertEquals(fallback.verdict_label, "⏳ 待機推奨");
  assertEquals(fallback.grounded_on_observed_logs_only, true);
  assertEquals(fallback.reasons.length > 0, true);
});

Deno.test("buildPriceAdvicePrompt includes stats and observed-only guardrail", () => {
  const product = {
    product_name: "4K Monitor",
    current_price: 49800,
    target_price: 45000,
    lowest_price: 44800,
    highest_price: 55000,
  };
  const logs = [
    { price: 49800, fetched_at: "2026-11-24T00:00:00Z" },
    { price: 50200, fetched_at: "2026-11-22T00:00:00Z" },
  ];
  const stats = computePriceLogStats(product, logs);
  const prompt = buildPriceAdvicePrompt(product, stats, logs);

  assertEquals(prompt.includes("観測統計 (2件)"), true);
  assertEquals(prompt.includes("平均 ¥50,000"), true);
  assertEquals(
    prompt.includes("未観測のセール日程・将来の値下げ予定・在庫残数・外部相場は推測して書かないでください"),
    true,
  );
});

Deno.test("coercePriceAdvice parses prose-wrapped JSON and preserves fallback on invalid input", () => {
  const product = {
    product_name: "Coffee Grinder",
    current_price: 8900,
    target_price: 9000,
  };
  const stats = computePriceLogStats(product, [
    { price: 8900, fetched_at: "2026-11-24T00:00:00Z" },
    { price: 9800, fetched_at: "2026-11-19T00:00:00Z" },
  ]);
  const fallback = buildStatisticalPriceAdviceFallback(product, stats);

  const parsed = coercePriceAdvice(
    '分析結果:\n```json\n{"verdict":"buy","summary":"目標価格を下回っており買い時です。","reasons":["観測最安値に到達","平均より9%安い"]}\n```',
    fallback,
    "llm",
  );
  assertEquals(parsed.verdict, "buy");
  assertEquals(parsed.verdict_label, "🎯 買い時");
  assertEquals(parsed.reasons.length, 2);
  assertEquals(parsed.source, "llm");
  assertEquals(formatPriceAdviceText(parsed).includes("🎯 買い時"), true);

  const degraded = coercePriceAdvice("not valid json", fallback, "llm");
  assertEquals(degraded.verdict, fallback.verdict);
  assertEquals(degraded.reasons, fallback.reasons);
});
