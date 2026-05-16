import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_card_statement_import_service.dart';

void main() {
  group('AssetLiabilityCardStatementImportService', () {
    const service = AssetLiabilityCardStatementImportService();

    test('imports pasted manual rows with a default billing card', () {
      final result = service.parse(
        rawText: 'Netflix,1980,2026-05-10\nMobile plan,5764,2026-05-12',
        defaultBillingAccountId: 'paypay_card',
        defaultBillingAccountName: 'PayPay card',
      );

      expect(result.rejectedRows, isEmpty);
      expect(result.lines, hasLength(2));
      expect(result.lines.first.billingAccountId, 'paypay_card');
      expect(result.lines.first.description, 'Netflix');
      expect(result.lines.first.amount, 1980);
      expect(result.lines.first.postedAt, DateTime(2026, 5, 10));
    });

    test('imports CSV rows that include billing account ids', () {
      final result = service.parse(
        rawText: [
          'billing_account_id,description,amount,posted_at',
          'aupay_card,"mobile, data",6200,2026-05-11',
        ].join('\n'),
      );

      expect(result.rejectedRows, isEmpty);
      expect(result.lines.single.billingAccountId, 'aupay_card');
      expect(result.lines.single.description, 'mobile, data');
      expect(result.lines.single.amount, 6200);
    });

    test('rejects malformed rows without stopping the import', () {
      final result = service.parse(
        rawText: 'Netflix,1980\nbad-row\nMobile plan,not-number',
        defaultBillingAccountId: 'paypay_card',
      );

      expect(result.lines, hasLength(1));
      expect(result.rejectedRows, hasLength(2));
      expect(result.rejectedRows.first.rowNumber, 2);
    });
  });
}
