class MonthlyKpiGoal {
  final String id;
  final String title;
  final String level;
  final String category;
  final int progress;
  final String status;
  final int priority;
  final DateTime? targetDate;

  const MonthlyKpiGoal({
    required this.id,
    required this.title,
    required this.level,
    required this.category,
    required this.progress,
    required this.status,
    required this.priority,
    this.targetDate,
  });

  factory MonthlyKpiGoal.fromMap(Map<String, dynamic> data) {
    return MonthlyKpiGoal(
      id: _asString(data['id']),
      title: _asString(data['title'], fallback: '(無題)'),
      level: _asString(data['level'], fallback: 'small'),
      category: _asString(data['category'], fallback: 'other'),
      progress: _asInt(data['progress']).clamp(0, 100).toInt(),
      status: _asString(data['status'], fallback: 'active'),
      priority: _asInt(data['priority'], fallback: 3).clamp(1, 5).toInt(),
      targetDate: _asDate(data['target_date']),
    );
  }

  bool get isCompleted => status == 'completed' || progress >= 100;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'level': level,
        'category': category,
        'progress': progress,
        'status': status,
        'priority': priority,
        'target_date': targetDate?.toIso8601String(),
      };
}

class MonthlyKpiReview {
  final String goalId;
  final int? progressBefore;
  final int? progressAfter;
  final DateTime createdAt;

  const MonthlyKpiReview({
    required this.goalId,
    required this.createdAt,
    this.progressBefore,
    this.progressAfter,
  });

