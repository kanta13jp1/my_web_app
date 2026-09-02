import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/conveni_daily_report_payload.dart';

void main() {
  test('daily report payload matches the conveni_daily_reports schema', () {
    final payload = buildConveniDailyReportPayload(
      storeId: 'store-1',
      gameDay: 3,
      revenue: 15000,
      costOfGoods: 9000,
      profit: 6000,
      customerCount: 25,
    );

    expect(payload, <String, Object>{
      'store_id': 'store-1',
      'game_day': 3,
      'revenue': 15000,
      'cost_of_goods': 9000,
      'staff_cost': 0,
      'waste_loss': 0,
      'profit': 6000,
      'customer_count': 25,
      'weather': 'sunny',
    });
    expect(payload, isNot(contains('expense')));
  });
}
