export const CONTENT_GUARDRAIL_POLICY_VERSION = "writer-content-v1";
export const CONTENT_GUARDRAIL_MAX_CHARS = 50_000;

export type ContentGuardrailStage = "input" | "output" | "provider";
export type ContentGuardrailDecision = "allow" | "block" | "redact";

export type ContentGuardrailCategory =
  | "input_too_large"
  | "pii_email"
  | "pii_phone"
  | "pii_credit_card"
  | "pii_jp_my_number"
  | "secret_api_key"
  | "harmful_content"
  | "prompt_injection";

export interface ContentGuardrailResult {
  stage: "input" | "output";
  decision: ContentGuardrailDecision;
  categories: ContentGuardrailCategory[];
  redactionCount: number;
  safeText: string | null;
  contentChars: number;
}

export interface WriterNativeGuardrailBlock {
  blocked: boolean;
  categories: string[];
  guardrailName: string | null;
}

type SensitiveCategory = Extract<
  ContentGuardrailCategory,
  | "pii_email"
  | "pii_phone"
  | "pii_credit_card"
  | "pii_jp_my_number"
  | "secret_api_key"
>;

const EMAIL_PATTERN = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/giu;
const PHONE_PATTERN =
  /(?<!\d)(?:\+81[-\s]?(?:[1-9]\d?)[-\s]?\d{3,4}[-\s]?\d{4}|0(?:50|70|80|90)[-\s]?\d{4}[-\s]?\d{4}|0\d{1,4}[-\s]?\d{1,4}[-\s]?\d{4})(?!\d)/gu;
const CREDIT_CARD_CANDIDATE_PATTERN = /(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)/gu;
const MY_NUMBER_PATTERN =
  /(?:マイナンバー|個人番号)\s*[:：]?\s*\d{4}[ -]?\d{4}[ -]?\d{4}/giu;
