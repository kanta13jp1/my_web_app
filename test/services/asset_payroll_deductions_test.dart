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
          'long_term_care_insurance': 0,
          'employees_pension_fund_contribution': 0,
          'ideco': 10,
        },
      };

  test('summary separates retrieval verification missing conflict and mismatch',
      () {
    PayrollMonthDeductions month(List<Map<String, dynamic>> rows) =>
        AssetPayrollDeductions.months(
          ownerId: 'owner-a',
          year: 2030,
          rows: rows,
        )[1];
    expect(month([]).summaryStatus(social: false), '明細なし');
    final automatic = month([fixture(status: 'auto')]);
    expect(automatic.summaryStatus(social: false), contains('取得済み・本人未確認'));
    expect(automatic.confirmedTaxYen, isNull);
    final missing = fixture();
    (missing['deductions'] as Map).remove('income_tax');
    expect(
      month([missing]).summaryStatus(social: false),
      contains('本人確認済み／必要項目の記載なし'),
    );
    final alias = fixture();
    (alias['deductions'] as Map)['employees_pension_insurance'] = 99;
    expect(month([alias]).summaryStatus(social: true), contains('項目名違いが競合'));
    final mismatch = fixture();
    mismatch['social_insurance_total'] = 201;
    expect(month([mismatch]).summaryStatus(social: true), contains('内訳が不一致'));
    expect(month([mismatch]).confirmedSocialYen, isNull);
    expect(month([fixture()]).summaryStatus(social: true), '本人確認済み');
  });

  test('missing optional premiums are unknown rather than inferred zero', () {
    final raw = fixture();
    raw['social_insurance_total'] = null;
    final items = raw['deductions'] as Map;
    items.remove('long_term_care_insurance');
    items.remove('employees_pension_fund_contribution');
    expect(PayrollDeductions.fromRow(raw)!.socialPartsTotalYen, isNull);
    expect(PayrollDeductions.fromRow(raw)!.socialTotalYen, isNull);
    items['long_term_care_insurance'] = 0;
    items['employees_pension_fund_contribution'] = 0;
    expect(PayrollDeductions.fromRow(raw)!.socialTotalYen, 200);
    items.remove('long_term_care_insurance');
    raw['social_insurance_total'] = 200;
    expect(PayrollDeductions.fromRow(raw)!.socialTotalYen, 200);
    expect(PayrollDeductions.fromRow(raw)!.socialPartsTotalYen, isNull);
  });
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
  test(
    'normalizes Japanese deduction keys and avoids unknown-key inflation',
    () {
      final raw = fixture(id: 'synthetic-jp-may', date: '2030-05-25');
      raw['gross_amount'] = 600000;
      raw['net_amount'] = 455000;
      raw['social_insurance_total'] = 86500;
      raw['deductions'] = <String, dynamic>{
        '所得税': 29500,
        '住民税': 29000,
        '健康保険料': 28000,
        '介護保険料': 4500,
        '厚生年金保険料': 51000,
        '雇用保険料': 3000,
        '厚生年金基金掛金': 0,
        'IDECO': 0,
      };
      final row = PayrollDeductions.fromRow(raw)!;
      expect(row.taxTotalYen, 58500);
      expect(row.socialTotalYen, 86500);
      expect(row.socialPartsTotalYen, 86500);
      expect(row.socialMismatchYen, 0);
      expect(row.unclassified, isEmpty);
      expect(row.identifiedSubtotalYen, 145000);
      expect(row.unidentifiedDifferenceYen, 0);
      expect(row.conflictingDeductionAliases, isFalse);

      final months = AssetPayrollDeductions.months(
        ownerId: 'owner-a',
        year: 2030,
        rows: [raw],
        asOfDate: DateTime(2030, 5, 25),
      );
      expect(months[4].confirmedTaxYen, 58500);
      expect(months[4].confirmedSocialYen, 86500);
      expect(months[4].summaryStatus(social: false), '本人確認済み');
    },
  );
  test(
    'normalizes singular English social aliases and classifies them as known',
    () {
      final raw = fixture(id: 'synthetic-aug-singular', date: '2030-08-25');
      raw['gross_amount'] = 560000;
      raw['net_amount'] = 420000;
      raw['social_insurance_total'] = 86400;
      raw['deductions'] = <String, dynamic>{
        'income_tax': 23800,
        'resident_tax': 29800,
        'health_insurance': 28200,
        'employment_insurance': 2800,
        'long_term_care_insurance': 4500,
        'employee_pension_insurance': 50900,
        'employee_pension_fund_contribution': 0,
        'ideco': 0,
      };
      final row = PayrollDeductions.fromRow(raw)!;
      expect(row.taxTotalYen, 53600);
      expect(row.socialTotalYen, 86400);
      expect(row.socialPartsTotalYen, 86400);
      expect(row.socialMismatchYen, 0);
      expect(row.unclassified, isEmpty);
      expect(row.unidentifiedDifferenceYen, 0);
    },
  );
  test(
    'matching Japanese and English aliases count once without conflict',
    () {
      final raw = fixture();
      (raw['deductions'] as Map)['所得税'] = 50;
      (raw['deductions'] as Map)['住民税'] = 40;
      final row = PayrollDeductions.fromRow(raw)!;
      expect(row.conflictingDeductionAliases, isFalse);
      expect(row.taxTotalYen, 90);
      expect(row.unclassified, isEmpty);
    },
  );
  test(
    'conflicting tax and social aliases exclude sums and stay unconfirmed',
    () {
      final raw = fixture();
      (raw['deductions'] as Map)['所得税'] = 55;
      final row = PayrollDeductions.fromRow(raw)!;
      expect(row.conflictingTaxAliases, isTrue);
      expect(row.conflictingDeductionAliases, isTrue);
      expect(row.taxTotalYen, isNull);
      final months = AssetPayrollDeductions.months(
        ownerId: 'owner-a',
        year: 2030,
        rows: [raw],
      );
      expect(months[1].confirmedTaxYen, isNull);
      expect(
        months[1].summaryStatus(social: false),
        contains('税金の項目名違いが競合'),
      );

      final socialConflict = fixture();
      (socialConflict['deductions'] as Map)['健康保険料'] = 79;
      final socialRow = PayrollDeductions.fromRow(socialConflict)!;
      expect(socialRow.conflictingSocialAliases, isTrue);
      expect(socialRow.socialPartsTotalYen, isNull);
      final socialMonths = AssetPayrollDeductions.months(
        ownerId: 'owner-a',
        year: 2030,
        rows: [socialConflict],
      );
      expect(socialMonths[1].confirmedSocialYen, isNull);
      expect(
        socialMonths[1].summaryStatus(social: true),
        contains('社会保険の項目名違いが競合'),
      );
    },
  );
  test(
    'null or invalid Japanese alias values remain unknown and never zero',
    () {
      final nullTax = fixture();
      nullTax['deductions'] = <String, dynamic>{
        '所得税': null,
        '住民税': 40,
      };
      expect(PayrollDeductions.fromRow(nullTax)!.taxTotalYen, isNull);

      final invalidTax = fixture();
      invalidTax['deductions'] = <String, dynamic>{
        '所得税': '50',
        '住民税': 40,
      };
      expect(PayrollDeductions.fromRow(invalidTax)!.taxTotalYen, isNull);
    },
  );
  test(
    'future pay_date payslips are excluded from confirmed totals until payday',
    () {
      final raw = fixture(id: 'synthetic-nov-future', date: '2030-11-25');
      final beforePayday = AssetPayrollDeductions.months(
        ownerId: 'owner-a',
        year: 2030,
        rows: [raw],
        asOfDate: DateTime(2030, 11, 24, 23, 59),
      );
      expect(beforePayday[10].hasFuturePayDate, isTrue);
      expect(beforePayday[10].confirmedTaxYen, isNull);
      expect(beforePayday[10].confirmedSocialYen, isNull);
      expect(beforePayday[10].summaryStatus(social: false), contains('支給日未到来'));

      final onPayday = AssetPayrollDeductions.months(
        ownerId: 'owner-a',
        year: 2030,
        rows: [raw],
        asOfDate: DateTime(2030, 11, 25),
      );
      expect(onPayday[10].hasFuturePayDate, isFalse);
      expect(onPayday[10].confirmedTaxYen, 90);
      expect(onPayday[10].confirmedSocialYen, 200);
      expect(onPayday[10].summaryStatus(social: false), '本人確認済み');
    },
  );
}
