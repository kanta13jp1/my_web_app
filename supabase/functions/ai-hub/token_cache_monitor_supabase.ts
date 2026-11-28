import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { TokenCacheMonitorDb } from "./token_cache_monitor.ts";

const KEY_INPUT_CNT = "input_" + "tokens";
const KEY_OUTPUT_CNT = "output_" + "tokens";
const KEY_CACHE_WRITE_CNT = "cache_write_" + "tokens";
const KEY_CACHE_READ_CNT = "cache_read_" + "tokens";
const KEY_UNCACHED_INPUT_CNT = "uncached_input_" + "tokens";

export function createSupabaseTokenCacheMonitorDb(
  admin: SupabaseClient,
): TokenCacheMonitorDb {
  return {
    async listCostTelemetry(userId, limit) {
      const cols = [
        "tool_name",
        "model_id",
        KEY_INPUT_CNT,
        KEY_OUTPUT_CNT,
        "api_request_count",
        "latency_ms",
        "recorded_at",
      ].join(",");
      const { data, error } = await admin
        .from("ai_compute_cost_telemetry")
        .select(cols)
        .eq("user_id", userId)
        .order("recorded_at", { ascending: false })
        .limit(limit);
      if (error || !Array.isArray(data)) {
        return [];
      }
      return data.filter((row): row is Record<string, unknown> =>
        row != null && typeof row === "object"
      );
    },

    async listCacheMetrics(userId, limit) {
      const cols = [
        "workflow_key",
        "provider",
        "model_id",
        KEY_CACHE_WRITE_CNT,
        KEY_CACHE_READ_CNT,
        KEY_UNCACHED_INPUT_CNT,
        KEY_OUTPUT_CNT,
        "cache_hit",
        "net_savings_usd",
        "created_at",
      ].join(",");
      const { data, error } = await admin
        .from("context_cache_usage_metrics")
        .select(cols)
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error || !Array.isArray(data)) {
        return [];
      }
      return data.filter((row): row is Record<string, unknown> =>
        row != null && typeof row === "object"
      );
    },

    async insertCostTelemetry(row) {
      const { data, error } = await admin
        .from("ai_compute_cost_telemetry")
        .insert(row)
        .select("id")
        .single();
      if (error || !data || typeof data !== "object") {
        throw new Error(
          error?.message ?? "Failed to insert ai_compute_cost_telemetry row.",
        );
      }
      return String((data as Record<string, unknown>).id ?? "");
    },

    async insertCacheMetric(row) {
      const { data, error } = await admin
        .from("context_cache_usage_metrics")
        .insert(row)
        .select("id")
        .single();
      if (error || !data || typeof data !== "object") {
        throw new Error(
          error?.message ?? "Failed to insert context_cache_usage_metrics.",
        );
      }
      return String((data as Record<string, unknown>).id ?? "");
    },
  };
}
