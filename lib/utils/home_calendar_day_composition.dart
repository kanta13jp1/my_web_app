import '../models/home_daily_cashflow_summary.dart';
import 'home_calendar_visible_range.dart';

/// Slipped guard item metadata needed to choose the next replacement action.
class HomeCalendarSlipCandidate {
  final String label;
  final String replacementAction;
  final int slipCount;

  const HomeCalendarSlipCandidate({
    required this.label,
    required this.replacementAction,
    required this.slipCount,
  });
}

/// Pure daily abstinence summary decoupled from store-specific types.
class HomeCalendarAbstinenceInput {
  final int enabledCount;
  final int totalSlipCount;
  final int disciplineRepCount;
  final List<String> enabledLabels;
  final List<String> slipDetails;
  final List<HomeCalendarSlipCandidate> slippedCandidates;

  const HomeCalendarAbstinenceInput({
    this.enabledCount = 0,
    this.totalSlipCount = 0,
    this.disciplineRepCount = 0,
    this.enabledLabels = const <String>[],
    this.slipDetails = const <String>[],
    this.slippedCandidates = const <HomeCalendarSlipCandidate>[],
  });
}

/// Pure daily routine completion flags for one calendar day.
class HomeCalendarDailyStatusInput {
  final bool morningBriefingDone;
  final bool balanceCheckDone;

  const HomeCalendarDailyStatusInput({
    this.morningBriefingDone = false,
    this.balanceCheckDone = false,
  });
}

/// Composed calendar day model produced without widget or store state.
class HomeCalendarComposedDay<TTask> {
  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isFuture;
  final bool morningDone;
  final bool balanceDone;
  final int pendingCriticalTaskCount;
  final bool hasAbstinenceProtection;
  final bool hasAbstinenceSlip;
  final bool hasAdditionalDebtViolation;
  final bool isSaturday;
  final List<String> enabledLabels;
  final List<String> slipDetails;
  final List<String> missingItems;
  final String relapsePreventionAction;
  final HomeDailyCashflowSummary cashflow;
  final List<TTask> tasks;

  const HomeCalendarComposedDay({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isFuture,
    required this.morningDone,
    required this.balanceDone,
    required this.pendingCriticalTaskCount,
    required this.hasAbstinenceProtection,
    required this.hasAbstinenceSlip,
    this.hasAdditionalDebtViolation = false,
    required this.isSaturday,
    required this.enabledLabels,
    required this.slipDetails,
    required this.missingItems,
    required this.relapsePreventionAction,
    this.cashflow = const HomeDailyCashflowSummary(),
    required this.tasks,
  });
}

/// Builds the ordered list of incomplete daily items for a non-future day.
List<String> buildHomeCalendarMissingItems({
  required bool isFuture,
  required bool morningDone,
  required bool balanceDone,
  required int pendingCriticalTaskCount,
  required bool hasProtection,
}) {
  return <String>[
    if (!isFuture && !morningDone) 'モーニング・ブリーフィング',
    if (!isFuture && !balanceDone) '口座残高確認',
    if (!isFuture && pendingCriticalTaskCount > 0)
      '必須タスク $pendingCriticalTaskCount件',
    if (!isFuture && !hasProtection) '禁欲ガード設定',
  ];
}

/// Selects the relapse-prevention prompt using Home's existing priority order.
String buildHomeCalendarRelapsePreventionAction({
  required bool isFuture,
  required bool hasSlip,
  required List<HomeCalendarSlipCandidate> slippedCandidates,
  required bool hasProtection,
  required int disciplineRepCount,
  required bool morningDone,
  required bool balanceDone,
}) {
  if (isFuture) {
    return '前日までの逸脱傾向を見て、禁止対象を1件だけ先に固定する。';
  }

  if (hasSlip) {
    final sortedSlips = List<HomeCalendarSlipCandidate>.from(slippedCandidates)
      ..sort((a, b) => b.slipCount.compareTo(a.slipCount));
    if (sortedSlips.isNotEmpty) {
      final top = sortedSlips.first;
      return '${top.label}が崩れやすい日。${top.replacementAction}';
    }
  }

  if (!hasProtection) {
    return '朝いちで禁止対象を1件だけ固定して、先に逃げ道を塞ぐ。';
  }
  if (disciplineRepCount == 0) {
    return '今日はまだ我慢の実績がありません。買わない・開かないを1回記録する。';
  }
  if (!morningDone) {
    return '朝の最初にブリーフィングを実施し、優先順位を固定する。';
  }
  if (!balanceDone) {
    return '口座残高確認を先に終えて、意思決定を数字に戻す。';
  }

  return '同じ禁止対象を維持し、夜に逸脱ゼロを確認して日次を閉じる。';
}

