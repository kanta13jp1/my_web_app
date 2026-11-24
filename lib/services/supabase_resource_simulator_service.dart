import 'package:flutter/foundation.dart';

/// Supabase 課金プラン種別 (#2624)。
///
/// 料金・クォータ基準は `https://supabase.com/pricing`（2026-11-24 確認時点）に基づく
/// point-in-time 参照値であり、運用時は定期的な一次情報再確認が必要です。
enum SupabasePlanTier {
  free('Free', 0.0),
  pro('Pro', 25.0);

  const SupabasePlanTier(this.label, this.baseMonthlyUsd);

  final String label;
  final double baseMonthlyUsd;
}

/// クォータ消費率の警告段階 (#2624)。
enum QuotaThresholdLevel {
  normal('正常 (<80%)'),
  warning('80%到達警告'),
  overage('上限超過 (>100%)');

  const QuotaThresholdLevel(this.labelJa);

  final String labelJa;
}

/// Supabase プラン別公式クォータ・超過単価仕様 (#2624)。
class SupabasePlanQuotaSpec {
  const SupabasePlanQuotaSpec({
    required this.tier,
    required this.baseMonthlyUsd,
    required this.includedDbMb,
    required this.includedEgressGb,
    required this.includedCachedEgressGb,
    required this.includedAuthMau,
    required this.includedStorageGb,
    required this.dbOverageUsdPerGb,
    required this.egressOverageUsdPerGb,
    required this.mauOverageUsdPerUser,
    required this.storageOverageUsdPerGb,
    required this.hasSevenDayInactivityPause,
  });

  final SupabasePlanTier tier;
  final double baseMonthlyUsd;
  final double includedDbMb;
  final double includedEgressGb;
  final double includedCachedEgressGb;
  final int includedAuthMau;
  final double includedStorageGb;
  final double dbOverageUsdPerGb;
  final double egressOverageUsdPerGb;
  final double mauOverageUsdPerUser;
  final double storageOverageUsdPerGb;
  final bool hasSevenDayInactivityPause;

  static const String pricingSourceUrl = 'https://supabase.com/pricing';
  static const String pricingVerifiedDate = '2026-11-24';

  static const SupabasePlanQuotaSpec free = SupabasePlanQuotaSpec(
    tier: SupabasePlanTier.free,
    baseMonthlyUsd: 0.0,
    includedDbMb: 500.0,
    includedEgressGb: 5.0,
    includedCachedEgressGb: 5.0,
    includedAuthMau: 50000,
    includedStorageGb: 1.0,
    dbOverageUsdPerGb: 0.0,
    egressOverageUsdPerGb: 0.0,
    mauOverageUsdPerUser: 0.0,
    storageOverageUsdPerGb: 0.0,
    hasSevenDayInactivityPause: true,
  );

  static const SupabasePlanQuotaSpec pro = SupabasePlanQuotaSpec(
    tier: SupabasePlanTier.pro,
    baseMonthlyUsd: 25.0,
    includedDbMb: 8000.0,
    includedEgressGb: 250.0,
    includedCachedEgressGb: 250.0,
    includedAuthMau: 100000,
    includedStorageGb: 100.0,
    dbOverageUsdPerGb: 0.125,
    egressOverageUsdPerGb: 0.09,
    mauOverageUsdPerUser: 0.00325,
    storageOverageUsdPerGb: 0.0213,
    hasSevenDayInactivityPause: false,
  );

  static SupabasePlanQuotaSpec forTier(SupabasePlanTier tier) {
    return switch (tier) {
      SupabasePlanTier.free => free,
      SupabasePlanTier.pro => pro,
    };
  }
}

/// シミュレーション入力パラメータ (#2624)。
class SupabaseResourceInputs {
  const SupabaseResourceInputs({
    this.planTier = SupabasePlanTier.free,
    this.mau = 12000,
    this.avgDbMbPerUser = 0.02,
    this.avgEgressMbPerUser = 0.2,
    this.storageGb = 0.4,
  });

  final SupabasePlanTier planTier;
  final int mau;
  final double avgDbMbPerUser;
  final double avgEgressMbPerUser;
  final double storageGb;

