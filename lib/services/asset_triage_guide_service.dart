import '../models/asset_liability_workbook.dart';
import '../models/user_profile.dart';
import 'asset_debt_discipline_monitor.dart';

/// トリアージステップの種別。
enum AssetTriageStepKind {
  /// 今日: 食費・移動費など最低限の生活費を確保する。
  secureLivingExpense,

  /// 今日: 収入予定が1件も未登録のため、資金繰りが実態より厳しく出ていることを
  /// 知らせ、給料日・金額・入金先の登録を促す。
  registerIncomePlan,

  /// 今日: 期日を過ぎた入金予定（給料等）が着金したか確認する。
  confirmIncomeArrival,

  /// 今日: 本日期日の支払いの原資を確認する。
  dueTodayPayment,

  /// 今日: カードの新規利用を止める（財布から抜く）。
  stopNewCardUsage,

  /// 今週: 家賃・通信など生活の生命線となる固定費を優先確保する。
  secureLifeline,

  /// 今週: 高金利ローンの最低額を死守する。
  protectHighInterestLoan,

  /// 今週: 期限超過の支払いを上から処理する。
  processOverdue,

  /// 今週: カード新規利用分の25日返済ルールを直す。
  disableRevolving,

  /// 今月: サブスク区分の固定費を名指しで解約候補として見直す。
  cancelSubscriptions,

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
/// → ④期限超過の処理 → ⑤新規利用分の25日返済 → ⑥返済ペース → ⑦収支ギャップ。
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

  /// 「高金利ローン」と見なす年利の下限（この値以上を死守対象にする）。
  /// 消費者金融 (年18%) だけでなく銀行カードローン (年14.5% 前後) も
  /// 延滞は等しく重いため、10% を閾値にして cardLoan 種別を漏れなく拾う。
  static const double highInterestRateThreshold = 0.10;

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

