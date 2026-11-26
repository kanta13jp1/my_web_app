import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  DX_ROI_TIER_LABELS,
  summarizeAiRoi,
} from "./ai_roi_measurement.ts";

Deno.test(
  "summarizeAiRoi computes 3-tier DX ROI and net ratio accurately",
  () => {
    const summary = summarizeAiRoi(
      [
        {
          featureName: "receipt_ocr",
          periodLabel: "2026-11",
          callCount: 10,
          apiCostJpy: 1000,
        },
        {
          featureName: "daily_brief",
          periodLabel: "2026-11",
          callCount: 10,
          apiCostJpy: 1000,
        },
      ],
      {
        hourlyRateJpy: 3000,
        estimatedHoursSavedPerCall: 0.1,
        opportunityLossAvoidedPerCallJpy: 100,
        addedValuePerCallJpy: 200,
      },
    );

    // Per call benefit = 300 + 100 + 200 = 600 JPY; 20 calls = 12000 JPY.
    // API cost = 2000 JPY -> net = 10000 JPY -> ROI ratio = 5.0.
    assertEquals(summary.totalCalls, 20);
    assertEquals(summary.totalApiCostJpy, 2000);
    assertEquals(summary.totalDirectCostSavingsJpy, 6000);
    assertEquals(summary.totalOpportunityLossAvoidanceJpy, 2000);
    assertEquals(summary.totalAddedValueCreationJpy, 4000);
    assertEquals(summary.totalBenefitJpy, 12000);
    assertEquals(summary.totalNetBenefitJpy, 10000);
    assertEquals(summary.overallRoiRatio, 5);
    assertEquals(
      DX_ROI_TIER_LABELS.added_value_creation,
      "Added Value Creation",
    );
  },
);

Deno.test(
  "summarizeAiRoi handles zero API cost safely",
  () => {
    const summary = summarizeAiRoi(
      [
        {
          featureName: "free_tier_summary",
          periodLabel: "2026-11",
          callCount: 5,
          apiCostJpy: 0,
        },
      ],
      {
        hourlyRateJpy: 3000,
        estimatedHoursSavedPerCall: 0.1,
        opportunityLossAvoidedPerCallJpy: 0,
        addedValuePerCallJpy: 0,
      },
    );

    assertEquals(summary.totalApiCostJpy, 0);
    assertEquals(summary.overallRoiRatio, 0);
  },
);
