import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type {
  SavedRoutingPreference,
  StructuredRoutingStore,
} from "./structured_routing.ts";

function toSavedPreference(
  row: Record<string, unknown>,
): SavedRoutingPreference {
  return {
    task: String(row.task ?? ""),
    provider: String(row.provider ?? ""),
    model: typeof row.model === "string" ? row.model : null,
    is_enabled: row.is_enabled !== false,
    source: String(row.source ?? "recommendation"),
    updated_at: typeof row.updated_at === "string"
      ? row.updated_at
      : undefined,
  };
}

export function createSupabaseStructuredRoutingStore(
  admin: SupabaseClient,
): StructuredRoutingStore {
  return {
    async getTaskPreference(userId, task) {
      const { data, error } = await admin
        .from("ai_task_routing_preferences")
        .select("task, provider, model, is_enabled, source, updated_at")
        .eq("user_id", userId)
        .eq("task", task)
        .maybeSingle();
      if (error || !data || typeof data !== "object") {
        return null;
      }
      return toSavedPreference(data as Record<string, unknown>);
    },

    async listTaskPreferences(userId) {
      const { data, error } = await admin
        .from("ai_task_routing_preferences")
        .select("task, provider, model, is_enabled, source, updated_at")
        .eq("user_id", userId)
        .order("updated_at", { ascending: false });
      if (error || !Array.isArray(data)) {
        return [];
      }
      return data
        .filter((row): row is Record<string, unknown> =>
          row != null && typeof row === "object"
        )
        .map(toSavedPreference);
    },

    async upsertTaskPreference(params) {
      const nowIso = new Date().toISOString();
      const { data, error } = await admin
        .from("ai_task_routing_preferences")
        .upsert(
          {
            user_id: params.userId,
            task: params.task,
            provider: params.provider,
            model: params.model,
            is_enabled: true,
            source: params.source,
            updated_at: nowIso,
          },
          { onConflict: "user_id,task" },
        )
        .select("task, provider, model, is_enabled, source, updated_at")
        .single();
      if (error || !data || typeof data !== "object") {
        throw new Error(
          error?.message ?? "Failed to save ai_task_routing_preferences row.",
        );
      }
      return toSavedPreference(data as Record<string, unknown>);
    },
  };
}
