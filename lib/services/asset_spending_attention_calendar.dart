/// Calendar context only: these labels never create spending/activity records.
class AssetSpendingAttentionDay {
  const AssetSpendingAttentionDay({
    required this.reasons,
    required this.holiday,
    required this.holidayDataAvailable,
  });
  final List<String> reasons;
  final String? holiday;
  final bool holidayDataAvailable;
  bool get isAttentionDay => reasons.isNotEmpty;
  String get description {
    final label = reasons.isNotEmpty
        ? '浪費危険日: ${reasons.join('・')}'
        : '注意日の条件に該当しません（支出の有無とは別です）';
    return holidayDataAvailable ? label : '$label / 祝日は未確認（未対応年）';
  }
}

class AssetSpendingAttentionCalendar {
  const AssetSpendingAttentionCalendar._();
  static const sourceUrl =
      'https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv';
  static const sourceRetrievedOn = '2026-10-15';
  static const supportedYears = {2026, 2027};
  // Cabinet Office official CSV; includes substitute/citizens holidays.
  static const Map<String, String> holidays = {
    '2026-01-01': '元日',
    '2026-01-12': '成人の日',
    '2026-02-11': '建国記念の日',
    '2026-02-23': '天皇誕生日',
    '2026-03-20': '春分の日',
    '2026-04-29': '昭和の日',
    '2026-05-03': '憲法記念日',
    '2026-05-04': 'みどりの日',
    '2026-05-05': 'こどもの日',
    '2026-05-06': '休日',
    '2026-07-20': '海の日',
    '2026-08-11': '山の日',
    '2026-09-21': '敬老の日',
    '2026-09-22': '休日',
    '2026-09-23': '秋分の日',
    '2026-10-12': 'スポーツの日',
    '2026-11-03': '文化の日',
    '2026-11-23': '勤労感謝の日',
    '2027-01-01': '元日',
    '2027-01-11': '成人の日',
    '2027-02-11': '建国記念の日',
    '2027-02-23': '天皇誕生日',
    '2027-03-21': '春分の日',
    '2027-03-22': '休日',
    '2027-04-29': '昭和の日',
    '2027-05-03': '憲法記念日',
    '2027-05-04': 'みどりの日',
    '2027-05-05': 'こどもの日',
    '2027-07-19': '海の日',
    '2027-08-11': '山の日',
    '2027-09-20': '敬老の日',
    '2027-09-23': '秋分の日',
    '2027-10-11': 'スポーツの日',
    '2027-11-03': '文化の日',
    '2027-11-23': '勤労感謝の日',
  };
  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static bool _weekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  static AssetSpendingAttentionDay forDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final next = DateTime(day.year, day.month, day.day + 1);
    final holiday = holidays[_key(day)];
    final reasons = <String>[
      if (day.weekday == DateTime.friday) '金曜日',
      if (day.weekday == DateTime.saturday) '土曜日',
      if (day.weekday == DateTime.sunday) '日曜日',
      if (holiday != null) '祝日・休日（$holiday）',
      if (_weekend(next) || holidays.containsKey(_key(next))) '休前日（翌日が土日・公式祝日）',
    ];
    return AssetSpendingAttentionDay(
      reasons: List.unmodifiable(reasons),
      holiday: holiday,
      holidayDataAvailable: supportedYears.contains(day.year),
    );
  }

  static int countDays(Iterable<DateTime> dates) => dates
      .where((date) => forDate(date).isAttentionDay)
      .map(_key)
      .toSet()
      .length;
}
