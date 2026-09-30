export const HEDRA_MIN_BATCH_SIZE = 1;
export const HEDRA_MAX_BATCH_SIZE = 8;

export type HedraBatchVariant = {
  id: string | null;
  status: string;
  videoUrl: string | null;
  previewUrl: string | null;
  downloadUrl: string | null;
  progress: number | null;
  etaSec: number | null;
  reason: string | null;
};

export type HedraBatchResponse = {
  batchGenerationId: string | null;
  batchSize: number;
  generationIds: string[];
  variants: HedraBatchVariant[];
};

export function parseHedraBatchSize(value: unknown): number {
  if (value == null || value === "") return HEDRA_MIN_BATCH_SIZE;
  const parsed = typeof value === "number"
    ? value
    : typeof value === "string" && /^\d+$/.test(value.trim())
    ? Number(value.trim())
    : Number.NaN;
  if (
    !Number.isInteger(parsed) || parsed < HEDRA_MIN_BATCH_SIZE ||
    parsed > HEDRA_MAX_BATCH_SIZE
  ) {
    throw new Error(
      `batchSize must be an integer between ${HEDRA_MIN_BATCH_SIZE} and ${HEDRA_MAX_BATCH_SIZE}`,
    );
  }
  return parsed;
}

export function withHedraBatchSize(
  body: Record<string, unknown>,
  batchSize: number,
): Record<string, unknown> {
  return { ...body, batch_size: parseHedraBatchSize(batchSize) };
}

export function parseHedraGenerationIds(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  for (const candidate of value) {
    if (typeof candidate !== "string") continue;
    const id = candidate.trim();
    if (id.length > 0 && id.length <= 200) seen.add(id);
    if (seen.size === HEDRA_MAX_BATCH_SIZE) break;
  }
  return [...seen];
}

export function normalizeHedraBatchResponse(
  payload: unknown,
): HedraBatchResponse {
  const record = asRecord(payload) ?? {};
  const rawVariants = Array.isArray(record["batch_results"])
    ? record["batch_results"]
    : Array.isArray(record["results"])
    ? record["results"]
    : [];
  const listedIds = parseHedraGenerationIds(record["generation_ids"]);
  let variants = rawVariants
    .map((item) => normalizeVariant(item))
    .filter((item): item is HedraBatchVariant => item != null);
  if (variants.length === 0) {
    variants = listedIds.length > 0
      ? listedIds.map((id) => ({ ...emptyVariant(), id }))
      : [normalizeVariant(record) ?? emptyVariant()];
  }

  variants = variants.map((variant, index) =>
    variant.id == null && listedIds[index] != null
      ? { ...variant, id: listedIds[index] }
      : variant
  );
  const generationIds = uniqueStrings([
    ...listedIds,
    ...variants.map((item) => item.id),
  ]);
  const declaredSize = firstNumber(record["batch_size"]);

  return {
    batchGenerationId: firstString(
      record["batch_generation_id"],
      record["batch_id"],
    ),
    batchSize: declaredSize == null
      ? Math.max(HEDRA_MIN_BATCH_SIZE, variants.length)
      : Math.min(
        HEDRA_MAX_BATCH_SIZE,
        Math.max(HEDRA_MIN_BATCH_SIZE, Math.trunc(declaredSize)),
      ),
    generationIds,
    variants,
  };
}

function normalizeVariant(value: unknown): HedraBatchVariant | null {
  const record = asRecord(value);
  if (!record) return null;
  const generation = asRecord(record["generation"]);
  const video = asRecord(record["video"]);
  const result = asRecord(record["result"]);
  const asset = asRecord(record["asset"]);
  return {
    id: firstString(
      record["id"],
      record["generation_id"],
      record["video_id"],
      generation?.["id"],
      video?.["id"],
      result?.["id"],
    ),
    status: firstString(
      record["status"],
      generation?.["status"],
      video?.["status"],
      result?.["status"],
    ) ?? "submitted",
    videoUrl: firstString(
      record["video_url"],
      record["url"],
      record["download_url"],
      asset?.["url"],
      generation?.["video_url"],
      generation?.["url"],
      video?.["url"],
      video?.["download_url"],
      result?.["url"],
      result?.["download_url"],
    ),
    previewUrl: firstString(
      record["preview_url"],
      record["streaming_url"],
      record["thumbnail_url"],
      video?.["preview_url"],
      result?.["preview_url"],
    ),
    downloadUrl: firstString(
      record["download_url"],
      video?.["download_url"],
      result?.["download_url"],
    ),
    progress: firstNumber(
      record["progress"],
      generation?.["progress"],
      result?.["progress"],
    ),
    etaSec: firstNumber(
      record["eta_sec"],
      generation?.["eta_sec"],
      result?.["eta_sec"],
    ),
    reason: firstString(
      record["error_message"],
      record["error"],
      generation?.["error"],
      result?.["error_message"],
      result?.["error"],
    ),
  };
}

function emptyVariant(): HedraBatchVariant {
  return {
    id: null,
    status: "submitted",
    videoUrl: null,
    previewUrl: null,
    downloadUrl: null,
    progress: null,
    etaSec: null,
    reason: null,
  };
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null
    ? value as Record<string, unknown>
    : null;
}

function firstString(...values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }
  return null;
}

function firstNumber(...values: unknown[]): number | null {
  for (const value of values) {
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string" && value.trim().length > 0) {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return null;
}

function uniqueStrings(values: Array<string | null>): string[] {
  return [...new Set(values.filter((value): value is string => value != null))];
}
