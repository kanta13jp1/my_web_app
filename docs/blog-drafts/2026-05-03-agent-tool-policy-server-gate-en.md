---
title: "Stopping AI agent tool calls with deny-by-default — server-side scope gate and CEO approval"
emoji: "🛡️"
type: "tech"
topics: ["security", "mcp", "supabase", "ai-agent"]
published: true
---

## Client guards alone do not stop a determined caller

At Jibun K.K., AI agents impersonating six departments (CEO / CFO / CMO / CHO / CHRO / Legal) call various tools (`notion.write`, `slack.send`, `payment.purchase`, `mail.external_share` …) through Edge Functions.

The first iteration kept the guard in the Flutter `AgentOrg` class: "this role can only request these scopes." That is a textbook **client-trust** design with three obvious holes:

- A different client (curl, Codex, Cursor) can hit the EF directly and slip past
- Audit logs end up scattered across every client
- "Was this approved?" state lives in client memory, not in the server DB you can query

Rule 27 of our internal `MCP_AUTH_SECURITY_PRINCIPLES.md` requires **#5 Scope (least privilege)** and **#7 Audit (centralized)**. Either one is impossible without a **deny-by-default scope gate on the server**.

This post is a design memo from adding `agent.tool_policy.evaluate` and a fail-close gate to `agent.run` inside the `ai-hub` Edge Function. It pairs with the [previous post on MCP AuthKit metadata](./2026-05-02-mcp-authkit-metadata-discovery-en.md) — metadata is the **declaration**, the gate is the **enforcement**.

## Nine scopes and the "high-risk five"

`supabase/functions/_shared/agent_tool_policy.ts` enumerates every scope:

```ts
export const AGENT_TOOL_SCOPES = [
  "read",
  "suggest",
  "create",
  "update",
  "delete",
  "send",
  "purchase",
  "discount",
  "external_share",
] as const;

export const HIGH_RISK_AGENT_TOOL_SCOPES: readonly AgentToolScope[] = [
  "delete",
  "send",
  "purchase",
  "discount",
  "external_share",
];
```

Two design decisions matter here:

1. **The whole scope universe is an enum.** If scopes are free-form strings, every new EF will invent its own and the fleet-wide least-privilege story collapses. Pinning the universe to one file means a new EF cannot route around the policy.
2. **The "high-risk five" live in a separate array.** Destructive (`delete`), outbound (`send`), monetary (`purchase`, `discount`), and third-party publishing (`external_share`) auto-set `requiresApproval` and refuse to execute without an explicit CEO approval.

The intent: low-risk `read` / `suggest` / `create` flow freely across the fleet, while anything touching money, destruction, or external sharing forces an out-of-band approval workflow — encoded in code, not in a Notion page someone forgot to read.

## Default scopes per role

Once the universe is fixed, the next layer is which role gets what:

```ts
export const DEFAULT_AGENT_ROLE_SCOPES: Readonly<
  Record<string, readonly AgentToolScope[]>
> = {
  ceo: AGENT_TOOL_SCOPES,                                  // everything
  cfo: ["read", "suggest", "create", "update"],            // touches money but cannot purchase / discount
  cmo: ["read", "suggest", "create", "external_share"],    // marketing is the only role allowed external_share
  cho: ["read", "suggest", "create"],                      // health agents stay low-risk
  chro: ["read", "suggest", "create", "update"],
  legal: ["read", "suggest", "create", "update"],
};
```

Two notable choices:

- **Only CMO gets `external_share`.** Posting to social media is a marketing job; giving the same scope to CFO would create an AI that tweets the company's invoices.
- **Unknown / null roles fall back to `["read", "suggest"]`.** `getDefaultAgentRoleScopes` defaults unknown roles to the minimum set, so a tenant inventing custom roles (`engineer`, `intern`) cannot accidentally inherit broad permissions.

## Fail-close evaluation

The core verdict:

```ts
let blockedReason: string | null = null;
if (requestedScopes.length === 0) {
  blockedReason = "empty_requested_scope";
} else if (missingScopes.length > 0) {
  blockedReason = "missing_scope";
} else if (requiresApproval && !hasApproval) {
  blockedReason = "approval_required";
}

return {
  allowed: blockedReason === null,
  ...
};
```

Three distinct rejection reasons exist because the recovery UX differs:

| `blockedReason` | What the client should do |
| --- | --- |
| `empty_requested_scope` | Caller bug — scope array missing. Surface as a 400 in the client SDK so a developer sees it instead of swallowing |
| `missing_scope` | The role is too weak. This is a **privilege-escalation request**, not an approval workflow |
| `approval_required` | Scopes are present, but this is a high-risk action. Pop the CEO approval modal to obtain `approval.decision = "approved"` |

A blanket 403 hides the difference and the user just sees "the AI is broken." Splitting the reason lets each branch route to the right recovery flow.

`hasApproval` is an AND of three conditions:

```ts
const hasApproval = input.approval?.decision === "approved" &&
  Boolean(input.approval.approvedBy?.trim()) &&
  Boolean(input.approval.approvedAt?.trim());
```

If `approved` is set but the approver and timestamp are blank, that is a client bug. Defaulting to fail-close is correct.

## Two endpoint shapes inside the EF

`ai-hub` exposes the gate two ways.

### 1. `agent.tool_policy.evaluate` — dry-run

```ts
case "agent.tool_policy.evaluate": {
  const gate = await evaluateAgentToolGate(admin, userId!, body);
  return json({
    success: gate.decision.allowed,
    decision: publicPolicyDecision(gate.decision),
    actor_role: gate.actorRole,
    requested_scopes: gate.requestedScopes,
    allowed_scopes: gate.allowedScopes,
    approval: gate.approval,
    audit_logged: gate.auditLogged,
  }, gate.decision.allowed ? 200 : 403);
}
```

