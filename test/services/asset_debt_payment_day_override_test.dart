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
  test('only a valid independent name fallback blocks clearing', () {
    bool legacy(
      Map<String, int> values, {
      String id = 'id',
      String name = ' Name ',
    }) =>
        hasAssetDebtLegacyNameOverride(
          overrides: values,
          accountId: id,
          accountName: name,
        );
    expect(legacy({'id': 4}), isFalse);
    expect(legacy({'id': 4, 'Name': 5}), isTrue);
    expect(legacy({' Name ': 6}), isTrue);
    expect(legacy({'Name': 99, ' Name ': 6}), isFalse);
    expect(legacy({'Name': 5}, id: 'Name', name: 'Name'), isFalse);
    expect(legacy({'Name': 5, ' Name ': 6}, id: 'Name'), isTrue);
    expect(legacy({'Name': 0}), isFalse);
  });
}
