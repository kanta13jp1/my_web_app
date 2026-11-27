/// 3-tier DX ROI classification (#4130).
enum DxRoiTier {
  directCostSavings('direct_cost_savings', '直接コスト削減'),
  opportunityLossAvoidance('opportunity_loss_avoidance', '機会損失回避'),
  addedValueCreation('added_value_creation', '付加価値創出');

  const DxRoiTier(this.wireName, this.label);

  final String wireName;
  final String label;
}

/// Configurable business coefficients for AI ROI calculation.
class RoiCoefficients {
  const RoiCoefficients({
    this.hourlyRateJpy = 3000,
    this.estimatedHoursSavedPerCall = 0.1,
    this.opportunityLossAvoidedPerCallJpy = 100,
    this.addedValuePerCallJpy = 200,
  });

  final double hourlyRateJpy;
  final double estimatedHoursSavedPerCall;
  final double opportunityLossAvoidedPerCallJpy;
  final double addedValuePerCallJpy;
}

/// Usage sample for a single AI feature and period.
class AiFeatureUsageSample {
  const AiFeatureUsageSample({
    required this.featureName,
    required this.periodLabel,
    required this.callCount,
    required this.apiCostJpy,
  });

  final String featureName;
  final String periodLabel;
  final int callCount;
  final double apiCostJpy;
}

/// Per-feature ROI breakdown across the 3 DX value tiers.
class FeatureRoiBreakdown {
  const FeatureRoiBreakdown({
    required this.featureName,
    required this.periodLabel,
    required this.callCount,
    required this.apiCostJpy,
    required this.directCostSavingsJpy,
    required this.opportunityLossAvoidanceJpy,
    required this.addedValueCreationJpy,
    required this.totalBenefitJpy,
    required this.netBenefitJpy,
    required this.roiRatio,
  });

  final String featureName;
  final String periodLabel;
  final int callCount;
  final double apiCostJpy;
  final double directCostSavingsJpy;
  final double opportunityLossAvoidanceJpy;
  final double addedValueCreationJpy;
  final double totalBenefitJpy;
  final double netBenefitJpy;
  final double roiRatio;
}

/// Aggregated AI ROI summary across features and periods.
class AiRoiSummary {
  const AiRoiSummary({
    required this.totalCalls,
    required this.totalApiCostJpy,
    required this.totalDirectCostSavingsJpy,
    required this.totalOpportunityLossAvoidanceJpy,
    required this.totalAddedValueCreationJpy,
    required this.totalBenefitJpy,
    required this.totalNetBenefitJpy,
    required this.overallRoiRatio,
    required this.items,
  });

  final int totalCalls;
  final double totalApiCostJpy;
  final double totalDirectCostSavingsJpy;
  final double totalOpportunityLossAvoidanceJpy;
  final double totalAddedValueCreationJpy;
  final double totalBenefitJpy;
  final double totalNetBenefitJpy;
  final double overallRoiRatio;
  final List<FeatureRoiBreakdown> items;
}

/// Computes 3-tier DX ROI metrics from AI usage and configurable coefficients.
class AiRoiMeasurementService {
  const AiRoiMeasurementService();

  /// Computes ROI breakdown for a single [sample] under [coefficients].
  FeatureRoiBreakdown computeFeatureRoi(
    AiFeatureUsageSample sample,
    RoiCoefficients coefficients,
  ) {
    final calls = sample.callCount < 0 ? 0 : sample.callCount;
    final apiCost = sample.apiCostJpy < 0 ? 0.0 : sample.apiCostJpy;
    final hourlyRate =
        coefficients.hourlyRateJpy < 0 ? 0.0 : coefficients.hourlyRateJpy;
    final hoursSaved = coefficients.estimatedHoursSavedPerCall < 0
        ? 0.0
        : coefficients.estimatedHoursSavedPerCall;
    final oppAvoided = coefficients.opportunityLossAvoidedPerCallJpy < 0
        ? 0.0
        : coefficients.opportunityLossAvoidedPerCallJpy;
    final addedValue = coefficients.addedValuePerCallJpy < 0
        ? 0.0
        : coefficients.addedValuePerCallJpy;

    final direct = calls * hoursSaved * hourlyRate;
    final opp = calls * oppAvoided;
    final added = calls * addedValue;
    final totalBenefit = direct + opp + added;
    final netBenefit = totalBenefit - apiCost;
    final roi = apiCost == 0 ? 0.0 : netBenefit / apiCost;

    return FeatureRoiBreakdown(
      featureName: sample.featureName,
      periodLabel: sample.periodLabel,
      callCount: calls,
      apiCostJpy: apiCost,
      directCostSavingsJpy: direct,
      opportunityLossAvoidanceJpy: opp,
      addedValueCreationJpy: added,
      totalBenefitJpy: totalBenefit,
      netBenefitJpy: netBenefit,
      roiRatio: roi,
    );
  }

  /// Summarizes all [samples] into an immutable [AiRoiSummary].
  AiRoiSummary summarize(
    List<AiFeatureUsageSample> samples,
    RoiCoefficients coefficients,
  ) {
    final items = samples
        .map((AiFeatureUsageSample s) => computeFeatureRoi(s, coefficients))
        .toList();

    var totalCalls = 0;
    var totalCost = 0.0;
    var totalDirect = 0.0;
    var totalOpp = 0.0;
    var totalAdded = 0.0;

    for (final item in items) {
      totalCalls += item.callCount;
      totalCost += item.apiCostJpy;
      totalDirect += item.directCostSavingsJpy;
      totalOpp += item.opportunityLossAvoidanceJpy;
      totalAdded += item.addedValueCreationJpy;
    }

    final totalBenefit = totalDirect + totalOpp + totalAdded;
    final netBenefit = totalBenefit - totalCost;
    final roi = totalCost == 0 ? 0.0 : netBenefit / totalCost;

    return AiRoiSummary(
      totalCalls: totalCalls,
      totalApiCostJpy: totalCost,
      totalDirectCostSavingsJpy: totalDirect,
      totalOpportunityLossAvoidanceJpy: totalOpp,
      totalAddedValueCreationJpy: totalAdded,
      totalBenefitJpy: totalBenefit,
      totalNetBenefitJpy: netBenefit,
      overallRoiRatio: roi,
      items: List<FeatureRoiBreakdown>.unmodifiable(items),
    );
  }
}
