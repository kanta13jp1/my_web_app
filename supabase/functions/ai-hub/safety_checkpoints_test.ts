import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type GitHubIssueCommentEntry,
  handleSafetyCheckpointAction,
  type SafetyCheckpointDb,
  type SafetyCheckpointDbQuery,
} from "./safety_checkpoints.ts";

class InMemorySafetyCheckpointDb implements SafetyCheckpointDb {
  readonly profiles = new Map<string, Record<string, unknown>>();
  readonly rows: Record<string, unknown>[] = [];
  private seqCounter = 1;

  from(table: string): SafetyCheckpointDbQuery {
    const filters: Array<{ column: string; value: unknown }> = [];
    let orderColumn: string | null = null;
    let orderAscending = true;

    const matchRows = () => {
      const source = table === "user_profiles"
        ? Array.from(this.profiles.values())
        : this.rows;
      let filtered = source.filter((row) =>
        filters.every((filter) => row[filter.column] === filter.value)
      );
      if (orderColumn) {
        const col = orderColumn;
        filtered = [...filtered].sort((a, b) => {
          const av = a[col];
          const bv = b[col];
          const cmp = String(av ?? "").localeCompare(String(bv ?? ""));
          return orderAscending ? cmp : -cmp;
        });
      }
      return filtered;
    };

    const query: SafetyCheckpointDbQuery = {
      select(_columns?: string) {
        return query;
      },
      eq(column: string, value: unknown) {
        filters.push({ column, value });
        return query;
      },
      order(column: string, options?: { ascending?: boolean }) {
        orderColumn = column;
        orderAscending = options?.ascending ?? true;
        return query;
      },
      async limit(count: number) {
        return { data: matchRows().slice(0, count), error: null };
      },
      async maybeSingle() {
        const matched = matchRows();
        return { data: matched[0] ?? null, error: null };
      },
      insert: (value: Record<string, unknown>) => {
        const record: Record<string, unknown> = {
          id: `chk-${this.seqCounter++}`,
          resumed_by: null,
          resumed_at: null,
          created_at: "2026-11-25T10:00:00Z",
          updated_at: "2026-11-25T10:00:00Z",
          ...value,
        };
        this.rows.push(record);
        return {
          select: (_columns?: string) => ({
            single: async () => ({ data: { ...record }, error: null }),
          }),
        };
      },
      update: (value: Record<string, unknown>) => ({
        eq: (column: string, eqValue: unknown) => ({
          select: (_columns?: string) => ({
            single: async () => {
              const target = this.rows.find((row) => row[column] === eqValue);
              if (!target) {
                return { data: null, error: { message: "Not found" } };
              }
              Object.assign(target, value, {
                updated_at: "2026-11-25T10:05:00Z",
              });
              return { data: { ...target }, error: null };
            },
          }),
        }),
      }),
    };

    return query;
  }
}

Deno.test("read-only MCP calls run directly while system-impact calls pause before execution", async () => {
  const db = new InMemorySafetyCheckpointDb();
  db.profiles.set("agent-owner", {
    user_id: "agent-owner",
    is_admin: false,
    role: "user",
  });

  const safeRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      tool_name: "notes.search",
      requested_scopes: ["read"],
      actor_role: "writer",
    },
  });
  assertEquals(safeRes.status, 200);
  assertEquals(safeRes.body.decision, "allow_direct");
  assertEquals(safeRes.body.execution_allowed, true);
  assertEquals(safeRes.body.pause_required, false);
  assertEquals(db.rows.length, 0);

  const highRiskRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      run_key: "mcp-db-cleanup-01",
      agent_name: "ops-worker",
      tool_name: "db.prune_stale_records",
      requested_scopes: ["delete"],
      actor_role: "admin",
      pending_step: "step_2_delete_rows",
      tool_payload: { table: "temp_logs", older_than_days: 30 },
      github_issue_number: 2712,
      github_repo: "kanta13jp1/my_web_app",
    },
    nowIso: "2026-11-25T10:00:00Z",
  });
  assertEquals(highRiskRes.status, 200);
  assertEquals(highRiskRes.body.decision, "paused_for_approval");
  assertEquals(highRiskRes.body.execution_allowed, false);
  assertEquals(highRiskRes.body.pause_required, true);
  assertEquals(db.rows.length, 1);
  assertEquals(db.rows[0].pause_status, "paused_lossless");
  const createdCheckpoint = highRiskRes.body.checkpoint as Record<
    string,
    unknown
  >;
  assertExists(createdCheckpoint.id);
  assertEquals(createdCheckpoint.approval_state, "awaiting_admin_approval");
});

