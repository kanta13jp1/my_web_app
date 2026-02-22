import 'dart:math';

import 'package:intl/intl.dart';
import 'package:my_web_app/models/debt_repayment_plan.dart';

class DebtRepaymentPlannerService {
  const DebtRepaymentPlannerService();

  static const double _epsilon = 0.01;

  DebtRepaymentInputDebt normalizeDebt({
    required String name,
    required double balance,
  }) {
    final assumption = _assumptionForName(name);
    return DebtRepaymentInputDebt(
      name: name,
      balance: balance.abs(),
      annualRate: assumption.annualRate,
      minimumPaymentRate: assumption.minimumPaymentRate,
      minimumPaymentFloor: assumption.minimumPaymentFloor,
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
        requestedMonthlyBudget:
            max(0, input.monthlyBudget + input.extraBudget).toDouble(),
        affordableMonthlyBudget:
            max(0, input.monthlyIncome - input.monthlyExpense).toDouble(),
        estimatedCompletionMonths: 0,
        canMeetTargetMonths: true,
      );
    }

    final priorities = _buildPriorities(
      debts: sourceDebts,
      strategy: input.strategy,
    );

    final requestedMonthlyBudget =
        max(0, input.monthlyBudget + input.extraBudget).toDouble();
    final affordableMonthlyBudget =
        max(0, input.monthlyIncome - input.monthlyExpense).toDouble();

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

