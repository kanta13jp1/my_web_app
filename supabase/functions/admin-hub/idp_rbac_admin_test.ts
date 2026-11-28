import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { IdpGroupMappingRule } from "../_shared/idp_rbac.ts";
import {
  handleOrgIdpMappingsDelete,
  handleOrgIdpMappingsList,
  handleOrgIdpMappingsUpsert,
  handleOrgSsoEvaluate,
  type OrgIdpRbacStore,
} from "./idp_rbac_admin.ts";
import type { WorkosMemberRecord, WorkosOrgRecord } from "./workos_admin.ts";

function makeMemoryStore(options?: {
  members?: WorkosMemberRecord[];
  mappings?: IdpGroupMappingRule[];
}): OrgIdpRbacStore {
  const orgs: WorkosOrgRecord[] = [
    {
      id: "uuid-org-acme",
      workos_org_id: "org_acme",
      organization_name: "Acme Corp",
      owner_user_id: "owner-1",
      scim_enabled: true,
      default_role: "member",
      admin_portal_last_intent: "sso",
      last_portal_generated_at: null,
    },
  ];
  const members = [...(options?.members ?? [])];
  const mappings = [...(options?.mappings ?? [])];
  let auditCount = 0;

  return {
    isGlobalAdmin: () => Promise.resolve(false),
    getOrganization: (orgId) =>
      Promise.resolve(orgs.find((o) => o.workos_org_id === orgId) ?? null),
    getActiveMembership: (orgId, userId) =>
      Promise.resolve(
        members.find(
          (m) =>
            m.workos_org_id === orgId &&
            m.supabase_user_id === userId &&
            m.provisioning_status === "active",
        ) ?? null,
      ),
    listMappings: (orgId) =>
      Promise.resolve(mappings.filter((m) => m.workos_org_id === orgId)),
    upsertMapping: (input) => {
      const item: IdpGroupMappingRule = {
        id: `map-${mappings.length + 1}`,
        workos_org_id: input.workosOrgId,
        idp_provider: input.idpProvider,
        idp_group_id: input.idpGroupId,
        idp_group_label: input.idpGroupLabel,
        mapped_role: input.mappedRole,
        priority: input.priority,
        is_active: input.isActive,
      };
      mappings.push(item);
      return Promise.resolve(item);
    },
    deleteMapping: (orgId, mappingId) => {
      const idx = mappings.findIndex(
        (m) => m.workos_org_id === orgId && m.id === mappingId,
      );
      if (idx === -1) return Promise.resolve(false);
      mappings.splice(idx, 1);
      return Promise.resolve(true);
    },
    listRecentSsoAudits: () => Promise.resolve([]),
    recordSsoAudit: () => {
      auditCount += 1;
      void auditCount;
      return Promise.resolve();
    },
  };
}

Deno.test("cross-tenant caller is denied access to org IdP RBAC actions", async () => {
  const store = makeMemoryStore();
  const listRes = await handleOrgIdpMappingsList({
    store,
    caller: { userId: "outsider-99", isServiceRole: false },
    body: { workos_org_id: "org_acme" },
  });
  assertEquals(listRes.status, 403);

  const evalRes = await handleOrgSsoEvaluate({
    store,
    caller: { userId: "outsider-99", isServiceRole: false },
    body: {
      workos_org_id: "org_acme",
      idp_provider: "okta",
      claims: { groups: ["acme-admins"] },
    },
  });
  assertEquals(evalRes.status, 403);
});

