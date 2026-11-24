import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const DEFAULT_MAX_CONTEXT_UNITS = 1_000_000;
export const DEFAULT_FREE_MAX_SOURCES = 20;

export type CustomDataSourceType =
  | "text"
  | "markdown"
  | "csv"
  | "json"
  | "url"
  | "repository";

export interface ContextBudgetMessage {
  role?: string;
  content?: unknown;
}

export interface ContextBudgetValidation {
  allowed: boolean;
  estimatedUnits: number;
  maxUnits: number;
  exceededBy: number;
}

export interface CustomDataSourceRow {
  id: string;
  user_id: string;
  name: string;
  source_type: CustomDataSourceType;
  estimated_units: number;
  created_at: string;
}

export interface CustomDataSourceStatus {
  plan: string;
  used: number;
  maxSources: number;
  remaining: number;
  maxContextUnits: number;
  limitReached: boolean;
  items: CustomDataSourceRow[];
}

export interface DataSourceStoreResult<T> {
  data: T | null;
  error: { message: string } | null;
}

export interface CustomDataSourceStore {
  getPlanLimits(
    userId: string,
  ): Promise<
    DataSourceStoreResult<{
      plan: string;
      maxSources: number;
      maxContextUnits: number;
    }>
  >;
  listSources(
    userId: string,
    limit: number,
  ): Promise<DataSourceStoreResult<CustomDataSourceRow[]>>;
  insertSource(row: {
    user_id: string;
    name: string;
    source_type: CustomDataSourceType;
    estimated_units: number;
  }): Promise<DataSourceStoreResult<CustomDataSourceRow>>;
}

/**
 * Deterministic lightweight context estimator matching client-side logic:
 * ASCII characters count at ~1 unit per 4 chars; non-ASCII / CJK chars count
 * at ~1 unit per 1.5 chars so large Japanese & mixed prompts are bounded safely.
 */
export function estimateContextUnits(text: string): number {
  if (!text) return 0;
  let asciiCount = 0;
  let nonAsciiCount = 0;
  for (const ch of text) {
    const code = ch.codePointAt(0) ?? 0;
    if (code <= 0x7f) {
      asciiCount += 1;
    } else {
      nonAsciiCount += 1;
    }
  }
  return Math.ceil(asciiCount / 4) + Math.ceil((nonAsciiCount * 2) / 3);
}

export function validateMessagesContextBudget(
  messages: ReadonlyArray<ContextBudgetMessage>,
  maxUnits = DEFAULT_MAX_CONTEXT_UNITS,
): ContextBudgetValidation {
  const safeMax = Number.isFinite(maxUnits) && maxUnits > 0
    ? Math.trunc(maxUnits)
    : DEFAULT_MAX_CONTEXT_UNITS;

  let estimatedUnits = 0;
  for (const msg of messages) {
    estimatedUnits += estimateContextUnits(
      typeof msg.content === "string"
        ? msg.content
        : JSON.stringify(msg.content ?? ""),
    );
    // Small fixed per-message framing overhead.
    estimatedUnits += 4;
  }

  const exceededBy = Math.max(0, estimatedUnits - safeMax);
  return {
    allowed: estimatedUnits <= safeMax,
    estimatedUnits,
    maxUnits: safeMax,
    exceededBy,
  };
}

