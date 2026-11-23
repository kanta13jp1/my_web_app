import '../models/asset_liability_workbook.dart';
import '../models/asset_management_ai_analysis_history.dart';
import 'asset_management_insight_service.dart';

/// 過去AI分析履歴と現在値の比較結果 (#3395)。
class AssetAiHistoryComparison {
  final DateTime previousGeneratedAt;
  final String previousSummaryExcerpt;
  final List<String> improvedItems;
  final List<String> worsenedItems;
  final List<String> unresolvedItems;

  const AssetAiHistoryComparison({
    required this.previousGeneratedAt,
    required this.previousSummaryExcerpt,
    required this.improvedItems,
    required this.worsenedItems,
    required this.unresolvedItems,
  });

  bool get hasAnyDiff =>
      improvedItems.isNotEmpty ||
      worsenedItems.isNotEmpty ||
      unresolvedItems.isNotEmpty;
}

class _ComparableMetrics {
  final double? liabilityMagnitude;
  final double? cashLikeTotal;
  final double? cashAfterScheduledPayments;
  final double? monthlyUnpaidPaymentTotal;
  final int? paymentSourceMissingCount;
  final int? overdueCount;
  final int? shortAccountCount;

  const _ComparableMetrics({
    this.liabilityMagnitude,
    this.cashLikeTotal,
    this.cashAfterScheduledPayments,
    this.monthlyUnpaidPaymentTotal,
    this.paymentSourceMissingCount,
    this.overdueCount,
    this.shortAccountCount,
  });
}

/// 過去のAI資産分析履歴から前回からの改善点・悪化点・未解決点を抽出する (#3395)。
class AssetAiHistoryDiffService {
  const AssetAiHistoryDiffService._();

