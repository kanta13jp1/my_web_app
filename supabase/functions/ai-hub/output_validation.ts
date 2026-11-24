import { maskLogString } from "../_shared/sensitive_log_masker.ts";
import { evaluateComplianceGuardrail } from "./compliance_guardrails.ts";

export type ValidationDecision = "passed" | "remediated" | "blocked";
export type OutputFormatContract =
  | "markdown_sections"
  | "json_object"
  | "concise_summary"
  | "plain_text";
export type ViolationSeverity = "warning" | "remediate" | "block";

export interface OutputValidationViolation {
  code: string;
  severity: ViolationSeverity;
  message: string;
}

export interface OutputValidationOptions {
  ruleSetVersion?: string;
  formatContract?: OutputFormatContract;
  requiredHeadings?: readonly string[];
  requiredFields?: readonly string[];
  bannedTerms?: readonly string[];
  maxLength?: number;
}

export interface OutputValidationResult {
  ruleSetVersion: string;
  decision: ValidationDecision;
  formatContract: OutputFormatContract;
  allowed: boolean;
  remediatedOutput: string;
  violations: OutputValidationViolation[];
  violationCount: number;
  driftScore: number;
  reasonMessage: string;
}

export interface ValidationAuditLogEntry {
  rule_set_version: string;
  decision: ValidationDecision;
  format_contract: OutputFormatContract;
  prompt_excerpt: string;
  original_output_excerpt: string;
  remediated_output_excerpt: string;
  violations: OutputValidationViolation[];
  violation_count: number;
  drift_score: number;
}

interface BannedRule {
  pattern: RegExp;
  code: string;
  severity: ViolationSeverity;
  message: string;
}

export const DEFAULT_RULE_SET_VERSION = "v1.0";

const HARD_BLOCK_RULES: readonly BannedRule[] = [
  {
    pattern: /(?:SYSTEM_PROMPT:|BEGIN_INTERNAL_INSTRUCTIONS|DEVELOPER_POLICY_OVERRIDE)/i,
    code: "system_prompt_leak_marker",
    severity: "block",
    message: "内部システムプロンプト露出マーカーを検出したため出力をブロックしました。",
  },
  {
    pattern: /(?:100%\s*guaranteed\s*(?:profit|return)|確実に儲かる|元本保証で必ず増える|絶対に副作用はありません|医学的診断を確定します)/i,
    code: "ungrounded_absolute_guarantee",
    severity: "block",
    message: "根拠のない断定的保証表現（創発的過剰確信）を検出したため出力をブロックしました。",
  },
];

const REMEDIABLE_PHRASE_RULES: readonly BannedRule[] = [
  {
    pattern: /\b(?:TODO_PLACEHOLDER|FIXME_OUTPUT|LOREM_IPSUM_PLACEHOLDER)\b/gi,
    code: "degenerate_placeholder_token",
    severity: "remediate",
    message: "未完成プレースホルダートークンを決定的に除去しました。",
  },
];

const DEFAULT_MARKDOWN_HEADINGS: readonly string[] = ["## 結論", "## 根拠"];

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function stripMarkdownCodeFence(text: string): {
  stripped: string;
  changed: boolean;
} {
  const trimmed = text.trim();
  const match = trimmed.match(/^```(?:json|JSON)?\s*\n([\s\S]*?)\n```$/);
  if (!match) {
    return { stripped: trimmed, changed: false };
  }
  return { stripped: match[1].trim(), changed: true };
}

function truncateExcerpt(text: string, maxChars: number): string {
  const masked = maskLogString(text).trim();
  if (masked.length <= maxChars) {
    return masked;
  }
  if (maxChars <= 3) {
    return masked.slice(0, maxChars);
  }
  return `${masked.slice(0, maxChars - 3)}...`;
}

