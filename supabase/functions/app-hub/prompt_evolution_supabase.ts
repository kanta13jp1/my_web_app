import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type {
  PromptEvolutionDb,
  PromptTemplateDraft,
} from "./prompt_evolution.ts";

export function createSupabasePromptEvolutionDb(
  admin: SupabaseClient,
): PromptEvolutionDb {
  return {
    async insertGpaEvaluation(row) {
      const { data, error } = await admin
        .from("agent_gpa_evaluations")
        .insert(row)
        .select("id")
        .single();
      if (error || !data || typeof data !== "object") {
        throw new Error(
          error?.message ?? "Failed to insert agent_gpa_evaluations row.",
        );
      }
      const record = data as Record<string, unknown>;
      return String(record.id ?? "");
    },

    async listRecentEvaluations(userId, limit) {
      const cols = [
        "id",
        "source_type",
        "source_id",
        "goal_score",
        "plan_score",
        "action_score",
        "consistency_score",
        "gpa",
        "judge_model",
        "rationale_short",
        "improvement_suggestions",
        "evaluated_at",
        "created_at",
      ].join(",");
      const { data, error } = await admin
        .from("agent_gpa_evaluations")
        .select(cols)
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error || !Array.isArray(data)) {
        throw new Error(
          error?.message ?? "Failed to load agent_gpa_evaluations rows.",
        );
      }
      return data.filter((item): item is Record<string, unknown> =>
        item != null && typeof item === "object"
      );
    },

    async insertPromptTemplateCandidate(
      userId: string,
      draft: PromptTemplateDraft,
    ) {
      const { data, error } = await admin
        .from("prompt_templates")
        .insert({
          user_id: userId,
          title: draft.title.trim().slice(0, 120),
          role_setting: draft.roleSetting.trim().slice(0, 2000),
          context_info: draft.contextInfo.trim().slice(0, 4000),
          deliverable_definition: draft.deliverableDefinition
            .trim()
            .slice(0, 4000),
          constraints_text: draft.constraintsText.trim().slice(0, 4000),
          thinking_process: draft.thinkingProcess.trim().slice(0, 4000),
          is_shared: false,
        })
        .select("id")
        .single();
      if (error || !data || typeof data !== "object") {
        throw new Error(
          error?.message ?? "Failed to insert prompt_templates candidate.",
        );
      }
      const record = data as Record<string, unknown>;
      return typeof record.id === "string" ? record.id : null;
    },
  };
}
