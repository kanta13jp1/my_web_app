export type GateDisposition = "published" | "revision_queue" | "discarded";

export type GateStage = "sentinel" | "warden";

export type GateSeverity = "info" | "warning" | "critical";

export const GATE_DISPOSITION_LABELS = {
  published: "公開承認済み",
  revision_queue: "修正キュー隔離",
  discarded: "自動破棄",
} as const satisfies Record<GateDisposition, string>;

export const GATE_STAGE_LABELS = {
  sentinel: "Sentinel（事実・スキーマ・PII検証）",
  warden: "Warden（フォーマット・最終品質検証）",
} as const satisfies Record<GateStage, string>;

export interface GateFinding {
  stage: GateStage;
  code: string;
  severity: GateSeverity;
  message: string;
}

export interface GateCandidate {
  id: string;
  sourceAction: string;
  content: string;
  structuredData?: Record<string, unknown>;
}

export interface GateEvaluationOptions {
  requiredKeys?: readonly string[];
  minContentLength?: number;
  maxContentLength?: number;
  minQualityScore?: number;
  nowIso?: () => string;
}

export interface RevisionQueueItem {
  id: string;
  candidateId: string;
  sourceAction: string;
  failedStage: GateStage;
  disposition: GateDisposition;
  contentExcerpt: string;
  findings: GateFinding[];
  createdAt: string;
  resolved: boolean;
}

export interface RevisionQueueStore {
  enqueue(item: RevisionQueueItem): Promise<void>;
  listPending(): Promise<RevisionQueueItem[]>;
  markResolved(id: string): Promise<boolean>;
}

export class InMemoryRevisionQueueStore implements RevisionQueueStore {
  private readonly items = new Map<string, RevisionQueueItem>();

  enqueue(item: RevisionQueueItem): Promise<void> {
    this.items.set(item.id, structuredClone(item));
    return Promise.resolve();
  }

  listPending(): Promise<RevisionQueueItem[]> {
    return Promise.resolve(
      Array.from(this.items.values())
        .filter((item) => !item.resolved)
        .map((item) => structuredClone(item)),
    );
  }

  markResolved(id: string): Promise<boolean> {
    const existing = this.items.get(id);
    if (!existing) return Promise.resolve(false);
    existing.resolved = true;
    this.items.set(id, existing);
    return Promise.resolve(true);
  }
}

export interface GateEvaluationResult {
  disposition: GateDisposition;
  publishable: boolean;
  sentinelPassed: boolean;
  wardenPassed: boolean;
  qualityScore: number;
  findings: GateFinding[];
  queuedItemId: string | null;
}

const EMAIL_RE = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/;
const PHONE_RE = /(?:\+?\d{1,3}[-.\s]?)?(?:\(?\d{2,4}\)?[-.\s]?){2}\d{3,4}/;
const SECRET_PREFIX_RE = new RegExp(
  ["(?:sk|ghp|AIza)", "[_-]?[A-Za-z0-9]{16,}"].join(""),
);
const HALLUCINATION_RE =
  /(\bTODO\b|\bFIXME\b|lorem ipsum|\[citation needed\]|架空の数値)/i;
const TEMPLATE_PLACEHOLDER_RE = /\{\{[^}]+\}\}|<placeholder>/i;

export function runSentinelCheck(
  candidate: GateCandidate,
  options: GateEvaluationOptions = {},
): { passed: boolean; criticalDiscard: boolean; findings: GateFinding[] } {
  const findings: GateFinding[] = [];
  const trimmed = candidate.content.trim();
  const minLen = options.minContentLength ?? 10;

  if (!trimmed) {
    findings.push({
      stage: "sentinel",
      code: "empty_output",
      severity: "critical",
      message: "Output content is empty.",
    });
    return { passed: false, criticalDiscard: true, findings };
  }

  if (
    EMAIL_RE.test(trimmed) ||
    PHONE_RE.test(trimmed) ||
    SECRET_PREFIX_RE.test(trimmed)
  ) {
    findings.push({
      stage: "sentinel",
      code: "pii_or_secret_detected",
      severity: "critical",
      message: "Detected PII or credential-like token in output.",
    });
  }

  if (trimmed.length < minLen) {
    findings.push({
      stage: "sentinel",
      code: "too_short_for_fact_check",
      severity: "warning",
      message: `Output shorter than ${minLen} characters.`,
    });
  }

  if (HALLUCINATION_RE.test(trimmed)) {
    findings.push({
      stage: "sentinel",
      code: "unverified_marker",
      severity: "warning",
      message: "Output contains unverified placeholder or marker.",
    });
  }

  const requiredKeys = options.requiredKeys ?? [];
  if (requiredKeys.length > 0) {
    const data = candidate.structuredData ?? {};
    for (const key of requiredKeys) {
      const value = data[key];
      if (value === undefined || value === null || value === "") {
        findings.push({
          stage: "sentinel",
          code: `missing_schema_key:${key}`,
          severity: "warning",
          message: `Missing required structured field: ${key}`,
        });
      }
    }
  }

  const criticalDiscard = findings.some((f) => f.severity === "critical");
  return {
    passed: findings.length === 0,
    criticalDiscard,
    findings,
  };
}

