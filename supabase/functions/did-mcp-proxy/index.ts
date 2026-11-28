import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  asRecord,
  asString,
  corsHeaders,
  jsonResponse,
} from "../_shared/edge.ts";
import { maskLogString, maskLogValue } from "../_shared/sensitive_log_masker.ts";

export const DID_MCP_DOCS_ENDPOINT = "https://docs.d-id.com/mcp";
export const DID_API_BASE_URL = "https://api.d-id.com";
export const UPSTREAM_TIMEOUT_MS = 15000;

const ALLOWED_UPSTREAM_HOSTS = new Set<string>([
  "docs.d-id.com",
  "api.d-id.com",
]);

export interface McpToolDescriptor {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
}

export const DID_MCP_TOOLS: readonly McpToolDescriptor[] = [
  {
    name: "did_generate_talk_video",
    description:
      "Queue a D-ID Talk avatar video from script text and optional presenter source URL.",
    inputSchema: {
      type: "object",
      required: ["script"],
      properties: {
        script: { type: "string", maxLength: 2000 },
        source_url: { type: "string" },
        voice_id: { type: "string" },
        dry_run: { type: "boolean", default: true },
      },
    },
  },
  {
    name: "did_agent_chat",
    description:
      "Send a prompt turn to an existing D-ID interactive Agent session.",
    inputSchema: {
      type: "object",
      required: ["agent_id", "message"],
      properties: {
        agent_id: { type: "string" },
        chat_id: { type: "string" },
        message: { type: "string", maxLength: 2000 },
        dry_run: { type: "boolean", default: true },
      },
    },
  },
  {
    name: "did_rag_query",
    description:
      "Search and ground D-ID Agent Knowledge bases or API docs for retrieval-augmented responses.",
    inputSchema: {
      type: "object",
      required: ["query"],
      properties: {
        knowledge_id: { type: "string" },
        query: { type: "string", maxLength: 500 },
        top_k: { type: "number", default: 5 },
        dry_run: { type: "boolean", default: true },
      },
    },
  },
  {
    name: "did_mcp_docs_lookup",
    description:
      "Forward a search query to D-ID's public Streamable HTTP MCP docs server (https://docs.d-id.com/mcp).",
    inputSchema: {
      type: "object",
      required: ["query"],
      properties: {
        query: { type: "string", maxLength: 500 },
        dry_run: { type: "boolean", default: true },
      },
    },
  },
];

const SUPPORTED_TOOL_NAMES = new Set<string>(
  DID_MCP_TOOLS.map((tool) => tool.name),
);

export interface AuthContext {
  authorized: boolean;
  isServiceRole: boolean;
  userId: string | null;
  reason?: string;
}

export interface RecordedProxyEvent {
  user_id: string | null;
  tool_name: string;
  rpc_method: "initialize" | "tools/list" | "tools/call";
  prompt_summary: string;
  sanitized_params: Record<string, unknown>;
  status: "queued" | "succeeded" | "rate_limited" | "failed";
  http_status: number;
  dry_run: boolean;
  alert_dispatched: boolean;
  upstream_host: "docs.d-id.com" | "api.d-id.com" | "dry-run" | null;
  error_message: string | null;
  latency_ms: number;
}

export interface RecordedMcpAlert {
  event_id: string | null;
  severity: "warning" | "critical";
  alert_type: "rate_limit" | "upstream_error" | "auth_failure" | "timeout";
  message: string;
}

export interface DidMcpProxyDeps {
  fetchFn?: typeof fetch;
  getEnv?: (key: string) => string;
  authenticate?: (req: Request) => Promise<AuthContext>;
  recordEvent?: (event: RecordedProxyEvent) => Promise<string | null>;
  recordAlert?: (alert: RecordedMcpAlert) => Promise<void>;
  listDashboard?: (
    userId: string | null,
    isServiceRole: boolean,
  ) => Promise<{
    events: Record<string, unknown>[];
    alerts: Record<string, unknown>[];
  }>;
  acknowledgeAlert?: (
    alertId: string,
    userId: string | null,
    isServiceRole: boolean,
  ) => Promise<Record<string, unknown> | null>;
  nowMs?: () => number;
}

