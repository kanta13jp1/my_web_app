import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/krisp_audio_quality_service.dart';

void main() {
  group('KrispAudioQualityService', () {
    const service = KrispAudioQualityService();

    test('defines one plan for each additional request scenario', () {
      final plans = service.plans;

      expect(plans, hasLength(4));
      expect(
        plans.map((plan) => plan.issueNumber),
        containsAll(<int>[752, 753, 754, 755]),
      );
      expect(
        plans.map((plan) => plan.scenario).toSet(),
        KrispAudioScenario.values.toSet(),
      );
    });

    test('remote meeting plan treats zero interruptions as complete', () {
      final plan = service.planFor(KrispAudioScenario.remoteMeeting);
      final interruptionKpi = plan.kpis.first;

      expect(interruptionKpi.target, 0);
      expect(interruptionKpi.current, 0);
      expect(interruptionKpi.progress, 1);
      expect(plan.readinessScore, greaterThanOrEqualTo(80));
    });

    test('share text contains KGI, CSF, KPI, and source URL', () {
      final plan = service.planFor(KrispAudioScenario.aiCoachSdk);
      final text = service.buildShareText(plan);

      expect(text, contains('KGI:'));
      expect(text, contains('CSF:'));
      expect(text, contains('KPI:'));
      expect(text, contains('https://sdk-docs.krisp.ai/docs/introduction'));
      expect(text, contains('SDK gates: 3/5'));
      expect(text, contains('contract'));
      expect(text, contains('model-distribution'));
    });

    test('AI coach SDK handoff keeps external gates explicit', () {
      final handoff = service.buildAiCoachHandoff();

      expect(handoff.issueNumber, 755);
      expect(handoff.readyForSdkSpike, isFalse);
      expect(handoff.satisfiedGateCount, 3);
      expect(
        handoff.blockers.map((gate) => gate.id),
        containsAll(<String>['contract', 'model-distribution']),
      );
      expect(
        handoff.pipeline.map((step) => step.id).toList(),
        <String>['capture', 'filter', 'turn-taking', 'stt', 'coach'],
      );
      expect(
        handoff.acceptanceChecks,
        contains(
          'Fallback to raw microphone input when Krisp SDK is unavailable.',
        ),
      );
    });
  });
}
