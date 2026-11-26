import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  calculateContributionReward,
  clampMultiplier,
  MAX_SAFE_MULTIPLIER,
  signRewardReceipt,
  verifyRewardReceipt,
} from "./contribution_reward_multiplier.ts";

Deno.test(
  "calculateContributionReward applies 1.6x to focus categories and caps",
  () => {
    const focusRes = calculateContributionReward(
      {
        userId: "u-1",
        category: "knowledge_guide",
        basePoints: 100,
        previousTotalPoints: 0,
      },
      { focusCategories: ["knowledge_guide"] },
    );
    assertEquals(focusRes.isFocusCategory, true);
    assertEquals(focusRes.appliedMultiplier, 1.6);
    assertEquals(focusRes.awardedPoints, 160);
    assertEquals(focusRes.unlockedTier, "contributor");

    const normalRes = calculateContributionReward(
      {
        userId: "u-1",
        category: "general_note",
        basePoints: 100,
        previousTotalPoints: 0,
      },
      { focusCategories: ["knowledge_guide"] },
    );
    assertEquals(normalRes.isFocusCategory, false);
    assertEquals(normalRes.appliedMultiplier, 1.0);
    assertEquals(normalRes.awardedPoints, 100);

    assertEquals(clampMultiplier(9.9), MAX_SAFE_MULTIPLIER);
  },
);

Deno.test(
  "signRewardReceipt and verifyRewardReceipt detect payload tampering",
  async () => {
    const receipt = calculateContributionReward(
      {
        userId: "u-2",
        category: "policy_fact",
        basePoints: 250,
        previousTotalPoints: 0,
      },
      { focusCategories: ["policy_fact"], focusMultiplier: 1.6 },
    );
    assertEquals(receipt.awardedPoints, 400);
    assertEquals(receipt.unlockedTier, "curator");

    const testMaterial = "unit-test-hmac-placeholder";
    const sig = await signRewardReceipt(receipt, testMaterial);
    assertEquals(await verifyRewardReceipt(receipt, sig, testMaterial), true);

    const tampered = { ...receipt, awardedPoints: 9999 };
    assertEquals(
      await verifyRewardReceipt(tampered, sig, testMaterial),
      false,
    );
  },
);
