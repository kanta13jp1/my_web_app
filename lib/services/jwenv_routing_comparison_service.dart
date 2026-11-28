/// Jwenv の曖昧入力を「要確認」へ回す判定方式を合成データで比較するための
/// 純粋な契約・評価サービス（UI / ネットワーク / 実家計データ非依存）。
///
/// 小標本・AI仮ラベルに基づく集計であり、本番精度や安全性を保証しない。
library;

/// 比較対象の判定方式。
enum JwenvRoutingMode {
  /// 既存: 12カテゴリそれぞれへの独立 Yes/No。
  independentYesNo12('independent_yes_no_12'),

  /// 12カテゴリ Yes/No + 明示的な「情報不足」選択肢。
  yesNoWithInsufficientInfo12('yes_no_with_insufficient_info_12'),

  /// 1回あたり最大8択の階層方式。
  hierarchicalMax8('hierarchical_max_8');

  const JwenvRoutingMode(this.wireName);

  final String wireName;
}

enum JwenvDatasetSplit { development, evaluation }

/// 合成ケースの期待種別（モデル出力取得前に固定する仮ラベル）。
enum JwenvExpectedKind { clear, insufficientInfo }

/// 推論の実行種別。モックと実推論を混同しない。
enum JwenvInferenceKind { mock, live }

class JwenvCategories {
  const JwenvCategories._();

  /// 既存 12 カテゴリ。カテゴリ優先規則の順序でもある（先頭ほど優先）。
  static const List<String> priorityOrdered = <String>[
    'medical',
    'housing',
    'utilities',
    'telecom',
    'transport',
    'subscription_entertainment',
    'dining_out',
    'cafe_snack',
    'convenience',
    'food',
    'daily_necessities',
    'other',
  ];

  static const String insufficientInfoOption = 'insufficient_info';

  static final Set<String> _all = Set<String>.unmodifiable(priorityOrdered);

  static bool contains(String category) => _all.contains(category);

  /// 複数カテゴリが該当する場合に、固定の優先規則で 1 件に解決する。
  static String? resolveByPriority(Iterable<String> matched) {
    final set = matched.toSet();
    for (final category in priorityOrdered) {
      if (set.contains(category)) {
        return category;
      }
    }
    return null;
  }
}

/// 合成ケース 1 件（実家計データは含めない）。
class JwenvSyntheticCase {
  const JwenvSyntheticCase({
    required this.caseId,
    required this.memo,
    required this.originGroup,
    required this.split,
    required this.expectedKind,
    required this.provisionalLabel,
    required this.labelLockedBeforeModelOutput,
    this.labelSource = 'ai_provisional',
  });

  final String caseId;
  final String memo;

  /// 由来の群。開発用と評価用で共有しない。
  final String originGroup;
  final JwenvDatasetSplit split;
  final JwenvExpectedKind expectedKind;

  /// `expectedKind == clear` のとき 12 カテゴリのいずれか。情報不足なら null。
  final String? provisionalLabel;
  final bool labelLockedBeforeModelOutput;
  final String labelSource;
}

class JwenvValidation {
  const JwenvValidation(this.errors);

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

/// 旧モデル・エンジンの固定来歴。
class JwenvProvenance {
  const JwenvProvenance({
    required this.modelId,
    required this.modelSha,
    required this.engineId,
    required this.engineSha,
  });

  final String modelId;
  final String modelSha;
  final String engineId;
  final String engineSha;

  static final RegExp _sha40 = RegExp(r'^[0-9a-f]{40}$');

  List<String> validate() {
    final errors = <String>[];
    if (modelId.trim().isEmpty) errors.add('model_id_required');
    if (engineId.trim().isEmpty) errors.add('engine_id_required');
    if (!_sha40.hasMatch(modelSha.trim())) {
      errors.add('model_sha_must_be_40_hex');
    }
    if (!_sha40.hasMatch(engineSha.trim())) {
      errors.add('engine_sha_must_be_40_hex');
    }
    return List<String>.unmodifiable(errors);
  }
}

/// 1 リクエスト分の保存対象テレメトリ（全スコア・実プロンプト・候補順・時間・失敗）。
class JwenvRoutingTelemetry {
  const JwenvRoutingTelemetry({
    required this.caseId,
    required this.mode,
    required this.inferenceKind,
    required this.provenance,
    required this.prompt,
    required this.candidateOrder,
    required this.logits,
    required this.rawResponse,
    required this.latencyMs,
    this.confirmedCategory,
    this.routedToReview = false,
    this.failureReason,
  });

