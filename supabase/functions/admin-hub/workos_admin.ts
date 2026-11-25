import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

import {
  evaluateOrgProvisioningAccess,
  maskWorkosText,
  VALID_ORG_ROLES,
  VALID_PORTAL_INTENTS,
  type WorkosOrgRole,
  type WorkosPortalIntent,
  type WorkosProvisioningStatus,
} from "../_shared/workos_scim.ts";

export interface WorkosOrgRecord {
  id: string;
  workos_org_id: string;
  organization_name: string;
  owner_user_id: string;
  scim_enabled: boolean;
  default_role: string;
  admin_portal_last_intent: string;
  last_portal_generated_at: string | null;
}

export interface WorkosMemberRecord {
  id: string;
  organization_id: string;
  workos_org_id: string;
  workos_directory_user_id: string;
  supabase_user_id: string | null;
  email: string;
  display_name: string;
  role: string;
  provisioning_status: string;
  last_event_type: string;
  last_synced_at: string;
}

export interface WorkosAdminCaller {
  userId: string | null;
  isServiceRole: boolean;
}

export interface WorkosAdminStore {
  isGlobalAdmin(userId: string): Promise<boolean>;
  getOrganization(workosOrgId: string): Promise<WorkosOrgRecord | null>;
  getActiveAdminMembership(
    workosOrgId: string,
    userId: string,
  ): Promise<WorkosMemberRecord | null>;
  touchPortalGenerated(
    workosOrgId: string,
    intent: WorkosPortalIntent,
    generatedAtIso: string,
  ): Promise<void>;
  updateMembershipRole(
    workosOrgId: string,
    directoryUserId: string,
    role: WorkosOrgRole,
  ): Promise<WorkosMemberRecord | null>;
}

export interface WorkosAdminResponse {
  status: number;
  body: Record<string, unknown>;
}

export function createSupabaseWorkosAdminStore(
  admin: SupabaseClient,
): WorkosAdminStore {
  return {
    async isGlobalAdmin(userId) {
      const { data, error } = await admin
        .from("user_profiles")
        .select("is_admin, role")
        .eq("user_id", userId)
        .maybeSingle();
      if (error || !data) return false;
      const row = data as { is_admin?: boolean | null; role?: string | null };
      return row.is_admin === true || row.role === "admin";
    },
    async getOrganization(workosOrgId) {
      const { data, error } = await admin
        .from("workos_organizations")
        .select(
          "id,workos_org_id,organization_name,owner_user_id,scim_enabled,default_role,admin_portal_last_intent,last_portal_generated_at",
        )
        .eq("workos_org_id", workosOrgId)
        .maybeSingle();
      if (error || !data) return null;
      return data as WorkosOrgRecord;
    },
    async getActiveAdminMembership(workosOrgId, userId) {
      const { data, error } = await admin
        .from("workos_directory_memberships")
        .select(
          "id,organization_id,workos_org_id,workos_directory_user_id,supabase_user_id,email,display_name,role,provisioning_status,last_event_type,last_synced_at",
        )
        .eq("workos_org_id", workosOrgId)
        .eq("supabase_user_id", userId)
        .eq("provisioning_status", "active")
        .maybeSingle();
      if (error || !data) return null;
      return data as WorkosMemberRecord;
    },
    async touchPortalGenerated(workosOrgId, intent, generatedAtIso) {
      await admin
        .from("workos_organizations")
        .update({
          admin_portal_last_intent: intent,
          last_portal_generated_at: generatedAtIso,
          updated_at: generatedAtIso,
        })
        .eq("workos_org_id", workosOrgId);
    },
    async updateMembershipRole(workosOrgId, directoryUserId, role) {
      const { data, error } = await admin
        .from("workos_directory_memberships")
        .update({
          role,
          last_synced_at: new Date().toISOString(),
        })
        .eq("workos_org_id", workosOrgId)
        .eq("workos_directory_user_id", directoryUserId)
        .select(
          "id,organization_id,workos_org_id,workos_directory_user_id,supabase_user_id,email,display_name,role,provisioning_status,last_event_type,last_synced_at",
        )
        .maybeSingle();
      if (error || !data) return null;
      return data as WorkosMemberRecord;
    },
  };
}

async function authorizeTenantAdmin(
  store: WorkosAdminStore,
  caller: WorkosAdminCaller,
  org: WorkosOrgRecord,
): Promise<{ authorized: boolean; reason: string }> {
  if (caller.isServiceRole) {
    return { authorized: true, reason: "service_role" };
  }
  if (!caller.userId) {
    return { authorized: false, reason: "missing_user" };
  }
  if (org.owner_user_id === caller.userId) {
    return { authorized: true, reason: "org_owner" };
  }
  if (await store.isGlobalAdmin(caller.userId)) {
    return { authorized: true, reason: "global_admin" };
  }
  const membership = await store.getActiveAdminMembership(
    org.workos_org_id,
    caller.userId,
  );
  if (!membership) {
    return { authorized: false, reason: "membership_not_found" };
  }
  const decision = evaluateOrgProvisioningAccess({
    orgScimEnabled: org.scim_enabled,
    membershipStatus: membership.provisioning_status as WorkosProvisioningStatus,
    membershipRole: membership.role as WorkosOrgRole,
    requiredRole: "admin",
  });
  return { authorized: decision.allowed, reason: decision.reason };
}

