export type RewardTier = "standard" | "contributor" | "curator" | "steward";

export const REWARD_TIER_LABELS = {
  standard: "一般メンバー",
  contributor: "貢献コントリビューター",
  curator: "ナレッジキュレーター",
  steward: "コミュニティスチュワード",
} as const satisfies Record<RewardTier, string>;

export const DEFAULT_FOCUS_MULTIPLIER = 1.6;
export const MIN_MULTIPLIER = 1.0;
export const MAX_SAFE_MULTIPLIER = 2.0;

export interface ContributionRewardPolicy {
  focusCategories: readonly string[];
  focusMultiplier?: number;
}

export interface ContributionInput {
  userId: string;
  category: string;
  basePoints: number;
  previousTotalPoints: number;
}

export interface ContributionRewardReceipt {
  userId: string;
  category: string;
  basePoints: number;
  isFocusCategory: boolean;
  appliedMultiplier: number;
  awardedPoints: number;
  newTotalPoints: number;
  unlockedTier: RewardTier;
}

export function clampMultiplier(value: number | undefined): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return DEFAULT_FOCUS_MULTIPLIER;
  }
  const bounded = Math.max(
    MIN_MULTIPLIER,
    Math.min(MAX_SAFE_MULTIPLIER, value),
  );
  return Math.round(bounded * 100) / 100;
}

export function resolveRewardTier(totalPoints: number): RewardTier {
  if (totalPoints >= 1000) return "steward";
  if (totalPoints >= 400) return "curator";
  if (totalPoints >= 100) return "contributor";
  return "standard";
}

export function calculateContributionReward(
  input: ContributionInput,
  policy: ContributionRewardPolicy,
): ContributionRewardReceipt {
  const safeBase = Math.max(0, Math.round(input.basePoints));
  const safePrev = Math.max(0, Math.round(input.previousTotalPoints));
  const normalizedCat = input.category.trim().toLowerCase();
  const focusSet = new Set(
    policy.focusCategories.map((c) => c.trim().toLowerCase()),
  );
  const isFocusCategory = normalizedCat.length > 0 &&
    focusSet.has(normalizedCat);
  const appliedMultiplier = isFocusCategory
    ? clampMultiplier(policy.focusMultiplier)
    : MIN_MULTIPLIER;
  const awardedPoints = Math.round(safeBase * appliedMultiplier);
  const newTotalPoints = safePrev + awardedPoints;

  return {
    userId: input.userId,
    category: input.category.trim(),
    basePoints: safeBase,
    isFocusCategory,
    appliedMultiplier,
    awardedPoints,
    newTotalPoints,
    unlockedTier: resolveRewardTier(newTotalPoints),
  };
}

function canonicalPayload(receipt: ContributionRewardReceipt): string {
  return [
    receipt.userId,
    receipt.category,
    String(receipt.basePoints),
    receipt.appliedMultiplier.toFixed(2),
    String(receipt.awardedPoints),
    String(receipt.newTotalPoints),
    receipt.unlockedTier,
  ].join("|");
}

function toHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function importHmacKey(rawMaterial: string): Promise<CryptoKey> {
  const enc = new TextEncoder();
  return await crypto.subtle.importKey(
    "raw",
    enc.encode(rawMaterial),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

export async function signRewardReceipt(
  receipt: ContributionRewardReceipt,
  hmacSecret: string,
): Promise<string> {
  const key = await importHmacKey(hmacSecret);
  const data = new TextEncoder().encode(canonicalPayload(receipt));
  const sig = await crypto.subtle.sign("HMAC", key, data);
  return toHex(sig);
}

export async function verifyRewardReceipt(
  receipt: ContributionRewardReceipt,
  signatureHex: string,
  hmacSecret: string,
): Promise<boolean> {
  const expected = await signRewardReceipt(receipt, hmacSecret);
  if (expected.length !== signatureHex.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signatureHex.charCodeAt(i);
  }
  return diff === 0;
}
