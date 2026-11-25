/**
 * Shared WorkOS Admin Portal, Directory Sync (SCIM), and org RBAC utilities (#2683).
 */

import { MASK_PLACEHOLDER, maskLogString, maskLogValue } from "./sensitive_log_masker.ts";

export type WorkosPortalIntent =
  | "sso"
  | "dsync"
  | "audit_logs"
  | "log_streams"
  | "domain_verification"
  | "certificate_renewal";

export type WorkosProvisioningStatus =
  | "active"
  | "suspended"
  | "deprovisioned";

export type WorkosOrgRole = "owner" | "admin" | "member" | "viewer";

export type WorkosScimEventType =
  | "dsync.user.created"
  | "dsync.user.updated"
  | "dsync.user.deleted";

export const VALID_PORTAL_INTENTS: ReadonlySet<WorkosPortalIntent> = new Set([
  "sso",
  "dsync",
  "audit_logs",
  "log_streams",
  "domain_verification",
  "certificate_renewal",
]);

export const VALID_ORG_ROLES: ReadonlySet<WorkosOrgRole> = new Set([
  "owner",
  "admin",
  "member",
  "viewer",
]);

export const VALID_SCIM_EVENT_TYPES: ReadonlySet<WorkosScimEventType> = new Set([
  "dsync.user.created",
  "dsync.user.updated",
  "dsync.user.deleted",
]);

export const DEFAULT_WORKOS_TOLERANCE_MS = 180_000;

const SENSITIVE_WORKOS_FIELDS: readonly string[] = [
  "webhook_secret",
  "signing_secret",
  "workos_api_key",
  "workos_webhook_secret",
];

const WORKOS_CRED_PREFIX_RE =
  /\b(?:sk_live|sk_test|whsec|ghp|github_pat|sb_secret)_[A-Za-z0-9_-]{8,}\b/g;

const ROLE_WEIGHT: Record<WorkosOrgRole, number> = {
  owner: 4,
  admin: 3,
  member: 2,
  viewer: 1,
};

export interface WorkosSignatureVerifyResult {
  ok: boolean;
  reason?: string;
  timestampMs?: number;
}

export interface NormalizedScimUserEvent {
  eventId: string;
  eventType: WorkosScimEventType;
  workosOrgId: string;
  directoryId: string;
  directoryUserId: string;
  email: string;
  displayName: string;
  role: WorkosOrgRole;
  targetStatus: WorkosProvisioningStatus;
}

export interface OrgProvisioningAccessInput {
  orgScimEnabled: boolean;
  membershipStatus: WorkosProvisioningStatus;
  membershipRole: WorkosOrgRole;
  requiredRole: WorkosOrgRole;
}

export interface OrgProvisioningAccessDecision {
  allowed: boolean;
  reason: string;
}

export function maskWorkosText(input: string): string {
  return maskLogString(input, SENSITIVE_WORKOS_FIELDS).replace(
    WORKOS_CRED_PREFIX_RE,
    MASK_PLACEHOLDER,
  );
}

export function sanitizeWorkosMetadata(
  payload: unknown,
): Record<string, unknown> {
  if (typeof payload !== "object" || payload === null || Array.isArray(payload)) {
    return {};
  }
  const masked = maskLogValue(payload, SENSITIVE_WORKOS_FIELDS);
  if (typeof masked !== "object" || masked === null || Array.isArray(masked)) {
    return {};
  }
  return JSON.parse(
    maskWorkosText(JSON.stringify(masked)),
  ) as Record<string, unknown>;
}

