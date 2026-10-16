import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payslip_item_label.dart';

void main() {
  test('parser earning keys have Japanese display labels', () {
    expect(PayslipItemLabel.earnings.keys, containsAll([
      'base_salary',
      'fixed_overtime',
      'overtime',
      'allowance',
      'commuting',
    ]));
    expect(PayslipItemLabel.label(PayslipItemGroup.earning, 'base_salary'), '基本給');
  });
  test('unknown key and raw values survive without guessed units', () {
    expect(PayslipItemLabel.label(PayslipItemGroup.earning, 'future_key'), 'その他（future_key）');
    expect(PayslipItemLabel.value(PayslipItemGroup.attendance, 'future_key', -1.5), '-1.5');
    expect(PayslipItemLabel.value(PayslipItemGroup.earning, 'base_salary', 0), '0');
    expect(PayslipItemLabel.value(PayslipItemGroup.attendance, 'work_days', null), '未取得');
    expect(PayslipItemLabel.value(PayslipItemGroup.attendance, 'work_days', 20), '20日');
    expect(PayslipItemLabel.value(PayslipItemGroup.attendance, 'overtime_hours', 1.5), '1.5時間');
    expect(PayslipItemLabel.value(PayslipItemGroup.attendance, 'work_days', '20?'), '20?');
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
      expect(PayslipItemLabel.label(PayslipItemGroup.earning, entry.key), entry.value);
    }
    expect(PayslipItemLabel.label(PayslipItemGroup.attendance, 'days_worked'), '出勤日数');
    expect(PayslipItemLabel.value(PayslipItemGroup.attendance, 'days_worked', 20), '20');
  });
}