Deno.test("member and admin role boundaries enforce write and owner restrictions", async () => {
  const store = makeMemoryStore({
    members: [
      {
        id: "mem-1",
        organization_id: "uuid-org-acme",
        workos_org_id: "org_acme",
        workos_directory_user_id: "dir-member",
        supabase_user_id: "user-member",
        email: "member@acme.example",
        display_name: "Member",
        role: "member",
        provisioning_status: "active",
        last_event_type: "dsync.user.created",
        last_synced_at: "2026-11-25T00:00:00Z",
      },
      {
        id: "mem-2",
        organization_id: "uuid-org-acme",
        workos_org_id: "org_acme",
        workos_directory_user_id: "dir-admin",
        supabase_user_id: "user-admin",
        email: "admin@acme.example",
        display_name: "Admin",
        role: "admin",
        provisioning_status: "active",
        last_event_type: "dsync.user.created",
        last_synced_at: "2026-11-25T00:00:00Z",
      },
    ],
  });

  // Member can list + receives member UI capabilities, but cannot upsert.
  const memberList = await handleOrgIdpMappingsList({
    store,
    caller: { userId: "user-member", isServiceRole: false },
    body: { workos_org_id: "org_acme" },
  });
  assertEquals(memberList.status, 200);
  const memberCaps = memberList.body.ui_capabilities as Record<string, unknown>;
  assertEquals(memberCaps.can_execute_member_actions, true);
  assertEquals(memberCaps.can_manage_idp_mappings, false);

  const memberUpsert = await handleOrgIdpMappingsUpsert({
    store,
    caller: { userId: "user-member", isServiceRole: false },
    body: {
      workos_org_id: "org_acme",
      idp_provider: "okta",
      idp_group_id: "acme-admins",
      mapped_role: "admin",
    },
  });
  assertEquals(memberUpsert.status, 403);

  // Admin cannot escalate a group to owner, but can assign admin and delete.
  const adminOwnerEscalate = await handleOrgIdpMappingsUpsert({
    store,
    caller: { userId: "user-admin", isServiceRole: false },
    body: {
      workos_org_id: "org_acme",
      idp_provider: "okta",
      idp_group_id: "acme-owners",
      mapped_role: "owner",
    },
  });
  assertEquals(adminOwnerEscalate.status, 403);

  const adminUpsert = await handleOrgIdpMappingsUpsert({
    store,
    caller: { userId: "user-admin", isServiceRole: false },
    body: {
      workos_org_id: "org_acme",
      idp_provider: "okta",
      idp_group_id: "acme-admins",
      mapped_role: "admin",
    },
  });
  assertEquals(adminUpsert.status, 200);
  const saved = adminUpsert.body.mapping as IdpGroupMappingRule;

  const delRes = await handleOrgIdpMappingsDelete({
    store,
    caller: { userId: "user-admin", isServiceRole: false },
    body: { workos_org_id: "org_acme", mapping_id: saved.id },
  });
  assertEquals(delRes.status, 200);
});

Deno.test("SSO evaluation resolves Entra ID group mapping and fails closed on overage", async () => {
  const store = makeMemoryStore({
    members: [
      {
        id: "mem-viewer",
        organization_id: "uuid-org-acme",
        workos_org_id: "org_acme",
        workos_directory_user_id: "dir-viewer",
        supabase_user_id: "user-viewer",
        email: "viewer@acme.example",
        display_name: "Viewer",
        role: "viewer",
        provisioning_status: "active",
        last_event_type: "dsync.user.created",
        last_synced_at: "2026-11-25T00:00:00Z",
      },
    ],
    mappings: [
      {
        id: "m-aad",
        workos_org_id: "org_acme",
        idp_provider: "azure_ad",
        idp_group_id: "22222222-2222-4222-8222-222222222222",
        idp_group_label: "Entra Admins",
        mapped_role: "admin",
        priority: 10,
        is_active: true,
      },
    ],
  });

  const okEval = await handleOrgSsoEvaluate({
    store,
    caller: { userId: "user-viewer", isServiceRole: false },
    body: {
      workos_org_id: "org_acme",
      idp_provider: "azure_ad",
      required_role: "admin",
      claims: {
        sub: "entra-sub-1",
        groups: ["22222222-2222-4222-8222-222222222222"],
      },
    },
  });
  assertEquals(okEval.status, 200);
  assertEquals(okEval.body.resolved_role, "admin");
  assertEquals(
    (okEval.body.ui_capabilities as Record<string, unknown>)
      .can_manage_idp_mappings,
    true,
  );

  const oversizedOrg = await handleOrgIdpMappingsList({
    store,
    caller: { userId: "usr-admin", isServiceRole: false },
    body: { workos_org_id: "o".repeat(121) },
  });
  assertEquals(oversizedOrg.status, 400);

  const oversizedGroup = await handleOrgIdpMappingsUpsert({
    store,
    caller: { userId: "usr-admin", isServiceRole: false },
    body: {
      workos_org_id: "org_acme",
      idp_provider: "okta",
      idp_group_id: "g".repeat(201),
      mapped_role: "member",
    },
  });
  assertEquals(oversizedGroup.status, 400);
});
