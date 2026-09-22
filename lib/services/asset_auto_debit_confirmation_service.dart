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

  /// 振替元口座の種別。与信枠 (クレカ/ショッピング枠/カードローン) は残高が常に
  /// マイナス (=利用額) になるため、資産口座とは異なる判定を行う。特定できなければ null。
  final AssetLiabilityAccountKind? sourceAccountKind;

  /// 振替元が与信枠の場合の利用限度額 (リボ払い設定の利用限度額)。リボ設定が無い、
  /// または限度額未設定の場合は null。与信枠で限度額が分からないときは判定しない。
  final double? sourceAccountCreditLimit;

  const AssetAutoDebitConfirmation({
    required this.row,
    required this.sourceAccountBalance,
    this.sourceAccountKind,
    this.sourceAccountCreditLimit,
  });

  /// 振替元口座が与信枠 (クレジットカード、ショッピング枠、カードローン、またはマイナス残高の債務枠) か。
  bool get isCreditLine {
    if (sourceAccountKind != null) {
      return _isCreditLineKind(sourceAccountKind!);
    }
    return (sourceAccountBalance ?? 0) < 0;
  }

  /// 与信枠で利用限度額を超過しているか。
  bool get isCreditLimitExceeded {
    if (!isCreditLine) return false;
    final balance = sourceAccountBalance;
    final limit = sourceAccountCreditLimit;
    if (balance == null || limit == null || limit <= 0) return false;
    return (-balance) + row.paymentAmount > limit;
  }

  /// 一括引落済み操作の対象に含められるか。
  ///
  /// - 残高不足・与信枠超過の警告が出ている行は対象外。
  /// - 与信枠で限度額が特定できない (null/0) 行は「枠超過の有無が未検証」であるため、
  ///   誤ってまとめて支払済みにしてしまうのを防ぎ、個別確認を促すため一括対象外とする。
  /// - 振替元の口座が不明 (残高 null) の行も同様に除外。
  bool get isEligibleForBulkConfirm {
    if (sourceBalanceInsufficient) return false;
    if (sourceAccountBalance == null) return false;
    if (isCreditLine &&
        (sourceAccountCreditLimit == null || sourceAccountCreditLimit! <= 0)) {
      return false;
    }
    return true;
  }

  /// 引落が失敗している可能性があるか (= 要確認の警告を出すか)。
  ///
  /// - 資産口座 (現金/預金など): 現在残高が支払額を下回るなら警告 (従来通り)。
  /// - 与信枠 (クレカ/ショッピング枠/カードローン): 残高は通常マイナス (=利用額) の
  ///   ため「残高 < 支払額」では常に誤発火する。**利用限度額が分かるときだけ**、
  ///   利用額 (= -残高) + 今回の支払額 が限度額を超える場合のみ警告する。限度額が
  ///   不明 (null/0) のときは判定できないため警告しない (= 翌月払いカード等の常時誤発火を防ぐ)。
  /// 残高を特定できない (null) 場合も警告しない。これは「失敗の確証」ではなく「要確認」
  /// のヒントであり、UI でも断定せずに案内する。
  bool get sourceBalanceInsufficient {
    return autoDebitSourceInsufficient(
      balance: sourceAccountBalance,
      kind: sourceAccountKind,
      creditLimit: sourceAccountCreditLimit,
      paymentAmount: row.paymentAmount,
    );
  }

  /// 警告文面を生成する。振替元が与信枠(限度額超過)か預金口座(残高不足)かで
  /// 理由と確認事項を明確に区別する。
  String? shortfallWarningMessage({
    required String formattedSourceBalance,
    String? formattedCreditLimit,
  }) {
    if (!sourceBalanceInsufficient) return null;
    if (isCreditLine) {
      if (formattedCreditLimit != null && formattedCreditLimit.isNotEmpty) {
        return '振替元カードの利用枠見込み(残高 $formattedSourceBalance / 限度額 $formattedCreditLimit)'
            'が利用限度額を超過しています。カード決済が承認されない可能性があるため、'
            '限度額をご確認のうえ操作してください。';
      }
      return '振替元カードの利用枠見込み(残高 $formattedSourceBalance)'
          'が利用限度額を超過しています。カード決済が承認されない可能性があるため、'
          '限度額をご確認のうえ操作してください。';
    }
    return '振替元の残高見込み($formattedSourceBalance)が支払額を下回っています。'
        '引落が失敗している可能性があるため、残高をご確認のうえ操作してください。';
  }
}

