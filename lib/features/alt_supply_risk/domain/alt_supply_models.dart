import 'dart:math' as math;

const double kDefaultStockpileTarget10kT = 100.0;
const double kDefaultProcurementThreshold10kT = 80.0;
const double kDefaultTotalProductionTarget10kT = 800.0;
const double kDefaultMaImportQuota10kT = 77.0;

enum AltSupplyRiskLevel {
  low('low', '低リスク'),
  elevated('elevated', '注意'),
  high('high', '高リスク (輸入転用警戒)'),
  critical('critical', '重大リスク (MA米依存拡大)');

  const AltSupplyRiskLevel(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static AltSupplyRiskLevel fromWire(final String? raw) {
    for (final level in AltSupplyRiskLevel.values) {
      if (level.wireValue == raw) return level;
    }
    return AltSupplyRiskLevel.low;
  }
}

enum AltSupplySourceKind {
  manual('manual', '手動シナリオ入力'),
  openDataSync('open_data_sync', 'オープンデータ定期連携');

  const AltSupplySourceKind(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static AltSupplySourceKind fromWire(final String? raw) {
    return raw == 'open_data_sync'
        ? AltSupplySourceKind.openDataSync
        : AltSupplySourceKind.manual;
  }
}

class AltSupplyMetrics {
  const AltSupplyMetrics({
    required this.stockpileShortfall10kT,
    required this.belowProcurementThreshold,
    required this.totalProductionGap10kT,
    required this.productionShortfall10kT,
    required this.importEscalationProbability,
    required this.riskLevel,
  });

  final double stockpileShortfall10kT;
  final bool belowProcurementThreshold;
  final double totalProductionGap10kT;
  final double productionShortfall10kT;
  final int importEscalationProbability;
  final AltSupplyRiskLevel riskLevel;

  static double _round1(final double v) => (v * 10).roundToDouble() / 10;

  static AltSupplyMetrics evaluate({
    required final double stockpileTarget10kT,
    required final double domesticProcurement10kT,
    required final double stockpileThreshold10kT,
    required final double totalProductionTarget10kT,
    required final double currentProduction10kT,
    required final double maImportQuota10kT,
  }) {
    final shortfall = _round1(
      math.max(0.0, stockpileTarget10kT - domesticProcurement10kT),
    );
    final belowThreshold = domesticProcurement10kT < stockpileThreshold10kT;
    final prodGap = _round1(currentProduction10kT - totalProductionTarget10kT);
    final prodShortfall = _round1(math.max(0.0, -prodGap));

    final targetBase = math.max(1.0, stockpileTarget10kT);
    final shortfallRatio = math.min(1.0, shortfall / targetBase);
    final thresholdGapRatio = stockpileThreshold10kT > 0 && belowThreshold
        ? math.min(
            1.0,
            (stockpileThreshold10kT - domesticProcurement10kT) /
                stockpileThreshold10kT,
          )
        : 0.0;
    final prodGapRatio = totalProductionTarget10kT > 0
        ? math.min(1.0, prodShortfall / totalProductionTarget10kT)
        : 0.0;

    var prob = 10 + shortfallRatio * 45 + prodGapRatio * 20;
    if (belowThreshold) {
      prob += 25 + thresholdGapRatio * 20;
    }
    final importProb = prob.round().clamp(5, 98);

    var riskLevel = AltSupplyRiskLevel.low;
    if (belowThreshold && importProb >= 75) {
      riskLevel = AltSupplyRiskLevel.critical;
    } else if (belowThreshold) {
      riskLevel = AltSupplyRiskLevel.high;
    } else if (shortfall > 0 || prodShortfall > 0) {
      riskLevel = AltSupplyRiskLevel.elevated;
    }

    return AltSupplyMetrics(
      stockpileShortfall10kT: shortfall,
      belowProcurementThreshold: belowThreshold,
      totalProductionGap10kT: prodGap,
      productionShortfall10kT: prodShortfall,
      importEscalationProbability: importProb,
      riskLevel: riskLevel,
    );
  }
}

class AltSupplyScenario {
  const AltSupplyScenario({
    required this.id,
    required this.title,
    required this.sourceKind,
    required this.sourceRef,
    required this.stockpileTarget10kT,
    required this.domesticProcurement10kT,
    required this.stockpileThreshold10kT,
    required this.totalProductionTarget10kT,
    required this.currentProduction10kT,
    required this.maImportQuota10kT,
    required this.metrics,
    required this.notes,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final AltSupplySourceKind sourceKind;
  final String sourceRef;
  final double stockpileTarget10kT;
  final double domesticProcurement10kT;
  final double stockpileThreshold10kT;
  final double totalProductionTarget10kT;
  final double currentProduction10kT;
  final double maImportQuota10kT;
  final AltSupplyMetrics metrics;
  final String notes;
  final DateTime updatedAt;
}

abstract interface class AltSupplyRepository {
  Future<List<AltSupplyScenario>> listScenarios();

  Future<List<AltSupplyScenario>> seedDefaults();

  Future<AltSupplyScenario> createScenario({
    required String title,
    required double stockpileTarget10kT,
    required double domesticProcurement10kT,
    required double stockpileThreshold10kT,
    required double totalProductionTarget10kT,
    required double currentProduction10kT,
    required double maImportQuota10kT,
    AltSupplySourceKind sourceKind = AltSupplySourceKind.manual,
    String sourceRef = '',
    String notes = '',
  });

  Future<AltSupplyScenario> updateScenario({
    required String id,
    required String title,
    required double stockpileTarget10kT,
    required double domesticProcurement10kT,
    required double stockpileThreshold10kT,
    required double totalProductionTarget10kT,
    required double currentProduction10kT,
    required double maImportQuota10kT,
    AltSupplySourceKind sourceKind = AltSupplySourceKind.manual,
    String sourceRef = '',
    String notes = '',
  });
}
