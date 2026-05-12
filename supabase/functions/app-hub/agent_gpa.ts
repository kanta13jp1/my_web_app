export const AGENT_GPA_SOURCE_TYPES = [
  "executive_chat",
  "executive_meeting",
  "secretary_action",
] as const;

type AgentGpaSourceType = typeof AGENT_GPA_SOURCE_TYPES[number];

type EvaluationScores = {
  goal_score: number;
  plan_score: number;
  action_score: number;
  consistency_score: number;
};

type ImprovementSuggestion = {
  type: "rerun" | "prompt_edit" | "approval_gate" | "scope_split";
  axis: "goal" | "plan" | "action" | "consistency";
  suggestion: string;
};

type AgentGpaEvaluation = EvaluationScores & {
  gpa: number;
  rationale_short: string;
  improvement_suggestions: ImprovementSuggestion[];
};

type DbResult<T> = {
  data: T | null;
  error?: { code?: string; message?: string } | null;
};

type QueryLike<T = unknown> = PromiseLike<DbResult<T>> & {
  select(columns: string): QueryLike<T>;
  insert(values: Record<string, unknown>): QueryLike<T>;
  eq(column: string, value: unknown): QueryLike<T>;
  filter(column: string, operator: string, value: unknown): QueryLike<T>;
  gte(column: string, value: unknown): QueryLike<T>;
  lte(column: string, value: unknown): QueryLike<T>;
  order(column: string, options?: { ascending?: boolean }): QueryLike<T>;
  limit(count: number): QueryLike<T>;
  single(): PromiseLike<DbResult<T>>;
  maybeSingle(): PromiseLike<DbResult<T | null>>;
};

type AgentGpaDb = {
  from(table: string): unknown;
};

const SOURCE_TABLES: Record<AgentGpaSourceType, string> = {
  executive_chat: "executive_chat_logs",
  executive_meeting: "executive_meetings",
  secretary_action: "secretary_actions",
};

const HUB_SOURCE_FALLBACKS: Record<AgentGpaSourceType, string[]> = {
  executive_chat: ["executive_chat", "executive_chat_log"],
  executive_meeting: ["executive_meeting", "executive_meeting_log"],
  secretary_action: ["secretary_action", "secretary_run"],
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class AgentGpaActionError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "AgentGpaActionError";
    this.status = status;
  }
}

export async function handleAgentGpaAction({
  action,
  admin,
  body,
  userId,
}: {
  action: string;
  admin: AgentGpaDb;
  body: Record<string, unknown>;
  userId: string;
}) {
  if (action === "agent.evaluate_gpa") {
    return await evaluateAgentGpa(admin, body, userId);
  }
  if (action === "agent.list_gpa_recent") {
    return await listAgentGpaRecent(admin, body, userId);
  }
  throw new AgentGpaActionError(`Unsupported agent GPA action: ${action}`);
}

export function normalizeSourceType(value: unknown): AgentGpaSourceType {
  const sourceType = typeof value === "string" ? value.trim() : "";
  if (AGENT_GPA_SOURCE_TYPES.includes(sourceType as AgentGpaSourceType)) {
    return sourceType as AgentGpaSourceType;
  }
  throw new AgentGpaActionError(
    `source_type must be one of: ${AGENT_GPA_SOURCE_TYPES.join(", ")}`,
  );
}

export function boundedLimit(value: unknown, fallback = 50): number {
  const parsed = Number(value ?? fallback);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(200, Math.max(1, Math.trunc(parsed)));
}

