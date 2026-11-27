import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  aggregateGrowthSummaryCounts,
  GROWTH_SUMMARY_METRIC_LABELS,
  normalizeSinceUtcIso,
} from "./growth_achievement_summary.ts";

Deno.test(
  "normalizeSinceUtcIso normalizes local ISO without Z and ms to UTC",
  () => {
    const localIso = normalizeSinceUtcIso("2026-11-26T00:00:00.123");
    assertEquals(localIso.sinceUtcIso, "2026-11-26T00:00:00.123Z");
    assertEquals(localIso.sinceDateKey, "2026-11-26");

    const zonedIso = normalizeSinceUtcIso("2026-11-26T09:00:00+09:00");
    assertEquals(zonedIso.sinceUtcIso, "2026-11-26T00:00:00.000Z");
    assertEquals(zonedIso.sinceDateKey, "2026-11-26");

    const fallback = normalizeSinceUtcIso("not-a-date");
    assertEquals(fallback.sinceUtcIso, "2020-01-01T00:00:00.000Z");
    assertEquals(GROWTH_SUMMARY_METRIC_LABELS.newUsers, "New Users");
  },
);

Deno.test(
  "aggregateGrowthSummaryCounts sums touch/share and import_preview keys",
  () => {
    const payload = aggregateGrowthSummaryCounts({
      newUsers: 4,
      totalUsersEver: 42,
      referralsCompleted: 3,
      label: "今週",
      analyticsRows: [
        {
          source_details: {
            touch_lp: 5,
            share_x: 2,
            import_preview_notion: 3,
            import_preview_evernote: 1,
            unrelated_key: 99,
          },
        },
        {
          source_details: {
            touch_comparison: 4,
            import_preview_markdown: 2,
          },
        },
      ],
    });

    assertEquals(payload.success, true);
    assertEquals(payload.newUsers, 4);
    assertEquals(payload.totalUsersEver, 42);
    assertEquals(payload.acquisitionSignals, 11);
    assertEquals(payload.referralsCompleted, 3);
    assertEquals(payload.importPreviews, 6);
    assertEquals(payload.label, "今週");
  },
);
