import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

import {
  evaluateIdpGroupRbac,
  type IdpGroupMappingRule,
  type IdpProviderKind,
  normalizeIdpGroupAssertion,
  VALID_IDP_PROVIDERS,
} from "../_shared/idp_rbac.ts";
import {
  maskWorkosText,
  VALID_ORG_ROLES,
  type WorkosOrgRole,
  type WorkosProvisioningStatus,
} from "../_shared/workos_scim.ts";
import type {
  WorkosAdminCaller,
  WorkosMemberRecord,
  WorkosOrgRecord,
} from "./workos_admin.ts";

export interface OrgSsoAuditRecord {
  id: string;
  workos_org_id: string;
  user_id: string | null;
  idp_provider: string;
  idp_subject: string;
  asserted_groups: string[];
  group_overage_detected: boolean;
  resolved_role: string;
  resolution_source: string;
  evaluated_at: string;
}

export interface OrgIdpRbacStore {
  isGlobalAdmin(userId: string): Promise<boolean>;
  getOrganization(workosOrgId: string): Promise<WorkosOrgRecord | null>;
  getActiveMembership(
    workosOrgId: string,
    userId: string,
  ): Promise<WorkosMemberRecord | null>;
  listMappings(workosOrgId: string): Promise<IdpGroupMappingRule[]>;
  upsertMapping(input: {
    organizationId: string;
    workosOrgId: string;
    idpProvider: IdpProviderKind;
    idpGroupId: string;
    idpGroupLabel: string;
    mappedRole: WorkosOrgRole;
    priority: number;
    isActive: boolean;
    actorUserId: string | null;
  }): Promise<IdpGroupMappingRule | null>;
  deleteMapping(workosOrgId: string, mappingId: string): Promise<boolean>;
  listRecentSsoAudits(
    workosOrgId: string,
    limit: number,
  ): Promise<OrgSsoAuditRecord[]>;
  recordSsoAudit(input: {
    organizationId: string;
    workosOrgId: string;
    userId: string | null;
    idpProvider: IdpProviderKind;
    idpSubject: string;
    assertedGroups: string[];
    groupOverageDetected: boolean;
    resolvedRole: WorkosOrgRole | "none";
    resolutionSource: string;
  }): Promise<void>;
}

export interface OrgIdpAdminResponse {
  status: number;
  body: Record<string, unknown>;
}

export function buildUiCapabilities(role: WorkosOrgRole | "none"): {
  role: WorkosOrgRole | "none";
  can_view_org: boolean;
  can_execute_member_actions: boolean;
  can_manage_idp_mappings: boolean;
  can_assign_owner_role: boolean;
} {
  return {
    role,
    can_view_org: role !== "none",
    can_execute_member_actions: role === "owner" || role === "admin" ||
      role === "member",
    can_manage_idp_mappings: role === "owner" || role === "admin",
    can_assign_owner_role: role === "owner",
  };
}