export function buildRuleBasedGpaEvaluation(
  sourceType: AgentGpaSourceType,
  source: Record<string, unknown>,
): AgentGpaEvaluation {
  const text = compactText(source);
  const hasGoal = hasAnyKey(source, ["goal", "objective", "prompt", "request"]);
  const hasPlan = hasAnyKey(source, ["plan", "steps", "todo", "workflow"]);
  const hasAction = hasAnyKey(source, [
    "action",
    "actions",
    "tool_calls",
    "toolCalls",
    "result",
    "response",
    "output",
  ]);
  const hasError =
    text.match(/\b(error|failed|failure|exception|timeout)\b/i) !=
      null;
  const hasConstraintIssue = text.match(
    /\b(contradiction|inconsistent|policy violation|pii|secret leaked)\b/i,
  ) != null;
  const status = String(source.status ?? source.state ?? "").toLowerCase();
  const successLike = status === "completed" || status === "succeeded" ||
    status === "success" || source.success === true;
  const failedLike = status === "failed" || status === "error" ||
    source.success === false;

  const scores: EvaluationScores = {
    goal_score: score(
      3.0 + (hasGoal ? 0.5 : -0.3) + (successLike ? 0.3 : 0) -
        (failedLike ? 0.9 : 0),
    ),
    plan_score: score(2.8 + (hasPlan ? 0.7 : -0.2) - (hasError ? 0.3 : 0)),
    action_score: score(
      2.9 + (hasAction ? 0.6 : -0.2) + (successLike ? 0.2 : 0) -
        (hasError || failedLike ? 1.0 : 0),
    ),
    consistency_score: score(
      3.3 - (hasConstraintIssue ? 1.2 : 0) -
        (failedLike ? 0.4 : 0),
    ),
  };
  const gpa = score(
    (scores.goal_score + scores.plan_score + scores.action_score +
      scores.consistency_score) / 4,
    2,
  );
  const weakAxes = buildImprovementSuggestions(scores);
  return {
    ...scores,
    gpa,
    rationale_short: buildRationale(sourceType, scores, successLike, hasError),
    improvement_suggestions: weakAxes,
  };
}

export function buildImprovementSuggestions(
  scores: EvaluationScores,
): ImprovementSuggestion[] {
  const suggestions: ImprovementSuggestion[] = [];
  if (scores.goal_score < 2.5) {
    suggestions.push({
      type: "scope_split",
      axis: "goal",
      suggestion:
        "Split the requested goal into one atomic objective before rerunning.",
    });
  }
  if (scores.plan_score < 2.5) {
    suggestions.push({
      type: "prompt_edit",
      axis: "plan",
      suggestion:
        "Add an explicit ordered plan requirement and acceptance checklist to the system prompt.",
    });
  }
  if (scores.action_score < 2.5) {
    suggestions.push({
      type: "approval_gate",
      axis: "action",
      suggestion:
        "Route risky tool or database actions through an approval step before automation continues.",
    });
  }
  if (scores.consistency_score < 2.5) {
    suggestions.push({
      type: "rerun",
      axis: "consistency",
      suggestion:
        "Rerun with a stricter consistency check and ask the model to cite violated constraints.",
    });
  }
  return suggestions;
}

async function evaluateAgentGpa(
  admin: AgentGpaDb,
  body: Record<string, unknown>,
  userId: string,
) {
  const sourceType = normalizeSourceType(body.source_type);
  const sourceId = asUuid(body.source_id, "source_id");
  const judgeModel = asNonEmptyString(body.judge_model) ??
    "claude-sonnet-4-6";
  const source = await loadSourceRecord(admin, sourceType, sourceId, userId) ??
    optionalSourcePayload(body.source_payload);
  if (!source) {
    throw new AgentGpaActionError("source record not found", 404);
  }

  const evaluation = buildRuleBasedGpaEvaluation(sourceType, source);
  const { data, error } = await table(admin, "agent_gpa_evaluations").insert({
    user_id: userId,
    source_type: sourceType,
    source_id: sourceId,
    goal_score: evaluation.goal_score,
    plan_score: evaluation.plan_score,
    action_score: evaluation.action_score,
    consistency_score: evaluation.consistency_score,
    judge_model: judgeModel,
    rationale_short: evaluation.rationale_short,
    improvement_suggestions: evaluation.improvement_suggestions,
  }).select(
    "id,source_type,source_id,goal_score,plan_score,action_score,consistency_score,gpa,judge_model,rationale_short,improvement_suggestions,evaluated_at,created_at",
  ).single();
  if (error) throw new Error(error.message);

  const row = asRecord(data);
  if (!row) throw new Error("evaluation insert returned no row");
  return {
    evaluation_id: row.id,
    gpa: Number(row.gpa ?? evaluation.gpa),
    scores: {
      goal: Number(row.goal_score ?? evaluation.goal_score),
      plan: Number(row.plan_score ?? evaluation.plan_score),
      action: Number(row.action_score ?? evaluation.action_score),
      consistency: Number(
        row.consistency_score ?? evaluation.consistency_score,
      ),
    },
    rationale_short: row.rationale_short ?? evaluation.rationale_short,
    improvement_suggestions: row.improvement_suggestions ??
      evaluation.improvement_suggestions,
    evaluation: row,
  };
}

