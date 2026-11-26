/// Default minimum distinct tenants required for opt-in global promotion (#2775).
const int kDefaultMinQualifyingTenants = 3;

/// Default minimum per-tenant evaluation score (`0.0` - `1.0`) to qualify (#2775).
const double kDefaultPromotionThreshold = 0.7;

/// Composite ranking weight for tenant-local evaluation score (70%).
const double kLocalScoreWeight = 0.70;

/// Composite ranking weight for globally promoted score (20%).
const double kGlobalScoreWeight = 0.20;

/// Composite ranking weight for normalized usage performance score (10%).
const double kUsageScoreWeight = 0.10;

/// Configurable thresholds and ranking weights for opt-in promotion (#2775).
class GlobalOptInConfig {
  const GlobalOptInConfig({
    this.minQualifyingTenants = kDefaultMinQualifyingTenants,
    this.promotionThreshold = kDefaultPromotionThreshold,
    this.localWeight = kLocalScoreWeight,
    this.globalWeight = kGlobalScoreWeight,
    this.usageWeight = kUsageScoreWeight,
  })  : assert(minQualifyingTenants >= 1),
        assert(promotionThreshold >= 0.0 && promotionThreshold <= 1.0);

  final int minQualifyingTenants;
  final double promotionThreshold;
  final double localWeight;
  final double globalWeight;
  final double usageWeight;
}

/// Lifecycle state of an item's global promotion eligibility (#2775).
enum GlobalPromotionStatus {
  localOnly(apiValue: 'local_only', label: 'ローカル限定'),
  promoted(apiValue: 'promoted', label: 'グローバル昇格済'),
  demoted(apiValue: 'demoted', label: '昇格解除');

  const GlobalPromotionStatus({
    required this.apiValue,
    required this.label,
  });

  final String apiValue;
  final String label;
}

/// Tenant-scoped evaluation record stored independently per `(tenantId, itemId)` (#2775).
class TenantItemEvaluation {
  const TenantItemEvaluation({
    required this.tenantId,
    required this.itemId,
    required this.score,
    this.usageScore = 0.0,
    required this.updatedAt,
  });

  final String tenantId;
  final String itemId;
  final double score;
  final double usageScore;
  final DateTime updatedAt;

  TenantItemEvaluation normalized() {
    return TenantItemEvaluation(
      tenantId: tenantId.trim(),
      itemId: itemId.trim(),
      score: score.clamp(0.0, 1.0).toDouble(),
      usageScore: usageScore.clamp(0.0, 1.0).toDouble(),
      updatedAt: updatedAt,
    );
  }
}

/// Global promotion state evaluated across distinct tenants (#2775).
class GlobalPromotedRecord {
  const GlobalPromotedRecord({
    required this.itemId,
    required this.status,
    required this.isGlobalPromoted,
    required this.qualifyingTenantCount,
    required this.globalScore,
    required this.evaluatedAt,
  });

  final String itemId;
  final GlobalPromotionStatus status;
  final bool isGlobalPromoted;
  final int qualifyingTenantCount;
  final double globalScore;
  final DateTime evaluatedAt;
}

/// Result summary from `runPromotionAndDemotionSweep` (#2775).
class PromotionSweepResult {
  const PromotionSweepResult({
    required this.evaluatedItems,
    required this.promotedCount,
    required this.demotedCount,
    required this.activeGlobalCount,
    required this.records,
  });

  final int evaluatedItems;
  final int promotedCount;
  final int demotedCount;
  final int activeGlobalCount;
  final List<GlobalPromotedRecord> records;
}

/// Ranked search/recommendation entry using `70% local + 20% global + 10% usage` (#2775).
class RankedOptInItem {
  const RankedOptInItem({
    required this.itemId,
    required this.tenantId,
    required this.localScore,
    required this.globalScore,
    required this.usageScore,
    required this.compositeScore,
    required this.isGlobalPromoted,
  });

  final String itemId;
  final String tenantId;
  final double localScore;
  final double globalScore;
  final double usageScore;
  final double compositeScore;
  final bool isGlobalPromoted;
}

/// Abstract tenant-scoped storage contract (`0` DB migrations / `hub_data` compatible) (#2775).
abstract class TenantEvaluationStore {
  Future<void> upsertEvaluation(final TenantItemEvaluation evaluation);

  Future<void> removeEvaluation({
    required final String tenantId,
    required final String itemId,
  });

  Future<List<TenantItemEvaluation>> listEvaluationsForItem(
    final String itemId,
  );

  Future<List<TenantItemEvaluation>> listAllEvaluations();

  Future<GlobalPromotedRecord?> getGlobalRecord(final String itemId);

  Future<List<GlobalPromotedRecord>> listGlobalRecords();

