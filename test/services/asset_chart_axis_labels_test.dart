import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_chart_axis_labels.dart';

void main() {
  test('empty or missing observations show no date labels', () {
    expect(assetChartDateLabelIndices(0), isEmpty);
    expect(assetChartDateLabelIndices(-1), isEmpty);
  });
  test('short histories keep every recorded date', () {
    expect(assetChartDateLabelIndices(1), <int>{0});
    expect(assetChartDateLabelIndices(2), <int>{0, 1});
    expect(assetChartDateLabelIndices(5), <int>{0, 1, 2, 3, 4});
  });
  test('dense histories show five labels including first and last', () {
    expect(assetChartDateLabelIndices(63), <int>{0, 16, 31, 47, 62});
    for (var count = 6; count <= 100; count++) {
      final labels = assetChartDateLabelIndices(count).toList()..sort();
      expect(labels.length, 5);
      expect(labels.first, 0);
      expect(labels.last, count - 1);
      expect(labels.every((index) => index >= 0 && index < count), isTrue);
    }
  });
}
