/// Allen AI OLMo モデルファミリ（現行 3/3.1 系と旧版 1/2 系を明示区別）。
enum AllenAiModelFamily {
  olmo3_1('olmo_3_1', isLegacy: false),
  olmo3('olmo_3', isLegacy: false),
  olmo2('olmo_2', isLegacy: true),
  olmo1('olmo_1', isLegacy: true);

  const AllenAiModelFamily(this.wireName, {required this.isLegacy});

  final String wireName;
  final bool isLegacy;
}

/// モデルのライフサイクル状態。
enum AllenAiLifecycleStatus {
  current('current'),
  legacy('legacy');

  const AllenAiLifecycleStatus(this.wireName);

  final String wireName;
}

/// トレードオフ評価の対象ワークロード規模（2段階固定）。
enum AllenAiWorkloadScale {
  smallWorkload('small_workload'),
  largeWorkload('large_workload');

  const AllenAiWorkloadScale(this.wireName);

  final String wireName;
}

/// ワークロード別の採用判定。
enum AllenAiGoNoGoDecision {
  go('go'),
  noGo('no_go');

  const AllenAiGoNoGoDecision(this.wireName);

  final String wireName;
}

/// 講座カタログ行の根拠完全性契約。
///
/// `evidenceComplete` は 5 項目の実在・有効性から厳密に導出され、
/// いずれかが null または空文字の場合は絶対に `true` にならない。
class AllenAiCourseEvidenceContract {
  const AllenAiCourseEvidenceContract({
    this.targetAudience,
    this.observableLearningOutcome,
    this.assessmentVerificationMethod,
    this.evidenceSourceUrl,
    this.evidenceVerifiedAt,
  });

  final String? targetAudience;
  final String? observableLearningOutcome;
  final String? assessmentVerificationMethod;
  final String? evidenceSourceUrl;
  final DateTime? evidenceVerifiedAt;

