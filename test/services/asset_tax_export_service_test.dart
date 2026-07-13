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
  });
}