  /// 履歴一覧を新しい順に並べて最新履歴をベースに現在の状態と比較する。
  static AssetAiHistoryComparison? compare({
    required List<AssetManagementAiAnalysisHistoryEntry> history,
    AssetLiabilityWorkbook? currentWorkbook,
    AssetManagementInsightReport? currentReport,
    Map<String, dynamic>? currentMetrics,
  }) {
    if (history.isEmpty) {
      return null;
    }

    final sorted = List<AssetManagementAiAnalysisHistoryEntry>.from(history)
      ..sort((a, b) {
        final byGen = b.generatedAt.compareTo(a.generatedAt);
        if (byGen != 0) {
          return byGen;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

    final AssetManagementAiAnalysisHistoryEntry baseline;
    final _ComparableMetrics current;

    if (currentMetrics != null) {
      baseline = sorted.first;
      current = _metricsFromPayload(currentMetrics);
    } else if (currentReport != null || currentWorkbook != null) {
      baseline = sorted.first;
      final wb = currentWorkbook ?? currentReport!.workbook;
      current = _ComparableMetrics(
        liabilityMagnitude: wb.liabilityTotal.abs(),
        cashLikeTotal: wb.cashLikeTotal,
        cashAfterScheduledPayments: wb.cashAfterScheduledPayments,
        monthlyUnpaidPaymentTotal: wb.monthlyUnpaidPaymentTotal,
        paymentSourceMissingCount: wb.paymentSourceMissingRows.length,
        overdueCount: wb.overdueCashflowRows.length,
        shortAccountCount: wb.shortAccountSummaries.length,
      );
    } else if (sorted.length >= 2) {
      baseline = sorted[1];
      current = _metricsFromPayload(sorted.first.inputPayload);
    } else {
      baseline = sorted.first;
      current = _metricsFromPayload(sorted.first.inputPayload);
    }

    final previous = _metricsFromPayload(baseline.inputPayload);
    final improved = <String>[];
    final worsened = <String>[];
    final unresolved = <String>[];

    _compareAmount(
      label: '負債残高',
      previous: previous.liabilityMagnitude,
      current: current.liabilityMagnitude,
      lowerIsBetter: true,
      improved: improved,
      worsened: worsened,
    );
    _compareAmount(
      label: '手元現金',
      previous: previous.cashLikeTotal,
      current: current.cashLikeTotal,
      lowerIsBetter: false,
      improved: improved,
      worsened: worsened,
    );
    _compareAmount(
      label: '支払後手元残高',
      previous: previous.cashAfterScheduledPayments,
      current: current.cashAfterScheduledPayments,
      lowerIsBetter: false,
      improved: improved,
      worsened: worsened,
    );
    _compareAmount(
      label: '未払いの月次支払予定額',
      previous: previous.monthlyUnpaidPaymentTotal,
      current: current.monthlyUnpaidPaymentTotal,
      lowerIsBetter: true,
      improved: improved,
      worsened: worsened,
    );
    _compareCount(
      label: '期限超過の支払い',
      previous: previous.overdueCount,
      current: current.overdueCount,
      improved: improved,
      worsened: worsened,
      unresolved: unresolved,
    );
    _compareCount(
      label: '支払原資未設定口座',
      previous: previous.paymentSourceMissingCount,
      current: current.paymentSourceMissingCount,
      improved: improved,
      worsened: worsened,
      unresolved: unresolved,
    );
    _compareCount(
      label: '残高不足見込み口座',
      previous: previous.shortAccountCount,
      current: current.shortAccountCount,
      improved: improved,
      worsened: worsened,
      unresolved: unresolved,
    );

    if (currentReport != null) {
      for (final item in currentReport.actionItems) {
        if (item.type == AssetManagementInsightActionType.paymentDiscrepancy) {
          unresolved.add('未解消の支払差額: ${item.title}');
        }
      }
    }

    return AssetAiHistoryComparison(
      previousGeneratedAt: baseline.generatedAt,
      previousSummaryExcerpt: _summaryExcerpt(baseline),
      improvedItems: List<String>.unmodifiable(improved),
      worsenedItems: List<String>.unmodifiable(worsened),
      unresolvedItems: List<String>.unmodifiable(unresolved),
    );
  }

  static void _compareAmount({
    required String label,
    required double? previous,
    required double? current,
    required bool lowerIsBetter,
    required List<String> improved,
    required List<String> worsened,
  }) {
    if (previous == null || current == null) {
      return;
    }
    final delta = current - previous;
    if (delta.abs() < 1) {
      return;
    }
    final isImproved = lowerIsBetter ? delta < 0 : delta > 0;
    final sign = delta > 0 ? '+' : '-';
    final message = '$label: ${_formatYen(previous)} → '
        '${_formatYen(current)}（$sign${_formatYen(delta.abs())}）';
    if (isImproved) {
      improved.add(message);
    } else {
      worsened.add(message);
    }
  }

  static void _compareCount({
    required String label,
    required int? previous,
    required int? current,
    required List<String> improved,
    required List<String> worsened,
    required List<String> unresolved,
  }) {
    if (current != null &&
        current > 0 &&
        (previous == null || previous == current)) {
      unresolved.add('$label: $current件が継続中');
      return;
    }
    if (previous == null || current == null) {
      return;
    }
    if (current < previous) {
      improved.add('$label: $previous件 → $current件');
      if (current > 0) {
        unresolved.add('$label: 残り$current件を対応待ち');
      }
    } else if (current > previous) {
      worsened.add('$label: $previous件 → $current件');
    }
  }

  static _ComparableMetrics _metricsFromPayload(Map<String, dynamic> payload) {
    final wb = _mapOf(payload['workbook']);
    final totals = _mapOf(wb['totals']);
    final review = _mapOf(wb['debt_control_review']);
    final actionInventory = _mapOf(payload['action_inventory']);
    final byType = _mapOf(actionInventory['by_type']);

    final liabilityRaw = _doubleOf(totals['liability_total']) ??
        _doubleOf(payload['liability_total']);
    final cashLike = _doubleOf(totals['cash_like_total']) ??
        _doubleOf(payload['cash_like_total']);
    final cashAfterScheduled =
        _doubleOf(totals['cash_after_scheduled_payments']) ??
            _doubleOf(payload['cash_after_scheduled_payments']);
    final unpaidTotal = _doubleOf(totals['monthly_unpaid_payment_total']) ??
        _doubleOf(payload['monthly_unpaid_payment_total']);
    final missingSources = _intOf(review['payment_source_missing_count']) ??
        _intOf(payload['payment_source_missing_count']) ??
        _intOf(byType['missingPaymentSource']);
    final overdue = _intOf(payload['overdue_payment_count']) ??
        _intOf(wb['overdue_payment_count']) ??
        _intOf(byType['overduePayment']);
    final shortAccounts = _intOf(payload['short_account_count']) ??
        _intOf(wb['short_account_count']) ??
        _intOf(byType['accountShortfallRisk']);

    return _ComparableMetrics(
      liabilityMagnitude: liabilityRaw?.abs(),
      cashLikeTotal: cashLike,
      cashAfterScheduledPayments: cashAfterScheduled,
      monthlyUnpaidPaymentTotal: unpaidTotal,
      paymentSourceMissingCount: missingSources,
      overdueCount: overdue,
      shortAccountCount: shortAccounts,
    );
  }

  static String _summaryExcerpt(AssetManagementAiAnalysisHistoryEntry entry) {
    final normalized = entry.summaryText.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return entry.summaryTextOmitted
          ? '前回の要約本文は一覧取得時に省略されています。'
          : '前回の要約本文は記録されていません。';
    }
    if (normalized.length <= 120) {
      return normalized;
    }
    return '${normalized.substring(0, 119)}…';
  }

  static Map<String, dynamic> _mapOf(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  static double? _doubleOf(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static int? _intOf(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String _formatYen(double amount) {
    final sign = amount < 0 ? '-' : '';
    final digits = amount.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i += 1) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$sign¥$buffer';
  }
}