/// Composes calendar days while calling fetchAbstinenceByDate at most once.
Future<List<HomeCalendarComposedDay<TTask>>> loadHomeCalendarDays<TTask>({
  required HomeCalendarVisibleRange range,
  required DateTime now,
  required String Function(DateTime) dateKeyFor,
  required Map<String, HomeCalendarDailyStatusInput> dailyStatusByDate,
  required Map<String, int> pendingCriticalTaskMap,
  required Map<String, HomeDailyCashflowSummary> cashflowByDate,
  required Map<String, List<TTask>> tasksByDate,
  Map<String, HomeCalendarAbstinenceInput>? abstinenceByDate,
  required Future<Map<String, HomeCalendarAbstinenceInput>> Function(
    DateTime startDate,
    DateTime endDate,
  ) fetchAbstinenceByDate,
  Set<String> additionalDebtViolationDates = const <String>{},
}) async {
  final monthAnchor = range.monthAnchor;
  final startDay = range.startDay;
  final endDay = range.endDay;
  final resolvedAbstinenceByDate =
      abstinenceByDate ?? await fetchAbstinenceByDate(startDay, endDay);

  final days = <HomeCalendarComposedDay<TTask>>[];
  final todayDate = DateTime(now.year, now.month, now.day);
  for (DateTime day = startDay;
      !day.isAfter(endDay);
      day = day.add(const Duration(days: 1))) {
    final dateKey = dateKeyFor(day);
    final abstinence = resolvedAbstinenceByDate[dateKey] ??
        const HomeCalendarAbstinenceInput();
    final isCurrentMonth =
        day.year == monthAnchor.year && day.month == monthAnchor.month;
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final dayStatus =
        dailyStatusByDate[dateKey] ?? const HomeCalendarDailyStatusInput();
    final morningDone = dayStatus.morningBriefingDone;
    final balanceDone = dayStatus.balanceCheckDone;
    final pendingCriticalTaskCountForDay = pendingCriticalTaskMap[dateKey] ?? 0;
    final tasks = List<TTask>.from(tasksByDate[dateKey] ?? <TTask>[]);
    final cashflow =
        cashflowByDate[dateKey] ?? const HomeDailyCashflowSummary();
    final hasProtection = abstinence.enabledCount > 0;
    final hasSlip = abstinence.totalSlipCount > 0;
    final isFuture = day.isAfter(todayDate);
    final missingItems = buildHomeCalendarMissingItems(
      isFuture: isFuture,
      morningDone: morningDone,
      balanceDone: balanceDone,
      pendingCriticalTaskCount: pendingCriticalTaskCountForDay,
      hasProtection: hasProtection,
    );
    final relapsePreventionAction = buildHomeCalendarRelapsePreventionAction(
      isFuture: isFuture,
      hasSlip: hasSlip,
      slippedCandidates: abstinence.slippedCandidates,
      hasProtection: hasProtection,
      disciplineRepCount: abstinence.disciplineRepCount,
      morningDone: morningDone,
      balanceDone: balanceDone,
    );

    days.add(
      HomeCalendarComposedDay<TTask>(
        date: day,
        isCurrentMonth: isCurrentMonth,
        isToday: isToday,
        isFuture: isFuture,
        morningDone: morningDone,
        balanceDone: balanceDone,
        pendingCriticalTaskCount: pendingCriticalTaskCountForDay,
        hasAbstinenceProtection: hasProtection,
        hasAbstinenceSlip: hasSlip,
        hasAdditionalDebtViolation:
            additionalDebtViolationDates.contains(dateKey),
        isSaturday: day.weekday == DateTime.saturday,
        enabledLabels: abstinence.enabledLabels,
        slipDetails: abstinence.slipDetails,
        missingItems: missingItems,
        relapsePreventionAction: relapsePreventionAction,
        cashflow: cashflow,
        tasks: tasks,
      ),
    );
  }
  return days;
}
