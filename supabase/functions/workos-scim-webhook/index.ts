import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

import { corsHeaders } from "../_shared/edge.ts";
import {
  maskWorkosText,
  normalizeDirectorySyncEvent,
  sanitizeWorkosMetadata,
  verifyWorkosSignature,
  type NormalizedScimUserEvent,
} from "../_shared/workos_scim.ts";

const MAX_WEBHOOK_BYTES = 64 * 1024;

export const scimWebhookCorsHeaders: Record<string, string> = {
  ...corsHeaders,
  "Access-Control-Allow-Headers":
    `${corsHeaders["Access-Control-Allow-Headers"]}, workos-signature, traceparent, tracestate, baggage, sentry-trace`,
};

export interface ScimWebhookStore {
  hasProcessedEvent(workosEventId: string): Promise<boolean>;
  findOrganizationId(workosOrgId: string): Promise<string | null>;
  findSupabaseUserId(
    workosOrgId: string,
    directoryUserId: string,
  ): Promise<string | null>;
  upsertDirectoryMembership(
    organizationId: string,
    event: NormalizedScimUserEvent,
    supabaseUserId: string | null,
    syncedAtIso: string,
  ): Promise<void>;
  insertScimSyncEvent(
    organizationId: string | null,
    event: NormalizedScimUserEvent,
    summary: Record<string, unknown>,
    processedAtIso: string,
  ): Promise<void>;
}

export interface ScimWebhookDeps {
  hmacMaterial: string;
  nowMs?: () => number;
  store: ScimWebhookStore;
}

function scimJson(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...scimWebhookCorsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export function createSupabaseScimWebhookStore(
  admin: SupabaseClient,
): ScimWebhookStore {
  return {
    async hasProcessedEvent(workosEventId) {
      const { data } = await admin
        .from("workos_scim_sync_events")
        .select("id")
        .eq("workos_event_id", workosEventId)
        .maybeSingle();
      return Boolean(data);
    },
    async findOrganizationId(workosOrgId) {
      const { data } = await admin
        .from("workos_organizations")
        .select("id")
        .eq("workos_org_id", workosOrgId)
        .maybeSingle();
      return data ? String((data as { id: string }).id) : null;
    },
    async findSupabaseUserId(workosOrgId, directoryUserId) {
      const { data } = await admin
        .from("workos_user_link")
        .select("supabase_user_id")
        .eq("workos_org_id", workosOrgId)
        .eq("workos_user_id", directoryUserId)
        .maybeSingle();
      return data
        ? String((data as { supabase_user_id: string }).supabase_user_id)
        : null;
    },
    async upsertDirectoryMembership(
      organizationId,
      event,
      supabaseUserId,
      syncedAtIso,
    ) {
      const { error } = await admin
        .from("workos_directory_memberships")
        .upsert(
          {
            organization_id: organizationId,
            workos_org_id: event.workosOrgId,
            workos_directory_user_id: event.directoryUserId,
            workos_directory_id: event.directoryId,
            supabase_user_id: supabaseUserId,
            email: event.email,
            display_name: event.displayName,
            role: event.role,
            provisioning_status: event.targetStatus,
            last_event_type: event.eventType,
            last_synced_at: syncedAtIso,
          },
          { onConflict: "workos_org_id,workos_directory_user_id" },
        );
      if (error) {
        throw new Error(maskWorkosText(error.message));
      }
    },
    async insertScimSyncEvent(organizationId, event, summary, processedAtIso) {
      const { error } = await admin.from("workos_scim_sync_events").insert({
        organization_id: organizationId,
        workos_org_id: event.workosOrgId,
        workos_event_id: event.eventId,
        event_type: event.eventType,
        directory_user_id: event.directoryUserId,
        target_status: event.targetStatus,
        payload_summary: summary,
        processed_at: processedAtIso,
      });
      if (error) {
        throw new Error(maskWorkosText(error.message));
      }
    },
  };
}

export function createScimWebhookHandler(
  deps: ScimWebhookDeps,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: scimWebhookCorsHeaders });
    }
    if (req.method !== "POST") {
      return scimJson({ error: "Method not allowed" }, 405);
    }

    const rawBody = await req.text();
    if (new TextEncoder().encode(rawBody).length > MAX_WEBHOOK_BYTES) {
      return scimJson({ error: "Payload exceeds 64 KiB limit" }, 413);
    }

    const sigHeader = req.headers.get("WorkOS-Signature") ?? "";
    const sigResult = await verifyWorkosSignature({
      rawBody,
      signatureHeader: sigHeader,
      hmacMaterial: deps.hmacMaterial,
      nowMs: deps.nowMs ? deps.nowMs() : Date.now(),
    });
    if (!sigResult.ok) {
      return scimJson(
        { error: "Unauthorized webhook signature", reason: sigResult.reason },
        401,
      );
    }

    let parsedPayload: unknown;
    try {
      parsedPayload = JSON.parse(rawBody);
    } catch {
      return scimJson({ error: "Invalid JSON payload" }, 400);
    }

    let event: NormalizedScimUserEvent;
    try {
      event = normalizeDirectorySyncEvent(parsedPayload);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return scimJson({ error: maskWorkosText(msg) }, 400);
    }

    try {
      if (await deps.store.hasProcessedEvent(event.eventId)) {
        return scimJson({
          ok: true,
          duplicate: true,
          workos_event_id: event.eventId,
        });
      }

      const nowIso = new Date(
        deps.nowMs ? deps.nowMs() : Date.now(),
      ).toISOString();
      const orgId = await deps.store.findOrganizationId(event.workosOrgId);
      if (orgId) {
        const linkedSupabaseUser = await deps.store.findSupabaseUserId(
          event.workosOrgId,
          event.directoryUserId,
        );
        await deps.store.upsertDirectoryMembership(
          orgId,
          event,
          linkedSupabaseUser,
          nowIso,
        );
      }

      const summary = sanitizeWorkosMetadata({
        directory_id: event.directoryId,
        email_domain: event.email.includes("@")
          ? event.email.split("@")[1]
          : "",
        role: event.role,
        target_status: event.targetStatus,
        organization_matched: Boolean(orgId),
      });
      await deps.store.insertScimSyncEvent(orgId, event, summary, nowIso);

      return scimJson({
        ok: true,
        duplicate: false,
        workos_event_id: event.eventId,
        event_type: event.eventType,
        target_status: event.targetStatus,
        organization_matched: Boolean(orgId),
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return scimJson({ error: maskWorkosText(msg) }, 500);
    }
  };
}

if (import.meta.main) {
  Deno.serve((req: Request) => {
    const supabaseUrl = (Deno.env.get("SUPABASE_URL") ?? "").trim();
    const adminCred = (
      Deno.env.get("SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      ""
    ).trim();
    const webhookCred = (Deno.env.get("WORKOS_WEBHOOK_SECRET") ?? "").trim();
    if (!supabaseUrl || !adminCred) {
      return Promise.resolve(
        scimJson({ error: "Supabase service environment not configured" }, 500),
      );
    }
    const admin = createClient(supabaseUrl, adminCred);
    return createScimWebhookHandler({
      hmacMaterial: webhookCred,
      store: createSupabaseScimWebhookStore(admin),
    })(req);
  });
}