  Future<void> saveGlobalRecord(final GlobalPromotedRecord record);
}

/// Pure in-memory store enforcing strict per-tenant isolation for tests & offline runs (#2775).
class InMemoryTenantEvaluationStore implements TenantEvaluationStore {
  final Map<String, Map<String, TenantItemEvaluation>> _byTenant =
      <String, Map<String, TenantItemEvaluation>>{};
  final Map<String, GlobalPromotedRecord> _global =
      <String, GlobalPromotedRecord>{};

  @override
  Future<void> upsertEvaluation(final TenantItemEvaluation evaluation) async {
    final normalized = evaluation.normalized();
    if (normalized.tenantId.isEmpty || normalized.itemId.isEmpty) {
      throw ArgumentError('tenantId and itemId must be non-empty');
    }
    final tenantMap = _byTenant.putIfAbsent(
      normalized.tenantId,
      () => <String, TenantItemEvaluation>{},
    );
    tenantMap[normalized.itemId] = normalized;
  }

  @override
  Future<void> removeEvaluation({
    required final String tenantId,
    required final String itemId,
  }) async {
    _byTenant[tenantId.trim()]?.remove(itemId.trim());
  }

  @override
  Future<List<TenantItemEvaluation>> listEvaluationsForItem(
    final String itemId,
  ) async {
    final targetId = itemId.trim();
    final results = <TenantItemEvaluation>[];
    for (final tenantMap in _byTenant.values) {
      final entry = tenantMap[targetId];
      if (entry != null) {
        results.add(entry);
      }
    }
    return List<TenantItemEvaluation>.unmodifiable(results);
  }

  @override
  Future<List<TenantItemEvaluation>> listAllEvaluations() async {
    final results = <TenantItemEvaluation>[];
    for (final tenantMap in _byTenant.values) {
      results.addAll(tenantMap.values);
    }
    return List<TenantItemEvaluation>.unmodifiable(results);
  }

  @override
  Future<GlobalPromotedRecord?> getGlobalRecord(final String itemId) async {
    return _global[itemId.trim()];
  }

  @override
  Future<List<GlobalPromotedRecord>> listGlobalRecords() async {
    return List<GlobalPromotedRecord>.unmodifiable(_global.values);
  }

  @override
  Future<void> saveGlobalRecord(final GlobalPromotedRecord record) async {
    _global[record.itemId] = record;
  }
}

/// Service implementing multi-tenant opt-in global promotion, `demotion_sweep`, and ranking (#2775).
class GlobalOptInPromotionService {
  GlobalOptInPromotionService({
    required final TenantEvaluationStore store,
    this.config = const GlobalOptInConfig(),
    final DateTime Function()? nowProvider,
  })  : _store = store,
        _nowProvider = nowProvider ?? DateTime.now;

  final TenantEvaluationStore _store;
  final GlobalOptInConfig config;
  final DateTime Function() _nowProvider;

  /// Records/updates a tenant-scoped score without polluting other tenants (#2775).
  Future<void> recordTenantEvaluation({
    required final String tenantId,
    required final String itemId,
    required final double score,
    final double usageScore = 0.0,
  }) async {
    await _store.upsertEvaluation(
      TenantItemEvaluation(
        tenantId: tenantId,
        itemId: itemId,
        score: score,
        usageScore: usageScore,
        updatedAt: _nowProvider().toUtc(),
      ),
    );
  }

  /// Evaluates a single item across distinct tenants (`>= minQualifyingTenants` at `>= promotionThreshold`).
  Future<GlobalPromotedRecord> evaluateItemPromotion(
    final String itemId,
  ) async {
    final targetId = itemId.trim();
    final evaluations = await _store.listEvaluationsForItem(targetId);
    final previous = await _store.getGlobalRecord(targetId);

    // Deduplicate by tenantId keeping the latest evaluation per tenant.
    final latestByTenant = <String, TenantItemEvaluation>{};
    for (final eval in evaluations) {
      final existing = latestByTenant[eval.tenantId];
      if (existing == null || eval.updatedAt.isAfter(existing.updatedAt)) {
        latestByTenant[eval.tenantId] = eval;
      }
    }

    final qualifyingScores = <double>[];
    for (final eval in latestByTenant.values) {
      if (eval.score >= config.promotionThreshold) {
        qualifyingScores.add(eval.score);
      }
    }

    final qualifyingCount = qualifyingScores.length;
    final qualifies = qualifyingCount >= config.minQualifyingTenants;
    final double meanScore;
    if (qualifyingScores.isEmpty) {
      meanScore = 0.0;
    } else {
      final sum = qualifyingScores.reduce(
        (final double a, final double b) => a + b,
      );
      meanScore = (sum / qualifyingScores.length).clamp(0.0, 1.0).toDouble();
    }

    final GlobalPromotionStatus nextStatus;
    if (qualifies) {
      nextStatus = GlobalPromotionStatus.promoted;
    } else if (previous != null && previous.isGlobalPromoted) {
      nextStatus = GlobalPromotionStatus.demoted;
    } else {
      nextStatus = GlobalPromotionStatus.localOnly;
    }

    final nextRecord = GlobalPromotedRecord(
      itemId: targetId,
      status: nextStatus,
      isGlobalPromoted: qualifies,
      qualifyingTenantCount: qualifyingCount,
      globalScore: qualifies ? meanScore : 0.0,
      evaluatedAt: _nowProvider().toUtc(),
    );
    await _store.saveGlobalRecord(nextRecord);
    return nextRecord;
  }

