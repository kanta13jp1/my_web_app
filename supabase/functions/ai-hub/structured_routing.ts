export function stripJsonMarkdownFence(raw: string): string {
  const trimmed = raw.trim();
  const match = trimmed.match(/^```(?:json|JSON)?\s*\r?\n([\s\S]*?)\r?\n```$/);
  if (match) {
    return match[1].trim();
  }
  return trimmed;
}

export type LlmRoutingTier = "trivial" | "standard" | "complex" | "critical";
export type LlmEffortLevel = "low" | "medium" | "high" | "xhigh";
export type LlmModelClass = "lightweight" | "balanced" | "advanced";

export type LlmRoutingTierRule = {
  tier: LlmRoutingTier;
  effort: LlmEffortLevel;
  modelClass: LlmModelClass;
  provider: string;
  model: string;
  fallbackChain: string[];
  outputLimit: number;
  description: string;
};

export const ROUTING_TIER_RULES: Record<LlmRoutingTier, LlmRoutingTierRule> = {
  trivial: {
    tier: "trivial",
    effort: "low",
    modelClass: "lightweight",
    provider: "google_flash_lite",
    model: "gemini-2.5-flash-lite",
    fallbackChain: ["google", "groq", "anthropic"],
    outputLimit: 1024,
    description:
      "Fast lightweight model for classification, tagging, and JSON parsing.",
  },
  standard: {
    tier: "standard",
    effort: "medium",
    modelClass: "balanced",
    provider: "openai",
    model: "gpt-5.4-mini",
    fallbackChain: ["google", "anthropic", "groq"],
    outputLimit: 2048,
    description:
      "Balanced model for summaries, translations, and general QA.",
  },
  complex: {
    tier: "complex",
    effort: "high",
    modelClass: "advanced",
    provider: "anthropic",
    model: "claude-sonnet-4-6",
    fallbackChain: ["google", "openai"],
    outputLimit: 4096,
    description:
      "Advanced reasoning model for deep analysis, planning, and code review.",
  },
  critical: {
    tier: "critical",
    effort: "xhigh",
    modelClass: "advanced",
    provider: "anthropic",
    model: "claude-opus-4-7",
    fallbackChain: ["openai", "google"],
    outputLimit: 8192,
    description:
      "Highest-capability model for security audits and architecture review.",
  },
};

const TRIVIAL_TASK_TYPES = new Set([
  "classification",
  "tagging",
  "formatting",
  "extraction",
  "routing",
  "triage",
  "labeling",
  "sentiment",
]);

const STANDARD_TASK_TYPES = new Set([
  "summary",
  "translation",
  "drafting",
  "qa",
  "email_reply",
  "daily_briefing",
  "writing",
  "chat",
]);

const COMPLEX_TASK_TYPES = new Set([
  "analysis",
  "code_review",
  "coding",
  "reasoning",
  "planning",
  "multi_step_synthesis",
  "refactor",
]);

const CRITICAL_TASK_TYPES = new Set([
  "security_audit",
  "architecture",
  "incident_root_cause",
  "compliance_review",
  "financial_audit",
]);

const CRITICAL_KEYWORDS = [
  "security audit",
  "vulnerability",
  "architecture",
  "root cause",
  "compliance",
  "migration",
  "セキュリティ監査",
  "脆弱性",
  "アーキテクチャ",
  "根本原因",
];

const COMPLEX_KEYWORDS = [
  "analyze",
  "code review",
  "refactor",
  "reasoning",
  "multi-step",
  "tradeoff",
  "分析",
  "設計",
  "コードレビュー",
  "比較検討",
];

const TRIVIAL_KEYWORDS = [
  "classify",
  "tag",
  "label",
  "extract",
  "format",
  "triage",
  "分類",
  "タグ付け",
  "抽出",
  "整形",
];

export type SavedRoutingPreference = {
  task: string;
  provider: string;
  model: string | null;
  is_enabled: boolean;
  source: string;
  updated_at?: string;
};

export type LlmRouteDecisionInput = {
  taskType?: string;
  prompt?: string;
  promptLength?: number;
  requiresReasoning?: boolean;
  preferredTier?: string;
  hasResponseSchema?: boolean;
  schemaComplexityScore?: number;
  savedPreference?: SavedRoutingPreference | null;
};

export type LlmRouteDecision = {
  taskType: string;
  tier: LlmRoutingTier;
  effort: LlmEffortLevel;
  modelClass: LlmModelClass;
  provider: string;
  model: string;
  fallbackChain: string[];
  recommendedOutputLimit: number;
  reason: string;
  preferenceApplied: boolean;
  recommendedTier: LlmRoutingTier;
  recommendedProvider: string;
  recommendedModel: string;
};

