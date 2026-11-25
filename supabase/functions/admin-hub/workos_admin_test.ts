import {
  assertEquals,
  assertNotMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  handleWorkosPortalLink,
  handleWorkosUpdateMemberRole,
  type WorkosAdminStore,
  type WorkosMemberRecord,
  type WorkosOrgRecord,
} from "./workos_admin.ts";

const ORG_ROW: WorkosOrgRecord = {
  id: "org-uuid-1",
  workos_org_id: "org_acme_1",
  organization_name: "Acme Corp",
  owner_user_id: "owner-user-1",
  scim_enabled: true,
  default_role: "member",
  admin_portal_last_intent: "dsync",
  last_portal_generated_at: null,
};

const MEMBER_ROW: WorkosMemberRecord = {
  id: "mem-uuid-1",
  organization_id: "org-uuid-1",
  workos_org_id: "org_acme_1",
  workos_directory_user_id: "dir_user_1",
  supabase_user_id: "user-admin-2",
  email: "admin2@acme.example",
  display_name: "Admin Two",
  role: "admin",
  provisioning_status: "active",
  last_event_type: "dsync.user.created",
  last_synced_at: "2026-11-25T00:00:00.000Z",
};

function createStubStore(
  overrides: Partial<WorkosAdminStore> = {},
): WorkosAdminStore {
  return {
    isGlobalAdmin: () => Promise.resolve(false),
    getOrganization: (orgId) =>
      Promise.resolve(orgId === "org_acme_1" ? ORG_ROW : null),
    getActiveAdminMembership: (orgId, userId) =>
      Promise.resolve(
        orgId === "org_acme_1" && userId === "user-admin-2" ? MEMBER_ROW : null,
      ),
    touchPortalGenerated: () => Promise.resolve(),
    updateMembershipRole: (_orgId, dirUserId, role) =>
      Promise.resolve(
        dirUserId === "dir_user_1" ? { ...MEMBER_ROW, role } : null,
      ),
    ...overrides,
  };
}

Deno.test("handleWorkosPortalLink returns graceful offline fallback when WORKOS_API_KEY is absent", async () => {
  let touched = false;
  const store = createStubStore({
    touchPortalGenerated: () => {
      touched = true;
      return Promise.resolve();
    },
  });
  const res = await handleWorkosPortalLink({
    store,
    caller: { userId: "owner-user-1", isServiceRole: false },
    body: { workos_org_id: "org_acme_1", intent: "dsync" },
    workosCred: "",
  });
  assertEquals(res.status, 200);
  assertEquals(res.body.mode, "offline_fallback");
  assertEquals(res.body.fallback, true);
  assertEquals(res.body.link, null);
  assertEquals(touched, true);
});

Deno.test("handleWorkosPortalLink generates live portal URL for authorized tenant admin and blocks unauthorized caller", async () => {
  const store = createStubStore();
  const sampleCred = ["sk_test", "workosportal123456"].join("_");

  const forbidden = await handleWorkosPortalLink({
    store,
    caller: { userId: "intruder-user", isServiceRole: false },
    body: { workos_org_id: "org_acme_1", intent: "sso" },
    workosCred: sampleCred,
  });
  assertEquals(forbidden.status, 403);

  const ok = await handleWorkosPortalLink({
    store,
    caller: { userId: "user-admin-2", isServiceRole: false },
    body: {
      workos_org_id: "org_acme_1",
      intent: "sso",
      return_url: "https://example.app/settings",
    },
    workosCred: sampleCred,
    fetchImpl: () =>
      Promise.resolve(
        new Response(
          JSON.stringify({ link: "https://id.workos.com/portal/session_123" }),
          { status: 201 },
        ),
      ),
  });
  assertEquals(ok.status, 200);
  assertEquals(ok.body.mode, "live");
  assertEquals(ok.body.link, "https://id.workos.com/portal/session_123");
  assertNotMatch(JSON.stringify(ok), /workosportal123456/);
});

Deno.test("handleWorkosUpdateMemberRole enforces RBAC and rejects suspended/non-admin callers", async () => {
  const suspendedStore = createStubStore({
    getActiveAdminMembership: () => Promise.resolve(null),
  });
  const denied = await handleWorkosUpdateMemberRole({
    store: suspendedStore,
    caller: { userId: "user-member-3", isServiceRole: false },
    body: {
      workos_org_id: "org_acme_1",
      workos_directory_user_id: "dir_user_1",
      role: "owner",
    },
  });
  assertEquals(denied.status, 403);

  const ok = await handleWorkosUpdateMemberRole({
    store: createStubStore(),
    caller: { userId: "owner-user-1", isServiceRole: false },
    body: {
      workos_org_id: "org_acme_1",
      workos_directory_user_id: "dir_user_1",
      role: "viewer",
    },
  });
  assertEquals(ok.status, 200);
  assertEquals(
    (ok.body.member as WorkosMemberRecord).role,
    "viewer",
  );
});
