import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  type AgentToolApproval,
  evaluateAgentToolPolicy,
  parseAgentToolApproval,
  parseAgentToolRequestedScopes,
} from "../_shared/agent_tool_policy.ts";
import { scanMcpPayloadForSecuritySignals } from "../_shared/mcp_security_scan.ts";

export type SandboxBlockedCategory =
  | "none"
  | "host_filesystem_access"
  | "prod_db_access"
  | "ssrf_metadata"
  | "prompt_injection"
  | "excessive_retries"
  | "invalid_tool_args"
  | "least_privilege_denied"
  | "sandbox_escape";

export type SandboxProfile = "isolated_worker" | "strict_read_only";
export type SandboxNetworkMode = "none" | "allowlist_only";

export const SANDBOX_ISOLATED_ALLOWLIST = [
  "sandbox.json_validate",
  "sandbox.text_metrics",
  "sandbox.math_eval",
] as const;

const ISOLATED_TOOL_SET = new Set<string>(SANDBOX_ISOLATED_ALLOWLIST);
const FORBIDDEN_PROTO_KEYS = new Set<string>([
  "__proto__",
  "constructor",
  "prototype",
]);
const MAX_ARGS_BYTES = 32 * 1024;
const MAX_ARGS_DEPTH = 10;

const HOST_FS_PATTERNS: readonly RegExp[] = [
  /(?:^|[\s"'`])\/(?:etc|proc|sys|var\/log|root|home|usr\/local|tmp\/host)\//i,
  /[a-zA-Z]:\\(?:windows|users|program\s*files|tmp\\)/i,
  /(?:^|[\\/])\.\.(?:[\\/]|$)/,
  /\bfile:\/\//i,
  /~\/\.(?:ssh|aws|kube|gnupg|env)\b/i,
];

const PROD_DB_PATTERNS: readonly RegExp[] = [
  /\bpostgres(?:ql)?:\/\//i,
  /[a-z0-9]{12,}\.supabase\.co\b/i,
  /\b(?:drop|truncate|alter)\s+table\b/i,
  /\bdelete\s+from\b/i,
  /\b(?:auth\.users|pg_catalog|pg_shadow|pg_roles)\b/i,
  /\bservice[_-]?role\b/i,
  /\bsb_secret_/i,
];

const SSRF_METADATA_PATTERNS: readonly RegExp[] = [
  /\b169\.254\.169\.254\b/,
  /\bmetadata\.google\.internal\b/i,
  /\b(?:127\.0\.0\.1|localhost|0\.0\.0\.0|::1)\b/i,
  /\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/,
];

const SANDBOX_ESCAPE_PATTERNS: readonly RegExp[] = [
  /\bDeno\.(?:Command|run|readTextFile|writeTextFile|remove|chmod)\b/,
  /\bchild_process\b/i,
  /\b(?:rm\s+-rf|chmod\s+777|curl\s+.*\|\s*(?:sh|bash))\b/i,
  /\$\([^)]+\)/,
  /\beval\s*\(/,
  /\bnew\s+Function\s*\(/,
];

const EXTRA_INJECTION_PATTERNS: readonly RegExp[] = [
  /\b(?:jailbreak|dan\s+mode|developer\s+mode\s+enabled)\b/i,
  /\bsystem\s+prompt\b.{0,40}\b(?:reveal|print|dump|export)\b/i,
  /\boverride\s+(?:sandbox|rls|security\s+policy)\b/i,
];

export interface SandboxPolicyConfig {
  sandboxProfile: SandboxProfile;
  allowHostFs: false;
  allowProdDb: false;
  networkEgressMode: SandboxNetworkMode;
  maxRetriesPerTool: number;
  maxBurstPerWindow: number;
  allowedTools: string[];
}

export interface SandboxPreflightInput {
  userId: string;
  sessionId?: string;
  sandboxId?: string;
  actorRole?: string | null;
  toolName: string;
  requestedScopes?: readonly string[];
  toolArgs: unknown;
  promptText?: string;
  retryAttempt?: number;
  recentAttemptCount?: number;
  networkEgressTarget?: string | null;
  enforceIsolatedToolAllowlist?: boolean;
  approval?: AgentToolApproval | null;
  policy?: Partial<SandboxPolicyConfig>;
}

export interface SandboxPreflightDecision {
  allowed: boolean;
  sandboxProfile: SandboxProfile;
  allowHostFs: false;
  allowProdDb: false;
  networkEgressMode: SandboxNetworkMode;
  blockedCategory: SandboxBlockedCategory;
  blockedReason: string | null;
  anomalyFlags: string[];
  injectionSignals: Array<{ code: string; path: string; message: string }>;
  sanitizedArgs: Record<string, unknown>;
  errorTrace: string | null;
}

function asTrimmed(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function clampInt(value: unknown, min: number, max: number, fallback: number): number {
  const num = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(num)) return fallback;
  const rounded = Math.floor(num);
  return Math.max(min, Math.min(max, rounded));
}

function defaultPolicyConfig(
  overrides?: Partial<SandboxPolicyConfig>,
): SandboxPolicyConfig {
  const profile: SandboxProfile = overrides?.sandboxProfile === "strict_read_only"
    ? "strict_read_only"
    : "isolated_worker";
  const networkEgressMode: SandboxNetworkMode =
    overrides?.networkEgressMode === "allowlist_only"
      ? "allowlist_only"
      : "none";
  const allowedTools = Array.isArray(overrides?.allowedTools) &&
      overrides.allowedTools.length > 0
    ? overrides.allowedTools
        .map((t) => String(t).trim())
        .filter((t) => ISOLATED_TOOL_SET.has(t))
    : [...SANDBOX_ISOLATED_ALLOWLIST];
  return {
    sandboxProfile: profile,
    allowHostFs: false,
    allowProdDb: false,
    networkEgressMode,
    maxRetriesPerTool: clampInt(overrides?.maxRetriesPerTool, 1, 5, 3),
    maxBurstPerWindow: clampInt(overrides?.maxBurstPerWindow, 1, 50, 10),
    allowedTools: allowedTools.length > 0
      ? allowedTools
      : [...SANDBOX_ISOLATED_ALLOWLIST],
  };
}

function inspectArgsStructure(
  value: unknown,
  depth: number,
  collectedStrings: string[],
  anomalyFlags: string[],
): boolean {
  if (depth > MAX_ARGS_DEPTH) {
    anomalyFlags.push("args_max_depth_exceeded");
    return false;
  }
  if (typeof value === "number" && !Number.isFinite(value)) {
    anomalyFlags.push("non_finite_number");
    return false;
  }
  if (typeof value === "string") {
    collectedStrings.push(value);
    return true;
  }
  if (value === null || typeof value === "boolean") {
    return true;
  }
  if (Array.isArray(value)) {
    for (const item of value) {
      if (!inspectArgsStructure(item, depth + 1, collectedStrings, anomalyFlags)) {
        return false;
      }
    }
    return true;
  }
  if (typeof value === "object") {
    const rec = value as Record<string, unknown>;
    for (const key of Object.keys(rec)) {
      if (FORBIDDEN_PROTO_KEYS.has(key)) {
        anomalyFlags.push(`forbidden_prototype_key:${key}`);
        return false;
      }
      collectedStrings.push(key);
      if (
        !inspectArgsStructure(rec[key], depth + 1, collectedStrings, anomalyFlags)
      ) {
        return false;
      }
    }
    return true;
  }
  anomalyFlags.push("unsupported_arg_type");
  return false;
}

export function sanitizeSandboxArgsForAudit(
  args: unknown,
): Record<string, unknown> {
  if (!args || typeof args !== "object" || Array.isArray(args)) {
    return { value_type: typeof args };
  }
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(args as Record<string, unknown>).slice(0, 20)) {
    if (FORBIDDEN_PROTO_KEYS.has(k)) continue;
    if (/(?:secret|passwd|password|credential|private_key)/i.test(k)) {
      out[k] = "[REDACTED]";
      continue;
    }
    if (typeof v === "string") {
      out[k] = v.length > 160 ? `${v.slice(0, 160)}...` : v;
    } else if (typeof v === "number" || typeof v === "boolean" || v === null) {
      out[k] = v;
    } else if (Array.isArray(v)) {
      out[k] = `[array:${v.length}]`;
    } else {
      out[k] = "[object]";
    }
  }
  return out;
}

function buildErrorTrace(
  category: SandboxBlockedCategory,
  toolName: string,
  reason: string,
  flags: string[],
): string {
  return `SANDBOX_BLOCK[${category}] tool=${toolName} flags=[${
    flags.join(",")
  }] reason=${reason}`;
}

export function evaluateAgentSandboxPreflight(
  input: SandboxPreflightInput,
): SandboxPreflightDecision {
  const policy = defaultPolicyConfig(input.policy);
  const toolName = asTrimmed(input.toolName) || "unknown";
  const retryAttempt = clampInt(input.retryAttempt, 0, 1000, 0);
  const recentAttemptCount = clampInt(input.recentAttemptCount, 0, 1000, 0);
  const networkEgressTarget = asTrimmed(input.networkEgressTarget);
  const anomalyFlags: string[] = [];
  const injectionSignals: Array<{ code: string; path: string; message: string }> =
    [];

  const sanitizedArgs = sanitizeSandboxArgsForAudit(input.toolArgs);

  const block = (
    blockedCategory: SandboxBlockedCategory,
    blockedReason: string,
  ): SandboxPreflightDecision => ({
    allowed: false,
    sandboxProfile: policy.sandboxProfile,
    allowHostFs: false,
    allowProdDb: false,
    networkEgressMode: policy.networkEgressMode,
    blockedCategory,
    blockedReason,
    anomalyFlags: [...new Set(anomalyFlags)],
    injectionSignals,
    sanitizedArgs,
    errorTrace: buildErrorTrace(
      blockedCategory,
      toolName,
      blockedReason,
      anomalyFlags,
    ),
  });

  // 1. Validate tool argument schema & size before inspection
  if (
    input.toolArgs !== undefined &&
    input.toolArgs !== null &&
    (typeof input.toolArgs !== "object" || Array.isArray(input.toolArgs))
  ) {
    anomalyFlags.push("tool_args_must_be_object");
    return block(
      "invalid_tool_args",
      "Tool arguments must be a structured JSON object.",
    );
  }

  let argsJson = "{}";
  try {
    argsJson = JSON.stringify(input.toolArgs ?? {});
  } catch {
    anomalyFlags.push("unserializable_tool_args");
    return block("invalid_tool_args", "Tool arguments cannot be serialized safely.");
  }

  if (new TextEncoder().encode(argsJson).length > MAX_ARGS_BYTES) {
    anomalyFlags.push("tool_args_size_exceeded");
    return block(
      "invalid_tool_args",
      `Tool argument payload exceeds sandbox limit (${MAX_ARGS_BYTES} bytes).`,
    );
  }

  const collectedStrings: string[] = [toolName];
  if (input.promptText) collectedStrings.push(input.promptText);
  if (networkEgressTarget) collectedStrings.push(networkEgressTarget);
  if (
    input.toolArgs !== undefined &&
    input.toolArgs !== null &&
    !inspectArgsStructure(input.toolArgs, 0, collectedStrings, anomalyFlags)
  ) {
    return block(
      "invalid_tool_args",
      `Invalid or unsafe tool argument structure: ${anomalyFlags.join(", ")}.`,
    );
  }

  // 2. Retry storm & burst anomaly check
  if (retryAttempt > policy.maxRetriesPerTool) {
    anomalyFlags.push(`retry_limit_exceeded:${retryAttempt}>${policy.maxRetriesPerTool}`);
    return block(
      "excessive_retries",
      `Excessive retry attempt (${retryAttempt}) exceeds policy limit (${policy.maxRetriesPerTool}).`,
    );
  }
  if (recentAttemptCount >= policy.maxBurstPerWindow) {
    anomalyFlags.push(
      `burst_rate_exceeded:${recentAttemptCount}>=${policy.maxBurstPerWindow}`,
    );
    return block(
      "excessive_retries",
      `Tool call burst (${recentAttemptCount}) exceeds sandbox rate window (${policy.maxBurstPerWindow}).`,
    );
  }

  // 3. Network egress isolation & SSRF metadata check
  if (networkEgressTarget) {
    for (const pattern of SSRF_METADATA_PATTERNS) {
      if (pattern.test(networkEgressTarget)) {
        anomalyFlags.push("ssrf_metadata_or_loopback");
        return block(
          "ssrf_metadata",
          "Direct loopback or cloud metadata egress is blocked inside isolated sandbox.",
        );
      }
    }
    if (policy.networkEgressMode === "none") {
      anomalyFlags.push("network_egress_denied");
      return block(
        "sandbox_escape",
        "External network egress is disabled under sandbox network_egress_mode=none.",
      );
    }
  }

  // 4. Sandbox boundary guards: Host FS, Prod DB, Sandbox Escape, Injection
  const combinedInspectionText = collectedStrings.join("\n");
  for (const pattern of HOST_FS_PATTERNS) {
    if (pattern.test(combinedInspectionText)) {
      anomalyFlags.push("host_fs_boundary_violation");
      return block(
        "host_filesystem_access",
        "Direct host filesystem path or traversal is blocked inside isolated sandbox.",
      );
    }
  }

  for (const pattern of PROD_DB_PATTERNS) {
    if (pattern.test(combinedInspectionText)) {
      anomalyFlags.push("prod_db_boundary_violation");
      return block(
        "prod_db_access",
        "Direct production DB connection, raw DDL/DML, or privileged role probe is blocked.",
      );
    }
  }

  for (const pattern of SSRF_METADATA_PATTERNS) {
    if (pattern.test(combinedInspectionText)) {
      anomalyFlags.push("ssrf_payload_detected");
      return block(
        "ssrf_metadata",
        "Loopback or instance metadata IP reference is blocked inside isolated sandbox.",
      );
    }
  }

  for (const pattern of SANDBOX_ESCAPE_PATTERNS) {
    if (pattern.test(combinedInspectionText)) {
      anomalyFlags.push("sandbox_escape_attempt");
      return block(
        "sandbox_escape",
        "Arbitrary shell/process execution or dynamic eval is forbidden inside sandbox.",
      );
    }
  }

  // 5. Prompt-injection detection (reuse shared MCP security scanner + sandbox rules)
  const mcpScan = scanMcpPayloadForSecuritySignals({
    toolName,
    promptText: input.promptText ?? "",
    toolArgs: input.toolArgs ?? {},
  });
  if (!mcpScan.allowed) {
    for (const finding of mcpScan.findings) {
      anomalyFlags.push(`mcp:${finding.code}`);
      injectionSignals.push({
        code: finding.code,
        path: finding.path,
        message: finding.message,
      });
    }
    return block(
      "prompt_injection",
      mcpScan.findings[0]?.message ?? "Prompt injection signal detected.",
    );
  }
  for (const pattern of EXTRA_INJECTION_PATTERNS) {
    if (pattern.test(combinedInspectionText)) {
      anomalyFlags.push("sandbox_policy_override_injection");
      injectionSignals.push({
        code: "sandbox_policy_override",
        path: "$",
        message: "Attempt to override sandbox or system prompt boundaries detected.",
      });
      return block(
        "prompt_injection",
        "Prompt injection / policy override attempt detected before tool execution.",
      );
    }
  }

  // 6. Least-privilege scope & role boundary enforcement
  const requestedScopes = input.requestedScopes && input.requestedScopes.length > 0
    ? [...input.requestedScopes]
    : ["read"];
  const toolPolicyDecision = evaluateAgentToolPolicy({
    actorRole: input.actorRole ?? "generated_ui_sandbox",
    toolName,
    requestedScopes,
    allowedScopes: policy.sandboxProfile === "strict_read_only"
      ? ["read"]
      : undefined,
    approval: input.approval ?? null,
  });
  if (!toolPolicyDecision.allowed) {
    anomalyFlags.push(
      `policy_denied:${toolPolicyDecision.blockedReason ?? "scope"}`,
    );
    return block(
      "least_privilege_denied",
      `Least-privilege policy denied scopes (${toolPolicyDecision.blockedReason ?? "denied"}).`,
    );
  }

  const effectiveRole = (input.actorRole ?? "generated_ui_sandbox").trim()
    .toLowerCase();
  const strictAllowlist = input.enforceIsolatedToolAllowlist === true;
  const mustCheckAllowlist = strictAllowlist ||
    (input.enforceIsolatedToolAllowlist !== false &&
      effectiveRole === "generated_ui_sandbox");
  if (
    mustCheckAllowlist &&
    (strictAllowlist || toolName !== "agent.run") &&
    !policy.allowedTools.includes(toolName)
  ) {
    anomalyFlags.push(`tool_not_allowlisted:${toolName}`);
    return block(
      "least_privilege_denied",
      `Tool "${toolName}" is not in the sandbox least-privilege allowlist.`,
    );
  }

  return {
    allowed: true,
    sandboxProfile: policy.sandboxProfile,
    allowHostFs: false,
    allowProdDb: false,
    networkEgressMode: policy.networkEgressMode,
    blockedCategory: "none",
    blockedReason: null,
    anomalyFlags: [],
    injectionSignals: [],
    sanitizedArgs,
    errorTrace: null,
  };
}

export function executeIsolatedSandboxTool(
  toolName: string,
  toolArgs: Record<string, unknown>,
): Record<string, unknown> {
  switch (toolName) {
    case "sandbox.json_validate": {
      const keys = Object.keys(toolArgs);
      return {
        isolated: true,
        tool: toolName,
        valid_object: true,
        key_count: keys.length,
        keys: keys.slice(0, 25),
      };
    }
    case "sandbox.text_metrics": {
      const text = typeof toolArgs.text === "string" ? toolArgs.text : "";
      const words = text.trim() ? text.trim().split(/\s+/).length : 0;
      return {
        isolated: true,
        tool: toolName,
        char_count: text.length,
        word_count: words,
        line_count: text ? text.split(/\r?\n/).length : 0,
      };
    }
    case "sandbox.math_eval": {
      const values = Array.isArray(toolArgs.values)
        ? toolArgs.values.filter((v): v is number =>
          typeof v === "number" && Number.isFinite(v)
        )
        : [];
      const sum = values.reduce((acc, v) => acc + v, 0);
      return {
        isolated: true,
        tool: toolName,
        count: values.length,
        sum,
        average: values.length > 0 ? Number((sum / values.length).toFixed(4)) : 0,
      };
    }
    default:
      throw new Error(`Tool "${toolName}" is not permitted in isolated runner.`);
  }
}

export interface HandleSandboxSecurityParams {
  action: string;
  body: Record<string, unknown>;
  userId: string | null;
  isElevatedAutomation: boolean;
  admin: SupabaseClient;
  json: (data: unknown, status?: number) => Response;
}

export async function recordSandboxAuditEntry(
  admin: SupabaseClient,
  params: {
    userId: string;
    sessionId: string;
    sandboxId: string;
    actorRole: string;
    toolName: string;
    actionKind:
      | "sandbox_preflight"
      | "tool_execution"
      | "blocked_guard"
      | "agent_run_preflight";
    decision: SandboxPreflightDecision;
    retryAttempt: number;
    networkEgressTarget: string | null;
    latencyMs: number;
  },
): Promise<{ logged: boolean; row: Record<string, unknown> | null; error?: string }> {
  try {
    const { data, error } = await admin
      .from("agent_sandbox_security_audit")
      .insert({
        user_id: params.userId,
        session_id: params.sessionId,
        sandbox_id: params.sandboxId,
        actor_role: params.actorRole,
        tool_name: params.toolName,
        action_kind: params.decision.allowed ? params.actionKind : "blocked_guard",
        decision: params.decision.allowed ? "allowed" : "blocked",
        blocked_category: params.decision.blockedCategory,
        blocked_reason: params.decision.blockedReason,
        retry_attempt: params.retryAttempt,
        sanitized_args: params.decision.sanitizedArgs,
        anomaly_flags: params.decision.anomalyFlags,
        injection_signals: params.decision.injectionSignals,
        network_egress_target: params.networkEgressTarget,
        error_trace: params.decision.errorTrace,
        latency_ms: params.latencyMs,
      })
      .select("*")
      .single();

    if (error) {
      return { logged: false, row: null, error: error.message };
    }
    return {
      logged: true,
      row: (data ?? null) as Record<string, unknown> | null,
    };
  } catch (err) {
    return {
      logged: false,
      row: null,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

export async function handleSandboxSecurityAction(
  params: HandleSandboxSecurityParams,
): Promise<Response> {
  const { action, body, admin, json } = params;
  const effectiveUserId = asTrimmed(params.userId) ||
    (params.isElevatedAutomation ? asTrimmed(body.user_id) : "");
  if (!effectiveUserId) {
    return json({ error: "Authenticated user_id is required" }, 401);
  }

  switch (action) {
    case "agent.sandbox.policy_upsert": {
      if (body.allow_host_fs === true || body.allow_prod_db === true) {
        return json({
          error:
            "Sandbox isolation boundary cannot enable allow_host_fs or allow_prod_db.",
        }, 403);
      }
      const policy = defaultPolicyConfig({
        sandboxProfile: body.sandbox_profile === "strict_read_only"
          ? "strict_read_only"
          : "isolated_worker",
        networkEgressMode: body.network_egress_mode === "allowlist_only"
          ? "allowlist_only"
          : "none",
        maxRetriesPerTool: clampInt(body.max_retries_per_tool, 1, 5, 3),
        maxBurstPerWindow: clampInt(body.max_burst_per_window, 1, 50, 10),
        allowedTools: Array.isArray(body.allowed_tools)
          ? body.allowed_tools.map((x) => String(x))
          : undefined,
      });

      const { data, error } = await admin
        .from("agent_sandbox_policies")
        .upsert(
          {
            user_id: effectiveUserId,
            sandbox_profile: policy.sandboxProfile,
            allow_host_fs: false,
            allow_prod_db: false,
            network_egress_mode: policy.networkEgressMode,
            max_retries_per_tool: policy.maxRetriesPerTool,
            max_burst_per_window: policy.maxBurstPerWindow,
            allowed_tools: policy.allowedTools,
          },
          { onConflict: "user_id,sandbox_profile" },
        )
        .select("*")
        .single();

      if (error) {
        return json({ error: error.message }, 500);
      }
      return json({ success: true, policy: data });
    }

    case "agent.sandbox.evaluate":
    case "agent.sandbox.execute_isolated": {
      const started = Date.now();
      const toolName = asTrimmed(body.tool_name ?? body.toolName) ||
        "sandbox.text_metrics";
      const actorRole = asTrimmed(body.actor_role ?? body.actorRole) ||
        "generated_ui_sandbox";
      const sessionId = asTrimmed(body.session_id) || "sandbox-session";
      const sandboxId = asTrimmed(body.sandbox_id) || "isolated_worker";
      const retryAttempt = clampInt(body.retry_attempt, 0, 1000, 0);
      const recentAttemptCount = clampInt(body.recent_attempt_count, 0, 1000, 0);
      const networkTarget = asTrimmed(body.network_egress_target) || null;
      const requestedScopes = parseAgentToolRequestedScopes(
        body.requested_scopes ?? body.requestedScopes ?? ["read"],
      );
      const approval = parseAgentToolApproval(body);

      const { data: storedPolicy } = await admin
        .from("agent_sandbox_policies")
        .select("*")
        .eq("user_id", effectiveUserId)
        .eq(
          "sandbox_profile",
          body.sandbox_profile === "strict_read_only"
            ? "strict_read_only"
            : "isolated_worker",
        )
        .maybeSingle();

      const policyRow = (storedPolicy ?? {}) as Record<string, unknown>;
      const decision = evaluateAgentSandboxPreflight({
        userId: effectiveUserId,
        sessionId,
        sandboxId,
        actorRole,
        toolName,
        requestedScopes,
        toolArgs: body.tool_args ?? body.toolArgs ?? {},
        promptText: asTrimmed(body.prompt_text ?? body.task),
        retryAttempt,
        recentAttemptCount,
        networkEgressTarget: networkTarget,
        enforceIsolatedToolAllowlist:
          action === "agent.sandbox.execute_isolated" ||
          body.sandbox_mode === true,
        approval,
        policy: {
          sandboxProfile: policyRow.sandbox_profile === "strict_read_only"
            ? "strict_read_only"
            : body.sandbox_profile === "strict_read_only"
            ? "strict_read_only"
            : "isolated_worker",
          networkEgressMode: policyRow.network_egress_mode === "allowlist_only"
            ? "allowlist_only"
            : "none",
          maxRetriesPerTool: clampInt(policyRow.max_retries_per_tool, 1, 5, 3),
          maxBurstPerWindow: clampInt(policyRow.max_burst_per_window, 1, 50, 10),
          allowedTools: Array.isArray(policyRow.allowed_tools)
            ? policyRow.allowed_tools.map((x) => String(x))
            : undefined,
        },
      });

      const latencyMs = Math.max(0, Date.now() - started);
      if (!decision.allowed) {
        const audit = await recordSandboxAuditEntry(admin, {
          userId: effectiveUserId,
          sessionId,
          sandboxId,
          actorRole,
          toolName,
          actionKind: "blocked_guard",
          decision,
          retryAttempt,
          networkEgressTarget: networkTarget,
          latencyMs,
        });
        return json({
          success: false,
          error: "agent_sandbox_blocked",
          decision,
          audit_logged: audit.logged,
          audit: audit.row,
        }, 403);
      }

      let executionOutput: Record<string, unknown> | null = null;
      if (action === "agent.sandbox.execute_isolated") {
        executionOutput = executeIsolatedSandboxTool(
          toolName,
          (body.tool_args ?? body.toolArgs ?? {}) as Record<string, unknown>,
        );
      }

      const audit = await recordSandboxAuditEntry(admin, {
        userId: effectiveUserId,
        sessionId,
        sandboxId,
        actorRole,
        toolName,
        actionKind: action === "agent.sandbox.execute_isolated"
          ? "tool_execution"
          : "sandbox_preflight",
        decision,
        retryAttempt,
        networkEgressTarget: networkTarget,
        latencyMs,
      });

      return json({
        success: true,
        decision,
        execution: executionOutput,
        audit_logged: audit.logged,
        audit: audit.row,
      });
    }

    case "agent.sandbox.audit_list": {
      const decisionFilter = asTrimmed(body.decision);
      const categoryFilter = asTrimmed(body.blocked_category);
      const limit = clampInt(body.limit, 1, 100, 30);

      let query = admin
        .from("agent_sandbox_security_audit")
        .select("*")
        .eq("user_id", effectiveUserId)
        .order("created_at", { ascending: false });

      if (decisionFilter === "allowed" || decisionFilter === "blocked") {
        query = query.eq("decision", decisionFilter);
      }
      if (categoryFilter && categoryFilter !== "all") {
        query = query.eq("blocked_category", categoryFilter);
      }

      const { data: logs, error } = await query.limit(limit);
      if (error) {
        return json({ error: error.message }, 500);
      }

      const { data: policyData } = await admin
        .from("agent_sandbox_policies")
        .select("*")
        .eq("user_id", effectiveUserId)
        .order("updated_at", { ascending: false })
        .limit(5);

      const rows = (Array.isArray(logs) ? logs : []) as Array<
        Record<string, unknown>
      >;
      const blockedCount = rows.filter((r) => r.decision === "blocked").length;
      const injectionCount = rows.filter((r) =>
        r.blocked_category === "prompt_injection"
      ).length;
      const anomalyCount = rows.filter((r) =>
        r.blocked_category === "excessive_retries" ||
        r.blocked_category === "invalid_tool_args"
      ).length;

      return json({
        success: true,
        audits: rows,
        policies: Array.isArray(policyData) ? policyData : [],
        summary: {
          total_count: rows.length,
          blocked_count: blockedCount,
          allowed_count: rows.length - blockedCount,
          prompt_injection_count: injectionCount,
          anomaly_count: anomalyCount,
        },
      });
    }

    default:
      return json({ error: `Unknown sandbox action: ${action}` }, 400);
  }
}
