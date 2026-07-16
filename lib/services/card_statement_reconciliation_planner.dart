// Card-statement reconciliation manual-adjustment planner.
//
// Deterministic money logic shared by three open asset-management requests:
//   #3326 — manual statement entry: validate configured total vs billed amount
//           and clear the alert when the difference reaches zero.
//   #3329 — 3-step reconciliation wizard (請求額確認 → 差分入力 → 保存): needs the
//           current difference, a pre-fillable balancing amount, and a live preview.
//   #3349 — 仮内訳 (provisional): save a difference as a provisional line that is
//           excluded from official totals and can later be promoted or deleted.
//
// It is intentionally free of Flutter / Supabase / workbook dependencies so the
// arithmetic is pure and fully unit-testable (money must not come from AI output,
// per docs/asset-management-wbs-plan.md). It complements — does not replace —
// AssetLiabilityCardStatementReconciliationGroup, which has no manual-adjustment
// or provisional concept. The UI wizard and persistence layer build on a plan.

/// Money comparison tolerance in yen. Mirrors the existing `_moneyDiffers` guard
/// (`>= 0.5`) so an adjustment that lands within half a yen counts as balanced.
const double kCardReconciliationToleranceYen = 0.5;

/// A user-entered adjustment to a card's configured breakdown. `provisional`
/// lines (#3349) are held aside and excluded from official totals until promoted.
class CardManualAdjustment {
  /// Signed yen amount added to the configured breakdown total.
  final double amount;
  final String memo;
  final bool provisional;

  const CardManualAdjustment({
    required this.amount,
    this.memo = '',
    this.provisional = false,
  });

  CardManualAdjustment promote() => CardManualAdjustment(
        amount: amount,
        memo: memo,
        provisional: false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'amount': amount,
        'memo': memo,
        'provisional': provisional,
      };
}

/// The result of previewing (or validating) a proposed manual adjustment.
class CardAdjustmentPreview {
  final bool valid;
  final String? error;

  /// The configured-vs-billed difference after applying the proposed amount
  /// (official lines only; provisional proposals do not move this).
  final double resultingDifference;

  /// True when applying this amount brings the official difference to zero
  /// (within tolerance) — i.e. the mismatch alert would clear.
  final bool resolvesAlert;

  /// True when the amount overshoots (flips the sign of the difference).
  final bool overshoots;

  const CardAdjustmentPreview({
    required this.valid,
    required this.resultingDifference,
    required this.resolvesAlert,
    required this.overshoots,
    this.error,
  });

  factory CardAdjustmentPreview.invalid(String error) => CardAdjustmentPreview(
        valid: false,
        error: error,
        resultingDifference: double.nan,
        resolvesAlert: false,
        overshoots: false,
      );
}

/// A snapshot of a single card's reconciliation state plus any manual
/// adjustments, exposing the derived totals the wizard/UI needs.
class CardReconciliationPlan {
  final double billedAmount;

  /// Sum of the officially configured breakdown items (excludes manual lines).
  final double configuredDetailTotal;

  final double statementLineTotal;
  final bool hasStatementLines;

  /// Revolving-credit cards legitimately have 請求額 ≠ 明細合計, so mismatch
  /// alerts are suppressed (mirrors the existing model's `isRevolving`).
  final bool isRevolving;

  final List<CardManualAdjustment> manualAdjustments;

  const CardReconciliationPlan({
    required this.billedAmount,
    required this.configuredDetailTotal,
    this.statementLineTotal = 0,
    this.hasStatementLines = false,
    this.isRevolving = false,
    this.manualAdjustments = const <CardManualAdjustment>[],
  });

  double get officialAdjustmentTotal => manualAdjustments
      .where((a) => !a.provisional)
      .fold<double>(0, (sum, a) => sum + a.amount);

  /// Provisional lines are tracked but excluded from official aggregation (#3349).
  double get provisionalTotal => manualAdjustments
      .where((a) => a.provisional)
      .fold<double>(0, (sum, a) => sum + a.amount);

  /// Official configured total including promoted manual adjustments.
  double get effectiveConfiguredTotal =>
      configuredDetailTotal + officialAdjustmentTotal;

  /// Configured-vs-billed difference (negative = configured is short of billed).
  double get configuredDifference => effectiveConfiguredTotal - billedAmount;

  double? get statementDifference =>
      hasStatementLines ? statementLineTotal - billedAmount : null;

  /// Within tolerance of zero → the configured breakdown matches the bill.
  bool get isConfiguredBalanced =>
      configuredDifference.abs() < kCardReconciliationToleranceYen;

  /// The card needs manual review when (non-revolving and) either the configured
  /// total does not match the bill, or no statement lines were imported.
  bool get needsReview {
    if (isRevolving) return false;
    return !isConfiguredBalanced || !hasStatementLines;
  }

  /// Human-readable alerts (mirrors the messages the planning service emits).
  List<String> get alerts {
    if (isRevolving) return const <String>[];
    final out = <String>[];
    if (!hasStatementLines) {
      out.add('カード明細の取り込みが未実施です');
    }
    if (!isConfiguredBalanced) {
      out.add('設定済みカード内訳合計が請求額と一致しません');
    }
    return out;
  }

  /// The signed amount that, added as an official adjustment, would exactly
  /// balance the configured total against the bill. The wizard pre-fills this
  /// (e.g. the auPAY 8,011 difference in the requests).
  double get suggestedBalancingAmount => billedAmount - effectiveConfiguredTotal;

  /// Preview the effect of adding [amount] as an adjustment. A `provisional`
  /// proposal is validated but does not move the official difference (#3349).
  CardAdjustmentPreview previewAdjustment(
    double amount, {
    bool provisional = false,
  }) {
    final validation = validateAdjustmentAmount(amount);
    if (!validation.valid) return validation;

    if (provisional) {
      // Provisional lines never change the official difference.
      return CardAdjustmentPreview(
        valid: true,
        resultingDifference: configuredDifference,
        resolvesAlert: isConfiguredBalanced,
        overshoots: false,
      );
    }

    final resulting = configuredDifference + amount;
    final resolves = resulting.abs() < kCardReconciliationToleranceYen;
    final overshoots = !resolves &&
        configuredDifference != 0 &&
        resulting.sign != configuredDifference.sign;
    return CardAdjustmentPreview(
      valid: true,
      resultingDifference: resulting,
      resolvesAlert: resolves,
      overshoots: overshoots,
    );
  }

  /// Validate a proposed adjustment amount in isolation.
  CardAdjustmentPreview validateAdjustmentAmount(double amount) {
    if (amount.isNaN || amount.isInfinite) {
      return CardAdjustmentPreview.invalid('金額が数値ではありません');
    }
    if (amount.abs() < kCardReconciliationToleranceYen) {
      return CardAdjustmentPreview.invalid('金額が0円です');
    }
    return CardAdjustmentPreview(
      valid: true,
      resultingDifference: configuredDifference + amount,
      resolvesAlert:
          (configuredDifference + amount).abs() < kCardReconciliationToleranceYen,
      overshoots: false,
    );
  }

  /// Return a new plan with [adjustment] appended (immutably) — the "保存" step.
  CardReconciliationPlan withAdjustment(CardManualAdjustment adjustment) {
    return CardReconciliationPlan(
      billedAmount: billedAmount,
      configuredDetailTotal: configuredDetailTotal,
      statementLineTotal: statementLineTotal,
      hasStatementLines: hasStatementLines,
      isRevolving: isRevolving,
      manualAdjustments: <CardManualAdjustment>[...manualAdjustments, adjustment],
    );
  }
}
