import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/activation_revenue_experiment_service.dart';
import 'package:my_web_app/services/activation_revenue_tracker.dart';

void main() {
  final assignment = ActivationRevenueAssignment(
    hypothesis: ActivationRevenueExperimentService.hypotheses.first,
    variant: ActivationRevenueVariant.treatment,
  );

  group('SupabaseActivationRevenueEventTracker', () {
    test(
      'forwards the bounded event key to the unique-user recorder',
      () async {
        final recorded = <String>[];
        final tracker = SupabaseActivationRevenueEventTracker(
          uniqueEventRecorderOverride: (eventKey) async {
            recorded.add(eventKey);
          },
        );

        await tracker.record(
          assignment: assignment,
          stage: 'first_action_completed',
        );

        expect(recorded, <String>[
          'activation_exp_a01_treatment_first_action_completed',
        ]);
      },
    );

    test('keeps activation UX fail-open when unique telemetry fails', () async {
      final tracker = SupabaseActivationRevenueEventTracker(
        uniqueEventRecorderOverride: (_) async {
          throw StateError('telemetry unavailable');
        },
      );

      await expectLater(
        tracker.record(assignment: assignment, stage: 'onboarding_completed'),
        completes,
      );
    });

    test('uses the dedicated unique-event RPC in production', () {
      final contents = File(
        'lib/services/activation_revenue_tracker.dart',
      ).readAsStringSync();

      expect(contents, contains('record_activation_experiment_event'));
      expect(contents, contains("'p_event_key': eventKey"));
    });
  });
}
