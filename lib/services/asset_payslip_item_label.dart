enum PayslipItemGroup { deduction, earning, attendance }

/// Display metadata only. Unknown keys and original values remain visible.
class PayslipItemLabel {
  static const earnings = {
    'base_salary': '基本給',
    'fixed_overtime': '固定残業手当',
    'overtime': '残業手当',
    'allowance': '手当',
    'commuting': '通勤手当',
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
  static const attendance = {
    'work_days': '勤務日数',
    'overtime_hours': '時間外時間',
    'days_worked': '出勤日数',
  };
  static String label(PayslipItemGroup group, String key) {
    final known = switch (group) {
      PayslipItemGroup.earning => earnings[key],
      PayslipItemGroup.attendance => attendance[key],
      PayslipItemGroup.deduction => null,
    };
    return known ?? 'その他（$key）';
  }

  static String value(PayslipItemGroup group, String key, Object? raw) {
    if (raw == null) return '未取得';
    final unit = group == PayslipItemGroup.attendance && raw is num
        ? switch (key) {
            'work_days' => '日',
            'overtime_hours' => '時間',
            _ => '',
          }
        : '';
    return '$raw$unit';
  }
}
