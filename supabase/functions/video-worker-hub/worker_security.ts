export const MAX_VIDEO_BYTES = 50 * 1024 * 1024;

export async function hasValidWorkerAuthorization(
  request: Request,
  configuredToken: string,
): Promise<boolean> {
  if (configuredToken.length < 32 || configuredToken.length > 256) return false;
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return false;
  const supplied = authorization.slice("Bearer ".length).trim();
  if (supplied.length < 32 || supplied.length > 256) return false;

  const encoder = new TextEncoder();
  const [expectedDigest, suppliedDigest] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(configuredToken)),
    crypto.subtle.digest("SHA-256", encoder.encode(supplied)),
  ]);
  return constantTimeEqual(
    new Uint8Array(expectedDigest),
    new Uint8Array(suppliedDigest),
  );
}

export function isWorkerId(value: string): boolean {
  return /^[a-z0-9._-]{3,80}$/i.test(value);
}

export function isLeaseToken(value: string): boolean {
  return /^[a-f0-9]{64}$/i.test(value);
}

export function isJobId(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

export function isWorkerErrorCode(value: string): boolean {
  return [
    "inference_failed",
    "inference_gpu_memory_exhausted",
    "inference_host_memory_exhausted",
    "inference_memory_exhausted",
    "inference_process_failed",
    "inference_timeout",
    "lease_lost",
    "output_invalid",
    "upload_failed",
    "worker_shutdown",
  ].includes(value);
}

export function videoOutputObject(
  storagePath: string,
): { folder: string; name: string } | null {
  const match = storagePath.match(
    /^([0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\/([0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}-attempt-[1-3]\.mp4)$/i,
  );
  return match ? { folder: match[1], name: match[2] } : null;
}

export function validVideoOutputPaths(value: unknown): string[] {
  if (!Array.isArray(value) || value.length > 2) return [];
  return value.filter((path): path is string =>
    typeof path === "string" && videoOutputObject(path) !== null
  );
}

export function isExpectedVideoObject(
  value: unknown,
  expectedName: string,
): boolean {
  const object = asRecord(value);
  const metadata = asRecord(object.metadata);
  const size = videoObjectSize(value) ?? 0;
  const contentType = String(
    metadata.mimetype ?? metadata.contentType ?? object.mimetype ?? "",
  ).toLowerCase();
  return object.name === expectedName && Number.isFinite(size) && size > 0 &&
    size <= MAX_VIDEO_BYTES && contentType === "video/mp4";
}

export function videoObjectSize(value: unknown): number | null {
  const object = asRecord(value);
  const metadata = asRecord(object.metadata);
  const size = Number(metadata.size ?? object.size ?? 0);
  return Number.isSafeInteger(size) && size > 0 && size <= MAX_VIDEO_BYTES
    ? size
    : null;
}

export function isVideoSha256(value: string): boolean {
  return /^[0-9a-f]{64}$/.test(value);
}

function constantTimeEqual(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference === 0;
}

function asRecord(value: unknown): Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}
