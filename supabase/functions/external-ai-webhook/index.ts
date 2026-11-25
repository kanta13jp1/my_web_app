import { createClient } from "npm:@supabase/supabase-js@2";

import { asRecord, asString, corsHeaders } from "../_shared/edge.ts";
import { sha256Hex } from "../_shared/internal_hmac.ts";
import {
  MASK_PLACEHOLDER,
  maskLogString,
  maskLogValue,
} from "../_shared/sensitive_log_masker.ts";

export const VALID_SOURCE_TOOLS = new Set([
  "n8n",
  "zapier",
  "analytics",
  "custom",
]);
export const VALID_PROCESSING_STATUSES = new Set([
  "received",
  "processed",
  "failed",
]);
const MAX_BODY_BYTES = 64 * 1024;
const MAX_PAYLOAD_JSON_BYTES = 32_768;
const EXTRA_SENSITIVE_KEYS: readonly string[] = [
  "webhook_secret",
  "webhook_api_key",
  "signing_secret",
  "x_webhook_api_key",
];
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const webhookCorsHeaders: Record<string, string> = {
  ...corsHeaders,
  "Access-Control-Allow-Headers":
    `${corsHeaders["Access-Control-Allow-Headers"]}, x-webhook-api-key, traceparent, tracestate, baggage, sentry-trace`,
};

export interface WebhookApiKeyRecord {
  id: string;
  user_id: string;
  key_hash: string;
  is_active: boolean;
}

export interface StoredWebhookEvent {
  id: string;
  user_id: string;
  source_tool: string;
  event_type: string;
  external_event_id: string;
  payload: Record<string, unknown>;
  auth_method: "api_key" | "jwt";
  processing_status: "received" | "processed" | "failed";
  error_message: string;
  created_at: string;
}

export interface InsertWebhookEventInput {
  user_id: string;
  source_tool: string;
  event_type: string;
  external_event_id: string;
  payload: Record<string, unknown>;
  auth_method: "api_key" | "jwt";
  processing_status: "received" | "processed" | "failed";
  error_message: string;
}

export interface ExternalWebhookEnv {
  supabaseUrl: string;
  adminRoleCredential: string;
}

export interface ExternalWebhookDependencies {
  env: ExternalWebhookEnv;
  verifyJwtUser: (
    jwtInput: string,
  ) => Promise<{ id: string; isAdmin: boolean } | null>;
  lookupCredentialByHash: (
    credentialHash: string,
  ) => Promise<WebhookApiKeyRecord | null>;
  touchApiKeyLastUsed: (keyId: string, usedAtIso: string) => Promise<void>;
  insertEvent: (input: InsertWebhookEventInput) => Promise<StoredWebhookEvent>;
}

function webhookJson(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...webhookCorsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export function constantTimeEqual(left: string, right: string): boolean {
  if (left.length !== right.length || left.length === 0) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < left.length; i += 1) {
    diff |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return diff === 0;
}

const TOKEN_SECRET_RE =
  /\b(?:ghp|gho|ghu|ghs|ghr|github_pat|sk|eaw)[_-][A-Za-z0-9_-]{8,}\b/g;

function maskWebhookString(input: string): string {
  return maskLogString(input, EXTRA_SENSITIVE_KEYS).replace(
    TOKEN_SECRET_RE,
    MASK_PLACEHOLDER,
  );
}

export function sanitizeWebhookPayload(
  rawPayload: unknown,
): Record<string, unknown> {
  if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
    return {};
  }
  const masked = maskLogValue(rawPayload, {
    extraKeys: EXTRA_SENSITIVE_KEYS,
    maxDepth: 6,
  });
  return asRecord(masked);
}