function timingSafeEqualText(a: string, b: string): boolean {
  const encoder = new TextEncoder();
  const ab = encoder.encode(a);
  const bb = encoder.encode(b);
  if (ab.length === 0 || ab.length !== bb.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < ab.length; i++) {
    diff |= ab[i] ^ bb[i];
  }
  return diff === 0;
}

export function validateAllowedUpstreamUrl(rawUrl: string): URL {
  const parsed = new URL(rawUrl);
  if (parsed.protocol !== "https:") {
    throw new Error("Upstream protocol must be https");
  }
  if (parsed.username !== "" || parsed.password !== "") {
    throw new Error("Upstream credentials in URL are forbidden");
  }
  if (parsed.port !== "" && parsed.port !== "443") {
    throw new Error("Non-standard upstream port is forbidden");
  }
  if (!ALLOWED_UPSTREAM_HOSTS.has(parsed.hostname.toLowerCase())) {
    throw new Error(`Disallowed upstream host: ${parsed.hostname}`);
  }
  return parsed;
}

export function sanitizeProxyParams(
  input: Record<string, unknown>,
): Record<string, unknown> {
  const masked = maskLogValue(input);
  return asRecord(masked);
}

function summarizePrompt(
  toolName: string,
  args: Record<string, unknown>,
): string {
  const candidate =
    asString(args.script) ||
    asString(args.message) ||
    asString(args.query) ||
    toolName;
  const masked = maskLogString(candidate).replace(/\s+/g, " ").trim();
  return masked.length > 500 ? masked.slice(0, 500) : masked;
}

