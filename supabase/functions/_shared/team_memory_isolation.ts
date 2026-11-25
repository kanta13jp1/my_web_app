import { MASK_PLACEHOLDER, maskLogString } from "./sensitive_log_masker.ts";

export type TeamMemoryScopeType = "agent" | "org" | "project";
export type TeamMemoryPatternType =
  | "anti_pattern"
  | "success_rule"
  | "guardrail"
  | "workflow_pattern";

export interface TeamMemoryScopeRef {
  scopeType: TeamMemoryScopeType;
  scopeId: string;
}

export interface RawLearningPatternInput {
  scopeType: TeamMemoryScopeType;
  scopeId: string;
  patternType: TeamMemoryPatternType;
  rawSummary: string;
  rawRule?: string;
}

export interface SanitizedLearningPattern {
  scopeType: TeamMemoryScopeType;
  scopeId: string;
  patternType: TeamMemoryPatternType;
  abstractRule: string;
  sanitizedSummary: string;
  redactionCount: number;
  isSanitized: true;
}

const PREFIXED_MARKER_RE = new RegExp(
  [
    "\\b(?:ghp|gho|ghu|ghs|ghr)" + "_[A-Za-z0-9]{10,}\\b",
    "\\bgithub_pat" + "_[A-Za-z0-9_]{10,}\\b",
    "\\bsk-" + "[A-Za-z0-9_-]{10,}\\b",
    "\\bxox[baprs]-" + "[A-Za-z0-9-]{10,}\\b",
    "\\bAIza" + "[0-9A-Za-z_-]{10,}\\b",
    "\\bsb_(?:secret|publishable)" + "_[A-Za-z0-9_-]{10,}\\b",
    "\\b(?:pk|rk)_(?:live|test)" + "_[A-Za-z0-9]{10,}\\b",
  ].join("|"),
  "g",
);

const CODE_FENCE_RE = /```[\s\S]*?```/g;
const INLINE_SQL_CODE_RE =
  /\b(?:SELECT|INSERT\s+INTO|UPDATE|DELETE\s+FROM|CREATE\s+TABLE|ALTER\s+TABLE)\b[^.;\n]{4,}[;\n]?/gi;
const WINDOWS_PATH_RE = /[A-Za-z]:\\(?:Users|tmp|home|var)\\[^\s"'`)]+/gi;
const UNIX_PATH_RE = /\/(?:Users|home|etc|var|root)\/[^\s"'`)]+/g;
const PRIVATE_IPV4_RE =
  /\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|127\.\d{1,3}\.\d{1,3}\.\d{1,3}|169\.254\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3})\b/g;
const UUID_RE =
  /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi;
const DART_OR_TS_SNIPPET_RE =
  /\b(?:import\s+['"][^'"]+['"];?|class\s+[A-Za-z0-9_]+\s*(?:extends|implements)\s+[A-Za-z0-9_]+|const\s+[A-Za-z0-9_]+\s*=\s*\{[^}]+\})/g;

