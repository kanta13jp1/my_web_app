import '../models/asset_liability_workbook.dart';

/// 確認待ちの支払いと、その引落の振替元口座の残高状況。
///
/// 振替元の現在残高が支払額を下回っている場合、引落が失敗している(残高不足で
/// 弾かれた)可能性があるため、ユーザーに早期に気付かせるためのフラグを持つ。
class AssetAutoDebitConfirmation {
  /// 確認待ちの支払い行。
  final AssetLiabilityCashflowRow row;

  /// 引落の振替元口座の現在残高。振替元が未設定、またはスナップショットに
  /// 該当口座が無く残高を特定できない場合は null。
  final double? sourceAccountBalance;

  const AssetAutoDebitConfirmation({
    required this.row,
    required this.sourceAccountBalance,
  });

  /// 振替元残高が判明しており、かつ支払額を下回っている = 引落が失敗している可能性。
  ///
  /// 残高を特定できない (null) 場合は判定できないため false を返す (過剰警告を避ける)。
  /// なお現在残高は引落成功後の減算を反映していることもあるため、これは「失敗の確証」
  /// ではなく「要確認」のヒントであり、UI でもその旨を断定せずに案内する。
  bool get sourceBalanceInsufficient =>
      sourceAccountBalance != null && sourceAccountBalance! < row.paymentAmount;
}

/// 「支払日を過ぎたが、まだ支払済み確認をしていない直接支払い(口座振替など)」を
/// 抽出する純関数サービス。
///
/// これらの支払いは未払い扱いのまま見込み残高から差し引かれる。実際には自動
/// 口座振替で既に引落済みのことが多く、その場合は現在の口座残高に既に反映されて
/// いるため、二重に差し引かれて残高予測が過度に悲観的になる。一方で、残高不足で
/// 引落が失敗している可能性もあるため、自動的に「支払済み」にはせず、ユーザーに
/// 「引落されましたか?」と確認させて確定する(確認したら現在残高に反映済みとして扱う)。
class AssetAutoDebitConfirmationService {
  const AssetAutoDebitConfirmationService();

  /// 確認待ちの支払い行(支払日が baseDate より前=厳密に過去・直接支払い対象・未払い)。
  ///
  /// `overdue` フラグ自体が「直接支払い対象 かつ 未払い かつ 支払日<=本日」を表すため、
  /// それに「本日より前(本日分は引落が未確定なので除外)」の条件を重ねる。
  /// 金額の大きい順に並べる。
  List<AssetLiabilityCashflowRow> pendingConfirmations(
    AssetLiabilityWorkbook workbook,
  ) {
    final today = DateTime(
      workbook.baseDate.year,
      workbook.baseDate.month,
      workbook.baseDate.day,
    );
    final rows = workbook.cashflowRows
        .where(
          (row) =>
              row.isPayment && row.overdue && row.paymentDate.isBefore(today),
        )
        .toList();
    rows.sort((a, b) => b.paymentAmount.compareTo(a.paymentAmount));
    return List<AssetLiabilityCashflowRow>.unmodifiable(rows);
  }

  /// 確認待ち支払いの合計額(見込み残高から二重控除され得る金額)。
  double pendingTotal(AssetLiabilityWorkbook workbook) {
    return pendingConfirmations(
      workbook,
    ).fold<double>(0, (sum, row) => sum + row.paymentAmount);
  }

  /// 確認待ち支払いそれぞれに、引落の振替元口座の残高状況を添えて返す。
  ///
  /// 振替元口座は `paymentSourceAccountId` でワークブックの口座一覧を引いて残高を
  /// 特定する。振替元が未設定、または該当口座がスナップショットに無い場合は残高を
  /// null とし、引落失敗の判定は行わない (= 警告を出さない安全側)。
  /// 並び順は [pendingConfirmations] と同じ (金額の大きい順)。
  List<AssetAutoDebitConfirmation> pendingConfirmationDetails(
    AssetLiabilityWorkbook workbook,
  ) {
    final balanceByAccountId = <String, double>{
      for (final account in workbook.accounts) account.id: account.balance,
    };
    final details = pendingConfirmations(workbook).map((row) {
      final sourceAccountId = row.paymentSourceAccountId;
      return AssetAutoDebitConfirmation(
        row: row,
        sourceAccountBalance: sourceAccountId == null
            ? null
            : balanceByAccountId[sourceAccountId],
      );
    }).toList();
    return List<AssetAutoDebitConfirmation>.unmodifiable(details);
  }

  /// 振替元残高が支払額を下回っている (= 引落が失敗している可能性がある) 確認待ちの件数。
  int insufficientSourceCount(AssetLiabilityWorkbook workbook) {
    return pendingConfirmationDetails(
      workbook,
    ).where((detail) => detail.sourceBalanceInsufficient).length;
  }
}
