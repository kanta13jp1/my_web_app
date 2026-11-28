import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/jwenv_routing_comparison_service.dart';

const _sha = '0123456789abcdef0123456789abcdef01234567';

const _provenance = JwenvProvenance(
  modelId: 'legacy-model',
  modelSha: _sha,
  engineId: 'legacy-engine',
  engineSha: _sha,
);

JwenvSyntheticCase _case(
  String id, {
  String group = 'dev-group-a',
  JwenvDatasetSplit split = JwenvDatasetSplit.development,
  JwenvExpectedKind kind = JwenvExpectedKind.clear,
  String? label = 'food',
  bool locked = true,
}) {
  return JwenvSyntheticCase(
    caseId: id,
    memo: '合成メモ $id',
    originGroup: group,
    split: split,
    expectedKind: kind,
    provisionalLabel: kind == JwenvExpectedKind.insufficientInfo ? null : label,
    labelLockedBeforeModelOutput: locked,
  );
}

Map<String, double> _logitsFor(List<String> order) {
  return <String, double>{
    for (var i = 0; i < order.length; i++) order[i]: 0.1 * i,
  };
}

JwenvRoutingTelemetry _telemetry(
  String caseId, {
  JwenvRoutingMode mode = JwenvRoutingMode.independentYesNo12,
  String? confirmed,
  bool review = false,
  String? failure,
  List<String>? order,
  Map<String, double>? logits,
  JwenvInferenceKind kind = JwenvInferenceKind.live,
}) {
  final candidateOrder = order ??
      switch (mode) {
        JwenvRoutingMode.independentYesNo12 => <String>[
            ...JwenvCategories.priorityOrdered,
          ],
        JwenvRoutingMode.yesNoWithInsufficientInfo12 => <String>[
            ...JwenvCategories.priorityOrdered,
            JwenvCategories.insufficientInfoOption,
          ],
        JwenvRoutingMode.hierarchicalMax8 => <String>[
            ...JwenvCategories.priorityOrdered.take(8),
          ],
      };
  return JwenvRoutingTelemetry(
    caseId: caseId,
    mode: mode,
    inferenceKind: kind,
    provenance: _provenance,
    prompt: 'prompt for $caseId',
    candidateOrder: candidateOrder,
    logits: logits ?? _logitsFor(candidateOrder),
    rawResponse: failure == null ? '{"ok":true}' : '',
    latencyMs: 120.5,
    confirmedCategory: confirmed,
    routedToReview: review,
    failureReason: failure,
  );
}

