import 'dart:math';

import 'package:my_web_app/models/asset_liability_workbook.dart';

/// カレンダー用の負債入力(重量級の workbook 行から必要項目だけ写す)。
class AssetCalendarDebtInput {
  const AssetCalendarDebtInput({
    required this.name,
    required this.balance,
    required this.paymentDay,
    this.scheduledPaymentAmount = 0,
    this.isDirectCashflowTarget = true,
    this.isFixedCost = false,
    this.id = '',
    this.paid = false,
  });

  factory AssetCalendarDebtInput.fromDebtRow(
    AssetLiabilityDebtRow row, {
    Map<String, int>? paymentDayOverrides,
  }) {
    final overrideDay = paymentDayOverrides?[row.id] ??
        paymentDayOverrides?[row.name];
    return AssetCalendarDebtInput(
      id: row.id,
      name: row.name,
      balance: row.balance,
      paymentDay: overrideDay ?? row.paymentDay,
      scheduledPaymentAmount: row.scheduledPaymentAmount,
      isDirectCashflowTarget: row.isDirectCashflowTarget,
      isFixedCost: row.kind == AssetLiabilityAccountKind.utility ||
          row.fullPaymentEstimate,
      paid: row.paid,
    );
  }

  /// workbook 行ID(支払日移動などのアクション連携用)。
  final String id;
  final String name;
  final double balance;
  final int? paymentDay;
  final double scheduledPaymentAmount;
  final bool isDirectCashflowTarget;

  /// 家賃・通信費・サブスク等の全額支払い固定費か。
  /// true の行は返済額ではなく固定費額へ集計する。
  final bool isFixedCost;

  /// 支払完了済みフラグ。
  final bool paid;
}

/// カレンダーに載せる日次イベントの種別。
enum AssetCalendarEventKind {
  salary,
  expectedInflow,
  debtPayment,
  subscription,
  expense,
  income,
}

/// 入金予定の入力(ストアのモデルから必要項目だけ写す)。
class AssetCalendarInflowInput {
  const AssetCalendarInflowInput({
    required this.date,
    required this.amount,
    required this.label,
  });

  final DateTime date;
  final double amount;
  final String label;
}

/// カレンダー1イベント。amount は不明な場合 null。
class AssetCalendarEvent {
  const AssetCalendarEvent({
    required this.kind,
    required this.label,
    this.amount,
    this.sourceId,
    this.isPaid = false,
  });

  final AssetCalendarEventKind kind;
  final String label;
  final double? amount;

  /// 元データのID(debtPayment は workbook 行ID)。アクション連携用。
  final String? sourceId;

  /// 支払完了済みフラグ。
  final bool isPaid;
}

/// 1日分のサマリ。支出/収入はフロー記録の合算。
class AssetCalendarDaySummary {
  const AssetCalendarDaySummary({
    required this.date,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.events,
    this.scheduledOutflow = 0,
    this.projectedBalance,
  });

  final DateTime date;
  final double expenseTotal;
  final double incomeTotal;
  final List<AssetCalendarEvent> events;

  /// この日に予定されている支払(返済+固定費)の合計。
  final double scheduledOutflow;

  /// 月初の現金・預金から支払予定だけを引いた保守的な見込み残高。
  /// 入金(給料等)は加算しない。起点残高が未指定なら null。
  final double? projectedBalance;

  bool get isShortfall => projectedBalance != null && projectedBalance! < 0;

  bool _has(AssetCalendarEventKind kind) =>
      events.any((event) => event.kind == kind);

  bool get hasSalary => _has(AssetCalendarEventKind.salary);

  bool get hasDebtPayment => _has(AssetCalendarEventKind.debtPayment);

  bool get hasSubscription => _has(AssetCalendarEventKind.subscription);

  bool get hasExpectedInflow => _has(AssetCalendarEventKind.expectedInflow);

  bool get hasIncome => incomeTotal > 0;

  bool get hasAnyEvent => events.isNotEmpty;
}

