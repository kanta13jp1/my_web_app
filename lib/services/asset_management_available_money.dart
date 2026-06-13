import 'package:my_web_app/models/asset_liability_workbook.dart';

/// 使用可能額の内訳。ユーザー指定の式に基づく:
/// - 利用可能資産 = メインバンク残高 + 現金(財布)
/// - 給料日までの支払い予定額 = 給料日までに期日が来る「未払い」の支払い予定
/// - 今月使用可能額 = 利用可能資産 − 支払い予定額 − 安全余裕
/// - 本日使用可能額 = 今月使用可能額 ÷ 給料日までの残日数 (1日分)
/// - 今週使用可能額 = 本日使用可能額 × 今週末までの日数
class AssetManagementAvailableMoneyBreakdown {
  final double availableAssets;
  final double unpaidUntilPayday;
  final double minimumSafetyBalance;
  final int remainingDaysToPayday;
  final int daysThisWeek;
  final DateTime payday;

  const AssetManagementAvailableMoneyBreakdown({
    required this.availableAssets,
    required this.unpaidUntilPayday,
    required this.minimumSafetyBalance,
    required this.remainingDaysToPayday,
    required this.daysThisWeek,
    required this.payday,
  });

  /// 給料日までに自由に使える総額(安全余裕確保後)。今月使用可能額。
  double get disposableUntilPayday =>
      availableAssets - unpaidUntilPayday - minimumSafetyBalance;

  /// 1日あたりの使用可能額。残日数が0以下なら総額をそのまま返す。
  double get dailyAvailable => remainingDaysToPayday <= 0
      ? disposableUntilPayday
      : disposableUntilPayday / remainingDaysToPayday;

  double get todayAvailable => dailyAvailable;

  double get weekAvailable => dailyAvailable * daysThisWeek;

  double get monthAvailable => disposableUntilPayday;
}

class AssetManagementAvailableMoney {
  const AssetManagementAvailableMoney._();

  static const int defaultSalaryDay = 25;

  /// 次の給料日。today.day が給料日より前なら当月、以降なら翌月。
  static DateTime nextPayday(
    DateTime today, {
    int salaryDay = defaultSalaryDay,
  }) {
    final day = salaryDay.clamp(1, 28).toInt();
    final base = DateTime(today.year, today.month, today.day);
    if (base.day < day) {
      return DateTime(base.year, base.month, day);
    }
    return DateTime(base.year, base.month + 1, day);
  }

  /// 本日から給料日までの残日数(給料日当日は含めない / 最低1)。
  static int remainingDaysToPayday(DateTime today, DateTime payday) {
    final base = DateTime(today.year, today.month, today.day);
    final pay = DateTime(payday.year, payday.month, payday.day);
    final diff = pay.difference(base).inDays;
    return diff < 1 ? 1 : diff;
  }

  /// 本日から今週末(日曜)までの日数(本日含む / 最低1 / 残日数を上限)。
  static int daysUntilWeekEnd(DateTime today, {required int remainingDays}) {
    final base = DateTime(today.year, today.month, today.day);
    // DateTime.weekday: 月=1 .. 日=7。今週末(日)まで = 8 - weekday。
    final toSunday = 8 - base.weekday;
    final capped = toSunday > remainingDays ? remainingDays : toSunday;
    return capped < 1 ? 1 : capped;
  }

  /// メインバンク + 現金(財布)の利用可能資産。
  /// メインバンク未選択時は残高最大の預金口座を既定とする。
  static double availableAssets({
    required List<AssetLiabilityAccount> accounts,
    required String? mainAccountId,
  }) {
    final cashWalletTotal = accounts
        .where((account) => account.kind == AssetLiabilityAccountKind.cash)
        .fold<double>(0, (sum, account) => sum + account.balance);

    AssetLiabilityAccount? main;
    if (mainAccountId != null && mainAccountId.trim().isNotEmpty) {
      for (final account in accounts) {
        if (account.id == mainAccountId) {
          main = account;
          break;
        }
      }
    }
    main ??= _defaultMainAccount(accounts);

    // 既定/選択が現金口座だと現金合計と二重計上になるため除外する。
    final mainBalance =
        (main != null && main.kind != AssetLiabilityAccountKind.cash)
            ? main.balance
            : 0.0;
    return mainBalance + cashWalletTotal;
  }

  static AssetLiabilityAccount? _defaultMainAccount(
    List<AssetLiabilityAccount> accounts,
  ) {
    final deposits = accounts
        .where(
          (account) =>
              account.kind == AssetLiabilityAccountKind.deposit &&
              account.balance > 0,
        )
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
    return deposits.isEmpty ? null : deposits.first;
  }

  /// 給料日までに期日が来る「未払い」の直接支払い予定の合計。
  /// 期限超過(過去日)も未払いなら含める。
  static double unpaidUntilPayday({
    required List<AssetLiabilityCashflowRow> cashflowRows,
    required DateTime payday,
  }) {
    final pay = DateTime(payday.year, payday.month, payday.day);
    return cashflowRows
        .where(
          (row) =>
              row.isPayment &&
              !row.paid &&
              row.isDirectCashflowTarget &&
              !DateTime(
                row.paymentDate.year,
                row.paymentDate.month,
                row.paymentDate.day,
              ).isAfter(pay),
        )
        .fold<double>(0, (sum, row) => sum + row.paymentAmount);
  }
}
