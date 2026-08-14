import '../models/asset_liability_workbook.dart';

/// 支払原資が未設定の 1 支払いに対する、ルールで選んだ割当先。
class AssetBulkPaymentSourceAssignment {
  /// 原資未設定だった支払い (負債行)。
  final AssetLiabilityDebtRow row;

  /// 割当先に選ばれた現金・預金口座。
  final AssetLiabilityAccount account;

  /// この支払いを [account] から引いた後の見込み残高。
  final double projectedAfterPayment;

  const AssetBulkPaymentSourceAssignment({
    required this.row,
    required this.account,
    required this.projectedAfterPayment,
  });
}

/// 一括割当の計画 (プレビュー用)。適用前にユーザーへそのまま提示する。
class AssetBulkPaymentSourcePlan {
  /// ルールで割当先が決まった支払い。
  final List<AssetBulkPaymentSourceAssignment> assignments;

  /// 残高のある現金・預金口座が無く割当先を決められなかった支払い。
  final List<AssetLiabilityDebtRow> unassignableRows;

  const AssetBulkPaymentSourcePlan({
    required this.assignments,
    required this.unassignableRows,
  });

  bool get hasAssignments => assignments.isNotEmpty;

  bool get hasUnassignable => unassignableRows.isNotEmpty;

  /// 割当できた支払いの合計額。
  double get assignedTotal => assignments.fold<double>(
        0,
        (sum, assignment) => sum + assignment.row.scheduledPaymentAmount,
      );
}

/// 支払原資が未設定の支払いに対し、原資口座を一括で提案する。
///
/// 選定ルールは、その支払いを引いた後の**見込み残高が最大**の現金・預金口座
/// (残高 > 0) を選ぶ (特定口座名のハードコード割当より引き落とし超過リスクが低い)。
///
/// 重要: 複数の支払いを割り当てるとき、口座の見込み残高を割当のたびに**減算しながら**
/// 評価する (累積)。1 件ずつ同じ事前スナップショット残高で評価すると、全件が最大残高の
/// 同一口座に集中し、各行のプレビューは「安全」に見えるのに合計では口座がマイナスに
/// なる盲点が生じる (単一行フローは選択のたびに見込み残高が更新されるため元々安全だが、
/// 一括ではこの防御を明示的に再現する必要がある)。減算後の値でプレビューと警告
/// (安全額割れ・マイナス) を出すため、合計後の実残高が正しく反映される。
///
/// 支払いの大きい順に処理し、大きな引き落としから残高に余裕のある口座へ寄せる。
/// じぶん銀行のように預金と負債が同一 ID を持つ場合があるため、自分自身
/// (`account.id == row.id`) は割当先から必ず除外する。
class AssetBulkPaymentSourceAssigner {
  const AssetBulkPaymentSourceAssigner();

  /// 見込み残高がこの安全額を下回る割当を UI 側で警告表示するための基準。
  static const double safetyBalance = 30000;

  AssetBulkPaymentSourcePlan buildPlan(AssetLiabilityWorkbook workbook) {
    final options = workbook.accounts
        .where(
          (account) =>
              account.balance > 0 &&
              (account.kind == AssetLiabilityAccountKind.cash ||
                  account.kind == AssetLiabilityAccountKind.deposit),
        )
        .toList();

    final summariesById = <String, AssetLiabilityAccountCashflowSummary>{
      for (final summary in workbook.accountCashflowSummaries)
        summary.accountId: summary,
    };

    // 割当のたびに減算していく、口座 ID → 残り見込み残高の可変マップ。
    final runningProjected = <String, double>{
      for (final account in options)
        account.id:
            summariesById[account.id]?.projectedBalance ?? account.balance,
    };

    // 大きな支払いから先に、残高に余裕のある口座へ寄せる。
    final rows = workbook.paymentSourceMissingRows
      ..sort(
        (a, b) => b.scheduledPaymentAmount.compareTo(a.scheduledPaymentAmount),
      );

    final assignments = <AssetBulkPaymentSourceAssignment>[];
    final unassignable = <AssetLiabilityDebtRow>[];

    for (final row in rows) {
      AssetLiabilityAccount? best;
      var bestProjectedAfter = 0.0;
      for (final account in options) {
        // 自分自身への割当は不可 (同名の預金と負債が同一 ID になる罠を回避)。
        if (account.id == row.id) {
          continue;
        }
        final projectedAfter =
            runningProjected[account.id]! - row.scheduledPaymentAmount;
        // 引いた後の残高が最大 = 最も余裕のある口座。同値は先勝ちで決定論的。
        if (best == null || projectedAfter > bestProjectedAfter) {
          best = account;
          bestProjectedAfter = projectedAfter;
        }
      }
      if (best == null) {
        unassignable.add(row);
      } else {
        assignments.add(
          AssetBulkPaymentSourceAssignment(
            row: row,
            account: best,
            projectedAfterPayment: bestProjectedAfter,
          ),
        );
        // 次の割当が累積後の残高を見るよう、選んだ口座の残高を減らす。
        runningProjected[best.id] = bestProjectedAfter;
      }
    }

    return AssetBulkPaymentSourcePlan(
      assignments: assignments,
      unassignableRows: unassignable,
    );
  }
}
