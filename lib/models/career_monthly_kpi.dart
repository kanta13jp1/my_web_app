class CareerMonthlyKpi {
  final String? id;
  final String monthKey;
  final String annualGoal;
  final String category;
  final String metricName;
  final double targetValue;
  final double actualValue;
  final String unit;
  final String reflection;
  final String nextAction;
  final DateTime? createdAt;

  const CareerMonthlyKpi({
    this.id,
    required this.monthKey,
    required this.annualGoal,
    required this.category,
    required this.metricName,
    required this.targetValue,
    required this.actualValue,
    this.unit = '',
    this.reflection = '',
    this.nextAction = '',
    this.createdAt,
  });

  factory CareerMonthlyKpi.fromHubItem(Map<String, dynamic> item) {
    final metadata = item['metadata'] is Map
        ? Map<String, dynamic>.from(item['metadata'] as Map)
        : <String, dynamic>{};
    return CareerMonthlyKpi(
      id: item['id']?.toString(),
      monthKey: _readString(
        metadata['month_key'],
        defaultValue: currentMonthKey(),
      ),
      annualGoal: _readString(metadata['annual_goal']),
      category: _readString(metadata['category'], defaultValue: 'career'),
      metricName: _readString(metadata['metric_name']),
      targetValue: _readDouble(metadata['target_value']),
      actualValue: _readDouble(metadata['actual_value']),
      unit: _readString(metadata['unit']),
      reflection: _readString(metadata['reflection']),
      nextAction: _readString(metadata['next_action']),
      createdAt: DateTime.tryParse(item['created_at']?.toString() ?? ''),
    );
  }

  double get achievementRate {
    if (targetValue <= 0) {
      return 0;
    }
    return actualValue / targetValue;
  }

  double get cappedProgress => achievementRate.clamp(0, 1).toDouble();

  String get achievementPercentLabel => '${(achievementRate * 100).round()}%';

  Map<String, dynamic> toPayload() {
    return {
      'month_key': monthKey,
      'annual_goal': annualGoal,
      'category': category,
      'metric_name': metricName,
      'target_value': targetValue,
      'actual_value': actualValue,
      'unit': unit,
      'reflection': reflection,
      'next_action': nextAction,
    };
  }

  CareerMonthlyKpi copyWith({
    String? id,
    String? monthKey,
    String? annualGoal,
    String? category,
    String? metricName,
    double? targetValue,
    double? actualValue,
    String? unit,
    String? reflection,
    String? nextAction,
    DateTime? createdAt,
  }) {
    return CareerMonthlyKpi(
      id: id ?? this.id,
      monthKey: monthKey ?? this.monthKey,
      annualGoal: annualGoal ?? this.annualGoal,
      category: category ?? this.category,
      metricName: metricName ?? this.metricName,
      targetValue: targetValue ?? this.targetValue,
      actualValue: actualValue ?? this.actualValue,
      unit: unit ?? this.unit,
      reflection: reflection ?? this.reflection,
      nextAction: nextAction ?? this.nextAction,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String currentMonthKey({DateTime? now}) {
    final date = now ?? DateTime.now();
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  static String _readString(Object? value, {String defaultValue = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? defaultValue : text;
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
