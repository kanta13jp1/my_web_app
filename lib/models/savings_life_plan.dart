class SavingsLifePlan {
  const SavingsLifePlan({
    required this.start,
    required this.targetDate,
    this.target = 1000000,
    this.savings,
    this.income,
    this.livingCosts,
    this.reserve = 0,
  });

  final DateTime start;
  final DateTime targetDate;
  final int target;
  final int? savings;
  final int? income;
  final int? livingCosts;
  final int reserve;

  Map<String, Object?> toJson() => {
        'version': 1,
        'start': dateText(start),
        'targetDate': dateText(targetDate),
        'target': target,
        'savings': savings,
        'income': income,
        'livingCosts': livingCosts,
        'reserve': reserve,
      };

  static SavingsLifePlan fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException('unsupported plan');
    int? amount(String key, {bool optional = false}) {
      final value = json[key];
      if (value == null && optional) return null;
      if (value is! int || value < 0 || value > 100000000) {
        throw FormatException('invalid $key');
      }
      return value;
    }

    final start = DateTime.parse(json['start'] as String);
    final targetDate = DateTime.parse(json['targetDate'] as String);
    if (!targetDate.isAfter(start)) throw const FormatException('invalid dates');
    return SavingsLifePlan(
      start: start,
      targetDate: targetDate,
      target: amount('target')!,
      savings: amount('savings', optional: true),
      income: amount('income', optional: true),
      livingCosts: amount('livingCosts', optional: true),
      reserve: amount('reserve')!,
    );
  }

  static String dateText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class SavingsPlanCheckpoint {
  const SavingsPlanCheckpoint(this.date, this.targetSavings, this.forecastSavings);
  final DateTime date;
  final int targetSavings;
  final int forecastSavings;
}

class SavingsPlanResult {
  const SavingsPlanResult({
    required this.ready,
    required this.expired,
    required this.requiredMonthlySavings,
    required this.monthlyCapacity,
    required this.monthlyShortfall,
    required this.monthlyLivingCeiling,
    required this.dailyLivingBudget,
    required this.checkpoints,
  });

  final bool ready;
  final bool expired;
  final int requiredMonthlySavings;
  final int monthlyCapacity;
  final int monthlyShortfall;
  final int monthlyLivingCeiling;
  /// Null when inputs are missing or the plan cannot fund essential living costs.
  final int? dailyLivingBudget;
  final List<SavingsPlanCheckpoint> checkpoints;
}