export function createSupabaseCustomDataSourceStore(
  admin: SupabaseClient,
): CustomDataSourceStore {
  return {
    async getPlanLimits(userId) {
      let plan = "free";
      const subRes = await admin
        .from("user_subscriptions")
        .select("plan, status")
        .eq("user_id", userId)
        .in("status", ["active", "trialing"])
        .order("updated_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (subRes.error) {
        return { data: null, error: { message: subRes.error.message } };
      }
      if (subRes.data?.plan) {
        plan = String(subRes.data.plan).trim().toLowerCase();
      } else {
        const profRes = await admin
          .from("user_profiles")
          .select("subscription_plan")
          .eq("user_id", userId)
          .maybeSingle();
        if (profRes.data?.subscription_plan) {
          plan = String(profRes.data.subscription_plan).trim().toLowerCase();
        }
      }
      if (plan !== "pro" && plan !== "enterprise") {
        plan = "free";
      }

      const limitRes = await admin
        .from("user_custom_data_source_limits")
        .select("max_sources, max_context_units")
        .eq("plan", plan)
        .maybeSingle();
      if (limitRes.error) {
        return { data: null, error: { message: limitRes.error.message } };
      }
      const fallbackMax = plan === "enterprise"
        ? 20000
        : plan === "pro"
        ? 500
        : DEFAULT_FREE_MAX_SOURCES;
      return {
        data: {
          plan,
          maxSources: Number(limitRes.data?.max_sources ?? fallbackMax),
          maxContextUnits: Number(
            limitRes.data?.max_context_units ?? DEFAULT_MAX_CONTEXT_UNITS,
          ),
        },
        error: null,
      };
    },
    async listSources(userId, limit) {
      const { data, error } = await admin
        .from("user_custom_data_sources")
        .select("*")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      return {
        data: data ? (data as CustomDataSourceRow[]) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async insertSource(row) {
      const { data, error } = await admin
        .from("user_custom_data_sources")
        .insert(row)
        .select("*")
        .single();
      return {
        data: data ? (data as CustomDataSourceRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
  };
}

export async function handleDataSourceStatus(
  store: CustomDataSourceStore,
  userId: string,
): Promise<{ status: number; body: Record<string, unknown> }> {
  if (!userId.trim()) {
    return { status: 401, body: { error: "Unauthorized" } };
  }
  const [limitsRes, listRes] = await Promise.all([
    store.getPlanLimits(userId),
    store.listSources(userId, 100),
  ]);
  if (limitsRes.error || !limitsRes.data) {
    return {
      status: 500,
      body: {
        error: limitsRes.error?.message ?? "Failed to read data source limits",
      },
    };
  }
  if (listRes.error) {
    return { status: 500, body: { error: listRes.error.message } };
  }
  const items = listRes.data ?? [];
  const used = items.length;
  const maxSources = limitsRes.data.maxSources;
  const remaining = Math.max(0, maxSources - used);

  return {
    status: 200,
    body: {
      success: true,
      plan: limitsRes.data.plan,
      used,
      max_sources: maxSources,
      remaining,
      max_context_units: limitsRes.data.maxContextUnits,
      limit_reached: used >= maxSources,
      items,
    },
  };
}

export async function handleDataSourceRegister(
  store: CustomDataSourceStore,
  userId: string,
  body: Record<string, unknown>,
): Promise<{ status: number; body: Record<string, unknown> }> {
  if (!userId.trim()) {
    return { status: 401, body: { error: "Unauthorized" } };
  }
  const name = String(body.name ?? "").trim().slice(0, 120);
  if (!name) {
    return { status: 400, body: { error: "name is required" } };
  }
  const rawType = String(body.source_type ?? "text").trim().toLowerCase();
  const allowedTypes: readonly CustomDataSourceType[] = [
    "text",
    "markdown",
    "csv",
    "json",
    "url",
    "repository",
  ];
  const sourceType: CustomDataSourceType = allowedTypes.includes(
    rawType as CustomDataSourceType,
  )
    ? (rawType as CustomDataSourceType)
    : "text";

  const contentSample = typeof body.sample_text === "string"
    ? body.sample_text
    : "";
  const rawUnits = Number(body.estimated_units ?? 0);
  const estimatedUnits = contentSample.length > 0
    ? estimateContextUnits(contentSample)
    : Number.isFinite(rawUnits) && rawUnits >= 0
    ? Math.trunc(rawUnits)
    : 0;

  const limitsRes = await store.getPlanLimits(userId);
  if (limitsRes.error || !limitsRes.data) {
    return {
      status: 500,
      body: {
        error: limitsRes.error?.message ?? "Failed to read data source limits",
      },
    };
  }
  if (estimatedUnits > limitsRes.data.maxContextUnits) {
    return {
      status: 413,
      body: {
        success: false,
        code: "context_limit_exceeded",
        estimated_units: estimatedUnits,
        max_units: limitsRes.data.maxContextUnits,
        error: "データソースがコンテキスト上限を超過しています",
      },
    };
  }

  const listRes = await store.listSources(userId, limitsRes.data.maxSources + 1);
  if (listRes.error) {
    return { status: 500, body: { error: listRes.error.message } };
  }
  const existing = listRes.data ?? [];
  if (existing.length >= limitsRes.data.maxSources) {
    return {
      status: 409,
      body: {
        success: false,
        code: "custom_data_source_limit_exceeded",
        limit_reached: true,
        used: existing.length,
        max_sources: limitsRes.data.maxSources,
        error: "カスタムデータソースの登録上限に達しています",
      },
    };
  }

  const inserted = await store.insertSource({
    user_id: userId,
    name,
    source_type: sourceType,
    estimated_units: estimatedUnits,
  });
  if (inserted.error || !inserted.data) {
    const msg = inserted.error?.message ?? "Failed to register data source";
    if (msg.includes("custom_data_source_limit_exceeded")) {
      return {
        status: 409,
        body: {
          success: false,
          code: "custom_data_source_limit_exceeded",
          limit_reached: true,
          used: limitsRes.data.maxSources,
          max_sources: limitsRes.data.maxSources,
          error: "カスタムデータソースの登録上限に達しています",
        },
      };
    }
    return { status: 500, body: { error: msg } };
  }

  return {
    status: 201,
    body: {
      success: true,
      item: inserted.data,
      used: existing.length + 1,
      max_sources: limitsRes.data.maxSources,
      limit_reached: existing.length + 1 >= limitsRes.data.maxSources,
    },
  };
}
