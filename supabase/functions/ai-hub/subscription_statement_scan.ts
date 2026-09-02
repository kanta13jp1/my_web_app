export type SubscriptionStatementCandidate = {
  service_name: string;
  amount_jpy: number;
  charged_at: string | null;
  billing_cycle: "monthly" | "annual" | "unknown";
  gateway: "direct" | "apple" | "googlePlay" | "auKantan";
  confidence: number;
  evidence: string;
};

const MAX_CANDIDATES = 100;
const LONG_NUMBER_PATTERN = /(?:^|\D)(?:\d[ -]?){12,19}(?=\D|$)/g;

export function buildSubscriptionStatementPrompt(): string {
  return [
    "You extract recurring subscription charges from a Japanese credit-card statement screenshot.",
    'Return JSON only: {"candidates":[...]}.',
    "Each candidate must contain service_name, amount_jpy, charged_at, billing_cycle, gateway, confidence, evidence.",
    "billing_cycle must be monthly, annual, or unknown. gateway must be direct, apple, googlePlay, or auKantan.",
    "Include only likely recurring subscriptions (software, AI, cloud, video, music, news, learning, memberships).",
    "Exclude groceries, transport, one-time shopping, cash advances, repayments, taxes, utilities unless clearly a subscription, refunds, and statement totals.",
    "Do not guess unreadable amounts. If uncertain, omit the row or use billing_cycle=unknown with low confidence.",
    "For repeated instances of the same service, return one representative candidate and infer the cycle only when supported by dates.",
    "Never return card numbers, account numbers, customer names, addresses, phone numbers, email addresses, authentication data, or full OCR text.",
    "evidence must be a short non-sensitive reason, at most 160 characters. charged_at must be YYYY-MM-DD or null.",
  ].join("\n");
}

export function normalizeSubscriptionStatementCandidates(
  value: unknown,
): SubscriptionStatementCandidate[] {
  const root = asRecord(value);
  const rawCandidates = Array.isArray(root?.candidates)
    ? root.candidates
    : Array.isArray(value)
    ? value
    : [];
  const deduped = new Map<string, SubscriptionStatementCandidate>();
  for (const raw of rawCandidates.slice(0, MAX_CANDIDATES * 2)) {
    const item = asRecord(raw);
    if (!item) continue;
    const serviceName = sanitizeText(item.service_name, 100);
    const amount = finiteNumber(item.amount_jpy ?? item.amount);
    if (
      !serviceName || amount === null || amount <= 0 || amount > 100_000_000
    ) {
      continue;
    }
    const billingCycle = normalizeCycle(item.billing_cycle);
    const gateway = normalizeGateway(item.gateway);
    const chargedAt = normalizeDate(item.charged_at);
    const confidence = clamp(finiteNumber(item.confidence) ?? 0, 0, 1);
    const evidence = sanitizeText(item.evidence, 160);
    const candidate: SubscriptionStatementCandidate = {
      service_name: serviceName,
      amount_jpy: Math.round(amount * 100) / 100,
      charged_at: chargedAt,
      billing_cycle: billingCycle,
      gateway,
      confidence,
      evidence,
    };
    const key = `${normalizeServiceName(serviceName)}:${candidate.amount_jpy}`;
    const current = deduped.get(key);
    if (
      !current ||
      candidate.confidence > current.confidence ||
      (candidate.confidence === current.confidence &&
        (candidate.charged_at ?? "") > (current.charged_at ?? ""))
    ) {
      deduped.set(key, candidate);
    }
    if (deduped.size >= MAX_CANDIDATES) break;
  }
  return [...deduped.values()];
}

export function parseSubscriptionStatementResponse(
  raw: string,
): SubscriptionStatementCandidate[] {
  const cleaned = raw
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
  try {
    return normalizeSubscriptionStatementCandidates(JSON.parse(cleaned));
  } catch {
    return [];
  }
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function finiteNumber(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function sanitizeText(value: unknown, maxLength: number): string {
  const text = String(value ?? "")
    .replace(/[\r\n\t]+/g, " ")
    .replace(LONG_NUMBER_PATTERN, " [number removed] ")
    .replace(/\s+/g, " ")
    .trim();
  return text.slice(0, maxLength);
}

function normalizeServiceName(value: string): string {
  return value.toLowerCase().replace(/[\s\p{P}\p{S}]/gu, "");
}

function normalizeCycle(
  value: unknown,
): SubscriptionStatementCandidate["billing_cycle"] {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (normalized === "monthly") return "monthly";
  if (normalized === "annual" || normalized === "yearly") return "annual";
  return "unknown";
}

function normalizeGateway(
  value: unknown,
): SubscriptionStatementCandidate["gateway"] {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (normalized === "apple") return "apple";
  if (normalized === "googleplay" || normalized === "google_play") {
    return "googlePlay";
  }
  if (normalized === "aukantan" || normalized === "au_kantan") {
    return "auKantan";
  }
  return "direct";
}

function normalizeDate(value: unknown): string | null {
  const text = String(value ?? "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return null;
  const parsed = new Date(`${text}T00:00:00Z`);
  return Number.isNaN(parsed.getTime()) ||
      parsed.toISOString().slice(0, 10) !== text
    ? null
    : text;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