export function constantTimeHexEqual(left: string, right: string): boolean {
  const a = left.trim().toLowerCase();
  const b = right.trim().toLowerCase();
  if (a.length === 0 || a.length !== b.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i += 1) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

export async function computeWorkosHmacHex(
  timestampMs: string,
  rawBody: string,
  hmacKeyMaterial: string,
): Promise<string> {
  const encoder = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    encoder.encode(hmacKeyMaterial),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signedPayload = `${timestampMs}.${rawBody}`;
  const signatureBytes = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    encoder.encode(signedPayload),
  );
  return [...new Uint8Array(signatureBytes)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function parseWorkosSignatureHeader(
  headerValue: string,
): { timestampMs: string; v1Hex: string } | null {
  if (!headerValue.trim()) {
    return null;
  }
  let timestampMs = "";
  let v1Hex = "";
  for (const segment of headerValue.split(",")) {
    const eqIndex = segment.indexOf("=");
    if (eqIndex <= 0) {
      continue;
    }
    const key = segment.slice(0, eqIndex).trim().toLowerCase();
    const val = segment.slice(eqIndex + 1).trim();
    if (key === "t" && /^\d{10,16}$/.test(val)) {
      timestampMs = val;
    } else if (key === "v1" && /^[0-9a-f]{64}$/i.test(val)) {
      v1Hex = val;
    }
  }
  if (!timestampMs || !v1Hex) {
    return null;
  }
  return { timestampMs, v1Hex };
}

export async function verifyWorkosSignature(options: {
  rawBody: string;
  signatureHeader: string;
  hmacMaterial: string;
  nowMs?: number;
  toleranceMs?: number;
}): Promise<WorkosSignatureVerifyResult> {
  const { rawBody, signatureHeader, hmacMaterial } = options;
  if (!hmacMaterial.trim()) {
    return { ok: false, reason: "webhook_signing_secret_not_configured" };
  }
  const parsed = parseWorkosSignatureHeader(signatureHeader);
  if (!parsed) {
    return { ok: false, reason: "malformed_workos_signature_header" };
  }
  const tsMs = Number(parsed.timestampMs);
  const nowMs = options.nowMs ?? Date.now();
  const toleranceMs = options.toleranceMs ?? DEFAULT_WORKOS_TOLERANCE_MS;
  if (!Number.isFinite(tsMs) || Math.abs(nowMs - tsMs) > toleranceMs) {
    return { ok: false, reason: "signature_timestamp_outside_tolerance" };
  }
  const expectedHex = await computeWorkosHmacHex(
    parsed.timestampMs,
    rawBody,
    hmacMaterial,
  );
  if (!constantTimeHexEqual(expectedHex, parsed.v1Hex)) {
    return { ok: false, reason: "signature_mismatch" };
  }
  return { ok: true, timestampMs: tsMs };
}

function asObj(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function asStr(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function extractEmail(data: Record<string, unknown>): string {
  const direct = asStr(data.email);
  if (direct) return direct;
  const emails = Array.isArray(data.emails) ? data.emails : [];
  for (const item of emails) {
    const rec = asObj(item);
    const val = asStr(rec.value);
    if (val) return val;
  }
  return "";
}

function extractRole(data: Record<string, unknown>): WorkosOrgRole {
  const roleObj = asObj(data.role);
  const slug = (asStr(roleObj.slug) || asStr(data.role)).toLowerCase();
  if (VALID_ORG_ROLES.has(slug as WorkosOrgRole)) {
    return slug as WorkosOrgRole;
  }
  return "member";
}

export function normalizeDirectorySyncEvent(
  rawPayload: unknown,
): NormalizedScimUserEvent {
  const root = asObj(rawPayload);
  const eventId = asStr(root.id);
  const eventType = asStr(root.event) as WorkosScimEventType;
  if (!eventId) {
    throw new Error("Missing WorkOS event id");
  }
  if (!VALID_SCIM_EVENT_TYPES.has(eventType)) {
    throw new Error(`Unsupported WorkOS event type: ${eventType || "unknown"}`);
  }

  const data = asObj(root.data);
  const directoryUserId = asStr(data.id);
  const workosOrgId = asStr(data.organization_id) || asStr(root.organization_id);
  const directoryId = asStr(data.directory_id);
  if (!directoryUserId || !workosOrgId) {
    throw new Error("Missing directory user id or organization_id in SCIM event");
  }

  const rawState = asStr(data.state).toLowerCase();
  let targetStatus: WorkosProvisioningStatus;
  if (eventType === "dsync.user.deleted") {
    targetStatus = "deprovisioned";
  } else if (rawState === "suspended" || rawState === "inactive") {
    targetStatus = "suspended";
  } else {
    targetStatus = "active";
  }

  const first = asStr(data.first_name);
  const last = asStr(data.last_name);
  const displayName =
    asStr(data.display_name) || [first, last].filter(Boolean).join(" ").trim();
  const email = extractEmail(data) || `${directoryUserId}@scim.invalid`;

  return {
    eventId,
    eventType,
    workosOrgId,
    directoryId,
    directoryUserId,
    email,
    displayName,
    role: extractRole(data),
    targetStatus,
  };
}

export function evaluateOrgProvisioningAccess(
  input: OrgProvisioningAccessInput,
): OrgProvisioningAccessDecision {
  if (!input.orgScimEnabled) {
    return { allowed: false, reason: "organization_scim_disabled" };
  }
  if (input.membershipStatus !== "active") {
    return {
      allowed: false,
      reason: `membership_${input.membershipStatus}`,
    };
  }
  if (ROLE_WEIGHT[input.membershipRole] < ROLE_WEIGHT[input.requiredRole]) {
    return {
      allowed: false,
      reason: `insufficient_role:${input.membershipRole}<${input.requiredRole}`,
    };
  }
  return { allowed: true, reason: "authorized" };
}
