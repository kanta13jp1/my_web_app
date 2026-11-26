import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_roi_measurement_service.dart';
import 'package:my_web_app/widgets/ai_roi_dashboard_card.dart';

void main() {
  group('AiRoiMeasurementService & AiRoiDashboardCard', () {
    test('summarize computes 3-tier DX ROI and handles zero cost', () {
      const service = AiRoiMeasurementService();
      const coeff = RoiCoefficients(
        hourlyRateJpy: 3000,
        estimatedHoursSavedPerCall: 0.1,
        opportunityLossAvoidedPerCallJpy: 100,
        addedValuePerCallJpy: 200,
      );

      final summary = service.summarize(
        const <AiFeatureUsageSample>[
          AiFeatureUsageSample(
            featureName: 'receipt_ocr',
            periodLabel: '2026-11',
            callCount: 10,
            apiCostJpy: 1000,
          ),
          AiFeatureUsageSample(
            featureName: 'daily_brief',
            periodLabel: '2026-11',
            callCount: 10,
            apiCostJpy: 1000,
          ),
        ],
        coeff,
      );

      expect(summary.totalCalls, 20);
      expect(summary.totalDirectCostSavingsJpy, 6000);
      expect(summary.totalOpportunityLossAvoidanceJpy, 2000);
      expect(summary.totalAddedValueCreationJpy, 4000);
      expect(summary.totalBenefitJpy, 12000);
      expect(summary.totalNetBenefitJpy, 10000);
      expect(summary.overallRoiRatio, closeTo(5.0, 0.0001));

      final zeroCost = service.summarize(
        const <AiFeatureUsageSample>[
          AiFeatureUsageSample(
            featureName: 'free_summary',
            periodLabel: '2026-11',
            callCount: 3,
            apiCostJpy: 0,
          ),
        ],
        coeff,
      );
      expect(zeroCost.overallRoiRatio, 0);
    });

    testWidgets(
      'renders cleanly at 2.0x textScale on 360x800 and triggers adjust',
      (WidgetTester tester) async {
        const service = AiRoiMeasurementService();
        final summary = service.summarize(
          const <AiFeatureUsageSample>[
            AiFeatureUsageSample(
              featureName: 'receipt_ocr',
              periodLabel: '2026-11',
              callCount: 10,
              apiCostJpy: 1000,
            ),
          ],
          const RoiCoefficients(),
        );

        var adjusted = false;
        final errors = <FlutterErrorDetails>[];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          errors.add(details);
        };

        try {
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: AiRoiDashboardCard(
                      summary: summary,
                      onAdjustCoefficients: () => adjusted = true,
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.text('AI投資対効果 (ROI) サマリー'), findsOneWidget);
          expect(find.text('receipt_ocr (2026-11)'), findsOneWidget);
          await tester.tap(find.text('係数調整'));
          await tester.pump();

          expect(adjusted, isTrue);
          expect(errors, isEmpty);
        } finally {
          FlutterError.onError = oldOnError;
        }
      },
    );
  });
}
