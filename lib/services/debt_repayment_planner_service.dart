import 'dart:math';

import 'package:intl/intl.dart';
import 'package:my_web_app/models/debt_repayment_plan.dart';

class DebtRepaymentPlannerService {
  const DebtRepaymentPlannerService();

  static const double _epsilon = 0.01;

  DebtRepaymentInputDebt normalizeDebt({
    required String name,
    required double balance,
    double? annualRate,
    double? minimumPaymentRate,
    double? minimumPaymentFloor,
    int? paymentDay,
  }) {
    final assumption = _assumptionForName(name);
    return DebtRepaymentInputDebt(
      name: name,
      balance: balance.abs(),
      annualRate: annualRate ?? assumption.annualRate,
      minimumPaymentRate: minimumPaymentRate ?? assumption.minimumPaymentRate,
      minimumPaymentFloor:
          minimumPaymentFloor ?? assumption.minimumPaymentFloor,
      paymentDay: _normalizePaymentDay(paymentDay),
    );
  }

  DebtRepaymentPlanResult generatePlan({
    required DebtRepaymentPlanInput input,
  }) {
    final sourceDebts = input.debts
        .where((d) => d.balance > _epsilon)
        .map(_DebtState.fromInput)
        .toList();

    if (sourceDebts.isEmpty) {
      const markdown = '## 返済計画\n- 返済対象となる負債データがありません。';
      return DebtRepaymentPlanResult(
        markdown: markdown,
        warnings: const ['返済対象の負債が0件です。'],
        priorities: const [],
        monthlyActions: const [],
        roadmap: const [],
        requestedMonthlyBudget: max(
          0,
          input.monthlyBudget + input.extraBudget,
        ).toDouble(),
        affordableMonthlyBudget: max(
          0,
          input.monthlyIncome - input.monthlyExpense,
        ).toDouble(),
        estimatedCompletionMonths: 0,
        canMeetTargetMonths: true,
      );
    }

    final priorities = _buildPriorities(
      debts: sourceDebts,
      strategy: input.strategy,
    );

    final requestedMonthlyBudget = max(
      0,
      input.monthlyBudget + input.extraBudget,
    ).toDouble();
    final affordableMonthlyBudget = max(
      0,
      input.monthlyIncome - input.monthlyExpense,
    ).toDouble();

    final warnings = <String>[];
    if (input.netWorth < 0) {
      warnings.add('純資産がマイナスです。返済計画と同時に固定費の圧縮が必要です。');
    }
    if (requestedMonthlyBudget <= 0) {
      warnings.add('月次返済予算が0円以下です。返済計画を実行できません。');
    }
    if (affordableMonthlyBudget < requestedMonthlyBudget) {
      warnings.add(
        '返済予算が実収支を上回っています。予算差額は毎月 ${_yen(requestedMonthlyBudget - affordableMonthlyBudget)} です。',
      );
    }

    final simulation = _simulate(
      debts: sourceDebts,
      strategy: input.strategy,
      monthlyBudget: requestedMonthlyBudget,
      targetMonths: input.targetMonths,
      priorities: priorities,
      baseMonth: input.baseMonth,
    );

    for (final warning in simulation.warnings) {
      if (!warnings.contains(warning)) {
        warnings.add(warning);
      }
    }

    final estimatedCompletionMonths = simulation.estimatedCompletionMonths;
    if (estimatedCompletionMonths == null) {
      warnings.add('試算上、設定した予算では完済時期を確定できませんでした。');
    } else if (estimatedCompletionMonths > input.targetMonths) {
      warnings.add(
        '目標の${input.targetMonths}ヶ月に対して、試算完済は約$estimatedCompletionMonthsヶ月です。',
      );
    }

    final markdown = _buildMarkdown(
      input: input,
      priorities: priorities,
      monthlyActions: simulation.monthlyActions,
      roadmap: simulation.roadmap,
      warnings: warnings,
      requestedMonthlyBudget: requestedMonthlyBudget,
      affordableMonthlyBudget: affordableMonthlyBudget,
      estimatedCompletionMonths: estimatedCompletionMonths,
    );

    final canMeetTargetMonths =
        estimatedCompletionMonths != null &&
        estimatedCompletionMonths <= input.targetMonths;

    return DebtRepaymentPlanResult(
      markdown: markdown,
      warnings: warnings,
      priorities: priorities,
      monthlyActions: simulation.monthlyActions,
      roadmap: simulation.roadmap,
      requestedMonthlyBudget: requestedMonthlyBudget,
      affordableMonthlyBudget: affordableMonthlyBudget,
      estimatedCompletionMonths: estimatedCompletionMonths,
      canMeetTargetMonths: canMeetTargetMonths,
    );
  }