export type JsonSchemaValidationIssue = {
  path: string;
  message: string;
};

export type StructuredValidationResult = {
  valid: boolean;
  parsed: unknown;
  issues: JsonSchemaValidationIssue[];
  normalizedJson: string | null;
};

export type StructuredRoutingStore = {
  getTaskPreference(
    userId: string,
    task: string,
  ): Promise<SavedRoutingPreference | null>;
  listTaskPreferences(userId: string): Promise<SavedRoutingPreference[]>;
  upsertTaskPreference(params: {
    userId: string;
    task: string;
    provider: string;
    model: string;
    source: "manual" | "recommendation";
  }): Promise<SavedRoutingPreference>;
};

export type StructuredRoutingActionInput = {
  action: string;
  body: Record<string, unknown>;
  userId: string | null;
  isElevatedAutomation: boolean;
  store: StructuredRoutingStore;
};

export type StructuredRoutingActionResult = {
  status: number;
  body: Record<string, unknown>;
};

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function asTrimmedString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeTaskType(value?: string): string {
  const normalized = asTrimmedString(value).toLowerCase().replace(/\s+/g, "_");
  return normalized.slice(0, 120) || "classification";
}

function normalizeTier(value?: string): LlmRoutingTier | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (
    normalized === "trivial" ||
    normalized === "standard" ||
    normalized === "complex" ||
    normalized === "critical"
  ) {
    return normalized;
  }
  return null;
}

export function computeSchemaComplexityScore(
  schema: unknown,
  depth = 0,
): number {
  if (!isPlainObject(schema) || depth > 8) {
    return 0;
  }
  let score = 0;
  const props = schema.properties;
  if (isPlainObject(props)) {
    const entries = Object.values(props);
    score += entries.length;
    for (const child of entries) {
      score += computeSchemaComplexityScore(child, depth + 1);
    }
  }
  if (schema.items != null) {
    score += 1 + computeSchemaComplexityScore(schema.items, depth + 1);
  }
  if (Array.isArray(schema.anyOf)) {
    score += schema.anyOf.length;
    for (const variant of schema.anyOf) {
      score += computeSchemaComplexityScore(variant, depth + 1);
    }
  }
  return score;
}

export function routeLlmTaskByComplexity(
  input: LlmRouteDecisionInput,
): LlmRouteDecision {
  const taskType = normalizeTaskType(input.taskType);
  const promptText = asTrimmedString(input.prompt).toLowerCase();
  const effectiveLength = Math.max(
    promptText.length,
    typeof input.promptLength === "number" &&
      Number.isFinite(input.promptLength)
      ? Math.max(0, Math.floor(input.promptLength))
      : 0,
  );
  const explicitTier = normalizeTier(input.preferredTier);
  const schemaScore = input.schemaComplexityScore ?? 0;

  let tier: LlmRoutingTier = "standard";
  let reason = "Default balanced tier for general structured tasks.";

  if (explicitTier != null) {
    tier = explicitTier;
    reason = `Explicitly requested ${explicitTier} tier.`;
  } else if (
    CRITICAL_TASK_TYPES.has(taskType) ||
    CRITICAL_KEYWORDS.some((kw) => promptText.includes(kw))
  ) {
    tier = "critical";
    reason =
      "High-stakes audit or architecture task routed to critical tier.";
  } else if (
    COMPLEX_TASK_TYPES.has(taskType) ||
    input.requiresReasoning === true ||
    COMPLEX_KEYWORDS.some((kw) => promptText.includes(kw)) ||
    effectiveLength > 4000 ||
    schemaScore >= 14
  ) {
    tier = "complex";
    reason =
      "Reasoning, long context, or complex schema routed to advanced tier.";
  } else if (
    TRIVIAL_TASK_TYPES.has(taskType) ||
    (TRIVIAL_KEYWORDS.some((kw) => promptText.includes(kw)) &&
      effectiveLength <= 1500 &&
      schemaScore < 8)
  ) {
    tier = "trivial";
    reason =
      "Lightweight classification or tagging routed to fast low-cost tier.";
  } else if (STANDARD_TASK_TYPES.has(taskType)) {
    tier = "standard";
    reason = "Standard text transformation task routed to balanced tier.";
  }

  const rule = ROUTING_TIER_RULES[tier];
  const saved = input.savedPreference;
  if (saved != null && saved.is_enabled && saved.source === "manual") {
    const manualModel = saved.model?.trim() || rule.model;
    return {
      taskType,
      tier,
      effort: rule.effort,
      modelClass: rule.modelClass,
      provider: saved.provider,
      model: manualModel,
      fallbackChain: rule.fallbackChain.filter((p) => p !== saved.provider),
      recommendedOutputLimit: rule.outputLimit,
      reason: `${reason} Overridden by saved manual task preference.`,
      preferenceApplied: true,
      recommendedTier: rule.tier,
      recommendedProvider: rule.provider,
      recommendedModel: rule.model,
    };
  }

  return {
    taskType,
    tier,
    effort: rule.effort,
    modelClass: rule.modelClass,
    provider: rule.provider,
    model: rule.model,
    fallbackChain: [...rule.fallbackChain],
    recommendedOutputLimit: rule.outputLimit,
    reason,
    preferenceApplied: false,
    recommendedTier: rule.tier,
    recommendedProvider: rule.provider,
    recommendedModel: rule.model,
  };
}

