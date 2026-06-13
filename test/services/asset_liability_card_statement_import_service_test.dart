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

    test('imports auPAY tab-separated statement with Japanese header', () {
      final result = service.parse(
        rawText: [
          'ご利用者\t支払区分\t利用日\t利用店名\t利用金額\t摘要',
          '本人(1034)\tリボ払い・「あらかじめリボ」\t2026/5/31\t'
              'レモンガス（株）　東京支社\t8066\t',
          '本人(1034)\tリボ払い・「あらかじめリボ」\t2026/6/11\t'
              'ａｕ電話利用料\t15116\t０５月分',
        ].join('\n'),
        defaultBillingAccountId: 'aupay_card',
        defaultBillingAccountName: 'auPAYカード',
      );

      expect(result.rejectedRows, isEmpty);
      expect(result.lines, hasLength(2));
      final first = result.lines.first;
      expect(first.billingAccountId, 'aupay_card');
      expect(first.description, 'レモンガス（株）　東京支社');
      expect(first.amount, 8066);
      expect(first.postedAt, DateTime(2026, 5, 31));
      final second = result.lines[1];
      expect(second.description, 'ａｕ電話利用料');
      expect(second.amount, 15116);
      expect(second.postedAt, DateTime(2026, 6, 11));
    });

    test('header-driven mapping uses 摘要 when no 利用店名 column', () {
      final result = service.parse(
        rawText: [
          '利用日\t摘要\t利用金額',
          '2026/05/10\tNetflix\t1,980',
        ].join('\n'),
        defaultBillingAccountId: 'paypay_card',
      );

      expect(result.rejectedRows, isEmpty);
      expect(result.lines.single.description, 'Netflix');
      expect(result.lines.single.amount, 1980);
      expect(result.lines.single.postedAt, DateTime(2026, 5, 10));
    });

    test('normalizes full-width digits in amount and date', () {
      final result = service.parse(
        rawText: '利用日\t利用店名\t利用金額\n'
            '２０２６/６/１１\tａｕ電話利用料\t１５１１６',
        defaultBillingAccountId: 'aupay_card',
      );

      expect(result.rejectedRows, isEmpty);
      expect(result.lines.single.amount, 15116);
      expect(result.lines.single.postedAt, DateTime(2026, 6, 11));
    });
  });
}
