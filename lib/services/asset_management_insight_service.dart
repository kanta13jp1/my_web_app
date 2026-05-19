import '../models/asset_liability_workbook.dart';

enum AssetManagementInsightActionType {
  missingInput,
  missingPaymentDay,
  missingAnnualRate,
  missingPaymentSource,
  overduePayment,
  upcomingPayment,
  cashShortageRisk,
  emergencyLivingExpense,
  cardBillingConfiguration,
  doubleCountingRisk,
}

enum AssetManagementInsightSeverity { info, warning, critical }

enum AssetManagementInsightWindow { today, week, month }

class AssetManagementInsightActionItem {
  final AssetManagementInsightActionType type;
  final AssetManagementInsightSeverity severity;
  final String title;
  final String description;
  final String? relatedAccountId;
  final DateTime? dueDate;
  final int? paymentDay;
  final String suggestedAction;

  const AssetManagementInsightActionItem({
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.relatedAccountId,
    required this.dueDate,
    required this.paymentDay,
    required this.suggestedAction,
  });
}

class AssetManagementAvailableMoneyInsight {
  final AssetManagementInsightWindow window;
  final DateTime startDate;
  final DateTime endDate;
  final double cashLikeTotal;
  final double unpaidPaymentTotal;
  final double unreceivedIncomeTotal;
  final double minimumSafetyBalance;
  final double availableAmount;
  final String summary;

  const AssetManagementAvailableMoneyInsight({
    required this.window,
    required this.startDate,
    required this.endDate,
    required this.cashLikeTotal,
    required this.unpaidPaymentTotal,
    required this.unreceivedIncomeTotal,
    required this.minimumSafetyBalance,
    required this.availableAmount,
    required this.summary,
  });
}

class AssetManagementMovementSuggestion {
  final String fromAccountId;
  final String fromAccountName;
  final String? toAccountId;
  final String? toAccountName;
  final double amount;
  final DateTime? neededBy;
  final String reason;

  const AssetManagementMovementSuggestion({
    required this.fromAccountId,
    required this.fromAccountName,
    required this.toAccountId,
    required this.toAccountName,
    required this.amount,
    required this.neededBy,
    required this.reason,
  });
}

class AssetManagementDeveloperRequest {
  final String title;
  final String description;
  final AssetManagementInsightSeverity severity;

  const AssetManagementDeveloperRequest({
    required this.title,
    required this.description,
    required this.severity,
  });
}

class AssetManagementEmergencyAdvice {
  final AssetManagementInsightSeverity severity;
  final String title;
  final String description;
  final String suggestedAction;
  final double? amount;

  const AssetManagementEmergencyAdvice({
    required this.severity,
    required this.title,
    required this.description,
    required this.suggestedAction,
    required this.amount,
  });
}

class AssetManagementInsightReport {
  final List<AssetManagementInsightActionItem> actionItems;
  final AssetManagementAvailableMoneyInsight todayAvailable;
  final AssetManagementAvailableMoneyInsight weekAvailable;
  final AssetManagementAvailableMoneyInsight monthAvailable;
  final List<AssetManagementMovementSuggestion> movementSuggestions;
  final List<AssetManagementEmergencyAdvice> emergencyAdvices;
  final List<AssetManagementDeveloperRequest> developerRequests;

  const AssetManagementInsightReport({
    required this.actionItems,
    required this.todayAvailable,
    required this.weekAvailable,
    required this.monthAvailable,
    required this.movementSuggestions,
    required this.emergencyAdvices,
    required this.developerRequests,
  });

  bool get hasCriticalActions {
    return actionItems.any(
      (item) => item.severity == AssetManagementInsightSeverity.critical,
    );
  }

  List<AssetManagementInsightActionItem> get criticalActions {
    return actionItems
        .where(
          (item) => item.severity == AssetManagementInsightSeverity.critical,
        )
        .toList(growable: false);
  }
}

class AssetManagementInsightService {
  static const double defaultMinimumSafetyBalance = 10000;
  static const int defaultUpcomingPaymentWarningDays = 3;

  const AssetManagementInsightService();