Deno.test("only admin approval via UI or verified GitHub Issue unblocks resumption", async () => {
  const db = new InMemorySafetyCheckpointDb();
  db.profiles.set("agent-owner", {
    user_id: "agent-owner",
    is_admin: false,
    role: "user",
  });
  db.profiles.set("admin-user", {
    user_id: "admin-user",
    is_admin: true,
    role: "admin",
  });

  const evalRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      run_key: "mcp-deploy-02",
      agent_name: "release-agent",
      tool_name: "deploy.edge_function",
      requested_scopes: ["update"],
      actor_role: "admin",
      tool_payload: { fn: "ai-hub" },
    },
  });
  const checkpoint = evalRes.body.checkpoint as Record<string, unknown>;
  const checkpointId = String(checkpoint.id);

  // Non-admin caller cannot approve (fail-closed 403)
  const nonAdminApprove = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.approve",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      checkpoint_id: checkpointId,
      approval_channel: "admin_ui",
    },
  });
  assertEquals(nonAdminApprove.status, 403);
  assertEquals(db.rows[0].pause_status, "paused_lossless");

  // Re-evaluating before approval stays paused
  const stillPaused = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      checkpoint_id: checkpointId,
      run_key: "mcp-deploy-02",
      agent_name: "release-agent",
      tool_name: "deploy.edge_function",
      requested_scopes: ["update"],
      actor_role: "admin",
      tool_payload: { fn: "ai-hub" },
    },
  });
  assertEquals(stillPaused.body.execution_allowed, false);
  assertEquals(stillPaused.body.decision, "paused_for_approval");

  // Admin UI approval transitions checkpoint to resumed & permits matching operation
  const adminApprove = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.approve",
    userId: "admin-user",
    isElevatedAutomation: false,
    body: {
      checkpoint_id: checkpointId,
      approval_channel: "admin_ui",
      approval_note: "Verified release window",
    },
    nowIso: "2026-11-25T10:10:00Z",
  });
  assertEquals(adminApprove.status, 200);
  assertEquals(adminApprove.body.decision, "approved_resumed");
  assertEquals(adminApprove.body.execution_allowed, true);
  assertEquals(db.rows[0].pause_status, "resumed");
  assertEquals(db.rows[0].resumed_by, "admin-user");

  // Exact matching tool call is now permitted
  const resumedEval = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      checkpoint_id: checkpointId,
      run_key: "mcp-deploy-02",
      agent_name: "release-agent",
      tool_name: "deploy.edge_function",
      requested_scopes: ["update"],
      actor_role: "admin",
      tool_payload: { fn: "ai-hub" },
    },
  });
  assertEquals(resumedEval.body.execution_allowed, true);
  assertEquals(resumedEval.body.decision, "approved_resumed");

  // Altered payload MUST fail-closed and require a new safety checkpoint pause
  const alteredEval = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      checkpoint_id: checkpointId,
      run_key: "mcp-deploy-02",
      agent_name: "release-agent",
      tool_name: "deploy.edge_function",
      requested_scopes: ["update"],
      actor_role: "admin",
      tool_payload: { fn: "payments-hub" },
    },
  });
  assertEquals(alteredEval.body.execution_allowed, false);
  assertEquals(alteredEval.body.decision, "paused_for_approval");
});

