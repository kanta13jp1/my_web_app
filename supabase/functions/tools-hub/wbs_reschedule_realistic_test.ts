import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildWbsReschedulePlan } from "./wbs_reschedule_realistic.ts";

const today = new Date("2026-05-16T00:00:00.000Z");

function task(
  id: string,
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    id,
    category: "Backlog",
    title: `Task ${id}`,
    status: "pending",
    priority: "medium",
    category_order: 10,
    ...overrides,
  };
}

Deno.test("keeps pinned asset-management issue schedule after issue sync", () => {
  const plan = buildWbsReschedulePlan(
    [
      task("asset-2448", {
        title:
          "[Issue #2448] [\u8ffd\u52a0\u8981\u671b] Supabase sync conflict UI",
        github_issue_number: 2448,
        github_issue_state: "OPEN",
        priority: "high",
      }),
    ],
    {},
    today,
  );

  assertEquals(plan.updates.length, 1);
  assertEquals(plan.updates[0].tier, "pinned");
  assertEquals(plan.updates[0].schedule_source, "pinned");
  assertEquals(plan.updates[0].start_date, "2026-05-17");
  assertEquals(plan.updates[0].end_date, "2026-05-18");
});

Deno.test("does not place a large feature-request queue on one day", () => {
  const tasks = Array.from(
    { length: 5 },
    (_, index) =>
      task(`feature-${index}`, {
        category: "\u30e6\u30fc\u30b6\u30fc\u8981\u671b",
        title: `\u8ffd\u52a0\u8981\u671b ${index}`,
      }),
  );
  const plan = buildWbsReschedulePlan(tasks, {
    feature_request_offset_days: 0,
    feature_request_duration_days: 0,
    feature_request_parallel_capacity: 2,
  }, today);

  const startCounts = new Map<string, number>();
  for (const update of plan.updates) {
    startCounts.set(
      update.start_date,
      (startCounts.get(update.start_date) ?? 0) + 1,
    );
  }

  assertEquals(plan.byPriority.feature_request.count, 5);
  assert(startCounts.size > 1);
  assert([...startCounts.values()].every((count) => count <= 2));
});

Deno.test("schedules unpinned backlog after the pinned roadmap window", () => {
  const plan = buildWbsReschedulePlan([
    task("asset-2508", {
      title: "[Issue #2508] Memory/disk hygiene KPI dashboard",
      github_issue_number: 2508,
      github_issue_state: "OPEN",
    }),
    task("feature-after-pinned", {
      category: "\u30e6\u30fc\u30b6\u30fc\u8981\u671b",
      title: "\u8ffd\u52a0\u8981\u671b later feature",
    }),
  ], {
    feature_request_offset_days: 0,
    feature_request_duration_days: 0,
    feature_request_parallel_capacity: 2,
  }, today);

  const feature = plan.updates.find((update) =>
    update.id === "feature-after-pinned"
  );
  assert(feature);
  assertEquals(feature.start_date, "2026-08-12");
});

Deno.test("spreads unpinned GitHub issues with realistic default capacity", () => {
  const tasks = Array.from({ length: 5 }, (_, index) =>
    task(`issue-${index}`, {
      title: `[Issue #30${index}] ordinary issue`,
      github_issue_number: 300 + index,
      github_issue_state: "OPEN",
    }));
  const plan = buildWbsReschedulePlan(tasks, {}, today);

  const githubUpdates = plan.updates.filter((update) =>
    update.tier === "github_issue"
  );
  assertEquals(githubUpdates.length, 5);
  assertEquals(githubUpdates[0].start_date, "2026-05-16");
  assertEquals(githubUpdates[2].start_date, "2026-05-17");
  assertEquals(plan.params.github_issue.parallel_capacity, 2);
});

Deno.test("issue-backed feature requests use the GitHub issue lane", () => {
  const plan = buildWbsReschedulePlan(
    [
      task("issue-feature-2528", {
        title:
          "[Issue #2528] [\u8ffd\u52a0\u8981\u671b] Keep WBS schedule realistic after issue sync",
        github_issue_number: 2528,
        github_issue_state: "OPEN",
        category: "\u30e6\u30fc\u30b6\u30fc\u8981\u671b",
      }),
    ],
    {},
    today,
  );

  assertEquals(plan.updates.length, 1);
  assertEquals(plan.updates[0].tier, "github_issue");
  assertEquals(plan.byPriority.feature_request, undefined);
});