  AssetManagementInsightReport buildReport({
    required AssetLiabilityWorkbook workbook,
    double minimumSafetyBalance = defaultMinimumSafetyBalance,
    int upcomingPaymentWarningDays = defaultUpcomingPaymentWarningDays,
  }) {
    final actions = _buildActionItems(
      workbook: workbook,
      upcomingPaymentWarningDays: upcomingPaymentWarningDays,
      minimumSafetyBalance: minimumSafetyBalance,
    )..sort(_compareActionItems);
    final today = _buildAvailableMoneyInsight(
      workbook: workbook,
      window: AssetManagementInsightWindow.today,
      startDate: _dateOnly(workbook.baseDate),
      endDate: _dateOnly(workbook.baseDate),
      minimumSafetyBalance: minimumSafetyBalance,
    );
    final week = _buildAvailableMoneyInsight(
      workbook: workbook,
      window: AssetManagementInsightWindow.week,
      startDate: _dateOnly(workbook.baseDate),
      endDate: _dateOnly(workbook.baseDate).add(const Duration(days: 6)),
      minimumSafetyBalance: minimumSafetyBalance,
    );
    final month = _buildAvailableMoneyInsight(
      workbook: workbook,
      window: AssetManagementInsightWindow.month,
      startDate: DateTime(workbook.baseDate.year, workbook.baseDate.month),
      endDate: DateTime(workbook.baseDate.year, workbook.baseDate.month + 1, 0),
      minimumSafetyBalance: minimumSafetyBalance,
    );
    final movementSuggestions = _buildMovementSuggestions(
      workbook: workbook,
      windows: <AssetManagementAvailableMoneyInsight>[today, week, month],
      minimumSafetyBalance: minimumSafetyBalance,
    );
    final emergencyAdvices = _buildEmergencyAdvices(
      workbook: workbook,
      today: today,
      week: week,
      month: month,
      movementSuggestions: movementSuggestions,
    );
    final developerRequests = _buildDeveloperRequests(
      workbook: workbook,
      actions: actions,
      movementSuggestions: movementSuggestions,
    );

    return AssetManagementInsightReport(
      actionItems: actions,
      todayAvailable: today,
      weekAvailable: week,
      monthAvailable: month,
      movementSuggestions: movementSuggestions,
      emergencyAdvices: emergencyAdvices,
      developerRequests: developerRequests,
    );
  }

