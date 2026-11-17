import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_flow_amount_parser.dart';

void main() {
  test('accepts half-width, full-width and mixed yen digits', () {
    for (final value in ['1086', '１０８６', '１08６', '1,086', '１，０８６', '　１０８６　']) {
      expect(AssetFlowAmountParser.parse(value), 1086);
    }
  });
  test('rejects malformed and non-integer amounts', () {
    for (final value in ['', '1,08', '1.086', '-1086', '1086円', 'abc']) {
      expect(AssetFlowAmountParser.parse(value), isNull);
    }
  });
}
