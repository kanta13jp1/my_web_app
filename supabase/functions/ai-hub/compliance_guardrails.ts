import { maskLogString } from "../_shared/sensitive_log_masker.ts";

export type GuardrailStage = "input" | "output";
export type GuardrailAction = "allowed" | "masked" | "blocked";
export type GuardrailMode = "default" | "strict_block";

export type GuardrailViolationCategory =
  | "pii_credit_card"
  | "pii_my_number"
  | "pii_ssn"
  | "pii_credential"
  | "pii_contact"
  | "toxic_self_harm"
  | "toxic_violence"
  | "toxic_cyber_abuse"
  | "toxic_hate";

export interface ComplianceGuardrailResult {
  stage: GuardrailStage;
  action: GuardrailAction;
  allowed: boolean;
  categories: GuardrailViolationCategory[];
  sanitizedText: string;
  reasonMessage: string;
  auditSummary: string;
  maskedCount: number;
}

export interface MessagesGuardrailResult {
  stage: "input";
  action: GuardrailAction;
  allowed: boolean;
  categories: GuardrailViolationCategory[];
  sanitizedMessages: Array<Record<string, unknown>>;
  reasonMessage: string;
  auditSummary: string;
  maskedCount: number;
}

const PRIVATE_KEY_HEADER_RE = new RegExp(
  "-----BEGIN\\s+(?:RSA\\s+|EC\\s+|OPENSSH\\s+)?PRIVATE\\s+KEY-----",
  "i",
);

const API_TOKEN_LITERAL_RE = new RegExp(
  "(?:\\bsk-[A-Za-z0-9]{20,}|\\bgh[pousr]_[A-Za-z0-9]{20,}|\\bsb_secret_[A-Za-z0-9_]{12,}|\\bAIza[0-9A-Za-z\\-_]{30,})",
);

const EMAIL_RE = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
const JP_PHONE_RE = /0\d{1,4}-\d{1,4}-\d{3,4}/g;
const CARD_CANDIDATE_RE = /(?<!\d)(?:\d[ -]?){13,19}(?!\d)/g;
const MY_NUMBER_CONTEXT_RE =
  /(?:マイナンバー|個人番号)[^\d\n]{0,16}\d{4}[- ]?\d{4}[- ]?\d{4}/;
const SSN_CONTEXT_RE = /(?:ssn|社会保障番号)[^\d\n]{0,16}\d{3}-\d{2}-\d{4}/i;

const SELF_HARM_RE =
  /(?:自殺の方法|確実な自殺方法|自傷行為の手順|how\s+to\s+commit\s+suicide|step[- ]by[- ]step\s+self[- ]harm)/i;
const VIOLENCE_RE =
  /(?:爆弾の作り方|爆発物の製造方法|銃器の密造方法|how\s+to\s+make\s+a\s+bomb|build\s+an\s+improvised\s+explosive|mass\s+shooting\s+plan)/i;
const CYBER_ABUSE_RE =
  /(?:ランサムウェアを作成|クレジットカードを盗む|マルウェアのコードを書いて|write\s+ransomware\s+code|steal\s+credit\s+card\s+numbers|bypass\s+banking\s+authentication)/i;
const HATE_RE =
  /(?:特定の民族を絶滅|ヘイトスピーチを生成|genocide\s+of\s+an\s+ethnic\s+group)/i;

function isValidLuhn(digits: string): boolean {
  if (digits.length < 13 || digits.length > 19) return false;
  let sum = 0;
  let shouldDouble = false;
  for (let i = digits.length - 1; i >= 0; i--) {
    let d = digits.charCodeAt(i) - 48;
    if (d < 0 || d > 9) return false;
    if (shouldDouble) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    shouldDouble = !shouldDouble;
  }
  return sum % 10 === 0;
}

function hasCreditCardNumber(text: string): boolean {
  const matches = text.matchAll(CARD_CANDIDATE_RE);
  for (const match of matches) {
    const digits = match[0].replace(/[^0-9]/g, "");
    if (isValidLuhn(digits)) {
      return true;
    }
  }
  return false;
}

function uniqueCategories(
  list: GuardrailViolationCategory[],
): GuardrailViolationCategory[] {
  return [...new Set(list)];
}

function formatBlockedReason(
  stage: GuardrailStage,
  categories: readonly GuardrailViolationCategory[],
): string {
  const stageLabel = stage === "input" ? "入力プロンプト" : "AI応答";
  const hasToxicity = categories.some((c) => c.startsWith("toxic_"));
  const hasPii = categories.some((c) => c.startsWith("pii_"));
  if (hasPii && hasToxicity) {
    return `${stageLabel}に機密情報（PII/認証情報）および安全ポリシー違反表現が含まれるためブロックしました。`;
  }
  if (hasPii) {
    return `${stageLabel}に保護対象の個人情報・認証情報が含まれるためブロックしました。機密情報を除いて再試行してください。`;
  }
  return `${stageLabel}に安全ガイドライン違反（有害・攻撃的内容）が検出されたためブロックしました。`;
}

