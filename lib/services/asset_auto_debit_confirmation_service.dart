import '../models/asset_liability_workbook.dart';

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
}
