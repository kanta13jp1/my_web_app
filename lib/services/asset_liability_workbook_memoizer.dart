import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/contact_log.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/card_statement_refetch_service.dart';

/// [AssetLiabilityPlanningService.buildWorkbook] の入力値を構造的に
/// フィンガープリント化し、入力が不変な build() 再呼び出しで直前の
/// [AssetLiabilityWorkbook] を再利用するメモ化器 (#4095)。
///
/// Map/Set/List のミューテーション（in-place 更新）を取りこぼさないよう、
/// オブジェクト同一性ではなく内容の正規化直列化で一致判定する。
class AssetLiabilityWorkbookMemoizer {
  String? _lastSignature;
  AssetLiabilityWorkbook? _lastWorkbook;
  int _cacheHits = 0;
  int _cacheMisses = 0;

  int get cacheHits => _cacheHits;
  int get cacheMisses => _cacheMisses;

  void clear() {
    _lastSignature = null;
    _lastWorkbook = null;
  }

  AssetLiabilityWorkbook? resolve({
    required AssetLiabilityPlanningService planner,
    required Map<String, double> latestSnapshot,
    required DateTime baseDate,
    required Map<String, double> confirmedPaymentDays,
    required Map<String, double> monthlyPaymentOverrides,
    required Map<String, double> actualPaymentAmounts,
    required Map<String, String> paymentDifferenceReasons,
    required Map<String, double> annualRateOverrides,
    required Map<String, int> paymentDayOverrides,
    required Set<String> paidAccountNames,
    required Set<String> billingConfirmedAccountIds,
    required Map<String, String> paymentSourceAccountIds,
    required Map<String, String> defaultPaymentSourceAccountIds,
    required Map<String, String> defaultCardBillingAccountIds,
    required Map<String, String> cardBillingAccountIds,
    required Map<String, AssetLiabilityRevolvingCreditConfig> revolvingConfigs,
    required Map<String, AssetCardUsagePolicy> cardUsagePolicies,
    required List<AssetLiabilityIncomePlan> incomePlans,
    required List<AssetLiabilityCardStatementLine> cardStatementLines,
    required List<AssetLiabilityTransferTask> transferTasks,
    required List<AssetRecurringFixedCost> recurringFixedCosts,
    required bool includeDefaultFixedPayments,
    required int? salaryDay,
    List<CreditorContactLog> contactLogs = const <CreditorContactLog>[],
    Map<String, CardStatementImportStatus> statementImportStatuses =
        const <String, CardStatementImportStatus>{},
  }) {
    if (latestSnapshot.isEmpty) {
      clear();
      return null;
    }

    final signature = _buildSignature(
      latestSnapshot: latestSnapshot,
      baseDate: baseDate,
      confirmedPaymentDays: confirmedPaymentDays,
      monthlyPaymentOverrides: monthlyPaymentOverrides,
      actualPaymentAmounts: actualPaymentAmounts,
      paymentDifferenceReasons: paymentDifferenceReasons,
      annualRateOverrides: annualRateOverrides,
      paymentDayOverrides: paymentDayOverrides,
      paidAccountNames: paidAccountNames,
      billingConfirmedAccountIds: billingConfirmedAccountIds,
      paymentSourceAccountIds: paymentSourceAccountIds,
      defaultPaymentSourceAccountIds: defaultPaymentSourceAccountIds,
      defaultCardBillingAccountIds: defaultCardBillingAccountIds,
      cardBillingAccountIds: cardBillingAccountIds,
      revolvingConfigs: revolvingConfigs,
      cardUsagePolicies: cardUsagePolicies,
      incomePlans: incomePlans,
      cardStatementLines: cardStatementLines,
      transferTasks: transferTasks,
      recurringFixedCosts: recurringFixedCosts,
      includeDefaultFixedPayments: includeDefaultFixedPayments,
      salaryDay: salaryDay,
      contactLogs: contactLogs,
      statementImportStatuses: statementImportStatuses,
    );

    if (signature == _lastSignature && _lastWorkbook != null) {
      _cacheHits += 1;
      return _lastWorkbook;
    }

    _cacheMisses += 1;
    _lastSignature = signature;
    _lastWorkbook = planner.buildWorkbook(
      latestSnapshot: latestSnapshot,
      baseDate: baseDate,
      confirmedPaymentDays: confirmedPaymentDays,
      monthlyPaymentOverrides: monthlyPaymentOverrides,
      actualPaymentAmounts: actualPaymentAmounts,
      paymentDifferenceReasons: paymentDifferenceReasons,
      annualRateOverrides: annualRateOverrides,
      paymentDayOverrides: paymentDayOverrides,
      paidAccountNames: paidAccountNames,
      billingConfirmedAccountIds: billingConfirmedAccountIds,
      paymentSourceAccountIds: paymentSourceAccountIds,
      defaultPaymentSourceAccountIds: defaultPaymentSourceAccountIds,
      defaultCardBillingAccountIds: defaultCardBillingAccountIds,
      cardBillingAccountIds: cardBillingAccountIds,
      revolvingConfigs: revolvingConfigs,
      cardUsagePolicies: cardUsagePolicies,
      incomePlans: incomePlans,
      cardStatementLines: cardStatementLines,
      transferTasks: transferTasks,
      recurringFixedCosts: recurringFixedCosts,
      includeDefaultFixedPayments: includeDefaultFixedPayments,
      salaryDay: salaryDay,
      contactLogs: contactLogs,
      statementImportStatuses: statementImportStatuses,
    );
    return _lastWorkbook;
  }

