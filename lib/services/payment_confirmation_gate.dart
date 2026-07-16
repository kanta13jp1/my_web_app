// Payment-confirmation gate — GitHub Issue #3291.
//
// Deterministic decision logic for "should we warn / block before the user
// confirms a payment as paid?". The distinctive gap in #3291 is that today an
// empty income-plan list only produces an advisory card; it does not gate the
// payment-confirmation action. This pure core answers three questions the UI
// needs, given plain inputs:
//
//   1. bannerVisible        — show the "入金予定が未登録です" banner (AC: 警告バナー)
//   2. requiresConfirmation — intercept 支払確定 with a cancelable dialog (AC: 確認ダイアログ)
//   3. severity / message   — how loud, and what to say
//
// It has no Flutter / Supabase dependency so it is fully unit-testable (money and
// gating decisions must be deterministic, not AI output). The banner widget,
// the cancelable dialog, and the income-plan registration wizard are the thin UI
// layer built on top of a decision. Registration + cashflow recompute already
// exist; this only adds the missing gate.

enum PaymentGateSeverity { none, info, warning, critical }

/// The gate decision for the current asset-management state.
class PaymentGateDecision {
  /// Show the "入金予定が未登録" banner above the board (AC #1).
  final bool bannerVisible;

  /// Intercept the 支払確定 action with a cancelable confirmation dialog (AC #3).
  final bool requiresConfirmation;

  final PaymentGateSeverity severity;

  /// True when the income-plan list is empty.
  final bool incomePlansMissing;

  /// True when the month's available amount is already negative, or the payment
  /// being confirmed would push it negative.
  final bool projectedShortfall;

  /// Dialog title (null when no confirmation is required).
  final String? confirmationTitle;

  /// Dialog body (null when no confirmation is required).
  final String? confirmationMessage;

  /// Banner text (null when the banner is hidden).
  final String? bannerMessage;

  const PaymentGateDecision({
    required this.bannerVisible,
    required this.requiresConfirmation,
    required this.severity,
    required this.incomePlansMissing,
    required this.projectedShortfall,
    this.confirmationTitle,
    this.confirmationMessage,
    this.bannerMessage,
  });

  bool get blocksConfirmation => requiresConfirmation;
}

/// Evaluate the payment-confirmation gate.
///
/// - [incomePlanCount] — number of registered income plans (0 = 未登録).
/// - [monthlyAvailableAmount] — the month's available amount (negative = 不足).
/// - [paymentAmount] — the amount about to be confirmed as paid, if a specific
///   payment triggered the gate. When provided, a payment that would drive the
///   available amount negative also requires confirmation.
///
/// The gate always keeps the confirmation *cancelable* (the caller shows a
/// dialog with a cancel action); this function only decides whether to show it.
PaymentGateDecision evaluatePaymentConfirmationGate({
  required int incomePlanCount,
  required double monthlyAvailableAmount,
  double? paymentAmount,
}) {
  final incomePlansMissing = incomePlanCount <= 0;

  final alreadyNegative = monthlyAvailableAmount < 0;
  final wouldGoNegative = paymentAmount != null &&
      paymentAmount > 0 &&
      (monthlyAvailableAmount - paymentAmount) < 0;
  final projectedShortfall = alreadyNegative || wouldGoNegative;

  // Severity: missing income + shortfall is the worst; either alone is a warning.
  final PaymentGateSeverity severity;
  if (incomePlansMissing && projectedShortfall) {
    severity = PaymentGateSeverity.critical;
  } else if (incomePlansMissing || projectedShortfall) {
    severity = PaymentGateSeverity.warning;
  } else {
    severity = PaymentGateSeverity.none;
  }

  // The gate intercepts confirmation when income is unregistered (the #3291 ask)
  // or when this payment would cause / deepen a shortfall.
  final requiresConfirmation = incomePlansMissing || projectedShortfall;

  final bannerMessage = incomePlansMissing
      ? '入金予定が未登録です。給料日・金額・入金口座を登録すると、利用可能額と'
          '期日別リスクが正確に再計算されます。'
      : null;

  String? confirmationTitle;
  String? confirmationMessage;
  if (requiresConfirmation) {
    if (incomePlansMissing && projectedShortfall) {
      confirmationTitle = '入金予定が未登録で、利用可能額が不足しています';
      confirmationMessage =
          '入金予定が未登録のまま、利用可能額が不足した状態で支払いを確定しようと'
          'しています。先に入金予定を登録することを強くおすすめします。それでも'
          '支払いを確定しますか？';
    } else if (incomePlansMissing) {
      confirmationTitle = '入金予定が未登録です';
      confirmationMessage =
          '入金予定が未登録のままです。登録すると利用可能額と期日別リスクが'
          '正確になります。このまま支払いを確定しますか？';
    } else {
      confirmationTitle = '利用可能額が不足します';
      confirmationMessage =
          'この支払いを確定すると利用可能額が不足します。口座移動などで資金を'
          '手当てしてからでも確定できます。このまま確定しますか？';
    }
  }

  return PaymentGateDecision(
    bannerVisible: incomePlansMissing,
    requiresConfirmation: requiresConfirmation,
    severity: severity,
    incomePlansMissing: incomePlansMissing,
    projectedShortfall: projectedShortfall,
    confirmationTitle: confirmationTitle,
    confirmationMessage: confirmationMessage,
    bannerMessage: bannerMessage,
  );
}