export function defaultEnv(): ExternalWebhookEnv {
  return {
    supabaseUrl: asString(Deno.env.get("SUPABASE_URL")),
    adminRoleCredential: asString(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")),
  };
}

export function createDefaultDependencies(
  env: ExternalWebhookEnv,
): ExternalWebhookDependencies {
  const admin = env.supabaseUrl && env.adminRoleCredential
    ? createClient(env.supabaseUrl, env.adminRoleCredential)
    : null;

  return {
    env,
    verifyJwtUser: async (jwtInput: string) => {
      if (!admin || !jwtInput) return null;
      const { data, error } = await admin.auth.getUser(jwtInput);
      if (error || !data.user || data.user.is_anonymous) {
        return null;
      }
      const { data: profile, error: profileError } = await admin
        .from("user_profiles")
        .select("is_admin")
        .eq("user_id", data.user.id)
        .maybeSingle();
      if (profileError) {
        throw new Error(`Failed to load user profile: ${profileError.message}`);
      }
      return {
        id: data.user.id,
        isAdmin: profile?.is_admin === true,
      };
    },
    lookupCredentialByHash: async (credentialHash: string) => {
      if (!admin || !credentialHash) return null;
      const { data, error } = await admin
        .from("external_ai_webhook_keys")
        .select("id, user_id, key_hash, is_active")
        .eq("key_hash", credentialHash)
        .maybeSingle();
      if (error) {
        throw new Error(`Failed to verify webhook API key: ${error.message}`);
      }
      if (!data) return null;
      return {
        id: asString(data.id),
        user_id: asString(data.user_id),
        key_hash: asString(data.key_hash).toLowerCase(),
        is_active: data.is_active === true,
      };
    },
    touchApiKeyLastUsed: async (keyId: string, usedAtIso: string) => {
      if (!admin || !keyId) return;
      const { error } = await admin
        .from("external_ai_webhook_keys")
        .update({ last_used_at: usedAtIso })
        .eq("id", keyId);
      if (error) {
        throw new Error(`Failed to update key last_used_at: ${error.message}`);
      }
    },
    insertEvent: async (input: InsertWebhookEventInput) => {
      if (!admin) {
        throw new Error("Supabase admin client is not configured");
      }
      const { data, error } = await admin
        .from("external_ai_webhook_events")
        .insert(input)
        .select("*")
        .single();
      if (error || !data) {
        throw new Error(
          `Failed to persist external_ai_webhook_events: ${error?.message ?? "no row returned"}`,
        );
      }
      const row = asRecord(data);
      return {
        id: asString(row.id),
        user_id: asString(row.user_id),
        source_tool: asString(row.source_tool),
        event_type: asString(row.event_type),
        external_event_id: asString(row.external_event_id),
        payload: asRecord(row.payload),
        auth_method: asString(row.auth_method) === "api_key" ? "api_key" : "jwt",
        processing_status: asString(row.processing_status) === "processed"
          ? "processed"
          : asString(row.processing_status) === "failed"
          ? "failed"
          : "received",
        error_message: asString(row.error_message),
        created_at: asString(row.created_at),
      };
    },
  };
}

export function createHandler(deps: ExternalWebhookDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return new Response("ok", { headers: webhookCorsHeaders });
    }
    if (request.method !== "POST") {
      return webhookJson({ error: "method_not_allowed" }, 405);
    }

    const contentLength = Number(request.headers.get("content-length") ?? "0");
    if (Number.isFinite(contentLength) && contentLength > MAX_BODY_BYTES) {
      return webhookJson({ error: "payload_too_large" }, 413);
    }
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
      return webhookJson({ error: "payload_too_large" }, 413);
    }

    let bodyObj: Record<string, unknown>;
    try {
      const parsed = JSON.parse(rawBody);
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        return webhookJson({ error: "invalid_json_object" }, 400);
      }
      bodyObj = parsed as Record<string, unknown>;
    } catch {
      return webhookJson({ error: "invalid_json" }, 400);
    }

    const incomingCredential = asString(request.headers.get("x-webhook-api-key"));
    const authHeader = request.headers.get("authorization") ?? "";
    const bearerMatch = /^Bearer\s+(.+)$/i.exec(authHeader.trim());
    const bearerValue = bearerMatch ? bearerMatch[1].trim() : "";

    let authMethod: "api_key" | "jwt";
    let userId = "";
    let matchedKeyId = "";
    let isPrivilegedCaller = false;

    if (incomingCredential) {
      if (incomingCredential.length < 16 || incomingCredential.length > 256) {
        return webhookJson({ error: "invalid_api_key" }, 401);
      }
      const keyHash = (await sha256Hex(incomingCredential)).toLowerCase();
      let keyRecord: WebhookApiKeyRecord | null = null;
      try {
        keyRecord = await deps.lookupCredentialByHash(keyHash);
      } catch (error) {
        const message = maskWebhookString(
          error instanceof Error ? error.message : "Key lookup failed",
        );
        return webhookJson({ error: "auth_backend_error", message }, 502);
      }
      if (
        !keyRecord ||
        !constantTimeEqual(keyHash, keyRecord.key_hash.toLowerCase())
      ) {
        return webhookJson({ error: "invalid_api_key" }, 401);
      }
      if (!keyRecord.is_active || !keyRecord.user_id) {
        return webhookJson({ error: "revoked_api_key" }, 403);
      }
      authMethod = "api_key";
      userId = keyRecord.user_id;
      matchedKeyId = keyRecord.id;
    } else if (bearerValue) {
      if (
        deps.env.adminRoleCredential &&
        constantTimeEqual(bearerValue, deps.env.adminRoleCredential)
      ) {
        authMethod = "jwt";
        isPrivilegedCaller = true;
        const requestedUserId = asString(bodyObj.user_id);
        if (!UUID_RE.test(requestedUserId)) {
          return webhookJson({ error: "valid_user_id_required" }, 400);
        }
        userId = requestedUserId;
      } else {
        let jwtUser: { id: string; isAdmin: boolean } | null = null;
        try {
          jwtUser = await deps.verifyJwtUser(bearerValue);
        } catch (error) {
          const message = maskWebhookString(
            error instanceof Error ? error.message : "JWT verification error",
          );
          return webhookJson({ error: "auth_backend_error", message }, 502);
        }
        if (!jwtUser) {
          return webhookJson({ error: "unauthorized" }, 401);
        }
        authMethod = "jwt";
        isPrivilegedCaller = jwtUser.isAdmin;
        userId = jwtUser.id;
      }
    } else {
      return webhookJson({ error: "authentication_required" }, 401);
    }

    const bodyUserId = asString(bodyObj.user_id);
    if (bodyUserId && bodyUserId !== userId && !isPrivilegedCaller) {
      return webhookJson({ error: "forbidden_user_mismatch" }, 403);
    }
    if (bodyUserId && isPrivilegedCaller && UUID_RE.test(bodyUserId)) {
      userId = bodyUserId;
    }

    const rawSource = asString(bodyObj.source_tool);
    const sourceTool = rawSource ? rawSource.toLowerCase() : "custom";
    if (!VALID_SOURCE_TOOLS.has(sourceTool)) {
      return webhookJson({ error: "invalid_source_tool" }, 400);
    }

    const eventType = asString(bodyObj.event_type);
    if (!eventType || eventType.length > 120) {
      return webhookJson({ error: "invalid_event_type" }, 400);
    }

    const externalEventId = asString(bodyObj.external_event_id).slice(0, 120);
    if (
      bodyObj.payload !== undefined &&
      (typeof bodyObj.payload !== "object" ||
        bodyObj.payload === null ||
        Array.isArray(bodyObj.payload))
    ) {
      return webhookJson({ error: "payload_must_be_object" }, 400);
    }
    const sanitizedPayload = sanitizeWebhookPayload(bodyObj.payload);
    if (
      new TextEncoder().encode(JSON.stringify(sanitizedPayload)).length >
      MAX_PAYLOAD_JSON_BYTES
    ) {
      return webhookJson({ error: "event_payload_too_large" }, 413);
    }

    const rawStatus = asString(bodyObj.processing_status).toLowerCase() || "received";
    if (!VALID_PROCESSING_STATUSES.has(rawStatus)) {
      return webhookJson({ error: "invalid_processing_status" }, 400);
    }
    const processingStatus = rawStatus as "received" | "processed" | "failed";
    const errorMessage = maskWebhookString(
      asString(bodyObj.error_message),
    ).slice(0, 1000);

    const dryRun = bodyObj.dry_run === true;
    const eventInput: InsertWebhookEventInput = {
      user_id: userId,
      source_tool: sourceTool,
      event_type: eventType,
      external_event_id: externalEventId,
      payload: sanitizedPayload,
      auth_method: authMethod,
      processing_status: processingStatus,
      error_message: errorMessage,
    };

    if (dryRun) {
      return webhookJson({
        ok: true,
        dry_run: true,
        auth_method: authMethod,
        user_id: userId,
        event_preview: eventInput,
      });
    }

    try {
      if (matchedKeyId) {
        await deps.touchApiKeyLastUsed(matchedKeyId, new Date().toISOString());
      }
      const stored = await deps.insertEvent(eventInput);
      return webhookJson(
        {
          ok: true,
          id: stored.id,
          auth_method: stored.auth_method,
          source_tool: stored.source_tool,
          event_type: stored.event_type,
          processing_status: stored.processing_status,
          created_at: stored.created_at,
          event: stored,
        },
        201,
      );
    } catch (error) {
      const message = maskWebhookString(
        error instanceof Error ? error.message : "Failed to save webhook event",
      );
      return webhookJson({ error: "webhook_persist_failed", message }, 502);
    }
  };
}

if (import.meta.main) {
  const handler = createHandler(createDefaultDependencies(defaultEnv()));
  Deno.serve(handler);
}
