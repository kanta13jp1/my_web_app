import 'dart:convert';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssetLiabilityMonthlyState {
  final Map<String, double> paymentOverrides;
  final Set<String> paidAccountNames;
  final Map<String, String> paymentSourceAccountIds;
  final Map<String, String> cardBillingAccountIds;
  final List<AssetLiabilityIncomePlan> incomePlans;

  const AssetLiabilityMonthlyState({
    this.paymentOverrides = const <String, double>{},
    this.paidAccountNames = const <String>{},
    this.paymentSourceAccountIds = const <String, String>{},
    this.cardBillingAccountIds = const <String, String>{},
    this.incomePlans = const <AssetLiabilityIncomePlan>[],
  });

  bool get isEmpty =>
      paymentOverrides.isEmpty &&
      paidAccountNames.isEmpty &&
      paymentSourceAccountIds.isEmpty &&
      cardBillingAccountIds.isEmpty &&
      incomePlans.isEmpty;
}

class AssetLiabilityMonthlyStateStore {
  static const String paymentPrefsKey =
      'asset_liability_monthly_payment_overrides_v1';
  static const String paidPrefsKey = 'asset_liability_paid_accounts_v1';
  static const String paymentSourcePrefsKey =
      'asset_liability_payment_source_accounts_v1';
  static const String cardBillingPrefsKey =
      'asset_liability_card_billing_accounts_v1';
  static const String incomePrefsKey = 'asset_liability_income_plans_v1';
  static const String defaultPaymentSourcePrefsKey =
      'asset_liability_default_payment_source_accounts_v1';
  static const String recurringIncomeTemplatePrefsKey =
      'asset_liability_recurring_income_templates_v1';
  static const String monthlySnapshotPrefsKey =
      'asset_liability_monthly_snapshots_v1';

  const AssetLiabilityMonthlyStateStore();

  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    final prefs = await SharedPreferences.getInstance();
    final monthKey = formatMonthKey(month);
    return AssetLiabilityMonthlyState(
      paymentOverrides: paymentOverridesForMonth(
        prefs.getString(paymentPrefsKey),
        monthKey,
      ),
      paidAccountNames: paidAccountsForMonth(
        prefs.getString(paidPrefsKey),
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
      incomePlans: incomePlansForMonth(
        prefs.getString(incomePrefsKey),
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
      allPayments[monthKey] = Map<String, double>.from(
        state.paymentOverrides,
      );
    }

    final allPaidAccounts = decodePaidAccounts(
      prefs.getString(paidPrefsKey),
    );
    if (state.paidAccountNames.isEmpty) {
      allPaidAccounts.remove(monthKey);
    } else {
      allPaidAccounts[monthKey] = Set<String>.from(state.paidAccountNames);
    }

    await prefs.setString(paymentPrefsKey, jsonEncode(allPayments));
    await prefs.setString(
      paidPrefsKey,
      jsonEncode(_encodePaid(allPaidAccounts)),
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
    await prefs.setString(
      paymentSourcePrefsKey,
      jsonEncode(allPaymentSources),
    );

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

    final allIncomePlans = decodeIncomePlans(
      prefs.getString(incomePrefsKey),
    );
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
  }

  Future<Map<String, String>> loadDefaultPaymentSources() async {
    final prefs = await SharedPreferences.getInstance();
    return decodeStringMap(prefs.getString(defaultPaymentSourcePrefsKey));
  }

  Future<void> saveDefaultPaymentSources(
    Map<String, String> sources,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      defaultPaymentSourcePrefsKey,
      jsonEncode(_cleanStringMap(sources)),
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
    DateTime targetMonth,
  ) async {
    final previousMonth = DateTime(targetMonth.year, targetMonth.month - 1);
    final previousState = await loadMonth(previousMonth);
    final copied = copyPreviousMonthState(
      previousState: previousState,
      targetMonth: targetMonth,
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

  static String formatMonthKey(DateTime month) {
    return DateFormat('yyyy-MM').format(month);
  }

  static AssetLiabilityMonthlyState copyPreviousMonthState({
    required AssetLiabilityMonthlyState previousState,
    required DateTime targetMonth,
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

    return AssetLiabilityMonthlyState(
      paymentOverrides: Map<String, double>.from(
        previousState.paymentOverrides,
      ),
      paymentSourceAccountIds: Map<String, String>.from(
        previousState.paymentSourceAccountIds,
      ),
      cardBillingAccountIds: Map<String, String>.from(
        previousState.cardBillingAccountIds,
      ),
      incomePlans: copiedIncomePlans,
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
          destinationAccountId:
              _cleanNullableString(rawTemplate['destinationAccountId']),
          destinationAccountName:
              _cleanNullableString(rawTemplate['destinationAccountName']),
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
      final positiveAssetTotal =
          _parseNonNullDouble(rawSnapshot['positiveAssetTotal']);
      final liabilityTotal = _parseNonNullDouble(rawSnapshot['liabilityTotal']);
      final netWorth = _parseNonNullDouble(rawSnapshot['netWorth']);
      final cashLikeTotal = _parseNonNullDouble(rawSnapshot['cashLikeTotal']);
      final monthlyScheduledPaymentTotal =
          _parseNonNullDouble(rawSnapshot['monthlyScheduledPaymentTotal']);
      final monthlyPaidPaymentTotal =
          _parseNonNullDouble(rawSnapshot['monthlyPaidPaymentTotal']);
      final monthlyUnpaidPaymentTotal =
          _parseNonNullDouble(rawSnapshot['monthlyUnpaidPaymentTotal']);
      final overduePaymentCount =
          _parseNonNullInt(rawSnapshot['overduePaymentCount']);
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
          overduePaymentCount: overduePaymentCount,
        ),
      );
    }
    snapshots.sort((a, b) => a.monthKey.compareTo(b.monthKey));
    return snapshots;
  }

  static Map<String, double> paymentOverridesForMonth(
    String? raw,
    String monthKey,
  ) {
    return Map<String, double>.from(
      decodePaymentOverrides(raw)[monthKey] ?? const <String, double>{},
    );
  }

  static Set<String> paidAccountsForMonth(String? raw, String monthKey) {
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

  static List<AssetLiabilityIncomePlan> incomePlansForMonth(
    String? raw,
    String monthKey,
  ) {
    return List<AssetLiabilityIncomePlan>.from(
      decodeIncomePlans(raw)[monthKey] ?? const <AssetLiabilityIncomePlan>[],
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

    final migratedPaidAccounts = <String>{};
    for (final accountKey in state.paidAccountNames) {
      migratedPaidAccounts.add(legacyKeyToAccountId[accountKey] ?? accountKey);
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

    return AssetLiabilityMonthlyState(
      paymentOverrides: migratedPayments,
      paidAccountNames: migratedPaidAccounts,
      paymentSourceAccountIds: migratedPaymentSources,
      cardBillingAccountIds: migratedCardBillingAccounts,
      incomePlans: state.incomePlans,
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
          'overduePaymentCount': snapshot.overduePaymentCount,
        },
    ];
  }

  static Map<String, List<Map<String, Object?>>> _encodeIncomePlans(
    Map<String, List<AssetLiabilityIncomePlan>> source,
  ) {
    return source.map((month, plans) {
      final sorted = List<AssetLiabilityIncomePlan>.from(plans)
        ..sort((a, b) => a.date.compareTo(b.date));
      return MapEntry(
        month,
        [
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
        ],
      );
    });
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