/// 表示期間(暦月 or 給料日サイクル)のカレンダー。weeks は日曜始まり・null は空セル。
class AssetPaymentCalendarMonth {
  const AssetPaymentCalendarMonth({
    required this.month,
    required this.rangeStart,
    required this.rangeEndExclusive,
    required this.days,
    required this.weeks,
    this.scheduledDebtPaymentTotal = 0,
    this.subscriptionTotal = 0,
    this.firstShortfallDate,
    this.worstProjectedBalance,
  });

  final DateTime month;

  /// 表示期間の開始日(暦月なら1日 / 給料日サイクルなら給料日)。
  final DateTime rangeStart;

  /// 表示期間の終了(排他)。
  final DateTime rangeEndExclusive;

  final List<AssetCalendarDaySummary> days;
  final List<List<AssetCalendarDaySummary?>> weeks;

  /// 期間内の返済予定額合計(金額が分かるもののみ)。
  final double scheduledDebtPaymentTotal;

  /// 期間内の固定費(utility・サブスク)請求額合計。
  final double subscriptionTotal;

  /// 見込み残高が最初にマイナスへ落ちる日。資金リスクの早期警告。
  final DateTime? firstShortfallDate;

  /// 月内の見込み残高の最小値(起点未指定なら null)。
  final double? worstProjectedBalance;

  /// ショート回避に必要な追加入金額(=最大不足幅)。ショートなしなら 0。
  double get shortfallRecoveryAmount =>
      worstProjectedBalance != null && worstProjectedBalance! < 0
          ? -worstProjectedBalance!
          : 0;

  double get scheduledOutflowTotal =>
      scheduledDebtPaymentTotal + subscriptionTotal;

  AssetCalendarDaySummary? dayFor(DateTime date) {
    for (final day in days) {
      if (day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day) {
        return day;
      }
    }
    return null;
  }
}

/// フロー記録・サブスク請求日・負債返済日・給料日を月カレンダーへ集約する。
/// 入力はページが保持する生データ(Supabase row の Map)をそのまま受ける。
class AssetPaymentCalendarService {
  const AssetPaymentCalendarService();

  /// wealth_struggles の action_type 分類(ページ実装と同一)。
  static const Set<String> expenseActionTypes = <String>{'expense'};
  static const Set<String> incomeActionTypes = <String>{'conquer'};

  static const double _epsilon = 0.01;

  /// 31日などが短い月に食い込む場合は月末日に丸める(2月の26日締め等)。
  static int clampDayToMonth(int day, DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return max(1, min(day, lastDay));
  }

  static AssetPaymentCalendarMonth buildMonth({
    required DateTime month,
    required List<Map<String, dynamic>> flows,
    required List<Map<String, dynamic>> subscriptions,
    required List<AssetCalendarDebtInput> debts,
    int? salaryDay,
    double? startingCashBalance,
    List<AssetCalendarInflowInput> expectedInflows =
        const <AssetCalendarInflowInput>[],
  }) {
    return buildRange(
      start: DateTime(month.year, month.month),
      endExclusive: DateTime(month.year, month.month + 1),
      flows: flows,
      subscriptions: subscriptions,
      debts: debts,
      salaryDay: salaryDay,
      startingCashBalance: startingCashBalance,
      expectedInflows: expectedInflows,
    );
  }

