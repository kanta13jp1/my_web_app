import 'package:my_web_app/models/asset_liability_workbook.dart';

/// 支払原資の自動割当・残高余裕・除外対象を定めるルール (#4059)。
class PaymentFundingRule {
  final List<String> priorityAccountIds;
  final double minimumReserve;
  final Set<String> excludedAccountIds;

  const PaymentFundingRule({
    this.priorityAccountIds = const <String>[],
    this.minimumReserve = 10000,
    this.excludedAccountIds = const <String>{},
  });

  /// 支払額と口座別サマリーから最適な支払原資口座IDを解決する。
  static String? resolveFundingSourceAccountId({
    required double paymentAmount,
    required List<AssetLiabilityAccountCashflowSummary> summaries,
    required PaymentFundingRule rule,
  }) {
    final byId = <String, AssetLiabilityAccountCashflowSummary>{
      for (final summary in summaries) summary.accountId: summary,
    };

    for (final accountId in rule.priorityAccountIds) {
      if (rule.excludedAccountIds.contains(accountId)) {
        continue;
      }
      final summary = byId[accountId];
      if (summary == null) {
        continue;
      }
      if (summary.projectedBalance - paymentAmount >= rule.minimumReserve) {
        return summary.accountId;
      }
    }

    final excluded = rule.excludedAccountIds;
    final fallbackCandidates = summaries
        .where((summary) => !excluded.contains(summary.accountId))
        .toList(growable: false)
      ..sort((a, b) => b.projectedBalance.compareTo(a.projectedBalance));

    for (final summary in fallbackCandidates) {
      if (summary.projectedBalance - paymentAmount >= rule.minimumReserve) {
        return summary.accountId;
      }
    }

    return null;
  }
}
