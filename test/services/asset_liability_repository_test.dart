import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_persistence.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AssetLiabilityRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('saves and restores monthly state through local repository', () async {
      const repository = SharedPreferencesAssetLiabilityRepository();
      final month = DateTime(2026, 5, 14);

      await repository.saveMonth(
        month: month,
        state: AssetLiabilityMonthlyState(
          paymentOverrides: const <String, double>{
            'mobit': 70000,
            'kddi_provider': 5764,
          },
          paidAccountNames: const <String>{'kddi_provider'},
          paymentSourceAccountIds: const <String, String>{
            'mobit': 'smbc_otsuka',
          },
          incomePlans: <AssetLiabilityIncomePlan>[
            AssetLiabilityIncomePlan(
              id: 'salary',
              date: DateTime(2026, 5, 25),
              name: 'Salary',
              amount: 250000,
              destinationAccountId: 'smbc_otsuka',
              destinationAccountName: 'SMBC Otsuka',
              received: false,
            ),
          ],
        ),
      );

      final restored = await repository.loadMonth(DateTime(2026, 5, 31));

      expect(restored.paymentOverrides['mobit'], 70000);
      expect(restored.paymentOverrides['kddi_provider'], 5764);
      expect(restored.paidAccountNames, contains('kddi_provider'));
      expect(restored.paymentSourceAccountIds['mobit'], 'smbc_otsuka');
      expect(restored.incomePlans.single.name, 'Salary');
      expect(restored.incomePlans.single.received, isFalse);
    });

    test(
      'keeps SharedPreferences persistence working without Supabase',
      () async {
        const repository = SharedPreferencesAssetLiabilityRepository();

        await repository.saveDefaultPaymentSources(const <String, String>{
          'kddi_provider': 'smbc_otsuka',
        });
        await repository.saveRecurringIncomeTemplates(
          const <AssetLiabilityRecurringIncomeTemplate>[
            AssetLiabilityRecurringIncomeTemplate(
              id: 'salary',
              dayOfMonth: 25,
              name: 'Salary',
              amount: 250000,
              destinationAccountId: 'smbc_otsuka',
              destinationAccountName: 'SMBC Otsuka',
            ),
          ],
        );

        final defaults = await repository.loadDefaultPaymentSources();
        final templates = await repository.loadRecurringIncomeTemplates();

        expect(defaults, <String, String>{'kddi_provider': 'smbc_otsuka'});
        expect(templates.single.id, 'salary');
        expect(templates.single.destinationAccountId, 'smbc_otsuka');
      },
    );

    test('saves and restores monthly snapshots through repository', () async {
      const repository = SharedPreferencesAssetLiabilityRepository();
      final snapshot = AssetLiabilityMonthlySnapshot(
        monthKey: '2026-05',
        savedAt: DateTime.utc(2026, 5, 31, 12),
        positiveAssetTotal: 120000,
        liabilityTotal: -7200000,
        netWorth: -7080000,
        cashLikeTotal: 60000,
        monthlyScheduledPaymentTotal: 180000,
        monthlyPaidPaymentTotal: 100000,
        monthlyUnpaidPaymentTotal: 80000,
        overduePaymentCount: 1,
      );

      await repository.saveMonthlySnapshot(snapshot);

      final snapshots = await repository.loadMonthlySnapshots();

      expect(snapshots, hasLength(1));
      expect(snapshots.single.monthKey, '2026-05');
      expect(snapshots.single.monthlyUnpaidPaymentTotal, 80000);
    });

    test('builds a full local persistence snapshot', () async {
      const repository = SharedPreferencesAssetLiabilityRepository();
      final month = DateTime(2026, 5, 1);

      await repository.saveMonth(
        month: month,
        state: const AssetLiabilityMonthlyState(
          paymentOverrides: <String, double>{'mobit': 70000},
        ),
      );
      await repository.saveDefaultPaymentSources(const <String, String>{
        'mobit': 'smbc_otsuka',
      });
      await repository.saveMonthlySnapshot(
        AssetLiabilityMonthlySnapshot(
          monthKey: '2026-05',
          savedAt: DateTime.utc(2026, 5, 31, 12),
          positiveAssetTotal: 120000,
          liabilityTotal: -7200000,
          netWorth: -7080000,
          cashLikeTotal: 60000,
          monthlyScheduledPaymentTotal: 180000,
          monthlyPaidPaymentTotal: 100000,
          monthlyUnpaidPaymentTotal: 80000,
          overduePaymentCount: 1,
        ),
      );

      final snapshot = await repository.loadPersistenceSnapshot(month);

      expect(snapshot.monthKey, '2026-05');
      expect(snapshot.monthlyState.paymentOverrides['mobit'], 70000);
      expect(snapshot.defaultPaymentSourceAccountIds['mobit'], 'smbc_otsuka');
      expect(snapshot.monthlySnapshots.single.netWorth, -7080000);
    });

    test(
      'supports fake repository implementations for Supabase-free tests',
      () async {
        final repository = _FakeAssetLiabilityRepository();
        final month = DateTime(2026, 6, 1);

        await repository.saveMonth(
          month: month,
          state: const AssetLiabilityMonthlyState(
            paymentOverrides: <String, double>{'kddi_provider': 5764},
          ),
        );
        await repository.saveMonthlySnapshot(
          AssetLiabilityMonthlySnapshot(
            monthKey: '2026-06',
            savedAt: DateTime.utc(2026, 6, 30, 12),
            positiveAssetTotal: 100000,
            liabilityTotal: -7000000,
            netWorth: -6900000,
            cashLikeTotal: 50000,
            monthlyScheduledPaymentTotal: 160000,
            monthlyPaidPaymentTotal: 160000,
            monthlyUnpaidPaymentTotal: 0,
            overduePaymentCount: 0,
          ),
        );

        final restored = await repository.loadPersistenceSnapshot(month);

        expect(restored.monthlyState.paymentOverrides['kddi_provider'], 5764);
        expect(restored.monthlySnapshots.single.monthKey, '2026-06');
      },
    );
  });

  group('Asset liability Supabase payloads', () {
    test('round-trips monthly state payload', () {
      final state = AssetLiabilityMonthlyState(
        paymentOverrides: const <String, double>{'mobit': 70000},
        paidAccountNames: const <String>{'kddi_provider'},
        paymentSourceAccountIds: const <String, String>{'mobit': 'smbc_otsuka'},
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'salary',
            date: DateTime(2026, 5, 25),
            name: 'Salary',
            amount: 250000,
            destinationAccountId: 'smbc_otsuka',
            destinationAccountName: 'SMBC Otsuka',
            received: true,
          ),
        ],
      );

      final payload = AssetLiabilityMonthlyStatePayload.fromState(
        monthKey: '2026-05',
        state: state,
      );
      final row = payload.toSupabaseJson(
        userId: 'user-1',
        updatedAt: DateTime.utc(2026, 5, 14),
      );
      final restored = AssetLiabilityMonthlyStatePayload.fromSupabaseJson(
        row,
      ).toState();

      expect(row['user_id'], 'user-1');
      expect(row['month_key'], '2026-05');
      expect(restored.paymentOverrides['mobit'], 70000);
      expect(restored.paidAccountNames, contains('kddi_provider'));
      expect(restored.paymentSourceAccountIds['mobit'], 'smbc_otsuka');
      expect(restored.incomePlans.single.received, isTrue);
    });

    test('round-trips settings and snapshot payloads', () {
      const settings = AssetLiabilityUserSettingsPayload(
        defaultPaymentSourceAccountIds: <String, String>{
          'mobit': 'smbc_otsuka',
        },
        recurringIncomeTemplates: <AssetLiabilityRecurringIncomeTemplate>[
          AssetLiabilityRecurringIncomeTemplate(
            id: 'salary',
            dayOfMonth: 25,
            name: 'Salary',
            amount: 250000,
            destinationAccountId: 'smbc_otsuka',
            destinationAccountName: 'SMBC Otsuka',
          ),
        ],
      );
      final settingsRow = settings.toSupabaseJson(userId: 'user-1');
      final restoredSettings =
          AssetLiabilityUserSettingsPayload.fromSupabaseJson(settingsRow);

      expect(
        restoredSettings.defaultPaymentSourceAccountIds['mobit'],
        'smbc_otsuka',
      );
      expect(restoredSettings.recurringIncomeTemplates.single.id, 'salary');

      final snapshot = AssetLiabilityMonthlySnapshot(
        monthKey: '2026-05',
        savedAt: DateTime.utc(2026, 5, 31, 12),
        positiveAssetTotal: 120000,
        liabilityTotal: -7200000,
        netWorth: -7080000,
        cashLikeTotal: 60000,
        monthlyScheduledPaymentTotal: 180000,
        monthlyPaidPaymentTotal: 100000,
        monthlyUnpaidPaymentTotal: 80000,
        overduePaymentCount: 1,
      );
      final snapshotRow = AssetLiabilityMonthlySnapshotPayload(
        snapshot: snapshot,
      ).toSupabaseJson(userId: 'user-1');
      final restoredSnapshot =
          AssetLiabilityMonthlySnapshotPayload.fromSupabaseJson(
        snapshotRow,
      ).snapshot;

      expect(snapshotRow['user_id'], 'user-1');
      expect(restoredSnapshot.monthKey, '2026-05');
      expect(restoredSnapshot.netWorth, -7080000);
      expect(restoredSnapshot.overduePaymentCount, 1);
    });

    test('documents Supabase table names and required identity columns', () {
      expect(
        AssetLiabilitySupabaseTablePlan.monthlyStatesTable,
        'asset_liability_monthly_states',
      );
      expect(
        AssetLiabilitySupabaseTablePlan.monthlyStateColumns,
        containsAll(<String>['user_id', 'month_key', 'updated_at']),
      );
      expect(
        AssetLiabilitySupabaseTablePlan.monthlySnapshotColumns,
        containsAll(<String>['user_id', 'month_key', 'created_at']),
      );
    });
  });
}