function deepEquals(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  return JSON.stringify(a) === JSON.stringify(b);
}

function matchesSchemaType(value: unknown, expectedType: string): boolean {
  switch (expectedType) {
    case "object":
      return isPlainObject(value);
    case "array":
      return Array.isArray(value);
    case "string":
      return typeof value === "string";
    case "number":
      return typeof value === "number" && Number.isFinite(value);
    case "integer":
      return typeof value === "number" && Number.isInteger(value);
    case "boolean":
      return typeof value === "boolean";
    case "null":
      return value === null;
    default:
      return true;
  }
}

function validateSchemaNode(
  value: unknown,
  schema: Record<string, unknown>,
  path: string,
  issues: JsonSchemaValidationIssue[],
  depth: number,
): void {
  if (depth > 16) {
    issues.push({
      path,
      message: "Maximum JSON schema validation depth exceeded.",
    });
    return;
  }

  if (Array.isArray(schema.anyOf) && schema.anyOf.length > 0) {
    let anyMatched = false;
    for (const candidate of schema.anyOf) {
      if (!isPlainObject(candidate)) continue;
      const candidateIssues: JsonSchemaValidationIssue[] = [];
      validateSchemaNode(value, candidate, path, candidateIssues, depth + 1);
      if (candidateIssues.length === 0) {
        anyMatched = true;
        break;
      }
    }
    if (!anyMatched) {
      issues.push({
        path,
        message: "Value does not match any allowed anyOf schema.",
      });
    }
    return;
  }

  if (Array.isArray(schema.enum)) {
    const matched = schema.enum.some((entry) => deepEquals(entry, value));
    if (!matched) {
      issues.push({
        path,
        message: `Value must be one of: ${JSON.stringify(schema.enum)}.`,
      });
      return;
    }
  }

  const rawType = schema.type;
  if (typeof rawType === "string") {
    if (!matchesSchemaType(value, rawType)) {
      issues.push({
        path,
        message: `Expected type '${rawType}'.`,
      });
      return;
    }
  } else if (Array.isArray(rawType)) {
    const allowed = rawType.filter((t): t is string => typeof t === "string");
    if (
      allowed.length > 0 &&
      !allowed.some((candidate) => matchesSchemaType(value, candidate))
    ) {
      issues.push({
        path,
        message: `Expected one of types [${allowed.join(", ")}].`,
      });
      return;
    }
  }

  if (typeof value === "string") {
    if (
      typeof schema.minLength === "number" &&
      value.length < schema.minLength
    ) {
      issues.push({
        path,
        message: `String length must be >= ${schema.minLength}.`,
      });
    }
    if (
      typeof schema.maxLength === "number" &&
      value.length > schema.maxLength
    ) {
      issues.push({
        path,
        message: `String length must be <= ${schema.maxLength}.`,
      });
    }
    if (typeof schema.pattern === "string" && schema.pattern.length <= 256) {
      try {
        const regex = new RegExp(schema.pattern);
        if (!regex.test(value)) {
          issues.push({
            path,
            message: `String does not match pattern '${schema.pattern}'.`,
          });
        }
      } catch {
        issues.push({
          path,
          message: "Schema contains an invalid regular expression pattern.",
        });
      }
    }
    return;
  }

  if (typeof value === "number") {
    if (typeof schema.minimum === "number" && value < schema.minimum) {
      issues.push({
        path,
        message: `Number must be >= ${schema.minimum}.`,
      });
    }
    if (typeof schema.maximum === "number" && value > schema.maximum) {
      issues.push({
        path,
        message: `Number must be <= ${schema.maximum}.`,
      });
    }
    return;
  }

  if (Array.isArray(value)) {
    if (typeof schema.minItems === "number" && value.length < schema.minItems) {
      issues.push({
        path,
        message: `Array must contain at least ${schema.minItems} item(s).`,
      });
    }
    if (typeof schema.maxItems === "number" && value.length > schema.maxItems) {
      issues.push({
        path,
        message: `Array must contain at most ${schema.maxItems} item(s).`,
      });
    }
    if (isPlainObject(schema.items)) {
      for (let i = 0; i < value.length; i += 1) {
        validateSchemaNode(
          value[i],
          schema.items,
          `${path}[${i}]`,
          issues,
          depth + 1,
        );
      }
    }
    return;
  }

  if (isPlainObject(value)) {
    const props = isPlainObject(schema.properties) ? schema.properties : {};
    if (Array.isArray(schema.required)) {
      for (const reqKey of schema.required) {
        if (typeof reqKey !== "string") continue;
        if (
          !Object.prototype.hasOwnProperty.call(value, reqKey) ||
          value[reqKey] === undefined
        ) {
          issues.push({
            path: path === "$" ? `$.${reqKey}` : `${path}.${reqKey}`,
            message: `Missing required property '${reqKey}'.`,
          });
        }
      }
    }

    if (schema.additionalProperties === false) {
      for (const actualKey of Object.keys(value)) {
        if (!Object.prototype.hasOwnProperty.call(props, actualKey)) {
          issues.push({
            path: path === "$" ? `$.${actualKey}` : `${path}.${actualKey}`,
            message: `Unexpected property '${actualKey}' is not allowed.`,
          });
        }
      }
    }

    for (const [propKey, propSchema] of Object.entries(props)) {
      if (!isPlainObject(propSchema)) continue;
      if (!Object.prototype.hasOwnProperty.call(value, propKey)) continue;
      if (value[propKey] === undefined) continue;
      validateSchemaNode(
        value[propKey],
        propSchema,
        path === "$" ? `$.${propKey}` : `${path}.${propKey}`,
        issues,
        depth + 1,
      );
    }
  }
}

