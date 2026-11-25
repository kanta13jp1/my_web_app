import 'dart:math';

import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/payment_funding_rule.dart';

/// 安全残高割れを予防する概算口座振替提案 (#3350 / #4059)。
class AssetSafetyTransferSuggestion {
  final String fromAccountId;
  final String fromAccountName;
  final String toAccountId;
  final String toAccountName;
  final double amount;
  final DateTime? neededBy;
  final String? targetPaymentName;
  final DateTime? targetPaymentDate;
  final double projectedBalanceBefore;
  final double minimumSafetyBalance;
  final bool isSameBankFreeTransfer;
  final String reason;

  const AssetSafetyTransferSuggestion({
    required this.fromAccountId,
    required this.fromAccountName,
    required this.toAccountId,
    required this.toAccountName,
    required this.amount,
    required this.neededBy,
    this.targetPaymentName,
    this.targetPaymentDate,
    required this.projectedBalanceBefore,
    required this.minimumSafetyBalance,
    required this.isSameBankFreeTransfer,
    required this.reason,
  });

  String get dedupeKey =>
      '${fromAccountId}__${toAccountId}__${amount.round()}__${neededBy?.toIso8601String().split('T').first ?? 'any'}';

  AssetLiabilityTransferSuggestion toTransferSuggestion() {
    return AssetLiabilityTransferSuggestion(
      fromAccountId: fromAccountId,
      fromAccountName: fromAccountName,
      toAccountId: toAccountId,
      toAccountName: toAccountName,
      amount: amount,
      neededBy: neededBy,
      targetPaymentName: targetPaymentName,
      targetPaymentDate: targetPaymentDate,
    );
  }
}

/// projectedBalance < minimumSafetyBalance 口座に対する 1口座1件の概算振替提案を生成する。
class AssetSafetyTransferSuggestionService {
  const AssetSafetyTransferSuggestionService._();

  static List<AssetSafetyTransferSuggestion> buildSuggestions({
    required AssetLiabilityWorkbook workbook,
    required double minimumSafetyBalance,
    double bufferAmount = 0,
    PaymentFundingRule? fundingRule,
  }) {
    if (minimumSafetyBalance <= 0) {
      return const <AssetSafetyTransferSuggestion>[];
    }

    final deficits = workbook.accountCashflowSummaries
        .where(
          (summary) => summary.projectedBalance < minimumSafetyBalance,
        )
        .toList(growable: false)
      ..sort((a, b) => a.projectedBalance.compareTo(b.projectedBalance));

    if (deficits.isEmpty) {
      return const <AssetSafetyTransferSuggestion>[];
    }

    final donorReserve = fundingRule == null
        ? minimumSafetyBalance
        : max(fundingRule.minimumReserve, minimumSafetyBalance);

    final excludedIds = fundingRule?.excludedAccountIds ?? const <String>{};
    final priorityIds = fundingRule?.priorityAccountIds ?? const <String>[];

    final suggestions = <AssetSafetyTransferSuggestion>[];
    final allocatedByDonor = <String, double>{};

    for (final deficit in deficits) {
      final candidates = workbook.accountCashflowSummaries.where((candidate) {
        if (candidate.accountId == deficit.accountId) {
          return false;
        }
        if (excludedIds.contains(candidate.accountId)) {
          return false;
        }
        final allocated = allocatedByDonor[candidate.accountId] ?? 0;
        final donorSurplus =
            candidate.projectedBalance - donorReserve - allocated;
        final movableNow =
            candidate.currentBalance - candidate.pendingTransferOut - allocated;
        return donorSurplus > 0 && movableNow > 0;
      }).toList(growable: false)
        ..sort((a, b) {
          final priorityA = priorityIds.indexOf(a.accountId);
          final priorityB = priorityIds.indexOf(b.accountId);
          if (priorityA >= 0 && priorityB >= 0 && priorityA != priorityB) {
            return priorityA.compareTo(priorityB);
          }
          if ((priorityA >= 0) != (priorityB >= 0)) {
            return priorityA >= 0 ? -1 : 1;
          }
          final freeA = _isSameBankFreeTransfer(a, deficit);
          final freeB = _isSameBankFreeTransfer(b, deficit);
          if (freeA != freeB) {
            return freeA ? -1 : 1;
          }
          final allocA = allocatedByDonor[a.accountId] ?? 0;
          final allocB = allocatedByDonor[b.accountId] ?? 0;
          final surplusA = a.projectedBalance - donorReserve - allocA;
          final surplusB = b.projectedBalance - donorReserve - allocB;
          return surplusB.compareTo(surplusA);
        });

      if (candidates.isEmpty) {
        continue;
      }

      final donor = candidates.first;
      final allocated = allocatedByDonor[donor.accountId] ?? 0;
      final donorSurplus = donor.projectedBalance - donorReserve - allocated;
      final movableNow =
          donor.currentBalance - donor.pendingTransferOut - allocated;
      final safeBuffer = bufferAmount > 0 ? bufferAmount : 0.0;
      final targetAmount =
          (minimumSafetyBalance - deficit.projectedBalance) + safeBuffer;
      final amount = min(targetAmount, min(donorSurplus, movableNow));
      if (amount <= 0) {
        continue;
      }

      AssetLiabilityCashflowRow? targetPayment;
      for (final row in workbook.cashflowRows) {
        if (row.isPayment &&
            row.isDirectCashflowTarget &&
            !row.paid &&
            row.paymentSourceAccountId == deficit.accountId) {
          targetPayment = row;
          break;
        }
      }

      allocatedByDonor[donor.accountId] = allocated + amount;
      final sameBankFree = _isSameBankFreeTransfer(donor, deficit);
      final targetPart = targetPayment == null
          ? ''
          : '・対象支払: ${targetPayment.accountName}（${targetPayment.paymentDate.month}/${targetPayment.paymentDate.day}）';
      final freePart = sameBankFree ? '・同一銀行/無料優遇' : '';

      suggestions.add(
        AssetSafetyTransferSuggestion(
          fromAccountId: donor.accountId,
          fromAccountName: donor.accountName,
          toAccountId: deficit.accountId,
          toAccountName: deficit.accountName,
          amount: amount,
          neededBy: targetPayment?.paymentDate,
          targetPaymentName: targetPayment?.accountName,
          targetPaymentDate: targetPayment?.paymentDate,
          projectedBalanceBefore: deficit.projectedBalance,
          minimumSafetyBalance: minimumSafetyBalance,
          isSameBankFreeTransfer: sameBankFree,
          reason: '${deficit.accountName}の見込み残高が安全残高を下回るため、'
              '概算 ${amount.round()} 円の事前振替を提案します'
              '$targetPart$freePart',
        ),
      );
    }

    return suggestions;
  }

  static bool _isSameBankFreeTransfer(
    AssetLiabilityAccountCashflowSummary donor,
    AssetLiabilityAccountCashflowSummary deficit,
  ) {
    final toId = deficit.accountId.toLowerCase();
    final fromId = donor.accountId.toLowerCase();
    if (toId == 'wallet_cash' &&
        (fromId.contains('smbc') ||
            fromId.contains('jibun') ||
            fromId.contains('bank'))) {
      return true;
    }
    if (fromId.contains('smbc') && toId.contains('smbc')) {
      return true;
    }
    if (fromId.contains('jibun') && toId.contains('jibun')) {
      return true;
    }
    return false;
  }
}
