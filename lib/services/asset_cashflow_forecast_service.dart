import 'dart:math';

/// 繰り返し(毎月)発生する収入・支出の1項目。
/// [dayOfMonth] はその月の入金日 / 支払日(月末超過は丸める)。
class AssetCashflowRecurringEntry {
  const AssetCashflowRecurringEntry({
    required this.dayOfMonth,
    required this.amount,
    this.label = '',
  });

  final int dayOfMonth;
  final double amount;
  final String label;
}

/// 特定日に1回だけ発生する収入・支出の1項目。
class AssetCashflowDatedEntry {
  const AssetCashflowDatedEntry({
    required this.date,
    required this.amount,
    this.label = '',
  });

  final DateTime date;
  final double amount;
  final String label;
}

/// 予測1ヶ月分のサマリ。
class AssetCashflowForecastMonth {
  const AssetCashflowForecastMonth({
    required this.month,
    required this.openingBalance,
    required this.closingBalance,
    required this.worstBalance,
    required this.incomeTotal,
    required this.outflowTotal,
    this.firstShortfallDate,
  });

  /// 対象月(1日0時)。
  final DateTime month;

  /// 月初(=前月末)の見込み残高。
  final double openingBalance;

  /// 月末の見込み残高。
  final double closingBalance;

  /// 月内の見込み残高の最小値。
  final double worstBalance;

  final double incomeTotal;
  final double outflowTotal;

  /// 月内で最初に残高が 0 未満へ落ちる日。なければ null。
  final DateTime? firstShortfallDate;

  bool get isShortfall => worstBalance < 0;

  double get netChange => closingBalance - openingBalance;
}

/// 「今日起点・Nヶ月先」までの前方残高予測の結果。
class AssetCashflowForecast {
  const AssetCashflowForecast({
    required this.asOf,
    required this.startingBalance,
    required this.months,
    required this.worstBalance,
    required this.safetyMargin,
    this.firstShortfallDate,
  });

  final DateTime asOf;
  final double startingBalance;
  final List<AssetCashflowForecastMonth> months;

  /// 全期間を通じた見込み残高の最小値。
  final double worstBalance;

  /// 安全余裕(見込み残高がこれを下回ると注意。0 なら 0 円ライン)。
  final double safetyMargin;

  /// 見込み残高が最初に 0 未満へ落ちる日。なければ null。
  final DateTime? firstShortfallDate;

  bool get isEmpty => months.isEmpty;

  bool get hasShortfall => firstShortfallDate != null;

  /// ショート回避に必要な追加資金(=最大不足幅)。ショートなしなら 0。
  double get shortfallRecoveryAmount => worstBalance < 0 ? -worstBalance : 0;

  /// 安全余裕を割り込む不足額(安全線維持に必要な額)。ショートなしでも > 0 になりうる。
  double get safetyShortfallAmount =>
      worstBalance < safetyMargin ? safetyMargin - worstBalance : 0;
}

/// 既存の単月 [AssetPaymentCalendarService.buildMonth] を「今日起点・Nヶ月先」
/// の前方残高予測へ拡張する純関数サービス。
///
/// 各月で繰り返し収入/支出と一時収入/支出を日付順に積み上げ、月末残高を
/// 翌月へ繰り越す。当月(m==0)は基準日より前の予定を二重計上しないよう
/// 基準日以降のイベントのみ計上する。スキーマ非依存で完全にテスト可能。
class AssetCashflowForecastService {
  const AssetCashflowForecastService();

  static const double _epsilon = 0.01;

  /// 月の日数を超える日を月末へ丸める(2月の31日指定など)。
  static int _clampDay(int day, DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return max(1, min(day, lastDay));
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static AssetCashflowForecast project({
    required DateTime asOf,
    required double startingBalance,
    int horizonMonths = 6,
    List<AssetCashflowRecurringEntry> recurringIncome =
        const <AssetCashflowRecurringEntry>[],
    List<AssetCashflowRecurringEntry> recurringOutflow =
        const <AssetCashflowRecurringEntry>[],
    List<AssetCashflowDatedEntry> oneTimeIncome =
        const <AssetCashflowDatedEntry>[],
    List<AssetCashflowDatedEntry> oneTimeOutflow =
        const <AssetCashflowDatedEntry>[],
    double safetyMargin = 0,
  }) {
    final anchor = DateTime(asOf.year, asOf.month, asOf.day);
    final horizon = max(1, horizonMonths);
    var running = startingBalance;
    var worstBalance = startingBalance;
    DateTime? firstShortfallDate;
    final months = <AssetCashflowForecastMonth>[];

    for (var m = 0; m < horizon; m++) {
      final monthStart = DateTime(asOf.year, asOf.month + m, 1);
      final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
      final opening = running;
      var incomeTotal = 0.0;
      var outflowTotal = 0.0;
      var worstInMonth = running;
      DateTime? monthShortfall;

      for (var day = 1; day <= lastDay; day++) {
        final date = DateTime(monthStart.year, monthStart.month, day);
        if (m == 0 && date.isBefore(anchor)) {
          continue;
        }
        var dayIn = 0.0;
        var dayOut = 0.0;
        for (final entry in recurringIncome) {
          if (entry.amount > _epsilon &&
              _clampDay(entry.dayOfMonth, monthStart) == day) {
            dayIn += entry.amount;
          }
        }
        for (final entry in recurringOutflow) {
          if (entry.amount > _epsilon &&
              _clampDay(entry.dayOfMonth, monthStart) == day) {
            dayOut += entry.amount;
          }
        }
        for (final entry in oneTimeIncome) {
          if (entry.amount > _epsilon && _isSameDate(entry.date, date)) {
            dayIn += entry.amount;
          }
        }
        for (final entry in oneTimeOutflow) {
          if (entry.amount > _epsilon && _isSameDate(entry.date, date)) {
            dayOut += entry.amount;
          }
        }
        if (dayIn == 0 && dayOut == 0) {
          continue;
        }
        running += dayIn - dayOut;
        incomeTotal += dayIn;
        outflowTotal += dayOut;
        if (running < worstInMonth) {
          worstInMonth = running;
        }
        if (running < worstBalance) {
          worstBalance = running;
        }
        if (firstShortfallDate == null && running < 0) {
          firstShortfallDate = date;
        }
        if (monthShortfall == null && running < 0) {
          monthShortfall = date;
        }
      }

      months.add(
        AssetCashflowForecastMonth(
          month: monthStart,
          openingBalance: opening,
          closingBalance: running,
          worstBalance: worstInMonth,
          incomeTotal: incomeTotal,
          outflowTotal: outflowTotal,
          firstShortfallDate: monthShortfall,
        ),
      );
    }

    return AssetCashflowForecast(
      asOf: anchor,
      startingBalance: startingBalance,
      months: months,
      worstBalance: worstBalance,
      safetyMargin: safetyMargin,
      firstShortfallDate: firstShortfallDate,
    );
  }
}