export function runWardenCheck(
  candidate: GateCandidate,
  options: GateEvaluationOptions = {},
): { passed: boolean; qualityScore: number; findings: GateFinding[] } {
  const findings: GateFinding[] = [];
  const trimmed = candidate.content.trim();
  const maxLen = options.maxContentLength ?? 20000;
  const minScore = options.minQualityScore ?? 0.7;
  let score = 1.0;

  if (trimmed.length > maxLen) {
    score -= 0.35;
    findings.push({
      stage: "warden",
      code: "exceeds_max_length",
      severity: "warning",
      message: `Output exceeds ${maxLen} characters.`,
    });
  }

  const fenceMatches = trimmed.match(/```/g);
  const fenceCount = fenceMatches ? fenceMatches.length : 0;
  if (fenceCount % 2 !== 0) {
    score -= 0.4;
    findings.push({
      stage: "warden",
      code: "unbalanced_code_fence",
      severity: "warning",
      message: "Markdown code fence count is odd.",
    });
  }

  if (TEMPLATE_PLACEHOLDER_RE.test(trimmed)) {
    score -= 0.4;
    findings.push({
      stage: "warden",
      code: "unresolved_template_placeholder",
      severity: "warning",
      message: "Unresolved template placeholder remains in output.",
    });
  }

  const clampedScore = Math.max(0, Math.round(score * 100) / 100);
  return {
    passed: findings.length === 0 && clampedScore >= minScore,
    qualityScore: clampedScore,
    findings,
  };
}

export async function evaluateSentinelWardenGate(
  candidate: GateCandidate,
  queueStore?: RevisionQueueStore,
  options: GateEvaluationOptions = {},
): Promise<GateEvaluationResult> {
  const now = options.nowIso ?? (() => new Date().toISOString());
  const sentinel = runSentinelCheck(candidate, options);

  if (!sentinel.passed) {
    const disposition: GateDisposition = sentinel.criticalDiscard
      ? "discarded"
      : "revision_queue";
    let queuedItemId: string | null = null;
    if (disposition === "revision_queue" && queueStore) {
      queuedItemId = `rev-${candidate.id}`;
      await queueStore.enqueue({
        id: queuedItemId,
        candidateId: candidate.id,
        sourceAction: candidate.sourceAction,
        failedStage: "sentinel",
        disposition,
        contentExcerpt: candidate.content.trim().slice(0, 160),
        findings: sentinel.findings,
        createdAt: now(),
        resolved: false,
      });
    }
    return {
      disposition,
      publishable: false,
      sentinelPassed: false,
      wardenPassed: false,
      qualityScore: 0,
      findings: sentinel.findings,
      queuedItemId,
    };
  }

  const warden = runWardenCheck(candidate, options);
  if (!warden.passed) {
    let queuedItemId: string | null = null;
    if (queueStore) {
      queuedItemId = `rev-${candidate.id}`;
      await queueStore.enqueue({
        id: queuedItemId,
        candidateId: candidate.id,
        sourceAction: candidate.sourceAction,
        failedStage: "warden",
        disposition: "revision_queue",
        contentExcerpt: candidate.content.trim().slice(0, 160),
        findings: warden.findings,
        createdAt: now(),
        resolved: false,
      });
    }
    return {
      disposition: "revision_queue",
      publishable: false,
      sentinelPassed: true,
      wardenPassed: false,
      qualityScore: warden.qualityScore,
      findings: warden.findings,
      queuedItemId,
    };
  }

  return {
    disposition: "published",
    publishable: true,
    sentinelPassed: true,
    wardenPassed: true,
    qualityScore: warden.qualityScore,
    findings: [],
    queuedItemId: null,
  };
}
