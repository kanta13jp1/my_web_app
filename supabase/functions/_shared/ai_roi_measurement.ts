/**
 * 3-Tier DX AI ROI Measurement Engine (#4130)
 *
 * Models Direct Cost Savings, Opportunity Loss Avoidance, and Added Value
 * Creation against API cost using configurable business coefficients.
 */

export type DxRoiTier =
  | "direct_cost_savings"
  | "opportunity_loss_avoidance"
  | "added_value_creation";

export const DX_ROI_TIER_LABELS = {
  direct_cost_savings: "Direct Cost Savings",
  opportunity_loss_avoidance: "Opportunity Loss Avoidance",
  added_value_creation: "Added Value Creation",
} as const satisfies Record<DxRoiTier, string>;

export interface RoiCoefficients {
  readonly hourlyRateJpy: number;
  readonly estimatedHoursSavedPerCall: number;
  readonly opportunityLossAvoidedPerCallJpy: number;
  readonly addedValuePerCallJpy: number;
}

export interface AiFeatureUsageSample {
  readonly featureName: string;
  readonly periodLabel: string;
  readonly callCount: number;
  readonly apiCostJpy: number;
}

export interface FeatureRoiBreakdown {
  readonly featureName: string;
  readonly periodLabel: string;
  readonly callCount: number;
  readonly apiCostJpy: number;
  readonly directCostSavingsJpy: number;
  readonly opportunityLossAvoidanceJpy: number;
  readonly addedValueCreationJpy: number;
  readonly totalBenefitJpy: number;
  readonly netBenefitJpy: number;
  readonly roiRatio: number;
}

export interface AiRoiSummary {
  readonly totalCalls: number;
  readonly totalApiCostJpy: number;
  readonly totalDirectCostSavingsJpy: number;
  readonly totalOpportunityLossAvoidanceJpy: number;
  readonly totalAddedValueCreationJpy: number;
  readonly totalBenefitJpy: number;
  readonly totalNetBenefitJpy: number;
  readonly overallRoiRatio: number;
  readonly items: readonly FeatureRoiBreakdown[];
}

function roundJpy(val: number): number {
  return Math.round(val * 100) / 100;
}

export function computeFeatureRoi(
  sample: AiFeatureUsageSample,
  coeff: RoiCoefficients,
): FeatureRoiBreakdown {
  const calls = Math.max(0, Math.round(sample.callCount));
  const apiCostJpy = Math.max(0, roundJpy(sample.apiCostJpy));

  const directCostSavingsJpy = roundJpy(
    calls *
      Math.max(0, coeff.estimatedHoursSavedPerCall) *
      Math.max(0, coeff.hourlyRateJpy),
  );
  const opportunityLossAvoidanceJpy = roundJpy(
    calls * Math.max(0, coeff.opportunityLossAvoidedPerCallJpy),
  );
  const addedValueCreationJpy = roundJpy(
    calls * Math.max(0, coeff.addedValuePerCallJpy),
  );

  const totalBenefitJpy = roundJpy(
    directCostSavingsJpy +
      opportunityLossAvoidanceJpy +
      addedValueCreationJpy,
  );
  const netBenefitJpy = roundJpy(totalBenefitJpy - apiCostJpy);
  const roiRatio = apiCostJpy === 0
    ? 0
    : Number((netBenefitJpy / apiCostJpy).toFixed(4));

  return {
    featureName: sample.featureName,
    periodLabel: sample.periodLabel,
    callCount: calls,
    apiCostJpy,
    directCostSavingsJpy,
    opportunityLossAvoidanceJpy,
    addedValueCreationJpy,
    totalBenefitJpy,
    netBenefitJpy,
    roiRatio,
  };
}

export function summarizeAiRoi(
  samples: readonly AiFeatureUsageSample[],
  coeff: RoiCoefficients,
): AiRoiSummary {
  const items = samples.map((s) => computeFeatureRoi(s, coeff));
  let totalCalls = 0;
  let totalApiCostJpy = 0;
  let totalDirectCostSavingsJpy = 0;
  let totalOpportunityLossAvoidanceJpy = 0;
  let totalAddedValueCreationJpy = 0;

  for (const item of items) {
    totalCalls += item.callCount;
    totalApiCostJpy += item.apiCostJpy;
    totalDirectCostSavingsJpy += item.directCostSavingsJpy;
    totalOpportunityLossAvoidanceJpy += item.opportunityLossAvoidanceJpy;
    totalAddedValueCreationJpy += item.addedValueCreationJpy;
  }

  totalApiCostJpy = roundJpy(totalApiCostJpy);
  totalDirectCostSavingsJpy = roundJpy(totalDirectCostSavingsJpy);
  totalOpportunityLossAvoidanceJpy = roundJpy(totalOpportunityLossAvoidanceJpy);
  totalAddedValueCreationJpy = roundJpy(totalAddedValueCreationJpy);

  const totalBenefitJpy = roundJpy(
    totalDirectCostSavingsJpy +
      totalOpportunityLossAvoidanceJpy +
      totalAddedValueCreationJpy,
  );
  const totalNetBenefitJpy = roundJpy(totalBenefitJpy - totalApiCostJpy);
  const overallRoiRatio = totalApiCostJpy === 0
    ? 0
    : Number((totalNetBenefitJpy / totalApiCostJpy).toFixed(4));

  return {
    totalCalls,
    totalApiCostJpy,
    totalDirectCostSavingsJpy,
    totalOpportunityLossAvoidanceJpy,
    totalAddedValueCreationJpy,
    totalBenefitJpy,
    totalNetBenefitJpy,
    overallRoiRatio,
    items,
  };
}
