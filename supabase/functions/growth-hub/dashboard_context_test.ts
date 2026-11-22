import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildDashboardContext,
  type DashboardSectionKey,
  DEFAULT_DASHBOARD_CANDIDATE_STATUSES,
  normalizeCandidateBatchStatuses,
  X_OPERATOR_FORBIDDEN_REASON,
} from "./dashboard_context.ts";

Deno.test("buildDashboardContext returns all 4 sections for X operator", async () => {
  const called: string[] = [];
  const result = await buildDashboardContext({
    isXOperator: true,
    loaders: {
      loadXTodayStatus: () => {
        called.push("xTodayStatus");
        return Promise.resolve({ success: true, available: true, postedTodayCount: 1 });
      },
      loadXPerformanceContext: () => {
        called.push("xPerformanceContext");
        return Promise.resolve({ success: true, rows: [] });
      },
      loadXCandidateList: () => {
        called.push("xCandidateList");
        return Promise.resolve({ success: true, byStatus: { approved: { candidates: [], total: 0 } } });
      },
      loadAchievementList: () => {
        called.push("achievementList");
        return Promise.resolve({ success: true, items: [{ id: "a1" }] });
      },
    },
  });

  assertEquals(result.success, true);
  assertEquals(result.isXOperator, true);
  assertEquals(result.xTodayStatus, {
    success: true,
    available: true,
    postedTodayCount: 1,
  });
  assertEquals(result.xPerformanceContext, { success: true, rows: [] });
  assertEquals(result.xCandidateList, {
    success: true,
    byStatus: { approved: { candidates: [], total: 0 } },
  });
  assertEquals(result.achievementList, { success: true, items: [{ id: "a1" }] });
  assertEquals(result.errors, {});
  assertEquals(called.sort(), [
    "achievementList",
    "xCandidateList",
    "xPerformanceContext",
    "xTodayStatus",
  ]);
});

Deno.test("buildDashboardContext degrades only xCandidateList for non-X-operator", async () => {
  let candidateLoaderCalled = false;
  const result = await buildDashboardContext({
    isXOperator: false,
    loaders: {
      loadXTodayStatus: () =>
        Promise.resolve({ success: true, available: true, postedTodayCount: 0 }),
      loadXPerformanceContext: () =>
        Promise.resolve({ success: true, rows: [{ id: "p1" }] }),
      loadXCandidateList: () => {
        candidateLoaderCalled = true;
        return Promise.resolve({ success: true, byStatus: {} });
      },
      loadAchievementList: () =>
        Promise.resolve({ success: true, items: [{ id: "a1" }] }),
    },
  });

  assertEquals(candidateLoaderCalled, false);
  assertEquals(result.success, true);
  assertEquals(result.isXOperator, false);
  assertEquals(result.xCandidateList, null);
  assertEquals(result.errors, {
    xCandidateList: {
      code: "forbidden",
      reason: X_OPERATOR_FORBIDDEN_REASON,
    },
  });
  assertEquals(result.xTodayStatus, {
    success: true,
    available: true,
    postedTodayCount: 0,
  });
  assertEquals(result.xPerformanceContext, {
    success: true,
    rows: [{ id: "p1" }],
  });
  assertEquals(result.achievementList, {
    success: true,
    items: [{ id: "a1" }],
  });
});

Deno.test("buildDashboardContext isolates runtime failure in one section", async () => {
  const reported: Array<{ section: DashboardSectionKey; message: string }> = [];
  const result = await buildDashboardContext({
    isXOperator: true,
    loaders: {
      loadXTodayStatus: () =>
        Promise.resolve({ success: true, available: true }),
      loadXPerformanceContext: () =>
        Promise.reject(new Error("db timeout")),
      loadXCandidateList: () =>
        Promise.resolve({ success: true, candidates: [], total: 0 }),
      loadAchievementList: () =>
        Promise.resolve({ success: true, items: [] }),
    },
    onSectionError: (section, error) => {
      reported.push({
        section,
        message: error instanceof Error ? error.message : String(error),
      });
    },
  });

  assertEquals(result.success, true);
  assertEquals(result.xPerformanceContext, null);
  assertEquals(result.errors, {
    xPerformanceContext: {
      code: "unavailable",
      reason: "xPerformanceContext_unavailable",
    },
  });
  assertEquals(reported, [
    { section: "xPerformanceContext", message: "db timeout" },
  ]);
  assertEquals(result.xTodayStatus, { success: true, available: true });
  assertEquals(result.xCandidateList, {
    success: true,
    candidates: [],
    total: 0,
  });
  assertEquals(result.achievementList, { success: true, items: [] });
});

Deno.test("buildDashboardContext combines non-X-operator forbidden with section unavailable", async () => {
  const result = await buildDashboardContext({
    isXOperator: false,
    loaders: {
      loadXTodayStatus: () =>
        Promise.resolve({ success: true, available: true }),
      loadXPerformanceContext: () =>
        Promise.resolve({ success: true, rows: [] }),
      loadXCandidateList: () =>
        Promise.resolve({ success: true, byStatus: {} }),
      loadAchievementList: () =>
        Promise.reject(new Error("achievement query failed")),
    },
  });

  assertEquals(result.success, true);
  assertEquals(result.isXOperator, false);
  assertEquals(result.xCandidateList, null);
  assertEquals(result.achievementList, null);
  assertEquals(result.errors, {
    xCandidateList: {
      code: "forbidden",
      reason: X_OPERATOR_FORBIDDEN_REASON,
    },
    achievementList: {
      code: "unavailable",
      reason: "achievementList_unavailable",
    },
  });
  assertEquals(result.xTodayStatus, { success: true, available: true });
  assertEquals(result.xPerformanceContext, { success: true, rows: [] });
});

Deno.test("normalizeCandidateBatchStatuses deduplicates, caps, supports single status, and falls back to defaults", () => {
  assertEquals(
    normalizeCandidateBatchStatuses(
      [
        " pending_approval ",
        "approved",
        "pending_approval",
        "",
        "s4",
        "s5",
        "s6",
        "s7",
        "s8",
        "s9",
        "s10",
        "s11",
        "s12",
      ],
      "ignored",
    ),
    {
      mode: "batch",
      statuses: [
        "pending_approval",
        "approved",
        "s4",
        "s5",
        "s6",
        "s7",
        "s8",
        "s9",
        "s10",
        "s11",
      ],
    },
  );

  assertEquals(normalizeCandidateBatchStatuses(undefined, " approved "), {
    mode: "single",
    status: "approved",
  });

  assertEquals(normalizeCandidateBatchStatuses([], " publish_failed "), {
    mode: "single",
    status: "publish_failed",
  });

  assertEquals(normalizeCandidateBatchStatuses(undefined, undefined), {
    mode: "batch",
    statuses: [...DEFAULT_DASHBOARD_CANDIDATE_STATUSES],
  });
});
