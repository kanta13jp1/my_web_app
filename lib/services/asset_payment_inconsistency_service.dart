import '../models/asset_liability_workbook.dart';

/// Workbook 上の支払済みフラグ・支払予定額・実支払額の不整合 (R1〜R3) を検知する。
///
/// - R1: `paid == true && actualPaymentAmount == null` (期日未到来)
/// - R2: `scheduledPaymentAmount <= 0 && actualPaymentAmount > 0`
/// - R3: `isPastDue && paid == true && actualPaymentAmount == null`
class AssetPaymentInconsistencyService {
  const AssetPaymentInconsistencyService._();

  static List<AssetPaymentInconsistency> detect({
    required List<AssetLiabilityDebtRow> debtRows,
    required List<AssetLiabilityCashflowRow> cashflowRows,
    required DateTime baseDate,
  }) {
    final today = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final paymentDateByAccountId = <String, DateTime>{
      for (final row in cashflowRows)
        if (row.eventType == AssetLiabilityCashflowEventType.payment)
          row.accountId: row.paymentDate,
    };

    final detected = <AssetPaymentInconsistency>[];
    for (final row in debtRows) {
      if (row.includedInBillingAccount) {
        continue;
      }
      final paymentDate = paymentDateByAccountId[row.id];
      final resolvedPaymentDate = paymentDate == null
          ? null
          : DateTime(paymentDate.year, paymentDate.month, paymentDate.day);
      final paymentDay = row.paymentDay;
      final isPastDue = resolvedPaymentDate != null
          ? resolvedPaymentDate.isBefore(today)
          : (paymentDay != null && paymentDay > 0 && paymentDay < today.day);

      if (row.paid && row.actualPaymentAmount == null) {
        final rule = isPastDue
            ? AssetPaymentInconsistencyRule.pastDuePaidWithoutActual
            : AssetPaymentInconsistencyRule.paidWithoutActual;
        detected.add(
          AssetPaymentInconsistency(
            accountId: row.id,
            accountName: row.name,
            rule: rule,
            paymentDay: row.paymentDay,
            paymentDate: resolvedPaymentDate,
            scheduledPaymentAmount: row.scheduledPaymentAmount,
            actualPaymentAmount: null,
            paid: true,
            isPastDue: isPastDue,
            reasonLabel: isPastDue
                ? '期日経過かつ支払済みですが実支払額が未記録です (R3)'
                : '支払済みですが実支払額が未記録です (R1)',
            suggestedAction: '実支払額を入力するか、誤チェックの場合は支払済みを取消してください。',
          ),
        );
      } else if (row.scheduledPaymentAmount <= 0 &&
          row.actualPaymentAmount != null &&
          row.actualPaymentAmount! > 0) {
        detected.add(
          AssetPaymentInconsistency(
            accountId: row.id,
            accountName: row.name,
            rule: AssetPaymentInconsistencyRule.zeroScheduledWithActual,
            paymentDay: row.paymentDay,
            paymentDate: resolvedPaymentDate,
            scheduledPaymentAmount: row.scheduledPaymentAmount,
            actualPaymentAmount: row.actualPaymentAmount,
            paid: row.paid,
            isPastDue: isPastDue,
            reasonLabel: '今月支払予定額が0円のまま実支払額が記録されています (R2)',
            suggestedAction: '実支払額を予定額へ反映するか、実支払額を修正してください。',
          ),
        );
      }
    }
    return List<AssetPaymentInconsistency>.unmodifiable(detected);
  }

  static AssetPaymentInconsistencySummary summarize(
    List<AssetPaymentInconsistency> items,
  ) {
    return AssetPaymentInconsistencySummary(
      totalCount: items.length,
      r1Count: items.where((item) => item.matchesR1).length,
      r2Count: items.where((item) => item.matchesR2).length,
      r3Count: items.where((item) => item.matchesR3).length,
    );
  }
}