Deno.test("github_issue approval channel rejects unprivileged comments and allows OWNER directive", async () => {
  const db = new InMemorySafetyCheckpointDb();
  db.profiles.set("admin-user", {
    user_id: "admin-user",
    is_admin: true,
    role: "admin",
  });

  const evalRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "admin-user",
    isElevatedAutomation: false,
    body: {
      run_key: "mcp-billing-03",
      agent_name: "fin-agent",
      tool_name: "billing.refund_invoice",
      requested_scopes: ["purchase"],
      actor_role: "admin",
      github_issue_number: 2712,
      github_repo: "kanta13jp1/my_web_app",
    },
  });
  const checkpointId = String(
    (evalRes.body.checkpoint as Record<string, unknown>).id,
  );

  const untrustedComments: GitHubIssueCommentEntry[] = [
    {
      id: 9001,
      author: "random-outsider",
      authorAssociation: "NONE",
      body: `/approve-checkpoint ${checkpointId}`,
    },
  ];
  const blockedRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.approve",
    userId: "admin-user",
    isElevatedAutomation: false,
    body: {
      checkpoint_id: checkpointId,
      approval_channel: "github_issue",
      github_issue_number: 2712,
      github_repo: "kanta13jp1/my_web_app",
    },
    fetchIssueComments: async () => untrustedComments,
  });
  assertEquals(blockedRes.status, 403);
  assertEquals(db.rows[0].pause_status, "paused_lossless");

  const maintainerComments: GitHubIssueCommentEntry[] = [
    ...untrustedComments,
    {
      id: 9002,
      author: "kanta13jp1",
      authorAssociation: "OWNER",
      body: `Reviewed safety impact. /approve-checkpoint ${checkpointId}`,
    },
  ];
  const okRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.approve",
    userId: "admin-user",
    isElevatedAutomation: false,
    body: {
      checkpoint_id: checkpointId,
      approval_channel: "github_issue",
      github_issue_number: 2712,
      github_repo: "kanta13jp1/my_web_app",
    },
    fetchIssueComments: async () => maintainerComments,
  });
  assertEquals(okRes.status, 200);
  assertEquals(okRes.body.execution_allowed, true);
  assertEquals(
    (okRes.body.checkpoint as Record<string, unknown>).approval_channel,
    "github_issue",
  );
  assertEquals(
    (okRes.body.checkpoint as Record<string, unknown>).github_comment_id,
    9002,
  );
});

Deno.test("reject permanently blocks checkpoint and blocks missing-scope calls", async () => {
  const db = new InMemorySafetyCheckpointDb();
  db.profiles.set("agent-owner", {
    user_id: "agent-owner",
    is_admin: false,
    role: "user",
  });

  const missingScopeRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      tool_name: "db.drop_table",
      requested_scopes: ["delete"],
      actor_role: "viewer",
    },
  });
  assertEquals(missingScopeRes.body.decision, "blocked_policy");
  assertEquals(missingScopeRes.body.execution_allowed, false);

  const pauseRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      run_key: "mcp-send-04",
      tool_name: "mail.send_broadcast",
      requested_scopes: ["send"],
      actor_role: "admin",
    },
  });
  const checkpointId = String(
    (pauseRes.body.checkpoint as Record<string, unknown>).id,
  );

  const rejectRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.reject",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      checkpoint_id: checkpointId,
      reason: "Operator aborted broadcast",
    },
  });
  assertEquals(rejectRes.status, 200);
  assertEquals(rejectRes.body.decision, "rejected");
  assertEquals(rejectRes.body.execution_allowed, false);

  const afterReject = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      checkpoint_id: checkpointId,
      run_key: "mcp-send-04",
      tool_name: "mail.send_broadcast",
      requested_scopes: ["send"],
      actor_role: "admin",
    },
  });
  assertEquals(afterReject.body.decision, "rejected_blocked");
  assertEquals(afterReject.body.execution_allowed, false);
});

