import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  filterCurrentStrategyLogs,
  filterRecentLogs,
} from "./metrics_window.ts";

const NOW = Date.parse("2026-07-07T00:00:00Z");
const DAY = 86_400_000;

function log(
  createdAgoDays: number,
  checkedAt: string | null,
): { id: string; created_at: string; metadata: Record<string, unknown> } {
  return {
    id: `${createdAgoDays}-${checkedAt}`,
    created_at: new Date(NOW - createdAgoDays * DAY).toISOString(),
    metadata: checkedAt == null ? {} : { metrics_checked_at: checkedAt },
  };
}

Deno.test("filterRecentLogs keeps measured rows inside the window", () => {
  const rows = [log(3, "2026-07-06T00:00:00Z")];
  assertEquals(filterRecentLogs(rows, 7, NOW).length, 1);
});

Deno.test("filterRecentLogs drops measured rows outside the window", () => {
  const rows = [log(8, "2026-07-01T00:00:00Z")];
  assertEquals(filterRecentLogs(rows, 7, NOW).length, 0);
});

Deno.test("filterRecentLogs keeps unmeasured rows regardless of age", () => {
  // cap 停止中に生まれた古い投稿も、復旧後 1 回は必ず計測する。
  const rows = [log(30, null)];
  assertEquals(filterRecentLogs(rows, 7, NOW).length, 1);
});

Deno.test("filterRecentLogs fail-opens on unparsable created_at", () => {
  const broken = {
    id: "broken",
    created_at: "not-a-date",
    metadata: { metrics_checked_at: "2026-07-01T00:00:00Z" },
  };
  assert(filterRecentLogs([broken], 7, NOW).length === 1);
});

// R18: filterCurrentStrategyLogs — 現行コピー戦略窓で学習を測る。
const R18_NOW = Date.parse("2026-07-09T02:00:00Z");
const EPOCH = Date.parse("2026-07-05");

function logAt(iso: string): {
  id: string;
  created_at: string;
  metadata: Record<string, unknown>;
} {
  return { id: iso, created_at: iso, metadata: {} };
}

Deno.test("filterCurrentStrategyLogs excludes pre-epoch old-format posts", () => {
  const rows = [logAt("2026-07-02T00:00:00Z")]; // epoch より前
  assertEquals(
    filterCurrentStrategyLogs(rows, { windowDays: 28, epochMs: EPOCH }, R18_NOW)
      .length,
    0,
  );
});

Deno.test("filterCurrentStrategyLogs keeps a within-window current post", () => {
  const rows = [logAt("2026-07-08T00:00:00Z")];
  assertEquals(
    filterCurrentStrategyLogs(rows, { windowDays: 28, epochMs: EPOCH }, R18_NOW)
      .length,
    1,
  );
});

Deno.test("filterCurrentStrategyLogs fail-opens on unparsable created_at", () => {
  const broken = { id: "b", created_at: "not-a-date", metadata: {} };
  assertEquals(
    filterCurrentStrategyLogs(
      [broken],
      { windowDays: 28, epochMs: EPOCH },
      R18_NOW,
    ).length,
    1,
  );
});

Deno.test("filterCurrentStrategyLogs windowDays tightens beyond epoch", () => {
  // epoch は古いが window 3 日なら 07-06 より前は落とす。
  const rows = [logAt("2026-07-05T12:00:00Z"), logAt("2026-07-08T00:00:00Z")];
  assertEquals(
    filterCurrentStrategyLogs(rows, { windowDays: 3, epochMs: EPOCH }, R18_NOW)
      .length,
    1,
  );
});

Deno.test("filterCurrentStrategyLogs falls back to windowDays when epoch NaN", () => {
  const rows = [logAt("2026-07-08T00:00:00Z")];
  assertEquals(
    filterCurrentStrategyLogs(rows, { windowDays: 28, epochMs: NaN }, R18_NOW)
      .length,
    1,
  );
});
