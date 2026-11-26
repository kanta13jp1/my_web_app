import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_chart_tooltip.dart';

void main() {
  LineChartBarData barWithSpots(List<FlSpot> spots) {
    return LineChartBarData(spots: spots);
  }

  test('returns empty list when touched spots are empty', () {
    final items = buildAssetTrendTooltipItems(
      spots: const [],
      sortedDates: const ['2026-11-23'],
      effectiveAssetDataByDate: const {},
      assetData: const {},
      assetTypes: const ['銀行'],
      colors: const [Colors.blue],
      isStacked: false,
    );
    expect(items, isEmpty);
  });

  test('returns null placeholders matching spot count when index is invalid',
      () {
    final bar = barWithSpots(const [FlSpot(0, 100), FlSpot(1, 200)]);
    final spots = [
      LineBarSpot(bar, 0, const FlSpot(0, 100)),
      LineBarSpot(bar, 1, const FlSpot(1, 200)),
    ];

    final afterEnd = buildAssetTrendTooltipItems(
      spots: spots,
      sortedDates: const [],
      effectiveAssetDataByDate: const {},
      assetData: const {},
      assetTypes: const ['銀行'],
      colors: const [Colors.blue],
      isStacked: true,
    );
    expect(afterEnd, hasLength(2));
    expect(afterEnd, everyElement(isNull));

    final negativeBar = barWithSpots(const [FlSpot(0, 100)]);
    final negItems = buildAssetTrendTooltipItems(
      spots: [
        LineBarSpot(negativeBar, 0, const FlSpot(0, 100)),
      ],
      sortedDates: const [],
      effectiveAssetDataByDate: const {},
      assetData: const {},
      assetTypes: const [],
      colors: const [],
      isStacked: false,
    );
    expect(negItems, hasLength(1));
    expect(negItems.single, isNull);
  });

  test('matches spots length and renders stacked total and sorted breakdown',
      () {
    final bar0 = barWithSpots(const [FlSpot(0, 1000)]);
    final bar1 = barWithSpots(const [FlSpot(0, 3000)]);
    final spots = [
      LineBarSpot(bar0, 0, const FlSpot(0, 1000)),
      LineBarSpot(bar1, 1, const FlSpot(0, 3000)),
    ];

    final stackedItems = buildAssetTrendTooltipItems(
      spots: spots,
      sortedDates: const ['2026-11-23'],
      effectiveAssetDataByDate: const {
        '2026-11-23': {'現金': 500, '銀行': 2000, '証券': 1500},
      },
      assetData: const {},
      assetTypes: const ['銀行', '証券', '現金'],
      colors: const [Colors.blue, Colors.green, Colors.orange],
      isStacked: true,
    );

    expect(stackedItems, hasLength(2));
    expect(stackedItems.first, isNotNull);
    expect(stackedItems[1], isNull);
    expect(stackedItems.first!.text, '2026/11/23');
    final children = stackedItems.first!.children!;
    expect(children, hasLength(4));
    expect(children[0].text, contains('総資産:'));
    expect(children[0].text, contains('4,000'));
    expect(children[1].text, contains('銀行:'));
    expect(children[1].style?.color, Colors.blue);
    expect(children[2].text, contains('証券:'));
    expect(children[2].style?.color, Colors.green);
    expect(children[3].text, contains('現金:'));
    expect(children[3].style?.color, Colors.orange);

    final unstackedSingle = buildAssetTrendTooltipItems(
      spots: [LineBarSpot(bar0, 0, const FlSpot(0, 1000))],
      sortedDates: const ['2026-11-23'],
      effectiveAssetDataByDate: const {
        '2026-11-23': {'現金': 500, '銀行': 2000, '証券': 1500},
      },
      assetData: const {},
      assetTypes: const ['銀行', '証券', '現金'],
      colors: const [Colors.blue, Colors.green, Colors.orange],
      isStacked: false,
    );

    expect(unstackedSingle, hasLength(1));
    expect(unstackedSingle.first, isNotNull);
    expect(unstackedSingle.first!.children, hasLength(3));
    expect(
      unstackedSingle.first!.children!.any(
        (span) => (span.text ?? '').contains('総資産'),
      ),
      isFalse,
    );
  });

  test('handles unknown asset types, empty colors, and non-ISO dates safely',
      () {
    final bar = barWithSpots(const [FlSpot(0, 500)]);
    final items = buildAssetTrendTooltipItems(
      spots: [LineBarSpot(bar, 0, const FlSpot(0, 500))],
      sortedDates: const ['2026/11/23'],
      effectiveAssetDataByDate: const {},
      assetData: const {
        '2026/11/23': {'未知資産': 500},
      },
      assetTypes: const ['銀行'],
      colors: const [],
      isStacked: false,
    );

    expect(items, hasLength(1));
    expect(items.first?.text, '2026/11/23');
    expect(items.first?.children?.single.text, contains('未知資産'));
    expect(items.first?.children?.single.style?.color, Colors.white);
  });

  testWidgets('LineChart paints tooltip indicators without length exception', (
    tester,
  ) async {
    final bar0 = barWithSpots(const [FlSpot(0, 1000), FlSpot(1, 1500)]);
    final bar1 = barWithSpots(const [FlSpot(0, 2000), FlSpot(1, 3000)]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 240,
            child: LineChart(
              LineChartData(
                showingTooltipIndicators: [
                  ShowingTooltipIndicators([
                    LineBarSpot(bar0, 0, bar0.spots.first),
                    LineBarSpot(bar1, 1, bar1.spots.first),
                  ]),
                ],
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: false,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => buildAssetTrendTooltipItems(
                      spots: spots,
                      sortedDates: const ['2026-11-23', '2026-11-24'],
                      effectiveAssetDataByDate: const {
                        '2026-11-23': {
                          '銀行': 1000,
                          '証券': 1500,
                          '現金': 500,
                        },
                      },
                      assetData: const {},
                      assetTypes: const ['銀行', '証券', '現金'],
                      colors: const [Colors.blue, Colors.green, Colors.orange],
                      isStacked: true,
                    ),
                  ),
                ),
                lineBarsData: [bar0, bar1],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(LineChart), findsOneWidget);
  });
}