Deno.test("isolates safety checkpoints across tenants sharing run_key and tool_name", async () => {
  const db = new InMemorySafetyCheckpointDb();
  const userARes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "user-a",
    isElevatedAutomation: false,
    body: {
      run_key: "mcp-safety-check",
      tool_name: "deploy.edge_function",
      requested_scopes: ["update"],
      actor_role: "admin",
      github_issue_number: 2712,
      github_repo: "kanta13jp1/my_web_app",
    },
  });
  const userBRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "user-b",
    isElevatedAutomation: false,
    body: {
      run_key: "mcp-safety-check",
      tool_name: "deploy.edge_function",
      requested_scopes: ["update"],
      actor_role: "admin",
    },
  });

  assertEquals(userARes.status, 200);
  assertEquals(userBRes.status, 200);
  assertEquals(db.rows.length, 2);
  const chkA = userARes.body.checkpoint as Record<string, unknown>;
  const chkB = userBRes.body.checkpoint as Record<string, unknown>;
  assertEquals(chkA.user_id, "user-a");
  assertEquals(chkB.user_id, "user-b");
  assertEquals(chkA.id === chkB.id, false);
  assertEquals(userBRes.body.reused_existing_pause, undefined);
  assertEquals(chkB.github_issue_number, null);
});

Deno.test("rejects tampered state_snapshot and mismatched pinned github_repo fail-closed", async () => {
  const db = new InMemorySafetyCheckpointDb();
  db.profiles.set("agent-owner", {
    user_id: "agent-owner",
    is_admin: false,
    role: "user",
  });
  db.profiles.set("admin-user", {
    user_id: "admin-user",
    is_admin: true,
    role: "admin",
  });

  const evalRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      run_key: "mcp-pinned-01",
      tool_name: "deploy.edge_function",
      requested_scopes: ["update"],
      actor_role: "admin",
      github_issue_number: 2712,
      github_repo: "kanta13jp1/my_web_app",
    },
  });
  const checkpointId = String(
    (evalRes.body.checkpoint as Record<string, unknown>).id,
  );

  // Mismatched github_repo against pinned checkpoint fails closed (403)
  const mismatchedRepoRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.approve",
    userId: "admin-user",
    isElevatedAutomation: false,
    body: {
      checkpoint_id: checkpointId,
      approval_channel: "github_issue",
      github_issue_number: 2712,
      github_repo: "attacker/evil_repo",
    },
    fetchIssueComments: async () => [],
  });
  assertEquals(mismatchedRepoRes.status, 403);
  assertEquals(db.rows[0].pause_status, "paused_lossless");

  // Mutate snapshot content without updating snapshot_sha256 -> both approve and evaluate fail closed
  const snapshot = db.rows[0].state_snapshot as Record<string, unknown>;
  snapshot.pending_step = "hijacked_step";

  const tamperedApproveRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.approve",
    userId: "admin-user",
    isElevatedAutomation: false,
    body: {
      checkpoint_id: checkpointId,
      approval_channel: "admin_ui",
    },
  });
  assertEquals(tamperedApproveRes.status, 409);

  // Even if row were forged to paused/resumed, evaluate refuses tampered snapshot
  db.rows[0].pause_status = "resumed";
  db.rows[0].resumed_by = "admin-user";
  const safetyMeta = snapshot.safety_checkpoint as Record<string, unknown>;
  safetyMeta.approval_state = "approved";

  const tamperedEvalRes = await handleSafetyCheckpointAction({
    db,
    action: "agent.safety_checkpoint.evaluate",
    userId: "agent-owner",
    isElevatedAutomation: false,
    body: {
      checkpoint_id: checkpointId,
      run_key: "mcp-pinned-01",
      tool_name: "deploy.edge_function",
      requested_scopes: ["update"],
      actor_role: "admin",
    },
  });
  assertEquals(tamperedEvalRes.body.decision, "blocked_tampered_snapshot");
  assertEquals(tamperedEvalRes.body.execution_allowed, false);
});
