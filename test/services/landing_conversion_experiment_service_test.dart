import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/landing_conversion_experiment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const service = LandingConversionExperimentService();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('defines exactly ten independently measurable hypotheses', () {
    expect(LandingConversionExperimentService.hypotheses, hasLength(10));
    expect(
      LandingConversionExperimentService.hypotheses
          .map((hypothesis) => hypothesis.id)
          .toList(),
      <String>[
        'h01',
        'h02',
        'h03',
        'h04',
        'h05',
        'h06',
        'h07',
        'h08',
        'h09',
        'h10',
      ],
    );
  });

  test('leave-one-out control disables only its assigned hypothesis', () {
    for (final assigned in LandingConversionExperimentService.hypotheses) {
      final assignment = LandingExperimentAssignment(
        hypothesis: assigned,
        variant: LandingExperimentVariant.control,
      );
      for (final candidate in LandingConversionExperimentService.hypotheses) {
        expect(
          assignment.enables(candidate.id),
          candidate.id != assigned.id,
          reason: '${assigned.id} control must only disable ${assigned.id}',
        );
      }
    }
  });

  test('treatment keeps every conversion mechanism enabled', () {
    for (final assigned in LandingConversionExperimentService.hypotheses) {
      final assignment = LandingExperimentAssignment(
        hypothesis: assigned,
        variant: LandingExperimentVariant.treatment,
      );
      for (final candidate in LandingConversionExperimentService.hypotheses) {
        expect(assignment.enables(candidate.id), isTrue);
      }
    }
  });

  test('assignment is stable after the first visit', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = await service.resolve(
      preferences: prefs,
      deterministicBucket: 3,
    );
    final second = await service.resolve(
      preferences: prefs,
      deterministicBucket: 18,
    );

    expect(first, second);
    expect(first.hypothesis.id, 'h04');
    expect(first.variant, LandingExperimentVariant.control);
  });

  test(
    'query override supports deterministic QA without changing storage',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final stored = await service.resolve(
        preferences: prefs,
        deterministicBucket: 1,
      );
      final override = await service.resolve(
        uri: Uri.parse(
          'https://example.com/?lp_hypothesis=h10&lp_variant=treatment',
        ),
        preferences: prefs,
      );
      final afterOverride = await service.resolve(preferences: prefs);

      expect(stored.hypothesis.id, 'h02');
      expect(override.hypothesis.id, 'h10');
      expect(override.variant, LandingExperimentVariant.treatment);
      expect(afterOverride, stored);
    },
  );

  test('all funnel stages produce accepted experiment event keys', () {
    for (final hypothesis in LandingConversionExperimentService.hypotheses) {
      for (final variant in LandingExperimentVariant.values) {
        final assignment = LandingExperimentAssignment(
          hypothesis: hypothesis,
          variant: variant,
        );
        for (final stage
            in LandingConversionExperimentService.supportedStages) {
          expect(
            LandingConversionExperimentService.isExperimentEventKey(
              assignment.eventKey(stage),
            ),
            isTrue,
          );
        }
      }
    }
    expect(
      LandingConversionExperimentService.isExperimentEventKey(
        'lp_exp_h11_treatment_view',
      ),
      isFalse,
    );
  });
}