  /// [start]〜[endExclusive)(給料日サイクル等の複数暦月に跨りうる窓)の
  /// カレンダーを組み立てる。支払日・給料日(日指定)は窓内に落ちる暦月へ解決する。
  ///
  /// [asOf] を渡すと予定系(返済・固定費・入金予定)は `asOf` 以降の日付のみ
  /// 予定として計上する(過去分は現在残高に織り込み済みとみなし、実績は
  /// フロー記録が担う)。null なら窓内全日を予定として扱う(暦月互換)。
  static AssetPaymentCalendarMonth buildRange({
    required DateTime start,
    required DateTime endExclusive,
    required List<Map<String, dynamic>> flows,
    required List<Map<String, dynamic>> subscriptions,
    required List<AssetCalendarDebtInput> debts,
    int? salaryDay,
    DateTime? asOf,
    double? startingCashBalance,
    List<AssetCalendarInflowInput> expectedInflows =
        const <AssetCalendarInflowInput>[],
  }) {
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(
      endExclusive.year,
      endExclusive.month,
      endExclusive.day,
    );
    // 予定系イベントを計上する下限(この日を含む)。
    final scheduleStart = asOf == null
        ? rangeStart
        : _laterDate(rangeStart, DateTime(asOf.year, asOf.month, asOf.day));
    final expenseByDate = <int, double>{};
    final incomeByDate = <int, double>{};
    final outflowByDate = <int, double>{};
    final inflowByDate = <int, double>{};
    final eventsByDate = <int, List<AssetCalendarEvent>>{};
    var scheduledDebtPaymentTotal = 0.0;
    var subscriptionTotal = 0.0;
    final scheduledFixedCostKeys = <String>{};

    bool inRange(DateTime date) =>
        !date.isBefore(rangeStart) && date.isBefore(rangeEnd);

    bool inSchedule(DateTime date) =>
        !date.isBefore(scheduleStart) && date.isBefore(rangeEnd);

    void addEvent(DateTime date, AssetCalendarEvent event) {
      eventsByDate
          .putIfAbsent(_dateKey(date), () => <AssetCalendarEvent>[])
          .add(event);
    }

    String fixedCostKey(String name, DateTime date, double amount) {
      final normalizedName = name.trim().toLowerCase().replaceAll(
            RegExp(r'\s+'),
            '',
          );
      return '$normalizedName|${_dateKey(date)}|${amount.toStringAsFixed(2)}';
    }

    // 窓に重なる暦月ごとに「毎月N日」を実日付へ解決する(月末クランプ)。
    // 窓は高々2暦月に跨るが、任意長でも正しく動く。
    final overlappingMonths = <DateTime>[];
    if (rangeStart.isBefore(rangeEnd)) {
      final lastMonth = DateTime(
        rangeEnd.year,
        rangeEnd.month,
        rangeEnd.day,
      ).subtract(const Duration(days: 1));
      var cursor = DateTime(rangeStart.year, rangeStart.month);
      final endMonth = DateTime(lastMonth.year, lastMonth.month);
      while (!cursor.isAfter(endMonth)) {
        overlappingMonths.add(cursor);
        cursor = DateTime(cursor.year, cursor.month + 1);
      }
    }

    if (salaryDay != null && salaryDay > 0) {
      for (final month in overlappingMonths) {
        final date = DateTime(
          month.year,
          month.month,
          clampDayToMonth(salaryDay, month),
        );
        if (inRange(date)) {
          addEvent(
            date,
            const AssetCalendarEvent(
              kind: AssetCalendarEventKind.salary,
              label: '給料日',
            ),
          );
        }
      }
    }

    for (final inflow in expectedInflows) {
      final date = DateTime(
        inflow.date.year,
        inflow.date.month,
        inflow.date.day,
      );
      if (!inSchedule(date) || inflow.amount <= 0) {
        continue;
      }
      inflowByDate[_dateKey(date)] =
          (inflowByDate[_dateKey(date)] ?? 0) + inflow.amount;
      addEvent(
        date,
        AssetCalendarEvent(
          kind: AssetCalendarEventKind.expectedInflow,
          label: inflow.label,
          amount: inflow.amount,
        ),
      );
    }

    for (final row in debts) {
      final paymentDay = row.paymentDay;
      if (paymentDay == null || paymentDay <= 0) {
        continue;
      }
      if (row.balance >= -_epsilon || !row.isDirectCashflowTarget) {
        continue;
      }
      for (final month in overlappingMonths) {
        final date = DateTime(
          month.year,
          month.month,
          clampDayToMonth(paymentDay, month),
        );
        if (!inSchedule(date)) {
          continue;
        }
        final amount = (!row.paid && row.scheduledPaymentAmount > _epsilon)
            ? row.scheduledPaymentAmount
            : null;
        if (amount != null) {
          if (row.isFixedCost) {
            subscriptionTotal += amount;
            scheduledFixedCostKeys.add(fixedCostKey(row.name, date, amount));
          } else {
            scheduledDebtPaymentTotal += amount;
          }
          outflowByDate[_dateKey(date)] =
              (outflowByDate[_dateKey(date)] ?? 0) + amount;
        }
        addEvent(
          date,
          AssetCalendarEvent(
            kind: row.isFixedCost
                ? AssetCalendarEventKind.subscription
                : AssetCalendarEventKind.debtPayment,
            label: row.isFixedCost
                ? (row.paid ? '${row.name} (支払済)' : row.name)
                : (row.paid ? '${row.name} (支払済)' : '${row.name} 返済'),
            amount: amount,
            sourceId: row.id.isEmpty ? null : row.id,
            isPaid: row.paid,
          ),
        );
      }
    }

    for (final subscription in subscriptions) {
      final dueDate = DateTime.tryParse(
        subscription['due_date']?.toString() ?? '',
      )?.toLocal();
      if (dueDate == null) {
        continue;
      }
      final date = DateTime(dueDate.year, dueDate.month, dueDate.day);
      if (!inSchedule(date)) {
        continue;
      }
      final name = subscription['service_name']?.toString().trim() ?? '';
      final price = (subscription['price'] as num?)?.toDouble();
      if (price != null && price > 0) {
        if (scheduledFixedCostKeys.contains(fixedCostKey(name, date, price))) {
          continue;
        }
        subscriptionTotal += price;
        outflowByDate[_dateKey(date)] =
            (outflowByDate[_dateKey(date)] ?? 0) + price;
      }
      addEvent(
        date,
        AssetCalendarEvent(
          kind: AssetCalendarEventKind.subscription,
          label: name.isEmpty ? '固定費' : name,
          amount: price,
        ),
      );
    }

    for (final flow in flows) {
      final occurredAt = DateTime.tryParse(
        flow['occurred_at']?.toString() ?? '',
      )?.toLocal();
      if (occurredAt == null) {
        continue;
      }
      final date = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
      if (!inRange(date)) {
        continue;
      }
      final amount = (flow['amount'] as num?)?.toDouble() ?? 0;
      final actionType = flow['action_type']?.toString() ?? '';
      final description = flow['description']?.toString().trim() ?? '';
      if (expenseActionTypes.contains(actionType)) {
        expenseByDate[_dateKey(date)] =
            (expenseByDate[_dateKey(date)] ?? 0) + amount.abs();
        addEvent(
          date,
          AssetCalendarEvent(
            kind: AssetCalendarEventKind.expense,
            label: description.isEmpty ? '支出' : description,
            amount: amount.abs(),
          ),
        );
      } else if (incomeActionTypes.contains(actionType)) {
        incomeByDate[_dateKey(date)] =
            (incomeByDate[_dateKey(date)] ?? 0) + amount.abs();
        addEvent(
          date,
          AssetCalendarEvent(
            kind: AssetCalendarEventKind.income,
            label: description.isEmpty ? '収入' : description,
            amount: amount.abs(),
          ),
        );
      }
    }

    var runningBalance = startingCashBalance;
    DateTime? firstShortfallDate;
    double? worstProjectedBalance;
    final days = <AssetCalendarDaySummary>[];
    var date = rangeStart;
    while (date.isBefore(rangeEnd)) {
      final key = _dateKey(date);
      final outflow = outflowByDate[key] ?? 0;
      final inflow = inflowByDate[key] ?? 0;
      if (runningBalance != null) {
        runningBalance = runningBalance + inflow - outflow;
      }
      if (firstShortfallDate == null &&
          runningBalance != null &&
          runningBalance < 0) {
        firstShortfallDate = date;
      }
      if (runningBalance != null &&
          (worstProjectedBalance == null ||
              runningBalance < worstProjectedBalance)) {
        worstProjectedBalance = runningBalance;
      }
      days.add(
        AssetCalendarDaySummary(
          date: date,
          expenseTotal: expenseByDate[key] ?? 0,
          incomeTotal: incomeByDate[key] ?? 0,
          events: _sortEvents(
            eventsByDate[key] ?? const <AssetCalendarEvent>[],
          ),
          scheduledOutflow: outflow,
          projectedBalance: runningBalance,
        ),
      );
      date = DateTime(date.year, date.month, date.day + 1);
    }

    return AssetPaymentCalendarMonth(
      month: DateTime(rangeStart.year, rangeStart.month),
      rangeStart: rangeStart,
      rangeEndExclusive: rangeEnd,
      days: days,
      weeks: _buildWeeks(rangeStart, days),
      scheduledDebtPaymentTotal: scheduledDebtPaymentTotal,
      subscriptionTotal: subscriptionTotal,
      firstShortfallDate: firstShortfallDate,
      worstProjectedBalance: worstProjectedBalance,
    );
  }