class _FakeAssetLiabilityRepository extends AssetLiabilityRepository {
  final Map<String, AssetLiabilityMonthlyState> _states =
      <String, AssetLiabilityMonthlyState>{};
  final Map<String, String> _defaultSources = <String, String>{};
  final List<AssetLiabilityRecurringIncomeTemplate> _templates =
      <AssetLiabilityRecurringIncomeTemplate>[];
  final List<AssetLiabilityMonthlySnapshot> _snapshots =
      <AssetLiabilityMonthlySnapshot>[];

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    return _states[AssetLiabilityMonthlyStateStore.formatMonthKey(month)] ??
        const AssetLiabilityMonthlyState();
  }

  @override
  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    _states[AssetLiabilityMonthlyStateStore.formatMonthKey(month)] = state;
  }

  @override
  Future<Map<String, String>> loadDefaultPaymentSources() async {
    return Map<String, String>.from(_defaultSources);
  }

  @override
  Future<void> saveDefaultPaymentSources(Map<String, String> sources) async {
    _defaultSources
      ..clear()
      ..addAll(sources);
  }

  @override
  Future<List<AssetLiabilityRecurringIncomeTemplate>>
      loadRecurringIncomeTemplates() async {
    return List<AssetLiabilityRecurringIncomeTemplate>.from(_templates);
  }

  @override
  Future<void> saveRecurringIncomeTemplates(
    List<AssetLiabilityRecurringIncomeTemplate> templates,
  ) async {
    _templates
      ..clear()
      ..addAll(templates);
  }

  @override
  Future<AssetLiabilityMonthlyState> copyPreviousMonthToMonth(
    DateTime targetMonth,
  ) async {
    final previousMonth = DateTime(targetMonth.year, targetMonth.month - 1);
    final copied = AssetLiabilityMonthlyStateStore.copyPreviousMonthState(
      previousState: await loadMonth(previousMonth),
      targetMonth: targetMonth,
    );
    await saveMonth(month: targetMonth, state: copied);
    return copied;
  }

  @override
  Future<List<AssetLiabilityMonthlySnapshot>> loadMonthlySnapshots() async {
    return List<AssetLiabilityMonthlySnapshot>.from(_snapshots);
  }

  @override
  Future<void> saveMonthlySnapshot(
    AssetLiabilityMonthlySnapshot snapshot,
  ) async {
    _snapshots.removeWhere((current) => current.monthKey == snapshot.monthKey);
    _snapshots.add(snapshot);
    _snapshots.sort((a, b) => a.monthKey.compareTo(b.monthKey));
  }
}
