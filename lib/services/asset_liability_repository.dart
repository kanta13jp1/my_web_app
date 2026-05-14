import 'package:flutter/foundation.dart';
import 'package:my_web_app/models/asset_liability_persistence.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AssetLiabilityUserIdProvider = String? Function();
typedef AssetLiabilitySyncErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

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

abstract class AssetLiabilityRemoteStore {
  const AssetLiabilityRemoteStore();

  Future<AssetLiabilityMonthlyState?> loadMonth({
    required String userId,
    required DateTime month,
  });

  Future<void> saveMonth({
    required String userId,
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  });

  Future<Map<String, String>?> loadDefaultPaymentSources({
    required String userId,
  });

  Future<void> saveDefaultPaymentSources({
    required String userId,
    required Map<String, String> sources,
  });

  Future<List<AssetLiabilityRecurringIncomeTemplate>?>
      loadRecurringIncomeTemplates({required String userId});

  Future<void> saveRecurringIncomeTemplates({
    required String userId,
    required List<AssetLiabilityRecurringIncomeTemplate> templates,
  });

  Future<List<AssetLiabilityMonthlySnapshot>?> loadMonthlySnapshots({
    required String userId,
  });

  Future<void> saveMonthlySnapshot({
    required String userId,
    required AssetLiabilityMonthlySnapshot snapshot,
  });
}

class AssetLiabilityRepositoryFactory {
  static const String syncFlagName = 'ASSET_LIABILITY_SUPABASE_SYNC_ENABLED';
  static const bool supabaseSyncEnabled = bool.fromEnvironment(syncFlagName);

  const AssetLiabilityRepositoryFactory._();

  static AssetLiabilityRepository createDefault({
    SupabaseClient? supabaseClient,
    AssetLiabilityRepository localRepository =
        const SharedPreferencesAssetLiabilityRepository(),
    bool syncEnabled = supabaseSyncEnabled,
    AssetLiabilityRemoteStore? remoteStore,
    AssetLiabilityUserIdProvider? userIdProvider,
    AssetLiabilitySyncErrorHandler? onSyncError,
  }) {
    if (!syncEnabled) {
      return localRepository;
    }

    final client = supabaseClient ?? Supabase.instance.client;
    return FeatureFlaggedAssetLiabilityRepository(
      localRepository: localRepository,
      remoteStore: remoteStore ?? AssetLiabilitySupabaseRemoteStore(client),
      syncEnabled: syncEnabled,
      userIdProvider: userIdProvider ?? () => client.auth.currentUser?.id,
      onSyncError: onSyncError,
    );
  }
}

class FeatureFlaggedAssetLiabilityRepository extends AssetLiabilityRepository {
  final AssetLiabilityRepository localRepository;
  final AssetLiabilityRemoteStore? remoteStore;
  final bool syncEnabled;
  final AssetLiabilityUserIdProvider userIdProvider;
  final AssetLiabilitySyncErrorHandler? onSyncError;

