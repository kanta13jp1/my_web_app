import 'package:my_web_app/models/asset_liability_persistence.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';

abstract class AssetLiabilityRepository {
  const AssetLiabilityRepository();

  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month);

  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  });

  Future<Map<String, String>> loadDefaultPaymentSources();

  Future<void> saveDefaultPaymentSources(Map<String, String> sources);

  Future<List<AssetLiabilityRecurringIncomeTemplate>>
      loadRecurringIncomeTemplates();

  Future<void> saveRecurringIncomeTemplates(
    List<AssetLiabilityRecurringIncomeTemplate> templates,
  );

  Future<AssetLiabilityMonthlyState> copyPreviousMonthToMonth(
    DateTime targetMonth,
  );

  Future<List<AssetLiabilityMonthlySnapshot>> loadMonthlySnapshots();

  Future<void> saveMonthlySnapshot(AssetLiabilityMonthlySnapshot snapshot);

  Future<AssetLiabilityPersistenceSnapshot> loadPersistenceSnapshot(
    DateTime month,
  ) async {
    return AssetLiabilityPersistenceSnapshot(
      monthKey: AssetLiabilityMonthlyStateStore.formatMonthKey(month),
      monthlyState: await loadMonth(month),
      defaultPaymentSourceAccountIds: await loadDefaultPaymentSources(),
      recurringIncomeTemplates: await loadRecurringIncomeTemplates(),
      monthlySnapshots: await loadMonthlySnapshots(),
    );
  }
}

class SharedPreferencesAssetLiabilityRepository
    extends AssetLiabilityRepository {
  final AssetLiabilityMonthlyStateStore store;

  const SharedPreferencesAssetLiabilityRepository({
    this.store = const AssetLiabilityMonthlyStateStore(),
  });

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) {
    return store.loadMonth(month);
  }

  @override
  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) {
    return store.saveMonth(month: month, state: state);
  }

  @override
  Future<Map<String, String>> loadDefaultPaymentSources() {
    return store.loadDefaultPaymentSources();
  }

  @override
  Future<void> saveDefaultPaymentSources(Map<String, String> sources) {
    return store.saveDefaultPaymentSources(sources);
  }

  @override
  Future<List<AssetLiabilityRecurringIncomeTemplate>>
      loadRecurringIncomeTemplates() {
    return store.loadRecurringIncomeTemplates();
  }

  @override
  Future<void> saveRecurringIncomeTemplates(
    List<AssetLiabilityRecurringIncomeTemplate> templates,
  ) {
    return store.saveRecurringIncomeTemplates(templates);
  }

  @override
  Future<AssetLiabilityMonthlyState> copyPreviousMonthToMonth(
    DateTime targetMonth,
  ) {
    return store.copyPreviousMonthToMonth(targetMonth);
  }

  @override
  Future<List<AssetLiabilityMonthlySnapshot>> loadMonthlySnapshots() {
    return store.loadMonthlySnapshots();
  }

  @override
  Future<void> saveMonthlySnapshot(AssetLiabilityMonthlySnapshot snapshot) {
    return store.saveMonthlySnapshot(snapshot);
  }
}
