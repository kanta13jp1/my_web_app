/// Aleph Alpha 講座カタログ（利用可能モデル）の根拠完全性・提供状態・
/// 2 ワークロードのトレードオフ評価を扱う純粋サービス（UI / ネットワーク非依存）。
library;

/// 提供系統。Pharia と Luminous を混同しない。
enum AlephAlphaProviderVariant {
  pharia('pharia'),
  luminous('luminous');

  const AlephAlphaProviderVariant(this.wireName);

  final String wireName;
}

/// モデルの提供状態。
enum AlephAlphaAvailability {
  available('available'),
  deprecated('deprecated'),
  retired('retired');

  const AlephAlphaAvailability(this.wireName);

  final String wireName;
}

/// 根拠 URL の検証結果。
enum AlephAlphaLinkStatus {
  /// 遷移先でモデル名・文脈長・提供状態を確認できた。
  verifiedVariants('verified_variants'),

  /// ホーム/マーケティングページへ転送され、モデル一覧を確認できない。
  redirectMismatch('redirect_mismatch'),

  /// 到達できない。
  unreachable('unreachable'),

  /// まだ検証していない。
  unverified('unverified');

  const AlephAlphaLinkStatus(this.wireName);

  final String wireName;
}

enum AlephAlphaWorkloadKind {
  documentQuestionAnswering('document_question_answering'),
  structuredExtraction('structured_extraction');

  const AlephAlphaWorkloadKind(this.wireName);

  final String wireName;
}

enum AlephAlphaGoNoGo {
  go('go'),
  noGo('no_go');

  const AlephAlphaGoNoGo(this.wireName);

  final String wireName;
}

/// 講座行の根拠完全性契約。
///
/// `evidenceComplete` は 5 項目とリンク検証結果から厳密に導出される。
/// いずれかが空、または根拠 URL が転送先不一致・未検証なら `true` にならない。
class AlephAlphaEvidenceContract {
  const AlephAlphaEvidenceContract({
    this.targetAudience,
    this.observableLearningOutcome,
    this.assessmentVerificationMethod,
    this.evidenceSourceUrl,
    this.evidenceVerifiedAt,
    this.linkStatus = AlephAlphaLinkStatus.unverified,
  });

  final String? targetAudience;
  final String? observableLearningOutcome;
  final String? assessmentVerificationMethod;
  final String? evidenceSourceUrl;
  final DateTime? evidenceVerifiedAt;
  final AlephAlphaLinkStatus linkStatus;

  bool get hasValidSourceUrl {
    final raw = (evidenceSourceUrl ?? '').trim();
    if (raw.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(raw);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  bool get evidenceComplete =>
      (targetAudience ?? '').trim().isNotEmpty &&
      (observableLearningOutcome ?? '').trim().isNotEmpty &&
      (assessmentVerificationMethod ?? '').trim().isNotEmpty &&
      hasValidSourceUrl &&
      evidenceVerifiedAt != null &&
      linkStatus == AlephAlphaLinkStatus.verifiedVariants;

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
    switch (linkStatus) {
      case AlephAlphaLinkStatus.verifiedVariants:
        break;
      case AlephAlphaLinkStatus.redirectMismatch:
        errors.add('source_url_redirects_to_unverified_destination');
        break;
      case AlephAlphaLinkStatus.unreachable:
        errors.add('source_url_unreachable');
        break;
      case AlephAlphaLinkStatus.unverified:
        errors.add('source_url_not_verified');
        break;
    }
    return List<String>.unmodifiable(errors);
  }
}

/// 利用可能モデル一覧の 1 行。
class AlephAlphaModelEntry {
  const AlephAlphaModelEntry({
    required this.modelId,
    required this.variant,
    required this.availability,
    required this.contextLength,
    required this.verifiedAt,
    required this.sourceUrl,
  });

  final String modelId;
  final AlephAlphaProviderVariant variant;
  final AlephAlphaAvailability availability;
  final int contextLength;
  final DateTime verifiedAt;
  final String sourceUrl;
}

/// 2 ワークロードのトレードオフ評価の 1 候補。
class AlephAlphaCandidateAssessment {
  const AlephAlphaCandidateAssessment({
    required this.modelId,
    required this.quality,
    required this.speed,
    required this.estimatedCostYen,
    required this.explainability,
  });

  final String modelId;

  /// 0.0〜1.0 の相対評価（固定 fixture 上の値であり実測ではない）。
  final double quality;
  final double speed;
  final int estimatedCostYen;
  final double explainability;
}

class AlephAlphaWorkloadAssessment {
  const AlephAlphaWorkloadAssessment({
    required this.workload,
    required this.candidates,
    required this.decision,
    required this.decisionReason,
  });