  final String caseId;
  final JwenvRoutingMode mode;
  final JwenvInferenceKind inferenceKind;
  final JwenvProvenance provenance;
  final String prompt;
  final List<String> candidateOrder;
  final Map<String, double> logits;
  final String rawResponse;
  final double latencyMs;

  /// 確定したカテゴリ。要確認へ回した場合・失敗時は null。
  final String? confirmedCategory;
  final bool routedToReview;
  final String? failureReason;

  bool get failed => (failureReason ?? '').trim().isNotEmpty;
}

class JwenvDiagnosticPlan {
  const JwenvDiagnosticPlan({
    required this.requestCaseIds,
    required this.maxRequests,
    required this.stepBudgetMinutes,
    required this.perRequestBudgetMinutes,
  });

  final List<String> requestCaseIds;
  final int maxRequests;
  final int stepBudgetMinutes;
  final int perRequestBudgetMinutes;
}

class JwenvModeMetrics {
  const JwenvModeMetrics({
    required this.mode,
    required this.sampleSize,
    required this.failureCount,
    required this.routedToReviewCount,
    required this.rejectionRate,
    required this.inappropriateConfirmationCount,
    required this.inappropriateConfirmationRate,
    required this.overRejectionCount,
    required this.overRejectionRate,
    required this.caveat,
  });

  final JwenvRoutingMode mode;

  /// 失敗を除いた有効応答数。
  final int sampleSize;
  final int failureCount;
  final int routedToReviewCount;

  /// 要確認へ回した割合（有効応答に対する）。算出不能時は null。
  final double? rejectionRate;

  /// 情報不足の入力をカテゴリ確定してしまった件数と割合（情報不足ケースに対する）。
  final int inappropriateConfirmationCount;
  final double? inappropriateConfirmationRate;

  /// 明確な入力を要確認へ回した件数と割合（明確ケースに対する）。
  final int overRejectionCount;
  final double? overRejectionRate;
  final String caveat;
}

class JwenvRoutingComparisonService {
  const JwenvRoutingComparisonService();

  static const int maxOptionsPerRequest = 8;
  static const int initialMaxRequests = 8;
  static const int initialStepBudgetMinutes = 45;
  static const int initialPerRequestBudgetMinutes = 15;

  static const String smallSampleCaveat = '小標本かつAI作成の仮ラベルに基づく合成データ比較であり、'
      '本番精度・安全性・購入判断の妥当性を保証しない';

  /// データセット契約: 分割・ラベル整合・仮ラベル事前固定を検証する。
  JwenvValidation validateDataset(List<JwenvSyntheticCase> cases) {
    final errors = <String>[];
    final ids = <String>{};
    final groupSplits = <String, Set<JwenvDatasetSplit>>{};

    for (final item in cases) {
      if (item.caseId.trim().isEmpty) {
        errors.add('case_id_required');
      } else if (!ids.add(item.caseId)) {
        errors.add('duplicate_case_id:${item.caseId}');
      }
      final memo = item.memo.trim();
      if (memo.isEmpty || memo.length > 500) {
        errors.add('invalid_memo:${item.caseId}');
      }
      if (item.originGroup.trim().isEmpty) {
        errors.add('origin_group_required:${item.caseId}');
      } else {
        groupSplits
            .putIfAbsent(item.originGroup, () => <JwenvDatasetSplit>{})
            .add(item.split);
      }
      if (!item.labelLockedBeforeModelOutput) {
        errors.add('label_must_be_locked_before_model_output:${item.caseId}');
      }
      switch (item.expectedKind) {
        case JwenvExpectedKind.clear:
          final label = item.provisionalLabel;
          if (label == null || !JwenvCategories.contains(label)) {
            errors.add('clear_case_requires_category_label:${item.caseId}');
          }
          break;
        case JwenvExpectedKind.insufficientInfo:
          if (item.provisionalLabel != null) {
            errors.add(
              'insufficient_case_must_not_have_category:${item.caseId}',
            );
          }
          break;
      }
    }

    for (final entry in groupSplits.entries) {
      if (entry.value.length > 1) {
        errors.add('origin_group_spans_splits:${entry.key}');
      }
    }
    return JwenvValidation(List<String>.unmodifiable(errors));
  }