  DebtExecutionPlan buildExecutionPlan({
    required DebtRepaymentPlanInput input,
    required DebtRepaymentPlanResult result,
  }) {
    final tasks = <DebtExecutionTask>[];
    final seenIds = <String>{};

    void addTask({
      required String id,
      required DebtExecutionTaskKind kind,
      required String title,
      required String detail,
      required DateTime dueDate,
    }) {
      if (!seenIds.add(id)) return;
      tasks.add(
        DebtExecutionTask(
          id: id,
          kind: kind,
          title: title,
          detail: detail,
          dueDate: dueDate,
        ),
      );
    }

    final topPriority = result.priorities.isEmpty
        ? null
        : result.priorities.first;
    final firstAction = result.monthlyActions.isEmpty
        ? null
        : result.monthlyActions.first;
    final firstRoadmap = result.roadmap.isEmpty ? null : result.roadmap.first;
    final monthStart = DateTime(input.baseMonth.year, input.baseMonth.month, 1);
    final budgetGap = max(
      0,
      result.requestedMonthlyBudget - result.affordableMonthlyBudget,
    );

    if (topPriority != null) {
      addTask(
        id: 'focus-${topPriority.name}',
        kind: DebtExecutionTaskKind.focus,
        title: '最優先返済「${topPriority.name}」へ集中する',
        detail:
            '${_strategyLabel(input.strategy)}では ${topPriority.name} が第1優先です。${topPriority.reason}',
        dueDate: _dueDateInMonth(monthStart, day: 7),
      );
    }

    if (budgetGap > 0) {
      addTask(
        id: 'budget-gap',
        kind: DebtExecutionTaskKind.budget,
        title: '返済原資 ${_yen(budgetGap)} を補填する',
        detail: '実収支ベースでは毎月 ${_yen(budgetGap)} 足りません。固定費圧縮か追加収入で穴を埋める必要があります。',
        dueDate: _dueDateInMonth(monthStart, day: 10),
      );
    } else if (input.fixedCost > 0) {
      addTask(
        id: 'fixed-cost-review',
        kind: DebtExecutionTaskKind.fixedCost,
        title: '固定費を棚卸しして追加返済枠を作る',
        detail: '現在の固定費は ${_yen(input.fixedCost)} です。不要な契約や分割払いを見直して余力を増やします。',
        dueDate: _dueDateInMonth(monthStart, day: 12),
      );
    }

    if (firstAction != null) {
      final focusName = firstAction.focusDebt ?? topPriority?.name ?? '最優先債務';
      addTask(
        id: 'payment-$focusName-${firstAction.monthIndex}',
        kind: DebtExecutionTaskKind.payment,
        title: '今月の返済 ${_yen(firstAction.paymentTotal)} を実行する',
        detail:
            '$focusName を軸に、最低返済 ${_yen(firstAction.minimumTotal)} と上乗せ ${_yen(firstAction.extraTotal)} を確保します。',
        dueDate: _dueDateInMonth(monthStart, day: 25),
      );
    }

    if (firstRoadmap != null) {
      final milestoneWindow = firstRoadmap.endMonth == null
          ? '${firstRoadmap.startMonth}ヶ月目から着手'
          : '${firstRoadmap.startMonth}〜${firstRoadmap.endMonth}ヶ月目の完了目標';
      addTask(
        id: 'milestone-${firstRoadmap.name}',
        kind: DebtExecutionTaskKind.milestone,
        title: '${firstRoadmap.name} の完済マイルストーンを追跡する',
        detail: '$milestoneWindow を念頭に、返済順序を崩さず進捗を確認します。',
        dueDate: _dueDateInMonth(monthStart, day: 28),
      );
    }

    addTask(
      id: 'review-and-rerun',
      kind: DebtExecutionTaskKind.review,
      title: '月末に実績を記録してプランを再実行する',
      detail: '返済額・固定費・収支を更新し、Ask の提案を次の Code 実行へつなげます。',
      dueDate: _dueDateInMonth(monthStart, day: 31),
    );

    final summary = topPriority == null
        ? 'Codex-style Code モード用に、今月の実行タスクを整理しました。'
        : 'Codex-style Code モード用に、${topPriority.name} を起点とした実行タスクへ落とし込みました。';

    return DebtExecutionPlan(summary: summary, tasks: tasks);
  }

