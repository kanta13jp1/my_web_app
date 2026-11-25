import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const VISION_BENCHMARK_SOURCE = "vision_benchmark_run";
export const DEFAULT_VISION_THRESHOLD = 70;
export const MIN_VISION_THRESHOLD = 1;
export const MAX_VISION_THRESHOLD = 100;

export interface VisionBenchmarkLevel {
  level: string;
  description: string;
  passed: boolean;
  score: number;
  maxPoints: number;
  latency: number;
  response: string;
}

export interface VisionBenchmarkRunRecord {
  id: string;
  user_id: string;
  model: string;
  provider: string;
  score: number;
  latency_ms: number;
  threshold: number;
  below_threshold: boolean;
  passed: boolean;
  detail: string;
  levels: VisionBenchmarkLevel[];
  recorded_at: string;
}

export interface VisionBenchmarkModelSummary {
  model: string;
  provider: string;
  latest_score: number;
  previous_score: number | null;
  delta: number | null;
  run_count: number;
  below_threshold: boolean;
  latest_recorded_at: string;
}

export interface VisionBenchmarkSummary {
  total_runs: number;
  alert_count: number;
  average_score: number;
  below_threshold_models: string[];
  latest_by_model: VisionBenchmarkModelSummary[];
}

export interface VisionBenchmarkDb {
  insertRun(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
  listRuns(
    userId: string,
    limit: number,
  ): Promise<Array<Record<string, unknown>>>;
}

export interface VisionBenchmarkActionResult {
  status: number;
  body: Record<string, unknown>;
}

export function normalizeVisionThreshold(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed)) {
    return DEFAULT_VISION_THRESHOLD;
  }
  return Math.max(
    MIN_VISION_THRESHOLD,
    Math.min(MAX_VISION_THRESHOLD, Math.round(parsed)),
  );
}

export function normalizeVisionScore(value: unknown): number | null {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed)) {
    return null;
  }
  return Math.max(0, Math.min(100, Math.round(parsed)));
}

function asTrimmedString(value: unknown, maxLength: number): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maxLength);
}

function parseNonNegativeInt(value: unknown, fallback = 0): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return fallback;
  }
  return Math.round(parsed);
}

function parsePositiveInt(
  value: unknown,
  fallback: number,
  max: number,
): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return Math.min(max, Math.floor(parsed));
}

function parseBooleanish(value: unknown, fallback: boolean): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value !== "string") return fallback;
  const normalized = value.trim().toLowerCase();
  if (["true", "1", "yes", "on"].includes(normalized)) return true;
  if (["false", "0", "no", "off"].includes(normalized)) return false;
  return fallback;
}

function sanitizeLevels(raw: unknown): VisionBenchmarkLevel[] {
  if (!Array.isArray(raw)) return [];
  const result: VisionBenchmarkLevel[] = [];
  for (const entry of raw.slice(0, 6)) {
    if (!entry || typeof entry !== "object") continue;
    const item = entry as Record<string, unknown>;
    const score = normalizeVisionScore(item.score) ?? 0;
    const maxPoints = parsePositiveInt(
      item.maxPoints ?? item.max_points,
      100,
      1000,
    );
    result.push({
      level: asTrimmedString(item.level, 32) || `level${result.length + 1}`,
      description: asTrimmedString(item.description, 160),
      passed: parseBooleanish(item.passed, score > 0),
      score,
      maxPoints,
      latency: parseNonNegativeInt(item.latency ?? item.latency_ms, 0),
      response: asTrimmedString(item.response, 240),
    });
  }
  return result;
}

function toIsoTimestamp(value: unknown): string {
  const raw = asTrimmedString(value, 64);
  if (!raw) return new Date().toISOString();
  const ms = Date.parse(raw);
  return Number.isNaN(ms)
    ? new Date().toISOString()
    : new Date(ms).toISOString();
}

function mapRowToRun(
  row: Record<string, unknown>,
  activeThreshold: number,
  fallbackUserId: string,
): VisionBenchmarkRunRecord {
  const meta = row.metadata && typeof row.metadata === "object"
    ? (row.metadata as Record<string, unknown>)
    : {};
  const score = normalizeVisionScore(meta.score) ?? 0;
  const recordedThreshold = normalizeVisionThreshold(meta.threshold);
  const effectiveThreshold = activeThreshold || recordedThreshold;
  const passed = parseBooleanish(meta.passed, score >= effectiveThreshold);
  return {
    id: row.id == null ? "" : String(row.id),
    user_id: asTrimmedString(meta.user_id, 128) || fallbackUserId,
    model: asTrimmedString(meta.model, 120) || "unknown",
    provider: asTrimmedString(meta.provider, 64) || "unknown",
    score,
    latency_ms: parseNonNegativeInt(meta.latency_ms, 0),
    threshold: effectiveThreshold,
    below_threshold: score < effectiveThreshold,
    passed,
    detail: asTrimmedString(meta.detail, 500),
    levels: sanitizeLevels(meta.levels),
    recorded_at: toIsoTimestamp(meta.recorded_at ?? row.created_at),
  };
}

