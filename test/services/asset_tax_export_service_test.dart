import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_tax_export_service.dart';
import 'package:test/test.dart';

void main() {
  group('AssetTaxExportService', () {
    const service = AssetTaxExportService();

    test('builds preview totals and ignores records outside tax year', () {
      final bundle = service.buildExportBundle(
        taxYear: 2026,
        generatedAt: DateTime.utc(2026, 12, 31, 12),
        records: <AssetTaxRecord>[
          AssetTaxRecord(
            id: 'misc-1',
            occurredOn: DateTime(2026, 1, 10),
            kind: AssetTaxRecordKind.income,
            category: AssetTaxRecordCategory.miscIncome,
            amount: 120000,
            title: 'Affiliate payout',
            counterparty: 'Example, Inc.',
            source: 'tax_records',
          ),
          AssetTaxRecord(
            id: 'biz-1',
            occurredOn: DateTime(2026, 2, 1),
            kind: AssetTaxRecordKind.income,
            category: AssetTaxRecordCategory.businessIncome,
            amount: 250000,
            title: 'Consulting',
            invoiceNumber: 'INV-2026-001',
            taxRate: 0.1,
          ),
          AssetTaxRecord(
            id: 'expense-1',
            occurredOn: DateTime(2026, 2, 5),
            kind: AssetTaxRecordKind.expense,
            category: AssetTaxRecordCategory.businessExpense,
            amount: 33000,
            title: 'SaaS subscription',
          ),
          AssetTaxRecord(
            id: 'old-1',
            occurredOn: DateTime(2025, 12, 31),
            kind: AssetTaxRecordKind.income,
            category: AssetTaxRecordCategory.miscIncome,
            amount: 999999,
            title: 'Previous year',
          ),
        ],
      );

      expect(bundle.preview.records.map((record) => record.id), <String>[
        'misc-1',
        'biz-1',
        'expense-1',
      ]);
      expect(bundle.preview.ignoredRecordCount, 1);
      expect(bundle.preview.totalIncome, 370000);
      expect(bundle.preview.totalExpense, 33000);
      expect(bundle.preview.netBeforeSpecialRules, 337000);
      expect(bundle.preview.confirmation.requiresReview, isTrue);
      expect(bundle.preview.confirmation.summaryLines, contains('Records: 3'));
    });

    test('exports deterministic CSV with escaped cells', () {
      final preview = service.buildPreview(
        taxYear: 2026,
        generatedAt: DateTime.utc(2026, 7, 13),
        records: <AssetTaxRecord>[
          AssetTaxRecord(
            id: 'misc-1',
            occurredOn: DateTime(2026, 7, 1),
            kind: AssetTaxRecordKind.income,
            category: AssetTaxRecordCategory.miscIncome,
            amount: 12345,
            title: 'Article "royalty"',
            counterparty: 'Example, Inc.',
            memo: 'includes comma, quote " and memo',
          ),
        ],
      );

      final csv = service.buildCsv(preview);

      expect(csv, contains('tax_year,date,kind,category'));
      expect(csv, contains('2026,2026-07-01,income,miscIncome'));
      expect(csv, contains('"Article ""royalty"""'));
      expect(csv, contains('"Example, Inc."'));
      expect(csv, contains('"includes comma, quote "" and memo"'));
    });

    test('neutralizes spreadsheet formula prefixes in CSV cells', () {
      final preview = service.buildPreview(
        taxYear: 2026,
        generatedAt: DateTime.utc(2026, 7, 13),
        records: <AssetTaxRecord>[
          AssetTaxRecord(
            id: '\r=record-id',
            occurredOn: DateTime(2026, 7, 1),
            kind: AssetTaxRecordKind.income,
            category: AssetTaxRecordCategory.miscIncome,
            amount: 12345,
            title: '=SUM(A1:A2)',
            counterparty: '+HYPERLINK("https://example.com")',
            invoiceNumber: '-1+2',
            memo: '@SUM(A1:A2)',
            source: '\t=external',
          ),
        ],
      );

      final csv = service.buildCsv(preview);

      expect(csv, contains("'=SUM(A1:A2)"));
      expect(csv, contains("'+HYPERLINK("));
      expect(csv, contains("'-1+2"));
      expect(csv, contains("'@SUM(A1:A2)"));
      expect(csv, contains("'\t=external"));
      expect(csv, contains("'\r=record-id"));
    });

    test('uses JST consistently for tax-year filtering and CSV dates', () {
      final bundle = service.buildExportBundle(
        taxYear: 2026,
        generatedAt: DateTime.utc(2026, 1, 1),
        records: <AssetTaxRecord>[
          AssetTaxRecord(
            id: 'jst-new-year',
            occurredOn: DateTime.utc(2025, 12, 31, 15),
            kind: AssetTaxRecordKind.income,
            category: AssetTaxRecordCategory.miscIncome,
            amount: 1000,
            title: 'JST new year',
          ),
          AssetTaxRecord(
            id: 'jst-next-year',
            occurredOn: DateTime.utc(2026, 12, 31, 15),
            kind: AssetTaxRecordKind.income,
            category: AssetTaxRecordCategory.miscIncome,
            amount: 2000,
            title: 'JST next year',
          ),
        ],
      );

      expect(bundle.preview.records.map((record) => record.id), <String>[
        'jst-new-year',
      ]);
      expect(bundle.preview.ignoredRecordCount, 1);
      expect(bundle.csv, contains('2026,2026-01-01,income,miscIncome'));
      expect(bundle.csv, isNot(contains('jst-next-year')));
    });

    test('exports e-Tax XML skeleton grouped by category', () {
      final preview = service.buildPreview(
        taxYear: 2026,
        generatedAt: DateTime.utc(2026, 7, 13),
        records: <AssetTaxRecord>[
          AssetTaxRecord(
            id: 'real-estate-1',
            occurredOn: DateTime(2026, 3, 1),
            kind: AssetTaxRecordKind.income,
            category: AssetTaxRecordCategory.realEstateIncome,
            amount: 80000,
            title: 'Rent <March>',
            counterparty: 'Tenant & Co',
          ),
          AssetTaxRecord(
            id: 'furusato-1',
            occurredOn: DateTime(2026, 6, 1),
            kind: AssetTaxRecordKind.deduction,
            category: AssetTaxRecordCategory.furusatoTaxDonation,
            amount: 20000,
            title: 'Donation',
          ),
        ],
      );

      final xml = service.buildETaxXmlSkeleton(preview);

      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml, contains('<jibun_tax_export version="0.1"'));
      expect(
        xml,
        contains(
          '<summary total_income="80000" total_expense="0" total_deduction="20000" net_before_special_rules="60000" />',
        ),
      );
      expect(xml, contains('<section code="realEstateIncome"'));
      expect(xml, contains('<title>Rent &lt;March&gt;</title>'));
      expect(xml, contains('<counterparty>Tenant &amp; Co</counterparty>'));
      expect(xml, contains('<section code="furusatoTaxDonation"'));
    });

    test('surfaces preview warnings before export', () {
      final preview = service.buildPreview(
        taxYear: 2026,
        records: <AssetTaxRecord>[
          AssetTaxRecord(
            id: 'bad-1',
            occurredOn: DateTime(2026, 1, 1),
            kind: AssetTaxRecordKind.income,
            category: AssetTaxRecordCategory.furusatoTaxDonation,
            amount: 0,
            title: '',
          ),
        ],
      );

      expect(preview.confirmation.requiresReview, isTrue);
      expect(preview.warnings, contains('Record bad-1 has zero amount.'));
      expect(preview.warnings, contains('Record bad-1 is missing a title.'));
      expect(
        preview.warnings,
        contains(
          'Record bad-1 is furusato tax but is not marked as deduction.',
        ),
      );
    });

    test('extracts tax records from workbook income plans and cashflow rows',
        () {
      final workbook = AssetLiabilityWorkbook(
        baseDate: DateTime(2026, 6, 1),
        accounts: const [],
        debtMasterRows: const [],
        repaymentPriorityRows: const [],
        paymentDayRisks: const [],
        cashflowRows: [
          AssetLiabilityCashflowRow(
            eventType: AssetLiabilityCashflowEventType.payment,
            accountId: 'act-1',
            accountName: 'ふるさと納税 寄付金',
            paymentDay: 15,
            paymentDate: DateTime(2026, 6, 15),
            paymentSourceAccountId: 'bank-1',
            paymentSourceAccountName: 'Bank',
            destinationAccountId: 'furusato',
            destinationAccountName: 'Municipality',
            paymentMethod: AssetLiabilityPaymentMethod.direct,
            paymentMethodLabel: 'Direct',
            paymentMethodSettingSource:
                AssetLiabilityPaymentMethodSettingSource.builtInDefault,
            billingAccountId: null,
            billingAccountName: null,
            includedInBillingAccount: false,
            paymentAmount: 50000,
            paymentAmountEstimated: false,
            paid: true,
            received: false,
            overdue: false,
            cashBeforePayment: 100000,
            cashAfterPayment: 50000,
            riskLevel: AssetLiabilityCashRiskLevel.normal,
          ),
          AssetLiabilityCashflowRow(
            eventType: AssetLiabilityCashflowEventType.payment,
            accountId: 'act-2',
            accountName: 'サーバー代',
            paymentDay: 20,
            paymentDate: DateTime(2026, 6, 20),
            paymentSourceAccountId: 'card-1',
            paymentSourceAccountName: 'Card',
            destinationAccountId: 'cloud',
            destinationAccountName: 'Cloud Provider',
            paymentMethod: AssetLiabilityPaymentMethod.direct,
            paymentMethodLabel: 'Direct',
            paymentMethodSettingSource:
                AssetLiabilityPaymentMethodSettingSource.builtInDefault,
            billingAccountId: null,
            billingAccountName: null,
            includedInBillingAccount: false,
            paymentAmount: 15000,
            paymentAmountEstimated: false,
            paid: true,
            received: false,
            overdue: false,
            cashBeforePayment: 50000,
            cashAfterPayment: 35000,
            riskLevel: AssetLiabilityCashRiskLevel.normal,
          ),
        ],
        incomePlans: [
          AssetLiabilityIncomePlan(
            id: 'inc-1',
            date: DateTime(2026, 6, 25),
            name: '業務委託報酬',
            amount: 400000,
            destinationAccountId: 'bank-1',
            destinationAccountName: 'Main Bank',
            received: true,
          ),
        ],
        transferTasks: const [],
        accountCashflowSummaries: const [],
        transferSuggestions: const [],
        cardBillingReview: const AssetLiabilityCardBillingReviewData(
          directPaymentItems: [],
          cardBillingGroups: [],
          missingBillingAccountItems: [],
          needsReviewItems: [],
          doubleCountingRiskItems: [],
        ),
        cardStatementReconciliation:
            const AssetLiabilityCardStatementReconciliationData(
          groups: [],
          unmatchedStatementLines: [],
        ),
        cashLikeTotal: 100000,
        securitiesTotal: 0,
        positiveAssetTotal: 100000,
        liabilityTotal: 0,
        netWorth: 100000,
        monthlyMinimumPaymentEstimateTotal: 0,
        monthlyScheduledPaymentTotal: 65000,
        monthlyActualPaymentTotal: 65000,
        monthlyPaymentDifferenceTotal: 0,
        monthlyUnpaidPaymentTotal: 0,
        monthlyUnreceivedIncomeTotal: 0,
        cashAfterMinimumPayments: 100000,
        cashAfterScheduledPayments: 35000,
        debtToAssetRatio: 0,
        topFourDebtShare: 0,
        manualPaymentCount: 0,
        estimatedPaymentCount: 0,
        subscriptionFixedCostAccountIds: const {},
        cardUsagePolicies: const {},
      );

      final extracted = service.extractRecordsFromWorkbook(
        workbook: workbook,
        targetYear: 2026,
      );

      expect(extracted.length, 3);
      final income =
          extracted.firstWhere((r) => r.kind == AssetTaxRecordKind.income);
      expect(income.amount, 400000);
      expect(income.title, '業務委託報酬');

      final furusato = extracted.firstWhere(
        (r) => r.category == AssetTaxRecordCategory.furusatoTaxDonation,
      );
      expect(furusato.amount, 50000);
      expect(furusato.kind, AssetTaxRecordKind.deduction);

      final expense = extracted.firstWhere(
        (r) => r.category == AssetTaxRecordCategory.businessExpense,
      );
      expect(expense.amount, 15000);
      expect(expense.title, 'サーバー代');
    });
  });
}
