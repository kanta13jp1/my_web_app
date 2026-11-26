import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Builds `fl_chart` tooltip items whose length always matches [spots.length].
///
/// `LineChartPainter` throws `Exception('tooltipItems and touchedSpots size should be same')`
/// whenever the returned list length differs from `touchedSpots.length`.
/// To preserve the multi-line summary (date, optional stacked total, and sorted
/// asset breakdown) regardless of how many spots are touched, render the full
/// summary via `LineTooltipItem.children` on index 0 and `null` for remaining spots.
List<LineTooltipItem?> buildAssetTrendTooltipItems({
  required List<LineBarSpot> spots,
  required List<String> sortedDates,
  required Map<String, Map<String, double>> effectiveAssetDataByDate,
  required Map<String, Map<String, double>> assetData,
  required List<String> assetTypes,
  required List<Color> colors,
  required bool isStacked,
}) {
  if (spots.isEmpty) return const <LineTooltipItem?>[];
  final dateIndex = spots.first.spotIndex;
  if (dateIndex < 0 || dateIndex >= sortedDates.length) {
    return List<LineTooltipItem?>.filled(spots.length, null);
  }
  final date = sortedDates[dateIndex];
  final assetsOnDate = effectiveAssetDataByDate[date] ??
      assetData[date] ??
      const <String, double>{};
  double total = 0;
  assetsOnDate.forEach((_, value) => total += value);
  final parsedDate = DateTime.tryParse(date);
  final formattedDate =
      parsedDate == null ? date : DateFormat('yyyy/MM/dd').format(parsedDate);
  final currencyFormat = NumberFormat.simpleCurrency(locale: 'ja_JP');
  final formattedTotal = currencyFormat.format(total);
  final children = <TextSpan>[
    if (isStacked)
      TextSpan(
        text: '\n総資産: $formattedTotal',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          height: 1.5,
        ),
      ),
  ];
  final sortedAssets = assetsOnDate.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final entry in sortedAssets) {
    final typeIndex = assetTypes.indexOf(entry.key);
    final color = colors.isEmpty
        ? Colors.white
        : colors[(typeIndex >= 0 ? typeIndex : 0) % colors.length];
    children.add(
      TextSpan(
        text: '\n${entry.key}: ${currencyFormat.format(entry.value)}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
    );
  }
  final summaryItem = LineTooltipItem(
    formattedDate,
    const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      height: 1.5,
    ),
    children: children,
  );
  return List<LineTooltipItem?>.generate(
    spots.length,
    (index) => index == 0 ? summaryItem : null,
  );
}