/// 「引落失敗の可能性 (= 要確認)」を振替元の種別に応じて判定する純関数。
///
/// - 資産口座 (現金/預金など) / 種別不明: 残高 < 支払額 なら true (従来通り)。
/// - 与信枠 (クレカ/ショッピング枠/カードローン): 残高は通常マイナス (=利用額) の
///   ため、利用上限 [creditLimit] が分かるときだけ「利用額 (= -残高) + 支払額 > 上限」
///   で true。上限が不明 (null/0) なら false (翌月払いカード等の常時誤発火を防ぐ)。
/// 残高 [balance] が null (特定不能) のときは判定できないため false。
bool autoDebitSourceInsufficient({
  required double? balance,
  required AssetLiabilityAccountKind? kind,
  required double? creditLimit,
  required double paymentAmount,
}) {
  if (balance == null) {
    return false;
  }
  if (kind != null && _isCreditLineKind(kind)) {
    if (creditLimit == null || creditLimit <= 0) {
      return false;
    }
    return (-balance) + paymentAmount > creditLimit;
  }
  // If kind is null or unknown but balance is negative, it represents a credit
  // line or debt account. Do not trigger cash shortfall warnings on negative balances
  // unless credit limit is specified and exceeded.
  if (balance < 0) {
    if (creditLimit != null && creditLimit > 0) {
      return (-balance) + paymentAmount > creditLimit;
    }
    return false;
  }
  return balance < paymentAmount;
}

