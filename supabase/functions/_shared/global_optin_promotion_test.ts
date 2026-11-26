import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computeCompositeRankScore,
  DEFAULT_MIN_PROMOTION_TENANTS,
  DEFAULT_PROMOTION_SCORE_THRESHOLD,
  resolveOptInConfigFromEnv,
  runPromotionAndDemotionSweep,
} from "./global_optin_promotion.ts";

Deno.test(
  "resolveOptInConfigFromEnv uses defaults and honors valid overrides",
  () => {
    const defaults = resolveOptInConfigFromEnv(() => undefined);
    assertEquals(defaults.minQualifyingTenants, DEFAULT_MIN_PROMOTION_TENANTS);
    assertEquals(
      defaults.promotionThreshold,
      DEFAULT_PROMOTION_SCORE_THRESHOLD,
    );

    const custom = resolveOptInConfigFromEnv((key) => {
      if (key === "OPTIN_MIN_QUALIFYING_TENANTS") return "4";
      if (key === "OPTIN_PROMOTION_THRESHOLD") return "0.82";
      return undefined;
    });
    assertEquals(custom.minQualifyingTenants, 4);
    assertEquals(custom.promotionThreshold, 0.82);
  },
);

Deno.test(
  "runPromotionAndDemotionSweep promotes at >=3 tenants and demotes on drop",
  () => {
    const first = runPromotionAndDemotionSweep({
      nowIso: "2026-11-26T04:00:00Z",
      evaluations: [
        {
          tenantId: "t1",
          itemId: "doc-1",
          score: 0.7,
          updatedAt: "2026-11-26T01:00:00Z",
        },
        {
          tenantId: "t2",
          itemId: "doc-1",
          score: 0.8,
          updatedAt: "2026-11-26T01:00:00Z",
        },
        {
          tenantId: "t3",
          itemId: "doc-1",
          score: 0.9,
          updatedAt: "2026-11-26T01:00:00Z",
        },
      ],
    });
    assertEquals(first.promotedCount, 1);
    assertEquals(first.activeGlobalCount, 1);
    assertEquals(first.records[0].isGlobalPromoted, true);

    const second = runPromotionAndDemotionSweep({
      nowIso: "2026-11-26T05:00:00Z",
      previousRecords: first.records,
      evaluations: [
        {
          tenantId: "t1",
          itemId: "doc-1",
          score: 0.7,
          updatedAt: "2026-11-26T01:00:00Z",
        },
        {
          tenantId: "t2",
          itemId: "doc-1",
          score: 0.8,
          updatedAt: "2026-11-26T01:00:00Z",
        },
        {
          tenantId: "t3",
          itemId: "doc-1",
          score: 0.5,
          updatedAt: "2026-11-26T04:30:00Z",
        },
      ],
    });
    assertEquals(second.demotedCount, 1);
    assertEquals(second.activeGlobalCount, 0);
    assertEquals(second.records[0].status, "demoted");
    assertEquals(second.records[0].globalScore, 0);
  },
);

Deno.test(
  "computeCompositeRankScore applies 70/20/10 weights bounded [0,1]",
  () => {
    const score = computeCompositeRankScore({
      localScore: 0.8,
      globalScore: 0.9,
      usageScore: 0.6,
    });
    assertEquals(Math.round(score * 1000) / 1000, 0.8);
  },
);