  List<DebtPriorityItem> _buildPriorities({
    required List<_DebtState> debts,
    required DebtRepaymentStrategy strategy,
  }) {
    final sorted = debts.map((d) => d.copy()).toList()
      ..sort((a, b) => _compareByStrategy(a, b, strategy));

    return sorted.asMap().entries.map((entry) {
      final rank = entry.key + 1;
      final debt = entry.value;
      return DebtPriorityItem(
        rank: rank,
        name: debt.name,
        balance: debt.balance,
        annualRate: debt.annualRate,
        paymentDay: debt.paymentDay,
        reason: _priorityReason(debt: debt, strategy: strategy),
      );
    }).toList();
  }

  _SimulationResult _simulate({
    required List<_DebtState> debts,
    required DebtRepaymentStrategy strategy,
    required double monthlyBudget,
    required int targetMonths,
    required List<DebtPriorityItem> priorities,
    required DateTime baseMonth,
  }) {
    final states = debts.map((d) => d.copy()).toList();
    final actions = <DebtMonthlyAction>[];
    final closedMonthByDebt = <String, int>{};
    var shortfallDetected = false;
    int? estimatedCompletionMonths;

    final maxSimulateMonths = max(targetMonths * 4, 240);

    for (var monthIndex = 1; monthIndex <= maxSimulateMonths; monthIndex++) {
      final active = states.where((d) => d.balance > _epsilon).toList();
      if (active.isEmpty) {
        estimatedCompletionMonths = monthIndex - 1;
        break;
      }

      var interestTotal = 0.0;
      for (final debt in active) {
        final interest = debt.balance * (debt.annualRate / 12.0);
        debt.balance += interest;
        interestTotal += interest;
      }

      active.sort((a, b) => _compareByStrategy(a, b, strategy));

      final minimumByDebt = <String, double>{};
      var minimumTotal = 0.0;
      for (final debt in active) {
        final minimum = _minimumPayment(debt);
        minimumByDebt[debt.name] = minimum;
        minimumTotal += minimum;
      }

      var remainingBudget = monthlyBudget;
      var paymentTotal = 0.0;
      final closedDebts = <String>[];
      final focusDebt = active.isEmpty ? null : active.first.name;
      final isBudgetShortfall = remainingBudget + _epsilon < minimumTotal;

      if (isBudgetShortfall) {
        shortfallDetected = true;
        for (final debt in active) {
          if (remainingBudget <= _epsilon) break;
          final minimum = minimumByDebt[debt.name] ?? 0.0;
          final payment = min(remainingBudget, minimum);
          final paid = _applyPayment(
            debt: debt,
            candidatePayment: payment,
            monthIndex: monthIndex,
            closedMonthByDebt: closedMonthByDebt,
            closedDebts: closedDebts,
          );
          paymentTotal += paid;
          remainingBudget -= paid;
        }
      } else {
        for (final debt in active) {
          final minimum = minimumByDebt[debt.name] ?? 0.0;
          final paid = _applyPayment(
            debt: debt,
            candidatePayment: minimum,
            monthIndex: monthIndex,
            closedMonthByDebt: closedMonthByDebt,
            closedDebts: closedDebts,
          );
          paymentTotal += paid;
          remainingBudget -= paid;
        }

        while (remainingBudget > _epsilon) {
          final target = _firstActiveDebt(active);
          if (target == null) break;

          final paid = _applyPayment(
            debt: target,
            candidatePayment: remainingBudget,
            monthIndex: monthIndex,
            closedMonthByDebt: closedMonthByDebt,
            closedDebts: closedDebts,
          );
          paymentTotal += paid;
          remainingBudget -= paid;
        }
      }

      final remainingDebt = states.fold<double>(
        0,
        (sum, debt) => sum + max(0, debt.balance),
      );

      actions.add(
        DebtMonthlyAction(
          monthIndex: monthIndex,
          monthStart: DateTime(
            baseMonth.year,
            baseMonth.month + monthIndex - 1,
          ),
          focusDebt: focusDebt,
          paymentTotal: paymentTotal,
          minimumTotal: minimumTotal,
          extraTotal: max(0, paymentTotal - minimumTotal),
          interestTotal: interestTotal,
          remainingDebt: remainingDebt,
          isBudgetShortfall: isBudgetShortfall,
          closedDebts: closedDebts,
        ),
      );

      if (remainingDebt <= _epsilon) {
        estimatedCompletionMonths = monthIndex;
        break;
      }
    }

    final warnings = <String>[];
    if (shortfallDetected) {
      warnings.add('月次返済予算が最低返済額を下回る月があります。延滞リスクに注意してください。');
    }

    final roadmap = _buildRoadmap(
      priorities: priorities,
      closedMonthByDebt: closedMonthByDebt,
    );

    return _SimulationResult(
      monthlyActions: actions,
      roadmap: roadmap,
      estimatedCompletionMonths: estimatedCompletionMonths,
      warnings: warnings,
    );
  }

