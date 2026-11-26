import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Builds `fl_chart` line tooltips whose length always matches `spots.length`.
///
/// `fl_chart` asserts `tooltipItems.length == touchedSpots.length`, so multi-line
/// asset breakdowns must live inside the first item's [TextSpan] children while
/// remaining touched spots map to `null`.
List<LineTooltipItem?> buildAssetTrendTooltipItems({
  required final List<LineBarSpot> spots,
  required final List<String> sortedDates,
  required final Map<String, Map<String, double>> effectiveAssetDataByDate,
  required final Map<String, Map<String, double>> assetData,
  required final List<String> assetTypes,
  required final List<Color> colors,
  required final bool isStacked,
}) {
  if (spots.isEmpty) {
    return const <LineTooltipItem?>[];
  }
  final int dateIndex = spots.first.spotIndex;
  if (dateIndex < 0 || dateIndex >= sortedDates.length) {
    return List<LineTooltipItem?>.filled(spots.length, null);
  }

  final String date = sortedDates[dateIndex];
  final Map<String, double> assetsOnDate =
      effectiveAssetDataByDate[date] ?? assetData[date] ?? const <String, double>{};
  double total = 0;
  assetsOnDate.forEach((final _, final double value) => total += value);

  final DateTime? parsedDate = DateTime.tryParse(date);
  final String formattedDate =
      parsedDate == null ? date : DateFormat('yyyy/MM/dd').format(parsedDate);
  final NumberFormat currencyFormat = NumberFormat.simpleCurrency(
    locale: 'ja_JP',
  );
  final String formattedTotal = currencyFormat.format(total);

  final List<MapEntry<String, double>> sortedAssets = assetsOnDate.entries
      .toList()
    ..sort((final a, final b) => b.value.compareTo(a.value));

  final List<TextSpan> children = <TextSpan>[];
  if (isStacked) {
    children.add(
      TextSpan(
        text: '総資産: $formattedTotal${sortedAssets.isEmpty ? '' : '\n'}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
  for (var i = 0; i < sortedAssets.length; i++) {
    final MapEntry<String, double> entry = sortedAssets[i];
    final int typeIndex = assetTypes.indexOf(entry.key);
    final Color color = colors.isEmpty
        ? Colors.white
        : colors[(typeIndex >= 0 ? typeIndex : 0) % colors.length];
    final String formattedValue = currencyFormat.format(entry.value);
    final String suffix = i + 1 < sortedAssets.length ? '\n' : '';
    children.add(
      TextSpan(
        text: '${entry.key}: $formattedValue$suffix',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
    );
  }

  final LineTooltipItem primaryItem = LineTooltipItem(
    children.isEmpty ? formattedDate : '$formattedDate\n',
    const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      height: 1.5,
    ),
    children: children,
  );
  return List<LineTooltipItem?>.generate(
    spots.length,
    (final int index) => index == 0 ? primaryItem : null,
  );
}
