export type ArtifactStorageScope = "private" | "shared";

export const ARTIFACT_SCOPE_LABELS = {
  private: "Private User Scope",
  shared: "Shared Workspace Scope",
} as const satisfies Record<ArtifactStorageScope, string>;

export const DEFAULT_MAX_PAYLOAD_BYTES = 65536;
const HIERARCHICAL_KEY_RE = /^[a-zA-Z0-9_-]{1,48}:[a-zA-Z0-9_.-]{1,79}$/;

export interface ArtifactKvRecord {
  scope: ArtifactStorageScope;
  hierarchicalKey: string;
  payloadJson: string;
  updatedAtIso: string;
  byteLength: number;
}

export interface ArtifactKeyValidation {
  valid: boolean;
  reason: string | null;
}

export function validateArtifactKey(rawKey: string): ArtifactKeyValidation {
  const trimmed = rawKey.trim();
  if (trimmed.length === 0) {
    return { valid: false, reason: "key must not be empty" };
  }
  if (trimmed.length > 128) {
    return { valid: false, reason: "key exceeds 128 characters" };
  }
  if (!HIERARCHICAL_KEY_RE.test(trimmed)) {
    return {
      valid: false,
      reason: "key must match namespace:id format",
    };
  }
  return { valid: true, reason: null };
}

export function measurePayloadBytes(payloadJson: string): number {
  return new TextEncoder().encode(payloadJson).length;
}

export function validatePayloadSize(
  payloadJson: string,
  maxBytes: number = DEFAULT_MAX_PAYLOAD_BYTES,
): ArtifactKeyValidation {
  const byteLength = measurePayloadBytes(payloadJson);
  if (byteLength > maxBytes) {
    return {
      valid: false,
      reason: `payload ${byteLength} bytes exceeds limit ${maxBytes}`,
    };
  }
  return { valid: true, reason: null };
}

export function resolveLwwRecord(
  existingRecord: ArtifactKvRecord | null,
  candidateRecord: ArtifactKvRecord,
): ArtifactKvRecord {
  if (existingRecord === null) {
    return candidateRecord;
  }
  const existingMs = Date.parse(existingRecord.updatedAtIso);
  const candidateMs = Date.parse(candidateRecord.updatedAtIso);
  if (Number.isNaN(existingMs) || Number.isNaN(candidateMs)) {
    throw new TypeError("updatedAtIso must be a valid ISO timestamp");
  }
  return candidateMs >= existingMs ? candidateRecord : existingRecord;
}

export function createArtifactRecord(
  scope: ArtifactStorageScope,
  rawKey: string,
  payloadJson: string,
  updatedAtIso: string,
  maxBytes: number = DEFAULT_MAX_PAYLOAD_BYTES,
): ArtifactKvRecord {
  const keyCheck = validateArtifactKey(rawKey);
  if (!keyCheck.valid) {
    throw new Error(keyCheck.reason ?? "invalid artifact key");
  }
  const sizeCheck = validatePayloadSize(payloadJson, maxBytes);
  if (!sizeCheck.valid) {
    throw new Error(sizeCheck.reason ?? "payload exceeds limit");
  }
  const parsedMs = Date.parse(updatedAtIso);
  if (Number.isNaN(parsedMs)) {
    throw new TypeError("updatedAtIso must be a valid ISO timestamp");
  }
  return {
    scope,
    hierarchicalKey: rawKey.trim(),
    payloadJson,
    updatedAtIso: new Date(parsedMs).toISOString(),
    byteLength: measurePayloadBytes(payloadJson),
  };
}
