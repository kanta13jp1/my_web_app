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

  group('FeatureFlaggedAssetLiabilityRepository', () {
    test('factory keeps Supabase sync disabled by default', () {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();

      final repository = AssetLiabilityRepositoryFactory.createDefault(
        localRepository: local,
        remoteStore: remote,
      );

      expect(AssetLiabilityRepositoryFactory.supabaseSyncEnabled, isFalse);
      expect(repository, same(local));
      expect(remote.calls, isEmpty);
    });

    test('does not call remote store when Supabase sync flag is off', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: false,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);

      await repository.saveMonth(month: month, state: _sampleMonthlyState());
      final restored = await repository.loadMonth(month);

      expect(restored.paymentOverrides['mobit'], 70000);
      expect(remote.calls, isEmpty);
    });

    test(
      'saves monthly data and settings through remote store when on',
      () async {
        final local = _FakeAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore();
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);
        final snapshot = _sampleSnapshot('2026-05');

        await repository.saveMonth(month: month, state: _sampleMonthlyState());
        await repository.saveDefaultPaymentSources(const <String, String>{
          'mobit': 'smbc_otsuka',
        });
        await repository.saveRecurringIncomeTemplates(
          <AssetLiabilityRecurringIncomeTemplate>[
            _sampleRecurringIncomeTemplate(),
          ],
        );
        await repository.saveMonthlySnapshot(snapshot);

        expect(remote.monthState('2026-05')?.paymentOverrides['mobit'], 70000);
        expect(remote.defaultPaymentSources['mobit'], 'smbc_otsuka');
        expect(remote.recurringIncomeTemplates.single.id, 'salary');
        expect(remote.monthlySnapshots.single.monthKey, '2026-05');
      },
    );

    test('keeps local save when remote save fails', () async {
      final errors = <Object>[];
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore()..failSaves = true;
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        userIdProvider: () => 'user-1',
        onSyncError: (error, _) => errors.add(error),
      );
      final month = DateTime(2026, 5);

      await repository.saveMonth(month: month, state: _sampleMonthlyState());

      final localState = await local.loadMonth(month);
      expect(localState.paymentOverrides['mobit'], 70000);
      expect(errors, isNotEmpty);
      expect(remote.calls, contains('saveMonth:user-1:2026-05'));
    });

    test('uploads local monthly state when remote is empty', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);
      await local.saveMonth(month: month, state: _sampleMonthlyState());

      final restored = await repository.loadMonth(month);

      expect(restored.paymentOverrides['mobit'], 70000);
      expect(remote.monthState('2026-05')?.paymentOverrides['mobit'], 70000);
    });

    test('restores remote monthly state when local is empty', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore()
        ..seedMonth(DateTime(2026, 5), _sampleMonthlyState());
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);

      final restored = await repository.loadMonth(month);
      final localState = await local.loadMonth(month);

      expect(restored.paymentOverrides['mobit'], 70000);
      expect(localState.paymentOverrides['mobit'], 70000);
    });

    test('restores remote settings and snapshots when local is empty',
        () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore()
        ..seedDefaultPaymentSources(const <String, String>{
          'mobit': 'smbc_otsuka',
        })
        ..seedRecurringIncomeTemplates(<AssetLiabilityRecurringIncomeTemplate>[
          _sampleRecurringIncomeTemplate(),
        ])
        ..seedMonthlySnapshots(<AssetLiabilityMonthlySnapshot>[
          _sampleSnapshot('2026-05'),
        ]);
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        userIdProvider: () => 'user-1',
      );

      final sources = await repository.loadDefaultPaymentSources();
      final templates = await repository.loadRecurringIncomeTemplates();
      final snapshots = await repository.loadMonthlySnapshots();

      expect(sources['mobit'], 'smbc_otsuka');
      expect(templates.single.id, 'salary');
      expect(snapshots.single.monthKey, '2026-05');
      expect((await local.loadDefaultPaymentSources())['mobit'], 'smbc_otsuka');
      expect((await local.loadRecurringIncomeTemplates()).single.id, 'salary');
      expect((await local.loadMonthlySnapshots()).single.monthKey, '2026-05');
    });

    test(
      'keeps local repository usable when no Supabase user is available',
      () async {
        final local = _FakeAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore();
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          userIdProvider: () => null,
        );
        final month = DateTime(2026, 5);

        await repository.saveMonth(month: month, state: _sampleMonthlyState());
        final restored = await repository.loadMonth(month);

        expect(restored.paymentOverrides['mobit'], 70000);
        expect(remote.calls, isEmpty);
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
        AssetLiabilitySupabaseTablePlan.incomePlansTable,
        'asset_liability_income_plans',
      );
      expect(
        AssetLiabilitySupabaseTablePlan.paymentSourceSettingsTable,
        'asset_liability_payment_source_settings',
      );
      expect(
        AssetLiabilitySupabaseTablePlan.commonPayloadColumns,
        containsAll(<String>['id', 'user_id', 'month_key', 'payload']),
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

class _RecordingAssetLiabilityRemoteStore extends AssetLiabilityRemoteStore {
  final List<String> calls = <String>[];
  final Map<String, AssetLiabilityMonthlyState> _states =
      <String, AssetLiabilityMonthlyState>{};
  final Map<String, String> _defaultPaymentSources = <String, String>{};
  final List<AssetLiabilityRecurringIncomeTemplate> _recurringIncomeTemplates =
      <AssetLiabilityRecurringIncomeTemplate>[];
  final List<AssetLiabilityMonthlySnapshot> _monthlySnapshots =
      <AssetLiabilityMonthlySnapshot>[];

  bool _hasDefaultPaymentSources = false;
  bool _hasRecurringIncomeTemplates = false;
  bool _hasMonthlySnapshots = false;
  bool failSaves = false;

  Map<String, String> get defaultPaymentSources =>
      Map<String, String>.from(_defaultPaymentSources);

  List<AssetLiabilityRecurringIncomeTemplate> get recurringIncomeTemplates =>
      List<AssetLiabilityRecurringIncomeTemplate>.from(
        _recurringIncomeTemplates,
      );

  List<AssetLiabilityMonthlySnapshot> get monthlySnapshots =>
      List<AssetLiabilityMonthlySnapshot>.from(_monthlySnapshots);

  AssetLiabilityMonthlyState? monthState(String monthKey) => _states[monthKey];

  void seedMonth(DateTime month, AssetLiabilityMonthlyState state) {
    _states[AssetLiabilityMonthlyStateStore.formatMonthKey(month)] = state;
  }

  void seedDefaultPaymentSources(Map<String, String> sources) {
    _hasDefaultPaymentSources = true;
    _defaultPaymentSources
      ..clear()
      ..addAll(sources);
  }

  void seedRecurringIncomeTemplates(
    List<AssetLiabilityRecurringIncomeTemplate> templates,
  ) {
    _hasRecurringIncomeTemplates = true;
    _recurringIncomeTemplates
      ..clear()
      ..addAll(templates);
  }

  void seedMonthlySnapshots(List<AssetLiabilityMonthlySnapshot> snapshots) {
    _hasMonthlySnapshots = true;
    _monthlySnapshots
      ..clear()
      ..addAll(snapshots)
      ..sort((a, b) => a.monthKey.compareTo(b.monthKey));
  }

  @override
  Future<AssetLiabilityMonthlyState?> loadMonth({
    required String userId,
    required DateTime month,
  }) async {
    final monthKey = AssetLiabilityMonthlyStateStore.formatMonthKey(month);
    calls.add('loadMonth:$userId:$monthKey');
    return _states[monthKey];
  }

  @override
  Future<void> saveMonth({
    required String userId,
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    final monthKey = AssetLiabilityMonthlyStateStore.formatMonthKey(month);
    calls.add('saveMonth:$userId:$monthKey');
    _throwIfSavingFails();
    _states[monthKey] = state;
  }

  @override
  Future<Map<String, String>?> loadDefaultPaymentSources({
    required String userId,
  }) async {
    calls.add('loadDefaultPaymentSources:$userId');
    if (!_hasDefaultPaymentSources) {
      return null;
    }
    return Map<String, String>.from(_defaultPaymentSources);
  }

  @override
  Future<void> saveDefaultPaymentSources({
    required String userId,
    required Map<String, String> sources,
  }) async {
    calls.add('saveDefaultPaymentSources:$userId');
    _throwIfSavingFails();
    _hasDefaultPaymentSources = true;
    _defaultPaymentSources
      ..clear()
      ..addAll(sources);
  }

  @override
  Future<List<AssetLiabilityRecurringIncomeTemplate>?>
      loadRecurringIncomeTemplates({required String userId}) async {
    calls.add('loadRecurringIncomeTemplates:$userId');
    if (!_hasRecurringIncomeTemplates) {
      return null;
    }
    return List<AssetLiabilityRecurringIncomeTemplate>.from(
      _recurringIncomeTemplates,
    );
  }

  @override
  Future<void> saveRecurringIncomeTemplates({
    required String userId,
    required List<AssetLiabilityRecurringIncomeTemplate> templates,
  }) async {
    calls.add('saveRecurringIncomeTemplates:$userId');
    _throwIfSavingFails();
    _hasRecurringIncomeTemplates = true;
    _recurringIncomeTemplates
      ..clear()
      ..addAll(templates);
  }

  @override
  Future<List<AssetLiabilityMonthlySnapshot>?> loadMonthlySnapshots({
    required String userId,
  }) async {
    calls.add('loadMonthlySnapshots:$userId');
    if (!_hasMonthlySnapshots) {
      return null;
    }
    return List<AssetLiabilityMonthlySnapshot>.from(_monthlySnapshots);
  }

  @override
  Future<void> saveMonthlySnapshot({
    required String userId,
    required AssetLiabilityMonthlySnapshot snapshot,
  }) async {
    calls.add('saveMonthlySnapshot:$userId:${snapshot.monthKey}');
    _throwIfSavingFails();
    _hasMonthlySnapshots = true;
    _monthlySnapshots.removeWhere(
      (current) => current.monthKey == snapshot.monthKey,
    );
    _monthlySnapshots.add(snapshot);
    _monthlySnapshots.sort((a, b) => a.monthKey.compareTo(b.monthKey));
  }

  void _throwIfSavingFails() {
    if (failSaves) {
      throw StateError('remote save failed');
    }
  }
}

AssetLiabilityMonthlyState _sampleMonthlyState() {
  return AssetLiabilityMonthlyState(
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
        received: false,
      ),
    ],
  );
}

AssetLiabilityRecurringIncomeTemplate _sampleRecurringIncomeTemplate() {
  return const AssetLiabilityRecurringIncomeTemplate(
    id: 'salary',
    dayOfMonth: 25,
    name: 'Salary',
    amount: 250000,
    destinationAccountId: 'smbc_otsuka',
    destinationAccountName: 'SMBC Otsuka',
  );
}

AssetLiabilityMonthlySnapshot _sampleSnapshot(String monthKey) {
  return AssetLiabilityMonthlySnapshot(
    monthKey: monthKey,
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
}