function computeDriftScore(
  violations: readonly OutputValidationViolation[],
): number {
  let score = 0;
  for (const item of violations) {
    if (item.severity === "block") {
      score += 0.5;
    } else if (item.severity === "remediate") {
      score += 0.2;
    } else {
      score += 0.05;
    }
  }
  const bounded = Math.min(1, Math.max(0, score));
  return Math.round(bounded * 10000) / 10000;
}

export function validateAiOutput(
  rawOutput: string,
  options: OutputValidationOptions = {},
): OutputValidationResult {
  const ruleSetVersion = (options.ruleSetVersion ?? DEFAULT_RULE_SET_VERSION).trim() ||
    DEFAULT_RULE_SET_VERSION;
  const formatContract: OutputFormatContract =
    options.formatContract ?? "markdown_sections";
  const violations: OutputValidationViolation[] = [];

  let working = String(rawOutput ?? "").trim();
  if (working.length === 0) {
    violations.push({
      code: "empty_output",
      severity: "block",
      message: "AI出力が空のためブロックしました。",
    });
    return {
      ruleSetVersion,
      decision: "blocked",
      formatContract,
      allowed: false,
      remediatedOutput: "",
      violations,
      violationCount: violations.length,
      driftScore: computeDriftScore(violations),
      reasonMessage: violations[0].message,
    };
  }

  // Delegate PII / secret / toxic checks to existing compliance_guardrails (#2736)
  const compliance = evaluateComplianceGuardrail(working, { stage: "output" });
  if (!compliance.allowed) {
    for (const cat of compliance.categories) {
      violations.push({
        code: `compliance_${cat}`,
        severity: "block",
        message: compliance.reasonMessage,
      });
    }
  } else if (compliance.action === "masked") {
    working = compliance.sanitizedText;
    violations.push({
      code: "compliance_pii_masked",
      severity: "remediate",
      message: "連絡先等の機微情報を自動マスクしました。",
    });
  }

  for (const rule of HARD_BLOCK_RULES) {
    if (rule.pattern.test(working)) {
      violations.push({
        code: rule.code,
        severity: rule.severity,
        message: rule.message,
      });
    }
  }

  for (const rule of REMEDIABLE_PHRASE_RULES) {
    if (rule.pattern.test(working)) {
      working = working.replace(rule.pattern, "[REMOVED]").trim();
      violations.push({
        code: rule.code,
        severity: rule.severity,
        message: rule.message,
      });
    }
  }

  if (options.bannedTerms && options.bannedTerms.length > 0) {
    for (const term of options.bannedTerms) {
      const normalized = term.trim();
      if (normalized.length === 0) continue;
      const re = new RegExp(escapeRegExp(normalized), "gi");
      if (re.test(working)) {
        working = working.replace(re, "[REMOVED]").trim();
        violations.push({
          code: "custom_banned_term_remediated",
          severity: "remediate",
          message: `禁止語句を自動除去しました (${normalized.slice(0, 24)})。`,
        });
      }
    }
  }

  if (formatContract === "json_object") {
    const unfenced = stripMarkdownCodeFence(working);
    if (unfenced.changed) {
      working = unfenced.stripped;
      violations.push({
        code: "json_code_fence_stripped",
        severity: "remediate",
        message: "JSON出力周囲のMarkdownコードフェンスを除去しました。",
      });
    }
    try {
      const parsed: unknown = JSON.parse(working);
      if (
        parsed === null || typeof parsed !== "object" || Array.isArray(parsed)
      ) {
        violations.push({
          code: "invalid_json_object_type",
          severity: "block",
          message: "JSON出力はトップレベルオブジェクトである必要があります。",
        });
      } else {
        const record = parsed as Record<string, unknown>;
        const requiredFields = options.requiredFields ?? [];
        for (const field of requiredFields) {
          const trimmedField = field.trim();
          if (trimmedField.length === 0) continue;
          const val = record[trimmedField];
          if (
            val === undefined || val === null ||
            (typeof val === "string" && val.trim().length === 0)
          ) {
            violations.push({
              code: `missing_required_field_${trimmedField}`,
              severity: "block",
              message: `必須JSONフィールド「${trimmedField}」が欠落しています。`,
            });
          }
        }
        working = JSON.stringify(record);
      }
    } catch {
      violations.push({
        code: "invalid_json_syntax",
        severity: "block",
        message: "JSON構文のパースに失敗したため出力をブロックしました。",
      });
    }
  } else if (formatContract === "markdown_sections") {
    const requiredHeadings = options.requiredHeadings &&
        options.requiredHeadings.length > 0
      ? options.requiredHeadings
      : DEFAULT_MARKDOWN_HEADINGS;
    for (const heading of requiredHeadings) {
      const trimmedHeading = heading.trim();
      if (trimmedHeading.length === 0) continue;
      if (!working.includes(trimmedHeading)) {
        violations.push({
          code: "missing_required_markdown_heading",
          severity: "block",
          message: `必須Markdown見出し「${trimmedHeading}」が不足しています。`,
        });
      }
    }
  } else if (formatContract === "concise_summary") {
    const maxLen = Math.max(40, options.maxLength ?? 400);
    const collapsed = working.replace(/\n{3,}/g, "\n\n").trim();
    if (collapsed !== working) {
      working = collapsed;
      violations.push({
        code: "whitespace_normalized",
        severity: "warning",
        message: "連続改行を正規化しました。",
      });
    }
    if (working.length > maxLen) {
      working = `${working.slice(0, maxLen - 3).trimEnd()}...`;
      violations.push({
        code: "summary_max_length_truncated",
        severity: "remediate",
        message: `上限文字数 (${maxLen}) を超過したため決定的に短縮しました。`,
      });
    }
  }

  const maxOutputLen = options.maxLength ?? (formatContract === "concise_summary" ? 400 : 4000);
  if (formatContract !== "concise_summary" && formatContract !== "json_object" && working.length > maxOutputLen) {
    working = `${working.slice(0, maxOutputLen - 3).trimEnd()}...`;
    violations.push({
      code: "output_max_length_truncated",
      severity: "remediate",
      message: `上限文字数 (${maxOutputLen}) 超過のためトリミングしました。`,
    });
  }

  const hasBlock = violations.some((v) => v.severity === "block");
  const hasRemediate = violations.some((v) => v.severity === "remediate");
  const decision: ValidationDecision = hasBlock
    ? "blocked"
    : hasRemediate || violations.length > 0
    ? "remediated"
    : "passed";

  const driftScore = computeDriftScore(violations);
  const finalOutput = decision === "blocked" ? "" : working;
  const reasonMessage = hasBlock
    ? violations.find((v) => v.severity === "block")?.message ??
      "AI出力検証ルールに違反したためブロックしました。"
    : decision === "remediated"
    ? violations.map((v) => v.message).join(" / ")
    : "";

  return {
    ruleSetVersion,
    decision,
    formatContract,
    allowed: decision !== "blocked",
    remediatedOutput: finalOutput,
    violations,
    violationCount: violations.length,
    driftScore,
    reasonMessage,
  };
}

export function buildValidationLogEntry(
  prompt: string,
  rawOutput: string,
  result: OutputValidationResult,
): ValidationAuditLogEntry {
  const safePrompt = truncateExcerpt(prompt, 1000) || "(empty-prompt)";
  const safeOriginal = truncateExcerpt(rawOutput, 2000);
  const safeRemediated = result.decision === "blocked"
    ? "[BLOCKED]"
    : truncateExcerpt(result.remediatedOutput, 2000);

  return {
    rule_set_version: result.ruleSetVersion,
    decision: result.decision,
    format_contract: result.formatContract,
    prompt_excerpt: safePrompt,
    original_output_excerpt: safeOriginal,
    remediated_output_excerpt: safeRemediated,
    violations: [...result.violations],
    violation_count: result.violationCount,
    drift_score: result.driftScore,
  };
}
