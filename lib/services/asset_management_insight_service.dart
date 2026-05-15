import '../models/asset_liability_workbook.dart';

enum AssetManagementInsightActionType {
  missingInput,
  missingPaymentDay,
  missingAnnualRate,
  missingPaymentSource,
  overduePayment,
  upcomingPayment,
  cashShortageRisk,
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

class AssetManagementInsightReport {
  final List<AssetManagementInsightActionItem> actionItems;
  final AssetManagementAvailableMoneyInsight todayAvailable;
  final AssetManagementAvailableMoneyInsight weekAvailable;
  final AssetManagementAvailableMoneyInsight monthAvailable;
  final List<AssetManagementMovementSuggestion> movementSuggestions;
  final List<AssetManagementDeveloperRequest> developerRequests;

  const AssetManagementInsightReport({
    required this.actionItems,
    required this.todayAvailable,
    required this.weekAvailable,
    required this.monthAvailable,
    required this.movementSuggestions,
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
      developerRequests: developerRequests,
    );
  }

  List<AssetManagementInsightActionItem> _buildActionItems({
    required AssetLiabilityWorkbook workbook,
    required int upcomingPaymentWarningDays,
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
