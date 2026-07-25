import '../models/asset_liability_workbook.dart';

/// 不足額の根拠となる 1 明細 (引き落とし or 入金予定)。
class AssetAccountShortfallLine {
  const AssetAccountShortfallLine({
    required this.date,
    required this.name,
    required this.amount,
  });

  final DateTime date;
  final String name;

  /// 正の金額 (引き落としか入金かは所属リストで決まる)。
  final double amount;
}

/// なぜ不足するのかの診断。UI はこれに応じて修正導線を出し分ける。
enum AssetAccountShortfallCause {
  /// この口座への入金予定が無く、かつ**振込先口座が未設定の収入予定**がある。
  /// 収入自体は登録されているのに口座別資金繰りへ反映されていない状態で、
  /// 「給料は入るのに不足と出る」の最有力原因。振込先を設定すれば解消する。
  incomeDestinationUnassigned,

  /// この口座への入金予定が無く、振込先未設定の収入予定も無い。
  /// 収入予定そのものが未登録か、他口座宛て。移動が要るか収入登録が要る。
  noIncomeForAccount,

  /// この口座への入金予定はあるが、引き落としを賄いきれない。
  incomeInsufficient,
}

/// 口座の残高不足見込みについて「何が根拠でそうなったか」を組み立てた結果。
///
/// 見込み残高の式は
/// `現在残高 − 未払いの引き落とし + この口座への入金予定 + 移動入 − 移動出`
/// で、**入金予定は `destinationAccountId` がこの口座のものだけ**が数えられる。
/// そのため収入予定の振込先が未設定だと、収入があるのに口座別では不足に見える。
class AssetAccountShortfallBasis {
  const AssetAccountShortfallBasis({
    required this.accountId,
    required this.accountName,
    required this.currentBalance,
    required this.paymentLines,
    required this.incomeLines,
    required this.pendingTransferIn,
    required this.pendingTransferOut,
    required this.projectedBalance,
    required this.cause,
    required this.unassignedIncomeTotal,
    required this.unassignedIncomeNames,
  });

  final String accountId;
  final String accountName;

  /// 今この口座にある額。
  final double currentBalance;

  /// この口座から引き落とされる未払いの支払い (日付昇順)。
  final List<AssetAccountShortfallLine> paymentLines;

  /// この口座へ入る未受取の入金予定 (日付昇順)。
  final List<AssetAccountShortfallLine> incomeLines;

  final double pendingTransferIn;
  final double pendingTransferOut;

  /// 差し引き後の見込み残高 (負なら不足)。
  final double projectedBalance;

  final AssetAccountShortfallCause cause;

  /// 振込先未設定の収入予定の合計額 (原因表示用)。
  final double unassignedIncomeTotal;

  /// 同上の名称 (最大数は呼び出し側で調整)。
  final List<String> unassignedIncomeNames;

  double get paymentTotal =>
      paymentLines.fold<double>(0, (sum, line) => sum + line.amount);

  double get incomeTotal =>
      incomeLines.fold<double>(0, (sum, line) => sum + line.amount);

  double get shortfall => projectedBalance < 0 ? projectedBalance.abs() : 0;

  /// 振込先未設定の収入が解消された場合、この口座の不足が消え得るか。
  /// (全額がこの口座宛てだったと仮定した上限見積り。断定はしない)
  bool get unassignedIncomeCouldCover =>
      cause == AssetAccountShortfallCause.incomeDestinationUnassigned &&
      unassignedIncomeTotal >= shortfall;
}

/// 残高不足の根拠を組み立てる純関数サービス。
class AssetAccountShortfallBasisService {
  const AssetAccountShortfallBasisService();

  /// [accountId] の不足根拠を組み立てる。対象口座のサマリが無ければ null。
  AssetAccountShortfallBasis? buildBasis({
    required AssetLiabilityWorkbook workbook,
    required String accountId,
  }) {
    AssetLiabilityAccountCashflowSummary? summary;
    for (final candidate in workbook.accountCashflowSummaries) {
      if (candidate.accountId == accountId) {
        summary = candidate;
        break;
      }
    }
    if (summary == null) {
      return null;
    }

    // 見込み残高の計算 (_buildAccountCashflowSummaries) と同一条件で明細化する。
    // ここがずれると「根拠の合計と結論が合わない」表示になるため揃える。
    final paymentLines = <AssetAccountShortfallLine>[
      for (final row in workbook.cashflowRows)
        if (row.isPayment &&
            row.isDirectCashflowTarget &&
            !row.paid &&
            row.paymentSourceAccountId == accountId)
          AssetAccountShortfallLine(
            date: row.paymentDate,
            name: row.accountName,
            amount: row.paymentAmount,
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    final incomeLines = <AssetAccountShortfallLine>[
      for (final row in workbook.cashflowRows)
        if (row.isIncome &&
            !row.received &&
            row.destinationAccountId == accountId)
          AssetAccountShortfallLine(
            date: row.paymentDate,
            name: row.accountName,
            amount: row.paymentAmount,
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    final unassigned = workbook.unassignedDestinationIncomePlans
        .where((plan) => !plan.received)
        .toList();
    final unassignedTotal =
        unassigned.fold<double>(0, (sum, plan) => sum + plan.amount);

    final AssetAccountShortfallCause cause;
    if (incomeLines.isEmpty && unassigned.isNotEmpty) {
      cause = AssetAccountShortfallCause.incomeDestinationUnassigned;
    } else if (incomeLines.isEmpty) {
      cause = AssetAccountShortfallCause.noIncomeForAccount;
    } else {
      cause = AssetAccountShortfallCause.incomeInsufficient;
    }

    return AssetAccountShortfallBasis(
      accountId: summary.accountId,
      accountName: summary.accountName,
      currentBalance: summary.currentBalance,
      paymentLines: List.unmodifiable(paymentLines),
      incomeLines: List.unmodifiable(incomeLines),
      pendingTransferIn: summary.pendingTransferIn,
      pendingTransferOut: summary.pendingTransferOut,
      projectedBalance: summary.projectedBalance,
      cause: cause,
      unassignedIncomeTotal: unassignedTotal,
      unassignedIncomeNames: List.unmodifiable(
        unassigned.map((plan) => plan.name).toList(),
      ),
    );
  }
}
