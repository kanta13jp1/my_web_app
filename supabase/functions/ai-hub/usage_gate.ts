// AI 使用量メータリング + フリーミアム上限ゲート (#3645 paywall / #3646 metering)
//
// 設計方針:
//  - フェイルオープン: 課金/メータリングのDBエラーで AI 応答を絶対に止めない。
//  - 純粋ロジック (decideUsage) と DB I/O (UsageStore) を分離してテスト容易に。
//  - free は月次上限 (既定 30 回 = 課金UI表記と一致)、pro/team は無制限。
//    pro/team も利用量は記録する (billing.status の usage 表示用)。

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const FREE_AI_QUERY_LIMIT = 30;

/// 当課金期間 (= 暦月初日 'YYYY-MM-DD')。schedule-hub の billing と同形式。
export function currentBillingPeriodStart(now: Date): string {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
    .toISOString()
    .slice(0, 10);
}

export interface UsageDecision {
  allowed: boolean;
  tier: string;
  used: number;
  /// null = 無制限 (pro/team)
  limit: number | null;
  reason?: string;
}

/// 純粋な判定ロジック (DB 非依存・完全テスト対象)。
export function decideUsage(
  tier: string,
  used: number,
  limit: number,
): UsageDecision {
  const t = (tier || "free").toLowerCase();
  if (t === "pro" || t === "team") {
    return { allowed: true, tier: t, used, limit: null };
  }
  if (used >= limit) {
    return {
      allowed: false,
      tier: "free",
      used,
      limit,
      reason: "free_limit_reached",
    };
  }
  return { allowed: true, tier: "free", used, limit };
}

/// DB I/O 抽象。Supabase に依存せずモック可能にするための注入点。
export interface UsageStore {
  getTier(userId: string): Promise<string>;
  getCount(userId: string, periodStart: string): Promise<number>;
  setCount(userId: string, periodStart: string, count: number): Promise<void>;
}

export interface UsageOptions {
  limit?: number;
  now?: Date;
}

/// tier を読み、当月カウンタを読み、許可なら +1 して記録する。
/// 失敗時はフェイルオープン (allowed=true) で AI を止めない。
/// 注: read→write は厳密にアトミックでなく、高並行下では僅かに過小計数し得る
/// (= ユーザーに有利な緩い上限。課金の soft-limit として許容)。
export async function checkAndRecordAiUsage(
  store: UsageStore,
  userId: string,
  opts: UsageOptions = {},
): Promise<UsageDecision> {
  const limit = opts.limit ?? FREE_AI_QUERY_LIMIT;
  const periodStart = currentBillingPeriodStart(opts.now ?? new Date());
  try {
    const tier = await store.getTier(userId);
    const used = await store.getCount(userId, periodStart);
    const decision = decideUsage(tier, used, limit);
    if (!decision.allowed) return decision;
    await store.setCount(userId, periodStart, used + 1);
    return { ...decision, used: used + 1 };
  } catch (_error) {
    // フェイルオープン: メータリング失敗で AI を遮断しない。
    return {
      allowed: true,
      tier: "unknown",
      used: 0,
      limit: null,
      reason: "metering_error",
    };
  }
}

/// Supabase admin client を UsageStore に適合させる薄いアダプタ。
export function supabaseUsageStore(admin: SupabaseClient): UsageStore {
  return {
    async getTier(userId) {
      const { data, error } = await admin
        .from("billing_subscriptions")
        .select("tier")
        .eq("user_id", userId)
        .maybeSingle();
      if (error) throw new Error(error.message);
      const tier = (data as { tier?: unknown } | null)?.tier;
      return typeof tier === "string" ? tier : "free";
    },
    async getCount(userId, periodStart) {
      const { data, error } = await admin
        .from("billing_usage_counters")
        .select("ai_query_count")
        .eq("user_id", userId)
        .eq("period_start", periodStart)
        .maybeSingle();
      if (error) throw new Error(error.message);
      const n = (data as { ai_query_count?: unknown } | null)?.ai_query_count;
      return typeof n === "number" ? n : Number(n ?? 0) || 0;
    },
    async setCount(userId, periodStart, count) {
      const { error } = await admin
        .from("billing_usage_counters")
        .upsert({
          user_id: userId,
          period_start: periodStart,
          ai_query_count: count,
        }, { onConflict: "user_id,period_start" });
      if (error) throw new Error(error.message);
    },
  };
}
