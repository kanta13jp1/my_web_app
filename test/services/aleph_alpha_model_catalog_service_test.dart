import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/aleph_alpha_model_catalog_service.dart';

final DateTime _now = DateTime.utc(2026, 11, 28);
final DateTime _verified = DateTime.utc(2026, 11, 20);

AlephAlphaModelEntry _model(
  String id, {
  AlephAlphaProviderVariant variant = AlephAlphaProviderVariant.pharia,
  AlephAlphaAvailability availability = AlephAlphaAvailability.available,
  int contextLength = 32768,
  DateTime? verifiedAt,
  String sourceUrl = 'https://docs.aleph-alpha.com/docs/models/',
}) {
  return AlephAlphaModelEntry(
    modelId: id,
    variant: variant,
    availability: availability,
    contextLength: contextLength,
    verifiedAt: verifiedAt ?? _verified,
    sourceUrl: sourceUrl,
  );
}

AlephAlphaCandidateAssessment _candidate(
  String id, {
  double quality = 0.8,
  double speed = 0.6,
  int cost = 1200,
  double explainability = 0.7,
}) {
  return AlephAlphaCandidateAssessment(
    modelId: id,
    quality: quality,
    speed: speed,
    estimatedCostYen: cost,
    explainability: explainability,
  );
}

AlephAlphaWorkloadAssessment _workload(
  AlephAlphaWorkloadKind kind,
  List<AlephAlphaCandidateAssessment> candidates, {
  AlephAlphaGoNoGo decision = AlephAlphaGoNoGo.go,
  String reason = '固定fixture上の相対評価',
}) {
  return AlephAlphaWorkloadAssessment(
    workload: kind,
    candidates: candidates,
    decision: decision,
    decisionReason: reason,
  );
}

