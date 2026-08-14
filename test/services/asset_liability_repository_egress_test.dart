import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';

void main() {
  group('asset liability egress controls', () {
    test('coalesces concurrent monthly loads for the same month', () async {
      final local = _MemoryAssetLiabilityRepository();
      final remote = _CountingRemoteStore()
        ..monthState = const AssetLiabilityMonthlyState(
          paymentOverrides: <String, double>{'mobit': 32000},
        )
        ..monthLoadGate = Completer<void>();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        userIdProvider: () => 'user-1',
      );

      final first = repository.loadMonth(DateTime(2026, 5));
      final second = repository.loadMonth(DateTime(2026, 5, 31));
      await Future<void>.delayed(Duration.zero);

      expect(identical(first, second), isTrue);
      expect(remote.monthLoadCount, 1);

      remote.monthLoadGate!.complete();
      final states = await Future.wait(<Future<AssetLiabilityMonthlyState>>[
        first,
        second,
      ]);

      expect(states[0].paymentOverrides['mobit'], 32000);
      expect(states[1].paymentOverrides, states[0].paymentOverrides);
      expect(local.savedMonthCount, 1);
    });

    test('loads both payment defaults through one remote read', () async {
      final local = _MemoryAssetLiabilityRepository();
      final remote = _CountingRemoteStore()
        ..defaultSettings = AssetLiabilityDefaultPaymentSettings(
          paymentSourceAccountIds: const <String, String>{
            'mobit': 'smbc_otsuka',
          },
          cardBillingAccountIds: const <String, String>{'au': 'aupay_card'},
        );
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        userIdProvider: () => 'user-1',
      );

      final settings = await repository.loadDefaultPaymentSettings();

      expect(settings.paymentSourceAccountIds['mobit'], 'smbc_otsuka');
      expect(settings.cardBillingAccountIds['au'], 'aupay_card');
      expect(remote.defaultSettingsLoadCount, 1);
      expect(remote.legacyDefaultLoadCount, 0);
      expect(local.defaultPaymentSources['mobit'], 'smbc_otsuka');
      expect(local.defaultCardBillingAccounts['au'], 'aupay_card');
    });

    test('compares only the latest bounded monthly snapshot window', () async {
      final snapshots = <AssetLiabilityMonthlySnapshot>[
        for (var index = 0; index < 121; index++)
          _snapshotFor(DateTime(2016, index + 1)),
      ];
      final local = _MemoryAssetLiabilityRepository()
        ..monthlySnapshots = snapshots;
      final remote = _CountingRemoteStore()
        ..monthlySnapshots = snapshots.sublist(1);
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        userIdProvider: () => 'user-1',
      );

      final preview = await repository.previewSyncMonth(DateTime(2026, 1));
      final snapshotItem = preview.items.singleWhere(
        (item) => item.target == AssetLiabilitySyncTarget.monthlySnapshots,
      );

      expect(snapshotItem.dataMatches, isTrue);
      expect(snapshotItem.localCount, 120);
      expect(snapshotItem.remoteCount, 120);
    });
  });
}

AssetLiabilityMonthlySnapshot _snapshotFor(DateTime month) {
  final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
  return AssetLiabilityMonthlySnapshot(
    monthKey: monthKey,
    savedAt: DateTime.utc(month.year, month.month, 1),
    positiveAssetTotal: 100000,
    liabilityTotal: -1000000,
    netWorth: -900000,
    cashLikeTotal: 50000,
    monthlyScheduledPaymentTotal: 100000,
    monthlyPaidPaymentTotal: 50000,
    monthlyUnpaidPaymentTotal: 50000,
    overduePaymentCount: 0,
  );
}

