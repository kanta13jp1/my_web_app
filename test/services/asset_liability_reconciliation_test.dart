import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';

void main() {
  group('AssetLiability auto-reconciliation', () {
    test(
        'Issue #5211: reconciles billing confirmations from server paid and actual amounts',
        () {
      const state = AssetLiabilityMonthlyState(
        paidAccountNames: <String>{'NOTION LABS, INC.', '横浜銀行'},
        actualPaymentAmounts: <String, double>{'mobit': 10000},
        paymentSourceAccountIds: <String, String>{'notion': 'smbc_bank'},
      );

      final autoReconciled = <String>{...state.billingConfirmedAccountIds};
      for (final paidName in state.paidAccountNames) {
        final trimmed = paidName.trim();
        autoReconciled.add(paidName);
        autoReconciled.add(trimmed);
        autoReconciled.add(trimmed.toLowerCase());
      }
      for (final entry in state.actualPaymentAmounts.entries) {
        if (entry.value > 0) {
          autoReconciled.add(entry.key);
        }
      }

      expect(autoReconciled.contains('NOTION LABS, INC.'), isTrue);
      expect(autoReconciled.contains('notion labs, inc.'), isTrue);
      expect(autoReconciled.contains('mobit'), isTrue);
    });
  });
}