  /// 階層方式: 各段階の選択肢は最大 8 件。
  JwenvValidation validateHierarchy(List<List<String>> stageOptions) {
    final errors = <String>[];
    if (stageOptions.isEmpty) {
      errors.add('hierarchy_requires_stage');
    }
    for (var i = 0; i < stageOptions.length; i++) {
      final options = stageOptions[i];
      if (options.isEmpty) {
        errors.add('stage_${i}_has_no_options');
      }
      if (options.length > maxOptionsPerRequest) {
        errors.add('stage_${i}_exceeds_max_8_options');
      }
      if (options.toSet().length != options.length) {
        errors.add('stage_${i}_has_duplicate_options');
      }
    }
    return JwenvValidation(List<String>.unmodifiable(errors));
  }

  /// 初回クラウド診断計画: 開発用のみ・最大8要求・45分/15分、未使用評価用は実行しない。
  JwenvValidation validateInitialDiagnosticPlan(
    JwenvDiagnosticPlan plan,
    List<JwenvSyntheticCase> cases,
  ) {
    final errors = <String>[];
    final byId = <String, JwenvSyntheticCase>{
      for (final item in cases) item.caseId: item,
    };
    if (plan.requestCaseIds.isEmpty) {
      errors.add('plan_requires_requests');
    }
    if (plan.maxRequests > initialMaxRequests ||
        plan.requestCaseIds.length > initialMaxRequests) {
      errors.add('plan_exceeds_max_8_requests');
    }
    if (plan.stepBudgetMinutes > initialStepBudgetMinutes) {
      errors.add('plan_exceeds_45_minute_step_budget');
    }
    if (plan.perRequestBudgetMinutes > initialPerRequestBudgetMinutes) {
      errors.add('plan_exceeds_15_minute_request_budget');
    }
    final distinctCases = plan.requestCaseIds.toSet();
    var clearCount = 0;
    var insufficientCount = 0;
    for (final caseId in distinctCases) {
      final item = byId[caseId];
      if (item == null) {
        errors.add('plan_references_unknown_case:$caseId');
        continue;
      }
      if (item.split == JwenvDatasetSplit.evaluation) {
        errors.add('plan_must_not_run_unused_evaluation_case:$caseId');
      }
      if (item.expectedKind == JwenvExpectedKind.clear) {
        clearCount++;
      } else {
        insufficientCount++;
      }
    }
    if (clearCount != 1 || insufficientCount != 1) {
      errors.add('initial_plan_requires_one_clear_and_one_insufficient_case');
    }
    return JwenvValidation(List<String>.unmodifiable(errors));
  }