    // ① 生活費確保 (健康を削らない)。現金口座を登録していないだけの利用者に
    // 「現金0円」の偽危機を出さないため、現金口座がある場合の残高不足か、
    // 本日使用可能額のマイナスのどちらかでのみ発火する。
    final cashAccounts = workbook.accounts
        .where((account) => account.kind == AssetLiabilityAccountKind.cash)
        .toList();
    final cashOnHand = cashAccounts
        .where((account) => account.balance > 0)
        .fold<double>(0, (sum, account) => sum + account.balance);
    final lowCash =
        cashAccounts.isNotEmpty && cashOnHand < livingExpenseCashThreshold;
    if (lowCash || todayAvailableAmount < 0) {
      // 引出元は生残高でなく「引落予定を除いた見込み残高」最大の預金を選ぶ
      // (残高最大口座が引落原資だと、下ろした結果引き落とし不能になるため)。
      final summariesById = <String, AssetLiabilityAccountCashflowSummary>{
        for (final summary in workbook.accountCashflowSummaries)
          summary.accountId: summary,
      };
      AssetLiabilityAccount? source;
      var sourceProjected = 0.0;
      for (final account in workbook.accounts) {
        if (account.kind != AssetLiabilityAccountKind.deposit ||
            account.balance <= 0) {
          continue;
        }
        final projected =
            summariesById[account.id]?.projectedBalance ?? account.balance;
        if (source == null || projected > sourceProjected) {
          source = account;
          sourceProjected = projected;
        }
      }
      final reason = lowCash
          ? '手元現金が${_yen(cashOnHand)}しかありません。'
          : '本日の使用可能額が${_yen(todayAvailableAmount)}です。';
      final String detail;
      if (source == null || sourceProjected <= 0) {
        detail = '$reason現金・預金として登録された口座に余力が見つかりません。'
            '他に使える資産がないか確認し、無ければ今日の食費は家族・自治体・'
            'フードバンク等への相談も選択肢にしてください。食事を抜く判断はしないでください。';
      } else if (sourceProjected >= 20000) {
        detail = '$reason${source.name}（残高 ${_yen(source.balance)} / '
            '引落予定を除いた余力 ${_yen(sourceProjected)}）から'
            '1〜2万円を下ろして今日の食費・移動費を確保してください。'
            '食事を抜く判断はしないでください。';
      } else {
        detail = '$reason${source.name}の引落予定を除いた余力は'
            '${_yen(sourceProjected)}です。引き落としに影響しないよう、'
            'この範囲で今日の食費・移動費を確保してください。'
            '食事を抜く判断はしないでください。';
      }
      todaySteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.secureLivingExpense,
          title: '食費・移動費を確保する',
          detail: detail,
        ),
      );
    }

    // ①.5 期日を過ぎた入金予定（給料等）の着金確認。着金すれば口座が正常化する
    // 最もレバレッジの高い1件のため、生活費の次・本日期日の前に置く。
    final pendingIncome = workbook.incomePlans
        .where(
          (plan) => !plan.received && !_dateOnly(plan.date).isAfter(today),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (pendingIncome.isNotEmpty) {
      final top = pendingIncome.first;
      final others = pendingIncome.length - 1;
      final destinationNote = top.destinationAccountName == null
          ? ''
          : '着金先は${top.destinationAccountName}の見込みです。';
      todaySteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.confirmIncomeArrival,
          title: '入金予定が着金したか確認する',
          detail: '${top.name} ${_yen(top.amount)}'
              '${others > 0 ? ' ほか$others件' : ''}が'
              '入金予定日を過ぎても「未受取」のままです。$destinationNote'
              '着金していれば「受取済み」に更新してください。口座の見込み残高が'
              '正常化し、以降の資金繰り判断が変わります。',
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
        for (final violation in discipline.allViolations) violation.accountName,
      }.take(3).join('・');
      final newBorrowingNote = discipline.totalNewBorrowing > 0
          ? '今月すでに約${_yen(discipline.totalNewBorrowing)}の新規借入があります。'
          : 'カード新規利用分の25日返済額が不足しています。';
      todaySteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.stopNewCardUsage,
          title: 'カードを財布から抜く',
          detail: '$namesを今日から使わないでください。$newBorrowingNote'
              '「増やさない」が返済より先です。支払いは現金かデビットに切り替えてください。',
        ),
      );
    }

    // ③.5 収入予定が1件も未登録なら、資金繰りは「収入ゼロ」で計算され、使用可能額が
    // 実態より大幅に低く出る。数字を鵜呑みにして過度に不安になるのを防ぐため登録を促す。
    // ただし生存行動 (生活費確保・本日期日・カード停止) より後に置き、今日の3件枠が
    // 埋まっているときはそちらを優先する (データ入力より今日を生き延びる方が先)。
    // 支払予定がある家計にだけ出す (データ未入力の新規利用者への誤発火防止)。
    final hasScheduledPayments = workbook.cashflowRows.any(
      (row) => row.isPayment && row.isDirectCashflowTarget,
    );
    if (workbook.incomePlans.isEmpty && hasScheduledPayments) {
      todaySteps.add(
        const AssetTriageStep(
          kind: AssetTriageStepKind.registerIncomePlan,
          title: '収入予定を登録する',
          detail: '今月の収入予定が1件も登録されていません。'
              'そのため使用可能額や口座の見込み残高は「収入ゼロ」で計算されており、'
              '実際より大幅に厳しい数字が出ています。'
              '給料日・金額・入金先の口座を登録すると正しい資金繰りに直ります。',
        ),
      );
    }

    // 今日のステップは最大 3 件 (多いと動けなくなる)。溢れた分は翌日以降に回る。
    final cappedToday = todaySteps.take(maxTodaySteps).toList();

    // ④ 家賃・通信など生活の生命線を優先確保。fullPaymentEstimate は
    // 「家賃・通信費など毎月全額を支払う固定費型」だが、サブスク区分の定期固定費も
    // 同じ fullPaymentEstimate=true で計上される。サブスクは解約候補であって
    // 「優先して払う生命線」ではないため、subscriptionFixedCostAccountIds を除外する
    // (これを混ぜると困窮ユーザーに『サブスクを他の支払いより先に払え』と誤指示し、
    // 同じ計画の固定費見直しステップとも矛盾する)。
    // カード請求に内包される固定費 (例: auPay カード経由の通信費) は、口座から
    // 直接引き落とされず、そのカードの請求行で支払われる。ここで「口座に先に
    // 確保せよ」と出すとカード請求分と二重計上になるため、直接引落分のみを対象にする。
    final subscriptionIds = workbook.subscriptionFixedCostAccountIds;
    final lifelineRows = workbook.debtMasterRows
        .where(
          (row) =>
              row.fullPaymentEstimate &&
              !row.paid &&
              row.scheduledPaymentAmount > 0 &&
              !row.includedInBillingAccount &&
              !subscriptionIds.contains(row.id),
        )
        .toList()
      ..sort((a, b) => (a.paymentDay ?? 99).compareTo(b.paymentDay ?? 99));
    if (lifelineRows.isNotEmpty) {
      final total = lifelineRows.fold<double>(
        0,
        (sum, row) => sum + row.scheduledPaymentAmount,
      );
      final names = lifelineRows
          .take(3)
          .map(
            (row) => '${row.name} ${_yen(row.scheduledPaymentAmount)}'
                '${row.paymentDay == null ? '' : '（${row.paymentDay}日）'}',
          )
          .join(' / ');
      weekSteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.secureLifeline,
          title: '家賃・通信など生命線を優先確保する',
          detail: '住居・通信は生活の生命線です。$names'
              '${lifelineRows.length > 3 ? ' ほか${lifelineRows.length - 3}件' : ''}'
              '（合計 ${_yen(total)}）の引落分は、他の支払いより先に口座へ確保してください。',
        ),
      );
    }

    // ⑤ 高金利ローンの最低額を死守（利息が重いので他より優先して最低額を守る）。
    final highInterestLoans = workbook.debtMasterRows
        .where(
          (row) =>
              !row.fullPaymentEstimate &&
              row.kind == AssetLiabilityAccountKind.cardLoan &&
              row.annualRate >= highInterestRateThreshold &&
              row.balance.abs() > 1 &&
              !row.paid,
        )
        .toList()
      ..sort((a, b) => b.annualRate.compareTo(a.annualRate));
    if (highInterestLoans.isNotEmpty) {
      final names = highInterestLoans
          .take(3)
          .map(
            (row) => '${row.name}（年${_formatRate(row.annualRate)} / '
                '最低 ${_yen(row.minimumPaymentEstimate)}）',
          )
          .join(' / ');
      weekSteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.protectHighInterestLoan,
          title: '高金利ローンの最低額を死守する',
          detail: '利息が重い高金利ローンは、延滞すると傷が深くなります。$names'
              '${highInterestLoans.length > 3 ? ' ほか${highInterestLoans.length - 3}件' : ''}'
              'は最低額を必ず確保し、余力があればここから多めに返してください。',
        ),
      );
    }

    // ⑥ 期限超過の処理 (放置だけが最悪)。
    // overdueCashflowRows は未受領の収入行も含み、本日期日 (=ステップ②) も
    // overdue 扱いのため、「支払 かつ 昨日以前」に絞る (収入を延滞額扱いしない・
    // 本日期日を②と二重計上しない)。
    final overdueRows = workbook.cashflowRows
        .where(
          (row) =>
              row.isPayment &&
              row.isDirectCashflowTarget &&
              !row.paid &&
              row.overdue &&
              _dateOnly(row.paymentDate).isBefore(today),
        )
        .toList();
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

    // ⑤ カード新規利用分の25日返済ルールを是正する。
    final revolving = discipline?.revolvingCardViolations ??
        const <AssetDebtDisciplineViolation>[];
    if (revolving.isNotEmpty) {
      final names =
          revolving.map((violation) => violation.accountName).take(4).join('・');
      weekSteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.disableRevolving,
          title: '新規利用分の25日返済を確保する',
          detail: '$namesは、最低返済額に当月の新規利用分を全額上乗せし、'
              '給料日の25日に返済できる予定へ直してください。'
              '既存残高の一括返済は求めず、これ以上残高を増やさないことを優先します。',
        ),
      );
    }

    // ⑥ サブスク区分の固定費を名指しで解約候補にする。fullPaymentEstimate は
    // 家賃とサブスクを区別できないが、subscriptionFixedCostAccountIds はサブスク
    // 区分だけを正確に指すため、家賃を「解約候補」と誤提示せず安全に名指しできる。
    // 借入のある利用者にだけ出す (このカードは家計が苦しい人向けの整理であり、
    // 無借金の健全な利用者にサブスク解約を促すのはノイズになるため)。
    final hasBorrowingDebt = workbook.debtMasterRows.any(
      (row) =>
          !row.fullPaymentEstimate &&
          AssetDebtDisciplineMonitor.isBorrowingKind(row.kind) &&
          row.balance.abs() > 1,
    );
    final subscriptionRows = workbook.debtMasterRows
        .where(
          (row) =>
              workbook.subscriptionFixedCostAccountIds.contains(row.id) &&
              row.scheduledPaymentAmount > 0,
        )
        .toList()
      ..sort(
        (a, b) => b.scheduledPaymentAmount.compareTo(a.scheduledPaymentAmount),
      );
    if (hasBorrowingDebt && subscriptionRows.isNotEmpty) {
      final total = subscriptionRows.fold<double>(
        0,
        (sum, row) => sum + row.scheduledPaymentAmount,
      );
      final names = subscriptionRows
          .take(4)
          .map((row) => '${row.name} ${_yen(row.scheduledPaymentAmount)}')
          .join(' / ');
      monthSteps.add(
        AssetTriageStep(
          kind: AssetTriageStepKind.cancelSubscriptions,
          title: 'サブスクを見直す',
          detail: '$names'
              '${subscriptionRows.length > 4 ? ' ほか${subscriptionRows.length - 4}件' : ''}'
              '（毎月 ${_yen(total)}）。使う月だけ入れて、終わったら切る運用にすれば'
              'この分がそのまま浮きます。今すぐ使っていないものから解約してください。',
        ),
      );
    }

    // ⑦ 返済ペースを脱却プランで決める。例示カードも本文どおり
    // 「金利の高い順」で選ぶ (違反リスト自体は繰越額順のため並べ直す)。
    final annualRateById = <String, double>{
      for (final row in workbook.debtMasterRows) row.id: row.annualRate,
    };
    final planned =
        revolving.where((violation) => violation.hasEscapePlan).toList()
          ..sort(
            (a, b) => (annualRateById[b.accountId] ?? 0).compareTo(
              annualRateById[a.accountId] ?? 0,
            ),
          );
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
                '通信費・保険など固定費の見直し候補を明細から洗い出してください。',
          ),
        );
      }
    }

    // 専門窓口の案内 (借入が絶対額または年収比の閾値を超えたら)。
    // 家賃・通信費など毎月全額払いの固定費は「借金」ではないため、
    // 規律モニターと同じ基準 (isBorrowingKind + 非固定費) で合算する。
    final totalDebt = workbook.debtMasterRows
        .where(
          (row) =>
              !row.fullPaymentEstimate &&
              AssetDebtDisciplineMonitor.isBorrowingKind(row.kind),
        )
        .fold<double>(0, (sum, row) => sum + row.balance.abs());
    final showConsultation = totalDebt >= consultationDebtThreshold ||
        (annualIncome != null &&
            annualIncome > 0 &&
            totalDebt >= annualIncome * consultationDebtIncomeRatio);
    String? consultationNote;
    if (showConsultation) {
      // 「立て直せる」の断言は借入が年収1.5倍以内のときだけ。それ以上は
      // 結果を請け合わず、専門家との計画づくりへ誘導する。
      final String incomeNote;
      if (annualIncome == null || annualIncome <= 0) {
        incomeNote = '';
      } else if (totalDebt <= annualIncome * 1.5) {
        incomeNote = '年収${_yen(annualIncome)}の収入があるので、増やすのを止めて'
            '計画を立て直せば十分立て直せる数字です。';
      } else {
        incomeNote = '年収${_yen(annualIncome)}の収入があることは大きな強みです。'
            'どの手続きが合うかも含めて、専門家と一緒に現実的な計画を立てましょう。';
      }
      consultationNote = '借入合計 約${_yen(totalDebt)}は、任意整理などで利息を'
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

  /// 年利 (小数) を「18%」のような表示へ。整数割り切れ時は小数点を省く。
  String _formatRate(double rate) {
    final percent = rate * 100;
    if ((percent - percent.roundToDouble()).abs() < 0.05) {
      return '${percent.round()}%';
    }
    return '${percent.toStringAsFixed(1)}%';
  }

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
