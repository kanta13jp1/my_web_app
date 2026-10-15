import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_spending_attention_calendar.dart';
void main() {
  test('Friday and weekends include distinct reasons but count unique days', () {
    final friday = DateTime(2026, 10, 16);
    expect(AssetSpendingAttentionCalendar.forDate(friday).reasons,
      containsAll(['金曜日', '休前日（翌日が土日・公式祝日）']));
    expect(AssetSpendingAttentionCalendar.forDate(DateTime(2026, 10, 17)).reasons, contains('土曜日'));
    expect(AssetSpendingAttentionCalendar.countDays([friday, friday, DateTime(2026, 10, 17)]), 2);
  });
  test('official substitute and citizens holidays are included', () {
    expect(AssetSpendingAttentionCalendar.forDate(DateTime(2026, 5, 6)).holiday, '休日');
    expect(AssetSpendingAttentionCalendar.forDate(DateTime(2026, 9, 22)).holiday, '休日');
    final autumn = DateTime(2026, 9, 23);
    expect(autumn.weekday, DateTime.wednesday);
    expect(AssetSpendingAttentionCalendar.forDate(autumn).holiday, '秋分の日');
    expect(AssetSpendingAttentionCalendar.forDate(DateTime(2026, 9, 22)).reasons,
      contains('休前日（翌日が土日・公式祝日）'));
  });
  test('ordinary weekday is not an actual spending assertion', () {
    final day = AssetSpendingAttentionCalendar.forDate(DateTime(2026, 10, 15));
    expect(day.isAttentionDay, isFalse);
    expect(day.description, contains('支出の有無とは別'));
  });
  test('unsupported years never guess holidays but keep known weekday context', () {
    final day = AssetSpendingAttentionCalendar.forDate(DateTime(2028, 1, 3));
    expect(day.holidayDataAvailable, isFalse);
    expect(day.holiday, isNull);
    expect(day.description, contains('未対応年'));
  });
}
