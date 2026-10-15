import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_deductions.dart';

void main() {
  Map<String, dynamic> fixture({
    String id = 'synthetic-a',
    String owner = 'owner-a',
    String status = 'confirmed',
    String date = '2030-02-20',
  }) =>
      {
        'id': id,
        'user_id': owner,
        'pay_date': date,
        'review_status': status,
        'gross_amount': 1000,
        'net_amount': 700,
        'social_insurance_total': 200,
        'deductions': <String, dynamic>{
          'income_tax': 50,
          'resident_tax': 40,
          'health_insurance': 80,
          'pension': 100,
          'employment_insurance': 20,
          'ideco': 10,
        },
      };

  test('AI pension alias and care/fund remain one social total', () {
    final raw = fixture();
    raw['social_insurance_total'] = 230;
    raw['deductions'] = {
      'income_tax': 50,
      'resident_tax': 40,
      'health_insurance': 80,
      'employees_pension_insurance': 100,
      'employment_insurance': 20,
      'long_term_care_insurance': 10,
      'employees_pension_fund_contribution': 20,
      'ideco': 10,
    };
    final row = PayrollDeductions.fromRow(raw)!;
    expect(row.items['pension'], 100);
    expect(row.socialPartsTotalYen, 230);
    expect(row.socialTotalYen, 230);
    expect(row.identifiedSubtotalYen, 330);
    expect(row.socialMismatchYen, 0);
    expect(row.unclassified, isEmpty);
  });
  test('matching pension aliases count once and conflicting ones need review',
      () {
    final raw = fixture();
    (raw['deductions'] as Map)['employees_pension_insurance'] = 100;
    expect(PayrollDeductions.fromRow(raw)!.socialPartsTotalYen, 200);
    (raw['deductions'] as Map)['employees_pension_insurance'] = 101;
    final row = PayrollDeductions.fromRow(raw)!;
    expect(row.conflictingPensionAliases, isTrue);
    expect(row.socialPartsTotalYen, isNull);
    final month = AssetPayrollDeductions.months(
      ownerId: 'owner-a',
      year: 2030,
      rows: [raw],
    )[1];
    expect(month.confirmedSocialYen, isNull);
  });
  test('present unknown optional premium is not treated as zero', () {
    final raw = fixture();
    raw['social_insurance_total'] = null;
    (raw['deductions'] as Map)['long_term_care_insurance'] = null;
    expect(PayrollDeductions.fromRow(raw)!.socialTotalYen, isNull);
  });
  test(
    'social total replaces components and iDeCo is neither tax nor social',
    () {
      final row = PayrollDeductions.fromRow(fixture())!;
      expect(
        row.taxTotalYen,
        90,
      );
      expect(
        row.socialTotalYen,
        200,
      );
      expect(
        row.socialMismatchYen,
        0,
      );
      expect(
        row.identifiedSubtotalYen,
        300,
      );
      expect(
        row.derivedDeductionTotalYen,
        300,
      );
      expect(
        row.unidentifiedDifferenceYen,
        0,
      );
    },
  );
  test(
    'missing values are unknown while explicitly reported zeros remain zero',
    () {
      final raw = fixture();
      raw['deductions'] = {'income_tax': 0, 'resident_tax': 0};
      raw['social_insurance_total'] = null;
      final row = PayrollDeductions.fromRow(raw)!;
      expect(
        row.taxTotalYen,
        0,
      );
      expect(
        row.socialTotalYen,
        isNull,
      );
      expect(
        row.items['health_insurance'],
        isNull,
      );
    },
  );
  test(
    'partial tax extraction has no full tax total',
    () {
      final raw = fixture();
      (raw['deductions'] as Map).remove(
        'resident_tax',
      );
      final row = PayrollDeductions.fromRow(raw)!;
      expect(
        row.taxTotalYen,
        isNull,
      );
      expect(
        row.items['income_tax'],
        50,
      );
    },
  );
  test(
    'negative withholding adjustment retains its sign',
    () {
      final raw = fixture();
      (raw['deductions'] as Map)['income_tax'] = -50;
      final row = PayrollDeductions.fromRow(raw)!;
      expect(
        row.taxTotalYen,
        -10,
      );
      expect(
        row.unidentifiedDifferenceYen,
        100,
      );
    },
  );
  test(
    'unknown keys and invalid numeric values retain unknown classification',
    () {
      final raw = fixture();
      (raw['deductions'] as Map)['unknown_component'] = 15;
      (raw['deductions'] as Map)['income_tax'] = '50';
      final row = PayrollDeductions.fromRow(raw)!;
      expect(
        row.unclassified['unknown_component'],
        15,
      );
      expect(
        row.taxTotalYen,
        isNull,
      );
      expect(
        PayrollDeductions.readYen(double.infinity),
        isNull,
      );
      expect(
        PayrollDeductions.readYen(12.5),
        isNull,
      );
    },
  );
  test(
    'social mismatch is visible without adding two social totals',
    () {
      final raw = fixture();
      raw['social_insurance_total'] = 210;
      final row = PayrollDeductions.fromRow(raw)!;
      expect(
        row.socialMismatchYen,
        10,
      );
      expect(
        row.identifiedSubtotalYen,
        310,
      );
    },
  );
  test(
    'only owner rows and confirmed months enter comparison',
    () {
      final months = AssetPayrollDeductions.months(
        ownerId: 'owner-a',
        year: 2030,
        rows: [
          fixture(),
          fixture(id: 'foreign', owner: 'owner-b'),
          fixture(id: 'auto', status: 'auto', date: '2030-03-20'),
          fixture(id: 'rejected', status: 'rejected', date: '2030-04-20'),
        ],
      );
      expect(
        months[1].confirmedTaxYen,
        90,
      );
      expect(
        months[2].confirmedTaxYen,
        isNull,
      );
      expect(
        months[3].statements,
        isEmpty,
      );
      expect(
        months[0].confirmedTaxYen,
        isNull,
      );
    },
  );
  test(
    'repeated same source is deduplicated and different content conflicts',
    () {
      var months = AssetPayrollDeductions.months(
        ownerId: 'owner-a',
        year: 2030,
        rows: [fixture(), fixture()],
      );
      expect(
        months[1].statements,
        hasLength(1),
      );
      expect(
        months[1].confirmedTaxYen,
        90,
      );
      final corrected = fixture();
      corrected['net_amount'] = 600;
      months = AssetPayrollDeductions.months(
        ownerId: 'owner-a',
        year: 2030,
        rows: [fixture(), corrected],
      );
      expect(
        months[1].conflicting,
        isTrue,
      );
      expect(
        months[1].confirmedTaxYen,
        isNull,
      );
    },
  );
  test(
    'multiple distinct payslips in one month are combined without loss',
    () {
      final months = AssetPayrollDeductions.months(
        ownerId: 'owner-a',
        year: 2030,
        rows: [fixture(), fixture(id: 'synthetic-b')],
      );
      expect(
        months[1].statements,
        hasLength(2),
      );
      expect(
        months[1].confirmedTaxYen,
        180,
      );
    },
  );
  test(
    'invalid or missing dates never roll into another month',
    () {
      expect(
        PayrollDeductions.fromRow(fixture(date: '2030-02-31')),
        isNull,
      );
      expect(
        PayrollDeductions.fromRow(fixture(date: '')),
        isNull,
      );
    },
  );
}