    final canMeetTargetMonths = estimatedCompletionMonths != null &&
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
        reason: _priorityReason(
          debt: debt,
          strategy: strategy,
        ),
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
          monthStart:
              DateTime(baseMonth.year, baseMonth.month + monthIndex - 1),
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
      final monthsRequired =
          endMonth == null ? null : max(1, endMonth - startMonth + 1);
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
        return '残高が小さく、完済件数を早く増やせるため';
      case DebtRepaymentStrategy.avalanche:
        return '推定金利 ${_percent(debt.annualRate)} と高く、利息削減効果が大きいため';
      case DebtRepaymentStrategy.hybrid:
        if (debt.annualRate >= 0.15) {
          return '高金利帯で、放置時の利息負担が大きいため';
        }
        return '残高圧縮と利息削減の両立を優先するため';
    }
  }

  double _minimumPayment(_DebtState debt) {
    final byRate = debt.balance * debt.minimumPaymentRate;
    final minimum = max(byRate, debt.minimumPaymentFloor);
    return min(minimum, debt.balance);
  }

  _DebtAssumption _assumptionForName(String name) {
    final key = name.toLowerCase();

    if (_containsAny(
      key,
      const ['アコム', 'モビット', 'プロミス', 'レイク', 'アイフル'],
    )) {
      return const _DebtAssumption(
        annualRate: 0.18,
        minimumPaymentRate: 0.04,
        minimumPaymentFloor: 4000,
      );
    }

    if (_containsAny(
      key,
      const ['paypay', 'aupay', 'カード', 'クレジット', 'リボ', 'ショッピング'],
    )) {
      return const _DebtAssumption(
        annualRate: 0.15,
        minimumPaymentRate: 0.03,
        minimumPaymentFloor: 3000,
      );
    }

    if (_containsAny(
      key,
      const ['銀行', 'ローン', 'じぶん', '三井住友', '横浜'],
    )) {
      return const _DebtAssumption(
        annualRate: 0.14,
        minimumPaymentRate: 0.03,
        minimumPaymentFloor: 3000,
      );
    }

    if (_containsAny(
      key,
      const ['通信', '携帯', '税', '公共', '滞納', 'au'],
    )) {
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

    buffer.writeln('### 現状診断');
    buffer.writeln(
      '- 純資産は ${_yen(input.netWorth)}、借入残高は ${_yen(currentDebt)} です。',
    );
    buffer.writeln(
      '- 今月収支は 収入 ${_yen(input.monthlyIncome)} / 支出 ${_yen(input.monthlyExpense)} / 固定費 ${_yen(input.fixedCost)} です。',
    );
    buffer.writeln(
      '- 返済予算は 月次 ${_yen(input.monthlyBudget)} + 臨時 ${_yen(input.extraBudget)} = ${_yen(requestedMonthlyBudget)} を前提に試算しています。',
    );
    buffer.writeln(
      '- 実収支から見た安全側の返済可能額は ${_yen(affordableMonthlyBudget)} です。',
    );
    if (input.note.trim().isNotEmpty) {
      buffer.writeln('- 追加メモ: ${input.note.trim()}');
    }
    buffer.writeln('');

    buffer.writeln('### 返済優先順位（$strategyLabel）');
    for (final item in priorities) {
      buffer.writeln(
        '${item.rank}. **${item.name}** 残高 ${_yen(item.balance)} / 推定年利 ${_percent(item.annualRate)}（${item.reason}）',
      );
    }
    buffer.writeln('');

    buffer.writeln('### 3ヶ月アクションプラン');
    buffer.writeln('| 月 | 今月の目標 | 具体アクション |');
    buffer.writeln('|---|---|---|');

    for (var i = 0; i < 3; i++) {
      final action = i < monthlyActions.length ? monthlyActions[i] : null;
      final monthStart = action?.monthStart ??
          DateTime(input.baseMonth.year, input.baseMonth.month + i);
      final monthLabel = DateFormat('yyyy/MM').format(monthStart);
      final role = _monthRole(i);

      final goal =
          action == null ? '返済原資の確保と優先順位の再確認' : _buildGoalText(action: action);
      final actionText = action == null
          ? '最低返済額と実収支を確認し、予算差額を埋める施策を実行する'
          : _buildActionText(action: action);

      buffer.writeln('| $role ($monthLabel) | $goal | $actionText |');
    }
    buffer.writeln('');

    buffer.writeln('### 完済までのロードマップ（月次）');
    for (final step in roadmap) {
      if (step.endMonth == null) {
        buffer.writeln(
          '- ${step.name}: ${step.startMonth}ヶ月目〜（未完了）',
        );
      } else {
        buffer.writeln(
          '- ${step.name}: ${step.startMonth}〜${step.endMonth}ヶ月目（${step.monthsRequired}ヶ月）',
        );
      }
    }
    if (estimatedCompletionMonths == null) {
      buffer.writeln('- 試算完済時期: 設定予算では未確定');
    } else {
      buffer.writeln('- 試算完済時期: 約$estimatedCompletionMonthsヶ月');
      if (estimatedCompletionMonths > input.targetMonths) {
        buffer.writeln(
          '- 目標期間との差分: 約${estimatedCompletionMonths - input.targetMonths}ヶ月超過',
        );
      } else {
        buffer.writeln('- 目標期間: 達成見込み');
      }
    }
    buffer.writeln('');

    buffer.writeln('### 今週やること');
    buffer.writeln(
      '1. 全借入先の実金利・最低返済額・返済日を確認し、推定値を実数値へ更新する。',
    );
    buffer.writeln(
      '2. 固定費と変動費を棚卸しし、今月中に削減・停止できる支出を最低3件実行する。',
    );
    buffer.writeln(
      '3. 返済原資が不足する場合は、公的窓口または弁護士・司法書士の無料相談を予約する。',
    );

    if (warnings.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('### 注意点');
      for (final warning in warnings) {
        buffer.writeln('- $warning');
      }
    }

    buffer.writeln('');
    buffer.writeln('※ 金利は借入先名からの推定値です。実契約値に置き換えて再計算してください。');

    return buffer.toString().trim();
  }

  String _buildGoalText({
    required DebtMonthlyAction action,
  }) {
    final closedText = action.closedDebts.isEmpty
        ? ''
        : ' / 完済候補: ${action.closedDebts.join('・')}';
    final focus = action.focusDebt ?? '返済原資の確保';
    return '重点: $focus$closedText';
  }

  String _buildActionText({
    required DebtMonthlyAction action,
  }) {
    if (action.isBudgetShortfall) {
      return '最低返済 ${_yen(action.minimumTotal)} に対して予算不足。まず収入増加と固定費削減を優先';
    }
    return '支払 ${_yen(action.paymentTotal)}（最低返済 ${_yen(action.minimumTotal)} + 上乗せ ${_yen(action.extraTotal)}）を実行';
  }

  String _strategyLabel(DebtRepaymentStrategy strategy) {
    switch (strategy) {
      case DebtRepaymentStrategy.snowball:
        return '少額優先（スノーボール）';
      case DebtRepaymentStrategy.avalanche:
        return '高金利優先（アバランチ）';
      case DebtRepaymentStrategy.hybrid:
        return 'ハイブリッド（高金利×少額）';
    }
  }

  String _monthRole(int index) {
    if (index == 0) return '今月';
    if (index == 1) return '来月';
    return '再来月';
  }

  String _yen(num value) {
    final format = NumberFormat('#,###');
    return '¥${format.format(value.round())}';
  }

  String _percent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
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

  _DebtState({
    required this.name,
    required this.balance,
    required this.annualRate,
    required this.minimumPaymentRate,
    required this.minimumPaymentFloor,
  });

  factory _DebtState.fromInput(DebtRepaymentInputDebt input) {
    return _DebtState(
      name: input.name,
      balance: input.balance,
      annualRate: input.annualRate,
      minimumPaymentRate: input.minimumPaymentRate,
      minimumPaymentFloor: input.minimumPaymentFloor,
    );
  }

  _DebtState copy() {
    return _DebtState(
      name: name,
      balance: balance,
      annualRate: annualRate,
      minimumPaymentRate: minimumPaymentRate,
      minimumPaymentFloor: minimumPaymentFloor,
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
