import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type AiCostMonitorDb,
  handleAiCostAction,
  type HubUsageRecord,
} from "./ai_cost_monitor.ts";

class InMemoryAiCostDb implements AiCostMonitorDb {
  readonly usageByUser = new Map<string, HubUsageRecord[]>();
  readonly alertsByUser = new Map<string, HubUsageRecord[]>();
  private seq = 1;

  listUsageRows(userId: string, limit: number): Promise<HubUsageRecord[]> {
    const rows = this.usageByUser.get(userId) ?? [];
    return Promise.resolve(rows.slice(0, limit));
  }

  insertUsageRow(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubUsageRecord> {
    const row: HubUsageRecord = {
      id: `usage-${this.seq++}`,
      metadata: { ...metadata, user_id: userId },
      created_at: String(metadata.recorded_at ?? "2026-11-26T00:00:00Z"),
    };
    const rows = this.usageByUser.get(userId) ?? [];
    rows.unshift(row);
    this.usageByUser.set(userId, rows);
    return Promise.resolve(row);
  }

  listBudgetAlertRows(
    userId: string,
    limit: number,
  ): Promise<HubUsageRecord[]> {
    const rows = this.alertsByUser.get(userId) ?? [];
    return Promise.resolve(rows.slice(0, limit));
  }

  insertBudgetAlertRow(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<HubUsageRecord> {
    const row: HubUsageRecord = {
      id: `alert-${this.seq++}`,
      metadata: { ...metadata, user_id: userId },
      created_at: String(metadata.recorded_at ?? "2026-11-26T00:00:00Z"),
    };
    const rows = this.alertsByUser.get(userId) ?? [];
    rows.unshift(row);
    this.alertsByUser.set(userId, rows);
    return Promise.resolve(row);
  }
}

Deno.test("ai_cost actions require authenticated userId", async () => {
  const db = new InMemoryAiCostDb();
  const res = await handleAiCostAction({
    action: "ai_cost.daily_summary",
    body: {},
    userId: "",
    db,
  });
  assertEquals(res.status, 401);
});

Deno.test("records usage, preserves unpriced null, isolates user", async () => {
  const db = new InMemoryAiCostDb();
  const fixedNow = () => new Date("2026-11-26T10:00:00Z");

  const r1 = await handleAiCostAction({
    action: "ai_cost.record_usage",
    body: {
      model: "gpt-4o",
      input_units: 1_000_000,
      output_units: 500_000,
      action_name: "hold_board_meeting",
    },
    userId: "user-a",
    db,
    now: fixedNow,
  });
  assertEquals(r1.status, 201);
  assertEquals(
    (r1.body.estimate as Record<string, unknown>).estimated_cost_usd,
    7.5,
  );

  const r2 = await handleAiCostAction({
    action: "ai_cost.record_usage",
    body: {
      model: "unknown-experimental-v1",
      input_units: 20_000,
      output_units: 10_000,
      action_name: "experiment",
    },
    userId: "user-a",
    db,
    now: fixedNow,
  });
  assertEquals(r2.status, 201);
  assertEquals(
    (r2.body.estimate as Record<string, unknown>).known_pricing,
    false,
  );
  assertEquals(
    (r2.body.estimate as Record<string, unknown>).estimated_cost_usd,
    null,
  );

  const summaryA = await handleAiCostAction({
    action: "ai_cost.daily_summary",
    body: { target_date: "2026-11-26" },
    userId: "user-a",
    db,
    now: fixedNow,
  });
  assertEquals(summaryA.status, 200);
  assertEquals(summaryA.body.total_calls, 2);
  assertEquals(summaryA.body.known_cost_calls, 1);
  assertEquals(summaryA.body.unpriced_call_count, 1);
  assertEquals(summaryA.body.total_cost_usd, 7.5);

  const summaryB = await handleAiCostAction({
    action: "ai_cost.daily_summary",
    body: { target_date: "2026-11-26" },
    userId: "user-b",
    db,
    now: fixedNow,
  });
  assertEquals(summaryB.status, 200);
  assertEquals(summaryB.body.total_calls, 0);
});

Deno.test("check_budget logs alert and fails open on GitHub API", async () => {
  const db = new InMemoryAiCostDb();
  const fixedNow = () => new Date("2026-11-26T12:00:00Z");

  await handleAiCostAction({
    action: "ai_cost.record_usage",
    body: {
      model: "claude-sonnet-4-5",
      input_units: 1_000_000,
      output_units: 200_000,
      action_name: "summarize",
    },
    userId: "user-a",
    db,
    now: fixedNow,
  });

  const postedBodies: string[] = [];
  const checkRes = await handleAiCostAction({
    action: "ai_cost.check_budget",
    body: {
      target_date: "2026-11-26",
      budget_threshold_usd: 5.0,
    },
    userId: "user-a",
    db,
    now: fixedNow,
    getEnv: (key) => {
      if (key === "GITHUB_" + "TOKEN") return "gh-stub";
      return undefined;
    },
    fetcher: (_url, init) => {
      postedBodies.push(String(init?.body ?? ""));
      return Promise.resolve(
        new Response(
          JSON.stringify({
            number: 9991,
            html_url: "https://github.com/kanta13jp1/my_web_app/issues/9991",
          }),
          { status: 201 },
        ),
      );
    },
  });
  assertEquals(checkRes.status, 200);
  assertEquals(checkRes.body.threshold_exceeded, true);
  assertEquals(checkRes.body.daily_cost_usd, 6.0);
  assertEquals(checkRes.body.exceeded_by_usd, 1.0);
  assertEquals(checkRes.body.alert_recorded, true);
  assertEquals(postedBodies.length, 1);
  assertStringIncludes(postedBodies[0], "cost-alert");

  const ghResult = checkRes.body.github_result as Record<string, unknown>;
  assertEquals(ghResult.status, "created");
  assertEquals(ghResult.issue_number, 9991);

  const failOpenRes = await handleAiCostAction({
    action: "ai_cost.check_budget",
    body: {
      target_date: "2026-11-26",
      budget_threshold_usd: 5.0,
    },
    userId: "user-a",
    db,
    now: fixedNow,
    getEnv: () => undefined,
  });
  assertEquals(failOpenRes.status, 200);
  assertEquals(
    (failOpenRes.body.github_result as Record<string, unknown>).status,
    "skipped_no_token",
  );
});