  List<DebtRoadmapStep> _buildRoadmap({
    required List<DebtPriorityItem> priorities,
    required Map<String, int> closedMonthByDebt,
  }) {
    final steps = <DebtRoadmapStep>[];
    var startMonth = 1;

    for (final item in priorities) {
      final endMonth = closedMonthByDebt[item.name];
      final monthsRequired = endMonth == null
          ? null
          : max(1, endMonth - startMonth + 1);
      steps.add(
        DebtRoadmapStep(
          name: item.name,
          startMonth: startMonth,
          endMonth: endMonth,
          monthsRequired: monthsRequired,
        ),
      );
      if (endMonth != null) {
        startMonth = endMonth + 1;
      }
    }

    return steps;
  }

  double _applyPayment({
    required _DebtState debt,
    required double candidatePayment,
    required int monthIndex,
    required Map<String, int> closedMonthByDebt,
    required List<String> closedDebts,
  }) {
    if (candidatePayment <= _epsilon || debt.balance <= _epsilon) return 0;

    final paid = min(candidatePayment, debt.balance);
    debt.balance = max(0, debt.balance - paid);

    if (debt.balance <= _epsilon && !closedMonthByDebt.containsKey(debt.name)) {
      closedMonthByDebt[debt.name] = monthIndex;
      closedDebts.add(debt.name);
    }
    return paid;
  }

  _DebtState? _firstActiveDebt(List<_DebtState> debts) {
    for (final debt in debts) {
      if (debt.balance > _epsilon) return debt;
    }
    return null;
  }

