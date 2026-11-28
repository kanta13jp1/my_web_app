import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { AI_COMPLIANCE_SOURCE } from "../_shared/ai_compliance_guard.ts";
import {
  AiComplianceError,
  handleAiComplianceAction,
  type AiComplianceDb,
} from "./ai_compliance.ts";

class MockComplianceDb implements AiComplianceDb {
  rows: Array<{
    id: string;
    source: string;
    metadata: Record<string, unknown>;
    created_at: string;
  }> = [];
  private seq = 1;

  from(_table: string) {
    const state: {
      op: "select" | "insert" | "update";
      insertVal?: Record<string, unknown>;
      updateVal?: Record<string, unknown>;
      eqFilters: Array<[string, unknown]>;
      jsonFilters: Array<[string, string]>;
    } = {
      op: "select",
      eqFilters: [],
      jsonFilters: [],
    };

    const execute = () => {
      if (state.op === "insert" && state.insertVal) {
        const created = {
          id: `cmp-${this.seq++}`,
          source: String(state.insertVal.source ?? ""),
          metadata: (state.insertVal.metadata ?? {}) as Record<string, unknown>,
          created_at: `2026-05-0${this.seq}T00:00:00Z`,
        };
        this.rows.push(created);
        return { data: created, error: null };
      }

      const matches = this.rows.filter((row) => {
        for (const [col, val] of state.eqFilters) {
          if (col === "id" && row.id !== val) return false;
          if (col === "source" && row.source !== val) return false;
        }
        for (const [expr, expected] of state.jsonFilters) {
          const field = expr.replace("metadata->>", "");
          if (String(row.metadata[field] ?? "") !== expected) {
            return false;
          }
        }
        return true;
      });

      if (state.op === "update" && state.updateVal) {
        if (matches.length === 0) return { data: null, error: null };
        matches[0].metadata = (state.updateVal.metadata ?? {}) as Record<
          string,
          unknown
        >;
        return { data: matches[0], error: null };
      }

      return { data: matches, error: null };
    };

    const builder = {
      select(_columns: string) {
        return builder;
      },
      insert(values: Record<string, unknown>) {
        state.op = "insert";
        state.insertVal = values;
        return builder;
      },
      update(values: Record<string, unknown>) {
        state.op = "update";
        state.updateVal = values;
        return builder;
      },
      eq(col: string, val: unknown) {
        state.eqFilters.push([col, val]);
        return builder;
      },
      filter(col: string, _op: string, val: unknown) {
        state.jsonFilters.push([col, String(val)]);
        return builder;
      },
      order() {
        return builder;
      },
      limit() {
        return builder;
      },
      single() {
        const res = execute();
        return Promise.resolve({
          data: Array.isArray(res.data) ? res.data[0] ?? null : res.data,
          error: res.error,
        });
      },
      maybeSingle() {
        const res = execute();
        return Promise.resolve({
          data: Array.isArray(res.data) ? res.data[0] ?? null : res.data,
          error: res.error,
        });
      },
      then(onfulfilled?: (value: unknown) => unknown) {
        return Promise.resolve(execute()).then(onfulfilled);
      },
    };
    return builder;
  }
}

Deno.test(
  "ai_compliance enforces auth and fail-open issue dispatch",
  async () => {
    const db = new MockComplianceDb();
    await assertRejects(
      () =>
        handleAiComplianceAction({
          action: "ai_compliance.list",
          admin: db,
          body: {},
          userId: "",
        }),
      AiComplianceError,
      "Unauthorized",
    );

    const submitted = await handleAiComplianceAction({
      action: "ai_compliance.submit_review",
      admin: db,
      userId: "user-1",
      body: {
        provider_key: "q2-new-llm",
        model_id: "q2-reasoner",
        provider_name: "Q2 New LLM",
        terms_url: "https://example.com/terms",
      },
      deps: {
        envGetter: () => undefined,
        nowIso: () => "2026-05-10T00:00:00Z",
      },
    });

    const rec = submitted.record as Record<string, unknown>;
    assertEquals(db.rows[0].source, AI_COMPLIANCE_SOURCE);
    assertEquals(rec.status, "in_review");
    assertEquals(rec.invoke_allowed, false);
    assertEquals(rec.invoke_guard_code, "COMPLIANCE_NOT_APPROVED");
    assertEquals(rec.issue_dispatch_status, "skipped_no_token");
  },
);

