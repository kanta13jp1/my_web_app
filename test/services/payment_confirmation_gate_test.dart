import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/payment_confirmation_gate.dart';

void main() {
  group('evaluatePaymentConfirmationGate', () {
    test('no income plans + shortfall is critical and blocks', () {
      // The #3291 scenario: available -236,690 with income_plans = [].
      final d = evaluatePaymentConfirmationGate(
        incomePlanCount: 0,
        monthlyAvailableAmount: -236690,
      );
      expect(d.incomePlansMissing, isTrue);
      expect(d.projectedShortfall, isTrue);
      expect(d.severity, PaymentGateSeverity.critical);
      expect(d.requiresConfirmation, isTrue);
      expect(d.bannerVisible, isTrue);
      expect(d.confirmationTitle, isNotNull);
    });

    test('no income plans but positive available still warns and blocks', () {
      final d = evaluatePaymentConfirmationGate(
        incomePlanCount: 0,
        monthlyAvailableAmount: 50000,
      );
      expect(d.severity, PaymentGateSeverity.warning);
      expect(d.requiresConfirmation, isTrue); // AC: block when income unregistered
      expect(d.bannerVisible, isTrue);
      expect(d.confirmationTitle, '入金予定が未登録です');
    });

    test('income plans present and healthy → no banner, no block', () {
      final d = evaluatePaymentConfirmationGate(
        incomePlanCount: 2,
        monthlyAvailableAmount: 120000,
      );
      expect(d.severity, PaymentGateSeverity.none);
      expect(d.requiresConfirmation, isFalse);
      expect(d.bannerVisible, isFalse);
      expect(d.confirmationTitle, isNull);
      expect(d.confirmationMessage, isNull);
      expect(d.bannerMessage, isNull);
    });

    test('income plans present but already negative → warn + block, no banner', () {
      final d = evaluatePaymentConfirmationGate(
        incomePlanCount: 1,
        monthlyAvailableAmount: -5000,
      );
      expect(d.severity, PaymentGateSeverity.warning);
      expect(d.requiresConfirmation, isTrue);
      expect(d.bannerVisible, isFalse); // banner is income-registration specific
      expect(d.confirmationTitle, '利用可能額が不足します');
    });

    test('a payment that would drive available negative requires confirmation', () {
      final d = evaluatePaymentConfirmationGate(
        incomePlanCount: 3,
        monthlyAvailableAmount: 3000,
        paymentAmount: 8000, // 3000 - 8000 = -5000
      );
      expect(d.projectedShortfall, isTrue);
      expect(d.requiresConfirmation, isTrue);
      expect(d.severity, PaymentGateSeverity.warning);
    });

    test('a payment that fits within available does not block', () {
      final d = evaluatePaymentConfirmationGate(
        incomePlanCount: 3,
        monthlyAvailableAmount: 20000,
        paymentAmount: 8000, // 20000 - 8000 = 12000
      );
      expect(d.projectedShortfall, isFalse);
      expect(d.requiresConfirmation, isFalse);
      expect(d.severity, PaymentGateSeverity.none);
    });

    test('the confirmation is always cancelable by contract (decision only)', () {
      // The gate never forces the payment through; it only signals a dialog.
      final d = evaluatePaymentConfirmationGate(
        incomePlanCount: 0,
        monthlyAvailableAmount: -1,
      );
      expect(d.blocksConfirmation, isTrue);
      // Caller renders a dialog with a cancel action; nothing here auto-confirms.
    });
  });
}
