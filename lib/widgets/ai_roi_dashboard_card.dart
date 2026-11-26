import 'package:flutter/material.dart';
import 'package:my_web_app/services/ai_roi_measurement_service.dart';

/// 3-tier DX AI ROI summary & feature trend dashboard card (#4130).
class AiRoiDashboardCard extends StatelessWidget {
  const AiRoiDashboardCard({
    super.key,
    required this.summary,
    this.onAdjustCoefficients,
  });

  final AiRoiSummary summary;
  final VoidCallback? onAdjustCoefficients;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  'AI投資対効果 (ROI) サマリー',
                  style: theme.textTheme.titleMedium,
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: onAdjustCoefficients,
                  child: const Text('係数調整'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                _MetricChip(
                  label: DxRoiTier.directCostSavings.label,
                  value: '${summary.totalDirectCostSavingsJpy.round()}円',
                ),
                _MetricChip(
                  label: DxRoiTier.opportunityLossAvoidance.label,
                  value: '${summary.totalOpportunityLossAvoidanceJpy.round()}円',
                ),
                _MetricChip(
                  label: DxRoiTier.addedValueCreation.label,
                  value: '${summary.totalAddedValueCreationJpy.round()}円',
                ),
                _MetricChip(
                  label: 'APIコスト',
                  value: '${summary.totalApiCostJpy.round()}円',
                ),
                _MetricChip(
                  label: 'ROI倍率',
                  value: '${summary.overallRoiRatio.toStringAsFixed(2)}x',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (summary.items.isEmpty)
              Text(
                '集計対象のAI利用ログはありません。',
                style: theme.textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (final item in summary.items)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '${item.featureName} (${item.periodLabel})',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '呼出: ${item.callCount}回 / '
                                '純便益: ${item.netBenefitJpy.round()}円',
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                'ROI: ${item.roiRatio.toStringAsFixed(2)}x',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: Text(
        '$label: $value',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
