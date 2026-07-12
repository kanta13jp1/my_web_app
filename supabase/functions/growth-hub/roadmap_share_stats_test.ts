import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  canReadRoadmapShareStats,
  parseRoadmapCounts,
  type RoadmapPlan,
  selectShareableRoadmapPlans,
} from "./roadmap_share_stats.ts";

Deno.test("roadmap share stats are owner/admin only", () => {
  assertEquals(canReadRoadmapShareStats("service_role", false), true);
  assertEquals(canReadRoadmapShareStats("admin-user", true), true);
  assertEquals(canReadRoadmapShareStats("regular-user", false), false);
});

Deno.test("verified source counts preserve legitimate zero and reject defaults", () => {
  assertEquals(parseRoadmapCounts(0, 0), {
    userCount: 0,
    achievementsCount: 0,
  });
  assertThrows(() => parseRoadmapCounts(undefined, 0));
  assertThrows(() => parseRoadmapCounts(2, null));
  assertThrows(() => parseRoadmapCounts(-1, 3));
  assertThrows(() => parseRoadmapCounts(1.5, 3));
});

Deno.test("shareable plans are allowlisted and deterministically ordered", () => {
  const plan = (label: string): RoadmapPlan => ({
    label,
    deadline: "2026年08月01日",
    target: 100,
    features_done: 10,
    features_total: 20,
  });
  const selected = selectShareableRoadmapPlans([
    plan("vs Internal Competitor"),
    plan("長期計画"),
    plan("短期計画"),
    plan("中期計画"),
  ]);
  assertEquals(selected.map((entry) => entry.label), [
    "短期計画",
    "中期計画",
    "長期計画",
  ]);
});