  int _compareByStrategy(
    _DebtState a,
    _DebtState b,
    DebtRepaymentStrategy strategy,
  ) {
    switch (strategy) {
      case DebtRepaymentStrategy.snowball:
        final byBalance = a.balance.compareTo(b.balance);
        if (byBalance != 0) return byBalance;
        return b.annualRate.compareTo(a.annualRate);
      case DebtRepaymentStrategy.avalanche:
        final byRate = b.annualRate.compareTo(a.annualRate);
        if (byRate != 0) return byRate;
        return a.balance.compareTo(b.balance);
      case DebtRepaymentStrategy.dueDate:
        final byPaymentDay = (a.paymentDay ?? 99).compareTo(b.paymentDay ?? 99);
        if (byPaymentDay != 0) return byPaymentDay;
        final byRate = b.annualRate.compareTo(a.annualRate);
        if (byRate != 0) return byRate;
        return a.balance.compareTo(b.balance);
      case DebtRepaymentStrategy.hybrid:
        final rateGap = (a.annualRate - b.annualRate).abs();
        if (rateGap >= 0.03) {
          final byRate = b.annualRate.compareTo(a.annualRate);
          if (byRate != 0) return byRate;
        }
        final byBalance = a.balance.compareTo(b.balance);
        if (byBalance != 0) return byBalance;
        return b.annualRate.compareTo(a.annualRate);
    }
  }

  String _priorityReason({
    required _DebtState debt,
    required DebtRepaymentStrategy strategy,
  }) {
    switch (strategy) {
      case DebtRepaymentStrategy.snowball:
        return '残高が小さく、早期完済で達成感を得やすいため';
      case DebtRepaymentStrategy.avalanche:
        return '推定金利 ${_percent(debt.annualRate)} と高く、利息削減効果が大きいため';
      case DebtRepaymentStrategy.dueDate:
        final day = debt.paymentDay;
        return day == null
            ? '支払日が未設定のため、設定済みの返済を先に並べた後で扱います'
            : '支払日 $day日 が近く、月内の資金繰りリスクを抑えやすいため';
      case DebtRepaymentStrategy.hybrid:
        if (debt.annualRate >= 0.15) {
          return '高金利帯で、放置時の利息負担が大きいため';
        }
        return '残高圧縮と利息削減のバランスを優先するため';
    }
  }

  double _minimumPayment(_DebtState debt) {
    final byRate = debt.balance * debt.minimumPaymentRate;
    final minimum = max(byRate, debt.minimumPaymentFloor);
    return min(minimum, debt.balance);
  }

  _DebtAssumption _assumptionForName(String name) {
    final key = name.toLowerCase();

    if (_containsAny(key, const ['アコム', 'モビット', 'プロミス', 'レイク', 'アイフル'])) {
      return const _DebtAssumption(
        annualRate: 0.18,
        minimumPaymentRate: 0.04,
        minimumPaymentFloor: 4000,
      );
    }

    if (_containsAny(key, const [
      'paypay',
      'aupay',
      'カード',
      'クレジット',
      'リボ',
      'ショッピング',
    ])) {
      return const _DebtAssumption(
        annualRate: 0.15,
        minimumPaymentRate: 0.03,
        minimumPaymentFloor: 3000,
      );
    }

    if (_containsAny(key, const ['銀行', 'ローン', 'じぶん', '三井住友', '横浜'])) {
      return const _DebtAssumption(
        annualRate: 0.14,
        minimumPaymentRate: 0.03,
        minimumPaymentFloor: 3000,
      );
    }

    if (_containsAny(key, const ['通信', '携帯', '税', '公共', '滞納', 'au'])) {
      return const _DebtAssumption(
        annualRate: 0.06,
        minimumPaymentRate: 0.02,
        minimumPaymentFloor: 2000,
      );
    }

    return const _DebtAssumption(
      annualRate: 0.12,
      minimumPaymentRate: 0.03,
      minimumPaymentFloor: 3000,
    );
  }

  bool _containsAny(String source, List<String> keywords) {
    for (final keyword in keywords) {
      if (source.contains(keyword.toLowerCase())) return true;
    }
    return false;
  }

  int? _normalizePaymentDay(int? paymentDay) {
    if (paymentDay == null) return null;
    if (paymentDay < 1 || paymentDay > 31) return null;
    return paymentDay;
  }