  static int _dateKey(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  static DateTime _laterDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  /// [candidateIds] のうち、支払日を [shiftToDay] へ移すことでショートが
  /// 解消する最小の部分集合を返す。同サイズ候補が複数ある場合は
  /// **移動する予定支払額の合計が最小**の組合せを優先する。
  /// 候補7件以上は組合せ爆発を避け全件移動のみ判定する。
  static List<String>? findMinimalShiftSet({
    required DateTime month,
    required List<Map<String, dynamic>> flows,
    required List<Map<String, dynamic>> subscriptions,
    required List<AssetCalendarDebtInput> debts,
    required List<String> candidateIds,
    required int shiftToDay,
    int? salaryDay,
    DateTime? rangeStart,
    DateTime? rangeEndExclusive,
    DateTime? asOf,
    double? startingCashBalance,
    List<AssetCalendarInflowInput> expectedInflows =
        const <AssetCalendarInflowInput>[],
  }) {
    final start = rangeStart ?? DateTime(month.year, month.month);
    final endExclusive =
        rangeEndExclusive ?? DateTime(month.year, month.month + 1);
    bool clears(List<String> subset) {
      final shifted = buildRange(
        start: start,
        endExclusive: endExclusive,
        flows: flows,
        subscriptions: subscriptions,
        debts: [
          for (final debt in debts)
            if (subset.contains(debt.id))
              AssetCalendarDebtInput(
                id: debt.id,
                name: debt.name,
                balance: debt.balance,
                paymentDay: shiftToDay,
                scheduledPaymentAmount: debt.scheduledPaymentAmount,
                isDirectCashflowTarget: debt.isDirectCashflowTarget,
                isFixedCost: debt.isFixedCost,
              )
            else
              debt,
        ],
        salaryDay: salaryDay,
        asOf: asOf,
        startingCashBalance: startingCashBalance,
        expectedInflows: expectedInflows,
      );
      return shifted.firstShortfallDate == null;
    }

    double subsetAmount(List<String> subset) {
      var total = 0.0;
      for (final debt in debts) {
        if (subset.contains(debt.id)) {
          total += debt.scheduledPaymentAmount;
        }
      }
      return total;
    }

    if (candidateIds.length > 6) {
      return clears(candidateIds) ? List<String>.from(candidateIds) : null;
    }
    final maskLimit = 1 << candidateIds.length;
    for (var size = 2; size <= candidateIds.length; size++) {
      List<String>? best;
      var bestAmount = double.infinity;
      for (var mask = 1; mask < maskLimit; mask++) {
        var bits = 0;
        for (var i = 0; i < candidateIds.length; i++) {
          final bit = 1 << i;
          if (mask & bit != 0) {
            bits += 1;
          }
        }
        if (bits != size) {
          continue;
        }
        final subset = <String>[
          for (var i = 0; i < candidateIds.length; i++)
            if (mask & 1 << i != 0) candidateIds[i],
        ];
        if (!clears(subset)) {
          continue;
        }
        final amount = subsetAmount(subset);
        if (amount < bestAmount) {
          best = subset;
          bestAmount = amount;
        }
      }
      if (best != null) {
        return best;
      }
    }
    return null;
  }

  static List<AssetCalendarEvent> _sortEvents(List<AssetCalendarEvent> events) {
    final sorted = List<AssetCalendarEvent>.from(events);
    sorted.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return sorted;
  }

  /// 日曜始まりの週リストへ整形。期間開始日までの空きと終了以降は null。
  static List<List<AssetCalendarDaySummary?>> _buildWeeks(
    DateTime start,
    List<AssetCalendarDaySummary> days,
  ) {
    final leadingBlanks = start.weekday % 7;
    final cells = <AssetCalendarDaySummary?>[
      for (var i = 0; i < leadingBlanks; i++) null,
      ...days,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return <List<AssetCalendarDaySummary?>>[
      for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7),
    ];
  }
}
