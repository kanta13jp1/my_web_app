import '../models/asset_liability_workbook.dart';
import 'asset_cashflow_forecast_service.dart';
import 'asset_expected_inflow_store.dart';

/// 資産管理ページの状態(口座・負債・繰り返し収入テンプレ・入金ルール・固定費)から
/// [AssetCashflowForecastService.project] へ渡す入力を導出する純関数の置き場。
///
/// 元々ページの `_buildCashflowForecastCard` 内にインラインで書かれていたロジックを
/// 抽出し、build メソッドから切り離してユニットテスト可能にしたもの(振る舞いは不変)。
class AssetCashflowForecastInputs {
  const AssetCashflowForecastInputs({
    required this.startingBalance,
    required this.recurringIncome,
    required this.recurringOutflow,
    required this.oneTimeIncome,
  });

  /// 現金・預金(残高がプラスの流動資産)の合計。予測の起点残高。
  final double startingBalance;

  final List<AssetCashflowRecurringEntry> recurringIncome;
  final List<AssetCashflowRecurringEntry> recurringOutflow;
  final List<AssetCashflowDatedEntry> oneTimeIncome;

  /// いずれかの入力があるか(なければカードを出さない判定に使う)。
  bool get hasData =>
      recurringIncome.isNotEmpty ||
      recurringOutflow.isNotEmpty ||
      oneTimeIncome.isNotEmpty;

  /// ページ状態から予測入力を導出する。
  ///
  /// - 起点残高 = 現金・預金口座(`cash`/`deposit` かつ残高 > 0)の合計。
  /// - 繰り返し収入 = 繰り返し収入テンプレ + 入金ルール(日付・金額が正のもの)。
  /// - 繰り返し支出 = 直接キャッシュフロー対象の負債(残高 < 0・支払日・予定額あり)
  ///   + 固定費(subscription)。
  /// - 一時収入 = 登録済みの入金予定(金額が正のもの)。
  static AssetCashflowForecastInputs fromAssetData({
    required List<AssetLiabilityAccount> accounts,
    required List<AssetLiabilityDebtRow> debtRows,
    required List<AssetLiabilityRecurringIncomeTemplate>
        recurringIncomeTemplates,
    required List<AssetExpectedInflowRule> inflowRules,
    required List<AssetExpectedInflow> oneTimeInflows,
    required List<Map<String, dynamic>> subscriptions,
  }) {
    var startingBalance = 0.0;
    for (final account in accounts) {
      final isLiquid = account.kind == AssetLiabilityAccountKind.cash ||
          account.kind == AssetLiabilityAccountKind.deposit;
      if (isLiquid && account.balance > 0) {
        startingBalance += account.balance;
      }
    }

    final recurringIncome = <AssetCashflowRecurringEntry>[];
    final seenIncomeKeys = <String>{};

    String normalizeIncomeLabel(String label) {
      final s = label.toLowerCase().replaceAll(RegExp(r'[\s　・_\-]'), '');
      return s
          .replaceAll('給料', '給与')
          .replaceAll('給与振込', '給与')
          .replaceAll('手当', '給与')
          .replaceAll('salary', '給与');
    }

    for (final template in recurringIncomeTemplates) {
      if (template.dayOfMonth > 0 && template.amount > 0) {
        final key =
            '${template.dayOfMonth}_${normalizeIncomeLabel(template.name)}';
        seenIncomeKeys.add(key);
        recurringIncome.add(
          AssetCashflowRecurringEntry(
            dayOfMonth: template.dayOfMonth,
            amount: template.amount,
            label: template.name,
          ),
        );
      }
    }

    for (final rule in inflowRules) {
      if (rule.dayOfMonth > 0 && rule.amount > 0) {
        final key = '${rule.dayOfMonth}_${normalizeIncomeLabel(rule.label)}';
        if (!seenIncomeKeys.contains(key)) {
          seenIncomeKeys.add(key);
          recurringIncome.add(
            AssetCashflowRecurringEntry(
              dayOfMonth: rule.dayOfMonth,
              amount: rule.amount,
              label: rule.label,
            ),
          );
        }
      }
    }

    final recurringOutflow = <AssetCashflowRecurringEntry>[
      for (final row in debtRows)
        if (row.isDirectCashflowTarget &&
            row.balance < 0 &&
            (row.paymentDay ?? 0) > 0 &&
            row.scheduledPaymentAmount > 0)
          AssetCashflowRecurringEntry(
            dayOfMonth: row.paymentDay!,
            amount: row.scheduledPaymentAmount,
            label: row.name,
          ),
    ];
    for (final subscription in subscriptions) {
      final entry = subscriptionRecurringEntry(subscription);
      if (entry != null) {
        recurringOutflow.add(entry);
      }
    }

    final oneTimeIncome = <AssetCashflowDatedEntry>[
      for (final inflow in oneTimeInflows)
        if (inflow.amount > 0)
          AssetCashflowDatedEntry(
            date: inflow.date,
            amount: inflow.amount,
            label: inflow.label,
          ),
    ];

    return AssetCashflowForecastInputs(
      startingBalance: startingBalance,
      recurringIncome: recurringIncome,
      recurringOutflow: recurringOutflow,
      oneTimeIncome: oneTimeIncome,
    );
  }

  /// 固定費(subscription)1 件を繰り返し支出エントリへ変換する。
  /// 価格が無効(null/非正)なら null。支払日は due_date の日、名前が空なら「固定費」。
  static AssetCashflowRecurringEntry? subscriptionRecurringEntry(
    Map<String, dynamic> subscription,
  ) {
    final price = (subscription['price'] as num?)?.toDouble();
    if (price == null || price <= 0) {
      return null;
    }
    final dueDate = DateTime.tryParse(
      subscription['due_date']?.toString() ?? '',
    );
    final name = subscription['service_name']?.toString().trim() ?? '';
    return AssetCashflowRecurringEntry(
      dayOfMonth: dueDate?.day ?? 1,
      amount: price,
      label: name.isEmpty ? '固定費' : name,
    );
  }
}