  SupabaseResourceInputs copyWith({
    SupabasePlanTier? planTier,
    int? mau,
    double? avgDbMbPerUser,
    double? avgEgressMbPerUser,
    double? storageGb,
  }) {
    return SupabaseResourceInputs(
      planTier: planTier ?? this.planTier,
      mau: (mau ?? this.mau).clamp(0, 500000),
      avgDbMbPerUser: (avgDbMbPerUser ?? this.avgDbMbPerUser).clamp(0.0, 5.0),
      avgEgressMbPerUser:
          (avgEgressMbPerUser ?? this.avgEgressMbPerUser).clamp(0.0, 20.0),
      storageGb: (storageGb ?? this.storageGb).clamp(0.0, 500.0),
    );
  }
}

/// 単一リソース軸の予測結果 (#2624)。
class ResourceUtilizationMetric {
  const ResourceUtilizationMetric({
    required this.id,
    required this.labelJa,
    required this.projectedValue,
    required this.includedQuota,
    required this.unit,
    required this.utilizationPercent,
    required this.thresholdLevel,
    required this.overageUnits,
    required this.estimatedOverageUsd,
  });

  final String id;
  final String labelJa;
  final double projectedValue;
  final double includedQuota;
  final String unit;
  final double utilizationPercent;
  final QuotaThresholdLevel thresholdLevel;
  final double overageUnits;
  final double estimatedOverageUsd;

  bool get isWarningOrHigher => thresholdLevel != QuotaThresholdLevel.normal;
  bool get isOverQuota => thresholdLevel == QuotaThresholdLevel.overage;
}

/// リソース消費量・コスト・警告アラートの算出結果 (#2624)。
class SupabaseSimulationResult {
  const SupabaseSimulationResult({
    required this.spec,
    required this.inputs,
    required this.metrics,
    required this.estimatedOverageUsd,
    required this.estimatedTotalUsd,
    required this.hasWarning,
    required this.hasOverage,
    required this.alerts,
  });

  final SupabasePlanQuotaSpec spec;
  final SupabaseResourceInputs inputs;
  final List<ResourceUtilizationMetric> metrics;
  final double estimatedOverageUsd;
  final double estimatedTotalUsd;
  final bool hasWarning;
  final bool hasOverage;
  final List<String> alerts;
}

/// Supabase 制約シミュレーターの決定論的計算ロジック (#2624)。
class SupabaseResourceSimulatorCalculator {
  const SupabaseResourceSimulatorCalculator._();

  static const double mbPerGb = 1000.0;

  static SupabaseSimulationResult evaluate(SupabaseResourceInputs inputs) {
    final spec = SupabasePlanQuotaSpec.forTier(inputs.planTier);
    final projectedDbMb = inputs.mau * inputs.avgDbMbPerUser;
    final projectedEgressGb =
        (inputs.mau * inputs.avgEgressMbPerUser) / mbPerGb;
    final projectedMau = inputs.mau.toDouble();
    final projectedStorageGb = inputs.storageGb;

    final dbMetric = _buildMetric(
      id: 'database',
      labelJa: 'Database 容量',
      projected: projectedDbMb,
      quota: spec.includedDbMb,
      unit: 'MB',
      overageUnitDivisor: mbPerGb,
      overageUsdPerUnit: spec.dbOverageUsdPerGb,
    );
    final egressMetric = _buildMetric(
      id: 'egress',
      labelJa: 'ネットワーク Egress',
      projected: projectedEgressGb,
      quota: spec.includedEgressGb,
      unit: 'GB',
      overageUnitDivisor: 1.0,
      overageUsdPerUnit: spec.egressOverageUsdPerGb,
    );
    final mauMetric = _buildMetric(
      id: 'auth_mau',
      labelJa: 'Auth MAU',
      projected: projectedMau,
      quota: spec.includedAuthMau.toDouble(),
      unit: 'users',
      overageUnitDivisor: 1.0,
      overageUsdPerUnit: spec.mauOverageUsdPerUser,
    );
    final storageMetric = _buildMetric(
      id: 'storage',
      labelJa: 'File Storage',
      projected: projectedStorageGb,
      quota: spec.includedStorageGb,
      unit: 'GB',
      overageUnitDivisor: 1.0,
      overageUsdPerUnit: spec.storageOverageUsdPerGb,
    );

    final metrics = List<ResourceUtilizationMetric>.unmodifiable(
      <ResourceUtilizationMetric>[
        dbMetric,
        egressMetric,
        mauMetric,
        storageMetric,
      ],
    );

    final overageUsd = metrics.fold<double>(
      0.0,
      (sum, metric) => sum + metric.estimatedOverageUsd,
    );
    final totalUsd = spec.baseMonthlyUsd + overageUsd;

    final alerts = <String>[];
    var hasWarning = false;
    var hasOverage = false;
    for (final metric in metrics) {
      if (metric.isOverQuota) {
        hasOverage = true;
        hasWarning = true;
        if (spec.tier == SupabasePlanTier.free) {
          alerts.add(
            '${metric.labelJa} が Free 上限 (${metric.utilizationPercent.toStringAsFixed(1)}%) を超過しています。'
            'Pro プランへの切替またはデータ削減が必要です。',
          );
        } else {
          alerts.add(
            '${metric.labelJa} が基本枠を超過 (${metric.utilizationPercent.toStringAsFixed(1)}%)：'
            '従量課金推定 USD ${metric.estimatedOverageUsd.toStringAsFixed(2)}/月 が発生します。',
          );
        }
      } else if (metric.isWarningOrHigher) {
        hasWarning = true;
        alerts.add(
          '${metric.labelJa} が 80% 警告ライン (${metric.utilizationPercent.toStringAsFixed(1)}%) に到達しています。',
        );
      }
    }

    if (spec.hasSevenDayInactivityPause) {
      alerts.add(
        'Free プランでは 7 日間（1 週間）無操作でプロジェクトが自動停止される制約があります（同時稼働上限 2 プロジェクト）。',
      );
    }

    return SupabaseSimulationResult(
      spec: spec,
      inputs: inputs,
      metrics: metrics,
      estimatedOverageUsd: overageUsd,
      estimatedTotalUsd: totalUsd,
      hasWarning: hasWarning,
      hasOverage: hasOverage,
      alerts: List<String>.unmodifiable(alerts),
    );
  }