export function evaluateComplianceGuardrail(
  text: string,
  options: { stage: GuardrailStage; mode?: GuardrailMode },
): ComplianceGuardrailResult {
  const stage = options.stage;
  const mode: GuardrailMode = options.mode ?? "default";
  const raw = String(text ?? "");

  const hardBlockCategories: GuardrailViolationCategory[] = [];
  const contactCategories: GuardrailViolationCategory[] = [];

  if (hasCreditCardNumber(raw)) {
    hardBlockCategories.push("pii_credit_card");
  }
  if (MY_NUMBER_CONTEXT_RE.test(raw)) {
    hardBlockCategories.push("pii_my_number");
  }
  if (SSN_CONTEXT_RE.test(raw)) {
    hardBlockCategories.push("pii_ssn");
  }
  if (PRIVATE_KEY_HEADER_RE.test(raw) || API_TOKEN_LITERAL_RE.test(raw)) {
    hardBlockCategories.push("pii_credential");
  }
  if (SELF_HARM_RE.test(raw)) {
    hardBlockCategories.push("toxic_self_harm");
  }
  if (VIOLENCE_RE.test(raw)) {
    hardBlockCategories.push("toxic_violence");
  }
  if (CYBER_ABUSE_RE.test(raw)) {
    hardBlockCategories.push("toxic_cyber_abuse");
  }
  if (HATE_RE.test(raw)) {
    hardBlockCategories.push("toxic_hate");
  }

  let contactHits = 0;
  const emailMatches = raw.match(EMAIL_RE);
  if (emailMatches) contactHits += emailMatches.length;
  const phoneMatches = raw.match(JP_PHONE_RE);
  if (phoneMatches) contactHits += phoneMatches.length;
  if (contactHits > 0) {
    contactCategories.push("pii_contact");
  }

  const shouldBlock = hardBlockCategories.length > 0 ||
    (mode === "strict_block" && contactCategories.length > 0);
  const categories = uniqueCategories([
    ...hardBlockCategories,
    ...contactCategories,
  ]);

  if (shouldBlock) {
    const auditSummary =
      `guardrail_blocked[stage=${stage}][categories=${categories.join(",")}]`;
    return {
      stage,
      action: "blocked",
      allowed: false,
      categories,
      sanitizedText: "",
      reasonMessage: formatBlockedReason(stage, categories),
      auditSummary,
      maskedCount: 0,
    };
  }

  if (contactCategories.length > 0) {
    const sanitized = maskLogString(raw);
    const auditSummary =
      `guardrail_masked[stage=${stage}][categories=${categories.join(",")}]`;
    return {
      stage,
      action: "masked",
      allowed: true,
      categories,
      sanitizedText: sanitized,
      reasonMessage: "",
      auditSummary,
      maskedCount: contactHits,
    };
  }

  return {
    stage,
    action: "allowed",
    allowed: true,
    categories: [],
    sanitizedText: raw,
    reasonMessage: "",
    auditSummary: `guardrail_allowed[stage=${stage}]`,
    maskedCount: 0,
  };
}

export function evaluateMessagesGuardrail(
  messages: ReadonlyArray<Record<string, unknown>>,
  mode: GuardrailMode = "default",
): MessagesGuardrailResult {
  const allCategories: GuardrailViolationCategory[] = [];
  const sanitizedMessages: Array<Record<string, unknown>> = [];
  let totalMasked = 0;
  let blockedReason = "";

  for (const msg of messages) {
    if (typeof msg.content !== "string") {
      sanitizedMessages.push({ ...msg });
      continue;
    }
    const evaluated = evaluateComplianceGuardrail(msg.content, {
      stage: "input",
      mode,
    });
    allCategories.push(...evaluated.categories);
    totalMasked += evaluated.maskedCount;
    if (!evaluated.allowed) {
      blockedReason = evaluated.reasonMessage;
    }
    sanitizedMessages.push({
      ...msg,
      content: evaluated.allowed ? evaluated.sanitizedText : "[BLOCKED]",
    });
  }

  const categories = uniqueCategories(allCategories);
  if (blockedReason.length > 0) {
    return {
      stage: "input",
      action: "blocked",
      allowed: false,
      categories,
      sanitizedMessages: [],
      reasonMessage: blockedReason,
      auditSummary:
        `guardrail_blocked[stage=input][categories=${categories.join(",")}]`,
      maskedCount: totalMasked,
    };
  }

  if (totalMasked > 0) {
    return {
      stage: "input",
      action: "masked",
      allowed: true,
      categories,
      sanitizedMessages,
      reasonMessage: "",
      auditSummary:
        `guardrail_masked[stage=input][categories=${categories.join(",")}]`,
      maskedCount: totalMasked,
    };
  }

  return {
    stage: "input",
    action: "allowed",
    allowed: true,
    categories: [],
    sanitizedMessages,
    reasonMessage: "",
    auditSummary: "guardrail_allowed[stage=input]",
    maskedCount: 0,
  };
}

export function buildGuardrailBlockedPayload(
  result: Pick<
    ComplianceGuardrailResult,
    "stage" | "categories" | "reasonMessage"
  >,
  meta: {
    provider: string;
    traceId: string;
    action: string;
  },
): Record<string, unknown> {
  return {
    success: false,
    status: "guardrailBlocked",
    code: "compliance_guardrail_blocked",
    stage: result.stage,
    categories: result.categories,
    provider: meta.provider,
    action: meta.action,
    trace_id: meta.traceId,
    message: result.reasonMessage,
    guardrail: {
      checked: true,
      action: "blocked",
      stage: result.stage,
      categories: result.categories,
    },
  };
}
