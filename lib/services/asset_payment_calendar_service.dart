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
  });

  final DateTime date;
  final double expenseTotal;
  final double incomeTotal;
  final List<AssetCalendarEvent> events;

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
  });

  final DateTime month;
  final List<AssetCalendarDaySummary> days;
  final List<List<AssetCalendarDaySummary?>> weeks;

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
  }) {
    final normalizedMonth = DateTime(month.year, month.month);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final expenseByDay = <int, double>{};
    final incomeByDay = <int, double>{};
    final eventsByDay = <int, List<AssetCalendarEvent>>{};

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
      addEvent(
        clampDayToMonth(paymentDay, normalizedMonth),
        AssetCalendarEvent(
          kind: AssetCalendarEventKind.debtPayment,
          label: '${row.name} 返済',
          amount: row.scheduledPaymentAmount > _epsilon
              ? row.scheduledPaymentAmount
              : null,
        ),
      );
    }

    for (final subscription in subscriptions) {
      final dueDate =
          DateTime.tryParse(subscription['due_date']?.toString() ?? '')
              ?.toLocal();
      if (dueDate == null ||
          dueDate.year != normalizedMonth.year ||
          dueDate.month != normalizedMonth.month) {
        continue;
      }
      final name = subscription['service_name']?.toString().trim() ?? '';
      addEvent(
        dueDate.day,
        AssetCalendarEvent(
          kind: AssetCalendarEventKind.subscription,
          label: name.isEmpty ? '固定費' : name,
          amount: (subscription['price'] as num?)?.toDouble(),
        ),
      );
    }

    for (final flow in flows) {
      final occurredAt =
          DateTime.tryParse(flow['occurred_at']?.toString() ?? '')?.toLocal();
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

    final days = <AssetCalendarDaySummary>[
      for (var day = 1; day <= lastDay; day++)
        AssetCalendarDaySummary(
          date: DateTime(normalizedMonth.year, normalizedMonth.month, day),
          expenseTotal: expenseByDay[day] ?? 0,
          incomeTotal: incomeByDay[day] ?? 0,
          events: _sortEvents(eventsByDay[day] ?? const <AssetCalendarEvent>[]),
        ),
    ];

    return AssetPaymentCalendarMonth(
      month: normalizedMonth,
      days: days,
      weeks: _buildWeeks(normalizedMonth, days),
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