  final AlephAlphaWorkloadKind workload;
  final List<AlephAlphaCandidateAssessment> candidates;
  final AlephAlphaGoNoGo decision;
  final String decisionReason;
}

/// 固定 fixture による 2 ワークロード比較。実測・外部呼び出しを含まない。
class AlephAlphaTradeoffFixture {
  const AlephAlphaTradeoffFixture({
    required this.usesFixtureOnly,
    required this.workloads,
  });

  final bool usesFixtureOnly;
  final List<AlephAlphaWorkloadAssessment> workloads;
}

class AlephAlphaValidation {
  const AlephAlphaValidation(this.errors);

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

class AlephAlphaModelCatalogService {
  const AlephAlphaModelCatalogService();

  static const int requiredWorkloadCount = 2;

  /// モデル一覧の検証。`now` より未来の確認日時・重複 ID・不正な文脈長を拒否する。
  AlephAlphaValidation validateModels(
    List<AlephAlphaModelEntry> models, {
    required DateTime now,
  }) {
    final errors = <String>[];
    final ids = <String>{};
    for (final model in models) {
      final id = model.modelId.trim();
      if (id.isEmpty) {
        errors.add('model_id_required');
      } else if (!ids.add(id)) {
        errors.add('duplicate_model_id:$id');
      }
      if (model.contextLength <= 0) {
        errors.add('context_length_must_be_positive:$id');
      }
      if (model.verifiedAt.isAfter(now)) {
        errors.add('verified_at_in_future:$id');
      }
      final uri = Uri.tryParse(model.sourceUrl.trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        errors.add('source_https_url_required:$id');
      }
    }
    return AlephAlphaValidation(List<String>.unmodifiable(errors));
  }

  /// 系統ごとの件数。Pharia と Luminous の主張を分けて確認するために使う。
  Map<AlephAlphaProviderVariant, int> countByVariant(
    List<AlephAlphaModelEntry> models,
  ) {
    return <AlephAlphaProviderVariant, int>{
      for (final variant in AlephAlphaProviderVariant.values)
        variant: models.where((model) => model.variant == variant).length,
    };
  }

  /// 現在利用を勧められるモデル（`available` のみ）。
  List<AlephAlphaModelEntry> recommendable(List<AlephAlphaModelEntry> models) {
    return models.where(_isAvailable).toList(growable: false);
  }

  static bool _isAvailable(AlephAlphaModelEntry model) {
    return model.availability == AlephAlphaAvailability.available;
  }

  /// 2 ワークロードの固定 fixture を検証する。
  AlephAlphaValidation validateTradeoffFixture(
    AlephAlphaTradeoffFixture fixture,
    List<AlephAlphaModelEntry> models,
  ) {
    final errors = <String>[];
    if (!fixture.usesFixtureOnly) {
      errors.add('fixture_only_required');
    }
    if (fixture.workloads.length != requiredWorkloadCount ||
        fixture.workloads.map((item) => item.workload).toSet().length !=
            requiredWorkloadCount) {
      errors.add('exactly_two_distinct_workloads_required');
    }
    final byId = <String, AlephAlphaModelEntry>{
      for (final model in models) model.modelId: model,
    };
    for (final workload in fixture.workloads) {
      final label = workload.workload.wireName;
      if (workload.candidates.isEmpty) {
        errors.add('candidates_required:$label');
      }
      if (workload.decisionReason.trim().isEmpty) {
        errors.add('decision_reason_required:$label');
      }
      var hasRecommendableCandidate = false;
      for (final candidate in workload.candidates) {
        final entry = byId[candidate.modelId];
        if (entry == null) {
          errors.add('unknown_candidate_model:${candidate.modelId}');
          continue;
        }
        if (entry.availability == AlephAlphaAvailability.retired) {
          errors.add('retired_model_cannot_be_candidate:${candidate.modelId}');
        }
        if (entry.availability == AlephAlphaAvailability.available) {
          hasRecommendableCandidate = true;
        }
        if (!_isUnitScore(candidate.quality) ||
            !_isUnitScore(candidate.speed) ||
            !_isUnitScore(candidate.explainability)) {
          errors.add('scores_must_be_within_0_and_1:${candidate.modelId}');
        }
        if (candidate.estimatedCostYen < 0) {
          errors
              .add('estimated_cost_must_not_be_negative:${candidate.modelId}');
        }
      }
      if (workload.decision == AlephAlphaGoNoGo.go &&
          !hasRecommendableCandidate) {
        errors.add('go_requires_available_candidate:$label');
      }
    }
    return AlephAlphaValidation(List<String>.unmodifiable(errors));
  }

  static bool _isUnitScore(double value) {
    return value.isFinite && value >= 0 && value <= 1;
  }
}