const API_KEY_PATTERNS = [
  /\bsk-[A-Za-z0-9_-]{16,}\b/gu,
  /\bgh[pousr]_[A-Za-z0-9]{20,}\b/gu,
  /\bAKIA[A-Z0-9]{16}\b/gu,
  /\bBearer\s+[A-Za-z0-9._~+\/-]{16,}=*\b/giu,
  /\b(?:api[_-]?key|secret|token)\s*[:=]\s*["']?[A-Za-z0-9._~+\/-]{16,}["']?/giu,
];

const HARMFUL_PATTERNS = [
  /(?:爆弾|爆発物|銃器|毒物).{0,16}(?:作り方|製造方法|入手方法)/giu,
  /(?:人|他人|相手).{0,12}(?:殺す|傷つける|襲う).{0,12}(?:方法|手順)/giu,
  /(?:マルウェア|ランサムウェア|ウイルス).{0,16}(?:作る|作成|配布|感染)/giu,
  /(?:build|make).{0,12}(?:bomb|explosive|ransomware|malware)/giu,
  /how\s+to\s+(?:kill|poison|attack)\b/giu,
  /(?:child\s+sexual|児童.{0,4}性的)/giu,
];

const PROMPT_INJECTION_PATTERNS = [
  /ignore\s+(?:all\s+)?(?:previous|prior|system)\s+instructions?/giu,
  /reveal\s+(?:the\s+)?(?:system|developer)\s+prompt/giu,
  /(?:以前|これまで|システム)の(?:指示|命令)を(?:無視|忘れ)/gu,
  /(?:システム|開発者)(?:プロンプト|指示)を(?:表示|公開|開示)/gu,
];

function reset(pattern: RegExp): RegExp {
  pattern.lastIndex = 0;
  return pattern;
}

function hasMatch(pattern: RegExp, value: string): boolean {
  return reset(pattern).test(value);
}

function replaceAll(
  pattern: RegExp,
  value: string,
  replacement: string,
): { text: string; count: number } {
  let count = 0;
  const text = value.replace(reset(pattern), () => {
    count += 1;
    return replacement;
  });
  return { text, count };
}

function luhnValid(candidate: string): boolean {
  const digits = candidate.replace(/\D/g, "");
  if (digits.length < 13 || digits.length > 19 || /^(\d)\1+$/.test(digits)) {
    return false;
  }
  let sum = 0;
  let doubleDigit = false;
  for (let index = digits.length - 1; index >= 0; index -= 1) {
    let digit = Number(digits[index]);
    if (doubleDigit) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    doubleDigit = !doubleDigit;
  }
  return sum % 10 === 0;
}

function hasCreditCard(value: string): boolean {
  const matches = value.match(reset(CREDIT_CARD_CANDIDATE_PATTERN)) ?? [];
  return matches.some(luhnValid);
}

function redactCreditCards(value: string): { text: string; count: number } {
  let count = 0;
  const text = value.replace(
    reset(CREDIT_CARD_CANDIDATE_PATTERN),
    (candidate) => {
      if (!luhnValid(candidate)) return candidate;
      count += 1;
      return "[REDACTED_CREDIT_CARD]";
    },
  );
  return { text, count };
}

function sensitiveCategories(value: string): SensitiveCategory[] {
  const categories: SensitiveCategory[] = [];
  if (hasMatch(EMAIL_PATTERN, value)) categories.push("pii_email");
  if (hasMatch(PHONE_PATTERN, value)) categories.push("pii_phone");
  if (hasCreditCard(value)) categories.push("pii_credit_card");
  if (hasMatch(MY_NUMBER_PATTERN, value)) {
    categories.push("pii_jp_my_number");
  }
  if (API_KEY_PATTERNS.some((pattern) => hasMatch(pattern, value))) {
    categories.push("secret_api_key");
  }
  return categories;
}

function policyCategories(value: string): ContentGuardrailCategory[] {
  const categories: ContentGuardrailCategory[] = [
    ...sensitiveCategories(value),
  ];
  if (HARMFUL_PATTERNS.some((pattern) => hasMatch(pattern, value))) {
    categories.push("harmful_content");
  }
  if (PROMPT_INJECTION_PATTERNS.some((pattern) => hasMatch(pattern, value))) {
    categories.push("prompt_injection");
  }
  return [...new Set(categories)];
}

function redactSensitive(value: string): {
  text: string;
  redactionCount: number;
} {
  let text = value;
  let redactionCount = 0;
  const replacements: Array<[RegExp, string]> = [
    [EMAIL_PATTERN, "[REDACTED_EMAIL]"],
    [PHONE_PATTERN, "[REDACTED_PHONE]"],
    [MY_NUMBER_PATTERN, "[REDACTED_MY_NUMBER]"],
  ];
  for (const [pattern, replacement] of replacements) {
    const result = replaceAll(pattern, text, replacement);
    text = result.text;
    redactionCount += result.count;
  }
  const cardResult = redactCreditCards(text);
  text = cardResult.text;
  redactionCount += cardResult.count;
  for (const pattern of API_KEY_PATTERNS) {
    const result = replaceAll(pattern, text, "[REDACTED_SECRET]");
    text = result.text;
    redactionCount += result.count;
  }
  return { text, redactionCount };
}

export function evaluateContentGuardrail(
  rawText: string,
  stage: "input" | "output",
): ContentGuardrailResult {
  const normalized = rawText.normalize("NFKC");
  if (normalized.length > CONTENT_GUARDRAIL_MAX_CHARS) {
    return {
      stage,
      decision: "block",
      categories: ["input_too_large"],
      redactionCount: 0,
      safeText: null,
      contentChars: normalized.length,
    };
  }

  const categories = policyCategories(normalized);
  if (stage === "input") {
    return {
      stage,
      decision: categories.length === 0 ? "allow" : "block",
      categories,
      redactionCount: 0,
      safeText: categories.length === 0 ? rawText : null,
      contentChars: normalized.length,
    };
  }

  if (
    categories.includes("harmful_content") ||
    categories.includes("prompt_injection")
  ) {
    return {
      stage,
      decision: "block",
      categories,
      redactionCount: 0,
      safeText: null,
      contentChars: normalized.length,
    };
  }

  if (categories.length > 0) {
    const redacted = redactSensitive(normalized);
    return {
      stage,
      decision: "redact",
      categories,
      redactionCount: redacted.redactionCount,
      safeText: redacted.text,
      contentChars: normalized.length,
    };
  }

  return {
    stage,
    decision: "allow",
    categories: [],
    redactionCount: 0,
    safeText: rawText,
    contentChars: normalized.length,
  };
}

function collectText(value: unknown, output: string[]): void {
  if (typeof value === "string") {
    output.push(value);
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectText(item, output);
    return;
  }
  if (!value || typeof value !== "object") return;
  const record = value as Record<string, unknown>;
  if (typeof record.content === "string" || Array.isArray(record.content)) {
    collectText(record.content, output);
  } else if (typeof record.text === "string") {
    output.push(record.text);
  }
}

export function collectProviderInputText(
  messages: unknown,
  fallbackMessage: unknown,
): string {
  const output: string[] = [];
  if (Array.isArray(messages)) collectText(messages, output);
  if (output.length === 0 && typeof fallbackMessage === "string") {
    output.push(fallbackMessage);
  }
  return output.join("\n");
}

function safeCategory(value: unknown): string | null {
  const normalized = String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 64);
  return normalized || null;
}

export function parseWriterNativeGuardrailBlock(
  responseText: string,
): WriterNativeGuardrailBlock {
  let payload: unknown;
  try {
    payload = JSON.parse(responseText);
  } catch {
    return { blocked: false, categories: [], guardrailName: null };
  }
  if (!payload || typeof payload !== "object") {
    return { blocked: false, categories: [], guardrailName: null };
  }
  const record = payload as Record<string, unknown>;
  const errors = Array.isArray(record.errors) ? record.errors : [];
  const categories: string[] = [];
  let guardrailName: string | null = null;
  let blocked = false;
  for (const item of errors) {
    if (!item || typeof item !== "object") continue;
    const error = item as Record<string, unknown>;
    const key = String(error.key ?? "");
    const description = String(error.description ?? "");
    if (
      key === "fail.guardrail.blocked" ||
      /content blocked by guardrail/i.test(description)
    ) {
      blocked = true;
    }
    const extras = error.extras && typeof error.extras === "object"
      ? error.extras as Record<string, unknown>
      : {};
    const category = safeCategory(extras.entity_type);
    if (category) categories.push(`writer_${category}`);
    const name = safeCategory(extras.guardrail_name);
    if (name) guardrailName = name;
  }
  return {
    blocked,
    categories: [...new Set(categories)],
    guardrailName,
  };
}

export function writerSafeProviderErrorDetail(status: number): string {
  const safeStatus = Number.isInteger(status) && status >= 400 && status <= 599
    ? status
    : 502;
  return `Writer API request failed (${safeStatus}).`;
}