async function listAgentGpaRecent(
  admin: AgentGpaDb,
  body: Record<string, unknown>,
  userId: string,
) {
  const limit = boundedLimit(body.limit);
  let query = table(admin, "agent_gpa_evaluations").select(
    "id,source_type,source_id,goal_score,plan_score,action_score,consistency_score,gpa,judge_model,rationale_short,improvement_suggestions,evaluated_at,created_at",
  ).eq("user_id", userId).order("created_at", { ascending: false }).limit(
    limit,
  );

  if (body.source_type != null && String(body.source_type).trim()) {
    query = query.eq("source_type", normalizeSourceType(body.source_type));
  }
  const minGpa = optionalGpa(body.min_gpa, "min_gpa");
  const maxGpa = optionalGpa(body.max_gpa, "max_gpa");
  if (minGpa != null) query = query.gte("gpa", minGpa);
  if (maxGpa != null) query = query.lte("gpa", maxGpa);

  const { data, error } = await query;
  if (error) throw new Error(error.message);
  const evaluations = Array.isArray(data) ? data : [];
  return { evaluations, total_count: evaluations.length };
}

async function loadSourceRecord(
  admin: AgentGpaDb,
  sourceType: AgentGpaSourceType,
  sourceId: string,
  userId: string,
): Promise<Record<string, unknown> | null> {
  const table = SOURCE_TABLES[sourceType];
  const { data, error } = await tableQuery(admin, table).select("*").eq(
    "id",
    sourceId,
  ).eq("user_id", userId).maybeSingle();
  if (error && !isMissingRelation(error)) {
    throw new Error(error.message);
  }
  if (data) return asRecord(data);
  return await loadHubDataSource(admin, sourceType, sourceId, userId);
}

async function loadHubDataSource(
  admin: AgentGpaDb,
  sourceType: AgentGpaSourceType,
  sourceId: string,
  userId: string,
): Promise<Record<string, unknown> | null> {
  const { data, error } = await table(admin, "hub_data").select(
    "id,source,metadata,created_at",
  ).eq("id", sourceId).filter("metadata->>user_id", "eq", userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  const row = asRecord(data);
  if (!row) return null;
  const source = String(row.source ?? "");
  if (!HUB_SOURCE_FALLBACKS[sourceType].includes(source)) return null;
  const metadata = asRecord(row.metadata) ?? {};
  return { ...metadata, id: row.id, source, created_at: row.created_at };
}

function asUuid(value: unknown, name: string): string {
  const id = asNonEmptyString(value);
  if (!id || !UUID_PATTERN.test(id)) {
    throw new AgentGpaActionError(`${name} must be a UUID`);
  }
  return id;
}

function table(admin: AgentGpaDb, name: string): QueryLike {
  return admin.from(name) as QueryLike;
}

function tableQuery(admin: AgentGpaDb, name: string): QueryLike {
  return table(admin, name);
}

function optionalGpa(value: unknown, name: string): number | null {
  if (value == null || value === "") return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > 4) {
    throw new AgentGpaActionError(`${name} must be between 0 and 4`);
  }
  return score(parsed, 2);
}

function asNonEmptyString(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function optionalSourcePayload(value: unknown): Record<string, unknown> | null {
  return asRecord(value);
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function hasAnyKey(source: Record<string, unknown>, keys: string[]): boolean {
  return keys.some((key) => {
    const value = source[key];
    return Array.isArray(value) ? value.length > 0 : value != null &&
      String(value).trim() !== "";
  });
}

function compactText(value: unknown): string {
  try {
    return JSON.stringify(value).slice(0, 6000);
  } catch {
    return String(value);
  }
}

function buildRationale(
  sourceType: AgentGpaSourceType,
  scores: EvaluationScores,
  successLike: boolean,
  hasError: boolean,
): string {
  const weakest =
    Object.entries(scores).sort((a, b) => Number(a[1]) - Number(b[1]))[0]?.[0]
      .replace("_score", "") ?? "goal";
  const state = successLike
    ? "completed signal"
    : hasError
    ? "error signal"
    : "available trace signals";
  return `${sourceType} evaluated from ${state}; ${weakest} is the current lowest GPA axis.`;
}

function score(value: number, digits = 1): number {
  const factor = 10 ** digits;
  return Math.round(Math.min(4, Math.max(0, value)) * factor) / factor;
}

function isMissingRelation(
  error: { code?: string; message?: string },
): boolean {
  return error.code === "42P01" ||
    String(error.message ?? "").includes("does not exist");
}