  static String _buildSignature({
    required Map<String, double> latestSnapshot,
    required DateTime baseDate,
    required Map<String, double> confirmedPaymentDays,
    required Map<String, double> monthlyPaymentOverrides,
    required Map<String, double> actualPaymentAmounts,
    required Map<String, String> paymentDifferenceReasons,
    required Map<String, double> annualRateOverrides,
    required Map<String, int> paymentDayOverrides,
    required Set<String> paidAccountNames,
    required Set<String> billingConfirmedAccountIds,
    required Map<String, String> paymentSourceAccountIds,
    required Map<String, String> defaultPaymentSourceAccountIds,
    required Map<String, String> defaultCardBillingAccountIds,
    required Map<String, String> cardBillingAccountIds,
    required Map<String, AssetLiabilityRevolvingCreditConfig> revolvingConfigs,
    required Map<String, AssetCardUsagePolicy> cardUsagePolicies,
    required List<AssetLiabilityIncomePlan> incomePlans,
    required List<AssetLiabilityCardStatementLine> cardStatementLines,
    required List<AssetLiabilityTransferTask> transferTasks,
    required List<AssetRecurringFixedCost> recurringFixedCosts,
    required bool includeDefaultFixedPayments,
    required int? salaryDay,
    required List<CreditorContactLog> contactLogs,
    required Map<String, CardStatementImportStatus> statementImportStatuses,
  }) {
    final buf = StringBuffer();
    buf.write('b:');
    _writeInt(buf, baseDate.millisecondsSinceEpoch);
    buf.write(baseDate.isUtc ? '1' : '0');
    buf.write(includeDefaultFixedPayments ? '1' : '0');
    _writeNullableInt(buf, salaryDay);

    _writeDoubleMap(buf, 'ls', latestSnapshot);
    _writeDoubleMap(buf, 'cpd', confirmedPaymentDays);
    _writeDoubleMap(buf, 'mpo', monthlyPaymentOverrides);
    _writeDoubleMap(buf, 'apa', actualPaymentAmounts);
    _writeStringMap(buf, 'pdr', paymentDifferenceReasons);
    _writeDoubleMap(buf, 'aro', annualRateOverrides);
    _writeIntMap(buf, 'pdo', paymentDayOverrides);
    _writeStringSet(buf, 'pan', paidAccountNames);
    _writeStringSet(buf, 'bca', billingConfirmedAccountIds);
    _writeStringMap(buf, 'psa', paymentSourceAccountIds);
    _writeStringMap(buf, 'dpsa', defaultPaymentSourceAccountIds);
    _writeStringMap(buf, 'dcba', defaultCardBillingAccountIds);
    _writeStringMap(buf, 'cba', cardBillingAccountIds);

    final rcKeys = revolvingConfigs.keys.toList()..sort();
    buf.write('|rc:${rcKeys.length}:');
    for (final key in rcKeys) {
      final v = revolvingConfigs[key]!;
      _writeStr(buf, key);
      _writeDouble(buf, v.monthlyAmount);
      _writeDouble(buf, v.newUsageAmount);
      _writeInt(buf, v.paymentDay);
      _writeDouble(buf, v.creditLimit);
    }

    final cupKeys = cardUsagePolicies.keys.toList()..sort();
    buf.write('|cup:${cupKeys.length}:');
    for (final key in cupKeys) {
      final v = cardUsagePolicies[key]!;
      _writeStr(buf, key);
      buf.write(v.enforceOneShot ? '1' : '0');
      _writeNullableInt(buf, v.changedAt?.millisecondsSinceEpoch);
      _writeStr(buf, v.memo);
    }

    buf.write('|ip:${incomePlans.length}:');
    for (final item in incomePlans) {
      _writeStr(buf, item.id);
      _writeInt(buf, item.date.millisecondsSinceEpoch);
      _writeStr(buf, item.name);
      _writeDouble(buf, item.amount);
      _writeNullableStr(buf, item.destinationAccountId);
      _writeNullableStr(buf, item.destinationAccountName);
      buf.write(item.received ? '1' : '0');
    }

    buf.write('|csl:${cardStatementLines.length}:');
    for (final item in cardStatementLines) {
      _writeStr(buf, item.id);
      _writeStr(buf, item.billingAccountId);
      _writeNullableStr(buf, item.billingAccountName);
      _writeNullableInt(buf, item.postedAt?.millisecondsSinceEpoch);
      _writeStr(buf, item.description);
      _writeDouble(buf, item.amount);
      _writeNullableStr(buf, item.category);
      buf.write(item.isProvisional ? '1' : '0');
      buf.write(item.isConfiguredAdjustment ? '1' : '0');
      buf.write(item.excludeFromStatementTotal ? '1' : '0');
      _writeNullableInt(buf, item.createdAt?.millisecondsSinceEpoch);
    }

    buf.write('|tt:${transferTasks.length}:');
    for (final item in transferTasks) {
      _writeStr(buf, item.id);
      _writeStr(buf, item.fromAccountId);
      _writeStr(buf, item.fromAccountName);
      _writeStr(buf, item.toAccountId);
      _writeStr(buf, item.toAccountName);
      _writeDouble(buf, item.amount);
      _writeNullableInt(buf, item.dueDate?.millisecondsSinceEpoch);
      buf.write(item.completed ? '1' : '0');
      _writeNullableInt(buf, item.completedAt?.millisecondsSinceEpoch);
      _writeStr(buf, item.completionMemo);
      buf.write(item.canceled ? '1' : '0');
      _writeNullableInt(buf, item.canceledAt?.millisecondsSinceEpoch);
      _writeStr(buf, item.cancellationReason);
      _writeNullableStr(buf, item.dedupeKey);
    }

    buf.write('|rfc:${recurringFixedCosts.length}:');
    for (final item in recurringFixedCosts) {
      _writeStr(buf, item.id);
      _writeStr(buf, item.name);
      _writeDouble(buf, item.amount);
      _writeInt(buf, item.paymentDay);
      _writeNullableInt(buf, item.lastBillingDate?.millisecondsSinceEpoch);
      _writeStr(buf, item.cadence.name);
      _writeNullableStr(buf, item.sourceAccountId);
      _writeStr(buf, item.category.name);
      _writeStr(buf, item.subscriptionReviewDecision.name);
      _writeStr(buf, item.billingGateway.name);
      _writeStr(buf, item.currency.name);
      _writeNullableDouble(buf, item.usdAmount);
    }

    buf.write('|ccl:${contactLogs.length}:');
    for (final item in contactLogs) {
      _writeStr(buf, item.id);
      _writeStr(buf, item.accountId);
      _writeInt(buf, item.contactedAt.millisecondsSinceEpoch);
      _writeStr(buf, item.agreedSummary);
      _writeNullableInt(buf, item.nextFollowUpDate?.millisecondsSinceEpoch);
      _writeStr(buf, item.note);
    }

    final statusKeys = statementImportStatuses.keys.toList()..sort();
    buf.write('|csis:${statusKeys.length}:');
    for (final key in statusKeys) {
      final status = statementImportStatuses[key]!;
      _writeStr(buf, key);
      _writeStr(buf, status.lastResult.name);
      _writeInt(buf, status.lastAttemptAt.millisecondsSinceEpoch);
      _writeStr(buf, status.failureReason);
      _writeInt(buf, status.importedCount);
    }

    return buf.toString();
  }

