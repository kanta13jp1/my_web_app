import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  computeWorkosHmacHex,
  type NormalizedScimUserEvent,
} from "../_shared/workos_scim.ts";
import {
  createScimWebhookHandler,
  type ScimWebhookStore,
} from "./index.ts";

const SIGNING_VAL = ["whsec", "testworkoswebhooksecret123"].join("_");
const FIXED_NOW_MS = 1_764_000_000_000;

function createMemoryScimStore(): {
  store: ScimWebhookStore;
  memberships: Map<string, NormalizedScimUserEvent>;
  events: string[];
} {
  const memberships = new Map<string, NormalizedScimUserEvent>();
  const events: string[] = [];

  const store: ScimWebhookStore = {
    hasProcessedEvent: (id) => Promise.resolve(events.includes(id)),
    findOrganizationId: (orgId) =>
      Promise.resolve(orgId === "org_acme_1" ? "org-uuid-1" : null),
    findSupabaseUserId: () => Promise.resolve("sb-user-1"),
    upsertDirectoryMembership: (_orgUuid, event) => {
      memberships.set(event.directoryUserId, event);
      return Promise.resolve();
    },
    insertScimSyncEvent: (_orgUuid, event) => {
      events.push(event.eventId);
      return Promise.resolve();
    },
  };
  return { store, memberships, events };
}

Deno.test("workos-scim-webhook handles CORS preflight with tracing headers and fails closed on bad signature", async () => {
  const { store } = createMemoryScimStore();
  const handler = createScimWebhookHandler({
    hmacMaterial: SIGNING_VAL,
    nowMs: () => FIXED_NOW_MS,
    store,
  });

  const preflight = await handler(
    new Request("https://example.supabase.co/functions/v1/workos-scim-webhook", {
      method: "OPTIONS",
    }),
  );
  assertEquals(preflight.status, 200);
  const allowHeaders = preflight.headers.get("Access-Control-Allow-Headers") ?? "";
  assertMatch(allowHeaders, /traceparent/);
  assertMatch(allowHeaders, /tracestate/);
  assertMatch(allowHeaders, /baggage/);
  assertMatch(allowHeaders, /sentry-trace/);

  const unauth = await handler(
    new Request("https://example.supabase.co/functions/v1/workos-scim-webhook", {
      method: "POST",
      body: JSON.stringify({ id: "evt_1" }),
    }),
  );
  assertEquals(unauth.status, 401);
});

Deno.test("workos-scim-webhook verifies WorkOS-Signature and syncs created -> suspended -> deprovisioned idempotently", async () => {
  const { store, memberships, events } = createMemoryScimStore();
  const handler = createScimWebhookHandler({
    hmacMaterial: SIGNING_VAL,
    nowMs: () => FIXED_NOW_MS,
    store,
  });

  async function sendSigned(payload: Record<string, unknown>) {
    const raw = JSON.stringify(payload);
    const sig = await computeWorkosHmacHex(String(FIXED_NOW_MS), raw, SIGNING_VAL);
    return handler(
      new Request("https://example.supabase.co/functions/v1/workos-scim-webhook", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "WorkOS-Signature": `t=${FIXED_NOW_MS}, v1=${sig}`,
        },
        body: raw,
      }),
    );
  }

  const createdRes = await sendSigned({
    id: "evt_101",
    event: "dsync.user.created",
    data: {
      id: "dir_user_1",
      organization_id: "org_acme_1",
      directory_id: "dir_1",
      email: "bob@acme.example",
      state: "active",
      role: { slug: "member" },
    },
  });
  assertEquals(createdRes.status, 200);
  assertEquals(memberships.get("dir_user_1")?.targetStatus, "active");

  const dupRes = await sendSigned({
    id: "evt_101",
    event: "dsync.user.created",
    data: {
      id: "dir_user_1",
      organization_id: "org_acme_1",
      email: "bob@acme.example",
      state: "active",
    },
  });
  const dupBody = (await dupRes.json()) as { duplicate: boolean };
  assertEquals(dupBody.duplicate, true);
  assertEquals(events.length, 1);

  const suspendedRes = await sendSigned({
    id: "evt_102",
    event: "dsync.user.updated",
    data: {
      id: "dir_user_1",
      organization_id: "org_acme_1",
      email: "bob@acme.example",
      state: "suspended",
    },
  });
  assertEquals(suspendedRes.status, 200);
  assertEquals(memberships.get("dir_user_1")?.targetStatus, "suspended");

  const deletedRes = await sendSigned({
    id: "evt_103",
    event: "dsync.user.deleted",
    data: {
      id: "dir_user_1",
      organization_id: "org_acme_1",
      email: "bob@acme.example",
    },
  });
  assertEquals(deletedRes.status, 200);
  assertEquals(memberships.get("dir_user_1")?.targetStatus, "deprovisioned");
});
