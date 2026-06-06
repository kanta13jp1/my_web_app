import 'dart:convert';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_sync_audit_log.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/debt_lockdown_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssetLiabilityMonthlyState {
  final Map<String, double> paymentOverrides;
  final Map<String, double> actualPaymentAmounts;
  final Map<String, String> paymentDifferenceReasons;
  final Map<String, double> annualRateOverrides;
  final Map<String, AssetLiabilityAnnualRateEvidence> annualRateEvidences;
  final Set<String> paidAccountNames;
  final Set<String> billingConfirmedAccountIds;
  final Map<String, String> paymentSourceAccountIds;
  final Map<String, String> cardBillingAccountIds;
  final List<AssetLiabilityCardStatementLine> cardStatementLines;
  final List<AssetLiabilityIncomePlan> incomePlans;
  final List<AssetLiabilityTransferTask> transferTasks;

  const AssetLiabilityMonthlyState({
    this.paymentOverrides = const <String, double>{},
    this.actualPaymentAmounts = const <String, double>{},
    this.paymentDifferenceReasons = const <String, String>{},
    this.annualRateOverrides = const <String, double>{},
    this.annualRateEvidences =
        const <String, AssetLiabilityAnnualRateEvidence>{},
    this.paidAccountNames = const <String>{},
    this.billingConfirmedAccountIds = const <String>{},
    this.paymentSourceAccountIds = const <String, String>{},
    this.cardBillingAccountIds = const <String, String>{},
    this.cardStatementLines = const <AssetLiabilityCardStatementLine>[],
    this.incomePlans = const <AssetLiabilityIncomePlan>[],
    this.transferTasks = const <AssetLiabilityTransferTask>[],
  });

  bool get isEmpty =>
      paymentOverrides.isEmpty &&
      actualPaymentAmounts.isEmpty &&
      paymentDifferenceReasons.isEmpty &&
      annualRateOverrides.isEmpty &&
      annualRateEvidences.isEmpty &&
      paidAccountNames.isEmpty &&
      billingConfirmedAccountIds.isEmpty &&
      paymentSourceAccountIds.isEmpty &&
      cardBillingAccountIds.isEmpty &&
      cardStatementLines.isEmpty &&
      incomePlans.isEmpty &&
      transferTasks.isEmpty;
}

class AssetLiabilityMonthlyStateStore {
  static const String paymentPrefsKey =
      'asset_liability_monthly_payment_overrides_v1';
  static const String actualPaymentPrefsKey =
      'asset_liability_monthly_actual_payments_v1';
  static const String paymentDifferenceReasonPrefsKey =
      'asset_liability_monthly_payment_difference_reasons_v1';
  static const String annualRatePrefsKey =
      'asset_liability_monthly_annual_rate_overrides_v1';
  static const String annualRateEvidencePrefsKey =
      'asset_liability_monthly_annual_rate_evidences_v1';
  static const String paidPrefsKey = 'asset_liability_paid_accounts_v1';
  static const String billingConfirmedPrefsKey =
      'asset_liability_billing_confirmed_accounts_v1';
  static const String paymentSourcePrefsKey =
      'asset_liability_payment_source_accounts_v1';
  static const String cardBillingPrefsKey =
      'asset_liability_card_billing_accounts_v1';
  static const String cardStatementPrefsKey =
      'asset_liability_card_statement_lines_v1';
  static const String incomePrefsKey = 'asset_liability_income_plans_v1';
  static const String transferTaskPrefsKey =
      'asset_liability_transfer_tasks_v1';
  static const String defaultPaymentSourcePrefsKey =
      'asset_liability_default_payment_source_accounts_v1';
  static const String defaultCardBillingPrefsKey =
      'asset_liability_default_card_billing_accounts_v1';
  static const String recurringIncomeTemplatePrefsKey =
      'asset_liability_recurring_income_templates_v1';
  static const String monthlySnapshotPrefsKey =
      'asset_liability_monthly_snapshots_v1';
  static const String syncAuditLogPrefsKey =
      'asset_liability_sync_audit_logs_v1';
  static const int maxSyncAuditLogCount = 50;

