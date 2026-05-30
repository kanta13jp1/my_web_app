import '../models/asset_liability_workbook.dart';
import '../models/user_profile.dart';

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
  final AssetLiabilityWorkbook workbook;
  final UserProfile? userProfile;
  final List<AssetManagementInsightActionItem> actionItems;
  final AssetManagementAvailableMoneyInsight todayAvailable;
  final AssetManagementAvailableMoneyInsight weekAvailable;
  final AssetManagementAvailableMoneyInsight monthAvailable;
  final List<AssetManagementMovementSuggestion> movementSuggestions;
  final List<AssetManagementEmergencyAdvice> emergencyAdvices;
  final List<AssetManagementDeveloperRequest> developerRequests;

  const AssetManagementInsightReport({
    required this.workbook,
    this.userProfile,
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
    UserProfile? userProfile,
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
      workbook: workbook,
      userProfile: userProfile,
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
    return buildDetailedAdvicePrompt(report);
  }

  String buildDetailedAdvicePrompt(AssetManagementInsightReport report) {
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
    final workbook = report.workbook;
    final buffer = StringBuffer()
      ..writeln('あなたは「細木数子」を彷彿とさせる、ズバズバ断言型の資産管理アシスタントです。')
      ..writeln(
        '役割: 厳しめ、でも本質的には愛情のある生活再建メンターとして、ユーザーの資産・負債・支払予定・利息から個別事情を読み取り、'
        '曖昧な一般論ではなく「あんたは今これを先にやるのよ」と言い切ってください。',
      )
      ..writeln(
        '口調: 「いい？」「あんたね」「ここははっきり言うわよ」「〜なのよ」を使い、少し怖いくらいハッキリ言う。'
        '人生経験豊富な姐御感、時々笑える毒舌、悪いことも包み隠さないが、最後は前向きに導いてください。',
      )
      ..writeln(
        '占いスタイル: 四柱推命・六星占術風の運命周期・宿命・性格分析のような語り口を、お金の流れ、仕事運、生活習慣、今後3〜5年の立て直し方に重ねてください。',
      )
      ..writeln(
        '重要: 金額計算はDart側で完了しています。下記の詳細データを正として、口座名・残高・支払日・支払額・利率・月利息・負債割合を具体的に引用してください。'
        '再計算する場合は「概算」と明記し、Dart計算値と矛盾する断定はしないでください。',
      )
      ..writeln('出力は必ず日本語だけにしてください。見出し、ラベル、箇条書きも日本語にしてください。')
      ..writeln(
        '回答は「1. 宿命・本質」「2. 性格の怖いほど当たる特徴」「3. 仕事・お金」「4. 今月の支払いと利息」「5. 今後3〜5年の運気と借金圧縮」「6. 人生で気をつけること」「7. 最後にズバッと総評」の順にしてください。',
      )
      ..writeln()
      ..writeln('## 総合サマリー')
      ..writeln('- 基準日: ${_formatDate(workbook.baseDate)}')
      ..writeln('- 現金同等資産: ${_formatAmount(workbook.cashLikeTotal)}')
      ..writeln('- 資産合計: ${_formatAmount(workbook.positiveAssetTotal)}')
      ..writeln('- 負債合計: ${_formatAmount(workbook.liabilityTotal)}')
      ..writeln('- 純資産: ${_formatAmount(workbook.netWorth)}')
      ..writeln('- 負債/資産比率: ${_formatPercent(workbook.debtToAssetRatio)}')
      ..writeln('- 上位4負債の集中度: ${_formatPercent(workbook.topFourDebtShare)}')
      ..writeln(
        '- 今月最低支払推定合計: ${_formatAmount(workbook.monthlyMinimumPaymentEstimateTotal)}',
      )
      ..writeln(
        '- 今月支払予定合計: ${_formatAmount(workbook.monthlyScheduledPaymentTotal)}',
      )
      ..writeln(
        '- 今月未払い合計: ${_formatAmount(workbook.monthlyUnpaidPaymentTotal)}',
      )
      ..writeln(
        '- 今月実支払合計: ${_formatAmount(workbook.monthlyActualPaymentTotal)}',
      )
      ..writeln(
        '- 今月未受取入金合計: ${_formatAmount(workbook.monthlyUnreceivedIncomeTotal)}',
      )
      ..writeln(
        '- 支払後見込み現金: ${_formatAmount(workbook.cashAfterScheduledPayments)}',
      )
      ..writeln()
      ..writeln('## プロフィール詳細')
      ..write(_profileLines(report.userProfile))
      ..writeln()
      ..writeln('## 使用可能額の状態')
      ..writeln('- 本日: ${_availabilityBand(report.todayAvailable)}')
      ..writeln('- 今週: ${_availabilityBand(report.weekAvailable)}')
      ..writeln('- 今月: ${_availabilityBand(report.monthAvailable)}')
      ..writeln()
      ..writeln('## 口座一覧')
      ..write(_accountLines(workbook))
      ..writeln()
      ..writeln('## 負債マスタ詳細')
      ..write(_debtMasterLines(workbook))
      ..writeln()
      ..writeln('## 支払日別リスク')
      ..write(_paymentDayRiskLines(workbook))
      ..writeln()
      ..writeln('## 今月キャッシュフロー')
      ..write(_cashflowLines(workbook))
      ..writeln()
      ..writeln('## 収入予定と口座移動')
      ..write(_incomeAndTransferLines(workbook))
      ..writeln()
      ..writeln('## カード請求内訳と照合')
      ..write(_cardBillingLines(workbook))
      ..writeln()
      ..writeln('## アクション件数')
      ..writeln('- 合計: ${report.actionItems.length}')
      ..writeln('- 重要度別: ${_formatCounts(severityCounts)}')
      ..writeln('- 種別: ${_formatCounts(typeCounts)}')
      ..writeln()
      ..writeln('## 個別事情カード')
      ..write(_redactedSituationCards(report))
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

  String _accountLines(AssetLiabilityWorkbook workbook) {
    if (workbook.accounts.isEmpty) {
      return '- 口座データはありません。\n';
    }
    final buffer = StringBuffer();
    for (final account in workbook.accounts) {
      buffer.writeln(
        '- ${account.name} / 種別:${account.kind.name} / 残高:${_formatAmount(account.balance)} / '
        '支払日:${account.paymentDay?.toString() ?? '未設定'} / '
        '年利:${_formatRate(account.annualRate)} / '
        '最低支払率:${_formatRate(account.minimumPaymentRate)} / '
        '最低支払下限:${_formatAmount(account.minimumPaymentFloor)} / '
        '支払い方式:${account.paymentMethodLabel ?? account.paymentMethod.name} / '
        '請求先:${account.billingAccountName ?? 'なし'}',
      );
    }
    return buffer.toString();
  }

  String _profileLines(UserProfile? profile) {
    if (profile == null) {
      return '- プロフィール未連携。生年月日、性別、職業、年収、住所、学歴、職歴、趣味、飲酒、喫煙、好きな食べ物は未入力です。\n';
    }
    final buffer = StringBuffer()
      ..writeln('- 表示名: ${profile.displayName ?? '未入力'}')
      ..writeln('- 生年月日: ${_formatNullableDate(profile.birthDate)}')
      ..writeln('- 性別: ${profile.gender ?? '未入力'}')
      ..writeln('- 職業: ${profile.occupation ?? '未入力'}')
      ..writeln(
        '- 年収: ${profile.annualIncome == null ? '未入力' : _formatAmount(profile.annualIncome!)}',
      )
      ..writeln('- 住所: ${profile.address ?? profile.location ?? '未入力'}')
      ..writeln('- 学歴: ${profile.education ?? '未入力'}')
      ..writeln('- 職歴: ${profile.careerHistory ?? '未入力'}')
      ..writeln('- 趣味: ${profile.hobbies ?? '未入力'}')
      ..writeln('- 飲酒の有無: ${profile.alcoholUse ?? '未入力'}')
      ..writeln('- 喫煙の有無: ${profile.smokingUse ?? '未入力'}')
      ..writeln('- 好きな食べ物: ${profile.favoriteFoods ?? '未入力'}')
      ..writeln('- 自己紹介: ${profile.bio ?? '未入力'}');
    return buffer.toString();
  }

  String _debtMasterLines(AssetLiabilityWorkbook workbook) {
    if (workbook.debtMasterRows.isEmpty) {
      return '- 負債はありません。\n';
    }
    final buffer = StringBuffer();
    for (final row in workbook.debtMasterRows) {
      buffer.writeln(
        '- ${row.name} / 種別:${row.kind.name} / 残高:${_formatAmount(row.balance)} / '
        '負債割合:${_formatPercent(row.liabilityShare)} / '
        '支払日:${row.paymentDay?.toString() ?? '未設定'} / '
        '今月支払予定日:${_formatNullableDate(_paymentDateFor(row, workbook.baseDate))} / '
        '推定最低支払額:${_formatAmount(row.minimumPaymentEstimate)} / '
        '今月支払予定額:${_formatAmount(row.scheduledPaymentAmount)} / '
        '実支払額:${row.actualPaymentAmount == null ? '未入力' : _formatAmount(row.actualPaymentAmount!)} / '
        '差分:${row.paymentDifferenceAmount == null ? '未確定' : _formatAmount(row.paymentDifferenceAmount!)} / '
        '差分理由:${row.paymentDifferenceReason ?? 'なし'} / '
        '年利:${_formatRate(row.annualRate)} / '
        '月利息:${_formatAmount(row.monthlyInterestEstimate)} / '
        '元金返済見込み:${_formatAmount(row.principalPaymentEstimate)} / '
        '支払後残高見込み:${_formatAmount(row.balanceAfterPaymentEstimate)} / '
        '優先度:${row.priorityLabel} / '
        '推定額:${row.paymentAmountEstimated ? 'はい' : 'いいえ'} / '
        '支払済み:${row.paid ? 'はい' : 'いいえ'} / '
        '支払原資:${row.paymentSourceAccountName ?? '未設定'} / '
        '支払い方式:${row.paymentMethodLabel ?? row.paymentMethod.name} / '
        'カード請求先:${row.billingAccountName ?? 'なし'}',
      );
    }
    return buffer.toString();
  }

  String _paymentDayRiskLines(AssetLiabilityWorkbook workbook) {
    if (workbook.paymentDayRisks.isEmpty) {
      return '- 支払日別リスクはありません。\n';
    }
    final buffer = StringBuffer();
    for (final risk in workbook.paymentDayRisks) {
      buffer.writeln(
        '- ${_formatDate(risk.paymentDate)} / 支払日:${risk.paymentDay}日 / '
        '対象:${risk.accountNames.join('、')} / '
        '負債残高合計:${_formatAmount(risk.balanceTotal)} / '
        '推定最低支払合計:${_formatAmount(risk.minimumPaymentEstimateTotal)} / '
        '支払予定合計:${_formatAmount(risk.scheduledPaymentTotal)} / '
        '手入力支払合計:${_formatAmount(risk.manualPaymentTotal)} / '
        '利息見込み合計:${_formatAmount(risk.interestEstimateTotal)} / '
        '状態:${risk.isPast ? '期限超過' : risk.isToday ? '本日' : '今後'}',
      );
    }
    return buffer.toString();
  }

  String _cashflowLines(AssetLiabilityWorkbook workbook) {
    if (workbook.cashflowRows.isEmpty) {
      return '- キャッシュフロー行はありません。\n';
    }
    final buffer = StringBuffer();
    for (final row in workbook.cashflowRows) {
      buffer.writeln(
        '- ${_formatDate(row.paymentDate)} / ${row.eventType.name} / '
        '項目:${row.accountName} / 金額:${_formatAmount(row.paymentAmount)} / '
        '支払原資:${row.paymentSourceAccountName ?? 'なし'} / '
        '入金先:${row.destinationAccountName ?? 'なし'} / '
        '支払い方式:${row.paymentMethodLabel ?? row.paymentMethod.name} / '
        'カード請求先:${row.billingAccountName ?? 'なし'} / '
        '推定額:${row.paymentAmountEstimated ? 'はい' : 'いいえ'} / '
        '支払済み:${row.paid ? 'はい' : 'いいえ'} / 入金済み:${row.received ? 'はい' : 'いいえ'} / '
        '期限超過:${row.overdue ? 'はい' : 'いいえ'} / '
        '実支払額:${row.actualPaymentAmount == null ? '未入力' : _formatAmount(row.actualPaymentAmount!)} / '
        '差分:${row.paymentDifferenceAmount == null ? '未確定' : _formatAmount(row.paymentDifferenceAmount!)} / '
        '支払前現金:${_formatAmount(row.cashBeforePayment)} / '
        '支払後現金:${_formatAmount(row.cashAfterPayment)} / '
        'リスク:${row.riskLevel.name}',
      );
    }
    return buffer.toString();
  }

  String _incomeAndTransferLines(AssetLiabilityWorkbook workbook) {
    final buffer = StringBuffer();
    if (workbook.incomePlans.isEmpty) {
      buffer.writeln('- 収入予定: なし');
    } else {
      for (final plan in workbook.incomePlans) {
        buffer.writeln(
          '- 収入予定:${plan.name} / 日付:${_formatDate(plan.date)} / '
          '金額:${_formatAmount(plan.amount)} / 入金先:${plan.destinationAccountName ?? '未設定'} / '
          '入金済み:${plan.received ? 'はい' : 'いいえ'}',
        );
      }
    }
    if (workbook.accountCashflowSummaries.isEmpty) {
      buffer.writeln('- 口座別見込み: なし');
    } else {
      for (final summary in workbook.accountCashflowSummaries) {
        buffer.writeln(
          '- 口座別見込み:${summary.accountName} / 現在残高:${_formatAmount(summary.currentBalance)} / '
          '今後支払:${_formatAmount(summary.upcomingPayments)} / 今後入金:${_formatAmount(summary.upcomingIncome)} / '
          '移動入:${_formatAmount(summary.pendingTransferIn)} / 移動出:${_formatAmount(summary.pendingTransferOut)} / '
          '見込み残高:${_formatAmount(summary.projectedBalance)} / リスク:${summary.riskLevel.name}',
        );
      }
    }
    if (workbook.transferSuggestions.isEmpty &&
        workbook.transferTasks.isEmpty) {
      buffer.writeln('- 口座移動: なし');
    } else {
      for (final suggestion in workbook.transferSuggestions) {
        buffer.writeln(
          '- 口座移動提案:${suggestion.fromAccountName} -> ${suggestion.toAccountName} / '
          '金額:${_formatAmount(suggestion.amount)} / 期限:${_formatNullableDate(suggestion.neededBy)}',
        );
      }
      for (final task in workbook.transferTasks) {
        buffer.writeln(
          '- 口座移動タスク:${task.fromAccountName} -> ${task.toAccountName} / '
          '金額:${_formatAmount(task.amount)} / 期限:${_formatNullableDate(task.dueDate)} / '
          '完了:${task.completed ? 'はい' : 'いいえ'}',
        );
      }
    }
    return buffer.toString();
  }

  String _cardBillingLines(AssetLiabilityWorkbook workbook) {
    final review = workbook.cardBillingReview;
    final reconciliation = workbook.cardStatementReconciliation;
    final buffer = StringBuffer();
    if (review.directPaymentItems.isEmpty &&
        review.cardBillingGroups.isEmpty &&
        reconciliation.groups.isEmpty) {
      return '- カード請求内訳はありません。\n';
    }
    for (final item in review.directPaymentItems) {
      buffer.writeln(
        '- 直接支払い:${item.accountName} / 金額:${_formatAmount(item.amount)} / '
        '支払日:${item.paymentDay?.toString() ?? '未設定'} / アラート:${item.alerts.join('、')}',
      );
    }
    for (final group in review.cardBillingGroups) {
      buffer.writeln(
        '- カード請求グループ:${group.billingAccountName} / 合計:${_formatAmount(group.totalAmount)} / '
        '内訳:${group.items.map((item) => '${item.accountName} ${_formatAmount(item.amount)}').join('、')}',
      );
    }
    for (final group in reconciliation.groups) {
      buffer.writeln(
        '- 明細照合:${group.billingAccountName} / 請求額:${_formatAmount(group.billedAmount)} / '
        '設定内訳合計:${_formatAmount(group.configuredDetailTotal)} / '
        '取込明細合計:${_formatAmount(group.statementLineTotal)} / '
        '設定差分:${_formatAmount(group.configuredDifference)} / '
        '明細差分:${_formatAmount(group.statementDifference)} / '
        'アラート:${group.alerts.join('、')}',
      );
    }
    if (reconciliation.unmatchedStatementLines.isNotEmpty) {
      for (final line in reconciliation.unmatchedStatementLines) {
        buffer.writeln(
          '- 未照合明細:${line.billingAccountName ?? line.billingAccountId} / '
          '日付:${_formatNullableDate(line.postedAt)} / 内容:${line.description} / '
          '金額:${_formatAmount(line.amount)}',
        );
      }
    }
    return buffer.toString();
  }

  String _redactedSituationCards(AssetManagementInsightReport report) {
    if (report.actionItems.isEmpty && report.emergencyAdvices.isEmpty) {
      return '- 目立つ個別リスクはありません。現状維持と入力精度の確認を優先してください。\n';
    }
    final buffer = StringBuffer();
    for (final item in report.actionItems.take(8)) {
      buffer.writeln(
        '- ${_actionTypeLabel(item.type)} / 項目:${item.title} / '
        '重要度:${item.severity.name} / '
        '期限:${_dueTimingBand(item.dueDate, report.todayAvailable.startDate)} / '
        '次の一手:${item.suggestedAction}',
      );
    }
    for (final advice in report.emergencyAdvices.take(4)) {
      buffer.writeln(
        '- 緊急生活防衛 / 重要度:${advice.severity.name} / '
        '状況:${advice.title} / 次の一手:${advice.suggestedAction}',
      );
    }
    return buffer.toString();
  }

  String _dueTimingBand(DateTime? dueDate, DateTime baseDate) {
    if (dueDate == null) return '不明';
    final base = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final days = due.difference(base).inDays;
    if (days < 0) return '期限超過';
    if (days == 0) return '今日';
    if (days <= 3) return '3日以内';
    if (days <= 7) return '7日以内';
    if (due.year == base.year && due.month == base.month) return '今月中';
    return '将来';
  }

  String _actionTypeLabel(AssetManagementInsightActionType type) {
    return switch (type) {
      AssetManagementInsightActionType.missingInput => '請求額の未確定',
      AssetManagementInsightActionType.missingPaymentDay => '支払日の未設定',
      AssetManagementInsightActionType.missingAnnualRate => '金利情報の未設定',
      AssetManagementInsightActionType.missingPaymentSource => '支払原資口座の未設定',
      AssetManagementInsightActionType.overduePayment => '期限超過の未払い',
      AssetManagementInsightActionType.upcomingPayment => '近い支払期限',
      AssetManagementInsightActionType.cashShortageRisk => '支払後の資金ショート',
      AssetManagementInsightActionType.emergencyLivingExpense => '生活費の不足',
      AssetManagementInsightActionType.cardBillingConfiguration => 'カード請求設定の確認',
      AssetManagementInsightActionType.doubleCountingRisk => '二重計上リスク',
    };
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

  String _formatDate(DateTime value) {
    return '${value.year}/${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _formatNullableDate(DateTime? value) {
    return value == null ? '未設定' : _formatDate(value);
  }

  String _formatPercent(double value) {
    if (value.isInfinite) return '∞';
    if (value.isNaN) return '不明';
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  String _formatRate(double value) {
    return _formatPercent(value);
  }

  DateTime? _paymentDateFor(AssetLiabilityDebtRow row, DateTime baseDate) {
    if (row.paymentDay == null) return null;
    final lastDay = DateTime(baseDate.year, baseDate.month + 1, 0).day;
    return DateTime(
      baseDate.year,
      baseDate.month,
      row.paymentDay!.clamp(1, lastDay),
    );
  }
}
