import {
  assertEquals,
  assertNotMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  computeWorkosHmacHex,
  evaluateOrgProvisioningAccess,
  maskWorkosText,
  normalizeDirectorySyncEvent,
  sanitizeWorkosMetadata,
  verifyWorkosSignature,
} from "./workos_scim.ts";

const SAMPLE_CRED_VALUE = ["whsec", "testsigningsecret12345"].join("_");
const SAMPLE_LEAK_CRED = ["sk_live", "leaktestvalue1234567890"].join("_");

Deno.test("verifyWorkosSignature accepts valid timestamped HMAC-SHA256 and rejects replay/mismatch", async () => {
  const rawBody = JSON.stringify({ id: "evt_1", event: "dsync.user.created" });
  const nowMs = 1_764_000_000_000;
  const sigHex = await computeWorkosHmacHex(
    String(nowMs),
    rawBody,
    SAMPLE_CRED_VALUE,
  );
  const validHeader = `t=${nowMs}, v1=${sigHex}`;

  const okRes = await verifyWorkosSignature({
    rawBody,
    signatureHeader: validHeader,
    hmacMaterial: SAMPLE_CRED_VALUE,
    nowMs: nowMs + 5_000,
  });
  assertEquals(okRes.ok, true);

  const replayedRes = await verifyWorkosSignature({
    rawBody,
    signatureHeader: validHeader,
    hmacMaterial: SAMPLE_CRED_VALUE,
    nowMs: nowMs + 300_000,
  });
  assertEquals(replayedRes.ok, false);
  assertEquals(replayedRes.reason, "signature_timestamp_outside_tolerance");

  const tamperedRes = await verifyWorkosSignature({
    rawBody: `${rawBody} `,
    signatureHeader: validHeader,
    hmacMaterial: SAMPLE_CRED_VALUE,
    nowMs: nowMs + 1_000,
  });
  assertEquals(tamperedRes.ok, false);
  assertEquals(tamperedRes.reason, "signature_mismatch");
});

Deno.test("normalizeDirectorySyncEvent maps created, suspended, and deleted lifecycles cleanly", () => {
  const created = normalizeDirectorySyncEvent({
    id: "evt_created_1",
    event: "dsync.user.created",
    data: {
      id: "dir_usr_1",
      organization_id: "org_acme_1",
      directory_id: "dir_1",
      email: "alice@acme.example",
      first_name: "Alice",
      last_name: "Admin",
      state: "active",
      role: { slug: "admin" },
    },
  });
  assertEquals(created.targetStatus, "active");
  assertEquals(created.role, "admin");
  assertEquals(created.displayName, "Alice Admin");

  const suspended = normalizeDirectorySyncEvent({
    id: "evt_updated_1",
    event: "dsync.user.updated",
    data: {
      id: "dir_usr_1",
      organization_id: "org_acme_1",
      email: "alice@acme.example",
      state: "suspended",
    },
  });
  assertEquals(suspended.targetStatus, "suspended");

  const deleted = normalizeDirectorySyncEvent({
    id: "evt_deleted_1",
    event: "dsync.user.deleted",
    data: {
      id: "dir_usr_1",
      organization_id: "org_acme_1",
      email: "alice@acme.example",
    },
  });
  assertEquals(deleted.targetStatus, "deprovisioned");
});

Deno.test("evaluateOrgProvisioningAccess enforces active SCIM membership and RBAC hierarchy", () => {
  assertEquals(
    evaluateOrgProvisioningAccess({
      orgScimEnabled: true,
      membershipStatus: "active",
      membershipRole: "admin",
      requiredRole: "member",
    }).allowed,
    true,
  );
  assertEquals(
    evaluateOrgProvisioningAccess({
      orgScimEnabled: true,
      membershipStatus: "suspended",
      membershipRole: "owner",
      requiredRole: "viewer",
    }),
    { allowed: false, reason: "membership_suspended" },
  );
  assertEquals(
    evaluateOrgProvisioningAccess({
      orgScimEnabled: true,
      membershipStatus: "active",
      membershipRole: "member",
      requiredRole: "admin",
    }),
    { allowed: false, reason: "insufficient_role:member<admin" },
  );
});

Deno.test("maskWorkosText and sanitizeWorkosMetadata redact credential prefixes", () => {
  const masked = maskWorkosText(`failed authorization=Bearer ${SAMPLE_LEAK_CRED}`);
  assertNotMatch(masked, /leaktestvalue1234567890/);
  const sanitized = sanitizeWorkosMetadata({
    nested: { authorization: SAMPLE_LEAK_CRED, event: "dsync.user.updated" },
  });
  assertNotMatch(JSON.stringify(sanitized), /leaktestvalue1234567890/);
});