function validateReturnUrl(raw: unknown): string | undefined {
  if (typeof raw !== "string" || !raw.trim()) {
    return undefined;
  }
  const parsed = new URL(raw.trim());
  if (parsed.protocol !== "https:") {
    throw new Error("return_url must use https");
  }
  return parsed.toString();
}

export async function handleWorkosPortalLink(options: {
  store: WorkosAdminStore;
  caller: WorkosAdminCaller;
  body: Record<string, unknown>;
  workosCred?: string;
  fetchImpl?: typeof fetch;
  now?: Date;
}): Promise<WorkosAdminResponse> {
  const { store, caller, body } = options;
  const workosOrgId = String(body.workos_org_id ?? "").trim();
  const intent = String(body.intent ?? "dsync").trim() as WorkosPortalIntent;
  const dryRun = body.dry_run === true;

  if (!workosOrgId) {
    return { status: 400, body: { error: "workos_org_id is required" } };
  }
  if (!VALID_PORTAL_INTENTS.has(intent)) {
    return { status: 400, body: { error: `Invalid WorkOS portal intent: ${intent}` } };
  }

  let returnUrl: string | undefined;
  try {
    returnUrl = validateReturnUrl(body.return_url);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return { status: 400, body: { error: msg } };
  }

  const org = await store.getOrganization(workosOrgId);
  if (!org) {
    return { status: 404, body: { error: "WorkOS organization not found" } };
  }

  const authz = await authorizeTenantAdmin(store, caller, org);
  if (!authz.authorized) {
    return {
      status: 403,
      body: { error: `Forbidden: tenant admin required (${authz.reason})` },
    };
  }

  const nowIso = (options.now ?? new Date()).toISOString();
  const credValue = (options.workosCred ?? Deno.env.get("WORKOS_API_KEY") ?? "").trim();
  if (!credValue || dryRun) {
    await store.touchPortalGenerated(workosOrgId, intent, nowIso);
    return {
      status: 200,
      body: {
        ok: true,
        mode: "offline_fallback",
        configured: Boolean(credValue),
        fallback: true,
        workos_org_id: workosOrgId,
        intent,
        link: null,
        expires_in_seconds: 300,
        message: credValue
          ? "dry_run=true のため実際のポータルリンク発行をスキップしました。"
          : "WORKOS_API_KEY が未設定のためオフラインプレビューとして構成状態を返却しました。",
      },
    };
  }

  const fetcher = options.fetchImpl ?? fetch;
  try {
    const resp = await fetcher("https://api.workos.com/portal/generate_link", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${credValue}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        organization: workosOrgId,
        intent,
        ...(returnUrl ? { return_url: returnUrl } : {}),
      }),
    });
    const rawJson = (await resp.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    if (!resp.ok || typeof rawJson.link !== "string" || !rawJson.link.trim()) {
      return {
        status: 502,
        body: {
          error: maskWorkosText(
            `WorkOS Admin Portal returned HTTP ${resp.status}: ${String(rawJson.message ?? "no link")}`,
          ),
        },
      };
    }
    await store.touchPortalGenerated(workosOrgId, intent, nowIso);
    return {
      status: 200,
      body: {
        ok: true,
        mode: "live",
        configured: true,
        fallback: false,
        workos_org_id: workosOrgId,
        intent,
        link: rawJson.link,
        expires_in_seconds: 300,
      },
    };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return {
      status: 502,
      body: { error: maskWorkosText(`WorkOS portal request failed: ${msg}`) },
    };
  }
}

export async function handleWorkosUpdateMemberRole(options: {
  store: WorkosAdminStore;
  caller: WorkosAdminCaller;
  body: Record<string, unknown>;
}): Promise<WorkosAdminResponse> {
  const { store, caller, body } = options;
  const workosOrgId = String(body.workos_org_id ?? "").trim();
  const directoryUserId = String(body.workos_directory_user_id ?? "").trim();
  const role = String(body.role ?? "").trim().toLowerCase() as WorkosOrgRole;

  if (!workosOrgId || !directoryUserId) {
    return {
      status: 400,
      body: { error: "workos_org_id and workos_directory_user_id are required" },
    };
  }
  if (!VALID_ORG_ROLES.has(role)) {
    return { status: 400, body: { error: `Invalid org role: ${role}` } };
  }

  const org = await store.getOrganization(workosOrgId);
  if (!org) {
    return { status: 404, body: { error: "WorkOS organization not found" } };
  }

  const authz = await authorizeTenantAdmin(store, caller, org);
  if (!authz.authorized) {
    return {
      status: 403,
      body: { error: `Forbidden: tenant admin required (${authz.reason})` },
    };
  }

  const updated = await store.updateMembershipRole(
    workosOrgId,
    directoryUserId,
    role,
  );
  if (!updated) {
    return { status: 404, body: { error: "Directory member not found" } };
  }
  return {
    status: 200,
    body: {
      ok: true,
      member: updated,
    },
  };
}