/// 残高が通常マイナス (=利用額) になる与信枠の口座種別か。これらは「残高 < 支払額」
/// では常に警告が出てしまうため、利用限度額ベースで引落可否を判定する。
bool _isCreditLineKind(AssetLiabilityAccountKind kind) {
  return kind == AssetLiabilityAccountKind.creditCard ||
      kind == AssetLiabilityAccountKind.shoppingDebt ||
      kind == AssetLiabilityAccountKind.cardLoan;
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
              row.isPayment &&
              row.overdue &&
              row.paymentDate.isBefore(today) &&
              // 振替元 (支払原資) 未設定の行は除外する。残高が特定できず引落
              // 成否を判定できない上、これらは「支払原資口座が未設定」バナーで
              // 別途修正導線が出るため、確認待ちに重複表示すると同じ行が 2 箇所に
              // 並ぶ。原資を設定すれば次回から確認待ちに (残高判定付きで) 現れる。
              (row.paymentSourceAccountId?.trim().isNotEmpty ?? false),
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
  ///
  /// 同一口座から複数の確認待ちがある場合、`sourceAccountBalance` は
  /// 「その行の引落前の見込み残高」= 現在残高から、引落日が先で **成功し得る**
  /// 引落だけを順次差し引いた値になる (残高不足で弾かれる引落は実際には残高を
  /// 減らさないため差し引かない)。行単位で生残高と独立比較すると
  /// 「個別には足りるが合計では足りない」ケースを取りこぼすため (part338 教訓)。
  static AssetLiabilityAccount? _resolveSourceAccount(
    String? sourceAccountId,
    Map<String, AssetLiabilityAccount> accountById,
  ) {
    if (sourceAccountId == null || sourceAccountId.trim().isEmpty) return null;
    final direct = accountById[sourceAccountId];
    if (direct != null) return direct;
    final normalizedTarget = sourceAccountId.trim().toLowerCase();
    for (final account in accountById.values) {
      if (account.id.toLowerCase() == normalizedTarget ||
          account.name.trim().toLowerCase() == normalizedTarget) {
        return account;
      }
    }
    return null;
  }

  List<AssetAutoDebitConfirmation> pendingConfirmationDetails(
    AssetLiabilityWorkbook workbook,
  ) {
    final accountById = <String, AssetLiabilityAccount>{
      for (final account in workbook.accounts) account.id: account,
    };
    // 与信枠の利用限度額はリボ払い設定 (revolvingBilling) から取得する。
    final creditLimitByAccountId = <String, double>{
      for (final debt in workbook.debtMasterRows)
        if (debt.revolvingBilling != null)
          debt.id: debt.revolvingBilling!.creditLimit,
    };
    final rows = pendingConfirmations(workbook);
    final effectiveBalanceByRowId = _effectiveSourceBalances(
      rows: rows,
      accountById: accountById,
      creditLimitByAccountId: creditLimitByAccountId,
    );
    final details = rows.map((row) {
      final sourceAccountId = row.paymentSourceAccountId;
      final source = _resolveSourceAccount(sourceAccountId, accountById);
      return AssetAutoDebitConfirmation(
        row: row,
        sourceAccountBalance: effectiveBalanceByRowId.containsKey(row.accountId)
            ? effectiveBalanceByRowId[row.accountId]
            : source?.balance,
        sourceAccountKind: source?.kind,
        sourceAccountCreditLimit: sourceAccountId == null
            ? null
            : creditLimitByAccountId[sourceAccountId],
      );
    }).toList();
    return List<AssetAutoDebitConfirmation>.unmodifiable(details);
  }

  /// 口座毎に引落日昇順で「成功し得る引落」を残高から順次差し引き、
  /// 各行の「引落前の見込み残高」を row.accountId → 残高 で返す
  /// (確認待ちは 1 口座 1 行なので accountId で一意)。
  ///
  /// - 資産口座: 見込み残高 >= 支払額 の引落だけ残高から差し引く
  ///   (不足で弾かれる引落は残高を減らさない)。
  /// - 与信枠: 同様に、限度額内に収まる引落だけ利用額へ積む
  ///   (見込み残高はマイナスの利用額としてそのまま表現できる)。
  /// 振替元口座がスナップショットに無い行は対象外 (raw 値のまま)。
  Map<String, double> _effectiveSourceBalances({
    required List<AssetLiabilityCashflowRow> rows,
    required Map<String, AssetLiabilityAccount> accountById,
    required Map<String, double> creditLimitByAccountId,
  }) {
    final rowsBySource = <String, List<AssetLiabilityCashflowRow>>{};
    for (final row in rows) {
      final sourceAccountId = row.paymentSourceAccountId;
      if (sourceAccountId == null) continue;
      final source = accountById[sourceAccountId];
      if (source == null) continue;
      rowsBySource.putIfAbsent(sourceAccountId, () => []).add(row);
    }

    final effective = <String, double>{};
    rowsBySource.forEach((sourceAccountId, sourceRows) {
      final source = accountById[sourceAccountId]!;
      final creditLimit = creditLimitByAccountId[sourceAccountId];
      // 引落は日付順に口座へ到達する。表示順 (金額降順) とは独立に計算する。
      final ordered = [...sourceRows]..sort((a, b) {
          final byDate = a.paymentDate.compareTo(b.paymentDate);
          if (byDate != 0) return byDate;
          return b.paymentAmount.compareTo(a.paymentAmount);
        });
      var remaining = source.balance;
      for (final row in ordered) {
        effective[row.accountId] = remaining;
        final wouldSucceed = !autoDebitSourceInsufficient(
          balance: remaining,
          kind: source.kind,
          creditLimit: creditLimit,
          paymentAmount: row.paymentAmount,
        );
        if (wouldSucceed) {
          remaining -= row.paymentAmount;
        }
      }
    });
    return effective;
  }

  /// 振替元残高が支払額を下回っている (= 引落が失敗している可能性がある) 確認待ちの件数。
  int insufficientSourceCount(AssetLiabilityWorkbook workbook) {
    return pendingConfirmationDetails(
      workbook,
    ).where((detail) => detail.sourceBalanceInsufficient).length;
  }
}

/// 引落が失敗し別の振替元 ([sourceName]) で支払ったと記録したときに表示する案内文。
/// 残高は自動変更しないため、ユーザーに実残高への反映を促す ([formattedAmount] は
/// 表示用に整形済みの金額文字列)。
String autoDebitAlternateSourcePaidHint(
  String sourceName,
  String formattedAmount,
) {
  return '$sourceName を振替元に記録しました。'
      '残高一覧で $sourceName の残高に $formattedAmount を反映してください。';
}