  const FeatureFlaggedAssetLiabilityRepository({
    required this.localRepository,
    required this.remoteStore,
    required this.syncEnabled,
    required this.userIdProvider,
    this.onSyncError,
  });

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    final local = await localRepository.loadMonth(month);
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return local;
    }

    final remoteState = await _tryRemote(
      () => remote.loadMonth(userId: userId, month: month),
    );
    if (remoteState == null || remoteState.isEmpty) {
      if (!local.isEmpty) {
        await _tryRemote(
          () => remote.saveMonth(userId: userId, month: month, state: local),
        );
      }
      return local;
    }

    if (local.isEmpty) {
      await localRepository.saveMonth(month: month, state: remoteState);
      return remoteState;
    }

    return local;
  }

  @override
  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    await localRepository.saveMonth(month: month, state: state);
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return;
    }
    await _tryRemote(
      () => remote.saveMonth(userId: userId, month: month, state: state),
    );
  }

  @override
  Future<Map<String, String>> loadDefaultPaymentSources() async {
    final local = await localRepository.loadDefaultPaymentSources();
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return local;
    }

    final remoteSources = await _tryRemote(
      () => remote.loadDefaultPaymentSources(userId: userId),
    );
    if (remoteSources == null || remoteSources.isEmpty) {
      if (local.isNotEmpty) {
        await _tryRemote(
          () =>
              remote.saveDefaultPaymentSources(userId: userId, sources: local),
        );
      }
      return local;
    }

    if (local.isEmpty) {
      await localRepository.saveDefaultPaymentSources(remoteSources);
      return remoteSources;
    }

    return local;
  }

  @override
  Future<void> saveDefaultPaymentSources(Map<String, String> sources) async {
    await localRepository.saveDefaultPaymentSources(sources);
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return;
    }
    await _tryRemote(
      () => remote.saveDefaultPaymentSources(userId: userId, sources: sources),
    );
  }

  @override
  Future<List<AssetLiabilityRecurringIncomeTemplate>>
      loadRecurringIncomeTemplates() async {
    final local = await localRepository.loadRecurringIncomeTemplates();
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return local;
    }

    final remoteTemplates = await _tryRemote(
      () => remote.loadRecurringIncomeTemplates(userId: userId),
    );
    if (remoteTemplates == null || remoteTemplates.isEmpty) {
      if (local.isNotEmpty) {
        await _tryRemote(
          () => remote.saveRecurringIncomeTemplates(
            userId: userId,
            templates: local,
          ),
        );
      }
      return local;
    }

    if (local.isEmpty) {
      await localRepository.saveRecurringIncomeTemplates(remoteTemplates);
      return remoteTemplates;
    }

    return local;
  }

  @override
  Future<void> saveRecurringIncomeTemplates(
    List<AssetLiabilityRecurringIncomeTemplate> templates,
  ) async {
    await localRepository.saveRecurringIncomeTemplates(templates);
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return;
    }
    await _tryRemote(
      () => remote.saveRecurringIncomeTemplates(
        userId: userId,
        templates: templates,
      ),
    );
  }

  @override
  Future<AssetLiabilityMonthlyState> copyPreviousMonthToMonth(
    DateTime targetMonth,
  ) async {
    final previousMonth = DateTime(targetMonth.year, targetMonth.month - 1);
    final previousState = await loadMonth(previousMonth);
    final copied = AssetLiabilityMonthlyStateStore.copyPreviousMonthState(
      previousState: previousState,
      targetMonth: targetMonth,
    );
    await saveMonth(month: targetMonth, state: copied);
    return copied;
  }

  @override
  Future<List<AssetLiabilityMonthlySnapshot>> loadMonthlySnapshots() async {
    final local = await localRepository.loadMonthlySnapshots();
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return local;
    }

    final remoteSnapshots = await _tryRemote(
      () => remote.loadMonthlySnapshots(userId: userId),
    );
    if (remoteSnapshots == null || remoteSnapshots.isEmpty) {
      if (local.isNotEmpty) {
        for (final snapshot in local) {
          await _tryRemote(
            () =>
                remote.saveMonthlySnapshot(userId: userId, snapshot: snapshot),
          );
        }
      }
      return local;
    }

    if (local.isEmpty) {
      for (final snapshot in remoteSnapshots) {
        await localRepository.saveMonthlySnapshot(snapshot);
      }
      return remoteSnapshots;
    }

    return local;
  }

  @override
  Future<void> saveMonthlySnapshot(
    AssetLiabilityMonthlySnapshot snapshot,
  ) async {
    await localRepository.saveMonthlySnapshot(snapshot);
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return;
    }
    await _tryRemote(
      () => remote.saveMonthlySnapshot(userId: userId, snapshot: snapshot),
    );
  }

  AssetLiabilityRemoteStore? _remoteOrNull() {
    return syncEnabled ? remoteStore : null;
  }

  String? _userIdOrNull() {
    final userId = userIdProvider()?.trim();
    return userId == null || userId.isEmpty ? null : userId;
  }

  Future<T?> _tryRemote<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      if (onSyncError != null) {
        onSyncError!(error, stackTrace);
      } else {
        debugPrint('Asset liability Supabase sync skipped: $error');
      }
      return null;
    }
  }
}

class AssetLiabilitySupabaseRemoteStore extends AssetLiabilityRemoteStore {
  final SupabaseClient client;

  const AssetLiabilitySupabaseRemoteStore(this.client);

  @override
  Future<AssetLiabilityMonthlyState?> loadMonth({
    required String userId,
    required DateTime month,
  }) async {
    final monthKey = AssetLiabilityMonthlyStateStore.formatMonthKey(month);
    final monthlyRow = await _loadPayloadRow(
      AssetLiabilitySupabaseTablePlan.monthlyStatesTable,
      userId: userId,
      monthKey: monthKey,
    );
    final incomeRow = await _loadPayloadRow(
      AssetLiabilitySupabaseTablePlan.incomePlansTable,
      userId: userId,
      monthKey: monthKey,
    );
    if (monthlyRow == null && incomeRow == null) {
      return null;
    }

    final payload = <String, Object?>{
      ...?monthlyRow,
      ...?incomeRow,
      'month_key': monthKey,
    };
    return AssetLiabilityMonthlyStatePayload.fromSupabaseJson(
      payload,
    ).toState();
  }

