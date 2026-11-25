export const PAYMENT_EXHAUSTED_COOLDOWN_MS = 15 * 60 * 1000;

// Issue #5102: deepinfra が 402 (残高不足) を返し続けているため自動 budget ルーティングから除外する。
// PROVIDER_CONFIGS.deepinfra と DEEPINFRA_API_KEY 検証は互換性維持のため残す。
export const DEFAULT_BUDGET_TIER_PROVIDERS: readonly string[] = [
  "sambanova",
  "arcee_ai",
  "minimax",
  "together_ai",
  "fireworks_ai",
  "moonshot",
];

// 残高枯渇プロバイダより先に健全な google / nebius を試す順序に配置する。
export const QUOTA_FALLBACK_CHAIN: readonly string[] = [
  "google",
  "nebius",
  "anthropic",
  "openai",
];

export type BillingSkipReason = "disabled" | "payment_cooldown";

export function isProviderPaymentRequired(
  status: number,
  responseText: string,
): boolean {
  const text = responseText.toLowerCase();
  if (status === 422 || text.includes("guardrail_blocked")) {
    return false;
  }
  return status === 402 ||
    text.includes("paid_plan_required") ||
    text.includes("payment_required") ||
    text.includes("insufficient_quota") ||
    text.includes("positive balance") ||
    text.includes("add balance") ||
    text.includes("top-up") ||
    text.includes("billing") ||
    text.includes("credit");
}

export function parseDisabledProviders(raw?: string | null): Set<string> {
  if (!raw) return new Set<string>();
  return new Set(
    raw
      .split(",")
      .map((item) => item.trim().toLowerCase())
      .filter((item) => item.length > 0),
  );
}

export class ProviderPaymentCooldownTracker {
  private readonly cooldownUntilByProvider = new Map<string, number>();

  constructor(
    private readonly defaultCooldownMs: number = PAYMENT_EXHAUSTED_COOLDOWN_MS,
  ) {}

  markExhausted(
    providerId: string,
    nowMs: number = Date.now(),
    cooldownMs: number = this.defaultCooldownMs,
  ): void {
    const key = providerId.trim().toLowerCase();
    if (!key) return;
    const duration = Math.max(0, cooldownMs);
    this.cooldownUntilByProvider.set(key, nowMs + duration);
  }

  remainingCooldownMs(providerId: string, nowMs: number = Date.now()): number {
    const key = providerId.trim().toLowerCase();
    const until = this.cooldownUntilByProvider.get(key);
    if (until === undefined) return 0;
    const remaining = until - nowMs;
    if (remaining <= 0) {
      this.cooldownUntilByProvider.delete(key);
      return 0;
    }
    return remaining;
  }

  isInCooldown(providerId: string, nowMs: number = Date.now()): boolean {
    return this.remainingCooldownMs(providerId, nowMs) > 0;
  }

  clear(providerId?: string): void {
    if (!providerId) {
      this.cooldownUntilByProvider.clear();
      return;
    }
    this.cooldownUntilByProvider.delete(providerId.trim().toLowerCase());
  }
}

export function shouldSkipProviderForBilling(
  providerId: string,
  tracker: ProviderPaymentCooldownTracker,
  disabledRaw?: string | null,
  nowMs: number = Date.now(),
): { skip: boolean; reason: BillingSkipReason | null } {
  const key = providerId.trim().toLowerCase();
  if (!key) return { skip: false, reason: null };
  if (parseDisabledProviders(disabledRaw).has(key)) {
    return { skip: true, reason: "disabled" };
  }
  if (tracker.isInCooldown(key, nowMs)) {
    return { skip: true, reason: "payment_cooldown" };
  }
  return { skip: false, reason: null };
}

export function selectEligibleProviders(
  providers: readonly string[],
  tracker: ProviderPaymentCooldownTracker,
  disabledRaw?: string | null,
  nowMs: number = Date.now(),
): string[] {
  return providers.filter((providerId) =>
    !shouldSkipProviderForBilling(providerId, tracker, disabledRaw, nowMs).skip
  );
}