  String _buildMarkdown({
    required DebtRepaymentPlanInput input,
    required List<DebtPriorityItem> priorities,
    required List<DebtMonthlyAction> monthlyActions,
    required List<DebtRoadmapStep> roadmap,
    required List<String> warnings,
    required double requestedMonthlyBudget,
    required double affordableMonthlyBudget,
    required int? estimatedCompletionMonths,
  }) {
    final buffer = StringBuffer();
    final currentDebt = priorities.fold<double>(0, (sum, p) => sum + p.balance);
    final strategyLabel = _strategyLabel(input.strategy);
    final strategyTitle = _strategyTitle(input.strategy);
    final budgetGap = max(0, requestedMonthlyBudget - affordableMonthlyBudget);
    final topDebt = priorities.isEmpty ? null : priorities.first;
    final secondDebt = priorities.length > 1 ? priorities[1] : topDebt;
    final thirdDebt = priorities.length > 2 ? priorities[2] : secondDebt;

    final firstAction = monthlyActions.isNotEmpty ? monthlyActions[0] : null;
    final secondAction = monthlyActions.length > 1 ? monthlyActions[1] : null;
    final thirdAction = monthlyActions.length > 2 ? monthlyActions[2] : null;

    buffer.writeln(
      '承知いたしました。家計再建に強いファイナンシャルコーチとして、提示されたデータに基づき、現実的かつ保守的な借金返済計画を作成します。',
    );
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('');

    buffer.writeln('### 現状診断');
    buffer.writeln('');
    buffer.writeln(
      '現在の純資産は${_yen(input.netWorth)}、借入総額は${_yen(currentDebt)}です。',
    );
    buffer.writeln(
      '今月の収入合計は${_yen(input.monthlyIncome)}、固定費は${_yen(input.fixedCost)}、支出合計は${_yen(input.monthlyExpense)}です。',
    );
    buffer.writeln(
      '毎月の返済予算は${_yen(input.monthlyBudget)}、臨時返済予算は${_yen(input.extraBudget)}として試算しています。',
    );
    if (budgetGap > 0) {
      buffer.writeln(
        'ただし実収支ベースでは返済予算が毎月${_yen(budgetGap)}不足しており、この予算の安定確保が最優先課題です。',
      );
    }
    if (estimatedCompletionMonths != null &&
        estimatedCompletionMonths > input.targetMonths) {
      buffer.writeln(
        '目標完済期間${input.targetMonths}ヶ月は挑戦的で、現在条件では約$estimatedCompletionMonthsヶ月の見込みです。',
      );
    }
    buffer.writeln('返済方針は$strategyLabelで、完済体験を積みながら計画を前進させます。');
    buffer.writeln('');

    buffer.writeln('### 返済優先順位（$strategyTitle）');
    buffer.writeln('');
    buffer.writeln('※以下の金利は仮定値です。実際の金利は契約内容により異なりますので、必ずご確認ください。');
    buffer.writeln('* 消費者金融系（アコム、モビットなど）: 年利18.0%');
    buffer.writeln('* 銀行系カードローン（じぶんローン、三井住友、横浜銀行など）: 年利14.0%');
    buffer.writeln('* クレジットカードのリボ・キャッシング（auPAY、PayPayカードなど）: 年利15.0%');
    buffer.writeln('* その他（通信料滞納等）: 年利6.0%');
    buffer.writeln('');

    for (final item in priorities) {
      buffer.writeln(
        '${item.rank}.  **${item.name}:** 残高 ${_yen(item.balance)}',
      );
      buffer.writeln('    *   理由: ${item.reason}');
    }
    buffer.writeln('');

    buffer.writeln('### 3ヶ月アクションプラン');
    buffer.writeln('');
    buffer.writeln(
      '毎月の返済予算${_yen(requestedMonthlyBudget)}を確保できる前提で計画しますが、その確保の道筋が最重要課題です。',
    );
    buffer.writeln('');
    buffer.writeln('| 月 | 先月の振り返り | 今月の目標 | 具体的なアクション |');
    buffer.writeln('|---|---|---|---|');

    final row1Review = budgetGap > 0
        ? '収入に対して固定費と返済予算が重く、資金繰り改善が急務です。'
        : '返済原資は確保できていますが、固定費最適化の余地があります。';
    final row1Goal = topDebt == null
        ? '1. 返済原資の安定化。<br>2. 金利・最低返済額の確認。'
        : '1. 毎月の返済予算${_yen(requestedMonthlyBudget)}の安定確保。<br>2. 全借入先の正確な金利・最低返済額の把握。<br>3. 最少残高の「${topDebt.name} (${_yen(topDebt.balance)})」の完済。';
    final row1Action = firstAction == null
        ? '1. 収入増加策と固定費削減策を即実行。<br>2. 契約書・明細で金利と最低返済額を一覧化。'
        : '1. 他借入は最低返済額を支払い、残余資金を「${firstAction.focusDebt ?? topDebt?.name ?? '最優先債務'}」へ集中。<br>2. 月内支払 ${_yen(firstAction.paymentTotal)}（最低返済 ${_yen(firstAction.minimumTotal)} + 上乗せ ${_yen(firstAction.extraTotal)}）を実行。';

    final row2DebtName = secondDebt?.name ?? '次順位の借入';
    final row2DebtBalance = secondDebt == null
        ? ''
        : ' (${_yen(secondDebt.balance)})';
    final row2Goal =
        '1. 収入・支出状況の継続的な改善と定着。<br>2. 「$row2DebtName$row2DebtBalance」の完済。';
    final row2Action = secondAction == null
        ? '1. 先月からの改善策を継続し、予算と実績を毎週比較。<br>2. 他借入は最低返済額を維持し、残余を次順位へ集中。'
        : '1. 他借入は最低返済額を維持し、残余資金を「${secondAction.focusDebt ?? row2DebtName}」へ集中。<br>2. 月内支払 ${_yen(secondAction.paymentTotal)}（利息 ${_yen(secondAction.interestTotal)}）を実行。';

    final row3DebtName = thirdDebt?.name ?? '次順位の借入';
    final row3DebtBalance = thirdDebt == null
        ? ''
        : ' (${_yen(thirdDebt.balance)})';
    final row3Goal =
        '1. 家計基盤のさらなる安定化と返済習慣の確立。<br>2. 「$row3DebtName$row3DebtBalance」の完済。';
    final row3Action = thirdAction == null
        ? '1. 返済予算不足時は追加収入策を実行。<br>2. 返済順序を維持し、完済件数を増やす。'
        : '1. 返済予算を再確認し、足りない場合は即時に補填策を実行。<br>2. 月内支払 ${_yen(thirdAction.paymentTotal)}（最低返済 ${_yen(thirdAction.minimumTotal)}）を実行。';

    buffer.writeln('| (先月) | $row1Review | $row1Goal | $row1Action |');
    buffer.writeln(
      '| 来月 (2ヶ月目) | 先月からの行動継続により、家計状況の改善を実感し始める時期です。 | $row2Goal | $row2Action |',
    );
    buffer.writeln(
      '| 再来月 (3ヶ月目) | 完済件数を増やし、返済の勢いを維持するフェーズです。 | $row3Goal | $row3Action |',
    );
    buffer.writeln('');

    buffer.writeln('### 完済までのロードマップ（月次）');
    buffer.writeln('');
    for (final step in roadmap) {
      if (step.endMonth == null) {
        buffer.writeln(
          '*   **${step.startMonth}ヶ月目以降:** ${step.name} の完済を目指す。',
        );
      } else if (step.startMonth == step.endMonth) {
        buffer.writeln('*   **${step.startMonth}ヶ月目:** ${step.name} を完済。');
      } else {
        buffer.writeln(
          '*   **${step.startMonth}〜${step.endMonth}ヶ月目:** ${step.name} を完済。',
        );
      }
    }
    buffer.writeln('');

    buffer.writeln('**【重要事項】**');
    if (estimatedCompletionMonths == null) {
      buffer.writeln('設定した予算では完済時期を算定できませんでした。予算の再設定が必要です。');
    } else {
      final conservativeMin = max(
        estimatedCompletionMonths,
        (estimatedCompletionMonths * 1.05).round(),
      );
      final conservativeMax = max(
        conservativeMin + 1,
        (estimatedCompletionMonths * 1.25).round(),
      );
      buffer.writeln(
        '上記は推定金利に基づく試算です。実際には約$conservativeMinヶ月〜$conservativeMaxヶ月程度かかる可能性があります。',
      );
      if (estimatedCompletionMonths > input.targetMonths) {
        buffer.writeln(
          '目標完済期間${input.targetMonths}ヶ月を目指すには、毎月の返済額増額または臨時返済の積み増しが必要です。',
        );
      }
    }
    buffer.writeln('');

    buffer.writeln('### 今週やること');
    buffer.writeln('');
    buffer.writeln('1. 収入確保と家計の徹底見直しを同時実行し、返済予算の原資を確保する。');
    buffer.writeln('2. 全借入先の金利・最低返済額・返済日を確認し、一覧表を最新化する。');
    buffer.writeln('3. 資金繰りが厳しい場合は、公的窓口や弁護士・司法書士の無料相談を予約する。');

    if (warnings.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('---');
      buffer.writeln('### 追加注意');
      for (final warning in warnings) {
        buffer.writeln('- $warning');
      }
    }

    return buffer.toString().trim();
  }

