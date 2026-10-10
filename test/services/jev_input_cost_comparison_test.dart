import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/jev_input_cost_comparison.dart';

void main() {
  test('387 and 5762 input tokens reproduce the historical 1000-call estimates', () {
    final result = JevInputCostComparison.calculate(
      beforeTokens: 387,
      afterTokens: 5762,
      requests: 1000,
      usdPerMillionTokens: 0.042,
    );
    expect(result.beforeUsd, closeTo(0.016254, 1e-10));
    expect(result.afterUsd, closeTo(0.242004, 1e-10));
    expect(result.differenceUsd, closeTo(0.22575, 1e-10));
  });
  test('zero input is valid but zero requests and non-finite rates are rejected', () {
    expect(JevInputCostComparison.calculate(
      beforeTokens: 0,
      afterTokens: 0,
      requests: 1,
      usdPerMillionTokens: 0,
    ).beforeUsd, 0);
    for (final rate in [double.nan, double.infinity, -1.0]) {
      expect(() => JevInputCostComparison.calculate(
        beforeTokens: 387,
        afterTokens: 5762,
        requests: 1000,
        usdPerMillionTokens: rate,
      ), throwsArgumentError);
    }
    expect(() => JevInputCostComparison.calculate(
      beforeTokens: 387,
      afterTokens: 5762,
      requests: 0,
      usdPerMillionTokens: 0.042,
    ), throwsArgumentError);
  });
}