  static void _writeStr(StringBuffer buf, String value) {
    buf.write('${value.length}:$value');
  }

  static void _writeNullableStr(StringBuffer buf, String? value) {
    if (value == null) {
      buf.write('N;');
    } else {
      buf.write('S:');
      _writeStr(buf, value);
    }
  }

  static void _writeInt(StringBuffer buf, int value) {
    buf.write('$value;');
  }

  static void _writeNullableInt(StringBuffer buf, int? value) {
    buf.write(value == null ? 'N;' : 'I:$value;');
  }

  static void _writeDouble(StringBuffer buf, double value) {
    final normalized = value == 0.0 ? 0.0 : value;
    buf.write(normalized.isNaN ? 'NaN;' : '${normalized.toString()};');
  }

  static void _writeNullableDouble(StringBuffer buf, double? value) {
    if (value == null) {
      buf.write('N;');
    } else {
      buf.write('D:');
      _writeDouble(buf, value);
    }
  }

  static void _writeDoubleMap(
    StringBuffer buf,
    String tag,
    Map<String, double> map,
  ) {
    final keys = map.keys.toList()..sort();
    buf.write('|$tag:${keys.length}:');
    for (final key in keys) {
      _writeStr(buf, key);
      _writeDouble(buf, map[key]!);
    }
  }

  static void _writeIntMap(
    StringBuffer buf,
    String tag,
    Map<String, int> map,
  ) {
    final keys = map.keys.toList()..sort();
    buf.write('|$tag:${keys.length}:');
    for (final key in keys) {
      _writeStr(buf, key);
      _writeInt(buf, map[key]!);
    }
  }

  static void _writeStringMap(
    StringBuffer buf,
    String tag,
    Map<String, String> map,
  ) {
    final keys = map.keys.toList()..sort();
    buf.write('|$tag:${keys.length}:');
    for (final key in keys) {
      _writeStr(buf, key);
      _writeStr(buf, map[key]!);
    }
  }

  static void _writeStringSet(
    StringBuffer buf,
    String tag,
    Set<String> set,
  ) {
    final items = set.toList()..sort();
    buf.write('|$tag:${items.length}:');
    for (final item in items) {
      _writeStr(buf, item);
    }
  }
}