  String _strategyTitle(DebtRepaymentStrategy strategy) {
    switch (strategy) {
      case DebtRepaymentStrategy.snowball:
        return '少額優先：スノーボール方式';
      case DebtRepaymentStrategy.avalanche:
        return '高金利優先：アバランチ方式';
      case DebtRepaymentStrategy.dueDate:
        return '支払日順方式';
      case DebtRepaymentStrategy.hybrid:
        return 'ハイブリッド方式';
    }
  }

  String _strategyLabel(DebtRepaymentStrategy strategy) {
    switch (strategy) {
      case DebtRepaymentStrategy.snowball:
        return '少額優先（スノーボール）';
      case DebtRepaymentStrategy.avalanche:
        return '高金利優先（アバランチ）';
      case DebtRepaymentStrategy.dueDate:
        return '支払日順';
      case DebtRepaymentStrategy.hybrid:
        return 'ハイブリッド（高金利×少額）';
    }
  }

  String _yen(num value) {
    final format = NumberFormat('#,###');
    return '¥${format.format(value.round())}';
  }

  String _percent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  DateTime _dueDateInMonth(DateTime monthStart, {required int day}) {
    final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final resolvedDay = day.clamp(1, lastDay);
    return DateTime(monthStart.year, monthStart.month, resolvedDay);
  }
}

