import 'package:intl/intl.dart';

import '../models/asset_liability_workbook.dart';

class AssetLiabilityMonthlyReportView {
  final String monthKey;
  final AssetLiabilityMonthlySnapshot? snapshot;
  final AssetLiabilityMonthlySnapshot? previousSnapshot;
  final AssetLiabilityMonthlyReport? report;
  final String fallbackSummary;

  const AssetLiabilityMonthlyReportView({
    required this.monthKey,
    required this.snapshot,
    required this.previousSnapshot,
    required this.report,
    required this.fallbackSummary,
  });

  bool get hasAiReport => report != null && report!.aiSummary.trim().isNotEmpty;

  DateTime? get generatedAt => report?.generatedAt ?? snapshot?.savedAt;

  String get aiModel {
    final model = report?.aiModel.trim();
    if (model != null && model.isNotEmpty) {
      return model;
    }
    return 'deterministic-local-snapshot';
  }

  String get summary {
    final aiSummary = report?.aiSummary.trim();
    if (aiSummary != null && aiSummary.isNotEmpty) {
      return aiSummary;
    }
    return fallbackSummary;
  }

  double get totalAssets =>
      report?.totalAssets ?? snapshot?.positiveAssetTotal ?? 0;

  double get totalLiabilities =>
      report?.totalLiabilities ?? snapshot?.liabilityTotal ?? 0;

  double get netWorth => report?.netWorth ?? snapshot?.netWorth ?? 0;

  double? get netWorthDelta {
    if (snapshot == null || previousSnapshot == null) {
      return null;
    }
    return snapshot!.netWorth - previousSnapshot!.netWorth;
  }

  double get cashLikeTotal => snapshot?.cashLikeTotal ?? 0;

  double get monthlyScheduledPaymentTotal =>
      snapshot?.monthlyScheduledPaymentTotal ?? 0;

  double get monthlyPaidPaymentTotal => snapshot?.monthlyPaidPaymentTotal ?? 0;

  double get monthlyUnpaidPaymentTotal =>
      snapshot?.monthlyUnpaidPaymentTotal ?? 0;

  double get monthlyActualPaymentTotal =>
      snapshot?.monthlyActualPaymentTotal ?? 0;

  double get monthlyPaymentDifferenceTotal =>
      snapshot?.monthlyPaymentDifferenceTotal ?? 0;

  int get overduePaymentCount => snapshot?.overduePaymentCount ?? 0;
}

class AssetLiabilityMonthlyReportService {
  const AssetLiabilityMonthlyReportService();

  List<AssetLiabilityMonthlyReportView> buildReportViews({
    required List<AssetLiabilityMonthlySnapshot> snapshots,
    required List<AssetLiabilityMonthlyReport> reports,
    int limit = 24,
  }) {
    final snapshotsByMonth = <String, AssetLiabilityMonthlySnapshot>{
      for (final snapshot in snapshots) snapshot.monthKey: snapshot,
    };
    final reportsByMonth = <String, AssetLiabilityMonthlyReport>{
      for (final report in reports) report.monthKey: report,
    };
    final monthKeys = <String>{
      ...snapshotsByMonth.keys,
      ...reportsByMonth.keys,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final previousByMonth = _previousSnapshotsByMonth(snapshotsByMonth.values);

    return [
      for (final monthKey in monthKeys.take(limit < 0 ? 0 : limit))
        AssetLiabilityMonthlyReportView(
          monthKey: monthKey,
          snapshot: snapshotsByMonth[monthKey],
          previousSnapshot: previousByMonth[monthKey],
          report: reportsByMonth[monthKey],
          fallbackSummary: buildDeterministicSummary(
            monthKey: monthKey,
            snapshot: snapshotsByMonth[monthKey],
          ),
        ),
    ];
  }

  String buildDeterministicSummary({
    required String monthKey,
    required AssetLiabilityMonthlySnapshot? snapshot,
  }) {
    if (snapshot == null) {
      return '$monthKey report is available, but the KPI snapshot has not been synced locally yet.';
    }
    final paidRate = snapshot.monthlyScheduledPaymentTotal <= 0
        ? 0.0
        : snapshot.monthlyPaidPaymentTotal /
            snapshot.monthlyScheduledPaymentTotal;
    final formatter = NumberFormat('#,###');
    return [
      '$monthKey monthly asset report.',
      'Net worth: JPY ${formatter.format(snapshot.netWorth.round())}; '
          'cash-like assets: JPY ${formatter.format(snapshot.cashLikeTotal.round())}.',
      'Scheduled payments: JPY ${formatter.format(snapshot.monthlyScheduledPaymentTotal.round())}; '
          'paid ${(paidRate * 100).clamp(0, 999).toStringAsFixed(0)}%.',
      'Actual payment difference: JPY ${formatter.format(snapshot.monthlyPaymentDifferenceTotal.round())}; '
          'overdue payments: ${snapshot.overduePaymentCount}.',
    ].join(' ');
  }

  Map<String, AssetLiabilityMonthlySnapshot?> _previousSnapshotsByMonth(
    Iterable<AssetLiabilityMonthlySnapshot> snapshots,
  ) {
    final sorted = List<AssetLiabilityMonthlySnapshot>.from(snapshots)
      ..sort((a, b) => a.monthKey.compareTo(b.monthKey));
    return <String, AssetLiabilityMonthlySnapshot?>{
      for (var index = 0; index < sorted.length; index++)
        sorted[index].monthKey: index == 0 ? null : sorted[index - 1],
    };
  }
}
