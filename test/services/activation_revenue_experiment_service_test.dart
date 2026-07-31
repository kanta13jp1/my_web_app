import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/activation_revenue_experiment_service.dart';
import 'package:my_web_app/services/landing_share_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('deterministic buckets cover all 10 hypotheses and both variants',
      () async {
    final assignments = <String>{};

    for (var bucket = 0; bucket < 20; bucket++) {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final assignment = await const ActivationRevenueExperimentService()
          .resolve(preferences: prefs, deterministicBucket: bucket);
      assignments.add(
        '${assignment.hypothesis.id}:${assignment.variant.name}',
      );
    }

    expect(assignments, hasLength(20));
    for (final hypothesis in ActivationRevenueExperimentService.hypotheses) {
      expect(assignments, contains('${hypothesis.id}:control'));
      expect(assignments, contains('${hypothesis.id}:treatment'));
    }
  });

  test('assignment remains stable after the first visit', () async {
    final prefs = await SharedPreferences.getInstance();
    const service = ActivationRevenueExperimentService();
    final first = await service.resolve(
      preferences: prefs,
      deterministicBucket: 0,
    );
    final second = await service.resolve(
      preferences: prefs,
      deterministicBucket: 19,
    );

    expect(second, first);
  });

  test('QA query parameters override the stored assignment', () async {
    final prefs = await SharedPreferences.getInstance();
    await const ActivationRevenueExperimentService().resolve(
      preferences: prefs,
      deterministicBucket: 0,
    );

    final overridden = await const ActivationRevenueExperimentService().resolve(
      preferences: prefs,
      uri: Uri.parse(
        'https://example.test/onboarding?activation_hypothesis=a10&activation_variant=treatment',
      ),
    );

    expect(overridden.hypothesis.id, 'a10');
    expect(overridden.variant, ActivationRevenueVariant.treatment);
  });

  test('each control disables only its own hypothesis treatment', () {
    for (final hypothesis in ActivationRevenueExperimentService.hypotheses) {
      final control = ActivationRevenueAssignment(
        hypothesis: hypothesis,
        variant: ActivationRevenueVariant.control,
      );
      final treatment = ActivationRevenueAssignment(
        hypothesis: hypothesis,
        variant: ActivationRevenueVariant.treatment,
      );

      expect(control.enables(hypothesis.id), isFalse);
      expect(treatment.enables(hypothesis.id), isTrue);
      for (final other in ActivationRevenueExperimentService.hypotheses) {
        if (other.id != hypothesis.id) {
          expect(control.enables(other.id), isTrue);
        }
      }
    }
  });

  test('all funnel events have accepted bounded keys', () {
    for (final hypothesis in ActivationRevenueExperimentService.hypotheses) {
      for (final variant in ActivationRevenueVariant.values) {
        final assignment = ActivationRevenueAssignment(
          hypothesis: hypothesis,
          variant: variant,
        );
        for (final stage
            in ActivationRevenueExperimentService.supportedStages) {
          final key = assignment.eventKey(stage);
          expect(
            ActivationRevenueExperimentService.isExperimentEventKey(key),
            isTrue,
            reason: key,
          );
        }
      }
    }

    expect(
      ActivationRevenueExperimentService.isExperimentEventKey(
        'activation_exp_a11_treatment_billing_view',
      ),
      isFalse,
    );
  });

  test('landing analytics accepts activation funnel events', () async {
    await expectLater(
      LandingShareService.recordFunnelEvent(
        eventKey: 'activation_exp_a10_treatment_supporter_checkout',
      ),
      completes,
    );
  });
}
