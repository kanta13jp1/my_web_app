import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payslip_item_label.dart';

void main() {
  test('parser earning keys have Japanese display labels', () {
    expect(
      PayslipItemLabel.earnings.keys,
      containsAll([
        'base_salary',
        'fixed_overtime',
        'overtime',
        'allowance',
        'commuting',
      ]),
    );
    expect(
      PayslipItemLabel.label(PayslipItemGroup.earning, 'base_salary'),
      '基本給',
    );
  });
  test('unknown key and raw values survive without guessed units', () {
    expect(
      PayslipItemLabel.label(PayslipItemGroup.earning, 'future_key'),
      'その他（future_key）',
    );
    expect(
      PayslipItemLabel.value(PayslipItemGroup.attendance, 'future_key', -1.5),
      '-1.5',
    );
    expect(
      PayslipItemLabel.value(PayslipItemGroup.earning, 'base_salary', 0),
      '0',
    );
    expect(
      PayslipItemLabel.value(PayslipItemGroup.attendance, 'work_days', null),
      '未取得',
    );
    expect(
      PayslipItemLabel.value(PayslipItemGroup.attendance, 'work_days', 20),
      '20日',
    );
    expect(
      PayslipItemLabel.value(
        PayslipItemGroup.attendance,
        'overtime_hours',
        1.5,
      ),
      '1.5時間',
    );
    expect(
      PayslipItemLabel.value(PayslipItemGroup.attendance, 'work_days', '20?'),
      '20?',
    );
  });
  test('additional observed keys use conservative Japanese labels', () {
    const labels = {
      'meal_allowance': '食事手当',
      'project_allowance_1': 'プロジェクト手当1',
      'project_allowance_2': 'プロジェクト手当2',
      'basic_salary_monthly': '月額基本給',
      'fixed_overtime_allowance': '固定残業手当',
      'over_60h_month_allowance': '月60時間超の手当',
      'late_night_work_allowance': '深夜勤務手当',
      'commuting_allowance_taxable': '課税通勤手当',
      'overtime_allowance_non_legal': '残業手当（non_legal区分）',
      'commuting_allowance_non_taxable': '非課税通勤手当',
      'statutory_holiday_work_allowance': '法定休日勤務手当',
      'non_statutory_holiday_work_allowance': '法定外休日勤務手当',
      'over_40h_week_allowance_scheduled_working_hours': '週40時間超の手当（所定労働時間）',
    };
    for (final entry in labels.entries) {
      expect(
        PayslipItemLabel.label(PayslipItemGroup.earning, entry.key),
        entry.value,
      );
    }
    expect(
      PayslipItemLabel.label(PayslipItemGroup.attendance, 'days_worked'),
      '出勤日数',
    );
    expect(
      PayslipItemLabel.value(PayslipItemGroup.attendance, 'days_worked', 20),
      '20',
    );
  });
  const observedLabels = {
    PayslipItemGroup.earning: {'travel_expenses': '交通費'},
    PayslipItemGroup.attendance: {
      'overtime_hours_legal': '残業時間（法定内）',
      'late_night_work_hours': '深夜勤務時間',
      'overtime_hours_non_legal': '残業時間（法定外）',
      'actual_working_hours_legal': '実働時間（法定内）',
      'statutory_holiday_work_hours': '法定休日出勤時間',
      'non_statutory_holiday_work_hours': '法定外休日出勤時間',
      'scheduled_working_days_current_month': '所定労働日数（当月）',
    },
  };
  for (final group in observedLabels.entries) {
    for (final entry in group.value.entries) {
      test('labels observed payroll alias ${entry.key}', () {
        expect(PayslipItemLabel.label(group.key, entry.key), entry.value);
        expect(PayslipItemLabel.value(group.key, entry.key, 0), '0');
        expect(PayslipItemLabel.value(group.key, entry.key, -1.5), '-1.5');
        expect(PayslipItemLabel.value(group.key, entry.key, '19?'), '19?');
        expect(PayslipItemLabel.value(group.key, entry.key, null), '未取得');
      });
    }
  }
  test('observed aliases remain scoped to their item group', () {
    expect(
      PayslipItemLabel.label(PayslipItemGroup.attendance, 'travel_expenses'),
      'その他（travel_expenses）',
    );
    expect(
      PayslipItemLabel.label(PayslipItemGroup.earning, 'overtime_hours_legal'),
      'その他（overtime_hours_legal）',
    );
  });
}