const RESIDUAL_FORBIDDEN_RE =
  /```|ghp_|github_pat_|sk-[A-Za-z0-9_-]{8,}|xox[baprs]-|AIza[0-9A-Za-z_-]{8,}|sb_secret_|Bearer\s+[A-Za-z0-9._-]{8,}|eyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}/i;

function replaceAndCount(
  input: string,
  pattern: RegExp,
  replacement: string,
): { text: string; hits: number } {
  let hits = 0;
  const text = input.replace(pattern, () => {
    hits += 1;
    return replacement;
  });
  return { text, hits };
}

export function sanitizeTextForTeamMemory(raw: string): {
  text: string;
  redactionCount: number;
} {
  if (!raw.trim()) {
    return { text: "", redactionCount: 0 };
  }
  let totalHits = 0;

  let current = maskLogString(raw);
  if (current !== raw) {
    totalHits += 1;
  }

  for (const [pattern, replacement] of [
    [PREFIXED_MARKER_RE, MASK_PLACEHOLDER],
    [CODE_FENCE_RE, "[abstracted_code_block]"],
    [DART_OR_TS_SNIPPET_RE, "[abstracted_snippet]"],
    [INLINE_SQL_CODE_RE, "[abstracted_query]"],
    [WINDOWS_PATH_RE, "[local_path]"],
    [UNIX_PATH_RE, "[local_path]"],
    [PRIVATE_IPV4_RE, "[internal_ip]"],
    [UUID_RE, "[scoped_id]"],
  ] as const) {
    const step = replaceAndCount(current, pattern, replacement);
    current = step.text;
    totalHits += step.hits;
  }

  const normalized = current.replace(/\s+/g, " ").trim();
  return { text: normalized, redactionCount: totalHits };
}

export function detectResidualSensitiveMaterial(text: string): string | null {
  const match = text.match(RESIDUAL_FORBIDDEN_RE);
  return match ? match[0] : null;
}

export function sanitizeLearningPattern(
  input: RawLearningPatternInput,
): SanitizedLearningPattern {
  const scopeId = input.scopeId.trim();
  if (!/^[a-zA-Z0-9_.:-]{2,120}$/.test(scopeId)) {
    throw new Error(`Invalid team memory scopeId: ${input.scopeId}`);
  }

  const summaryPass = sanitizeTextForTeamMemory(input.rawSummary);
  const ruleSource = (input.rawRule ?? input.rawSummary).trim();
  const rulePass = sanitizeTextForTeamMemory(ruleSource);

  if (summaryPass.text.length < 10 || rulePass.text.length < 10) {
    throw new Error("Sanitized abstract rule and summary must be at least 10 characters");
  }

  const residualSummary = detectResidualSensitiveMaterial(summaryPass.text);
  const residualRule = detectResidualSensitiveMaterial(rulePass.text);
  if (residualSummary !== null || residualRule !== null) {
    throw new Error("Residual sensitive marker remained after sanitization");
  }

  return {
    scopeType: input.scopeType,
    scopeId,
    patternType: input.patternType,
    abstractRule: rulePass.text.slice(0, 1000),
    sanitizedSummary: summaryPass.text.slice(0, 2000),
    redactionCount: summaryPass.redactionCount + rulePass.redactionCount,
    isSanitized: true,
  };
}

export async function abstractAndSanitizePattern(
  input: RawLearningPatternInput,
  abstractor?: (sanitizedText: string) => Promise<string> | string,
): Promise<SanitizedLearningPattern> {
  const preSanitized = sanitizeLearningPattern(input);
  if (!abstractor) {
    return preSanitized;
  }
  const abstractedRule = await abstractor(preSanitized.abstractRule);
  const postSanitized = sanitizeLearningPattern({
    ...input,
    rawRule: abstractedRule,
    rawSummary: preSanitized.sanitizedSummary,
  });
  return {
    ...postSanitized,
    redactionCount: preSanitized.redactionCount + postSanitized.redactionCount,
  };
}

export function isScopeAuthorized(
  authorizedScopes: readonly TeamMemoryScopeRef[],
  targetScope: TeamMemoryScopeRef,
): boolean {
  return authorizedScopes.some(
    (scope) =>
      scope.scopeType === targetScope.scopeType &&
      scope.scopeId === targetScope.scopeId,
  );
}

export function filterPatternsForScope(
  patterns: readonly SanitizedLearningPattern[],
  authorizedScopes: readonly TeamMemoryScopeRef[],
  requestedScope: TeamMemoryScopeRef,
): SanitizedLearningPattern[] {
  if (!isScopeAuthorized(authorizedScopes, requestedScope)) {
    return [];
  }
  return patterns.filter(
    (pattern) =>
      pattern.scopeType === requestedScope.scopeType &&
      pattern.scopeId === requestedScope.scopeId &&
      pattern.isSanitized === true,
  );
}