  factory MonthlyKpiReview.fromMap(Map<String, dynamic> data) {
    return MonthlyKpiReview(
      goalId: _asString(data['goal_id']),
      progressBefore: _asNullableInt(data['progress_before']),
      progressAfter: _asNullableInt(data['progress_after']),
      createdAt:
          _asDate(data['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class MonthlyKpiMetric {
  final MonthlyKpiGoal goal;
  final double currentMonthDelta;
  final double previousMonthDelta;

  const MonthlyKpiMetric({
    required this.goal,
    required this.currentMonthDelta,
    required this.previousMonthDelta,
  });

  double get monthOverMonthDelta => currentMonthDelta - previousMonthDelta;

  double get progressRate => goal.progress / 100;

  bool isAtRisk(DateTime now) {
    final target = goal.targetDate;
    if (target == null || goal.progress >= 80 || goal.isCompleted) {
      return false;
    }
    final daysLeft = target.difference(now).inDays;
    return daysLeft >= 0 && daysLeft <= 30;
  }

  Map<String, dynamic> toJson() => {
        ...goal.toJson(),
        'current_month_delta': currentMonthDelta,
        'previous_month_delta': previousMonthDelta,
        'month_over_month_delta': monthOverMonthDelta,
        'progress_rate': progressRate,
      };
}

class MonthlyKpiLedger {
  final DateTime monthStart;
  final DateTime previousMonthStart;
  final List<MonthlyKpiMetric> metrics;
  final double averageProgress;
  final double currentMonthDeltaAverage;
  final double previousMonthDeltaAverage;

  const MonthlyKpiLedger({
    required this.monthStart,
    required this.previousMonthStart,
    required this.metrics,
    required this.averageProgress,
    required this.currentMonthDeltaAverage,
    required this.previousMonthDeltaAverage,
  });

  int get goalCount => metrics.length;

  int get completedCount =>
      metrics.where((metric) => metric.goal.isCompleted).length;

  double get progressRate => averageProgress / 100;

  double get monthOverMonthDelta =>
      currentMonthDeltaAverage - previousMonthDeltaAverage;

  List<MonthlyKpiMetric> atRiskGoals(DateTime now) =>
      metrics.where((metric) => metric.isAtRisk(now)).toList()
        ..sort((a, b) {
          final aDate = a.goal.targetDate ?? DateTime(9999);
          final bDate = b.goal.targetDate ?? DateTime(9999);
          return aDate.compareTo(bDate);
        });

  Map<String, dynamic> toJson() => {
        'month_start': monthStart.toIso8601String(),
        'previous_month_start': previousMonthStart.toIso8601String(),
        'goal_count': goalCount,
        'completed_count': completedCount,
        'average_progress': averageProgress,
        'progress_rate': progressRate,
        'current_month_delta_average': currentMonthDeltaAverage,
        'previous_month_delta_average': previousMonthDeltaAverage,
        'month_over_month_delta': monthOverMonthDelta,
        'metrics': metrics.map((metric) => metric.toJson()).toList(),
      };
}

class MonthlyKpiService {
  const MonthlyKpiService();

  MonthlyKpiLedger buildLedger({
    required List<Map<String, dynamic>> goals,
    required List<Map<String, dynamic>> reviews,
    DateTime? now,
  }) {
    final baseDate = now ?? DateTime.now();
    final monthStart = DateTime(baseDate.year, baseDate.month);
    final nextMonthStart = DateTime(baseDate.year, baseDate.month + 1);
    final previousMonthStart = DateTime(baseDate.year, baseDate.month - 1);

    final parsedGoals = goals
        .map(MonthlyKpiGoal.fromMap)
        .where((goal) => goal.id.isNotEmpty && goal.status != 'abandoned')
        .toList()
      ..sort(_compareGoals);
    final parsedReviews = reviews
        .map(MonthlyKpiReview.fromMap)
        .where((review) => review.goalId.isNotEmpty)
        .toList();

    final metrics = parsedGoals.map((goal) {
      return MonthlyKpiMetric(
        goal: goal,
        currentMonthDelta: _deltaForGoal(
          parsedReviews,
          goal.id,
          monthStart,
          nextMonthStart,
        ),
        previousMonthDelta: _deltaForGoal(
          parsedReviews,
          goal.id,
          previousMonthStart,
          monthStart,
        ),
      );
    }).toList();

    return MonthlyKpiLedger(
      monthStart: monthStart,
      previousMonthStart: previousMonthStart,
      metrics: metrics,
      averageProgress: _average(
        metrics.map((metric) => metric.goal.progress.toDouble()),
      ),
      currentMonthDeltaAverage: _average(
        metrics.map((metric) => metric.currentMonthDelta),
      ),
      previousMonthDeltaAverage: _average(
        metrics.map((metric) => metric.previousMonthDelta),
      ),
    );
  }

  List<String> fallbackAdvice(MonthlyKpiLedger ledger, DateTime now) {
    if (ledger.goalCount == 0) {
      return const [
        '今月の LifeGoals がまだありません。まず CFO Office から 1 件だけ月次 KPI にしたい目標を登録してください。',
      ];
    }

    final atRisk = ledger.atRiskGoals(now);
    final actions = <String>[];
    if (ledger.averageProgress < 40) {
      actions
          .add('平均進捗が 40% 未満です。今月は最重要の small 目標を 1 件に絞り、毎日 15 分の実行枠を固定してください。');
    } else if (ledger.averageProgress < 70) {
      actions.add('平均進捗は中盤です。進捗 50% 未満の目標を 1 件選び、次のレビューまでに +10pt だけ進めてください。');
    } else {
      actions.add('平均進捗は良好です。完了目前の目標を締め切り、翌月の KPI 候補を 1 件だけ前倒しで準備してください。');
    }

    if (ledger.monthOverMonthDelta < 0) {
      actions.add('前月比が低下しています。新規目標を増やすより、既存目標のレビュー頻度を週 2 回に戻してください。');
    } else {
      actions.add('前月比は改善傾向です。このペースを崩さないよう、今月の勝ちパターンを 1 行メモに残してください。');
    }

    if (atRisk.isNotEmpty) {
      actions.add(
        '期限 30 日以内かつ進捗 80% 未満の目標があります: ${atRisk.first.goal.title}。今日の最初の 1 手にしてください。',
      );
    }

    return actions;
  }

  int _compareGoals(MonthlyKpiGoal a, MonthlyKpiGoal b) {
    const levelOrder = {'dream': 0, 'big': 1, 'medium': 2, 'small': 3};
    final levelCompare =
        (levelOrder[a.level] ?? 99).compareTo(levelOrder[b.level] ?? 99);
    if (levelCompare != 0) return levelCompare;
    final priorityCompare = b.priority.compareTo(a.priority);
    if (priorityCompare != 0) return priorityCompare;
    return a.title.compareTo(b.title);
  }

  double _deltaForGoal(
    List<MonthlyKpiReview> reviews,
    String goalId,
    DateTime start,
    DateTime end,
  ) {
    final rows = reviews
        .where(
          (review) =>
              review.goalId == goalId &&
              !review.createdAt.isBefore(start) &&
              review.createdAt.isBefore(end),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (rows.isEmpty) return 0;
    final first = rows.first;
    final last = rows.last;
    final before = first.progressBefore ?? first.progressAfter ?? 0;
    final after = last.progressAfter ?? last.progressBefore ?? before;
    return (after - before).clamp(-100, 100).toDouble();
  }

  double _average(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((sum, value) => sum + value) / list.length;
  }
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _asDate(Object? value) {
  if (value is DateTime) return value;
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}