void main() {
  const service = JwenvRoutingComparisonService();

  group('dataset contract', () {
    test('accepts split separated by origin group with locked labels', () {
      final cases = <JwenvSyntheticCase>[
        _case('dev-1'),
        _case(
          'dev-2',
          kind: JwenvExpectedKind.insufficientInfo,
        ),
        _case(
          'eval-1',
          group: 'eval-group-b',
          split: JwenvDatasetSplit.evaluation,
          label: 'transport',
        ),
      ];
      expect(service.validateDataset(cases).isValid, isTrue);
    });

    test('rejects origin group shared across splits and unlocked labels', () {
      final cases = <JwenvSyntheticCase>[
        _case('dev-1', group: 'shared'),
        _case(
          'eval-1',
          group: 'shared',
          split: JwenvDatasetSplit.evaluation,
        ),
        _case('dev-2', locked: false),
      ];
      final errors = service.validateDataset(cases).errors;
      expect(errors, contains('origin_group_spans_splits:shared'));
      expect(
        errors,
        contains('label_must_be_locked_before_model_output:dev-2'),
      );
    });

    test('rejects label mismatch for clear and insufficient cases', () {
      final cases = <JwenvSyntheticCase>[
        _case('bad-clear', label: 'not_a_category'),
        const JwenvSyntheticCase(
          caseId: 'bad-insufficient',
          memo: '合成メモ',
          originGroup: 'g',
          split: JwenvDatasetSplit.development,
          expectedKind: JwenvExpectedKind.insufficientInfo,
          provisionalLabel: 'food',
          labelLockedBeforeModelOutput: true,
        ),
      ];
      final errors = service.validateDataset(cases).errors;
      expect(errors, contains('clear_case_requires_category_label:bad-clear'));
      expect(
        errors,
        contains('insufficient_case_must_not_have_category:bad-insufficient'),
      );
    });

    test('category priority rule resolves overlaps deterministically', () {
      expect(
        JwenvCategories.resolveByPriority(<String>['food', 'medical']),
        'medical',
      );
      expect(
        JwenvCategories.resolveByPriority(<String>['other', 'convenience']),
        'convenience',
      );
      expect(JwenvCategories.resolveByPriority(<String>[]), isNull);
    });
  });

  group('option limits and diagnostic plan', () {
    test('hierarchy stages are capped at 8 options', () {
      expect(
        service.validateHierarchy(<List<String>>[
          JwenvCategories.priorityOrdered.take(8).toList(),
          JwenvCategories.priorityOrdered.skip(8).toList(),
        ]).isValid,
        isTrue,
      );
      expect(
        service.validateHierarchy(<List<String>>[
          JwenvCategories.priorityOrdered.take(9).toList(),
        ]).errors,
        contains('stage_0_exceeds_max_8_options'),
      );
    });

    test('initial plan allows one clear + one insufficient dev case only', () {
      final cases = <JwenvSyntheticCase>[
        _case('dev-clear'),
        _case('dev-vague', kind: JwenvExpectedKind.insufficientInfo),
        _case(
          'eval-1',
          group: 'eval-group',
          split: JwenvDatasetSplit.evaluation,
        ),
      ];
      const okPlan = JwenvDiagnosticPlan(
        requestCaseIds: <String>['dev-clear', 'dev-vague'],
        maxRequests: 8,
        stepBudgetMinutes: 45,
        perRequestBudgetMinutes: 15,
      );
      expect(
          service.validateInitialDiagnosticPlan(okPlan, cases).isValid, isTrue);

      const badPlan = JwenvDiagnosticPlan(
        requestCaseIds: <String>['dev-clear', 'eval-1'],
        maxRequests: 9,
        stepBudgetMinutes: 60,
        perRequestBudgetMinutes: 20,
      );
      final errors =
          service.validateInitialDiagnosticPlan(badPlan, cases).errors;
      expect(
        errors,
        containsAll(<String>[
          'plan_exceeds_max_8_requests',
          'plan_exceeds_45_minute_step_budget',
          'plan_exceeds_15_minute_request_budget',
          'plan_must_not_run_unused_evaluation_case:eval-1',
          'initial_plan_requires_one_clear_and_one_insufficient_case',
        ]),
      );
    });
  });

  group('telemetry preservation', () {
    test('accepts complete telemetry for every mode', () {
      for (final mode in JwenvRoutingMode.values) {
        final record = _telemetry('dev-1', mode: mode, confirmed: 'food');
        expect(
          service.validateTelemetry(record).errors,
          isEmpty,
          reason: mode.wireName,
        );
      }
    });

    test('rejects missing logits, bad provenance, and oversized hierarchy', () {
      final partial = _telemetry(
        'dev-1',
        confirmed: 'food',
        logits: <String, double>{'food': 1.0},
      );
      expect(
        service.validateTelemetry(partial).errors,
        contains('logits_must_cover_every_candidate'),
      );

      const badProvenance = JwenvProvenance(
        modelId: '',
        modelSha: 'main',
        engineId: '',
        engineSha: 'latest',
      );
      final badRecord = JwenvRoutingTelemetry(
        caseId: 'dev-1',
        mode: JwenvRoutingMode.independentYesNo12,
        inferenceKind: JwenvInferenceKind.live,
        provenance: badProvenance,
        prompt: 'p',
        candidateOrder: JwenvCategories.priorityOrdered,
        logits: _logitsFor(JwenvCategories.priorityOrdered),
        rawResponse: 'r',
        latencyMs: 1,
        routedToReview: true,
      );
      expect(
        service.validateTelemetry(badRecord).errors,
        containsAll(<String>[
          'model_id_required',
          'engine_id_required',
          'model_sha_must_be_40_hex',
          'engine_sha_must_be_40_hex',
        ]),
      );

      final oversized = _telemetry(
        'dev-1',
        mode: JwenvRoutingMode.hierarchicalMax8,
        review: true,
        order: JwenvCategories.priorityOrdered.take(9).toList(),
      );
      expect(
        service.validateTelemetry(oversized).errors,
        contains('hierarchical_request_exceeds_max_8_options'),
      );
    });

    test('failed requests keep failure reason and never carry a decision', () {
      final failed = _telemetry('dev-1', failure: 'timeout_15_minutes');
      expect(failed.failed, isTrue);
      expect(service.validateTelemetry(failed).errors, isEmpty);

      final failedWithDecision = _telemetry(
        'dev-1',
        failure: 'timeout_15_minutes',
        confirmed: 'food',
      );
      expect(
        service.validateTelemetry(failedWithDecision).errors,
        contains('failed_request_must_not_carry_decision'),
      );
    });

    test('mock and live inference stay distinguishable', () {
      final mock = _telemetry(
        'dev-1',
        confirmed: 'food',
        kind: JwenvInferenceKind.mock,
      );
      final live = _telemetry('dev-1', confirmed: 'food');
      expect(mock.inferenceKind, JwenvInferenceKind.mock);
      expect(live.inferenceKind, JwenvInferenceKind.live);
      expect(mock.inferenceKind == live.inferenceKind, isFalse);
    });
  });

  group('metrics', () {
    test('reports rejection, inappropriate confirmation, and over-rejection',
        () {
      final cases = <JwenvSyntheticCase>[
        _case('clear-1'),
        _case('clear-2', label: 'transport'),
        _case('vague-1', kind: JwenvExpectedKind.insufficientInfo),
        _case('vague-2', kind: JwenvExpectedKind.insufficientInfo),
      ];
      final telemetry = <JwenvRoutingTelemetry>[
        _telemetry('clear-1', confirmed: 'food'),
        _telemetry('clear-2', review: true),
        _telemetry('vague-1', confirmed: 'other'),
        _telemetry('vague-2', review: true),
        _telemetry('vague-2', failure: 'timeout_15_minutes'),
      ];
      final metrics = service.evaluate(cases: cases, telemetry: telemetry);
      final independent = metrics.firstWhere(
        (item) => item.mode == JwenvRoutingMode.independentYesNo12,
      );

      expect(independent.sampleSize, 4);
      expect(independent.failureCount, 1);
      expect(independent.routedToReviewCount, 2);
      expect(independent.rejectionRate, 0.5);
      expect(independent.inappropriateConfirmationCount, 1);
      expect(independent.inappropriateConfirmationRate, 0.5);
      expect(independent.overRejectionCount, 1);
      expect(independent.overRejectionRate, 0.5);
      expect(independent.caveat, contains('保証しない'));

      final hierarchical = metrics.firstWhere(
        (item) => item.mode == JwenvRoutingMode.hierarchicalMax8,
      );
      expect(hierarchical.sampleSize, 0);
      expect(hierarchical.rejectionRate, isNull);
      expect(hierarchical.inappropriateConfirmationRate, isNull);
    });
  });
}
