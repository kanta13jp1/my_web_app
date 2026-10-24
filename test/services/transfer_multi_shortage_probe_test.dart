import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  test('combined proposals preserve the donor reserve across two shortages', () {
    final book = const AssetLiabilityPlanningService().buildWorkbook(
      latestSnapshot: <String, double>{
        'cash': 100000,
        'bank': 10000,
        'bank_two': 10000,
        'mobit': -100000,
        'paypay': -100000,
      },
      baseDate: DateTime(2026, 5, 1),
      monthlyPaymentOverrides: const <String, double>{
        'mobit': 60000,
        'paypay_card': 60000,
      },
      paymentSourceAccountIds: const <String, String>{
        'mobit': 'custom_bank',
        'paypay_card': 'custom_bank_two',
      },
    );
    final shortages = book.accountCashflowSummaries.where((x) => x.isShort).toList();
    expect(
      shortages,
      hasLength(2),
      reason: 'fixture must contain two independent deposit-account shortages',
    );
    expect(book.transferSuggestions, hasLength(2));
    expect(
      book.transferSuggestions.map((x) => x.amount).toList(),
      <double>[50000, 20000],
    );
    final total = book.transferSuggestions
        .where((x) => x.fromAccountId == 'custom_cash')
        .fold<double>(0, (a, x) => a + x.amount);
    expect(
      total,
      70000,
      reason: '100000 current cash minus 30000 reserve covers the combined plan',
    );
  });
}