final class _MemoryAssetLiabilityRepository extends AssetLiabilityRepository {
  AssetLiabilityMonthlyState monthState = const AssetLiabilityMonthlyState();
  Map<String, String> defaultPaymentSources = <String, String>{};
  Map<String, String> defaultCardBillingAccounts = <String, String>{};
  int savedMonthCount = 0;
  List<AssetLiabilityMonthlySnapshot> monthlySnapshots =
      <AssetLiabilityMonthlySnapshot>[];

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    return monthState;
  }

  @override
  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    monthState = state;
    savedMonthCount++;
  }

  @override
  Future<Map<String, String>> loadDefaultPaymentSources() async {
    return Map<String, String>.from(defaultPaymentSources);
  }

  @override
  Future<void> saveDefaultPaymentSources(Map<String, String> sources) async {
    defaultPaymentSources = Map<String, String>.from(sources);
  }

  @override
  Future<Map<String, String>> loadDefaultCardBillingAccounts() async {
    return Map<String, String>.from(defaultCardBillingAccounts);
  }

  @override
  Future<void> saveDefaultCardBillingAccounts(
    Map<String, String> accounts,
  ) async {
    defaultCardBillingAccounts = Map<String, String>.from(accounts);
  }

  @override
  Future<List<AssetLiabilityRecurringIncomeTemplate>>
      loadRecurringIncomeTemplates() async {
    return const <AssetLiabilityRecurringIncomeTemplate>[];
  }

  @override
  Future<void> saveRecurringIncomeTemplates(
    List<AssetLiabilityRecurringIncomeTemplate> templates,
  ) async {}

  @override
  Future<AssetLiabilityMonthlyState> copyPreviousMonthToMonth(
    DateTime targetMonth, {
    bool carryOverIncompleteTransferTasks = false,
  }) async {
    return monthState;
  }

  @override
  Future<List<AssetLiabilityMonthlySnapshot>> loadMonthlySnapshots() async {
    return List<AssetLiabilityMonthlySnapshot>.from(monthlySnapshots);
  }

  @override
  Future<void> saveMonthlySnapshot(
    AssetLiabilityMonthlySnapshot snapshot,
  ) async {}
}

final class _CountingRemoteStore extends AssetLiabilityRemoteStore {
  AssetLiabilityMonthlyState? monthState;
  AssetLiabilityDefaultPaymentSettings? defaultSettings;
  Completer<void>? monthLoadGate;
  int monthLoadCount = 0;
  int defaultSettingsLoadCount = 0;
  int legacyDefaultLoadCount = 0;
  List<AssetLiabilityMonthlySnapshot> monthlySnapshots =
      <AssetLiabilityMonthlySnapshot>[];

  @override
  Future<AssetLiabilityMonthlyState?> loadMonth({
    required String userId,
    required DateTime month,
  }) async {
    monthLoadCount++;
    await monthLoadGate?.future;
    return monthState;
  }

  @override
  Future<void> saveMonth({
    required String userId,
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    monthState = state;
  }

  @override
  Future<AssetLiabilityDefaultPaymentSettings?> loadDefaultPaymentSettings({
    required String userId,
  }) async {
    defaultSettingsLoadCount++;
    return defaultSettings;
  }

  @override
  Future<Map<String, String>?> loadDefaultPaymentSources({
    required String userId,
  }) async {
    legacyDefaultLoadCount++;
    return null;
  }

  @override
  Future<Map<String, String>?> loadDefaultCardBillingAccounts({
    required String userId,
  }) async {
    legacyDefaultLoadCount++;
    return null;
  }

  @override
  Future<void> saveDefaultPaymentSources({
    required String userId,
    required Map<String, String> sources,
  }) async {}

  @override
  Future<void> saveDefaultCardBillingAccounts({
    required String userId,
    required Map<String, String> accounts,
  }) async {}

  @override
  Future<List<AssetLiabilityRecurringIncomeTemplate>?>
      loadRecurringIncomeTemplates({required String userId}) async {
    return null;
  }

  @override
  Future<void> saveRecurringIncomeTemplates({
    required String userId,
    required List<AssetLiabilityRecurringIncomeTemplate> templates,
  }) async {}

  @override
  Future<List<AssetLiabilityMonthlySnapshot>?> loadMonthlySnapshots({
    required String userId,
  }) async {
    return List<AssetLiabilityMonthlySnapshot>.from(monthlySnapshots);
  }

  @override
  Future<void> saveMonthlySnapshot({
    required String userId,
    required AssetLiabilityMonthlySnapshot snapshot,
  }) async {}

  @override
  Future<List<AssetLiabilityMonthlyReport>?> loadMonthlyReports({
    required String userId,
    int limit = 24,
  }) async {
    return null;
  }
}