export function validateAgainstJsonSchema(
  rawOutput: unknown,
  schema?: Record<string, unknown>,
): StructuredValidationResult {
  let parsed: unknown = null;
  if (typeof rawOutput === "string") {
    const cleaned = stripJsonMarkdownFence(rawOutput);
    if (!cleaned) {
      return {
        valid: false,
        parsed: null,
        issues: [{ path: "$", message: "Structured JSON output is empty." }],
        normalizedJson: null,
      };
    }
    try {
      parsed = JSON.parse(cleaned);
    } catch (error) {
      return {
        valid: false,
        parsed: null,
        issues: [{
          path: "$",
          message: `Invalid JSON syntax: ${String(error)}`,
        }],
        normalizedJson: null,
      };
    }
  } else if (rawOutput !== undefined) {
    parsed = rawOutput;
  } else {
    return {
      valid: false,
      parsed: null,
      issues: [{ path: "$", message: "raw_output is required." }],
      normalizedJson: null,
    };
  }

  const issues: JsonSchemaValidationIssue[] = [];
  if (schema != null && Object.keys(schema).length > 0) {
    validateSchemaNode(parsed, schema, "$", issues, 0);
  }

  if (issues.length > 0) {
    return {
      valid: false,
      parsed,
      issues,
      normalizedJson: null,
    };
  }

  return {
    valid: true,
    parsed,
    issues: [],
    normalizedJson: JSON.stringify(parsed),
  };
}

function resolveTargetUserId(
  authenticatedUserId: string | null,
  requestedUserId: unknown,
  isElevatedAutomation: boolean,
): { ok: true; userId: string | null } | {
  ok: false;
  status: number;
  error: string;
} {
  const requested = asTrimmedString(requestedUserId);
  if (requested) {
    if (authenticatedUserId && requested !== authenticatedUserId) {
      return {
        ok: false,
        status: 403,
        error: "forbidden_user_mismatch",
      };
    }
    if (!authenticatedUserId && !isElevatedAutomation) {
      return {
        ok: false,
        status: 401,
        error: "unauthorized",
      };
    }
    return { ok: true, userId: requested };
  }
  return { ok: true, userId: authenticatedUserId };
}

