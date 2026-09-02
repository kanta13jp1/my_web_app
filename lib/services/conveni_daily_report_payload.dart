Map<String, Object> buildConveniDailyReportPayload({
  required String storeId,
  required int gameDay,
  required int revenue,
  required int costOfGoods,
  required int profit,
  required int customerCount,
  String weather = 'sunny',
}) {
  return <String, Object>{
    'store_id': storeId,
    'game_day': gameDay,
    'revenue': revenue,
    'cost_of_goods': costOfGoods,
    'staff_cost': 0,
    'waste_loss': 0,
    'profit': profit,
    'customer_count': customerCount,
    'weather': weather,
  };
}