  /// テレメトリ契約: 全スコア保存・候補順・来歴・モック/実推論の区別・失敗の保持。
  JwenvValidation validateTelemetry(JwenvRoutingTelemetry record) {
    final errors = <String>[];
    errors.addAll(record.provenance.validate());
    if (record.caseId.trim().isEmpty) errors.add('case_id_required');
    if (record.prompt.trim().isEmpty) errors.add('prompt_required');
    if (!record.latencyMs.isFinite || record.latencyMs < 0) {
      errors.add('latency_must_be_finite_non_negative');
    }

    final order = record.candidateOrder;
    if (order.toSet().length != order.length) {
      errors.add('candidate_order_has_duplicates');
    }
    _validateCandidateSet(record.mode, order, errors);

    if (record.failed) {
      if (record.confirmedCategory != null || record.routedToReview) {
        errors.add('failed_request_must_not_carry_decision');
      }
    } else {
      if (record.rawResponse.trim().isEmpty) {
        errors.add('raw_response_required');
      }
      final logitKeys = record.logits.keys.toSet();
      if (logitKeys.length != order.length || !logitKeys.containsAll(order)) {
        errors.add('logits_must_cover_every_candidate');
      }
      if (record.logits.values.any((value) => !value.isFinite)) {
        errors.add('logits_must_be_finite');
      }
      final confirmed = record.confirmedCategory;
      if (confirmed != null) {
        if (record.routedToReview) {
          errors.add('confirmed_and_review_are_exclusive');
        }
        if (!JwenvCategories.contains(confirmed)) {
          errors.add('confirmed_category_not_in_12_categories');
        }
      } else if (!record.routedToReview) {
        errors.add('decision_required_for_successful_request');
      }
    }
    return JwenvValidation(List<String>.unmodifiable(errors));
  }

  void _validateCandidateSet(
    JwenvRoutingMode mode,
    List<String> order,
    List<String> errors,
  ) {
    switch (mode) {
      case JwenvRoutingMode.independentYesNo12:
        if (order.length != 12 ||
            !order.toSet().containsAll(JwenvCategories.priorityOrdered)) {
          errors.add('mode_requires_exactly_12_categories');
        }
        break;
      case JwenvRoutingMode.yesNoWithInsufficientInfo12:
        final expected = <String>{
          ...JwenvCategories.priorityOrdered,
          JwenvCategories.insufficientInfoOption,
        };
        if (order.length != 13 || !order.toSet().containsAll(expected)) {
          errors.add('mode_requires_12_categories_plus_insufficient_option');
        }
        break;
      case JwenvRoutingMode.hierarchicalMax8:
        if (order.isEmpty || order.length > maxOptionsPerRequest) {
          errors.add('hierarchical_request_exceeds_max_8_options');
        }
        break;
    }
  }

  /// 方式ごとに棄却率と不適切な確定（および明確入力の過剰棄却）を両方集計する。
  List<JwenvModeMetrics> evaluate({
    required List<JwenvSyntheticCase> cases,
    required List<JwenvRoutingTelemetry> telemetry,
  }) {
    final byId = <String, JwenvSyntheticCase>{
      for (final item in cases) item.caseId: item,
    };
    final result = <JwenvModeMetrics>[];
    for (final mode in JwenvRoutingMode.values) {
      var sampleSize = 0;
      var failureCount = 0;
      var reviewCount = 0;
      var insufficientTotal = 0;
      var inappropriate = 0;
      var clearTotal = 0;
      var overRejected = 0;

      for (final record in telemetry.where((item) => item.mode == mode)) {
        if (record.failed) {
          failureCount++;
          continue;
        }
        final item = byId[record.caseId];
        if (item == null) {
          continue;
        }
        sampleSize++;
        if (record.routedToReview) {
          reviewCount++;
        }
        if (item.expectedKind == JwenvExpectedKind.insufficientInfo) {
          insufficientTotal++;
          if (record.confirmedCategory != null) {
            inappropriate++;
          }
        } else {
          clearTotal++;
          if (record.routedToReview) {
            overRejected++;
          }
        }
      }

      result.add(
        JwenvModeMetrics(
          mode: mode,
          sampleSize: sampleSize,
          failureCount: failureCount,
          routedToReviewCount: reviewCount,
          rejectionRate: sampleSize > 0 ? reviewCount / sampleSize : null,
          inappropriateConfirmationCount: inappropriate,
          inappropriateConfirmationRate:
              insufficientTotal > 0 ? inappropriate / insufficientTotal : null,
          overRejectionCount: overRejected,
          overRejectionRate: clearTotal > 0 ? overRejected / clearTotal : null,
          caveat: smallSampleCaveat,
        ),
      );
    }
    return List<JwenvModeMetrics>.unmodifiable(result);
  }
}