  List<AssetManagementInsightActionItem> _buildActionItems({
    required AssetLiabilityWorkbook workbook,
    required int upcomingPaymentWarningDays,
    required double minimumSafetyBalance,
  }) {
    final actions = <AssetManagementInsightActionItem>[];
    final today = _dateOnly(workbook.baseDate);
    final upcomingLimit = today.add(Duration(days: upcomingPaymentWarningDays));

    for (final row in workbook.debtMasterRows) {
      if (row.paymentAmountEstimated && row.isDirectCashflowTarget) {
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.missingInput,
            severity: AssetManagementInsightSeverity.info,
            title: '${row.name}の今月支払予定額を確認',
            description: '実請求額が未入力のため、推定最低支払額で資金繰りに入っています。',
            relatedAccountId: row.id,
            dueDate: _paymentDateFor(row, workbook.baseDate),
            paymentDay: row.paymentDay,
            suggestedAction: '請求確定後に今月支払予定額を入力してください。',
          ),
        );
      }
      if (row.paymentDay == null) {
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.missingPaymentDay,
            severity: AssetManagementInsightSeverity.warning,
            title: '${row.name}の支払日が未入力です',
            description: '支払日がないため、支払日順資金繰りで正しい危険日を判断しにくい状態です。',
            relatedAccountId: row.id,
            dueDate: null,
            paymentDay: null,
            suggestedAction: '契約画面または請求明細で支払日を確認して入力してください。',
          ),
        );
      }
      if (_needsAnnualRate(row)) {
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.missingAnnualRate,
            severity: AssetManagementInsightSeverity.warning,
            title: '${row.name}の利率を確認',
            description: 'カードローン・カード系の金利が未入力のため、返済優先度の判断精度が落ちます。',
            relatedAccountId: row.id,
            dueDate: _paymentDateFor(row, workbook.baseDate),
            paymentDay: row.paymentDay,
            suggestedAction: '契約中の年利を確認し、負債マスタへ入力してください。',
          ),
        );
      }
      if (row.isDirectCashflowTarget &&
          !row.paid &&
          (row.paymentSourceAccountId == null ||
              row.paymentSourceAccountId!.trim().isEmpty)) {
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.missingPaymentSource,
            severity: AssetManagementInsightSeverity.warning,
            title: '${row.name}の支払原資口座が未設定です',
            description: 'どの口座から引き落とすか未設定のため、口座別資金繰りに反映しにくい状態です。',
            relatedAccountId: row.id,
            dueDate: _paymentDateFor(row, workbook.baseDate),
            paymentDay: row.paymentDay,
            suggestedAction: '通常使う引落口座をデフォルト、または今月だけ上書きで設定してください。',
          ),
        );
      }
    }

    for (final row in workbook.cashflowRows.where((row) => row.isPayment)) {
      if (!row.isDirectCashflowTarget || row.paid) {
        continue;
      }
      if (row.overdue) {
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.overduePayment,
            severity: AssetManagementInsightSeverity.critical,
            title: '${row.accountName}が期限超過です',
            description: '支払日を過ぎた未払い予定があります。',
            relatedAccountId: row.accountId,
            dueDate: row.paymentDate,
            paymentDay: row.paymentDay,
            suggestedAction: '残高と引落状況を確認し、支払済みならチェックを更新してください。',
          ),
        );
      } else if (!row.paymentDate.isBefore(today) &&
          !row.paymentDate.isAfter(upcomingLimit)) {
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.upcomingPayment,
            severity: AssetManagementInsightSeverity.warning,
            title: '${row.accountName}の支払日が近づいています',
            description: '${_formatYen(row.paymentAmount)}の支払いが近づいています。',
            relatedAccountId: row.accountId,
            dueDate: row.paymentDate,
            paymentDay: row.paymentDay,
            suggestedAction: '支払原資口座の残高を確認してください。',
          ),
        );
      }
      if (row.riskLevel == AssetLiabilityCashRiskLevel.short) {
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.cashShortageRisk,
            severity: AssetManagementInsightSeverity.critical,
            title: '${row.accountName}支払い後に資金ショートします',
            description: '支払後手元資金が${_formatYen(row.cashAfterPayment)}になります。',
            relatedAccountId: row.accountId,
            dueDate: row.paymentDate,
            paymentDay: row.paymentDay,
            suggestedAction: '支払い前に口座移動または出金を行ってください。',
          ),
        );
      }
    }

    final todayInsight = _buildAvailableMoneyInsight(
      workbook: workbook,
      window: AssetManagementInsightWindow.today,
      startDate: today,
      endDate: today,
      minimumSafetyBalance: minimumSafetyBalance,
    );
    if (todayInsight.availableAmount < 0) {
      actions.add(
        AssetManagementInsightActionItem(
          type: AssetManagementInsightActionType.emergencyLivingExpense,
          severity: AssetManagementInsightSeverity.critical,
          title: '本日の生活費が不足しています',
          description:
              '本日使用可能額が${_formatYen(todayInsight.availableAmount)}です。水だけで過ごすなど、健康を削る判断はしないでください。',
          relatedAccountId: null,
          dueDate: today,
          paymentDay: today.day,
          suggestedAction:
              '支払いを実行する前に、今日の食費・移動費・医療など最低限の生活費を先に確保し、払えない支払いは支払先へ猶予または分割相談をしてください。',
        ),
      );
    }

    for (final item in workbook.cardBillingReview.needsReviewItems) {
      actions.add(
        AssetManagementInsightActionItem(
          type: AssetManagementInsightActionType.cardBillingConfiguration,
          severity: AssetManagementInsightSeverity.warning,
          title: '${item.accountName}のカード請求設定を確認',
          description: item.alerts.join(' / '),
          relatedAccountId: item.accountId,
          dueDate: item.paymentDay == null
              ? null
              : _paymentDateFromDay(workbook.baseDate, item.paymentDay!),
          paymentDay: item.paymentDay,
          suggestedAction: 'カード請求に含める設定と請求先カードを確認してください。',
        ),
      );
    }

    for (final item in workbook.cardBillingReview.doubleCountingRiskItems) {
      actions.add(
        AssetManagementInsightActionItem(
          type: AssetManagementInsightActionType.doubleCountingRisk,
          severity: AssetManagementInsightSeverity.critical,
          title: '${item.accountName}に二重計上リスクがあります',
          description: '直接支払いとカード請求内訳の両方で計算される可能性があります。',
          relatedAccountId: item.accountId,
          dueDate: item.paymentDay == null
              ? null
              : _paymentDateFromDay(workbook.baseDate, item.paymentDay!),
          paymentDay: item.paymentDay,
          suggestedAction: '支払い方式を直接支払いまたはカード請求に含めるのどちらかへ整理してください。',
        ),
      );
    }

    return actions;
  }

  AssetManagementAvailableMoneyInsight _buildAvailableMoneyInsight({
    required AssetLiabilityWorkbook workbook,
    required AssetManagementInsightWindow window,
    required DateTime startDate,
    required DateTime endDate,
    required double minimumSafetyBalance,
  }) {
    final payments = _paymentTotalForWindow(
      workbook: workbook,
      startDate: startDate,
      endDate: endDate,
    );
    final income = _incomeTotalForWindow(
      workbook: workbook,
      startDate: startDate,
      endDate: endDate,
    );
    final available =
        workbook.cashLikeTotal + income - payments - minimumSafetyBalance;
    return AssetManagementAvailableMoneyInsight(
      window: window,
      startDate: startDate,
      endDate: endDate,
      cashLikeTotal: workbook.cashLikeTotal,
      unpaidPaymentTotal: payments,
      unreceivedIncomeTotal: income,
      minimumSafetyBalance: minimumSafetyBalance,
      availableAmount: available,
      summary: _availableSummary(window, available),
    );
  }

  List<AssetManagementMovementSuggestion> _buildMovementSuggestions({
    required AssetLiabilityWorkbook workbook,
    required List<AssetManagementAvailableMoneyInsight> windows,
    required double minimumSafetyBalance,
  }) {
    final suggestions = <AssetManagementMovementSuggestion>[
      for (final suggestion in workbook.transferSuggestions)
        AssetManagementMovementSuggestion(
          fromAccountId: suggestion.fromAccountId,
          fromAccountName: suggestion.fromAccountName,
          toAccountId: suggestion.toAccountId,
          toAccountName: suggestion.toAccountName,
          amount: suggestion.amount,
          neededBy: suggestion.neededBy,
          reason: '口座別資金繰りで不足が見込まれています。',
        ),
    ];

    final worstWindow = windows
        .where((window) => window.availableAmount < 0)
        .toList()
      ..sort((a, b) => a.availableAmount.compareTo(b.availableAmount));
    if (worstWindow.isEmpty) {
      return _dedupeSuggestions(suggestions);
    }

    var needed = worstWindow.first.availableAmount.abs();
    final donors = workbook.accounts
        .where(
          (account) =>
              account.balance > minimumSafetyBalance &&
              (account.kind == AssetLiabilityAccountKind.cash ||
                  account.kind == AssetLiabilityAccountKind.deposit ||
                  account.kind == AssetLiabilityAccountKind.otherAsset),
        )
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));

    for (final donor in donors) {
      if (needed <= 0) {
        break;
      }
      final surplus = donor.balance - minimumSafetyBalance;
      if (surplus <= 0) {
        continue;
      }
      final amount = surplus < needed ? surplus : needed;
      if (amount <= 0) {
        continue;
      }
      suggestions.add(
        AssetManagementMovementSuggestion(
          fromAccountId: donor.id,
          fromAccountName: donor.name,
          toAccountId: null,
          toAccountName: null,
          amount: amount,
          neededBy: worstWindow.first.endDate,
          reason: '${_windowLabel(worstWindow.first.window)}の使用可能額が不足しています。',
        ),
      );
      needed -= amount;
    }

    return _dedupeSuggestions(suggestions);
  }

  List<AssetManagementEmergencyAdvice> _buildEmergencyAdvices({
    required AssetLiabilityWorkbook workbook,
    required AssetManagementAvailableMoneyInsight today,
    required AssetManagementAvailableMoneyInsight week,
    required AssetManagementAvailableMoneyInsight month,
    required List<AssetManagementMovementSuggestion> movementSuggestions,
  }) {
    final windows = <AssetManagementAvailableMoneyInsight>[today, week, month]
      ..sort((a, b) => a.availableAmount.compareTo(b.availableAmount));
    final worst = windows.first;
    final hasShortage = windows.any((window) => window.availableAmount < 0);
    if (!hasShortage) {
      return const <AssetManagementEmergencyAdvice>[];
    }

    final nextIncome = _nextIncomePlan(workbook);
    final shortfall =
        worst.availableAmount < 0 ? worst.availableAmount.abs() : 0.0;
    final advices = <AssetManagementEmergencyAdvice>[];

    if (today.availableAmount < 0) {
      advices.add(
        AssetManagementEmergencyAdvice(
          severity: AssetManagementInsightSeverity.critical,
          title: '今日の食費を先に確保してください',
          description:
              '本日使用可能額が${_formatYen(today.availableAmount)}です。給料日まで水だけで耐える方針は危険です。支払いより先に、今日食べるためのお金を隔離してください。',
          suggestedAction:
              '財布または引落口座とは別の口座に、最低でも今日の食費1,000〜1,500円と移動費を残してください。残せない場合は、家族・知人・自治体窓口・フードバンクへ今日中に相談してください。',
          amount: today.availableAmount.abs(),
        ),
      );
    }

    if (shortfall > 0) {
      advices.add(
        AssetManagementEmergencyAdvice(
          severity: AssetManagementInsightSeverity.critical,
          title: '払う順番を一度止めて組み替えてください',
          description:
              '${_windowLabel(worst.window)}の不足額は${_formatYen(shortfall)}です。全支払いを予定通り払う前提だと生活費が残りません。',
          suggestedAction:
              '優先順位は「食費・通勤・住居/公共料金の継続」→「期限超過の連絡」→「カード/ローンの猶予・分割相談」です。支払先へ、今日中に支払日変更・最低額変更・一時猶予を相談してください。',
          amount: shortfall,
        ),
      );
    }

    if (movementSuggestions.isNotEmpty) {
      final suggestion = movementSuggestions.first;
      advices.add(
        AssetManagementEmergencyAdvice(
          severity: AssetManagementInsightSeverity.warning,
          title: '口座移動または出金を先に実行してください',
          description:
              '${suggestion.fromAccountName}から${_formatYen(suggestion.amount)}を動かす候補があります。',
          suggestedAction:
              '支払い前にこの移動を実行し、生活費用の残高を確認してください。移動後も不足する場合は、その支払いは払う前に支払先へ連絡してください。',
          amount: suggestion.amount,
        ),
      );
    }

    if (nextIncome == null) {
      advices.add(
        const AssetManagementEmergencyAdvice(
          severity: AssetManagementInsightSeverity.warning,
          title: '次の入金予定を登録してください',
          description: '給料日や入金予定が未登録のため、何日分の生活費を守るべきか判断しにくい状態です。',
          suggestedAction:
              '給料日・金額・入金先口座を収入予定に入れてください。登録後、AIアシスタントが給料日までの不足額を再計算します。',
          amount: null,
        ),
      );
    } else {
      advices.add(
        AssetManagementEmergencyAdvice(
          severity: AssetManagementInsightSeverity.info,
          title: '次の入金日までの生活費を分けてください',
          description:
              '次の入金予定は${_formatDate(nextIncome.date)}の${nextIncome.name} ${_formatYen(nextIncome.amount)}です。',
          suggestedAction:
              'この入金日までに必要な食費を先に確保し、残額だけを支払いに回してください。入金前に資金が尽きる場合は支払い猶予の相談を優先してください。',
          amount: nextIncome.amount,
        ),
      );
    }

    advices.add(
      const AssetManagementEmergencyAdvice(
        severity: AssetManagementInsightSeverity.info,
        title: '公的・地域の緊急支援も候補に入れてください',
        description: '食費が確保できない場合は、アプリ内の節約だけではなく外部支援を使う局面です。',
        suggestedAction:
            '自治体の生活困窮者自立支援窓口、社会福祉協議会、フードバンク、緊急小口資金の相談先を今日確認してください。',
        amount: null,
      ),
    );

    return advices;
  }

  AssetLiabilityIncomePlan? _nextIncomePlan(AssetLiabilityWorkbook workbook) {
    final today = _dateOnly(workbook.baseDate);
    final plans = workbook.incomePlans
        .where(
          (plan) =>
              !plan.received &&
              plan.amount > 0 &&
              !_dateOnly(plan.date).isBefore(today),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return plans.isEmpty ? null : plans.first;
  }

  List<AssetManagementDeveloperRequest> _buildDeveloperRequests({
    required AssetLiabilityWorkbook workbook,
    required List<AssetManagementInsightActionItem> actions,
    required List<AssetManagementMovementSuggestion> movementSuggestions,
  }) {
    final requests = <AssetManagementDeveloperRequest>[];
    if (workbook.debtMasterRows.any((row) => row.paymentAmountEstimated)) {
      requests.add(
        const AssetManagementDeveloperRequest(
          title: '実支払額と推定額の差分管理',
          description:
              '現状では推定最低支払額と実際の引落額の差分を月次で記録しにくいです。カード請求内訳の実績差分管理機能を追加してください。',
          severity: AssetManagementInsightSeverity.info,
        ),
      );
    }
    if (actions.any(
      (action) =>
          action.type == AssetManagementInsightActionType.missingPaymentSource,
    )) {
      requests.add(
        const AssetManagementDeveloperRequest(
          title: '支払原資口座の未設定レビュー',
          description:
              '現状では支払原資口座が未設定のままでも運用できてしまいます。未設定項目を一括で確認・設定できる機能を追加してください。',
          severity: AssetManagementInsightSeverity.warning,
        ),
      );
    }
    if (workbook.cardBillingReview.hasNeedsReviewItems) {
      requests.add(
        const AssetManagementDeveloperRequest(
          title: 'カード請求内訳の設定監査',
          description:
              '現状ではカード請求に含める項目の請求先不整合を手動確認する必要があります。請求先カード未設定や削除済みカードを月次レビューで修正できる機能を強化してください。',
          severity: AssetManagementInsightSeverity.warning,
        ),
      );
    }
    if (movementSuggestions.isNotEmpty || workbook.hasAccountShortage) {
      requests.add(
        const AssetManagementDeveloperRequest(
          title: '口座間移動タスク管理',
          description:
              '現状では口座間移動の提案を完了タスクとして保存できません。移動候補をタスク化し、実行済み管理できる機能を追加してください。',
          severity: AssetManagementInsightSeverity.warning,
        ),
      );
    }
    if (requests.isEmpty) {
      requests.add(
        const AssetManagementDeveloperRequest(
          title: '月次レビュー履歴の強化',
          description:
              '現状ではAI資産管理アシスタントの確認結果を月次履歴へ保存していません。レビュー完了ログと改善メモを保存できる機能を追加してください。',
          severity: AssetManagementInsightSeverity.info,
        ),
      );
    }
    return requests;
  }

  double _paymentTotalForWindow({
    required AssetLiabilityWorkbook workbook,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return workbook.cashflowRows.fold<double>(0, (sum, row) {
      if (!row.isPayment ||
          !row.isDirectCashflowTarget ||
          row.paid ||
          row.paymentAmount <= 0) {
        return sum;
      }
      final date = _dateOnly(row.paymentDate);
      final inWindow = !date.isBefore(startDate) && !date.isAfter(endDate);
      final overdueForWindow =
          row.overdue && !endDate.isBefore(_dateOnly(workbook.baseDate));
      return inWindow || overdueForWindow ? sum + row.paymentAmount : sum;
    });
  }

  double _incomeTotalForWindow({
    required AssetLiabilityWorkbook workbook,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return workbook.cashflowRows.fold<double>(0, (sum, row) {
      if (!row.isIncome || row.received || row.paymentAmount <= 0) {
        return sum;
      }
      final date = _dateOnly(row.paymentDate);
      return !date.isBefore(startDate) && !date.isAfter(endDate)
          ? sum + row.paymentAmount
          : sum;
    });
  }

  bool _needsAnnualRate(AssetLiabilityDebtRow row) {
    if (row.annualRate > 0) {
      return false;
    }
    return switch (row.kind) {
      AssetLiabilityAccountKind.cardLoan ||
      AssetLiabilityAccountKind.shoppingDebt ||
      AssetLiabilityAccountKind.creditCard ||
      AssetLiabilityAccountKind.otherLiability =>
        true,
      _ => false,
    };
  }

  List<AssetManagementMovementSuggestion> _dedupeSuggestions(
    List<AssetManagementMovementSuggestion> suggestions,
  ) {
    final seen = <String>{};
    final result = <AssetManagementMovementSuggestion>[];
    for (final suggestion in suggestions) {
      final key =
          '${suggestion.fromAccountId}|${suggestion.toAccountId}|${suggestion.amount.round()}';
      if (seen.add(key)) {
        result.add(suggestion);
      }
    }
    return result;
  }

  int _compareActionItems(
    AssetManagementInsightActionItem a,
    AssetManagementInsightActionItem b,
  ) {
    final severity = _severityRank(
      b.severity,
    ).compareTo(_severityRank(a.severity));
    if (severity != 0) {
      return severity;
    }
    final aDate = a.dueDate ?? DateTime(9999);
    final bDate = b.dueDate ?? DateTime(9999);
    final date = aDate.compareTo(bDate);
    if (date != 0) {
      return date;
    }
    return a.title.compareTo(b.title);
  }

  int _severityRank(AssetManagementInsightSeverity severity) {
    return switch (severity) {
      AssetManagementInsightSeverity.critical => 3,
      AssetManagementInsightSeverity.warning => 2,
      AssetManagementInsightSeverity.info => 1,
    };
  }

  DateTime? _paymentDateFor(AssetLiabilityDebtRow row, DateTime baseDate) {
    if (row.paymentDay == null) {
      return null;
    }
    return _paymentDateFromDay(baseDate, row.paymentDay!);
  }

  DateTime _paymentDateFromDay(DateTime baseDate, int day) {
    final lastDay = DateTime(baseDate.year, baseDate.month + 1, 0).day;
    return DateTime(baseDate.year, baseDate.month, day.clamp(1, lastDay));
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _availableSummary(AssetManagementInsightWindow window, double amount) {
    final label = _windowLabel(window);
    if (amount < 0) {
      return '$labelの使用可能額は${_formatYen(amount)}です。支払い前に資金移動を確認してください。';
    }
    return '$labelの使用可能額は${_formatYen(amount)}です。';
  }

  String _windowLabel(AssetManagementInsightWindow window) {
    return switch (window) {
      AssetManagementInsightWindow.today => '本日',
      AssetManagementInsightWindow.week => '今週',
      AssetManagementInsightWindow.month => '今月',
    };
  }

  String _formatYen(double amount) {
    final sign = amount < 0 ? '-' : '';
    final digits = amount.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i += 1) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$sign$buffer円';
  }

  String _formatDate(DateTime value) {
    return '${value.month}/${value.day}';
  }
}

class AssetManagementInsightPromptBuilder {
  const AssetManagementInsightPromptBuilder();

  String buildPrompt(AssetManagementInsightReport report) {
    final buffer = StringBuffer()
      ..writeln('あなたは資産管理AIアシスタントです。')
      ..writeln('重要: 金額計算はDart側で計算済みです。数値を再計算せず、説明と優先順位付けだけ行ってください。')
      ..writeln()
      ..writeln('## 使用可能額')
      ..writeln('- 本日: ${_formatAmount(report.todayAvailable.availableAmount)}')
      ..writeln('- 今週: ${_formatAmount(report.weekAvailable.availableAmount)}')
      ..writeln('- 今月: ${_formatAmount(report.monthAvailable.availableAmount)}')
      ..writeln()
      ..writeln('## アクションアイテム');
    if (report.actionItems.isEmpty) {
      buffer.writeln('- 重要なアクションはありません。');
    } else {
      for (final item in report.actionItems.take(12)) {
        buffer.writeln(
          '- [${item.severity.name}] ${item.title}: ${item.suggestedAction}',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('## 緊急生活防衛アドバイス');
    if (report.emergencyAdvices.isEmpty) {
      buffer.writeln('- 緊急の生活費不足アドバイスはありません。');
    } else {
      for (final advice in report.emergencyAdvices.take(6)) {
        buffer.writeln(
          '- [${advice.severity.name}] ${advice.title}: ${advice.suggestedAction}',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('## 口座移動/出金提案');
    if (report.movementSuggestions.isEmpty) {
      buffer.writeln('- 現時点で提案はありません。');
    } else {
      for (final suggestion in report.movementSuggestions.take(8)) {
        buffer.writeln(
          '- ${suggestion.fromAccountName}から${_formatAmount(suggestion.amount)}: ${suggestion.reason}',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('## 開発者向け改善提案');
    for (final request in report.developerRequests.take(8)) {
      buffer.writeln('- ${request.title}: ${request.description}');
    }
    return buffer.toString();
  }

  String buildRedactedPrompt(AssetManagementInsightReport report) {
    final severityCounts = _countBy(
      report.actionItems.map((item) => item.severity.name),
    );
    final typeCounts = _countBy(
      report.actionItems.map((item) => item.type.name),
    );
    final emergencyCounts = _countBy(
      report.emergencyAdvices.map((item) => item.severity.name),
    );
    final developerCounts = _countBy(
      report.developerRequests.map((item) => item.severity.name),
    );
    final buffer = StringBuffer()
      ..writeln('あなたは資産管理AIアシスタントです。')
      ..writeln(
        '重要: 金額計算はDart側で完了しています。下記の安全化された分類だけを使い、'
        '推測・再計算・正確な残高の追加要求はしないでください。',
      )
      ..writeln('出力は必ず日本語だけにしてください。見出し、ラベル、箇条書きも日本語にしてください。')
      ..writeln()
      ..writeln('## 安全化された使用可能額の状態')
      ..writeln('- 本日: ${_availabilityBand(report.todayAvailable)}')
      ..writeln('- 今週: ${_availabilityBand(report.weekAvailable)}')
      ..writeln('- 今月: ${_availabilityBand(report.monthAvailable)}')
      ..writeln()
      ..writeln('## アクション件数')
      ..writeln('- 合計: ${report.actionItems.length}')
      ..writeln('- 重要度別: ${_formatCounts(severityCounts)}')
      ..writeln('- 種別: ${_formatCounts(typeCounts)}')
      ..writeln()
      ..writeln('## 口座移動と緊急アドバイス')
      ..writeln('- 口座移動・出金提案件数: ${report.movementSuggestions.length}')
      ..writeln('- 緊急生活防衛アドバイス件数: ${report.emergencyAdvices.length}')
      ..writeln('- 緊急アドバイス重要度別: ${_formatCounts(emergencyCounts)}')
      ..writeln()
      ..writeln('## 開発者向け改善提案件数')
      ..writeln('- 合計: ${report.developerRequests.length}')
      ..writeln('- 重要度別: ${_formatCounts(developerCounts)}');
    return buffer.toString();
  }

  String _availabilityBand(AssetManagementAvailableMoneyInsight insight) {
    final amount = insight.availableAmount;
    if (amount < 0) return '不足';
    if (amount < insight.minimumSafetyBalance) return '安全残高未満';
    if (amount < insight.minimumSafetyBalance * 2) return '安全余力が薄い';
    return '余力あり';
  }

  Map<String, int> _countBy(Iterable<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts;
  }

  String _formatCounts(Map<String, int> counts) {
    if (counts.isEmpty) return 'none';
    final keys = counts.keys.toList(growable: false)..sort();
    return keys.map((key) => '$key=${counts[key]}').join(', ');
  }

  String _formatAmount(double amount) {
    final sign = amount < 0 ? '-' : '';
    final digits = amount.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i += 1) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$sign$buffer円';
  }
}
