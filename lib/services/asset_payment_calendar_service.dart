import 'dart:math';

/// カレンダー用の負債入力(重量級の workbook 行から必要項目だけ写す)。
class AssetCalendarDebtInput {
  const AssetCalendarDebtInput({
    required this.name,
    required this.balance,
    required this.paymentDay,
    this.scheduledPaymentAmount = 0,
    this.isDirectCashflowTarget = true,
  });

  final String name;
  final double balance;
  final int? paymentDay;
  final double scheduledPaymentAmount;
  final bool isDirectCashflowTarget;
}

/// カレンダーに載せる日次イベントの種別。
enum AssetCalendarEventKind {
  salary,
  debtPayment,
  subscription,
  expense,
  income,
}

/// カレンダー1イベント。amount は不明な場合 null。
class AssetCalendarEvent {
  const AssetCalendarEvent({
    required this.kind,
    required this.label,
    this.amount,
  });

  final AssetCalendarEventKind kind;
  final String label;
  final double? amount;
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

  bool get hasIncome => incomeTotal > 0;

  bool get hasAnyEvent => events.isNotEmpty;
}

/// 月単位のカレンダー。weeks は日曜始まり・null は空セル。
class AssetPaymentCalendarMonth {
  const AssetPaymentCalendarMonth({
    required this.month,
    required this.days,
    required this.weeks,
    this.scheduledDebtPaymentTotal = 0,
    this.subscriptionTotal = 0,
    this.firstShortfallDate,
  });

  final DateTime month;
  final List<AssetCalendarDaySummary> days;
  final List<List<AssetCalendarDaySummary?>> weeks;

  /// 月内の返済予定額合計(金額が分かるもののみ)。
  final double scheduledDebtPaymentTotal;

  /// 月内の固定費(サブスク)請求額合計。
  final double subscriptionTotal;

  /// 見込み残高が最初にマイナスへ落ちる日。資金リスクの早期警告。
  final DateTime? firstShortfallDate;

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
  }) {
    final normalizedMonth = DateTime(month.year, month.month);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final expenseByDay = <int, double>{};
    final incomeByDay = <int, double>{};
    final outflowByDay = <int, double>{};
    final eventsByDay = <int, List<AssetCalendarEvent>>{};
    var scheduledDebtPaymentTotal = 0.0;
    var subscriptionTotal = 0.0;

    void addEvent(int day, AssetCalendarEvent event) {
      eventsByDay.putIfAbsent(day, () => <AssetCalendarEvent>[]).add(event);
    }

    if (salaryDay != null && salaryDay > 0) {
      addEvent(
        clampDayToMonth(salaryDay, normalizedMonth),
        const AssetCalendarEvent(
          kind: AssetCalendarEventKind.salary,
          label: '給料日',
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
      final clampedDay = clampDayToMonth(paymentDay, normalizedMonth);
      final amount = row.scheduledPaymentAmount > _epsilon
          ? row.scheduledPaymentAmount
          : null;
      if (amount != null) {
        scheduledDebtPaymentTotal += amount;
        outflowByDay[clampedDay] = (outflowByDay[clampedDay] ?? 0) + amount;
      }
      addEvent(
        clampedDay,
        AssetCalendarEvent(
          kind: AssetCalendarEventKind.debtPayment,
          label: '${row.name} 返済',
          amount: amount,
        ),
      );
    }

    for (final subscription in subscriptions) {
      final dueDate = DateTime.tryParse(
        subscription['due_date']?.toString() ?? '',
      )?.toLocal();
      if (dueDate == null ||
          dueDate.year != normalizedMonth.year ||
          dueDate.month != normalizedMonth.month) {
        continue;
      }
      final name = subscription['service_name']?.toString().trim() ?? '';
      final price = (subscription['price'] as num?)?.toDouble();
      if (price != null && price > 0) {
        subscriptionTotal += price;
        outflowByDay[dueDate.day] = (outflowByDay[dueDate.day] ?? 0) + price;
      }
      addEvent(
        dueDate.day,
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
      if (occurredAt == null ||
          occurredAt.year != normalizedMonth.year ||
          occurredAt.month != normalizedMonth.month) {
        continue;
      }
      final amount = (flow['amount'] as num?)?.toDouble() ?? 0;
      final actionType = flow['action_type']?.toString() ?? '';
      final description = flow['description']?.toString().trim() ?? '';
      final day = occurredAt.day;
      if (expenseActionTypes.contains(actionType)) {
        expenseByDay[day] = (expenseByDay[day] ?? 0) + amount.abs();
        addEvent(
          day,
          AssetCalendarEvent(
            kind: AssetCalendarEventKind.expense,
            label: description.isEmpty ? '支出' : description,
            amount: amount.abs(),
          ),
        );
      } else if (incomeActionTypes.contains(actionType)) {
        incomeByDay[day] = (incomeByDay[day] ?? 0) + amount.abs();
        addEvent(
          day,
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
    final days = <AssetCalendarDaySummary>[];
    for (var day = 1; day <= lastDay; day++) {
      final outflow = outflowByDay[day] ?? 0;
      if (runningBalance != null) {
        runningBalance = runningBalance - outflow;
      }
      final date = DateTime(normalizedMonth.year, normalizedMonth.month, day);
      if (firstShortfallDate == null &&
          runningBalance != null &&
          runningBalance < 0) {
        firstShortfallDate = date;
      }
      days.add(
        AssetCalendarDaySummary(
          date: date,
          expenseTotal: expenseByDay[day] ?? 0,
          incomeTotal: incomeByDay[day] ?? 0,
          events: _sortEvents(eventsByDay[day] ?? const <AssetCalendarEvent>[]),
          scheduledOutflow: outflow,
          projectedBalance: runningBalance,
        ),
      );
    }

    return AssetPaymentCalendarMonth(
      month: normalizedMonth,
      days: days,
      weeks: _buildWeeks(normalizedMonth, days),
      scheduledDebtPaymentTotal: scheduledDebtPaymentTotal,
      subscriptionTotal: subscriptionTotal,
      firstShortfallDate: firstShortfallDate,
    );
  }

  static List<AssetCalendarEvent> _sortEvents(List<AssetCalendarEvent> events) {
    final sorted = List<AssetCalendarEvent>.from(events);
    sorted.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return sorted;
  }

  /// 日曜始まりの週リストへ整形。月初までの空きと月末以降は null。
  static List<List<AssetCalendarDaySummary?>> _buildWeeks(
    DateTime month,
    List<AssetCalendarDaySummary> days,
  ) {
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday % 7;
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
