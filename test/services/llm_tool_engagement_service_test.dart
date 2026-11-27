import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/llm_tool_engagement_service.dart';

void main() {
  group('LlmToolEngagementService', () {
    test('logs (actionType, generatedLabel) pairs and computes CTR', () async {
      final forwarded = <ToolEngagementEvent>[];
      final service = LlmToolEngagementService(
        sink: (ToolEngagementEvent event) async {
          forwarded.add(event);
        },
      );

      for (var i = 0; i < 4; i++) {
        await service.logEvent(
          const ToolEngagementEvent(
            actionType: 'invite',
            generatedLabel: 'Pay \$30 Cash',
            eventKind: EngagementEventKind.impression,
          ),
        );
      }
      await service.logEvent(
        const ToolEngagementEvent(
          actionType: 'invite',
          generatedLabel: 'Pay \$30 Cash',
          eventKind: EngagementEventKind.click,
        ),
      );

      expect(forwarded.length, 5);
      final metrics = service.computeCtrMetrics();
      expect(metrics.length, 1);
      expect(metrics[0].actionType, 'invite');
      expect(metrics[0].generatedLabel, 'Pay \$30 Cash');
      expect(metrics[0].impressions, 4);
      expect(metrics[0].clicks, 1);
      expect(metrics[0].ctr, closeTo(0.25, 0.0001));
    });

    test('buildPruningReport recommends pruning low-CTR actions only',
        () async {
      final service = LlmToolEngagementService();

      for (var i = 0; i < 25; i++) {
        await service.logEvent(
          const ToolEngagementEvent(
            actionType: 'legacy_upsell',
            generatedLabel: 'Claim Mystery Bonus',
            eventKind: EngagementEventKind.impression,
          ),
        );
      }
      for (var i = 0; i < 5; i++) {
        await service.logEvent(
          const ToolEngagementEvent(
            actionType: 'new_helper',
            generatedLabel: 'Try Quick Audit',
            eventKind: EngagementEventKind.impression,
          ),
        );
      }

      final report = service.buildPruningReport(
        minImpressions: 20,
        minCtrThreshold: 0.02,
      );
      expect(report.totalPairs, 2);
      expect(report.prunedActionTypes, <String>['legacy_upsell']);
      expect(report.candidates.length, 1);
      expect(report.candidates[0].generatedLabel, 'Claim Mystery Bonus');
    });
  });
}
