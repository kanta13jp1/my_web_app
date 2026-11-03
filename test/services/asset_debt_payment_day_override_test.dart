import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_debt_payment_day_override.dart';

void main() {
  int? resolve(Map<String, int> values) => resolveAssetDebtPaymentDayOverride(
    overrides: values,
    accountId: 'synthetic-id',
    accountName: ' synthetic-name ',
  );

  test('matches id, then trimmed name, then exact name', () {
    expect(resolve({'synthetic-id': 4, 'synthetic-name': 5}), 4);
    expect(resolve({'synthetic-name': 5, ' synthetic-name ': 6}), 5);
    expect(resolve({' synthetic-name ': 6}), 6);
    expect(resolve({}), isNull);
  });

  test('out-of-range chosen value is not replaced by a lower-priority key', () {
    expect(resolve({'synthetic-id': 32, 'synthetic-name': 5}), isNull);
    expect(resolve({'synthetic-name': 0}), isNull);
    expect(resolve({'synthetic-id': 31}), 31);
  });
}
