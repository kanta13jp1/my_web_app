import '../models/asset_liability_workbook.dart';
import '../models/user_profile.dart';
import 'asset_debt_discipline_monitor.dart';

/// トリアージステップの種別。
enum AssetTriageStepKind {
  /// 今日: 食費・移動費など最低限の生活費を確保する。
  secureLivingExpense,

  /// 今日: 本日期日の支払いの原資を確認する。
  dueTodayPayment,

  /// 今日: カードの新規利用を止める（財布から抜く）。
  stopNewCardUsage,

  /// 今週: 期限超過の支払いを上から処理する。
  processOverdue,

  /// 今週: リボ/分割の設定解除を支払先へ電話する。
  disableRevolving,

  /// 今月: 脱却プランを見て返済ペースを決める。
  reviewRepaymentPace,

  /// 今月: 支払予定と収入の差を固定費見直しで埋める。
  closeIncomeGap,
}

/// 1 ステップ。金額・口座名はすべて Dart 側で計算済みの確定値。
class AssetTriageStep {
  final AssetTriageStepKind kind;
  final String title;
  final String detail;

  const AssetTriageStep({
    required this.kind,
    required this.title,
    required this.detail,
  });
}

/// 「まず、これだけ」段階別トリアージ計画。
///
/// 数字が多く混乱している利用者向けに、今日 (最大3件)・今週・今月の順で
/// やることを絞って提示する。全ステップ決定論的 (calculation_owner:
/// dart_service)。AI は文面の言い換えのみ。
class AssetTriagePlan {
  /// 今日やること (最大 [AssetTriageGuideService.maxTodaySteps] 件)。
  final List<AssetTriageStep> todaySteps;
  final List<AssetTriageStep> weekSteps;
  final List<AssetTriageStep> monthSteps;

  /// 専門窓口 (法テラス等) の案内を出すべき負債水準か。
  final bool showConsultation;

  /// 専門窓口案内の本文 (showConsultation=true のときのみ非 null)。
  final String? consultationNote;

  const AssetTriagePlan({
    required this.todaySteps,
    required this.weekSteps,
    required this.monthSteps,
    required this.showConsultation,
    this.consultationNote,
  });

  /// 免責: アプリは FP・弁護士ではない。UI とプロンプトの双方で明示する。
  static const String disclaimer =
      '本アプリはファイナンシャルプランナー・弁護士ではありません。アプリ内の数値に基づく優先順位の整理です。';

  /// 今日のステップを締める一文。「全部やらなくていい」ことを明示する。
  static const String todayClosingNote = '今日はこれで終わりです。それ以上やらなくていいです。';

  /// 表示すべき内容が 1 つでもあるか。
  bool get hasContent =>
      todaySteps.isNotEmpty ||
      weekSteps.isNotEmpty ||
      monthSteps.isNotEmpty ||
      showConsultation;

  List<AssetTriageStep> get allSteps => <AssetTriageStep>[
        ...todaySteps,
        ...weekSteps,
        ...monthSteps,
      ];
}

/// 資産管理レポートの計算結果から段階別トリアージ計画を組み立てる。
///
/// 優先順位の設計原則: ①生活費 (健康) → ②本日期日 → ③止血 (新規利用停止)
/// → ④期限超過の処理 → ⑤リボ解除 → ⑥返済ペース → ⑦収支ギャップ。
/// 「増やさない」を「返す」より先に置く。
class AssetTriageGuideService {
  const AssetTriageGuideService();

  /// 今日のステップ上限。多いと逆に動けなくなるため 3 で固定。
  static const int maxTodaySteps = 3;

  /// 手元現金がこの額を下回ったら生活費確保を最優先ステップにする。
  static const double livingExpenseCashThreshold = 10000;

  /// 専門窓口案内を出す負債合計の絶対閾値。
  static const double consultationDebtThreshold = 3000000;

  /// 年収が分かる場合、負債が年収のこの割合を超えたら専門窓口案内を出す。
  static const double consultationDebtIncomeRatio = 0.5;

