import {
  AGENT_GPA_SOURCE_TYPES,
  AgentGpaActionError,
  buildRuleBasedGpaEvaluation,
  normalizeSourceType,
} from "./agent_gpa.ts";

export type PromptTemplateDraft = {
  templateId?: string;
  title: string;
  roleSetting: string;
  contextInfo: string;
  deliverableDefinition: string;
  constraintsText: string;
  thinkingProcess: string;
};

export type GpaTraceInput = {
  sourceType: string;
  sourceId: string;
  goal: string;
  plan: string[];
  actions: string[];
  latencyMs: number;
  retryCount: number;
  outputChars: number;
  success: boolean;
  status: string;
  judgeModel?: string;
};

export type ScoredGpaTrace = {
  sourceType: string;
  sourceId: string;
  goalScore: number;
  planScore: number;
  actionScore: number;
  consistencyScore: number;
  efficiencyScore: number;
  gpa: number;
  rationaleShort: string;
  weakAxes: string[];
};

export type GpaBatchSummary = {
  sampleCount: number;
  meanGpa: number;
  meanConsistency: number;
  meanEfficiency: number;
  scoreVariance: number;
  scoreStddev: number;
  varianceThreshold: number;
  evolutionTriggered: boolean;
  scoredTraces: ScoredGpaTrace[];
};

export type ReflectionLesson = {
  axis: "goal" | "plan" | "action" | "consistency" | "efficiency";
  observedIssue: string;
  patchDirective: string;
};

export type EvolvedPromptCandidate = {
  candidateId: string;
  strategy:
    | "reflective_constraint_patch"
    | "stepwise_plan_enforcer"
    | "efficiency_compression";
  generation: number;
  parentTitle: string;
  draft: PromptTemplateDraft;
  fitnessScore: number;
  projectedGpa: number;
  projectedVarianceDrop: number;
  reflectionSummary: string;
  safetyValid: boolean;
  safetyIssues: string[];
};

export type PromptMutationBackend = {
  generateCandidates(params: {
    basePrompt: PromptTemplateDraft;
    lessons: ReflectionLesson[];
    batch: GpaBatchSummary;
    maxCandidates: number;
  }): Promise<EvolvedPromptCandidate[]>;
};

