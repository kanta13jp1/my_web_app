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
    'travel_expenses': '交通費',
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
    'base_salary_monthly': '月額基本給',
    'overtime_allowance_non_statutory': '残業手当（法定外）',
    'over_40h_week_allowance_scheduled_hours': '週40時間超の手当（所定労働時間）',
    '食事手当': '食事手当',
    '案件手当1': '案件手当1',
    '案件手当2': '案件手当2',
    '月60H超手当': '月60H超手当',
    '基本給(月給)': '基本給(月給)',
    '固定残業手当': '固定残業手当',
    '深夜勤務手当': '深夜勤務手当',
    '通勤手当(課税)': '通勤手当(課税)',
    '通勤手当(非課税)': '通勤手当(非課税)',
    '法定休日出勤手当': '法定休日出勤手当',
    '時間外手当(法定外)': '時間外手当(法定外)',
    '法定外休日出勤手当': '法定外休日出勤手当',
    '週40H超手当(所定労働時間)': '週40H超手当(所定労働時間)',
  };
  static const attendance = {
    'work_days': '勤務日数',
    'overtime_hours': '時間外時間',
    'days_worked': '出勤日数',
    'overtime_hours_legal': '残業時間（法定内）',
    'late_night_work_hours': '深夜勤務時間',
    'overtime_hours_non_legal': '残業時間（法定外）',
    'actual_working_hours_legal': '実働時間（法定内）',
    'statutory_holiday_work_hours': '法定休日出勤時間',
    'non_statutory_holiday_work_hours': '法定外休日出勤時間',
    'scheduled_working_days_current_month': '所定労働日数（当月）',
    'paid_leave_taken': '有給休暇取得日数',
    'overtime_hours_statutory': '残業時間（法定内）',
    'overtime_hours_non_statutory': '残業時間（法定外）',
    'actual_working_hours_statutory': '実働時間（法定内）',
    '出勤日数': '出勤日数',
    '深夜勤務時間': '深夜勤務時間',
    '実働時間(法定内)': '実働時間(法定内)',
    '残業時間(法定内)': '残業時間(法定内)',
    '残業時間(法定外)': '残業時間(法定外)',
    '法定休日出勤時間': '法定休日出勤時間',
    '所定労働日数(当月)': '所定労働日数(当月)',
    '法定外休日出勤時間': '法定外休日出勤時間',
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