export async function handleStructuredRoutingAction(
  input: StructuredRoutingActionInput,
): Promise<StructuredRoutingActionResult> {
  if (!input.userId && !input.isElevatedAutomation) {
    return {
      status: 401,
      body: { success: false, error: "unauthorized" },
    };
  }

  const userResolution = resolveTargetUserId(
    input.userId,
    input.body.user_id,
    input.isElevatedAutomation,
  );
  if (!userResolution.ok) {
    return {
      status: userResolution.status,
      body: { success: false, error: userResolution.error },
    };
  }
  const targetUserId = userResolution.userId;

  const taskType = normalizeTaskType(
    asTrimmedString(input.body.task_type) || asTrimmedString(input.body.task),
  );
  const responseSchema = isPlainObject(input.body.response_schema)
    ? input.body.response_schema
    : undefined;
  const schemaScore = responseSchema != null
    ? computeSchemaComplexityScore(responseSchema)
    : 0;

  if (input.action === "ai_router.structured.route") {
    const saved = targetUserId != null
      ? await input.store.getTaskPreference(targetUserId, taskType)
      : null;
    const prompt = asTrimmedString(input.body.prompt) ||
      asTrimmedString(input.body.user_prompt);
    const route = routeLlmTaskByComplexity({
      taskType,
      prompt,
      promptLength: typeof input.body.prompt_length === "number"
        ? input.body.prompt_length
        : undefined,
      requiresReasoning: input.body.requires_reasoning === true,
      preferredTier: asTrimmedString(input.body.preferred_tier) || undefined,
      hasResponseSchema: responseSchema != null,
      schemaComplexityScore: schemaScore,
      savedPreference: saved,
    });
    return {
      status: 200,
      body: {
        success: true,
        route,
        preference: saved,
        available_tiers: Object.values(ROUTING_TIER_RULES),
      },
    };
  }

  if (input.action === "ai_router.structured.validate_and_save") {
    const rawOutput = input.body.raw_output ?? input.body.payload;
    const validation = validateAgainstJsonSchema(rawOutput, responseSchema);
    const saved = targetUserId != null
      ? await input.store.getTaskPreference(targetUserId, taskType)
      : null;
    const route = routeLlmTaskByComplexity({
      taskType,
      prompt: asTrimmedString(input.body.prompt) ||
        asTrimmedString(input.body.user_prompt),
      requiresReasoning: input.body.requires_reasoning === true,
      preferredTier: asTrimmedString(input.body.preferred_tier) || undefined,
      hasResponseSchema: responseSchema != null,
      schemaComplexityScore: schemaScore,
      savedPreference: saved,
    });

    if (!validation.valid) {
      return {
        status: 422,
        body: {
          success: false,
          saved: false,
          error: "structured_output_validation_failed",
          validation,
          route,
        },
      };
    }

    const shouldPersist = input.body.persist_preference !== false;
    if (shouldPersist && targetUserId != null) {
      const requestedSource = asTrimmedString(input.body.source);
      const source = requestedSource === "manual"
        ? "manual"
        : "recommendation";
      const persisted = await input.store.upsertTaskPreference({
        userId: targetUserId,
        task: taskType,
        provider: route.provider,
        model: route.model,
        source,
      });
      return {
        status: 200,
        body: {
          success: true,
          saved: true,
          validation,
          route,
          preference: persisted,
        },
      };
    }

    return {
      status: 200,
      body: {
        success: true,
        saved: false,
        validation,
        route,
        preference: saved,
      },
    };
  }

  if (input.action === "ai_router.structured.list_preferences") {
    const preferences = targetUserId != null
      ? await input.store.listTaskPreferences(targetUserId)
      : [];
    return {
      status: 200,
      body: {
        success: true,
        preferences,
        routing_rules: ROUTING_TIER_RULES,
      },
    };
  }

  return {
    status: 400,
    body: {
      success: false,
      error: `unsupported_structured_routing_action:${input.action}`,
    },
  };
}

export function extractStructuredOutputOptions(
  body: Record<string, unknown>,
): {
  responseMimeType?: string;
  responseSchema?: Record<string, unknown>;
  schemaName?: string;
} {
  const responseSchema = isPlainObject(body.response_schema)
    ? body.response_schema
    : undefined;
  const responseMimeType = asTrimmedString(body.response_mime_type) ||
    (responseSchema != null ? "application/json" : undefined);
  const schemaName = asTrimmedString(body.schema_name) || undefined;
  return {
    responseMimeType,
    responseSchema,
    schemaName,
  };
}