void main() {
  const service = AlephAlphaModelCatalogService();

  group('evidence contract', () {
    test('evidenceComplete is true only when all fields and link verify', () {
      final complete = AlephAlphaEvidenceContract(
        targetAudience: 'アプリ開発者',
        observableLearningOutcome: '代表ワークロードで候補を選べる',
        assessmentVerificationMethod: '固定fixtureの比較課題',
        evidenceSourceUrl: 'https://docs.aleph-alpha.com/docs/models/',
        evidenceVerifiedAt: _verified,
        linkStatus: AlephAlphaLinkStatus.verifiedVariants,
      );
      expect(complete.evidenceComplete, isTrue);
      expect(complete.validate(), isEmpty);
    });

    test('all-null row (current public state) is never complete', () {
      const empty = AlephAlphaEvidenceContract();
      expect(empty.evidenceComplete, isFalse);
      expect(
        empty.validate(),
        containsAll(<String>[
          'target_audience_required',
          'observable_learning_outcome_required',
          'assessment_verification_method_required',
          'evidence_source_https_url_required',
          'evidence_verified_at_required',
          'source_url_not_verified',
        ]),
      );
    });

    test('redirect to an unverified destination blocks completeness', () {
      final redirected = AlephAlphaEvidenceContract(
        targetAudience: 'アプリ開発者',
        observableLearningOutcome: '代表ワークロードで候補を選べる',
        assessmentVerificationMethod: '固定fixtureの比較課題',
        evidenceSourceUrl:
            'https://docs.aleph-alpha.com/docs/introduction/luminous/',
        evidenceVerifiedAt: _verified,
        linkStatus: AlephAlphaLinkStatus.redirectMismatch,
      );
      expect(redirected.evidenceComplete, isFalse);
      expect(
        redirected.validate(),
        contains('source_url_redirects_to_unverified_destination'),
      );
    });

    test('blank strings and non-https URLs are treated as missing', () {
      final blank = AlephAlphaEvidenceContract(
        targetAudience: '  ',
        observableLearningOutcome: '成果',
        assessmentVerificationMethod: '方法',
        evidenceSourceUrl: 'http://docs.example.test/',
        evidenceVerifiedAt: _verified,
        linkStatus: AlephAlphaLinkStatus.verifiedVariants,
      );
      expect(blank.evidenceComplete, isFalse);
      expect(
        blank.validate(),
        containsAll(<String>[
          'target_audience_required',
          'evidence_source_https_url_required',
        ]),
      );
    });
  });

  group('model catalog', () {
    test('accepts a valid mixed Pharia/Luminous catalog', () {
      final models = <AlephAlphaModelEntry>[
        _model('pharia-a'),
        _model(
          'luminous-a',
          variant: AlephAlphaProviderVariant.luminous,
          availability: AlephAlphaAvailability.deprecated,
        ),
        _model(
          'luminous-old',
          variant: AlephAlphaProviderVariant.luminous,
          availability: AlephAlphaAvailability.retired,
        ),
      ];
      expect(service.validateModels(models, now: _now).isValid, isTrue);

      final counts = service.countByVariant(models);
      expect(counts[AlephAlphaProviderVariant.pharia], 1);
      expect(counts[AlephAlphaProviderVariant.luminous], 2);

      final recommendable = service.recommendable(models);
      expect(recommendable.map((model) => model.modelId), <String>['pharia-a']);
    });

    test('rejects duplicate ids, bad context, future dates, and bad urls', () {
      final models = <AlephAlphaModelEntry>[
        _model('dup'),
        _model('dup', contextLength: 0),
        _model('future', verifiedAt: DateTime.utc(2027, 1, 1)),
        _model('badurl', sourceUrl: 'http://docs.example.test/'),
      ];
      final errors = service.validateModels(models, now: _now).errors;
      expect(
        errors,
        containsAll(<String>[
          'duplicate_model_id:dup',
          'context_length_must_be_positive:dup',
          'verified_at_in_future:future',
          'source_https_url_required:badurl',
        ]),
      );
    });
  });

  group('two-workload tradeoff fixture', () {
    final models = <AlephAlphaModelEntry>[
      _model('pharia-a'),
      _model(
        'luminous-old',
        variant: AlephAlphaProviderVariant.luminous,
        availability: AlephAlphaAvailability.retired,
      ),
      _model(
        'luminous-a',
        variant: AlephAlphaProviderVariant.luminous,
        availability: AlephAlphaAvailability.deprecated,
      ),
    ];

    test('accepts two distinct workloads with go and no-go decisions', () {
      final fixture = AlephAlphaTradeoffFixture(
        usesFixtureOnly: true,
        workloads: <AlephAlphaWorkloadAssessment>[
          _workload(
            AlephAlphaWorkloadKind.documentQuestionAnswering,
            <AlephAlphaCandidateAssessment>[_candidate('pharia-a')],
          ),
          _workload(
            AlephAlphaWorkloadKind.structuredExtraction,
            <AlephAlphaCandidateAssessment>[_candidate('luminous-a')],
            decision: AlephAlphaGoNoGo.noGo,
            reason: '非推奨のみで採用不可',
          ),
        ],
      );
      expect(service.validateTradeoffFixture(fixture, models).errors, isEmpty);
    });

    test('rejects retired candidates, bad scores, and unsupported go', () {
      final fixture = AlephAlphaTradeoffFixture(
        usesFixtureOnly: false,
        workloads: <AlephAlphaWorkloadAssessment>[
          _workload(
            AlephAlphaWorkloadKind.documentQuestionAnswering,
            <AlephAlphaCandidateAssessment>[
              _candidate('luminous-old'),
              _candidate('unknown-model'),
              _candidate('pharia-a', quality: 1.5, cost: -1),
            ],
          ),
          _workload(
            AlephAlphaWorkloadKind.structuredExtraction,
            <AlephAlphaCandidateAssessment>[_candidate('luminous-a')],
            reason: ' ',
          ),
        ],
      );
      final errors = service.validateTradeoffFixture(fixture, models).errors;
      expect(
        errors,
        containsAll(<String>[
          'fixture_only_required',
          'retired_model_cannot_be_candidate:luminous-old',
          'unknown_candidate_model:unknown-model',
          'scores_must_be_within_0_and_1:pharia-a',
          'estimated_cost_must_not_be_negative:pharia-a',
          'decision_reason_required:structured_extraction',
          'go_requires_available_candidate:structured_extraction',
        ]),
      );
    });

    test('requires exactly two distinct workloads', () {
      final fixture = AlephAlphaTradeoffFixture(
        usesFixtureOnly: true,
        workloads: <AlephAlphaWorkloadAssessment>[
          _workload(
            AlephAlphaWorkloadKind.documentQuestionAnswering,
            <AlephAlphaCandidateAssessment>[_candidate('pharia-a')],
          ),
          _workload(
            AlephAlphaWorkloadKind.documentQuestionAnswering,
            <AlephAlphaCandidateAssessment>[_candidate('pharia-a')],
          ),
        ],
      );
      expect(
        service.validateTradeoffFixture(fixture, models).errors,
        contains('exactly_two_distinct_workloads_required'),
      );
    });
  });
}