  static ResourceUtilizationMetric _buildMetric({
    required String id,
    required String labelJa,
    required double projected,
    required double quota,
    required String unit,
    required double overageUnitDivisor,
    required double overageUsdPerUnit,
  }) {
    final safeQuota = quota <= 0 ? 1.0 : quota;
    final pct = (projected / safeQuota) * 100.0;
    final QuotaThresholdLevel level;
    if (pct > 100.0) {
      level = QuotaThresholdLevel.overage;
    } else if (pct >= 80.0) {
      level = QuotaThresholdLevel.warning;
    } else {
      level = QuotaThresholdLevel.normal;
    }
    final rawExcess = projected > safeQuota ? projected - safeQuota : 0.0;
    final overageUnits = rawExcess / overageUnitDivisor;
    final overageUsd = overageUnits * overageUsdPerUnit;
    return ResourceUtilizationMetric(
      id: id,
      labelJa: labelJa,
      projectedValue: projected,
      includedQuota: quota,
      unit: unit,
      utilizationPercent: pct,
      thresholdLevel: level,
      overageUnits: overageUnits,
      estimatedOverageUsd: overageUsd,
    );
  }
}

/// スライダー操作とプラン切替を管理する ChangeNotifier コントローラ (#2624)。
class SupabaseResourceSimulatorController extends ChangeNotifier {
  SupabaseResourceSimulatorController({
    SupabaseResourceInputs initialInputs = const SupabaseResourceInputs(),
  })  : _inputs = initialInputs,
        _result = SupabaseResourceSimulatorCalculator.evaluate(initialInputs);

  SupabaseResourceInputs _inputs;
  SupabaseSimulationResult _result;
  bool _disposed = false;

  SupabaseResourceInputs get inputs => _inputs;
  SupabaseSimulationResult get result => _result;

  void _updateInputs(SupabaseResourceInputs next) {
    if (_disposed) {
      return;
    }
    _inputs = next;
    _result = SupabaseResourceSimulatorCalculator.evaluate(next);
    notifyListeners();
  }

  void setPlanTier(SupabasePlanTier tier) {
    _updateInputs(_inputs.copyWith(planTier: tier));
  }

  void setMau(int mau) {
    _updateInputs(_inputs.copyWith(mau: mau));
  }

  void setAvgDbMbPerUser(double avgDbMbPerUser) {
    _updateInputs(_inputs.copyWith(avgDbMbPerUser: avgDbMbPerUser));
  }

  void setAvgEgressMbPerUser(double avgEgressMbPerUser) {
    _updateInputs(_inputs.copyWith(avgEgressMbPerUser: avgEgressMbPerUser));
  }

  void setStorageGb(double storageGb) {
    _updateInputs(_inputs.copyWith(storageGb: storageGb));
  }

  void resetDefaults() {
    _updateInputs(const SupabaseResourceInputs());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