  bool get hasValidSourceUrl {
    final raw = (evidenceSourceUrl ?? '').trim();
    if (raw.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(raw);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  /// 5項目すべてが有効な場合のみ `true` を返す厳格な導出プロパティ。
  bool get evidenceComplete =>
      (targetAudience ?? '').trim().isNotEmpty &&
      (observableLearningOutcome ?? '').trim().isNotEmpty &&
      (assessmentVerificationMethod ?? '').trim().isNotEmpty &&
      hasValidSourceUrl &&
      evidenceVerifiedAt != null;

  List<String> validate() {
    final errors = <String>[];
    if ((targetAudience ?? '').trim().isEmpty) {
      errors.add('target_audience_required');
    }
    if ((observableLearningOutcome ?? '').trim().isEmpty) {
      errors.add('observable_learning_outcome_required');
    }
    if ((assessmentVerificationMethod ?? '').trim().isEmpty) {
      errors.add('assessment_verification_method_required');
    }
    if (!hasValidSourceUrl) {
      errors.add('evidence_source_https_url_required');
    }
    if (evidenceVerifiedAt == null) {
      errors.add('evidence_verified_at_required');
    }
    return List<String>.unmodifiable(errors);
  }
}

/// Allen AI モデル一覧の 1 モデル定義。
class AllenAiModelCatalogEntry {
  const AllenAiModelCatalogEntry({
    required this.modelId,
    required this.family,
    required this.lifecycleStatus,
    required this.contextLength,
    required this.license,
    required this.benchmarkSummary,
    required this.verifiedAt,
    required this.sourceUrl,
  });

  final String modelId;
  final AllenAiModelFamily family;
  final AllenAiLifecycleStatus lifecycleStatus;
  final int contextLength;
  final String license;
  final String benchmarkSummary;
  final DateTime verifiedAt;
  final String sourceUrl;
}

/// 秘密情報を使わない固定 fixture による 2 ワークロード比較評価レコード。
class AllenAiWorkloadTradeoffAssessment {
  const AllenAiWorkloadTradeoffAssessment({
    required this.workloadScale,
    required this.workloadLabel,
    required this.selectedModelId,
    required this.qualityScoreLabel,
    required this.speedLatencyLabel,
    required this.requiredVramGb,
    required this.estimatedCostUsd,
    required this.decision,
    required this.rationale,
    required this.usesFixtureOnly,
  });

  final AllenAiWorkloadScale workloadScale;
  final String workloadLabel;
  final String selectedModelId;
  final String qualityScoreLabel;
  final String speedLatencyLabel;
  final double requiredVramGb;
  final double estimatedCostUsd;
  final AllenAiGoNoGoDecision decision;
  final String rationale;
  final bool usesFixtureOnly;
}

class AllenAiCatalogValidationResult {
  const AllenAiCatalogValidationResult({required this.errors});

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

/// Issue #5301 Part 1: Allen AI (OLMo) 講座カタログの根拠完全性・
/// モデルファミリ/世代管理・2ワークロードトレードオフ評価契約を提供する純粋 Dart サービス。
class AllenAiModelCatalogService {
  const AllenAiModelCatalogService();

  static const String officialOlmoUrl = 'https://allenai.org/olmo';

  /// 現行 OLMo 3/3.1 系と旧版 OLMo 1/2 系を区別した確認日付きカタログ一覧を検証する。
  AllenAiCatalogValidationResult validateCatalog(
    List<AllenAiModelCatalogEntry> entries,
  ) {
    final errors = <String>[];
    if (entries.isEmpty) {
      errors.add('catalog_entries_empty');
      return AllenAiCatalogValidationResult(
        errors: List<String>.unmodifiable(errors),
      );
    }

    var hasCurrentOlmo3Series = false;
    final seenIds = <String>{};

    for (final entry in entries) {
      final id = entry.modelId.trim();
      if (id.isEmpty) {
        errors.add('model_id_required');
      } else if (!seenIds.add(id)) {
        errors.add('duplicate_model_id:$id');
      }
      if (entry.contextLength <= 0) {
        errors.add('invalid_context_length:$id');
      }
      if (entry.license.trim().isEmpty) {
        errors.add('license_required:$id');
      }
      if (entry.benchmarkSummary.trim().isEmpty) {
        errors.add('benchmark_summary_required:$id');
      }
      final uri = Uri.tryParse(entry.sourceUrl.trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        errors.add('invalid_source_url:$id');
      }
      if (entry.family.isLegacy &&
          entry.lifecycleStatus != AllenAiLifecycleStatus.legacy) {
        errors.add('legacy_family_must_have_legacy_status:$id');
      }
      if (!entry.family.isLegacy &&
          entry.lifecycleStatus == AllenAiLifecycleStatus.current) {
        hasCurrentOlmo3Series = true;
      }
    }

    if (!hasCurrentOlmo3Series) {
      errors.add('current_olmo3_series_missing');
    }

    return AllenAiCatalogValidationResult(
      errors: List<String>.unmodifiable(errors),
    );
  }

  /// 単純な用語再生クイズに代わる、小規模/大規模 2 ワークロードのトレードオフ評価を検証する。
  AllenAiCatalogValidationResult validateTradeoffAssessments(
    List<AllenAiWorkloadTradeoffAssessment> assessments,
  ) {
    final errors = <String>[];
    final scales = <AllenAiWorkloadScale>{};

    for (final item in assessments) {
      scales.add(item.workloadScale);
      if (!item.usesFixtureOnly) {
        errors
            .add('static_fixture_only_required:${item.workloadScale.wireName}');
      }
      if (item.workloadLabel.trim().isEmpty) {
        errors.add('workload_label_required:${item.workloadScale.wireName}');
      }
      if (item.selectedModelId.trim().isEmpty) {
        errors.add('selected_model_id_required:${item.workloadScale.wireName}');
      }
      if (item.qualityScoreLabel.trim().isEmpty) {
        errors
            .add('quality_score_label_required:${item.workloadScale.wireName}');
      }
      if (item.speedLatencyLabel.trim().isEmpty) {
        errors
            .add('speed_latency_label_required:${item.workloadScale.wireName}');
      }
      if (!item.requiredVramGb.isFinite || item.requiredVramGb < 0) {
        errors.add('invalid_required_vram:${item.workloadScale.wireName}');
      }
      if (!item.estimatedCostUsd.isFinite || item.estimatedCostUsd < 0) {
        errors.add('invalid_estimated_cost:${item.workloadScale.wireName}');
      }
      if (item.rationale.trim().isEmpty) {
        errors
            .add('decision_rationale_required:${item.workloadScale.wireName}');
      }
    }

    if (!scales.contains(AllenAiWorkloadScale.smallWorkload)) {
      errors.add('small_workload_assessment_missing');
    }
    if (!scales.contains(AllenAiWorkloadScale.largeWorkload)) {
      errors.add('large_workload_assessment_missing');
    }

    return AllenAiCatalogValidationResult(
      errors: List<String>.unmodifiable(errors),
    );
  }

  /// 秘密情報を使わない固定 2 ワークロード評価 fixture を生成する。
  List<AllenAiWorkloadTradeoffAssessment> buildTwoWorkloadFixture() {
    return const <AllenAiWorkloadTradeoffAssessment>[
      AllenAiWorkloadTradeoffAssessment(
        workloadScale: AllenAiWorkloadScale.smallWorkload,
        workloadLabel: '小規模: 短文要約・単発分類（合成fixture）',
        selectedModelId: 'olmo-3-7b-instruct',
        qualityScoreLabel: '必要十分な構造化精度',
        speedLatencyLabel: '低レイテンシ（単一GPU動作）',
        requiredVramGb: 16.0,
        estimatedCostUsd: 0.45,
        decision: AllenAiGoNoGoDecision.go,
        rationale: '単一16GB級GPUで速度とコストのバランスが良く採用。',
        usesFixtureOnly: true,
      ),
      AllenAiWorkloadTradeoffAssessment(
        workloadScale: AllenAiWorkloadScale.largeWorkload,
        workloadLabel: '大規模: 長文推論・バッチ評価（合成fixture）',
        selectedModelId: 'olmo-3.1-32b-instruct',
        qualityScoreLabel: '高い長文整合性',
        speedLatencyLabel: '中速（複数GPUまたは量子化要）',
        requiredVramGb: 64.0,
        estimatedCostUsd: 3.80,
        decision: AllenAiGoNoGoDecision.noGo,
        rationale: '予算上限・単一GPU制約を超えるため現段階では見送り。',
        usesFixtureOnly: true,
      ),
    ];
  }
}
