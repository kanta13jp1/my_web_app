import '../models/asset_liability_workbook.dart';

/// 1 か月分のキャッシュフロー (収入 − 支出) を表すビュー。
///
/// [income] が null の月は収入が未追跡 (旧スナップショット / Supabase 同期分)
/// であり、支出だけを 0 円収入とみなすと赤字に倒れて誤誘導になるため、
/// [cashflow] も null を返し、累積・黒字/赤字カウントから除外される。
class AssetCashflowMonth {
  /// `yyyy-MM` 形式。
  final String monthKey;

  /// その月に受領済みとなった収入合計。null = 未追跡。
  final double? income;

  /// その月に実際に支払った支出合計 (paid payment total)。
  final double expense;

  /// その月時点の純資産 (B/S)。null = 未追跡。
  final double? netWorth;

  /// 前月からの純資産増減 (当月純資産 - 前月純資産)。前月または当月が未追跡なら null。
  final double? netWorthDelta;

  const AssetCashflowMonth({
    required this.monthKey,
    required this.income,
    required this.expense,
    this.netWorth,
    this.netWorthDelta,
  });

  /// 収入が追跡されているか (0 円でも追跡済みなら true)。
  bool get hasIncome => income != null;

  /// 当月キャッシュフロー。収入未追跡なら null。
  double? get cashflow => income == null ? null : income! - expense;

  /// 黒字 (CF >= 0)。未追跡月は false。
  bool get isSurplus {
    final value = cashflow;
    return value != null && value >= 0;
  }

  /// 赤字 (CF < 0)。未追跡月は false。
  bool get isDeficit {
    final value = cashflow;
    return value != null && value < 0;
  }

  int get year => int.tryParse(monthKey.split('-').first) ?? 0;
}

/// キャッシュフローパネル (Issue #2474) の集計結果。
class AssetCashflowStatement {
  /// monthKey 昇順。
  final List<AssetCashflowMonth> months;

  /// asOf の当月 (存在する場合)。
  final AssetCashflowMonth? currentMonth;

  /// 年初来 (同一暦年・当月まで) の累積キャッシュフロー。追跡済み月のみ加算。
  final double yearToDateCashflow;

  /// 年初来で収入が追跡されていた月数。
  final int yearToDateTrackedMonths;

  /// 年初来で収入が未追跡だった月数 (= 累積から除外した月数)。
  final int yearToDateUntrackedMonths;

  /// 直近ウィンドウ内で黒字だった月数。
  final int surplusMonthCount;

  /// 直近ウィンドウ内で赤字だった月数。
  final int deficitMonthCount;

  /// 直近ウィンドウ内で収入が追跡されていた月数 (= surplus + deficit)。
  final int trackedMonthCount;

  /// 黒字/赤字カウントの対象ウィンドウ月数 (既定 12)。
  final int windowMonths;

  const AssetCashflowStatement({
    required this.months,
    required this.currentMonth,
    required this.yearToDateCashflow,
    required this.yearToDateTrackedMonths,
    required this.yearToDateUntrackedMonths,
    required this.surplusMonthCount,
    required this.deficitMonthCount,
    required this.trackedMonthCount,
    required this.windowMonths,
  });

  static const AssetCashflowStatement empty = AssetCashflowStatement(
    months: <AssetCashflowMonth>[],
    currentMonth: null,
    yearToDateCashflow: 0,
    yearToDateTrackedMonths: 0,
    yearToDateUntrackedMonths: 0,
    surplusMonthCount: 0,
    deficitMonthCount: 0,
    trackedMonthCount: 0,
    windowMonths: AssetCashflowStatementService.trailingWindowMonths,
  );

  double? get currentMonthCashflow => currentMonth?.cashflow;

  bool get hasCurrentMonthCashflow => currentMonth?.hasIncome ?? false;

  bool get hasData => currentMonth != null || months.isNotEmpty;

  /// 年初来に収入未追跡の月が含まれているか (UI の注意書き用)。
  bool get hasUntrackedYearToDateMonths => yearToDateUntrackedMonths > 0;
}

/// 月次スナップショットから決定論的にキャッシュフローパネルを組み立てる純サービス。
///
/// - 金額計算はすべてローカルで deterministic に行い、AI は関与しない。
/// - 収入が未追跡 (null) の月は月次CF・累積・黒字/赤字カウントから除外し、
///   支出だけを 0 円収入とみなして赤字に倒すことを防ぐ。
class AssetCashflowStatementService {
  const AssetCashflowStatementService();

