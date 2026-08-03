import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';

void main() {
  group('AssetRecurringFixedCost currency (USD)', () {
    test('JPY (default) omits currency/usdAmount from json (back-compat)', () {
      const cost = AssetRecurringFixedCost(
        id: 'fc_1',
        name: '電気代',
        amount: 8000,
        paymentDay: 27,
      );
      final json = cost.toJson();
      expect(json.containsKey('currency'), isFalse);
      expect(json.containsKey('usdAmount'), isFalse);
      expect(cost.isUsd, isFalse);
    });

    test('legacy json without currency parses as JPY', () {
      final cost = AssetRecurringFixedCost.fromJson('fc_1', <String, dynamic>{
        'name': 'Notion',
        'amount': 1200,
        'paymentDay': 1,
      });
      expect(cost, isNotNull);
      expect(cost!.currency, AssetRecurringFixedCostCurrency.jpy);
      expect(cost.usdAmount, isNull);
    });

    test('USD cost round-trips currency + usdAmount', () {
      const cost = AssetRecurringFixedCost(
        id: 'fc_claude',
        name: 'Anthropic (Claude)',
        amount: 3200, // materialized JPY (20 USD * 160)
        paymentDay: 5,
        category: AssetRecurringFixedCostCategory.subscription,
        currency: AssetRecurringFixedCostCurrency.usd,
        usdAmount: 20,
      );
      final decoded =
          AssetRecurringFixedCost.fromJson('fc_claude', cost.toJson());
      expect(decoded, isNotNull);
      expect(decoded!.currency, AssetRecurringFixedCostCurrency.usd);
      expect(decoded.usdAmount, 20);
      expect(decoded.amount, 3200);
      expect(decoded.isUsd, isTrue);
    });

    test('resolveJpyAmount converts USD by rate, rounds to yen', () {
      const cost = AssetRecurringFixedCost(
        id: 'fc_claude',
        name: 'Claude',
        amount: 3000,
        paymentDay: 5,
        currency: AssetRecurringFixedCostCurrency.usd,
        usdAmount: 20,
      );
      // 20 USD * 162.39 = 3247.8 -> 3248
      expect(cost.resolveJpyAmount(162.39), 3248);
    });

    test('resolveJpyAmount keeps existing JPY when rate is missing', () {
      const cost = AssetRecurringFixedCost(
        id: 'fc_claude',
        name: 'Claude',
        amount: 3100, // last computed JPY
        paymentDay: 5,
        currency: AssetRecurringFixedCostCurrency.usd,
        usdAmount: 20,
      );
      expect(cost.resolveJpyAmount(null), 3100);
      expect(cost.resolveJpyAmount(0), 3100);
    });

    test('resolveJpyAmount is a no-op for JPY costs', () {
      const cost = AssetRecurringFixedCost(
        id: 'fc_rent',
        name: '家賃',
        amount: 63000,
        paymentDay: 25,
      );
      expect(cost.resolveJpyAmount(162.39), 63000);
    });

    test('usdAmount<=0 or invalid is dropped on parse', () {
      final cost = AssetRecurringFixedCost.fromJson('fc_1', <String, dynamic>{
        'name': 'x',
        'amount': 100,
        'paymentDay': 1,
        'currency': 'usd',
        'usdAmount': 0,
      });
      expect(cost, isNotNull);
      expect(cost!.usdAmount, isNull);
    });
  });
}
