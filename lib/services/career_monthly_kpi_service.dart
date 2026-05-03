import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/career_monthly_kpi.dart';

class CareerMonthlyKpiSummary {
  final String monthKey;
  final int totalMetrics;
  final int completedMetrics;
  final double averageProgress;
  final String primaryGoal;

  const CareerMonthlyKpiSummary({
    required this.monthKey,
    required this.totalMetrics,
    required this.completedMetrics,
    required this.averageProgress,
    required this.primaryGoal,
  });
}

class CareerMonthlyKpiService {
  final SupabaseClient _client;

  CareerMonthlyKpiService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<CareerMonthlyKpi>> list() async {
    final response = await _client.functions.invoke(
      'tools-hub',
      body: {'action': 'career_kpi.list'},
    );
    final data = response.data;
    final items = data is Map && data['items'] is List
        ? data['items'] as List
        : const <Object?>[];
    final kpis = items
        .whereType<Map>()
        .map(
          (item) => CareerMonthlyKpi.fromHubItem(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
    kpis.sort((a, b) => b.monthKey.compareTo(a.monthKey));
    return kpis;
  }

  Future<CareerMonthlyKpi?> add(CareerMonthlyKpi kpi) async {
    final response = await _client.functions.invoke(
      'tools-hub',
      body: {'action': 'career_kpi.add', ...kpi.toPayload()},
    );
    final data = response.data;
    if (data is Map && data['item'] is Map) {
      return CareerMonthlyKpi.fromHubItem(
        Map<String, dynamic>.from(data['item'] as Map),
      );
    }
    return null;
  }

  Future<void> update(CareerMonthlyKpi kpi) async {
    final id = kpi.id;
    if (id == null || id.isEmpty) {
      throw ArgumentError('A KPI id is required to update an existing record.');
    }
    await _client.functions.invoke(
      'tools-hub',
      body: {'action': 'career_kpi.update', 'id': id, ...kpi.toPayload()},
    );
  }

  Future<void> delete(String id) async {
    await _client.functions.invoke(
      'tools-hub',
      body: {'action': 'career_kpi.delete', 'id': id},
    );
  }

  static CareerMonthlyKpiSummary summarize(
    List<CareerMonthlyKpi> items,
    String monthKey,
  ) {
    final monthlyItems =
        items.where((item) => item.monthKey == monthKey).toList();
    if (monthlyItems.isEmpty) {
      return CareerMonthlyKpiSummary(
        monthKey: monthKey,
        totalMetrics: 0,
        completedMetrics: 0,
        averageProgress: 0,
        primaryGoal: '',
      );
    }
    final completed = monthlyItems
        .where(
          (item) =>
              item.targetValue > 0 && item.actualValue >= item.targetValue,
        )
        .length;
    final progress =
        monthlyItems
            .map((item) => item.cappedProgress)
            .fold<double>(0, (sum, value) => sum + value) /
        monthlyItems.length;
    final goal = monthlyItems
        .map((item) => item.annualGoal)
        .firstWhere((goal) => goal.trim().isNotEmpty, orElse: () => '');

    return CareerMonthlyKpiSummary(
      monthKey: monthKey,
      totalMetrics: monthlyItems.length,
      completedMetrics: completed,
      averageProgress: progress,
      primaryGoal: goal,
    );
  }

  static String buildMonthlyReport(
    List<CareerMonthlyKpi> items,
    String monthKey,
  ) {
    final monthlyItems =
        items.where((item) => item.monthKey == monthKey).toList();
    final summary = summarize(items, monthKey);
    final buffer = StringBuffer()
      ..writeln('# Career Monthly Close: $monthKey')
      ..writeln()
      ..writeln(
        '- Annual goal: ${summary.primaryGoal.isEmpty ? 'TBD' : summary.primaryGoal}',
      )
      ..writeln(
        '- Metrics: ${summary.completedMetrics}/${summary.totalMetrics} complete',
      )
      ..writeln(
        '- Average progress: ${(summary.averageProgress * 100).round()}%',
      )
      ..writeln();

    if (monthlyItems.isEmpty) {
      buffer
        ..writeln('## KPI Review')
        ..writeln('- No monthly KPI records yet.')
        ..writeln()
        ..writeln('## Next Month Focus')
        ..writeln(
          '- Define one measurable career KPI before the first weekly review.',
        );
      return buffer.toString().trim();
    }

    buffer.writeln('## KPI Review');
    for (final item in monthlyItems) {
      final unit = item.unit.isEmpty ? '' : item.unit;
      buffer
        ..writeln(
          '- ${item.metricName}: ${_formatNumber(item.actualValue)}$unit / '
          '${_formatNumber(item.targetValue)}$unit (${item.achievementPercentLabel})',
        )
        ..writeln(
          '  - Reflection: ${item.reflection.isEmpty ? 'TBD' : item.reflection}',
        )
        ..writeln(
          '  - Next action: ${item.nextAction.isEmpty ? 'TBD' : item.nextAction}',
        );
    }
    return buffer.toString().trim();
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}