export function createSupabaseOrgIdpRbacStore(
  admin: SupabaseClient,
): OrgIdpRbacStore {
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
    async getActiveMembership(workosOrgId, userId) {
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
    async listMappings(workosOrgId) {
      const { data, error } = await admin
        .from("org_idp_group_mappings")
        .select(
          "id,workos_org_id,idp_provider,idp_group_id,idp_group_label,mapped_role,priority,is_active",
        )
        .eq("workos_org_id", workosOrgId)
        .order("priority", { ascending: true })
        .limit(100);
      if (error || !data) return [];
      return data as IdpGroupMappingRule[];
    },
    async upsertMapping(input) {
      const { data, error } = await admin
        .from("org_idp_group_mappings")
        .upsert(
          {
            organization_id: input.organizationId,
            workos_org_id: input.workosOrgId,
            idp_provider: input.idpProvider,
            idp_group_id: input.idpGroupId,
            idp_group_label: input.idpGroupLabel,
            mapped_role: input.mappedRole,
            priority: input.priority,
            is_active: input.isActive,
            created_by: input.actorUserId,
          },
          { onConflict: "workos_org_id,idp_provider,idp_group_id" },
        )
        .select(
          "id,workos_org_id,idp_provider,idp_group_id,idp_group_label,mapped_role,priority,is_active",
        )
        .maybeSingle();
      if (error || !data) return null;
      return data as IdpGroupMappingRule;
    },
    async deleteMapping(workosOrgId, mappingId) {
      const { data, error } = await admin
        .from("org_idp_group_mappings")
        .delete()
        .eq("workos_org_id", workosOrgId)
        .eq("id", mappingId)
        .select("id")
        .maybeSingle();
      return !error && Boolean(data);
    },
    async listRecentSsoAudits(workosOrgId, limit) {
      const capped = Math.max(1, Math.min(50, Math.floor(limit)));
      const { data, error } = await admin
        .from("org_sso_sessions_audit")
        .select(
          "id,workos_org_id,user_id,idp_provider,idp_subject,asserted_groups,group_overage_detected,resolved_role,resolution_source,evaluated_at",
        )
        .eq("workos_org_id", workosOrgId)
        .order("evaluated_at", { ascending: false })
        .limit(capped);
      if (error || !data) return [];
      return data as OrgSsoAuditRecord[];
    },
    async recordSsoAudit(input) {
      await admin.from("org_sso_sessions_audit").insert({
        organization_id: input.organizationId,
        workos_org_id: input.workosOrgId,
        user_id: input.userId,
        idp_provider: input.idpProvider,
        idp_subject: input.idpSubject,
        asserted_groups: input.assertedGroups,
        group_overage_detected: input.groupOverageDetected,
        resolved_role: input.resolvedRole,
        resolution_source: input.resolutionSource,
      });
    },
  };
}

async function resolveCallerOrgRole(
  store: OrgIdpRbacStore,
  caller: WorkosAdminCaller,
  org: WorkosOrgRecord,
): Promise<{
  role: WorkosOrgRole | "none";
  isGlobalAdmin: boolean;
  isOrgOwner: boolean;
}> {
  if (caller.isServiceRole) {
    return { role: "owner", isGlobalAdmin: true, isOrgOwner: true };
  }
  if (!caller.userId) {
    return { role: "none", isGlobalAdmin: false, isOrgOwner: false };
  }
  if (org.owner_user_id === caller.userId) {
    return { role: "owner", isGlobalAdmin: false, isOrgOwner: true };
  }
  if (await store.isGlobalAdmin(caller.userId)) {
    return { role: "owner", isGlobalAdmin: true, isOrgOwner: false };
  }
  const membership = await store.getActiveMembership(
    org.workos_org_id,
    caller.userId,
  );
  if (
    !membership ||
    (membership.provisioning_status as WorkosProvisioningStatus) !== "active"
  ) {
    return { role: "none", isGlobalAdmin: false, isOrgOwner: false };
  }
  const normalized = membership.role.trim().toLowerCase() as WorkosOrgRole;
  return {
    role: VALID_ORG_ROLES.has(normalized) ? normalized : "viewer",
    isGlobalAdmin: false,
    isOrgOwner: false,
  };
}

export async function handleOrgIdpMappingsList(options: {
  store: OrgIdpRbacStore;
  caller: WorkosAdminCaller;
  body: Record<string, unknown>;
}): Promise<OrgIdpAdminResponse> {
  const workosOrgId = String(options.body.workos_org_id ?? "").trim();
  if (!workosOrgId || workosOrgId.length > 120) {
    return {
      status: 400,
      body: {
        error: workosOrgId
          ? "workos_org_id exceeds maximum length (120)"
          : "workos_org_id is required",
      },
    };
  }
  const org = await options.store.getOrganization(workosOrgId);
  if (!org) {
    return { status: 404, body: { error: "WorkOS organization not found" } };
  }
  const callerAccess = await resolveCallerOrgRole(
    options.store,
    options.caller,
    org,
  );
  if (callerAccess.role === "none") {
    return {
      status: 403,
      body: { error: "Forbidden: organization membership required" },
    };
  }
  const mappings = await options.store.listMappings(workosOrgId);
  const audits = await options.store.listRecentSsoAudits(workosOrgId, 20);
  return {
    status: 200,
    body: {
      ok: true,
      workos_org_id: workosOrgId,
      caller_role: callerAccess.role,
      ui_capabilities: buildUiCapabilities(callerAccess.role),
      mappings,
      audits,
    },
  };
}

