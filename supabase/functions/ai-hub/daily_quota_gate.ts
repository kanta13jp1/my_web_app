import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export interface DailyQuotaDecision {
  allowed: boolean;
  reason: string | null;
  plan: string;
  used: number;
  dailyLimit: number | null;
  remaining: number | null;
  quotaDate: string;
  resetAt: string | null;
}

export interface DailyQuotaStore {
  claimDailyQuota(userId: string): Promise<Record<string, unknown>>;
  getDailyQuotaStatus(userId: string): Promise<Record<string, unknown>>;
}

export function createSupabaseDailyQuotaStore(
  admin: SupabaseClient,
): DailyQuotaStore {
  return {
    async claimDailyQuota(userId) {
      const { data, error } = await admin.rpc("claim_user_daily_ai_quota", {
        p_user_id: userId,
      });
      if (error) throw new Error(error.message);
      if (data !== null && typeof data === "object" && !Array.isArray(data)) {
        return data as Record<string, unknown>;
      }
      throw new Error("Unexpected RPC payload from claim_user_daily_ai_quota");
    },
    async getDailyQuotaStatus(userId) {
      const { data, error } = await admin.rpc(
        "get_user_daily_ai_quota_status",
        { p_user_id: userId },
      );
      if (error) throw new Error(error.message);
      if (data !== null && typeof data === "object" && !Array.isArray(data)) {
        return data as Record<string, unknown>;
      }
      throw new Error(
        "Unexpected RPC payload from get_user_daily_ai_quota_status",
      );
    },
  };
}

function asNonNegativeInt(raw: unknown): number | null {
  if (typeof raw === "number" && Number.isFinite(raw)) {
    return Math.max(Math.trunc(raw), 0);
  }
  const n = Number(raw);
  if (Number.isFinite(n)) {
    return Math.max(Math.trunc(n), 0);
  }
  return null;
}

export function parseDailyQuotaPayload(
  raw: Record<string, unknown>,
): DailyQuotaDecision {
  const plan = typeof raw.plan === "string" && raw.plan.trim() !== ""
    ? raw.plan.trim().toLowerCase()
    : "free";
  const used = asNonNegativeInt(raw.used) ?? 0;
  const dailyLimit = raw.daily_limit === null
    ? null
    : asNonNegativeInt(raw.daily_limit);
  const remaining = raw.remaining === null
    ? null
    : asNonNegativeInt(raw.remaining) ??
      (dailyLimit !== null ? Math.max(dailyLimit - used, 0) : null);
  const quotaDate = typeof raw.quota_date === "string"
    ? raw.quota_date
    : new Date().toISOString().slice(0, 10);
  const resetAt = typeof raw.reset_at === "string" ? raw.reset_at : null;
  const allowed = raw.allowed !== false &&
    (dailyLimit === null || used <= dailyLimit);
  const reason = typeof raw.reason === "string" ? raw.reason : null;

  return {
    allowed,
    reason,
    plan,
    used,
    dailyLimit,
    remaining,
    quotaDate,
    resetAt,
  };
}

export async function enforceDailyAiQuota(
  store: DailyQuotaStore,
  userId: string,
): Promise<DailyQuotaDecision> {
  try {
    const raw = await store.claimDailyQuota(userId);
    return parseDailyQuotaPayload(raw);
  } catch {
    // Fail-open on transient RPC errors so existing chat paths never hard-break.
    return {
      allowed: true,
      reason: "daily_quota_store_error",
      plan: "unknown",
      used: 0,
      dailyLimit: null,
      remaining: null,
      quotaDate: new Date().toISOString().slice(0, 10),
      resetAt: null,
    };
  }
}

export async function readDailyAiQuotaStatus(
  store: DailyQuotaStore,
  userId: string,
): Promise<DailyQuotaDecision> {
  const raw = await store.getDailyQuotaStatus(userId);
  return parseDailyQuotaPayload(raw);
}