  /// 黒字/赤字カウントの対象とする直近月数。
  static const int trailingWindowMonths = 12;

  /// [snapshots] (履歴) と、任意で [currentMonthSnapshot] (ライブの当月; 未保存でも
  /// 反映するため別引数) からキャッシュフローパネルを構築する。
  ///
  /// [currentMonthSnapshot] は同一 monthKey の履歴スナップショットより優先される
  /// (ライブの方が新しいため)。
  AssetCashflowStatement build({
    required List<AssetLiabilityMonthlySnapshot> snapshots,
    AssetLiabilityMonthlySnapshot? currentMonthSnapshot,
    required DateTime asOf,
  }) {
    final rawMonthData =
        <String, ({double? income, double expense, double? netWorth})>{};
    for (final snapshot in snapshots) {
      final key = snapshot.monthKey.trim();
      if (key.isEmpty) {
        continue;
      }
      rawMonthData[key] = (
        income: snapshot.monthlyReceivedIncomeTotal,
        expense: snapshot.monthlyPaidPaymentTotal,
        netWorth: snapshot.netWorth,
      );
    }

    final currentMonthKey = _formatMonthKey(asOf);
    if (currentMonthSnapshot != null) {
      final key = currentMonthSnapshot.monthKey.trim().isEmpty
          ? currentMonthKey
          : currentMonthSnapshot.monthKey.trim();
      rawMonthData[key] = (
        income: currentMonthSnapshot.monthlyReceivedIncomeTotal,
        expense: currentMonthSnapshot.monthlyPaidPaymentTotal,
        netWorth: currentMonthSnapshot.netWorth,
      );
    }

    final sortedKeys = rawMonthData.keys.toList()..sort();
    final months = <AssetCashflowMonth>[];
    final byMonth = <String, AssetCashflowMonth>{};
    double? previousNetWorth;

    for (final key in sortedKeys) {
      final data = rawMonthData[key]!;
      double? delta;
      if (data.netWorth != null && previousNetWorth != null) {
        delta = data.netWorth! - previousNetWorth;
      }
      previousNetWorth = data.netWorth;

      final month = AssetCashflowMonth(
        monthKey: key,
        income: data.income,
        expense: data.expense,
        netWorth: data.netWorth,
        netWorthDelta: delta,
      );
      months.add(month);
      byMonth[key] = month;
    }

    final currentMonth = byMonth[currentMonthKey];

    // 年初来累積 (同一暦年・当月まで)。
    var ytdCashflow = 0.0;
    var ytdTracked = 0;
    var ytdUntracked = 0;
    for (final month in months) {
      if (month.year != asOf.year) {
        continue;
      }
      if (month.monthKey.compareTo(currentMonthKey) > 0) {
        continue; // 未来月は除外 (安全側)。
      }
      if (month.hasIncome) {
        ytdCashflow += month.cashflow!;
        ytdTracked += 1;
      } else {
        ytdUntracked += 1;
      }
    }

    // 直近ウィンドウの黒字/赤字カウント。
    final windowStartKey = _formatMonthKey(
      DateTime(asOf.year, asOf.month - (trailingWindowMonths - 1)),
    );
    var surplus = 0;
    var deficit = 0;
    var tracked = 0;
    for (final month in months) {
      if (month.monthKey.compareTo(windowStartKey) < 0) {
        continue;
      }
      if (month.monthKey.compareTo(currentMonthKey) > 0) {
        continue;
      }
      if (!month.hasIncome) {
        continue;
      }
      tracked += 1;
      if (month.isSurplus) {
        surplus += 1;
      } else {
        deficit += 1;
      }
    }

    return AssetCashflowStatement(
      months: months,
      currentMonth: currentMonth,
      yearToDateCashflow: ytdCashflow,
      yearToDateTrackedMonths: ytdTracked,
      yearToDateUntrackedMonths: ytdUntracked,
      surplusMonthCount: surplus,
      deficitMonthCount: deficit,
      trackedMonthCount: tracked,
      windowMonths: trailingWindowMonths,
    );
  }

  static String _formatMonthKey(DateTime date) {
    final normalized = DateTime(date.year, date.month);
    final month = normalized.month.toString().padLeft(2, '0');
    return '${normalized.year}-$month';
  }
}