export type PromptEvolutionDb = {
  insertGpaEvaluation(row: Record<string, unknown>): Promise<string>;
  listRecentEvaluations(
    userId: string,
    limit: number,
  ): Promise<Array<Record<string, unknown>>>;
  insertPromptTemplateCandidate(
    userId: string,
    draft: PromptTemplateDraft,
  ): Promise<string | null>;
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const UNSAFE_PROMPT_PATTERNS: Array<{ code: string; pattern: RegExp }> = [
  {
    code: "system_prompt_leak_marker",
    pattern: new RegExp(
      "SYSTEM_PROMPT:|BEGIN_INTERNAL_INSTRUCTIONS|" +
        "DEVELOPER_POLICY_OVERRIDE",
      "i",
    ),
  },
  {
    code: "credential_literal_detected",
    pattern: new RegExp(
      "-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-[A-Za-z0-9]{20,}|sb_secret_",
      "i",
    ),
  },
  {
    code: "injection_bypass_directive",
    pattern: /ignore all previous instructions|bypass policy check/i,
  },
];

function roundScore(value: number, decimals = 2): number {
  const factor = 10 ** decimals;
  const clamped = Math.min(4, Math.max(0, value));
  return Math.round(clamped * factor) / factor;
}

function asTrimmed(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

function asNonNegativeNum(value: unknown, fallback: number): number {
  const num = Number(value);
  if (!Number.isFinite(num) || num < 0) return fallback;
  return num;
}

export function computeEfficiencyScore(params: {
  latencyMs: number;
  retryCount: number;
  actionCount: number;
  outputChars: number;
  success: boolean;
}): number {
  let score = 3.8;
  if (!params.success) {
    score -= 1.2;
  }
  score -= Math.min(1.6, params.retryCount * 0.45);
  if (params.latencyMs > 8000) {
    score -= 1.0;
  } else if (params.latencyMs > 4000) {
    score -= 0.4;
  }
  if (params.actionCount > 10) {
    score -= Math.min(0.8, (params.actionCount - 10) * 0.15);
  }
  if (params.outputChars > 12000) {
    score -= 0.3;
  }
  return roundScore(score, 1);
}

export function scoreSingleGpaTrace(input: GpaTraceInput): ScoredGpaTrace {
  const sourceType = normalizeSourceType(input.sourceType);
  if (!UUID_PATTERN.test(input.sourceId)) {
    throw new AgentGpaActionError(
      "source_id must be a valid UUID.",
      400,
    );
  }

  const baseEval = buildRuleBasedGpaEvaluation(sourceType, {
    goal: input.goal,
    plan: input.plan,
    actions: input.actions,
    status: input.status,
    success: input.success,
  });

  const efficiencyScore = computeEfficiencyScore({
    latencyMs: input.latencyMs,
    retryCount: input.retryCount,
    actionCount: input.actions.length,
    outputChars: input.outputChars,
    success: input.success,
  });

  const combinedGpa = roundScore(
    (baseEval.goal_score +
      baseEval.plan_score +
      baseEval.action_score +
      baseEval.consistency_score +
      efficiencyScore) / 5,
    2,
  );

  const weakAxes: string[] = [];
  if (baseEval.goal_score < 3.0) weakAxes.push("goal");
  if (baseEval.plan_score < 3.0) weakAxes.push("plan");
  if (baseEval.action_score < 3.0) weakAxes.push("action");
  if (baseEval.consistency_score < 3.0) weakAxes.push("consistency");
  if (efficiencyScore < 3.0) weakAxes.push("efficiency");

  const summary = `${baseEval.rationale_short} eff=${
    efficiencyScore.toFixed(1)
  }`.slice(
    0,
    500,
  );

  return {
    sourceType,
    sourceId: input.sourceId,
    goalScore: baseEval.goal_score,
    planScore: baseEval.plan_score,
    actionScore: baseEval.action_score,
    consistencyScore: baseEval.consistency_score,
    efficiencyScore,
    gpa: combinedGpa,
    rationaleShort: summary,
    weakAxes,
  };
}

export function summarizeGpaVariance(
  traces: ScoredGpaTrace[],
  varianceThreshold = 0.15,
): GpaBatchSummary {
  const count = traces.length;
  if (count === 0) {
    return {
      sampleCount: 0,
      meanGpa: 0,
      meanConsistency: 0,
      meanEfficiency: 0,
      scoreVariance: 0,
      scoreStddev: 0,
      varianceThreshold,
      evolutionTriggered: false,
      scoredTraces: [],
    };
  }

  const meanGpa = traces.reduce((acc, t) => acc + t.gpa, 0) / count;
  const meanConsistency =
    traces.reduce((acc, t) => acc + t.consistencyScore, 0) / count;
  const meanEfficiency = traces.reduce((acc, t) => acc + t.efficiencyScore, 0) /
    count;

  const variance = traces.reduce(
    (acc, t) => acc + (t.gpa - meanGpa) ** 2,
    0,
  ) / count;
  const roundedMean = Math.round(meanGpa * 1000) / 1000;
  const roundedVariance = Math.round(variance * 10000) / 10000;
  const roundedStddev = Math.round(Math.sqrt(variance) * 10000) / 10000;

  return {
    sampleCount: count,
    meanGpa: roundedMean,
    meanConsistency: Math.round(meanConsistency * 1000) / 1000,
    meanEfficiency: Math.round(meanEfficiency * 1000) / 1000,
    scoreVariance: roundedVariance,
    scoreStddev: roundedStddev,
    varianceThreshold,
    evolutionTriggered: count >= 2 && roundedVariance > varianceThreshold,
    scoredTraces: traces,
  };
}

export function extractReflectionLessons(
  batch: GpaBatchSummary,
): ReflectionLesson[] {
  const axisCounts: Record<
    "goal" | "plan" | "action" | "consistency" | "efficiency",
    number
  > = {
    goal: 0,
    plan: 0,
    action: 0,
    consistency: 0,
    efficiency: 0,
  };

  for (const trace of batch.scoredTraces) {
    for (const axis of trace.weakAxes) {
      if (axis in axisCounts) {
        axisCounts[axis as keyof typeof axisCounts] += 1;
      }
    }
  }

  const lessons: ReflectionLesson[] = [];
  if (axisCounts.goal > 0) {
    lessons.push({
      axis: "goal",
      observedIssue: `${axisCounts.goal} trace(s) drifted from primary goal.`,
      patchDirective:
        "Restate the single atomic goal and success criteria before acting.",
    });
  }
  if (axisCounts.plan > 0) {
    lessons.push({
      axis: "plan",
      observedIssue: `${axisCounts.plan} trace(s) lacked ordered planning.`,
      patchDirective:
        "Require an explicit numbered plan aligned with verified inputs.",
    });
  }
  if (axisCounts.action > 0) {
    lessons.push({
      axis: "action",
      observedIssue: `${axisCounts.action} trace(s) failed during execution.`,
      patchDirective:
        "Validate tool preconditions and fail closed before side effects.",
    });
  }
  if (
    axisCounts.consistency > 0 ||
    batch.scoreVariance > batch.varianceThreshold
  ) {
    lessons.push({
      axis: "consistency",
      observedIssue: `GPA variance (${batch.scoreVariance}) exceeded ` +
        `threshold (${batch.varianceThreshold}).`,
      patchDirective:
        "Enforce deterministic output schema and self-check constraints.",
    });
  }
  if (axisCounts.efficiency > 0 || batch.meanEfficiency < 3.2) {
    lessons.push({
      axis: "efficiency",
      observedIssue: `Efficiency average (${batch.meanEfficiency}) showed ` +
        "extra retries/latency.",
      patchDirective:
        "Limit redundant tool retries and converge in <= 3 bounded steps.",
    });
  }

  return lessons;
}

export function validateCandidateSafety(
  draft: PromptTemplateDraft,
): { valid: boolean; issues: string[] } {
  const issues: string[] = [];
  const fields: Array<[string, string, number]> = [
    ["title", draft.title, 120],
    ["role_setting", draft.roleSetting, 2000],
    ["context_info", draft.contextInfo, 4000],
    ["deliverable_definition", draft.deliverableDefinition, 4000],
    ["constraints_text", draft.constraintsText, 4000],
    ["thinking_process", draft.thinkingProcess, 4000],
  ];

  for (const [label, value, maxLen] of fields) {
    const trimmed = value.trim();
    if (!trimmed) {
      issues.push(`${label} must not be empty.`);
      continue;
    }
    if (trimmed.length > maxLen) {
      issues.push(`${label} exceeds max length (${maxLen}).`);
    }
    for (const check of UNSAFE_PROMPT_PATTERNS) {
      if (check.pattern.test(trimmed)) {
        issues.push(`${label} matched unsafe pattern (${check.code}).`);
      }
    }
  }

  return { valid: issues.length === 0, issues };
}

export function createDeterministicReflectiveMutator(): PromptMutationBackend {
  return {
    generateCandidates(params) {
      const { basePrompt, lessons, batch, maxCandidates } = params;
      const directives = lessons.map((l) => l.patchDirective);
      const summary = lessons.map((l) => l.observedIssue).join(" ") ||
        "Stabilize GPA consistency across varied inputs.";

      const strategies: Array<{
        strategy: EvolvedPromptCandidate["strategy"];
        build: () => PromptTemplateDraft;
        gpaBoost: number;
        varianceDrop: number;
      }> = [
        {
          strategy: "reflective_constraint_patch",
          gpaBoost: 0.42,
          varianceDrop: Math.min(batch.scoreVariance * 0.55, 0.4),
          build: () => ({
            title: `[GEPA Candidate] ${basePrompt.title}`.slice(0, 120),
            roleSetting: basePrompt.roleSetting,
            contextInfo: basePrompt.contextInfo,
            deliverableDefinition: `${basePrompt.deliverableDefinition}\n` +
              "- Verify goal-plan-action alignment explicitly.",
            constraintsText: `${basePrompt.constraintsText}\n- ${
              directives.join("\n- ")
            }`,
            thinkingProcess: `${basePrompt.thinkingProcess}\n` +
              "1. Check goal scope.\n2. Verify constraints before output.",
          }),
        },
        {
          strategy: "stepwise_plan_enforcer",
          gpaBoost: 0.36,
          varianceDrop: Math.min(batch.scoreVariance * 0.48, 0.35),
          build: () => ({
            title: `[GEPA Plan] ${basePrompt.title}`.slice(0, 120),
            roleSetting: basePrompt.roleSetting,
            contextInfo:
              `${basePrompt.contextInfo}\nInclude verified tool preconditions.`,
            deliverableDefinition: basePrompt.deliverableDefinition,
            constraintsText: `${basePrompt.constraintsText}\n` +
              "- Cite failing constraint before retrying.",
            thinkingProcess: "Step 1: State atomic goal.\n" +
              "Step 2: Emit ordered plan.\n" +
              `Step 3: Execute & audit.\n${basePrompt.thinkingProcess}`,
          }),
        },
        {
          strategy: "efficiency_compression",
          gpaBoost: 0.31,
          varianceDrop: Math.min(batch.scoreVariance * 0.42, 0.3),
          build: () => ({
            title: `[GEPA Compact] ${basePrompt.title}`.slice(0, 120),
            roleSetting: basePrompt.roleSetting,
            contextInfo: basePrompt.contextInfo,
            deliverableDefinition: `${basePrompt.deliverableDefinition}\n` +
              "Respond concisely in <= 3 bounded steps.",
            constraintsText: `${basePrompt.constraintsText}\n` +
              "- Never repeat failed tool invocations without state change.",
            thinkingProcess:
              "Minimize intermediate hops while keeping strict schema.\n" +
              basePrompt.thinkingProcess,
          }),
        },
      ];

      const candidates: EvolvedPromptCandidate[] = [];
      for (const [idx, item] of strategies.slice(0, maxCandidates).entries()) {
        const draft = item.build();
        const safety = validateCandidateSafety(draft);
        const projectedGpa = roundScore(batch.meanGpa + item.gpaBoost, 2);
        const projectedVarianceDrop = Math.round(item.varianceDrop * 1000) /
          1000;
        const fitnessScore = safety.valid
          ? Math.round(
            (projectedGpa * 0.65 + (projectedVarianceDrop * 2.5) * 0.35) * 1000,
          ) / 1000
          : 0;

        candidates.push({
          candidateId: `gepa-${idx + 1}-${item.strategy}`,
          strategy: item.strategy,
          generation: 1,
          parentTitle: basePrompt.title,
          draft,
          fitnessScore,
          projectedGpa,
          projectedVarianceDrop,
          reflectionSummary: summary.slice(0, 300),
          safetyValid: safety.valid,
          safetyIssues: safety.issues,
        });
      }

      candidates.sort((a, b) => b.fitnessScore - a.fitnessScore);
      return Promise.resolve(candidates);
    },
  };
}

function parseTraceInputs(rawTraces: unknown): GpaTraceInput[] {
  if (!Array.isArray(rawTraces) || rawTraces.length === 0) {
    throw new AgentGpaActionError("traces array must not be empty.", 400);
  }
  if (rawTraces.length > 50) {
    throw new AgentGpaActionError(
      "traces array must contain <= 50 items.",
      400,
    );
  }
  return rawTraces.map((entry, idx) => {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
      throw new AgentGpaActionError(`traces[${idx}] must be an object.`, 400);
    }
    const obj = entry as Record<string, unknown>;
    return {
      sourceType: asTrimmed(obj.source_type) || AGENT_GPA_SOURCE_TYPES[2],
      sourceId: asTrimmed(obj.source_id),
      goal: asTrimmed(obj.goal),
      plan: asStringArray(obj.plan),
      actions: asStringArray(obj.actions),
      latencyMs: asNonNegativeNum(obj.latency_ms, 1200),
      retryCount: Math.trunc(asNonNegativeNum(obj.retry_count, 0)),
      outputChars: Math.trunc(asNonNegativeNum(obj.output_chars, 500)),
      success: obj.success !== false,
      status: asTrimmed(obj.status) ||
        (obj.success === false ? "failed" : "completed"),
      judgeModel: asTrimmed(obj.judge_model) || "claude-sonnet-4-6",
    };
  });
}

function parsePromptDraft(raw: unknown): PromptTemplateDraft {
  const obj = raw && typeof raw === "object" && !Array.isArray(raw)
    ? raw as Record<string, unknown>
    : {};
  return {
    templateId: asTrimmed(obj.id) || undefined,
    title: asTrimmed(obj.title) || "Executive Agent Baseline Prompt",
    roleSetting: asTrimmed(obj.role_setting) ||
      "You are an autonomous execution planner focused on reliability.",
    contextInfo: asTrimmed(obj.context_info) ||
      "Use verified database state and workspace telemetry only.",
    deliverableDefinition: asTrimmed(obj.deliverable_definition) ||
      "Return an auditable Goal-Plan-Action summary with explicit checks.",
    constraintsText: asTrimmed(obj.constraints_text) ||
      "Fail closed on missing fields and avoid duplicate side effects.",
    thinkingProcess: asTrimmed(obj.thinking_process) ||
      "Decompose goal, verify preconditions, execute step-by-step.",
  };
}

export async function handlePromptEvolutionAction(params: {
  action: string;
  body: Record<string, unknown>;
  userId: string;
  db: PromptEvolutionDb;
  mutator?: PromptMutationBackend;
}): Promise<{ status: number; body: Record<string, unknown> }> {
  if (!params.userId) {
    return { status: 401, body: { success: false, error: "unauthorized" } };
  }
  const requestedUserId = asTrimmed(params.body.user_id);
  if (requestedUserId && requestedUserId !== params.userId) {
    return {
      status: 403,
      body: { success: false, error: "forbidden_user_mismatch" },
    };
  }

  const varianceThreshold = Math.min(
    2.0,
    Math.max(0.01, Number(params.body.variance_threshold ?? 0.15) || 0.15),
  );

  if (params.action === "agent.evaluate_gpa_batch") {
    const traceInputs = parseTraceInputs(params.body.traces);
    const scored = traceInputs.map((item) => scoreSingleGpaTrace(item));
    const batch = summarizeGpaVariance(scored, varianceThreshold);

    const savedIds: string[] = [];
    if (params.body.persist !== false) {
      for (const [idx, s] of scored.entries()) {
        const judge = traceInputs[idx]?.judgeModel ?? "claude-sonnet-4-6";
        const insertedId = await params.db.insertGpaEvaluation({
          user_id: params.userId,
          source_type: s.sourceType,
          source_id: s.sourceId,
          goal_score: s.goalScore,
          plan_score: s.planScore,
          action_score: s.actionScore,
          consistency_score: s.consistencyScore,
          judge_model: judge,
          rationale_short: s.rationaleShort,
          improvement_suggestions: s.weakAxes.map((axis) => ({
            type: axis === "efficiency" ? "rerun" : "prompt_edit",
            axis: axis === "efficiency" ? "consistency" : axis,
            suggestion: `Improve ${axis} alignment ` +
              `(eff=${s.efficiencyScore.toFixed(1)}).`,
          })),
        });
        savedIds.push(insertedId);
      }
    }

    return {
      status: 200,
      body: {
        success: true,
        batch,
        saved_evaluation_ids: savedIds,
      },
    };
  }

  if (params.action === "agent.evolve_prompts_from_gpa") {
    const scored = Array.isArray(params.body.traces)
      ? parseTraceInputs(params.body.traces).map((item) =>
        scoreSingleGpaTrace(item)
      )
      : (await params.db.listRecentEvaluations(params.userId, 20)).map(
        (row) => {
          const finiteScore = (value: unknown, fallback = 3): number => {
            if (value === null || value === undefined || value === "") {
              return fallback;
            }
            const parsed = Number(value);
            return Number.isFinite(parsed) ? parsed : fallback;
          };
          const goalScore = finiteScore(row.goal_score);
          const planScore = finiteScore(row.plan_score);
          const actionScore = finiteScore(row.action_score);
          const consistencyScore = finiteScore(row.consistency_score);
          const gpa = finiteScore(
            row.gpa,
            Number(
              ((goalScore + planScore + actionScore + consistencyScore) / 4)
                .toFixed(2),
            ),
          );
          return {
            sourceType: asTrimmed(row.source_type) || "secretary_action",
            sourceId: asTrimmed(row.source_id),
            goalScore,
            planScore,
            actionScore,
            consistencyScore,
            efficiencyScore: 3.2,
            gpa,
            rationaleShort: asTrimmed(row.rationale_short),
            weakAxes: gpa < 3.0 ? ["plan", "consistency"] : [],
          };
        },
      );

    const batch = summarizeGpaVariance(scored, varianceThreshold);
    const force = params.body.force === true;
    if (!batch.evolutionTriggered && !force) {
      return {
        status: 200,
        body: {
          success: true,
          evolution_triggered: false,
          saved_template_id: null,
          batch,
          lessons: [],
          candidates: [],
        },
      };
    }

    const basePrompt = parsePromptDraft(params.body.base_prompt);
    const lessons = extractReflectionLessons(batch);
    const mutator = params.mutator ?? createDeterministicReflectiveMutator();
    const candidates = await mutator.generateCandidates({
      basePrompt,
      lessons,
      batch,
      maxCandidates: 3,
    });

    const winner = candidates.find((c) => c.safetyValid);
    if (!winner) {
      return {
        status: 422,
        body: {
          success: false,
          error: "all_prompt_candidates_failed_safety",
          evolution_triggered: true,
          saved_template_id: null,
          batch,
          lessons,
          candidates,
        },
      };
    }

    let savedTemplateId: string | null = null;
    if (params.body.persist_candidate === true) {
      savedTemplateId = await params.db.insertPromptTemplateCandidate(
        params.userId,
        winner.draft,
      );
    }

    return {
      status: 200,
      body: {
        success: true,
        evolution_triggered: true,
        saved_template_id: savedTemplateId,
        batch,
        lessons,
        candidates,
      },
    };
  }

  if (params.action === "agent.list_prompt_evolutions") {
    const limit = Math.min(50, Math.max(1, Number(params.body.limit ?? 20)));
    const rows = await params.db.listRecentEvaluations(params.userId, limit);
    return {
      status: 200,
      body: {
        success: true,
        evaluations: rows,
        total_count: rows.length,
      },
    };
  }

  throw new AgentGpaActionError(
    `Unsupported prompt evolution action: ${params.action}`,
    400,
  );
}
