/// 入金予定未設定・支払後マイナス転落の確定前ゲート判定 (#3291)。
enum PaymentConfirmationGateSeverity { none, warning, critical }

class PaymentConfirmationGateResult {
  final bool showIncomeMissingBanner;
  final bool requiresConfirmationDialog;
  final PaymentConfirmationGateSeverity severity;
  final String bannerMessage;
  final String dialogTitle;
  final String dialogMessage;

  const PaymentConfirmationGateResult({
    required this.showIncomeMissingBanner,
    required this.requiresConfirmationDialog,
    required this.severity,
    required this.bannerMessage,
    required this.dialogTitle,
    required this.dialogMessage,
  });
}

class PaymentConfirmationGate {
  const PaymentConfirmationGate._();

  static PaymentConfirmationGateResult evaluate({
    required int incomePlanCount,
    required double monthlyAvailableAmount,
    double? paymentAmount,
  }) {
    if (incomePlanCount <= 0) {
      final isCritical = monthlyAvailableAmount < 0;
      return PaymentConfirmationGateResult(
        showIncomeMissingBanner: true,
        requiresConfirmationDialog: true,
        severity: isCritical
            ? PaymentConfirmationGateSeverity.critical
            : PaymentConfirmationGateSeverity.warning,
        bannerMessage: '今月の入金予定が未登録です。給料日・金額・入金口座を登録してから支払いを確定してください。',
        dialogTitle: '入金予定が未登録です',
        dialogMessage: '入金予定が登録されていないため資金不足の試算が確定していません。'
            '先に入金予定を登録するか、内容を確認したうえで支払確定を進めてください。',
      );
    }

    if (paymentAmount != null && (monthlyAvailableAmount - paymentAmount) < 0) {
      return const PaymentConfirmationGateResult(
        showIncomeMissingBanner: false,
        requiresConfirmationDialog: true,
        severity: PaymentConfirmationGateSeverity.warning,
        bannerMessage: '',
        dialogTitle: '今月の使用可能額がマイナスになります',
        dialogMessage: 'この支払いを確定すると今月の使用可能額がマイナスに転落します。実行してよろしいですか？',
      );
    }

    return const PaymentConfirmationGateResult(
      showIncomeMissingBanner: false,
      requiresConfirmationDialog: false,
      severity: PaymentConfirmationGateSeverity.none,
      bannerMessage: '',
      dialogTitle: '',
      dialogMessage: '',
    );
  }

  static String? validateIncomePlanInput({
    required int? dayOfMonth,
    required double? amount,
    required String name,
  }) {
    if (dayOfMonth == null || dayOfMonth < 1 || dayOfMonth > 31) {
      return '給料日は 1〜31 の日付で入力してください。';
    }
    if (amount == null || amount <= 0) {
      return '入金金額は 1 円以上で入力してください。';
    }
    if (name.trim().isEmpty) {
      return '収入名を入力してください。';
    }
    return null;
  }
}