class _DebtAssumption {
  final double annualRate;
  final double minimumPaymentRate;
  final double minimumPaymentFloor;

  const _DebtAssumption({
    required this.annualRate,
    required this.minimumPaymentRate,
    required this.minimumPaymentFloor,
  });
}

class _DebtState {
  final String name;
  double balance;
  final double annualRate;
  final double minimumPaymentRate;
  final double minimumPaymentFloor;
  final int? paymentDay;

  _DebtState({
    required this.name,
    required this.balance,
    required this.annualRate,
    required this.minimumPaymentRate,
    required this.minimumPaymentFloor,
    required this.paymentDay,
  });

  factory _DebtState.fromInput(DebtRepaymentInputDebt input) {
    return _DebtState(
      name: input.name,
      balance: input.balance,
      annualRate: input.annualRate,
      minimumPaymentRate: input.minimumPaymentRate,
      minimumPaymentFloor: input.minimumPaymentFloor,
      paymentDay: input.paymentDay,
    );
  }

  _DebtState copy() {
    return _DebtState(
      name: name,
      balance: balance,
      annualRate: annualRate,
      minimumPaymentRate: minimumPaymentRate,
      minimumPaymentFloor: minimumPaymentFloor,
      paymentDay: paymentDay,
    );
  }
}

class _SimulationResult {
  final List<DebtMonthlyAction> monthlyActions;
  final List<DebtRoadmapStep> roadmap;
  final int? estimatedCompletionMonths;
  final List<String> warnings;

  const _SimulationResult({
    required this.monthlyActions,
    required this.roadmap,
    required this.estimatedCompletionMonths,
    required this.warnings,
  });
}