  const AssetLiabilityMonthlyStateStore();

  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    final prefs = await SharedPreferences.getInstance();
    final monthKey = formatMonthKey(month);
    return AssetLiabilityMonthlyState(
      paymentOverrides: paymentOverridesForMonth(
        prefs.getString(paymentPrefsKey),
        monthKey,
      ),
      actualPaymentAmounts: actualPaymentAmountsForMonth(
        prefs.getString(actualPaymentPrefsKey),
        monthKey,
      ),
      paymentDifferenceReasons: paymentDifferenceReasonsForMonth(
        prefs.getString(paymentDifferenceReasonPrefsKey),
        monthKey,
      ),
      annualRateOverrides: annualRateOverridesForMonth(
        prefs.getString(annualRatePrefsKey),
        monthKey,
      ),
      annualRateEvidences: annualRateEvidencesForMonth(
        prefs.getString(annualRateEvidencePrefsKey),
        monthKey,
      ),
      paidAccountNames: paidAccountsForMonth(
        prefs.getString(paidPrefsKey),
        monthKey,
      ),
      billingConfirmedAccountIds: billingConfirmedAccountsForMonth(
        prefs.getString(billingConfirmedPrefsKey),
        monthKey,
      ),
      paymentSourceAccountIds: paymentSourceAccountsForMonth(
        prefs.getString(paymentSourcePrefsKey),
        monthKey,
      ),
      cardBillingAccountIds: cardBillingAccountsForMonth(
        prefs.getString(cardBillingPrefsKey),
        monthKey,
      ),
      cardStatementLines: cardStatementLinesForMonth(
        prefs.getString(cardStatementPrefsKey),
        monthKey,
      ),
      incomePlans: incomePlansForMonth(
        prefs.getString(incomePrefsKey),
        monthKey,
      ),
      transferTasks: transferTasksForMonth(
        prefs.getString(transferTaskPrefsKey),
        monthKey,
      ),
    );
  }

  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final monthKey = formatMonthKey(month);

    final allPayments = decodePaymentOverrides(
      prefs.getString(paymentPrefsKey),
    );
    if (state.paymentOverrides.isEmpty) {
      allPayments.remove(monthKey);
    } else {
      allPayments[monthKey] = Map<String, double>.from(state.paymentOverrides);
    }

    final allActualPayments = decodePaymentOverrides(
      prefs.getString(actualPaymentPrefsKey),
    );
    if (state.actualPaymentAmounts.isEmpty) {
      allActualPayments.remove(monthKey);
    } else {
      allActualPayments[monthKey] = Map<String, double>.from(
        state.actualPaymentAmounts,
      );
    }

    final allPaymentDifferenceReasons = decodePaymentDifferenceReasons(
      prefs.getString(paymentDifferenceReasonPrefsKey),
    );
    if (state.paymentDifferenceReasons.isEmpty) {
      allPaymentDifferenceReasons.remove(monthKey);
    } else {
      allPaymentDifferenceReasons[monthKey] = Map<String, String>.from(
        state.paymentDifferenceReasons,
      );
    }

    final allPaidAccounts = decodePaidAccounts(prefs.getString(paidPrefsKey));
    if (state.paidAccountNames.isEmpty) {
      allPaidAccounts.remove(monthKey);
    } else {
      allPaidAccounts[monthKey] = Set<String>.from(state.paidAccountNames);
    }

    await prefs.setString(paymentPrefsKey, jsonEncode(allPayments));
    await prefs.setString(actualPaymentPrefsKey, jsonEncode(allActualPayments));
    await prefs.setString(
      paymentDifferenceReasonPrefsKey,
      jsonEncode(allPaymentDifferenceReasons),
    );

    final allAnnualRates = decodePaymentOverrides(
      prefs.getString(annualRatePrefsKey),
    );
    final sanitizedAnnualRateOverrides = sanitizeAnnualRateOverrides(
      state.annualRateOverrides,
    );
    if (sanitizedAnnualRateOverrides.isEmpty) {
      allAnnualRates.remove(monthKey);
    } else {
      allAnnualRates[monthKey] = sanitizedAnnualRateOverrides;
    }
    await prefs.setString(annualRatePrefsKey, jsonEncode(allAnnualRates));

    final allAnnualRateEvidences = decodeAnnualRateEvidences(
      prefs.getString(annualRateEvidencePrefsKey),
    );
    final sanitizedAnnualRateEvidences = sanitizeAnnualRateEvidences(
      state.annualRateEvidences,
    );
    if (sanitizedAnnualRateEvidences.isEmpty) {
      allAnnualRateEvidences.remove(monthKey);
    } else {
      allAnnualRateEvidences[monthKey] = sanitizedAnnualRateEvidences;
    }
    await prefs.setString(
      annualRateEvidencePrefsKey,
      jsonEncode(_encodeAnnualRateEvidences(allAnnualRateEvidences)),
    );

    await prefs.setString(
      paidPrefsKey,
      jsonEncode(_encodePaid(allPaidAccounts)),
    );

    final allBillingConfirmedAccounts = decodePaidAccounts(
      prefs.getString(billingConfirmedPrefsKey),
    );
    if (state.billingConfirmedAccountIds.isEmpty) {
      allBillingConfirmedAccounts.remove(monthKey);
    } else {
      allBillingConfirmedAccounts[monthKey] = Set<String>.from(
        state.billingConfirmedAccountIds,
      );
    }
    await prefs.setString(
      billingConfirmedPrefsKey,
      jsonEncode(_encodePaid(allBillingConfirmedAccounts)),
    );

    final allPaymentSources = decodePaymentSourceAccounts(
      prefs.getString(paymentSourcePrefsKey),
    );
    if (state.paymentSourceAccountIds.isEmpty) {
      allPaymentSources.remove(monthKey);
    } else {
      allPaymentSources[monthKey] = Map<String, String>.from(
        state.paymentSourceAccountIds,
      );
    }
    await prefs.setString(paymentSourcePrefsKey, jsonEncode(allPaymentSources));

    final allCardBillingAccounts = decodeCardBillingAccounts(
      prefs.getString(cardBillingPrefsKey),
    );
    if (state.cardBillingAccountIds.isEmpty) {
      allCardBillingAccounts.remove(monthKey);
    } else {
      allCardBillingAccounts[monthKey] = Map<String, String>.from(
        state.cardBillingAccountIds,
      );
    }
    await prefs.setString(
      cardBillingPrefsKey,
      jsonEncode(allCardBillingAccounts),
    );

    final allCardStatementLines = decodeCardStatementLines(
      prefs.getString(cardStatementPrefsKey),
    );
    if (state.cardStatementLines.isEmpty) {
      allCardStatementLines.remove(monthKey);
    } else {
      allCardStatementLines[monthKey] =
          List<AssetLiabilityCardStatementLine>.from(state.cardStatementLines);
    }
    await prefs.setString(
      cardStatementPrefsKey,
      jsonEncode(_encodeCardStatementLines(allCardStatementLines)),
    );

    final allIncomePlans = decodeIncomePlans(prefs.getString(incomePrefsKey));
    if (state.incomePlans.isEmpty) {
      allIncomePlans.remove(monthKey);
    } else {
      allIncomePlans[monthKey] = List<AssetLiabilityIncomePlan>.from(
        state.incomePlans,
      );
    }
    await prefs.setString(
      incomePrefsKey,
      jsonEncode(_encodeIncomePlans(allIncomePlans)),
    );

    final allTransferTasks = decodeTransferTasks(
      prefs.getString(transferTaskPrefsKey),
    );
    if (state.transferTasks.isEmpty) {
      allTransferTasks.remove(monthKey);
    } else {
      allTransferTasks[monthKey] = List<AssetLiabilityTransferTask>.from(
        state.transferTasks,
      );
    }
    await prefs.setString(
      transferTaskPrefsKey,
      jsonEncode(_encodeTransferTasks(allTransferTasks)),
    );
  }

  Future<Map<String, String>> loadDefaultPaymentSources() async {
    final prefs = await SharedPreferences.getInstance();
    return decodeStringMap(prefs.getString(defaultPaymentSourcePrefsKey));
  }

  Future<void> saveDefaultPaymentSources(Map<String, String> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      defaultPaymentSourcePrefsKey,
      jsonEncode(_cleanStringMap(sources)),
    );
  }

  Future<Map<String, String>> loadDefaultCardBillingAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    return decodeStringMap(prefs.getString(defaultCardBillingPrefsKey));
  }

  Future<void> saveDefaultCardBillingAccounts(
    Map<String, String> accounts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      defaultCardBillingPrefsKey,
      jsonEncode(_cleanStringMap(accounts)),
    );
  }

  Future<List<AssetLiabilityRecurringIncomeTemplate>>
      loadRecurringIncomeTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    return decodeRecurringIncomeTemplates(
      prefs.getString(recurringIncomeTemplatePrefsKey),
    );
  }

  Future<void> saveRecurringIncomeTemplates(
    List<AssetLiabilityRecurringIncomeTemplate> templates,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      recurringIncomeTemplatePrefsKey,
      jsonEncode(_encodeRecurringIncomeTemplates(templates)),
    );
  }

  Future<AssetLiabilityMonthlyState> copyPreviousMonthToMonth(
    DateTime targetMonth, {
    bool carryOverIncompleteTransferTasks = false,
  }) async {
    final previousMonth = DateTime(targetMonth.year, targetMonth.month - 1);
    final previousState = await loadMonth(previousMonth);
    final copied = copyPreviousMonthState(
      previousState: previousState,
      targetMonth: targetMonth,
      carryOverIncompleteTransferTasks: carryOverIncompleteTransferTasks,
    );
    await saveMonth(month: targetMonth, state: copied);
    return copied;
  }

  Future<List<AssetLiabilityMonthlySnapshot>> loadMonthlySnapshots() async {
    final prefs = await SharedPreferences.getInstance();
    return decodeMonthlySnapshots(prefs.getString(monthlySnapshotPrefsKey));
  }

  Future<void> saveMonthlySnapshot(
    AssetLiabilityMonthlySnapshot snapshot,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshots = decodeMonthlySnapshots(
      prefs.getString(monthlySnapshotPrefsKey),
    );
    final nextSnapshots = <AssetLiabilityMonthlySnapshot>[
      for (final current in snapshots)
        if (current.monthKey != snapshot.monthKey) current,
      snapshot,
    ]..sort((a, b) => a.monthKey.compareTo(b.monthKey));
    await prefs.setString(
      monthlySnapshotPrefsKey,
      jsonEncode(_encodeMonthlySnapshots(nextSnapshots)),
    );
  }

  Future<List<AssetLiabilitySyncAuditLog>> loadSyncAuditLogs({
    int limit = 20,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = decodeSyncAuditLogs(prefs.getString(syncAuditLogPrefsKey));
    return logs.take(limit < 0 ? 0 : limit).toList(growable: false);
  }

  Future<void> saveSyncAuditLog(AssetLiabilitySyncAuditLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = decodeSyncAuditLogs(prefs.getString(syncAuditLogPrefsKey));
    final nextLogs = <AssetLiabilitySyncAuditLog>[
      log,
      for (final current in logs)
        if (current.id != log.id) current,
    ].take(maxSyncAuditLogCount).toList(growable: false);
    await prefs.setString(
      syncAuditLogPrefsKey,
      jsonEncode(_encodeSyncAuditLogs(nextLogs)),
    );
  }

  static String formatMonthKey(DateTime month) {
    return DateFormat('yyyy-MM').format(month);
  }

  static DateTime salaryCycleMonthFor(DateTime date, {int salaryDay = 25}) {
    final normalizedSalaryDay = salaryDay.clamp(1, 28).toInt();
    if (date.day >= normalizedSalaryDay) {
      return DateTime(date.year, date.month);
    }
    return DateTime(date.year, date.month - 1);
  }

  static String formatSalaryCycleMonthKey(DateTime date, {int salaryDay = 25}) {
    return formatMonthKey(salaryCycleMonthFor(date, salaryDay: salaryDay));
  }

  static AssetLiabilityMonthlyState copyPreviousMonthState({
    required AssetLiabilityMonthlyState previousState,
    required DateTime targetMonth,
    bool carryOverIncompleteTransferTasks = false,
  }) {
    final targetMonthKey = formatMonthKey(targetMonth);
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    final copiedIncomePlans = <AssetLiabilityIncomePlan>[
      for (final plan in previousState.incomePlans)
        AssetLiabilityIncomePlan(
          id: 'copy_${targetMonthKey}_${plan.id}',
          date: DateTime(
            targetMonth.year,
            targetMonth.month,
            min(plan.date.day, lastDay),
          ),
          name: plan.name,
          amount: plan.amount,
          destinationAccountId: plan.destinationAccountId,
          destinationAccountName: plan.destinationAccountName,
          received: false,
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final copiedTransferTasks = carryOverIncompleteTransferTasks
        ? (<AssetLiabilityTransferTask>[
            for (final task in previousState.transferTasks)
              if (!task.completed && !task.canceled)
                AssetLiabilityTransferTask(
                  id: 'carry_${targetMonthKey}_${task.id}',
                  fromAccountId: task.fromAccountId,
                  fromAccountName: task.fromAccountName,
                  toAccountId: task.toAccountId,
                  toAccountName: task.toAccountName,
                  amount: task.amount,
                  dueDate: task.dueDate == null
                      ? null
                      : DateTime(
                          targetMonth.year,
                          targetMonth.month,
                          min(task.dueDate!.day, lastDay),
                        ),
                  completionMemo: task.completionMemo,
                ),
          ]..sort(_compareTransferTasks))
        : const <AssetLiabilityTransferTask>[];

    return AssetLiabilityMonthlyState(
      paymentOverrides: Map<String, double>.from(
        previousState.paymentOverrides,
      ),
      annualRateOverrides: Map<String, double>.from(
        previousState.annualRateOverrides,
      ),
      annualRateEvidences: Map<String, AssetLiabilityAnnualRateEvidence>.from(
        previousState.annualRateEvidences,
      ),
      paymentSourceAccountIds: Map<String, String>.from(
        previousState.paymentSourceAccountIds,
      ),
      cardBillingAccountIds: Map<String, String>.from(
        previousState.cardBillingAccountIds,
      ),
      incomePlans: copiedIncomePlans,
      transferTasks: copiedTransferTasks,
    );
  }

  static List<AssetLiabilityIncomePlan> applyRecurringIncomeTemplates({
    required DateTime month,
    required List<AssetLiabilityRecurringIncomeTemplate> templates,
    required List<AssetLiabilityIncomePlan> existingPlans,
  }) {
    final monthKey = formatMonthKey(month);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final result = List<AssetLiabilityIncomePlan>.from(existingPlans);
    final existingIds = result.map((plan) => plan.id).toSet();

    for (final template in templates) {
      final id = 'recurring_${template.id}_$monthKey';
      if (existingIds.contains(id)) {
        continue;
      }
      result.add(
        AssetLiabilityIncomePlan(
          id: id,
          date: DateTime(
            month.year,
            month.month,
            min(template.dayOfMonth.clamp(1, 31).toInt(), lastDay),
          ),
          name: template.name,
          amount: template.amount,
          destinationAccountId: template.destinationAccountId,
          destinationAccountName: template.destinationAccountName,
          received: false,
        ),
      );
    }

    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  static Map<String, String> decodeStringMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, String>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, String>{};
    }

    return _cleanStringMap(
      decoded.map<String, String>(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }

  static Map<String, Map<String, double>> decodePaymentOverrides(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, Map<String, double>>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, Map<String, double>>{};
    }

    return decoded.map<String, Map<String, double>>((month, values) {
      final monthKey = month.toString();
      final payments = <String, double>{};
      if (values is Map) {
        for (final entry in values.entries) {
          final rawAmount = entry.value;
          final amount = rawAmount is num
              ? rawAmount.toDouble()
              : double.tryParse(rawAmount.toString().replaceAll(',', ''));
          if (amount != null && amount >= 0) {
            payments[entry.key.toString()] = amount;
          }
        }
      }
      return MapEntry(monthKey, payments);
    });
  }

  static Map<String, Map<String, AssetLiabilityAnnualRateEvidence>>
      decodeAnnualRateEvidences(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, Map<String, AssetLiabilityAnnualRateEvidence>>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, Map<String, AssetLiabilityAnnualRateEvidence>>{};
    }

    return decoded.map<String, Map<String, AssetLiabilityAnnualRateEvidence>>((
      month,
      values,
    ) {
      final monthKey = month.toString();
      final evidences = <String, AssetLiabilityAnnualRateEvidence>{};
      if (values is Map) {
        for (final entry in values.entries) {
          if (entry.value is! Map) {
            continue;
          }
          final rawEvidence = Map<String, Object?>.from(
            (entry.value as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          );
          final evidence = AssetLiabilityAnnualRateEvidence.fromJson(
            rawEvidence,
          );
          if (evidence != null) {
            evidences[entry.key.toString()] = evidence;
          }
        }
      }
      return MapEntry(monthKey, evidences);
    });
  }

  static Map<String, Map<String, String>> decodePaymentDifferenceReasons(
    String? raw,
  ) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, Map<String, String>>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, Map<String, String>>{};
    }

    return decoded.map<String, Map<String, String>>((month, values) {
      final monthKey = month.toString();
      final reasons = <String, String>{};
      if (values is Map) {
        for (final entry in values.entries) {
          final reason = entry.value.toString().trim();
          if (reason.isNotEmpty) {
            reasons[entry.key.toString()] = reason;
          }
        }
      }
      return MapEntry(monthKey, reasons);
    });
  }

  static Map<String, Set<String>> decodePaidAccounts(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, Set<String>>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, Set<String>>{};
    }

    return decoded.map<String, Set<String>>((month, values) {
      final monthKey = month.toString();
      final accounts = <String>{};
      if (values is Iterable) {
        for (final value in values) {
          final accountName = value.toString().trim();
          if (accountName.isNotEmpty) {
            accounts.add(accountName);
          }
        }
      }
      return MapEntry(monthKey, accounts);
    });
  }

  static Map<String, Map<String, String>> decodePaymentSourceAccounts(
    String? raw,
  ) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, Map<String, String>>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, Map<String, String>>{};
    }

    return decoded.map<String, Map<String, String>>((month, values) {
      final monthKey = month.toString();
      final sources = <String, String>{};
      if (values is Map) {
        for (final entry in values.entries) {
          final sourceId = entry.value.toString().trim();
          if (sourceId.isNotEmpty) {
            sources[entry.key.toString()] = sourceId;
          }
        }
      }
      return MapEntry(monthKey, sources);
    });
  }

  static Map<String, Map<String, String>> decodeCardBillingAccounts(
    String? raw,
  ) {
    return decodePaymentSourceAccounts(raw);
  }

  static Map<String, List<AssetLiabilityCardStatementLine>>
      decodeCardStatementLines(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, List<AssetLiabilityCardStatementLine>>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, List<AssetLiabilityCardStatementLine>>{};
    }

    return decoded.map<String, List<AssetLiabilityCardStatementLine>>((
      month,
      values,
    ) {
      final monthKey = month.toString();
      final lines = <AssetLiabilityCardStatementLine>[];
      if (values is Iterable) {
        for (final rawLine in values) {
          if (rawLine is! Map) {
            continue;
          }
          final id = rawLine['id']?.toString().trim();
          final billingAccountId =
              rawLine['billingAccountId']?.toString().trim() ??
                  rawLine['billing_account_id']?.toString().trim();
          final description = rawLine['description']?.toString().trim();
          final amount = _parseNonNullDouble(rawLine['amount']);
          final postedAtText = rawLine['postedAt']?.toString() ??
              rawLine['posted_at']?.toString();
          final postedAt =
              postedAtText == null ? null : DateTime.tryParse(postedAtText);
          if (id == null ||
              id.isEmpty ||
              billingAccountId == null ||
              billingAccountId.isEmpty ||
              description == null ||
              description.isEmpty ||
              amount == null) {
            continue;
          }
          lines.add(
            AssetLiabilityCardStatementLine(
              id: id,
              billingAccountId: billingAccountId,
              billingAccountName: _cleanNullableString(
                rawLine['billingAccountName'] ??
                    rawLine['billing_account_name'],
              ),
              postedAt: postedAt,
              description: description,
              amount: amount,
            ),
          );
        }
      }
      lines.sort(_compareCardStatementLines);
      return MapEntry(monthKey, lines);
    });
  }

  static Map<String, List<AssetLiabilityIncomePlan>> decodeIncomePlans(
    String? raw,
  ) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, List<AssetLiabilityIncomePlan>>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, List<AssetLiabilityIncomePlan>>{};
    }

    return decoded.map<String, List<AssetLiabilityIncomePlan>>((month, values) {
      final monthKey = month.toString();
      final plans = <AssetLiabilityIncomePlan>[];
      if (values is Iterable) {
        for (final rawPlan in values) {
          if (rawPlan is! Map) {
            continue;
          }
          final id = rawPlan['id']?.toString().trim();
          final dateText = rawPlan['date']?.toString();
          final name = rawPlan['name']?.toString().trim();
          final rawAmount = rawPlan['amount'];
          final amount = rawAmount is num
              ? rawAmount.toDouble()
              : double.tryParse(rawAmount.toString().replaceAll(',', ''));
          final date = dateText == null ? null : DateTime.tryParse(dateText);
          if (id == null ||
              id.isEmpty ||
              date == null ||
              name == null ||
              name.isEmpty ||
              amount == null ||
              amount <= 0) {
            continue;
          }
          plans.add(
            AssetLiabilityIncomePlan(
              id: id,
              date: date,
              name: name,
              amount: amount,
              destinationAccountId:
                  rawPlan['destinationAccountId']?.toString().trim(),
              destinationAccountName:
                  rawPlan['destinationAccountName']?.toString().trim(),
              received: rawPlan['received'] == true,
            ),
          );
        }
      }
      plans.sort((a, b) => a.date.compareTo(b.date));
      return MapEntry(monthKey, plans);
    });
  }

  static Map<String, List<AssetLiabilityTransferTask>> decodeTransferTasks(
    String? raw,
  ) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, List<AssetLiabilityTransferTask>>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, List<AssetLiabilityTransferTask>>{};
    }

    return decoded.map<String, List<AssetLiabilityTransferTask>>((
      month,
      values,
    ) {
      final monthKey = month.toString();
      final tasks = <AssetLiabilityTransferTask>[];
      if (values is Iterable) {
        for (final rawTask in values) {
          if (rawTask is! Map) {
            continue;
          }
          final id = rawTask['id']?.toString().trim();
          final fromAccountId = rawTask['fromAccountId']?.toString().trim() ??
              rawTask['from_account_id']?.toString().trim();
          final toAccountId = rawTask['toAccountId']?.toString().trim() ??
              rawTask['to_account_id']?.toString().trim();
          final amount = _parseNonNullDouble(rawTask['amount']);
          final dueDateText =
              rawTask['dueDate']?.toString() ?? rawTask['due_date']?.toString();
          final completedAtText = rawTask['completedAt']?.toString() ??
              rawTask['completed_at']?.toString();
          final dueDate =
              dueDateText == null ? null : DateTime.tryParse(dueDateText);
          final completedAt = completedAtText == null
              ? null
              : DateTime.tryParse(completedAtText);
          final completionMemo = _cleanNullableString(
                rawTask['completionMemo'] ?? rawTask['completion_memo'],
              ) ??
              '';
          final canceledAtText = rawTask['canceledAt']?.toString() ??
              rawTask['cancelledAt']?.toString() ??
              rawTask['canceled_at']?.toString() ??
              rawTask['cancelled_at']?.toString();
          final canceledAt =
              canceledAtText == null ? null : DateTime.tryParse(canceledAtText);
          final cancellationReason = _cleanNullableString(
                rawTask['cancellationReason'] ??
                    rawTask['cancelReason'] ??
                    rawTask['cancellation_reason'] ??
                    rawTask['cancel_reason'],
              ) ??
              '';
          if (id == null ||
              id.isEmpty ||
              fromAccountId == null ||
              fromAccountId.isEmpty ||
              toAccountId == null ||
              toAccountId.isEmpty ||
              fromAccountId == toAccountId ||
              amount == null ||
              amount <= 0) {
            continue;
          }
          tasks.add(
            AssetLiabilityTransferTask(
              id: id,
              fromAccountId: fromAccountId,
              fromAccountName: _cleanNullableString(
                    rawTask['fromAccountName'] ?? rawTask['from_account_name'],
                  ) ??
                  fromAccountId,
              toAccountId: toAccountId,
              toAccountName: _cleanNullableString(
                    rawTask['toAccountName'] ?? rawTask['to_account_name'],
                  ) ??
                  toAccountId,
              amount: amount,
              dueDate: dueDate,
              completed: rawTask['completed'] == true,
              completedAt: completedAt,
              completionMemo: completionMemo,
              canceled:
                  rawTask['canceled'] == true || rawTask['cancelled'] == true,
              canceledAt: canceledAt,
              cancellationReason: cancellationReason,
            ),
          );
        }
      }
      tasks.sort(_compareTransferTasks);
      return MapEntry(monthKey, tasks);
    });
  }

  static List<AssetLiabilityRecurringIncomeTemplate>
      decodeRecurringIncomeTemplates(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <AssetLiabilityRecurringIncomeTemplate>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Iterable) {
      return <AssetLiabilityRecurringIncomeTemplate>[];
    }

    final templates = <AssetLiabilityRecurringIncomeTemplate>[];
    for (final rawTemplate in decoded) {
      if (rawTemplate is! Map) {
        continue;
      }
      final id = rawTemplate['id']?.toString().trim();
      final name = rawTemplate['name']?.toString().trim();
      final rawDay = rawTemplate['dayOfMonth'];
      final rawAmount = rawTemplate['amount'];
      final day = rawDay is num ? rawDay.toInt() : int.tryParse('$rawDay');
      final amount = rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse(rawAmount.toString().replaceAll(',', ''));
      if (id == null ||
          id.isEmpty ||
          name == null ||
          name.isEmpty ||
          day == null ||
          day < 1 ||
          amount == null ||
          amount <= 0) {
        continue;
      }
      templates.add(
        AssetLiabilityRecurringIncomeTemplate(
          id: id,
          dayOfMonth: day.clamp(1, 31).toInt(),
          name: name,
          amount: amount,
          destinationAccountId: _cleanNullableString(
            rawTemplate['destinationAccountId'],
          ),
          destinationAccountName: _cleanNullableString(
            rawTemplate['destinationAccountName'],
          ),
        ),
      );
    }
    templates.sort((a, b) {
      final day = a.dayOfMonth.compareTo(b.dayOfMonth);
      if (day != 0) {
        return day;
      }
      return a.name.compareTo(b.name);
    });
    return templates;
  }

  static List<AssetLiabilityMonthlySnapshot> decodeMonthlySnapshots(
    String? raw,
  ) {
    if (raw == null || raw.trim().isEmpty) {
      return <AssetLiabilityMonthlySnapshot>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Iterable) {
      return <AssetLiabilityMonthlySnapshot>[];
    }

    final snapshots = <AssetLiabilityMonthlySnapshot>[];
    for (final rawSnapshot in decoded) {
      if (rawSnapshot is! Map) {
        continue;
      }
      final monthKey = rawSnapshot['monthKey']?.toString().trim();
      final savedAtText = rawSnapshot['savedAt']?.toString();
      final savedAt =
          savedAtText == null ? null : DateTime.tryParse(savedAtText);
      final positiveAssetTotal = _parseNonNullDouble(
        rawSnapshot['positiveAssetTotal'],
      );
      final liabilityTotal = _parseNonNullDouble(rawSnapshot['liabilityTotal']);
      final netWorth = _parseNonNullDouble(rawSnapshot['netWorth']);
      final cashLikeTotal = _parseNonNullDouble(rawSnapshot['cashLikeTotal']);
      final monthlyScheduledPaymentTotal = _parseNonNullDouble(
        rawSnapshot['monthlyScheduledPaymentTotal'],
      );
      final monthlyPaidPaymentTotal = _parseNonNullDouble(
        rawSnapshot['monthlyPaidPaymentTotal'],
      );
      final monthlyUnpaidPaymentTotal = _parseNonNullDouble(
        rawSnapshot['monthlyUnpaidPaymentTotal'],
      );
      final monthlyActualPaymentTotal = _parseNonNullDouble(
        rawSnapshot['monthlyActualPaymentTotal'],
      );
      final monthlyPaymentDifferenceTotal = _parseNonNullDouble(
        rawSnapshot['monthlyPaymentDifferenceTotal'],
      );
      final overduePaymentCount = _parseNonNullInt(
        rawSnapshot['overduePaymentCount'],
      );
      if (monthKey == null ||
          monthKey.isEmpty ||
          savedAt == null ||
          positiveAssetTotal == null ||
          liabilityTotal == null ||
          netWorth == null ||
          cashLikeTotal == null ||
          monthlyScheduledPaymentTotal == null ||
          monthlyPaidPaymentTotal == null ||
          monthlyUnpaidPaymentTotal == null ||
          overduePaymentCount == null) {
        continue;
      }
      snapshots.add(
        AssetLiabilityMonthlySnapshot(
          monthKey: monthKey,
          savedAt: savedAt,
          positiveAssetTotal: positiveAssetTotal,
          liabilityTotal: liabilityTotal,
          netWorth: netWorth,
          cashLikeTotal: cashLikeTotal,
          monthlyScheduledPaymentTotal: monthlyScheduledPaymentTotal,
          monthlyPaidPaymentTotal: monthlyPaidPaymentTotal,
          monthlyUnpaidPaymentTotal: monthlyUnpaidPaymentTotal,
          monthlyActualPaymentTotal:
              monthlyActualPaymentTotal ?? monthlyPaidPaymentTotal,
          monthlyPaymentDifferenceTotal: monthlyPaymentDifferenceTotal ?? 0,
          overduePaymentCount: overduePaymentCount,
        ),
      );
    }
    snapshots.sort((a, b) => a.monthKey.compareTo(b.monthKey));
    return snapshots;
  }

  static List<AssetLiabilitySyncAuditLog> decodeSyncAuditLogs(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <AssetLiabilitySyncAuditLog>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Iterable) {
      return <AssetLiabilitySyncAuditLog>[];
    }

    final logs = <AssetLiabilitySyncAuditLog>[];
    for (final rawLog in decoded) {
      if (rawLog is! Map) {
        continue;
      }
      logs.add(
        AssetLiabilitySyncAuditLog.fromJson(
          rawLog.map<String, Object?>(
            (key, value) => MapEntry(key.toString(), value),
          ),
        ),
      );
    }
    logs.sort((a, b) => b.executedAt.compareTo(a.executedAt));
    return logs;
  }

  static Map<String, double> paymentOverridesForMonth(
    String? raw,
    String monthKey,
  ) {
    return Map<String, double>.from(
      decodePaymentOverrides(raw)[monthKey] ?? const <String, double>{},
    );
  }

  static Map<String, double> actualPaymentAmountsForMonth(
    String? raw,
    String monthKey,
  ) {
    return Map<String, double>.from(
      decodePaymentOverrides(raw)[monthKey] ?? const <String, double>{},
    );
  }

  static Map<String, double> annualRateOverridesForMonth(
    String? raw,
    String monthKey,
  ) {
    return sanitizeAnnualRateOverrides(
      Map<String, double>.from(
        decodePaymentOverrides(raw)[monthKey] ?? const <String, double>{},
      ),
    );
  }

  static Map<String, AssetLiabilityAnnualRateEvidence>
      annualRateEvidencesForMonth(String? raw, String monthKey) {
    return sanitizeAnnualRateEvidences(
      Map<String, AssetLiabilityAnnualRateEvidence>.from(
        decodeAnnualRateEvidences(raw)[monthKey] ??
            const <String, AssetLiabilityAnnualRateEvidence>{},
      ),
    );
  }

  static Map<String, double> sanitizeAnnualRateOverrides(
    Map<String, double> values,
  ) {
    return <String, double>{
      for (final entry in values.entries)
        if (DebtLockdownService.isRegistrableAnnualRate(entry.value))
          entry.key: entry.value,
    };
  }

  static Map<String, AssetLiabilityAnnualRateEvidence>
      sanitizeAnnualRateEvidences(
    Map<String, AssetLiabilityAnnualRateEvidence> values,
  ) {
    return <String, AssetLiabilityAnnualRateEvidence>{
      for (final entry in values.entries)
        if (DebtLockdownService.isRegistrableAnnualRate(
              entry.value.submittedAnnualRate,
            ) &&
            (entry.value.detectedAnnualRate == null ||
                DebtLockdownService.isRegistrableAnnualRate(
                  entry.value.detectedAnnualRate!,
                )))
          entry.key: entry.value,
    };
  }

  static Map<String, String> paymentDifferenceReasonsForMonth(
    String? raw,
    String monthKey,
  ) {
    return Map<String, String>.from(
      decodePaymentDifferenceReasons(raw)[monthKey] ?? const <String, String>{},
    );
  }

  static Set<String> paidAccountsForMonth(String? raw, String monthKey) {
    return Set<String>.from(
      decodePaidAccounts(raw)[monthKey] ?? const <String>{},
    );
  }

  static Set<String> billingConfirmedAccountsForMonth(
    String? raw,
    String monthKey,
  ) {
    return Set<String>.from(
      decodePaidAccounts(raw)[monthKey] ?? const <String>{},
    );
  }

  static Map<String, String> paymentSourceAccountsForMonth(
    String? raw,
    String monthKey,
  ) {
    return Map<String, String>.from(
      decodePaymentSourceAccounts(raw)[monthKey] ?? const <String, String>{},
    );
  }

  static Map<String, String> cardBillingAccountsForMonth(
    String? raw,
    String monthKey,
  ) {
    return Map<String, String>.from(
      decodeCardBillingAccounts(raw)[monthKey] ?? const <String, String>{},
    );
  }

  static List<AssetLiabilityCardStatementLine> cardStatementLinesForMonth(
    String? raw,
    String monthKey,
  ) {
    return List<AssetLiabilityCardStatementLine>.from(
      decodeCardStatementLines(raw)[monthKey] ??
          const <AssetLiabilityCardStatementLine>[],
    );
  }

  static List<AssetLiabilityIncomePlan> incomePlansForMonth(
    String? raw,
    String monthKey,
  ) {
    return List<AssetLiabilityIncomePlan>.from(
      decodeIncomePlans(raw)[monthKey] ?? const <AssetLiabilityIncomePlan>[],
    );
  }

  static List<AssetLiabilityTransferTask> transferTasksForMonth(
    String? raw,
    String monthKey,
  ) {
    return List<AssetLiabilityTransferTask>.from(
      decodeTransferTasks(raw)[monthKey] ??
          const <AssetLiabilityTransferTask>[],
    );
  }

  static AssetLiabilityMonthlyState migrateLegacyKeys({
    required AssetLiabilityMonthlyState state,
    required Map<String, String> legacyKeyToAccountId,
  }) {
    final migratedPayments = <String, double>{};
    for (final entry in state.paymentOverrides.entries) {
      final migratedKey = legacyKeyToAccountId[entry.key] ?? entry.key;
      if (legacyKeyToAccountId.containsKey(entry.key)) {
        migratedPayments.putIfAbsent(migratedKey, () => entry.value);
      } else {
        migratedPayments[migratedKey] = entry.value;
      }
    }

    final migratedActualPayments = <String, double>{};
    for (final entry in state.actualPaymentAmounts.entries) {
      final migratedKey = legacyKeyToAccountId[entry.key] ?? entry.key;
      if (legacyKeyToAccountId.containsKey(entry.key)) {
        migratedActualPayments.putIfAbsent(migratedKey, () => entry.value);
      } else {
        migratedActualPayments[migratedKey] = entry.value;
      }
    }

    final migratedDifferenceReasons = <String, String>{};
    for (final entry in state.paymentDifferenceReasons.entries) {
      final migratedKey = legacyKeyToAccountId[entry.key] ?? entry.key;
      migratedDifferenceReasons[migratedKey] = entry.value;
    }

    final migratedAnnualRates = <String, double>{};
    for (final entry in state.annualRateOverrides.entries) {
      if (!DebtLockdownService.isRegistrableAnnualRate(entry.value)) {
        continue;
      }
      final migratedKey = legacyKeyToAccountId[entry.key] ?? entry.key;
      if (legacyKeyToAccountId.containsKey(entry.key)) {
        migratedAnnualRates.putIfAbsent(migratedKey, () => entry.value);
      } else {
        migratedAnnualRates[migratedKey] = entry.value;
      }
    }

    final migratedAnnualRateEvidences =
        <String, AssetLiabilityAnnualRateEvidence>{};
    for (final entry in state.annualRateEvidences.entries) {
      if (!DebtLockdownService.isRegistrableAnnualRate(
            entry.value.submittedAnnualRate,
          ) ||
          (entry.value.detectedAnnualRate != null &&
              !DebtLockdownService.isRegistrableAnnualRate(
                entry.value.detectedAnnualRate!,
              ))) {
        continue;
      }
      final migratedKey = legacyKeyToAccountId[entry.key] ?? entry.key;
      migratedAnnualRateEvidences[migratedKey] = entry.value.copyWith(
        accountId: migratedKey,
      );
    }

    final migratedPaidAccounts = <String>{};
    for (final accountKey in state.paidAccountNames) {
      migratedPaidAccounts.add(legacyKeyToAccountId[accountKey] ?? accountKey);
    }

    final migratedBillingConfirmedAccounts = <String>{};
    for (final accountKey in state.billingConfirmedAccountIds) {
      migratedBillingConfirmedAccounts.add(
        legacyKeyToAccountId[accountKey] ?? accountKey,
      );
    }

    final migratedPaymentSources = <String, String>{};
    for (final entry in state.paymentSourceAccountIds.entries) {
      final liabilityId = legacyKeyToAccountId[entry.key] ?? entry.key;
      final sourceId = legacyKeyToAccountId[entry.value] ?? entry.value;
      migratedPaymentSources[liabilityId] = sourceId;
    }

    final migratedCardBillingAccounts = <String, String>{};
    for (final entry in state.cardBillingAccountIds.entries) {
      final liabilityId = legacyKeyToAccountId[entry.key] ?? entry.key;
      final cardId = legacyKeyToAccountId[entry.value] ?? entry.value;
      migratedCardBillingAccounts[liabilityId] = cardId;
    }

    final migratedCardStatementLines = <AssetLiabilityCardStatementLine>[
      for (final line in state.cardStatementLines)
        line.copyWith(
          billingAccountId: legacyKeyToAccountId[line.billingAccountId] ??
              line.billingAccountId,
          billingAccountName:
              legacyKeyToAccountId.containsKey(line.billingAccountId)
                  ? null
                  : line.billingAccountName,
        ),
    ];

    final migratedTransferTasks = <AssetLiabilityTransferTask>[
      for (final task in state.transferTasks)
        AssetLiabilityTransferTask(
          id: task.id,
          fromAccountId:
              legacyKeyToAccountId[task.fromAccountId] ?? task.fromAccountId,
          fromAccountName: legacyKeyToAccountId.containsKey(task.fromAccountId)
              ? task.fromAccountId
              : task.fromAccountName,
          toAccountId:
              legacyKeyToAccountId[task.toAccountId] ?? task.toAccountId,
          toAccountName: legacyKeyToAccountId.containsKey(task.toAccountId)
              ? task.toAccountId
              : task.toAccountName,
          amount: task.amount,
          dueDate: task.dueDate,
          completed: task.completed,
          completedAt: task.completedAt,
          completionMemo: task.completionMemo,
          canceled: task.canceled,
          canceledAt: task.canceledAt,
          cancellationReason: task.cancellationReason,
        ),
    ];

    return AssetLiabilityMonthlyState(
      paymentOverrides: migratedPayments,
      actualPaymentAmounts: migratedActualPayments,
      paymentDifferenceReasons: migratedDifferenceReasons,
      annualRateOverrides: migratedAnnualRates,
      annualRateEvidences: migratedAnnualRateEvidences,
      paidAccountNames: migratedPaidAccounts,
      billingConfirmedAccountIds: migratedBillingConfirmedAccounts,
      paymentSourceAccountIds: migratedPaymentSources,
      cardBillingAccountIds: migratedCardBillingAccounts,
      cardStatementLines: migratedCardStatementLines,
      incomePlans: state.incomePlans,
      transferTasks: migratedTransferTasks,
    );
  }

  static Map<String, List<String>> _encodePaid(
    Map<String, Set<String>> source,
  ) {
    return source.map((month, accounts) {
      final sorted = accounts.toList()..sort();
      return MapEntry(month, sorted);
    });
  }

  static Map<String, Map<String, Object?>> _encodeAnnualRateEvidences(
    Map<String, Map<String, AssetLiabilityAnnualRateEvidence>> source,
  ) {
    return source.map((month, evidences) {
      final sortedKeys = evidences.keys.toList()..sort();
      return MapEntry(month, <String, Object?>{
        for (final key in sortedKeys) key: evidences[key]!.toJson(),
      });
    });
  }

  static List<Map<String, Object?>> _encodeRecurringIncomeTemplates(
    List<AssetLiabilityRecurringIncomeTemplate> templates,
  ) {
    final sorted = List<AssetLiabilityRecurringIncomeTemplate>.from(templates)
      ..sort((a, b) {
        final day = a.dayOfMonth.compareTo(b.dayOfMonth);
        if (day != 0) {
          return day;
        }
        return a.name.compareTo(b.name);
      });
    return [
      for (final template in sorted)
        <String, Object?>{
          'id': template.id,
          'dayOfMonth': template.dayOfMonth,
          'name': template.name,
          'amount': template.amount,
          'destinationAccountId': template.destinationAccountId,
          'destinationAccountName': template.destinationAccountName,
        },
    ];
  }

  static List<Map<String, Object?>> _encodeMonthlySnapshots(
    List<AssetLiabilityMonthlySnapshot> snapshots,
  ) {
    final sorted = List<AssetLiabilityMonthlySnapshot>.from(snapshots)
      ..sort((a, b) => a.monthKey.compareTo(b.monthKey));
    return [
      for (final snapshot in sorted)
        <String, Object?>{
          'monthKey': snapshot.monthKey,
          'savedAt': snapshot.savedAt.toIso8601String(),
          'positiveAssetTotal': snapshot.positiveAssetTotal,
          'liabilityTotal': snapshot.liabilityTotal,
          'netWorth': snapshot.netWorth,
          'cashLikeTotal': snapshot.cashLikeTotal,
          'monthlyScheduledPaymentTotal': snapshot.monthlyScheduledPaymentTotal,
          'monthlyPaidPaymentTotal': snapshot.monthlyPaidPaymentTotal,
          'monthlyUnpaidPaymentTotal': snapshot.monthlyUnpaidPaymentTotal,
          'monthlyActualPaymentTotal': snapshot.monthlyActualPaymentTotal,
          'monthlyPaymentDifferenceTotal':
              snapshot.monthlyPaymentDifferenceTotal,
          'overduePaymentCount': snapshot.overduePaymentCount,
        },
    ];
  }

  static List<Map<String, Object?>> _encodeSyncAuditLogs(
    List<AssetLiabilitySyncAuditLog> logs,
  ) {
    final sorted = List<AssetLiabilitySyncAuditLog>.from(logs)
      ..sort((a, b) => b.executedAt.compareTo(a.executedAt));
    return [for (final log in sorted) log.toJson()];
  }

  static Map<String, List<Map<String, Object?>>> _encodeIncomePlans(
    Map<String, List<AssetLiabilityIncomePlan>> source,
  ) {
    return source.map((month, plans) {
      final sorted = List<AssetLiabilityIncomePlan>.from(plans)
        ..sort((a, b) => a.date.compareTo(b.date));
      return MapEntry(month, [
        for (final plan in sorted)
          <String, Object?>{
            'id': plan.id,
            'date': DateFormat('yyyy-MM-dd').format(plan.date),
            'name': plan.name,
            'amount': plan.amount,
            'destinationAccountId': plan.destinationAccountId,
            'destinationAccountName': plan.destinationAccountName,
            'received': plan.received,
          },
      ]);
    });
  }

  static Map<String, List<Map<String, Object?>>> _encodeTransferTasks(
    Map<String, List<AssetLiabilityTransferTask>> source,
  ) {
    return source.map((month, tasks) {
      final sorted = List<AssetLiabilityTransferTask>.from(tasks)
        ..sort(_compareTransferTasks);
      return MapEntry(month, [
        for (final task in sorted)
          <String, Object?>{
            'id': task.id,
            'fromAccountId': task.fromAccountId,
            'fromAccountName': task.fromAccountName,
            'toAccountId': task.toAccountId,
            'toAccountName': task.toAccountName,
            'amount': task.amount,
            'dueDate': task.dueDate == null
                ? null
                : DateFormat('yyyy-MM-dd').format(task.dueDate!),
            'completed': task.completed,
            'completedAt': task.completedAt?.toIso8601String(),
            'completionMemo': task.completionMemo,
            'canceled': task.canceled,
            'canceledAt': task.canceledAt?.toIso8601String(),
            'cancellationReason': task.cancellationReason,
          },
      ]);
    });
  }

  static Map<String, List<Map<String, Object?>>> _encodeCardStatementLines(
    Map<String, List<AssetLiabilityCardStatementLine>> source,
  ) {
    return source.map((month, lines) {
      final sorted = List<AssetLiabilityCardStatementLine>.from(lines)
        ..sort(_compareCardStatementLines);
      return MapEntry(month, [
        for (final line in sorted)
          <String, Object?>{
            'id': line.id,
            'billingAccountId': line.billingAccountId,
            'billingAccountName': line.billingAccountName,
            'postedAt': line.postedAt?.toIso8601String(),
            'description': line.description,
            'amount': line.amount,
          },
      ]);
    });
  }

  static int _compareCardStatementLines(
    AssetLiabilityCardStatementLine a,
    AssetLiabilityCardStatementLine b,
  ) {
    final billing = a.billingAccountId.compareTo(b.billingAccountId);
    if (billing != 0) {
      return billing;
    }
    final dateA = a.postedAt;
    final dateB = b.postedAt;
    if (dateA != null && dateB != null) {
      final date = dateA.compareTo(dateB);
      if (date != 0) {
        return date;
      }
    } else if (dateA != null) {
      return -1;
    } else if (dateB != null) {
      return 1;
    }
    return a.description.compareTo(b.description);
  }

  static int _compareTransferTasks(
    AssetLiabilityTransferTask a,
    AssetLiabilityTransferTask b,
  ) {
    final aDue = a.dueDate;
    final bDue = b.dueDate;
    if (aDue != null && bDue != null) {
      final date = aDue.compareTo(bDue);
      if (date != 0) {
        return date;
      }
    } else if (aDue != null) {
      return -1;
    } else if (bDue != null) {
      return 1;
    }
    return a.id.compareTo(b.id);
  }

  static Map<String, String> _cleanStringMap(Map<String, String> source) {
    final result = <String, String>{};
    for (final entry in source.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  }

  static String? _cleanNullableString(Object? source) {
    final value = source?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static double? _parseNonNullDouble(Object? source) {
    if (source is num) {
      return source.toDouble();
    }
    if (source == null) {
      return null;
    }
    return double.tryParse(source.toString().replaceAll(',', ''));
  }

  static int? _parseNonNullInt(Object? source) {
    if (source is num) {
      return source.toInt();
    }
    if (source == null) {
      return null;
    }
    return int.tryParse(source.toString().replaceAll(',', ''));
  }
}