  @override
  Future<void> saveMonth({
    required String userId,
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    final monthKey = AssetLiabilityMonthlyStateStore.formatMonthKey(month);
    final row = AssetLiabilityMonthlyStatePayload.fromState(
      monthKey: monthKey,
      state: state,
    ).toSupabaseJson(userId: userId);

    await _upsertPayloadRow(
      AssetLiabilitySupabaseTablePlan.monthlyStatesTable,
      userId: userId,
      monthKey: monthKey,
      payload: <String, Object?>{
        'payment_overrides': row['payment_overrides'],
        'paid_account_ids': row['paid_account_ids'],
        'payment_source_account_ids': row['payment_source_account_ids'],
      },
    );
    await _upsertPayloadRow(
      AssetLiabilitySupabaseTablePlan.incomePlansTable,
      userId: userId,
      monthKey: monthKey,
      payload: <String, Object?>{'income_plans': row['income_plans']},
    );
  }

  @override
  Future<Map<String, String>?> loadDefaultPaymentSources({
    required String userId,
  }) async {
    final payload = await _loadPayloadRow(
      AssetLiabilitySupabaseTablePlan.paymentSourceSettingsTable,
      userId: userId,
      monthKey: AssetLiabilitySupabaseTablePlan.globalMonthKey,
    );
    if (payload == null) {
      return null;
    }
    return AssetLiabilityUserSettingsPayload.fromSupabaseJson(
      payload,
    ).defaultPaymentSourceAccountIds;
  }

  @override
  Future<void> saveDefaultPaymentSources({
    required String userId,
    required Map<String, String> sources,
  }) async {
    final row = AssetLiabilityUserSettingsPayload(
      defaultPaymentSourceAccountIds: sources,
      recurringIncomeTemplates: const <AssetLiabilityRecurringIncomeTemplate>[],
    ).toSupabaseJson(userId: userId);
    await _upsertPayloadRow(
      AssetLiabilitySupabaseTablePlan.paymentSourceSettingsTable,
      userId: userId,
      monthKey: AssetLiabilitySupabaseTablePlan.globalMonthKey,
      payload: <String, Object?>{
        'default_payment_source_account_ids':
            row['default_payment_source_account_ids'],
      },
    );
  }

  @override
  Future<List<AssetLiabilityRecurringIncomeTemplate>?>
      loadRecurringIncomeTemplates({required String userId}) async {
    final payload = await _loadPayloadRow(
      AssetLiabilitySupabaseTablePlan.recurringIncomeTemplatesTable,
      userId: userId,
      monthKey: AssetLiabilitySupabaseTablePlan.globalMonthKey,
    );
    if (payload == null) {
      return null;
    }
    return AssetLiabilityUserSettingsPayload.fromSupabaseJson(
      payload,
    ).recurringIncomeTemplates;
  }

  @override
  Future<void> saveRecurringIncomeTemplates({
    required String userId,
    required List<AssetLiabilityRecurringIncomeTemplate> templates,
  }) async {
    final row = AssetLiabilityUserSettingsPayload(
      defaultPaymentSourceAccountIds: const <String, String>{},
      recurringIncomeTemplates: templates,
    ).toSupabaseJson(userId: userId);
    await _upsertPayloadRow(
      AssetLiabilitySupabaseTablePlan.recurringIncomeTemplatesTable,
      userId: userId,
      monthKey: AssetLiabilitySupabaseTablePlan.globalMonthKey,
      payload: <String, Object?>{
        'recurring_income_templates': row['recurring_income_templates'],
      },
    );
  }

  @override
  Future<List<AssetLiabilityMonthlySnapshot>?> loadMonthlySnapshots({
    required String userId,
  }) async {
    final response = await client
        .from(AssetLiabilitySupabaseTablePlan.monthlySnapshotsTable)
        .select('month_key,payload')
        .eq('user_id', userId)
        .order('month_key');

    final snapshots = <AssetLiabilityMonthlySnapshot>[];
    for (final item in response) {
      final monthKey = item['month_key']?.toString();
      final payload = _payloadFromRow(item);
      if (monthKey == null || monthKey.isEmpty || payload == null) {
        continue;
      }
      snapshots.add(
        AssetLiabilityMonthlySnapshotPayload.fromSupabaseJson(<String, Object?>{
          ...payload,
          'month_key': monthKey,
        }).snapshot,
      );
    }
    snapshots.sort((a, b) => a.monthKey.compareTo(b.monthKey));
    return snapshots;
  }

  @override
  Future<void> saveMonthlySnapshot({
    required String userId,
    required AssetLiabilityMonthlySnapshot snapshot,
  }) async {
    final row = AssetLiabilityMonthlySnapshotPayload(
      snapshot: snapshot,
    ).toSupabaseJson(userId: userId);
    await _upsertPayloadRow(
      AssetLiabilitySupabaseTablePlan.monthlySnapshotsTable,
      userId: userId,
      monthKey: snapshot.monthKey,
      payload: Map<String, Object?>.from(row)
        ..remove('user_id')
        ..remove('month_key'),
    );
  }

  Future<Map<String, Object?>?> _loadPayloadRow(
    String table, {
    required String userId,
    required String monthKey,
  }) async {
    final response = await client
        .from(table)
        .select('payload')
        .eq('user_id', userId)
        .eq('month_key', monthKey)
        .maybeSingle();
    if (response == null) {
      return null;
    }
    return _payloadFromRow(response);
  }

  Future<void> _upsertPayloadRow(
    String table, {
    required String userId,
    required String monthKey,
    required Map<String, Object?> payload,
  }) async {
    await client.from(table).upsert(
      <String, Object?>{
        'user_id': userId,
        'month_key': monthKey,
        'payload': payload,
      },
      onConflict: 'user_id,month_key',
    );
  }

  Map<String, Object?>? _payloadFromRow(Map<dynamic, dynamic> row) {
    final payload = row['payload'];
    if (payload is Map) {
      return payload.map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return null;
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
