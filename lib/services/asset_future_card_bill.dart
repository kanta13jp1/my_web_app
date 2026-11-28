import 'asset_liability_monthly_state_store.dart';

/// Updates an included card bill's estimate, never a cash flow or card total.
class AssetFutureCardBill {
  static const notePrefix = '将来カード内訳・未確定：';

  static int? parseAmount(String input) {
    final normalized = input
        .trim()
        .replaceAllMapped(
          RegExp('[０-９]'),
          (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xfee0),
        )
        .replaceAll('，', ',');
    if (!RegExp(r'^(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)$')
        .hasMatch(normalized)) {
      return null;
    }
    return int.tryParse(normalized.replaceAll(',', ''));
  }

  static AssetLiabilityMonthlyState apply({
    required AssetLiabilityMonthlyState state,
    required String accountId,
    required String accountName,
    required String cardId,
    required double amount,
    required String note,
    required DateTime editedAt,
  }) {
    if (accountId.isEmpty ||
        cardId.isEmpty ||
        accountId == cardId ||
        !amount.isFinite ||
        amount <= 0) {
      throw ArgumentError('利用先・請求先と正の金額が必要です');
    }
    if (state.paidAccountNames.contains(accountId) ||
        state.paidAccountNames.contains(accountName) ||
        state.actualPaymentAmounts.containsKey(accountId) ||
        state.billingConfirmedAccountIds.contains(accountId) ||
        state.confirmedPaymentDays.containsKey(accountId)) {
      throw StateError('対象月に支払実績または確定情報があります。先に明細を照合してください。');
    }
    return AssetLiabilityMonthlyState(
      paymentOverrides: {...state.paymentOverrides, accountId: amount},
      confirmedPaymentDays: state.confirmedPaymentDays,
      actualPaymentAmounts: state.actualPaymentAmounts,
      paymentDifferenceReasons: {
        ...state.paymentDifferenceReasons,
        accountId: '$notePrefix${note.trim()}',
      },
      annualRateOverrides: state.annualRateOverrides,
      annualRateEvidences: state.annualRateEvidences,
      paidAccountNames: state.paidAccountNames,
      billingConfirmedAccountIds: {
        ...state.billingConfirmedAccountIds.where((id) => id != accountId),
      },
      paymentSourceAccountIds: state.paymentSourceAccountIds,
      cardBillingAccountIds: {
        ...state.cardBillingAccountIds,
        accountId: cardId,
      },
      cardStatementLines: state.cardStatementLines,
      incomePlans: state.incomePlans,
      transferTasks: state.transferTasks,
      updatedAt: editedAt,
    );
  }
}
