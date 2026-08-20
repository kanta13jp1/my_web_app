import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  metricWindowLabel,
  normalizeXMetricWindows,
  selectXMetricComparisonWindow,
  X_METRIC_COMPARISON_MIN_SAMPLES,
  X_METRIC_WINDOW_SELECTION_RULE,
  type XMetricSourceRow,
} from "./x_metric_windows.ts";

const POSTED_AT = "2026-07-10T00:00:00.000Z";
const LOG: XMetricSourceRow = {
  id: "log-1",
  created_at: POSTED_AT,
  metadata: { tweet_id: "tweet-1", posted_at: POSTED_AT },
};

function snapshot(
  id: string,
  ageHours: number,
  impressions: unknown,
  overrides: Record<string, unknown> = {},
): XMetricSourceRow {
  const checkedAt = new Date(Date.parse(POSTED_AT) + ageHours * 3_600_000)
    .toISOString();
  return {
    id,
    created_at: checkedAt,
    metadata: {
      source_log_id: "log-1",
      tweet_id: "tweet-1",
      tweet_role: "lead",
      checked_at: checkedAt,
      impressions,
      bookmark_count: 4,
      profile_clicks: 2,
      ...overrides,
    },
  };
}

Deno.test("normalizes I3h/I24h/I72h with nearest snapshots", () => {
  const now = Date.parse(POSTED_AT) + 80 * 3_600_000;
  const rows = normalizeXMetricWindows(
    [LOG],
    [
      snapshot("3-before", 2.5, 100),
      snapshot("3-after", 3.5, 130),
      snapshot("24-near", 24.25, 700),
      snapshot("72-near", 71.75, 2000),
    ],
    now,
  );

  assertEquals(rows[0].i3h, 130); // equal distance: at/after wins
  assertEquals(rows[0].i24h, 700);
  assertEquals(rows[0].i72h, 2000);
  assertEquals(rows[0].windows.i3h?.sourceSnapshotId, "3-after");
  assertEquals(rows[0].windows.i24h?.distanceMinutes, 15);
  assertEquals(rows[0].windows.i24h?.bookmarkRate, 4 / 700);
  assertEquals(rows[0].windows.i24h?.profileClickRate, 2 / 700);
});

Deno.test("keeps unreached windows null even when a future snapshot is present", () => {
  const now = Date.parse(POSTED_AT) + 23 * 3_600_000;
  const [row] = normalizeXMetricWindows(
    [LOG],
    [snapshot("3", 3, 100), snapshot("future-24", 24, 999)],
    now,
  );
  assertEquals(row.i3h, 100);
  assertEquals(row.i24h, null);
  assertEquals(row.i72h, null);
});

Deno.test("uses lead snapshots only and rejects mismatched tweets", () => {
  const now = Date.parse(POSTED_AT) + 30 * 3_600_000;
  const [row] = normalizeXMetricWindows(
    [LOG],
    [
      snapshot("reply", 24, 9000, { tweet_role: "reply" }),
      snapshot("other-tweet", 24, 8000, { tweet_id: "tweet-2" }),
      snapshot("lead", 24.5, 600),
    ],
    now,
  );
  assertEquals(row.i24h, 600);
});

Deno.test("rejects stale, malformed, negative, and future-dated snapshots", () => {
  const now = Date.parse(POSTED_AT) + 30 * 3_600_000;
  const [row] = normalizeXMetricWindows(
    [LOG],
    [
      snapshot("stale", 30, 5000), // >2h from I24
      snapshot("negative", 24, -1),
      snapshot("nan", 24, "not-a-number"),
      snapshot("future", 31, 9000),
    ],
    now,
  );
  assertEquals(row.i24h, null);
});

Deno.test("falls back from invalid posted_at to valid log created_at", () => {
  const log = {
    ...LOG,
    metadata: { tweet_id: "tweet-1", posted_at: "broken" },
  };
  const now = Date.parse(POSTED_AT) + 4 * 3_600_000;
  const [row] = normalizeXMetricWindows([log], [snapshot("3", 3, 80)], now);
  assertEquals(row.postedAt, POSTED_AT);
  assertEquals(row.i3h, 80);
});

Deno.test("invalid log dates fail closed without throwing", () => {
  const [row] = normalizeXMetricWindows(
    [{ id: "bad", created_at: "broken", metadata: {} }],
    [snapshot("3", 3, 80)],
    Date.parse(POSTED_AT) + 80 * 3_600_000,
  );
  assertEquals(row.postedAt, null);
  assertEquals(row.i3h, null);
  assertEquals(row.i24h, null);
  assertEquals(row.i72h, null);
});

Deno.test("comparison cohort prioritizes I24, then I72, then I3", () => {
  const base = normalizeXMetricWindows(
    [LOG],
    [snapshot("3", 3, 100)],
    Date.parse(POSTED_AT) + 4 * 3_600_000,
  )[0];
  assertEquals(selectXMetricComparisonWindow([base]), null);
  const three = (row: typeof base) => [row, { ...row }, { ...row }];
  assertEquals(selectXMetricComparisonWindow(three(base)), "i3h");
  assertEquals(
    selectXMetricComparisonWindow(three({ ...base, i72h: 900 })),
    "i72h",
  );
  assertEquals(
    selectXMetricComparisonWindow(
      three({ ...base, i24h: 400, i72h: 900 }),
    ),
    "i24h",
  );
  assertEquals(X_METRIC_COMPARISON_MIN_SAMPLES, 3);
  assertEquals(metricWindowLabel("i24h"), "I24h");
  assert(X_METRIC_WINDOW_SELECTION_RULE.includes("lead only"));
});

Deno.test("comparison cohort skips a sparse I24 window for a mature I72 cohort", () => {
  const base = normalizeXMetricWindows(
    [LOG],
    [snapshot("3", 3, 100)],
    Date.parse(POSTED_AT) + 4 * 3_600_000,
  )[0];
  const rows = [
    { ...base, i24h: 500, i72h: 900 },
    { ...base, i24h: null, i72h: 800 },
    { ...base, i24h: null, i72h: 700 },
  ];
  assertEquals(selectXMetricComparisonWindow(rows), "i72h");
});