  /// Periodic batch (`promotion` + `demotion_sweep`) across all evaluated & promoted items (#2775).
  Future<PromotionSweepResult> runPromotionAndDemotionSweep() async {
    final allEvaluations = await _store.listAllEvaluations();
    final existingGlobals = await _store.listGlobalRecords();

    final itemIds = <String>{
      for (final eval in allEvaluations) eval.itemId,
      for (final record in existingGlobals) record.itemId,
    };

    var promotedCount = 0;
    var demotedCount = 0;
    var activeGlobalCount = 0;
    final updatedRecords = <GlobalPromotedRecord>[];

    final sortedIds = itemIds.toList(growable: false)..sort();
    for (final itemId in sortedIds) {
      final prev = await _store.getGlobalRecord(itemId);
      final next = await evaluateItemPromotion(itemId);
      updatedRecords.add(next);
      if (next.isGlobalPromoted) {
        activeGlobalCount += 1;
        if (prev == null || !prev.isGlobalPromoted) {
          promotedCount += 1;
        }
      } else if (prev != null && prev.isGlobalPromoted) {
        demotedCount += 1;
      }
    }

    return PromotionSweepResult(
      evaluatedItems: sortedIds.length,
      promotedCount: promotedCount,
      demotedCount: demotedCount,
      activeGlobalCount: activeGlobalCount,
      records: List<GlobalPromotedRecord>.unmodifiable(updatedRecords),
    );
  }

  /// Computes `0.70 * localScore + 0.20 * globalScore + 0.10 * usageScore` bounded `[0.0, 1.0]`.
  double computeCompositeScore({
    required final double localScore,
    required final double globalScore,
    required final double usageScore,
  }) {
    final safeLocal = localScore.clamp(0.0, 1.0).toDouble();
    final safeGlobal = globalScore.clamp(0.0, 1.0).toDouble();
    final safeUsage = usageScore.clamp(0.0, 1.0).toDouble();
    final weighted = (config.localWeight * safeLocal) +
        (config.globalWeight * safeGlobal) +
        (config.usageWeight * safeUsage);
    return weighted.clamp(0.0, 1.0).toDouble();
  }

  /// Ranks candidate items for a specific tenant without leaking other tenants' local scores (#2775).
  Future<List<RankedOptInItem>> rankItemsForTenant({
    required final String tenantId,
    required final List<String> candidateItemIds,
  }) async {
    final cleanTenant = tenantId.trim();
    final ranked = <RankedOptInItem>[];

    for (final rawId in candidateItemIds) {
      final itemId = rawId.trim();
      if (itemId.isEmpty) {
        continue;
      }
      final evaluations = await _store.listEvaluationsForItem(itemId);
      TenantItemEvaluation? ownEval;
      for (final eval in evaluations) {
        if (eval.tenantId == cleanTenant) {
          ownEval = eval;
          break;
        }
      }

      final globalRecord = await _store.getGlobalRecord(itemId);
      final isPromoted = globalRecord?.isGlobalPromoted ?? false;
      final globalScore = isPromoted ? (globalRecord?.globalScore ?? 0.0) : 0.0;
      final localScore = ownEval?.score ?? 0.0;
      final usageScore = ownEval?.usageScore ?? 0.0;
      final compositeScore = computeCompositeScore(
        localScore: localScore,
        globalScore: globalScore,
        usageScore: usageScore,
      );

      ranked.add(
        RankedOptInItem(
          itemId: itemId,
          tenantId: cleanTenant,
          localScore: localScore,
          globalScore: globalScore,
          usageScore: usageScore,
          compositeScore: compositeScore,
          isGlobalPromoted: isPromoted,
        ),
      );
    }

    ranked.sort((final RankedOptInItem a, final RankedOptInItem b) {
      final cmp = b.compositeScore.compareTo(a.compositeScore);
      return cmp != 0 ? cmp : a.itemId.compareTo(b.itemId);
    });
    return List<RankedOptInItem>.unmodifiable(ranked);
  }
}