  AssetTriagePlan buildPlan({
    required AssetLiabilityWorkbook workbook,
    AssetDebtDisciplineReport? disciplineReport,
    double todayAvailableAmount = 0,
    UserProfile? userProfile,
  }) {
    final today = _dateOnly(workbook.baseDate);
    final todaySteps = <AssetTriageStep>[];
    final weekSteps = <AssetTriageStep>[];
    final monthSteps = <AssetTriageStep>[];

    // ① 生活費確保 (健康を削らない)。
    final cashOnHand = workbook.accounts
        .where(
          (account) =>
              account.kind == AssetLiabilityAccountKind.cash &&
              account.balance > 0,
        )
        .fold<double>(0, (sum, account) => sum + account.balance);
    if (cashOnHand < livingExpenseCashThreshold || todayAvailableAmount < 0) {
      AssetLiabilityAccount? largestDeposit;
      for (final account in workbook.accounts) {
        if (account.kind != AssetLiabilityAccountKind.deposit ||
            account.balance <= 0) {
          continue;
        }
        if (largestDeposit == null ||
            account.balance > largestDeposit.balance) {
          largestDeposit = account;
        }
      }
      final reason = cashOnHand < livingExpenseCashThreshold
          ? '手元現金が${_yen(cashOnHand)}しかありません。'
          : '本日の使用可能額が${_yen(todayAvailableAmount)}です。';
      todaySteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.secureLivingExpense,
          title: '食費・移動費を確保する',
          detail: largestDeposit == null
              ? '$reason現金・預金に余力がないため、今日の食費は家族・自治体・'
                  'フードバンク等への相談も選択肢にしてください。食事を抜く判断はしないでください。'
              : '$reason${largestDeposit.name}（残高 ${_yen(largestDeposit.balance)}）から'
                  '1〜2万円を下ろして今日の食費・移動費を確保してください。'
                  '食事を抜く判断はしないでください。',
        ),
      );
    }

    // ② 本日期日の支払い。
    final dueTodayRows = workbook.cashflowRows
        .where(
          (row) =>
              row.isPayment &&
              row.isDirectCashflowTarget &&
              !row.paid &&
              _dateOnly(row.paymentDate) == today,
        )
        .toList()
      ..sort((a, b) => b.paymentAmount.compareTo(a.paymentAmount));
    if (dueTodayRows.isNotEmpty) {
      final total = dueTodayRows.fold<double>(
        0,
        (sum, row) => sum + row.paymentAmount,
      );
      final first = dueTodayRows.first;
      final others = dueTodayRows.length - 1;
      todaySteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.dueTodayPayment,
          title: '本日期日の支払いを確認する',
          detail: '本日期日は${first.accountName} ${_yen(first.paymentAmount)}'
              '${others > 0 ? ' ほか$others件（合計 ${_yen(total)}）' : ''}です。'
              '引落口座の残高が足りているか確認し、不足なら生活費とは別に移してください。',
        ),
      );
    }

    // ③ 止血: カードの新規利用を止める (返済より先)。
    final discipline = disciplineReport;
    if (discipline != null && discipline.hasViolations) {
      final names = <String>{
        for (final violation in discipline.allViolations)
          violation.accountName,
      }.take(3).join('・');
      final newBorrowingNote = discipline.totalNewBorrowing > 0
          ? '今月すでに約${_yen(discipline.totalNewBorrowing)}の新規利用があります。'
          : '残高が翌月へ繰り越され利息が発生しています。';
      todaySteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.stopNewCardUsage,
          title: 'カードを財布から抜く',
          detail: '$namesを今日から使わないでください。$newBorrowingNote'
              '「増やさない」が返済より先です。支払いは現金かデビットに切り替えてください。',
        ),
      );
    }

    // 今日のステップは最大 3 件 (多いと動けなくなる)。溢れた分は翌日以降に回る。
    final cappedToday = todaySteps.take(maxTodaySteps).toList();

    // ④ 期限超過の処理 (放置だけが最悪)。
    final overdueRows = workbook.overdueCashflowRows;
    if (overdueRows.isNotEmpty) {
      final total = overdueRows.fold<double>(
        0,
        (sum, row) => sum + row.paymentAmount,
      );
      weekSteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.processOverdue,
          title: '期限超過リストを上から処理する',
          detail: '期限超過が${overdueRows.length}件（合計 ${_yen(total)}）あります。'
              '各項目の「次の一手」に従って払えるものから払い、払えないものは放置せず'
              '支払先へ電話して支払日の再約束か分割の相談をしてください。放置だけが最悪の選択です。',
        ),
      );
    }

    // ⑤ リボ/分割の設定解除 (全額返済は不要、増やさない設定が目的)。
    final revolving = discipline?.revolvingCardViolations ??
        const <AssetDebtDisciplineViolation>[];
    if (revolving.isNotEmpty) {
      final names = revolving
          .map((violation) => violation.accountName)
          .take(4)
          .join('・');
      weekSteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.disableRevolving,
          title: 'リボ/分割の設定解除を電話する',
          detail: '$namesに電話し、今後の利用分の支払い方式を一括（1回払い）に'
              '変更してください。残高を今すぐ全額返す必要はありません。'
              '「これ以上リボが増えない設定」にすることが目的です。',
        ),
      );
    }

    // ⑥ 返済ペースを脱却プランで決める (金利の高い順)。
    final planned = revolving
        .where((violation) => violation.hasEscapePlan)
        .toList();
    if (planned.isNotEmpty) {
      final top = planned.first;
      monthSteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.reviewRepaymentPace,
          title: '返済ペースを宣言モニターで決める',
          detail: '宣言モニターの「${top.escapeMonths}ヶ月脱却の月額」を見て、'
              '金利の高いカードから月の返済額を決めてください。'
              '例: ${top.accountName}は月${_yen(top.escapeMonthlyPayment!)}を'
              '${top.escapeMonths}ヶ月続ければ脱却できます。',
        ),
      );
    }

    // ⑦ 支払予定と収入の差を固定費で埋める。
    final monthlyPaymentTotal = workbook.cashflowRows
        .where((row) => row.isPayment && row.isDirectCashflowTarget)
        .fold<double>(0, (sum, row) => sum + row.paymentAmount);
    final annualIncome = userProfile?.annualIncome;
    if (annualIncome != null && annualIncome > 0 && monthlyPaymentTotal > 0) {
      final monthlyIncome = annualIncome / 12;
      if (monthlyPaymentTotal > monthlyIncome * 0.8) {
        monthSteps.add(
          AssetTriageStep(
            kind: AssetTriageStepKind.closeIncomeGap,
            title: '支払予定と収入の差を埋める',
            detail: '今月の支払予定合計${_yen(monthlyPaymentTotal)}は'
                '月収目安${_yen(monthlyIncome)}に対して重すぎます。'
                '通信費・サブスクなど固定費の解約候補を明細から洗い出してください。',
          ),
        );
      }
    }

    // 専門窓口の案内 (負債が絶対額または年収比の閾値を超えたら)。
    final totalDebt = workbook.debtMasterRows.fold<double>(
      0,
      (sum, row) => sum + row.balance.abs(),
    );
    final showConsultation = totalDebt >= consultationDebtThreshold ||
        (annualIncome != null &&
            annualIncome > 0 &&
            totalDebt >= annualIncome * consultationDebtIncomeRatio);
    String? consultationNote;
    if (showConsultation) {
      final incomeNote = (annualIncome != null && annualIncome > 0)
          ? '年収${_yen(annualIncome)}の収入があるので、増やすのを止めて計画を立て直せば'
              '十分立て直せる数字です。'
          : '';
      consultationNote = '負債合計 約${_yen(totalDebt)}は、任意整理などで利息を'
          '止められる可能性がある水準です。無料で相談できます: '
          '法テラス 0570-078374（収入基準を満たせば弁護士相談が無料）/ '
          '消費者ホットライン 188（最寄りの消費生活センター）/ '
          '各自治体の無料法律相談（多重債務相談）。'
          '相談は「破産する人がするもの」ではなく、利息を止めて返済計画を'
          '立て直すための普通の手段です。$incomeNote';
    }

    return AssetTriagePlan(
      todaySteps: cappedToday,
      weekSteps: weekSteps,
      monthSteps: monthSteps,
      showConsultation: showConsultation,
      consultationNote: consultationNote,
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _yen(double amount) {
    final sign = amount < 0 ? '-' : '';
    final digits = amount.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$sign$buffer円';
  }
}
