import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/asset_trend_tooltip_builder.dart';

void main() {
  const List<String> assetTypes = <String>['銀行', '証券', '現金'];
  const List<Color> colors = <Color>[
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
  ];
  final LineChartBarData bar0 = LineChartBarData(
    spots: const <FlSpot>[FlSpot(0, 1000), FlSpot(1, 1500)],
  );
  final LineChartBarData bar1 = LineChartBarData(
    spots: const <FlSpot>[FlSpot(0, 2000), FlSpot(1, 2500)],
  );

  test('returns empty list when spots is empty', () {
    final List<LineTooltipItem?> items = buildAssetTrendTooltipItems(
      spots: const <LineBarSpot>[],
      sortedDates: const <String>['2026-11-26'],
      effectiveAssetDataByDate: const <String, Map<String, double>>{},
      assetData: const <String, Map<String, double>>{},
      assetTypes: assetTypes,
      colors: colors,
      isStacked: true,
    );
    expect(items, isEmpty);
  });

  test('returns null-filled list matching spots length when index out of range', () {
    final List<LineBarSpot> outsideSpots = <LineBarSpot>[
      LineBarSpot(bar0, 0, const FlSpot(99, 1000)),
      LineBarSpot(bar1, 1, const FlSpot(99, 2000)),
    ];
    final List<LineTooltipItem?> items = buildAssetTrendTooltipItems(
      spots: outsideSpots,
      sortedDates: const <String>['2026-11-26'],
      effectiveAssetDataByDate: const <String, Map<String, double>>{},
      assetData: const <String, Map<String, double>>{},
      assetTypes: assetTypes,
      colors: colors,
      isStacked: true,
    );
    expect(items, <LineTooltipItem?>[null, null]);
  });

  test('matches spots length in stacked mode across 1, 2, and 5 touched spots', () {
    final Map<String, Map<String, double>> effectiveData = <String, Map<String, double>>{
      '2026-11-26': <String, double>{
        '現金': 50000,
        '銀行': 150000,
        '証券': 300000,
      },
    };
    for (final int count in <int>[1, 2, 5]) {
      final List<LineBarSpot> spots = List<LineBarSpot>.generate(
        count,
        (final int index) => LineBarSpot(bar0, index, const FlSpot(0, 1000)),
      );
      final List<LineTooltipItem?> items = buildAssetTrendTooltipItems(
        spots: spots,
        sortedDates: const <String>['2026-11-26'],
        effectiveAssetDataByDate: effectiveData,
        assetData: const <String, Map<String, double>>{},
        assetTypes: assetTypes,
        colors: colors,
        isStacked: true,
      );
      expect(items, hasLength(count));
      expect(items.first, isNotNull);
      for (var i = 1; i < count; i++) {
        expect(items[i], isNull);
      }
      final String rendered =
          '${items.first!.text}${items.first!.children?.map((final c) => c.text).join() ?? ''}';
      expect(rendered, contains('2026/11/26'));
      expect(rendered, contains('総資産: ¥500,000'));
      expect(rendered.indexOf('証券'), lessThan(rendered.indexOf('銀行')));
      expect(rendered.indexOf('銀行'), lessThan(rendered.indexOf('現金')));
    }
  });

  test('omits total line in unstacked mode while keeping length invariant', () {
    final List<LineBarSpot> spots = <LineBarSpot>[
      LineBarSpot(bar0, 0, const FlSpot(1, 1500)),
      LineBarSpot(bar1, 1, const FlSpot(1, 2500)),
    ];
    final List<LineTooltipItem?> items = buildAssetTrendTooltipItems(
      spots: spots,
      sortedDates: const <String>['2026-11-25', '2026-11-26'],
      effectiveAssetDataByDate: const <String, Map<String, double>>{},
      assetData: const <String, Map<String, double>>{
        '2026-11-26': <String, double>{'銀行': 120000},
      },
      assetTypes: assetTypes,
      colors: colors,
      isStacked: false,
    );
    expect(items, <Matcher>[isNotNull, isNull]);
    final String rendered =
        '${items.first!.text}${items.first!.children?.map((final c) => c.text).join() ?? ''}';
    expect(rendered, isNot(contains('総資産:')));
    expect(rendered, contains('銀行: ¥120,000'));
  });

  test('handles unknown asset type, invalid date, and empty color list safely', () {
    final List<LineBarSpot> spots = <LineBarSpot>[
      LineBarSpot(bar0, 0, const FlSpot(0, 1000)),
    ];
    final List<LineTooltipItem?> items = buildAssetTrendTooltipItems(
      spots: spots,
      sortedDates: const <String>['invalid-date'],
      effectiveAssetDataByDate: const <String, Map<String, double>>{
        'invalid-date': <String, double>{'暗号資産': 42000},
      },
      assetData: const <String, Map<String, double>>{},
      assetTypes: assetTypes,
      colors: const <Color>[],
      isStacked: true,
    );
    expect(items, hasLength(1));
    expect(items.first, isNotNull);
    final String rendered =
        '${items.first!.text}${items.first!.children?.map((final c) => c.text).join() ?? ''}';
    expect(rendered, contains('invalid-date'));
    expect(rendered, contains('暗号資産: ¥42,000'));
  });

  testWidgets('LineChart paints multi-series tooltip without size mismatch exception', (
    final WidgetTester tester,
  ) async {
    final List<String> dates = <String>['2026-11-25', '2026-11-26'];
    final Map<String, Map<String, double>> data = <String, Map<String, double>>{
      '2026-11-25': <String, double>{'銀行': 1000, '証券': 2000, '現金': 3000},
      '2026-11-26': <String, double>{'銀行': 1500, '証券': 2500, '現金': 3500},
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 260,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (final List<LineBarSpot> spots) {
                      return buildAssetTrendTooltipItems(
                        spots: spots,
                        sortedDates: dates,
                        effectiveAssetDataByDate: data,
                        assetData: data,
                        assetTypes: assetTypes,
                        colors: colors,
                        isStacked: true,
                      );
                    },
                  ),
                ),
                lineBarsData: <LineChartBarData>[bar0, bar1],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Offset center = tester.getCenter(find.byType(LineChart));
    final TestGesture gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