Deno.test(
  "ai_compliance requires human confirm + 4 checks to pass guard",
  async () => {
    const db = new MockComplianceDb();
    let createdTitle = "";
    const submitted = await handleAiComplianceAction({
      action: "ai_compliance.submit_review",
      admin: db,
      userId: "user-1",
      body: {
        provider_key: "vendor-x",
        model_id: "model-alpha",
        provider_name: "Vendor X",
      },
      deps: {
        createGitHubIssue: (p) => {
          createdTitle = `${p.providerName}:${p.modelId}`;
          return Promise.resolve({
            issue_created: true,
            dispatch_status: "created",
            issue_number: 9001,
            issue_url: "https://github.com/kanta13jp1/my_web_app/issues/9001",
          });
        },
        nowIso: () => "2026-05-11T00:00:00Z",
      },
    });
    assertEquals(createdTitle, "Vendor X:model-alpha");
    const rec = submitted.record as Record<string, unknown>;
    const id = String(rec.id);
    assertEquals(rec.github_issue_number, 9001);

    // Blocked at system guard prior to approval
    const blocked = await handleAiComplianceAction({
      action: "ai_compliance.check_invoke_guard",
      admin: db,
      userId: "user-1",
      body: { id },
    });
    assertEquals(blocked.allowed, false);
    assertEquals(blocked.code, "COMPLIANCE_NOT_APPROVED");

    // Cross-user approval rejected (404)
    const crossErr = await assertRejects(
      () =>
        handleAiComplianceAction({
          action: "ai_compliance.approve",
          admin: db,
          userId: "user-2",
          body: { id, human_confirmed: true, reviewer_name: "hacker" },
        }),
      AiComplianceError,
    );
    assertEquals(crossErr.status, 404);

    // Partial checklist cannot be approved
    await assertRejects(
      () =>
        handleAiComplianceAction({
          action: "ai_compliance.approve",
          admin: db,
          userId: "user-1",
          body: { id, human_confirmed: true, reviewer_name: "Legal Lead" },
        }),
      AiComplianceError,
    );

    // Complete all 4 checklist items
    await handleAiComplianceAction({
      action: "ai_compliance.update_checklist",
      admin: db,
      userId: "user-1",
      body: {
        id,
        checklist: {
          terms_reviewed: true,
          data_retention_checked: true,
          pii_leakage_checked: true,
          security_controls_verified: true,
        },
      },
    });

    // Missing human_confirmed still fails
    await assertRejects(
      () =>
        handleAiComplianceAction({
          action: "ai_compliance.approve",
          admin: db,
          userId: "user-1",
          body: { id, human_confirmed: false, reviewer_name: "Legal Lead" },
        }),
      AiComplianceError,
    );

    // Explicit human approval unlocks guard
    const approved = await handleAiComplianceAction({
      action: "ai_compliance.approve",
      admin: db,
      userId: "user-1",
      body: {
        id,
        human_confirmed: true,
        reviewer_name: "Legal Lead",
        approval_note: "Confirmed enterprise DPA",
      },
    });
    const appRec = approved.record as Record<string, unknown>;
    assertEquals(appRec.status, "approved");
    assertEquals(appRec.invoke_allowed, true);
    assertEquals(appRec.human_approved_by, "Legal Lead");

    const allowed = await handleAiComplianceAction({
      action: "ai_compliance.check_invoke_guard",
      admin: db,
      userId: "user-1",
      body: { provider_key: "vendor-x", model_id: "model-alpha" },
    });
    assertEquals(allowed.allowed, true);
    assertEquals(allowed.code, "COMPLIANCE_APPROVED");

    // Unchecking a checklist box revokes approved status back to in_review
    const revoked = await handleAiComplianceAction({
      action: "ai_compliance.update_checklist",
      admin: db,
      userId: "user-1",
      body: {
        id,
        checklist: { pii_leakage_checked: false },
      },
    });
    const revRec = revoked.record as Record<string, unknown>;
    assertEquals(revRec.status, "in_review");
    assertEquals(revRec.invoke_allowed, false);
  },
);