function createServiceSupabaseClient(getEnv: (key: string) => string) {
  const supabaseUrl = getEnv("SUPABASE_URL");
  const serviceKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return null;
  }
  return createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function defaultAuthenticate(
  req: Request,
  getEnv: (key: string) => string,
): Promise<AuthContext> {
  const authHeader = (req.headers.get("authorization") ?? "").trim();
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return {
      authorized: false,
      isServiceRole: false,
      userId: null,
      reason: "missing_bearer_token",
    };
  }
  const bearerValue = authHeader.slice(7).trim();
  if (!bearerValue) {
    return {
      authorized: false,
      isServiceRole: false,
      userId: null,
      reason: "empty_bearer_token",
    };
  }

  const serviceRoleCredential = getEnv("SUPABASE_SERVICE_ROLE_KEY");
  if (
    serviceRoleCredential &&
    timingSafeEqualText(bearerValue, serviceRoleCredential)
  ) {
    return {
      authorized: true,
      isServiceRole: true,
      userId: null,
    };
  }

  const supabaseUrl = getEnv("SUPABASE_URL");
  const anonKey = getEnv("SUPABASE_ANON_KEY") || serviceRoleCredential;
  if (!supabaseUrl || !anonKey) {
    return {
      authorized: false,
      isServiceRole: false,
      userId: null,
      reason: "supabase_env_not_configured",
    };
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${bearerValue}` } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(
    bearerValue,
  );
  if (userError || !userData?.user) {
    return {
      authorized: false,
      isServiceRole: false,
      userId: null,
      reason: "invalid_user_jwt",
    };
  }

  const adminClient = createServiceSupabaseClient(getEnv);
  if (!adminClient) {
    return {
      authorized: false,
      isServiceRole: false,
      userId: userData.user.id,
      reason: "service_client_unavailable",
    };
  }

  const { data: profile, error: profileError } = await adminClient
    .from("user_profiles")
    .select("is_admin")
    .eq("user_id", userData.user.id)
    .maybeSingle();

  if (profileError || profile?.is_admin !== true) {
    return {
      authorized: false,
      isServiceRole: false,
      userId: userData.user.id,
      reason: "admin_role_required",
    };
  }

  return {
    authorized: true,
    isServiceRole: false,
    userId: userData.user.id,
  };
}

function buildDryRunPreview(
  toolName: string,
  args: Record<string, unknown>,
): Record<string, unknown> {
  const sanitized = sanitizeProxyParams(args);
  switch (toolName) {
    case "did_generate_talk_video":
      return {
        dry_run: true,
        target_endpoint: `${DID_API_BASE_URL}/talks`,
        planned_payload: {
          script: {
            type: "text",
            input: asString(sanitized.script) || "Hello from Jibun Inc MCP.",
          },
          source_url: asString(sanitized.source_url) || "default_presenter",
        },
        message: "Dry-run preview ready. No external D-ID talk credits consumed.",
      };
    case "did_agent_chat":
      return {
        dry_run: true,
        target_endpoint: `${DID_API_BASE_URL}/agents/${encodeURIComponent(asString(sanitized.agent_id) || "agent_default")}/chat`,
        planned_payload: {
          messages: [
            { role: "user", content: asString(sanitized.message) || "" },
          ],
        },
        message: "Dry-run preview ready for D-ID interactive Agent turn.",
      };
    case "did_rag_query":
      return {
        dry_run: true,
        target_endpoint: `${DID_API_BASE_URL}/knowledge/${encodeURIComponent(asString(sanitized.knowledge_id) || "default")}/query`,
        planned_payload: {
          query: asString(sanitized.query) || "",
          top_k: typeof sanitized.top_k === "number" ? sanitized.top_k : 5,
        },
        message: "Dry-run RAG retrieval payload prepared cleanly.",
      };
    default:
      return {
        dry_run: true,
        target_endpoint: DID_MCP_DOCS_ENDPOINT,
        planned_rpc: {
          jsonrpc: "2.0",
          method: "tools/call",
          params: {
            name: "search-endpoints",
            arguments: { query: asString(sanitized.query) || "talks" },
          },
        },
        message: "Dry-run Streamable HTTP request prepared for D-ID MCP docs server.",
      };
  }
}

async function fetchWithGuard(
  fetchFn: typeof fetch,
  url: string,
  init: RequestInit,
): Promise<Response> {
  const validated = validateAllowedUpstreamUrl(url);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
  try {
    const response = await fetchFn(validated.toString(), {
      ...init,
      redirect: "error",
      signal: controller.signal,
    });
    if (response.redirected) {
      throw new Error("Upstream HTTP redirects are blocked");
    }
    return response;
  } finally {
    clearTimeout(timer);
  }
}

export function createHandler(deps: DidMcpProxyDeps = {}) {
  const getEnv = deps.getEnv ?? ((k: string) => (Deno.env.get(k) ?? "").trim());
  const fetchFn = deps.fetchFn ?? fetch;
  const nowMs = deps.nowMs ?? (() => Date.now());
  const authenticate =
    deps.authenticate ?? ((req: Request) => defaultAuthenticate(req, getEnv));

  const recordEvent = deps.recordEvent ?? (async (event: RecordedProxyEvent) => {
    const admin = createServiceSupabaseClient(getEnv);
    if (!admin) return null;
    const { data, error } = await admin
      .from("did_mcp_proxy_events")
      .insert(event)
      .select("id")
      .maybeSingle();
    if (error) {
      throw new Error(`did_mcp_proxy_events insert failed: ${error.message}`);
    }
    if (!data) return null;
    return asString(data.id) || null;
  });

  const recordAlert = deps.recordAlert ?? (async (alert: RecordedMcpAlert) => {
    const admin = createServiceSupabaseClient(getEnv);
    if (!admin) return;
    const { error } = await admin.from("did_mcp_alerts").insert(alert);
    if (error) {
      throw new Error(`did_mcp_alerts insert failed: ${error.message}`);
    }
  });

  const safeRecordEvent = async (
    event: RecordedProxyEvent,
  ): Promise<string | null> => {
    try {
      return await recordEvent(event);
    } catch (err) {
      console.warn(
        "did-mcp-proxy event logging failed:",
        maskLogString(err instanceof Error ? err.message : String(err)),
      );
      return null;
    }
  };

  const safeRecordAlert = async (alert: RecordedMcpAlert): Promise<void> => {
    try {
      await recordAlert(alert);
    } catch (err) {
      console.warn(
        "did-mcp-proxy alert logging failed:",
        maskLogString(err instanceof Error ? err.message : String(err)),
      );
    }
  };

  const listDashboard = deps.listDashboard ?? (async () => {
    const admin = createServiceSupabaseClient(getEnv);
    if (!admin) return { events: [], alerts: [] };
    const [
      { data: events, error: eventsError },
      { data: alerts, error: alertsError },
    ] = await Promise.all([
      admin
        .from("did_mcp_proxy_events")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(40),
      admin
        .from("did_mcp_alerts")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(40),
    ]);
    if (eventsError) {
      throw new Error(
        `did_mcp_proxy_events query failed: ${eventsError.message}`,
      );
    }
    if (alertsError) {
      throw new Error(`did_mcp_alerts query failed: ${alertsError.message}`);
    }
    return {
      events: Array.isArray(events)
        ? events.map((row) => asRecord(row))
        : [],
      alerts: Array.isArray(alerts)
        ? alerts.map((row) => asRecord(row))
        : [],
    };
  });

  const acknowledgeAlert = deps.acknowledgeAlert ?? (async (
    alertId: string,
    userId: string | null,
    isServiceRole: boolean,
  ) => {
    const admin = createServiceSupabaseClient(getEnv);
    if (!admin) return null;
    if (!isServiceRole && !userId) return null;
    const { data, error } = await admin
      .from("did_mcp_alerts")
      .update({
        acknowledged: true,
        acknowledged_by: userId,
        acknowledged_at: new Date().toISOString(),
      })
      .eq("id", alertId)
      .select("*")
      .maybeSingle();
    if (error) {
      throw new Error(`did_mcp_alerts update failed: ${error.message}`);
    }
    if (!data) return null;
    return asRecord(data);
  });

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    if (req.method !== "POST") {
      return jsonResponse({ error: "method_not_allowed" }, 405);
    }

    const auth = await authenticate(req);
    if (!auth.authorized) {
      return jsonResponse(
        {
          error: "unauthorized",
          reason: auth.reason ?? "authentication_required",
        },
        401,
      );
    }

    let rawBody: Record<string, unknown>;
    try {
      const parsed = await req.json();
      rawBody = asRecord(parsed);
    } catch {
      return jsonResponse({ error: "invalid_json_body" }, 400);
    }

    const action = asString(rawBody.action);
    if (action === "list_events") {
      try {
        const dashboard = await listDashboard(auth.userId, auth.isServiceRole);
        return jsonResponse({ ok: true, ...dashboard }, 200);
      } catch (err) {
        return jsonResponse(
          {
            error: "dashboard_query_failed",
            detail: maskLogString(
              err instanceof Error ? err.message : String(err),
            ).slice(0, 200),
          },
          500,
        );
      }
    }

    if (action === "acknowledge_alert") {
      const alertId = asString(rawBody.alert_id);
      if (!alertId) {
        return jsonResponse({ error: "alert_id_required" }, 400);
      }
      try {
        const updated = await acknowledgeAlert(
          alertId,
          auth.userId,
          auth.isServiceRole,
        );
        if (!updated) {
          return jsonResponse({ error: "alert_not_found" }, 404);
        }
        return jsonResponse({ ok: true, alert: updated }, 200);
      } catch (err) {
        return jsonResponse(
          {
            error: "alert_acknowledge_failed",
            detail: maskLogString(
              err instanceof Error ? err.message : String(err),
            ).slice(0, 200),
          },
          500,
        );
      }
    }

    const rpcId = rawBody.id ?? null;
    const method = asString(rawBody.method) || "tools/call";

    if (method === "initialize") {
      return jsonResponse(
        {
          jsonrpc: "2.0",
          id: rpcId,
          result: {
            protocolVersion: "2024-11-05",
            serverInfo: {
              name: "jibun-did-mcp-proxy",
              version: "1.0.0",
            },
            capabilities: { tools: {} },
          },
        },
        200,
      );
    }

    if (method === "tools/list") {
      return jsonResponse(
        {
          jsonrpc: "2.0",
          id: rpcId,
          result: { tools: DID_MCP_TOOLS },
        },
        200,
      );
    }

    if (method !== "tools/call") {
      return jsonResponse(
        {
          jsonrpc: "2.0",
          id: rpcId,
          error: { code: -32601, message: `Unsupported MCP method: ${method}` },
        },
        400,
      );
    }

    const params = asRecord(rawBody.params);
    const toolName = asString(params.name) || asString(rawBody.tool_name);
    const toolArgs = asRecord(
      params.arguments ?? rawBody.arguments ?? rawBody.params,
    );
    if (!SUPPORTED_TOOL_NAMES.has(toolName)) {
      return jsonResponse(
        {
          jsonrpc: "2.0",
          id: rpcId,
          error: { code: -32602, message: `Unknown MCP tool: ${toolName}` },
        },
        400,
      );
    }

    const dryRun = toolArgs.dry_run === true || rawBody.dry_run === true;
    const sanitizedParams = sanitizeProxyParams(toolArgs);
    const promptSummary = summarizePrompt(toolName, toolArgs);
    const startedMs = nowMs();

    if (dryRun) {
      const preview = buildDryRunPreview(toolName, toolArgs);
      const latency = Math.max(0, nowMs() - startedMs);
      const eventId = await recordEvent({
        user_id: auth.userId,
        tool_name: toolName,
        rpc_method: "tools/call",
        prompt_summary: promptSummary,
        sanitized_params: sanitizedParams,
        status: "queued",
        http_status: 200,
        dry_run: true,
        alert_dispatched: false,
        upstream_host: "dry-run",
        error_message: null,
        latency_ms: latency,
      });
      return jsonResponse(
        {
          jsonrpc: "2.0",
          id: rpcId,
          result: {
            event_id: eventId,
            content: [{ type: "text", text: JSON.stringify(preview) }],
            structuredContent: preview,
          },
        },
        200,
      );
    }

    const isDocsTool = toolName === "did_mcp_docs_lookup";
    const upstreamUrl = isDocsTool
      ? DID_MCP_DOCS_ENDPOINT
      : toolName === "did_agent_chat"
      ? `${DID_API_BASE_URL}/agents/${encodeURIComponent(asString(toolArgs.agent_id) || "default")}/chat`
      : toolName === "did_rag_query"
      ? `${DID_API_BASE_URL}/knowledge/${encodeURIComponent(asString(toolArgs.knowledge_id) || "default")}/query`
      : `${DID_API_BASE_URL}/talks`;

    const didApiKey = getEnv("D_ID_API_KEY");
    if (!isDocsTool && !didApiKey) {
      const latency = Math.max(0, nowMs() - startedMs);
      const eventId = await safeRecordEvent({
        user_id: auth.userId,
        tool_name: toolName,
        rpc_method: "tools/call",
        prompt_summary: promptSummary,
        sanitized_params: sanitizedParams,
        status: "failed",
        http_status: 503,
        dry_run: false,
        alert_dispatched: true,
        upstream_host: "api.d-id.com",
        error_message: "D_ID_API_KEY is not configured in server secrets",
        latency_ms: latency,
      });
      await safeRecordAlert({
        event_id: eventId,
        severity: "critical",
        alert_type: "auth_failure",
        message: "D_ID_API_KEY is missing in Supabase Edge Function secrets",
      });
      return jsonResponse(
        { error: "did_api_key_not_configured", event_id: eventId },
        503,
      );
    }

    try {
      const headers: Record<string, string> = {
        "Content-Type": "application/json",
        Accept: isDocsTool
          ? "application/json, text/event-stream"
          : "application/json",
      };
      if (!isDocsTool && didApiKey) {
        headers.Authorization = `Basic ${didApiKey}`;
      }

      const upstreamPayload = isDocsTool
        ? {
          jsonrpc: "2.0",
          id: rpcId ?? 1,
          method: "tools/call",
          params: {
            name: "search-endpoints",
            arguments: { query: asString(toolArgs.query) || "talks" },
          },
        }
        : buildDryRunPreview(toolName, toolArgs).planned_payload;

      const response = await fetchWithGuard(fetchFn, upstreamUrl, {
        method: "POST",
        headers,
        body: JSON.stringify(upstreamPayload),
      });

      const latency = Math.max(0, nowMs() - startedMs);
      const rawText = await response.text();
      const safeText = maskLogString(rawText);

      if (response.status === 429) {
        const eventId = await safeRecordEvent({
          user_id: auth.userId,
          tool_name: toolName,
          rpc_method: "tools/call",
          prompt_summary: promptSummary,
          sanitized_params: sanitizedParams,
          status: "rate_limited",
          http_status: 429,
          dry_run: false,
          alert_dispatched: true,
          upstream_host: isDocsTool ? "docs.d-id.com" : "api.d-id.com",
          error_message: "D-ID upstream returned HTTP 429 Too Many Requests",
          latency_ms: latency,
        });
        await safeRecordAlert({
          event_id: eventId,
          severity: "critical",
          alert_type: "rate_limit",
          message: `HTTP 429 rate limit received on ${toolName}`,
        });
        return jsonResponse(
          {
            error: "upstream_rate_limited",
            http_status: 429,
            event_id: eventId,
            detail: safeText.slice(0, 400),
          },
          429,
        );
      }

      if (!response.ok) {
        const eventId = await safeRecordEvent({
          user_id: auth.userId,
          tool_name: toolName,
          rpc_method: "tools/call",
          prompt_summary: promptSummary,
          sanitized_params: sanitizedParams,
          status: "failed",
          http_status: response.status,
          dry_run: false,
          alert_dispatched: true,
          upstream_host: isDocsTool ? "docs.d-id.com" : "api.d-id.com",
          error_message: safeText.slice(0, 500) || `HTTP ${response.status}`,
          latency_ms: latency,
        });
        await safeRecordAlert({
          event_id: eventId,
          severity: response.status >= 500 ? "critical" : "warning",
          alert_type: response.status === 401 || response.status === 403
            ? "auth_failure"
            : "upstream_error",
          message: `D-ID upstream HTTP ${response.status} on ${toolName}`,
        });
        return jsonResponse(
          {
            error: "upstream_error",
            http_status: response.status,
            event_id: eventId,
            detail: safeText.slice(0, 400),
          },
          502,
        );
      }

      let structured: unknown = safeText;
      try {
        structured = maskLogValue(JSON.parse(rawText));
      } catch {
        // Keep masked plain text response when upstream returns SSE or text.
      }

      const eventId = await recordEvent({
        user_id: auth.userId,
        tool_name: toolName,
        rpc_method: "tools/call",
        prompt_summary: promptSummary,
        sanitized_params: sanitizedParams,
        status: "succeeded",
        http_status: response.status,
        dry_run: false,
        alert_dispatched: false,
        upstream_host: isDocsTool ? "docs.d-id.com" : "api.d-id.com",
        error_message: null,
        latency_ms: latency,
      });

      return jsonResponse(
        {
          jsonrpc: "2.0",
          id: rpcId,
          result: {
            event_id: eventId,
            structuredContent: structured,
            content: [{ type: "text", text: safeText.slice(0, 1200) }],
          },
        },
        200,
      );
    } catch (err) {
      const latency = Math.max(0, nowMs() - startedMs);
      const errMsg = maskLogString(
        err instanceof Error ? err.message : String(err),
      ).slice(0, 500);
      const isTimeout = errMsg.toLowerCase().includes("abort");
      const eventId = await safeRecordEvent({
        user_id: auth.userId,
        tool_name: toolName,
        rpc_method: "tools/call",
        prompt_summary: promptSummary,
        sanitized_params: sanitizedParams,
        status: "failed",
        http_status: isTimeout ? 504 : 502,
        dry_run: false,
        alert_dispatched: true,
        upstream_host: isDocsTool ? "docs.d-id.com" : "api.d-id.com",
        error_message: errMsg,
        latency_ms: latency,
      });
      await safeRecordAlert({
        event_id: eventId,
        severity: "critical",
        alert_type: isTimeout ? "timeout" : "upstream_error",
        message: `D-ID MCP proxy transport failure on ${toolName}: ${errMsg}`,
      });
      return jsonResponse(
        {
          error: isTimeout ? "upstream_timeout" : "upstream_transport_error",
          event_id: eventId,
        },
        isTimeout ? 504 : 502,
      );
    }
  };
}

if (import.meta.main) {
  serve(createHandler());
}