export function buildVisionBenchmarkSummary(
  runs: VisionBenchmarkRunRecord[],
  threshold: number,
): VisionBenchmarkSummary {
  const grouped = new Map<string, VisionBenchmarkRunRecord[]>();
  let scoreTotal = 0;
  for (const run of runs) {
    scoreTotal += run.score;
    const list = grouped.get(run.model) ?? [];
    list.push(run);
    grouped.set(run.model, list);
  }

  const latestByModel: VisionBenchmarkModelSummary[] = [];
  const belowModels: string[] = [];
  for (const [model, modelRuns] of grouped.entries()) {
    const latest = modelRuns[0];
    const previous = modelRuns.length > 1 ? modelRuns[1].score : null;
    const delta = previous === null ? null : latest.score - previous;
    const belowThreshold = latest.score < threshold;
    if (belowThreshold) {
      belowModels.push(model);
    }
    latestByModel.push({
      model,
      provider: latest.provider,
      latest_score: latest.score,
      previous_score: previous,
      delta,
      run_count: modelRuns.length,
      below_threshold: belowThreshold,
      latest_recorded_at: latest.recorded_at,
    });
  }

  latestByModel.sort((a, b) =>
    Number(b.below_threshold) - Number(a.below_threshold) ||
    a.latest_score - b.latest_score
  );
  const averageScore = runs.length === 0
    ? 0
    : Math.round((scoreTotal / runs.length) * 10) / 10;
  return {
    total_runs: runs.length,
    alert_count: belowModels.length,
    average_score: averageScore,
    below_threshold_models: belowModels,
    latest_by_model: latestByModel,
  };
}

export function createSupabaseVisionBenchmarkDb(
  admin: SupabaseClient,
): VisionBenchmarkDb {
  return {
    async insertRun(userId, metadata) {
      const { data, error } = await admin
        .from("hub_data")
        .insert({
          source: VISION_BENCHMARK_SOURCE,
          metadata: { ...metadata, user_id: userId },
        })
        .select("id, metadata, created_at")
        .single();
      if (error || !data || typeof data !== "object") {
        throw new Error(
          error?.message ?? "Failed to insert vision_benchmark_run row.",
        );
      }
      return data as Record<string, unknown>;
    },

    async listRuns(userId, limit) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", VISION_BENCHMARK_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error || !Array.isArray(data)) {
        throw new Error(
          error?.message ?? "Failed to load vision_benchmark_run rows.",
        );
      }
      return (data as unknown[]).filter(
        (item): item is Record<string, unknown> =>
          item != null && typeof item === "object",
      );
    },
  };
}

export async function handleVisionBenchmarkAction(params: {
  action: string;
  body: Record<string, unknown>;
  userId: string;
  db: VisionBenchmarkDb;
}): Promise<VisionBenchmarkActionResult> {
  const { action, body, userId, db } = params;
  const threshold = normalizeVisionThreshold(body.threshold);

  if (action === "vision_benchmark.list") {
    const limit = parsePositiveInt(body.limit, 40, 100);
    const modelFilter = asTrimmedString(body.model, 120);
    const rows = await db.listRuns(userId, limit);
    const mapped = rows
      .map((row) => mapRowToRun(row, threshold, userId))
      .filter((run) => !modelFilter || run.model === modelFilter);
    const summary = buildVisionBenchmarkSummary(mapped, threshold);
    return {
      status: 200,
      body: {
        success: true,
        threshold,
        runs: mapped,
        summary,
      },
    };
  }

  if (action === "vision_benchmark.record") {
    const model = asTrimmedString(body.model, 120);
    if (!model) {
      return { status: 400, body: { error: "model is required" } };
    }
    const score = normalizeVisionScore(body.score);
    if (score === null) {
      return { status: 400, body: { error: "numeric score is required" } };
    }
    const provider = asTrimmedString(body.provider, 64) || "unknown";
    const latencyMs = parseNonNegativeInt(body.latency_ms ?? body.latency, 0);
    const passed = parseBooleanish(body.passed, score >= threshold);
    const detail = asTrimmedString(body.detail, 500);
    const levels = sanitizeLevels(body.levels);
    const recordedAt = toIsoTimestamp(body.recorded_at);

    const inserted = await db.insertRun(userId, {
      model,
      provider,
      score,
      latency_ms: latencyMs,
      threshold,
      below_threshold: score < threshold,
      passed,
      detail,
      levels,
      recorded_at: recordedAt,
    });
    const run = mapRowToRun(inserted, threshold, userId);
    return {
      status: 200,
      body: {
        success: true,
        threshold,
        run,
      },
    };
  }

  return { status: 400, body: { error: `Unknown action: ${action}` } };
}