For UI use: "before I show this button as enabled, is this AI action even permitted?" With this endpoint you can grey-out a button and surface the actual reason in a tooltip.

### 2. `agent.run` — fail-close right before execution

```ts
case "agent.run": {
  const gate = shouldEvaluateToolPolicy
    ? await evaluateAgentToolGate(admin, userId!, body)
    : null;
  if (gate && !gate.decision.allowed) {
    return json({
      success: false,
      error: "agent_tool_policy_denied",
      decision: publicPolicyDecision(gate.decision),
      audit_logged: gate.auditLogged,
    }, 403);
  }
  // ... agent_run_log INSERT (queued)
}
```

The gate runs immediately before the queue insert. `shouldEvaluateToolPolicy` skips the check for legacy chat-only callers that never declare scopes — a deliberate migration strategy: **new tool calls must declare scopes; old chat paths still pass through.**

## Audit columns added to `agent_tool_execution_logs`

Migration `20260501210000_agent_tool_policy_server_gate.sql`:

```sql
ALTER TABLE public.agent_tool_execution_logs
  ADD COLUMN IF NOT EXISTS actor_role text,
  ADD COLUMN IF NOT EXISTS requested_scopes text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS allowed_scopes text[],
  ADD COLUMN IF NOT EXISTS high_risk_scopes text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS requires_approval boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS approval_decision text,
  ADD COLUMN IF NOT EXISTS approved_by text,
  ADD COLUMN IF NOT EXISTS approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS side_effects text,
  ADD COLUMN IF NOT EXISTS evaluated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_agent_tool_execution_logs_high_risk
  ON public.agent_tool_execution_logs(user_id, created_at DESC)
  WHERE requires_approval = true;
```

The lever here is the **partial index** (`WHERE requires_approval = true`). Low-risk `read` / `suggest` calls dominate volume by orders of magnitude, so a full index would be wasteful. Targeting "calls that needed approval" optimizes the audit dashboards (CEO view: "what's pending approval this week?") that actually matter.

`requested_scopes` is `NOT NULL DEFAULT '{}'` on purpose — mixing nulls and empty arrays warps downstream aggregate SQL. Normalizing to empty array keeps "scopeless rogue requests" countable via `array_length = 0`.

## Metadata and gate as a paired structure

| Layer | Responsibility | Spec |
| --- | --- | --- |
| MCP AuthKit metadata (`/.well-known/oauth-protected-resource`) | **Declares** the scopes available to clients | RFC 9728 |
| `agent_tool_policy` gate | **Enforces** that clients actually hold the declared scopes | Internal Rule 27 #5 |

Metadata is the **contract**, the gate is the **enforcement**. Either alone leaves a hole:

- Metadata missing / gate present → clients cannot learn the scopes
- Metadata present / gate missing → clients can lie about scopes freely

Only with both does "adding a new client to the fleet without breaking least-privilege" actually hold.

## Pitfalls discovered during implementation

- **`"all"` initially got filtered out.** `normalizeAgentToolScopes` was rejecting `"all"` because it isn't in `AGENT_TOOL_SCOPES`, so the CEO role with `["all"]` could call nothing. Added an explicit branch: `allowedScopes.includes("all")` expands to the full set.
- **`approval: {}` from older clients.** With `decision === undefined`, `hasApproval` is false and the call fail-closes — net behavior is correct, but the audit log shows "approval was sent and rejected." Fixed by having the client SDK omit empty approval objects entirely.
- **Forgot `body.scopes` in `shouldEvaluateToolPolicy`.** Codex was sending the snake-case short alias `scopes`, so its calls bypassed the gate for a few hours. The detection has to recognize every casing variant: `tool_name`, `toolName`, `scopes`, `requested_scopes`, `requestedScopes`.

## Takeaways

- Server-side **deny-by-default gate** is mandatory for AI agent tool calls. Client guards are auxiliary.
- Make scopes an **enum + a high-risk subset**. Bake business knowledge ("only marketing posts externally") into a per-role default table.
- Split rejection reasons into `empty_requested_scope` / `missing_scope` / `approval_required` so each maps to a different UX recovery flow.
- Audit log: partial index on `requires_approval = true` keeps "approval pending" lookups fast at low storage cost.
- MCP AuthKit metadata and the policy gate form a **declaration / enforcement** pair. Both are required for the model to hold across a multi-client fleet.

Next step: have the [`mcp_my_web_app_tools`](https://github.com/kanta13jp1/my_web_app/blob/main/supabase/functions/_shared/mcp_my_web_app_tools.ts) facade reuse the same scope arrays so that the scopes a client learns via MCP discovery and the scopes the server-side gate enforces share **one source of truth**.

## References

- [`supabase/functions/_shared/agent_tool_policy.ts`](https://github.com/kanta13jp1/my_web_app/blob/main/supabase/functions/_shared/agent_tool_policy.ts)
- [`supabase/functions/ai-hub/index.ts`](https://github.com/kanta13jp1/my_web_app/blob/main/supabase/functions/ai-hub/index.ts) (`agent.tool_policy.evaluate` / `agent.run`)
- [`supabase/migrations/20260501210000_agent_tool_policy_server_gate.sql`](https://github.com/kanta13jp1/my_web_app/blob/main/supabase/migrations/20260501210000_agent_tool_policy_server_gate.sql)
- [Part 1: MCP AuthKit metadata and RFC 9728](./2026-05-02-mcp-authkit-metadata-discovery-en.md)
