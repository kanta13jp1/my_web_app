import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/allen_ai_model_catalog_service.dart';

void main() {
  const service = AllenAiModelCatalogService();
  final verifiedAt = DateTime.utc(2026, 11, 28);

  test('derives evidenceComplete strictly from all five evidence fields', () {
    const incomplete = AllenAiCourseEvidenceContract(
      targetAudience: 'MLエンジニア',
      observableLearningOutcome: null,
      assessmentVerificationMethod: '2ワークロード比較演習',
      evidenceSourceUrl: AllenAiModelCatalogService.officialOlmoUrl,
      evidenceVerifiedAt: null,
    );
    expect(incomplete.evidenceComplete, isFalse);
    expect(
      incomplete.validate(),
      containsAll(<String>[
        'observable_learning_outcome_required',
        'evidence_verified_at_required',
      ]),
    );

    const insecureUrl = AllenAiCourseEvidenceContract(
      targetAudience: 'MLエンジニア',
      observableLearningOutcome: 'ワークロード別にgo/no-goを判定できる',
      assessmentVerificationMethod: '2ワークロード比較演習',
      evidenceSourceUrl: 'http://allenai.org/olmo',
      evidenceVerifiedAt: null,
    );
    expect(insecureUrl.evidenceComplete, isFalse);
    expect(
      insecureUrl.validate(),
      contains('evidence_source_https_url_required'),
    );

    final complete = AllenAiCourseEvidenceContract(
      targetAudience: 'MLエンジニア',
      observableLearningOutcome: 'ワークロード別にgo/no-goを判定できる',
      assessmentVerificationMethod: '2ワークロード比較演習',
      evidenceSourceUrl: AllenAiModelCatalogService.officialOlmoUrl,
      evidenceVerifiedAt: verifiedAt,
    );
    expect(complete.evidenceComplete, isTrue);
    expect(complete.validate(), isEmpty);
  });

  test('validates OLMo 3/3.1 current vs OLMo 1/2 legacy lifecycle rules', () {
    final validCatalog = <AllenAiModelCatalogEntry>[
      AllenAiModelCatalogEntry(
        modelId: 'olmo-3.1-32b-instruct',
        family: AllenAiModelFamily.olmo3_1,
        lifecycleStatus: AllenAiLifecycleStatus.current,
        contextLength: 65536,
        license: 'Apache-2.0',
        benchmarkSummary: 'OLMo 3.1 instruction benchmark',
        verifiedAt: verifiedAt,
        sourceUrl: AllenAiModelCatalogService.officialOlmoUrl,
      ),
      AllenAiModelCatalogEntry(
        modelId: 'olmo-2-32b',
        family: AllenAiModelFamily.olmo2,
        lifecycleStatus: AllenAiLifecycleStatus.legacy,
        contextLength: 4096,
        license: 'Apache-2.0',
        benchmarkSummary: 'OLMo 2 legacy baseline',
        verifiedAt: verifiedAt,
        sourceUrl: AllenAiModelCatalogService.officialOlmoUrl,
      ),
    ];
    expect(service.validateCatalog(validCatalog).isValid, isTrue);

    final legacyMarkedCurrent = <AllenAiModelCatalogEntry>[
      AllenAiModelCatalogEntry(
        modelId: 'olmo-2-32b',
        family: AllenAiModelFamily.olmo2,
        lifecycleStatus: AllenAiLifecycleStatus.current,
        contextLength: 4096,
        license: 'Apache-2.0',
        benchmarkSummary: 'OLMo 2 legacy baseline',
        verifiedAt: verifiedAt,
        sourceUrl: AllenAiModelCatalogService.officialOlmoUrl,
      ),
    ];
    expect(
      service.validateCatalog(legacyMarkedCurrent).errors,
      containsAll(<String>[
        'legacy_family_must_have_legacy_status:olmo-2-32b',
        'current_olmo3_series_missing',
      ]),
    );
  });

  test('validates static two-workload tradeoff fixture and rejects gaps', () {
    final fixture = service.buildTwoWorkloadFixture();
    expect(fixture.length, 2);
    expect(service.validateTradeoffAssessments(fixture).isValid, isTrue);

    final onlySmall = <AllenAiWorkloadTradeoffAssessment>[fixture.first];
    expect(
      service.validateTradeoffAssessments(onlySmall).errors,
      contains('large_workload_assessment_missing'),
    );

    const unverifiedFixture = <AllenAiWorkloadTradeoffAssessment>[
      AllenAiWorkloadTradeoffAssessment(
        workloadScale: AllenAiWorkloadScale.smallWorkload,
        workloadLabel: 'small',
        selectedModelId: 'olmo-3-7b-instruct',
        qualityScoreLabel: 'ok',
        speedLatencyLabel: 'fast',
        requiredVramGb: 16.0,
        estimatedCostUsd: 0.4,
        decision: AllenAiGoNoGoDecision.go,
        rationale: 'fits single GPU',
        usesFixtureOnly: false,
      ),
    ];
    expect(
      service.validateTradeoffAssessments(unverifiedFixture).errors,
      containsAll(<String>[
        'static_fixture_only_required:small_workload',
        'large_workload_assessment_missing',
      ]),
    );
  });
}