export async function handleOrgIdpMappingsUpsert(options: {
  store: OrgIdpRbacStore;
  caller: WorkosAdminCaller;
  body: Record<string, unknown>;
}): Promise<OrgIdpAdminResponse> {
  const workosOrgId = String(options.body.workos_org_id ?? "").trim();
  const idpProvider = String(options.body.idp_provider ?? "")
    .trim()
    .toLowerCase() as IdpProviderKind;
  const idpGroupId = String(options.body.idp_group_id ?? "").trim();
  const idpGroupLabel = String(options.body.idp_group_label ?? "")
    .trim()
    .slice(0, 160);
  const mappedRole = String(options.body.mapped_role ?? "member")
    .trim()
    .toLowerCase() as WorkosOrgRole;
  const rawPriority = Number(options.body.priority ?? 100);
  const priority = Number.isFinite(rawPriority)
    ? Math.max(1, Math.min(1000, Math.floor(rawPriority)))
    : 100;
  const isActive = options.body.is_active !== false;

  if (!workosOrgId || !idpGroupId) {
    return {
      status: 400,
      body: { error: "workos_org_id and idp_group_id are required" },
    };
  }
  if (workosOrgId.length > 120) {
    return {
      status: 400,
      body: { error: "workos_org_id exceeds maximum length (120)" },
    };
  }
  if (idpGroupId.length > 200) {
    return {
      status: 400,
      body: { error: "idp_group_id exceeds maximum length (200)" },
    };
  }
  if (!VALID_IDP_PROVIDERS.has(idpProvider)) {
    return {
      status: 400,
      body: { error: `Invalid idp_provider: ${idpProvider}` },
    };
  }
  if (!VALID_ORG_ROLES.has(mappedRole)) {
    return {
      status: 400,
      body: { error: `Invalid mapped_role: ${mappedRole}` },
    };
  }

  const org = await options.store.getOrganization(workosOrgId);
  if (!org) {
    return { status: 404, body: { error: "WorkOS organization not found" } };
  }

  const callerAccess = await resolveCallerOrgRole(
    options.store,
    options.caller,
    org,
  );
  if (callerAccess.role !== "owner" && callerAccess.role !== "admin") {
    return {
      status: 403,
      body: { error: "Forbidden: tenant admin role required" },
    };
  }
  if (mappedRole === "owner" && callerAccess.role !== "owner") {
    return {
      status: 403,
      body: { error: "Forbidden: only org owner may assign owner role" },
    };
  }

  const saved = await options.store.upsertMapping({
    organizationId: org.id,
    workosOrgId,
    idpProvider,
    idpGroupId,
    idpGroupLabel,
    mappedRole,
    priority,
    isActive,
    actorUserId: options.caller.userId,
  });
  if (!saved) {
    return {
      status: 500,
      body: { error: "Failed to persist IdP group mapping" },
    };
  }
  return { status: 200, body: { ok: true, mapping: saved } };
}

export async function handleOrgIdpMappingsDelete(options: {
  store: OrgIdpRbacStore;
  caller: WorkosAdminCaller;
  body: Record<string, unknown>;
}): Promise<OrgIdpAdminResponse> {
  const workosOrgId = String(options.body.workos_org_id ?? "").trim();
  const mappingId = String(options.body.mapping_id ?? "").trim();
  if (!workosOrgId || !mappingId) {
    return {
      status: 400,
      body: { error: "workos_org_id and mapping_id are required" },
    };
  }
  if (workosOrgId.length > 120) {
    return {
      status: 400,
      body: { error: "workos_org_id exceeds maximum length (120)" },
    };
  }
  const org = await options.store.getOrganization(workosOrgId);
  if (!org) {
    return { status: 404, body: { error: "WorkOS organization not found" } };
  }
  const callerAccess = await resolveCallerOrgRole(
    options.store,
    options.caller,
    org,
  );
  if (callerAccess.role !== "owner" && callerAccess.role !== "admin") {
    return {
      status: 403,
      body: { error: "Forbidden: tenant admin role required" },
    };
  }
  const deleted = await options.store.deleteMapping(workosOrgId, mappingId);
  if (!deleted) {
    return { status: 404, body: { error: "IdP mapping not found" } };
  }
  return { status: 200, body: { ok: true, deleted_id: mappingId } };
}

