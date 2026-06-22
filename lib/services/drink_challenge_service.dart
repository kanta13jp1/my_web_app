/// 「飲みに行くのを我慢して借金完済」チャレンジの純関数ロジック。
///
/// 飲み機会 = 金・土・日の夜、祝前日の夜、祝日の夜。各機会に「我慢した/飲んだ」を
/// 記録し、我慢1回あたり「借金 ÷ 目標回数(700)」を節約したものとして可視化する。
library;

/// 飲み機会の理由(複数該当しうる)。
enum DrinkOccasionReason {
  fridayNight,
  saturdayNight,
  sundayNight,
  holidayEve,
  holiday
}

extension DrinkOccasionReasonLabel on DrinkOccasionReason {
  String get label {
    switch (this) {
      case DrinkOccasionReason.fridayNight:
        return '金';
      case DrinkOccasionReason.saturdayNight:
        return '土';
      case DrinkOccasionReason.sundayNight:
        return '日';
      case DrinkOccasionReason.holidayEve:
        return '祝前日';
      case DrinkOccasionReason.holiday:
        return '祝日';
    }
  }
}

/// 1回の記録状態。
enum DrinkRecordStatus { abstained, drank }

/// 飲み機会(特定日)。
class DrinkOccasion {
  final DateTime date;
  final List<DrinkOccasionReason> reasons;

  const DrinkOccasion({required this.date, required this.reasons});

  /// 例: 「土・祝前日」。
  String get reasonLabel => reasons.map((r) => r.label).join('・');
}

/// チャレンジの集計結果。
class DrinkChallengeStats {
  /// 我慢した回数。
  final int abstainedCount;

  /// 飲んでしまった回数。
  final int drankCount;

  /// 目標回数(既定700)。
  final int targetCount;

  /// 1回の我慢あたりの節約額(= 借金 ÷ 目標回数)。
  final double perSessionYen;

  /// 累計節約額(= 我慢回数 × 1回あたり)。
  final double savedYen;

  /// 現在の借金総額(正の値)。
  final double totalDebtYen;

  /// 目標に対する進捗(0.0〜1.0)。
  final double progressRatio;

  /// 完済まで残りの我慢回数。
  final int remainingCount;

  /// 完済まで残りの金額(= 残り回数 × 1回あたり)。
  final double remainingYen;

  /// 記録した中での我慢率(我慢 ÷ (我慢+飲んだ))。
  final double abstentionRate;

  /// 全機会を我慢し続けた場合の完済予定日(残り0なら今日)。
  final DateTime? projectedCompletionDate;

  const DrinkChallengeStats({
    required this.abstainedCount,
    required this.drankCount,
    required this.targetCount,
    required this.perSessionYen,
    required this.savedYen,
    required this.totalDebtYen,
    required this.progressRatio,
    required this.remainingCount,
    required this.remainingYen,
    required this.abstentionRate,
    required this.projectedCompletionDate,
  });
}

class DrinkChallengeService {
  const DrinkChallengeService();

  static const int defaultTargetCount = 700;

  /// 1週間あたりの飲み機会の概算(金土日=3 + 祝日関連 ≈ 0.5)。完済予定日の試算に使う。
  static const double occasionsPerWeek = 3.5;

  /// 2026〜2027年の国民の祝日・休日(振替休日・国民の休日を含む)。
  /// 出典: 内閣府 / 国立天文台 暦要項。
  static const Set<String> japaneseHolidays = <String>{
    // 2026年(18日)
    '2026-01-01', '2026-01-12', '2026-02-11', '2026-02-23', '2026-03-20',
    '2026-04-29', '2026-05-03', '2026-05-04', '2026-05-05', '2026-05-06',
    '2026-07-20', '2026-08-11', '2026-09-21', '2026-09-22', '2026-09-23',
    '2026-10-12', '2026-11-03', '2026-11-23',
    // 2027年
    '2027-01-01', '2027-01-11', '2027-02-11', '2027-02-23', '2027-03-21',
    '2027-03-22', '2027-04-29', '2027-05-03', '2027-05-04', '2027-05-05',
    '2027-07-19', '2027-08-11', '2027-09-20', '2027-09-23', '2027-10-11',
    '2027-11-03', '2027-11-23',
  };

  static String dateKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  bool isHoliday(DateTime date) => japaneseHolidays.contains(dateKey(date));

  /// [start]〜[end](両端含む)の各日について飲み機会を判定して返す。
  List<DrinkOccasion> occasionsBetween(DateTime start, DateTime end) {
    final result = <DrinkOccasion>[];
    var day = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!day.isAfter(last)) {
      final reasons = <DrinkOccasionReason>[];
      switch (day.weekday) {
        case DateTime.friday:
          reasons.add(DrinkOccasionReason.fridayNight);
        case DateTime.saturday:
          reasons.add(DrinkOccasionReason.saturdayNight);
        case DateTime.sunday:
          reasons.add(DrinkOccasionReason.sundayNight);
      }
      if (isHoliday(day)) {
        reasons.add(DrinkOccasionReason.holiday);
      }
      if (isHoliday(day.add(const Duration(days: 1)))) {
        reasons.add(DrinkOccasionReason.holidayEve);
      }
      if (reasons.isNotEmpty) {
        result.add(DrinkOccasion(date: day, reasons: reasons));
      }
      day = day.add(const Duration(days: 1));
    }
    return result;
  }

  DrinkChallengeStats computeStats({
    required Map<String, DrinkRecordStatus> records,
    required double totalDebtYen,
    required DateTime baseDate,
    int targetCount = defaultTargetCount,
  }) {
    final target = targetCount <= 0 ? defaultTargetCount : targetCount;
    final abstained =
        records.values.where((s) => s == DrinkRecordStatus.abstained).length;
    final drank =
        records.values.where((s) => s == DrinkRecordStatus.drank).length;
    final debt = totalDebtYen.abs();
    final perSession = debt / target;
    final saved = abstained * perSession;
    final remaining = (target - abstained).clamp(0, target);
    final progress = (abstained / target).clamp(0.0, 1.0);
    final recorded = abstained + drank;
    final rate = recorded == 0 ? 0.0 : abstained / recorded;

    DateTime? projected;
    if (remaining <= 0) {
      projected = DateTime(baseDate.year, baseDate.month, baseDate.day);
    } else if (occasionsPerWeek > 0) {
      final days = (remaining / occasionsPerWeek * 7).ceil();
      final base = DateTime(baseDate.year, baseDate.month, baseDate.day);
      projected = base.add(Duration(days: days));
    }

    return DrinkChallengeStats(
      abstainedCount: abstained,
      drankCount: drank,
      targetCount: target,
      perSessionYen: perSession,
      savedYen: saved,
      totalDebtYen: debt,
      progressRatio: progress,
      remainingCount: remaining,
      remainingYen: remaining * perSession,
      abstentionRate: rate,
      projectedCompletionDate: projected,
    );
  }
}