export async function handleOrgSsoEvaluate(options: {
  store: OrgIdpRbacStore;
  caller: WorkosAdminCaller;
  body: Record<string, unknown>;
}): Promise<OrgIdpAdminResponse> {
  if (!options.caller.userId && !options.caller.isServiceRole) {
    return { status: 401, body: { error: "Unauthorized" } };
  }
  const workosOrgId = String(options.body.workos_org_id ?? "").trim();
  const idpProvider = String(options.body.idp_provider ?? "okta").trim();
  const requiredRoleRaw = String(options.body.required_role ?? "viewer")
    .trim()
    .toLowerCase() as WorkosOrgRole;
  const requiredRole = VALID_ORG_ROLES.has(requiredRoleRaw)
    ? requiredRoleRaw
    : "viewer";

  if (!workosOrgId || workosOrgId.length > 120) {
    return {
      status: 400,
      body: {
        error: workosOrgId
          ? "workos_org_id exceeds maximum length (120)"
          : "workos_org_id is required",
      },
    };
  }
  const org = await options.store.getOrganization(workosOrgId);
  if (!org) {
    return { status: 404, body: { error: "WorkOS organization not found" } };
  }
  const callerAccess = await resolveCallerOrgRole(
    options.store,
    options.caller,
    org,
  );
  if (callerAccess.role === "none") {
    return {
      status: 403,
      body: { error: "Forbidden: organization membership required" },
    };
  }

  const rawClaims = options.body.claims !== null &&
      typeof options.body.claims === "object" &&
      !Array.isArray(options.body.claims)
    ? (options.body.claims as Record<string, unknown>)
    : {};
  const claimSource = options.body.claim_source === "user_metadata"
    ? "user_metadata"
    : "id_token";

  const assertion = normalizeIdpGroupAssertion({
    provider: idpProvider,
    claims: rawClaims,
    claimSource,
  });
  const mappings = await options.store.listMappings(workosOrgId);
  const membership = options.caller.userId
    ? await options.store.getActiveMembership(
      workosOrgId,
      options.caller.userId,
    )
    : null;
  const scimRole =
    membership && VALID_ORG_ROLES.has(membership.role as WorkosOrgRole)
      ? (membership.role as WorkosOrgRole)
      : null;

  const evaluation = evaluateIdpGroupRbac({
    workosOrgId,
    assertion,
    mappings,
    isOrgOwner: callerAccess.isOrgOwner,
    existingScimRole: scimRole,
    requiredRole,
  });

  await options.store.recordSsoAudit({
    organizationId: org.id,
    workosOrgId,
    userId: options.caller.userId,
    idpProvider: assertion.provider,
    idpSubject: maskWorkosText(assertion.subject),
    assertedGroups: assertion.groups.slice(0, 50),
    groupOverageDetected: evaluation.overageDetected,
    resolvedRole: evaluation.resolvedRole,
    resolutionSource: evaluation.resolutionSource,
  });

  return {
    status: evaluation.allowed ? 200 : 403,
    body: {
      ok: evaluation.allowed,
      allowed: evaluation.allowed,
      workos_org_id: workosOrgId,
      idp_provider: assertion.provider,
      resolved_role: evaluation.resolvedRole,
      resolution_source: evaluation.resolutionSource,
      overage_detected: evaluation.overageDetected,
      matched_groups: evaluation.matchedGroups,
      warnings: evaluation.warnings,
      ui_capabilities: buildUiCapabilities(evaluation.resolvedRole),
      app_metadata_claims: evaluation.appMetadataClaims,
    },
  };
}
