import 'package:flutter/foundation.dart';
import 'package:my_web_app/models/asset_liability_persistence.dart';
import 'package:my_web_app/models/asset_liability_sync_audit_log.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_management_egress_policy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AssetLiabilityUserIdProvider = String? Function();
typedef AssetLiabilitySyncErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

enum AssetLiabilityManualSyncStatus {
  notRun,
  disabled,
  success,
  failure,
  conflict,
}

enum AssetLiabilitySyncTarget {
  monthlyState('monthly_state', '月次状態'),
  paymentSourceSettings('payment_source_settings', '支払原資口座設定'),
  cardBillingDefaults('card_billing_defaults', 'カード請求デフォルト'),
  recurringIncomeTemplates('recurring_income_templates', '定期収入テンプレート'),
  monthlySnapshots('monthly_snapshots', '月次スナップショット');

  final String storageKey;
  final String label;

  const AssetLiabilitySyncTarget(this.storageKey, this.label);

  static AssetLiabilitySyncTarget? fromStorageKey(String value) {
    final normalized = value.trim();
    for (final target in values) {
      if (target.storageKey == normalized) {
        return target;
      }
    }
    return null;
  }
}

enum AssetLiabilityConflictResolutionChoice {
  localWins('local_wins', 'ローカル優先'),
  supabaseWins('supabase_wins', 'Supabase優先'),
  skip('skip', 'スキップ');

  final String storageKey;
  final String label;

  const AssetLiabilityConflictResolutionChoice(this.storageKey, this.label);
}

enum AssetLiabilityConflictResolutionStatus { disabled, success, failure }

class AssetLiabilityConflictResolution {
  final AssetLiabilitySyncTarget target;
  final AssetLiabilityConflictResolutionChoice choice;

  const AssetLiabilityConflictResolution({
    required this.target,
    required this.choice,
  });
}

class AssetLiabilityConflictResolutionResult {
  final AssetLiabilityConflictResolutionStatus status;
  final DateTime completedAt;
  final String message;
  final List<AssetLiabilitySyncTarget> resolvedTargets;
  final List<AssetLiabilitySyncTarget> skippedTargets;

  const AssetLiabilityConflictResolutionResult({
    required this.status,
    required this.completedAt,
    required this.message,
    this.resolvedTargets = const <AssetLiabilitySyncTarget>[],
    this.skippedTargets = const <AssetLiabilitySyncTarget>[],
  });

  factory AssetLiabilityConflictResolutionResult.disabled({
    DateTime? completedAt,
  }) {
    return AssetLiabilityConflictResolutionResult(
      status: AssetLiabilityConflictResolutionStatus.disabled,
      completedAt: completedAt ?? DateTime.now(),
      message: 'Supabase同期は無効です',
    );
  }

  factory AssetLiabilityConflictResolutionResult.success({
    required String message,
    required List<AssetLiabilitySyncTarget> resolvedTargets,
    required List<AssetLiabilitySyncTarget> skippedTargets,
    DateTime? completedAt,
  }) {
    return AssetLiabilityConflictResolutionResult(
      status: AssetLiabilityConflictResolutionStatus.success,
      completedAt: completedAt ?? DateTime.now(),
      message: message,
      resolvedTargets: List<AssetLiabilitySyncTarget>.unmodifiable(
        resolvedTargets,
      ),
      skippedTargets: List<AssetLiabilitySyncTarget>.unmodifiable(
        skippedTargets,
      ),
    );
  }

  factory AssetLiabilityConflictResolutionResult.failure({
    required String message,
    DateTime? completedAt,
  }) {
    return AssetLiabilityConflictResolutionResult(
      status: AssetLiabilityConflictResolutionStatus.failure,
      completedAt: completedAt ?? DateTime.now(),
      message: message,
    );
  }

  bool get isSuccess =>
      status == AssetLiabilityConflictResolutionStatus.success;
}

class AssetLiabilityManualSyncResult {
  final AssetLiabilityManualSyncStatus status;
  final DateTime completedAt;
  final String message;
  final List<String> conflictTargets;

  const AssetLiabilityManualSyncResult({
    required this.status,
    required this.completedAt,
    required this.message,
    this.conflictTargets = const <String>[],
  });

  factory AssetLiabilityManualSyncResult.disabled({DateTime? completedAt}) {
    return AssetLiabilityManualSyncResult(
      status: AssetLiabilityManualSyncStatus.disabled,
      completedAt: completedAt ?? DateTime.now(),
      message: 'Supabase同期は無効です',
    );
  }

  factory AssetLiabilityManualSyncResult.success({
    required String message,
    DateTime? completedAt,
  }) {
    return AssetLiabilityManualSyncResult(
      status: AssetLiabilityManualSyncStatus.success,
      completedAt: completedAt ?? DateTime.now(),
      message: message,
    );
  }

  factory AssetLiabilityManualSyncResult.failure({
    required String message,
    DateTime? completedAt,
  }) {
    return AssetLiabilityManualSyncResult(
      status: AssetLiabilityManualSyncStatus.failure,
      completedAt: completedAt ?? DateTime.now(),
      message: message,
    );
  }

  factory AssetLiabilityManualSyncResult.conflict({
    required List<String> targets,
    DateTime? completedAt,
  }) {
    return AssetLiabilityManualSyncResult(
      status: AssetLiabilityManualSyncStatus.conflict,
      completedAt: completedAt ?? DateTime.now(),
      message: 'ローカルとSupabaseの両方にデータがあります',
      conflictTargets: List<String>.unmodifiable(targets),
    );
  }

  bool get isSuccess => status == AssetLiabilityManualSyncStatus.success;

  bool get hasConflict => status == AssetLiabilityManualSyncStatus.conflict;
}

class AssetLiabilitySyncPreviewItem {
  final AssetLiabilitySyncTarget target;
  final bool localHasData;
  final bool remoteHasData;
  final int localCount;
  final int remoteCount;
  final bool dataMatches;

  const AssetLiabilitySyncPreviewItem({
    required this.target,
    required this.localHasData,
    required this.remoteHasData,
    required this.localCount,
    required this.remoteCount,
    this.dataMatches = false,
  });

  String get targetName => target.label;
  String get targetDataType => target.storageKey;
  bool get uploadCandidate => localHasData && !remoteHasData;
  bool get downloadCandidate => !localHasData && remoteHasData;
  bool get conflict => localHasData && remoteHasData && !dataMatches;
}

class AssetLiabilitySyncPreviewResult {
  final AssetLiabilityManualSyncStatus status;
  final DateTime completedAt;
  final String message;
  final List<AssetLiabilitySyncPreviewItem> items;

  const AssetLiabilitySyncPreviewResult({
    required this.status,
    required this.completedAt,
    required this.message,
    this.items = const <AssetLiabilitySyncPreviewItem>[],
  });

  factory AssetLiabilitySyncPreviewResult.disabled({DateTime? completedAt}) {
    return AssetLiabilitySyncPreviewResult(
      status: AssetLiabilityManualSyncStatus.disabled,
      completedAt: completedAt ?? DateTime.now(),
      message: 'Supabase同期は無効です',
    );
  }

  factory AssetLiabilitySyncPreviewResult.failure({
    required String message,
    DateTime? completedAt,
  }) {
    return AssetLiabilitySyncPreviewResult(
      status: AssetLiabilityManualSyncStatus.failure,
      completedAt: completedAt ?? DateTime.now(),
      message: message,
    );
  }

  factory AssetLiabilitySyncPreviewResult.ready({
    required List<AssetLiabilitySyncPreviewItem> items,
    DateTime? completedAt,
  }) {
    final conflicts =
        items.where((item) => item.conflict).map((item) => item.targetName);
    final hasConflict = conflicts.isNotEmpty;
    return AssetLiabilitySyncPreviewResult(
      status: hasConflict
          ? AssetLiabilityManualSyncStatus.conflict
          : AssetLiabilityManualSyncStatus.success,
      completedAt: completedAt ?? DateTime.now(),
      message: hasConflict ? '競合あり。自動上書きは行いません' : '同期プレビューを更新しました',
      items: List<AssetLiabilitySyncPreviewItem>.unmodifiable(items),
    );
  }

  int get targetCount => items.length;
  int get localDataTargetCount =>
      items.where((item) => item.localHasData).length;
  int get remoteDataTargetCount =>
      items.where((item) => item.remoteHasData).length;
  int get uploadCandidateCount => items
      .where((item) => item.uploadCandidate)
      .fold<int>(0, (total, item) => total + item.localCount);
  int get downloadCandidateCount => items
      .where((item) => item.downloadCandidate)
      .fold<int>(0, (total, item) => total + item.remoteCount);
  int get conflictCount => items.where((item) => item.conflict).length;
  bool get hasConflict => conflictCount > 0;
  List<String> get conflictTargets => <String>[
        for (final item in items)
          if (item.conflict) item.targetName,
      ];
  List<AssetLiabilitySyncTarget> get conflictTargetTypes =>
      <AssetLiabilitySyncTarget>[
        for (final item in items)
          if (item.conflict) item.target,
      ];
}

class AssetLiabilityDefaultPaymentSettings {
  final Map<String, String> paymentSourceAccountIds;
  final Map<String, String> cardBillingAccountIds;

  AssetLiabilityDefaultPaymentSettings({
    required Map<String, String> paymentSourceAccountIds,
    required Map<String, String> cardBillingAccountIds,
  })  : paymentSourceAccountIds = Map<String, String>.unmodifiable(
          paymentSourceAccountIds,
        ),
        cardBillingAccountIds = Map<String, String>.unmodifiable(
          cardBillingAccountIds,
        );
}

abstract class AssetLiabilityRepository {
  const AssetLiabilityRepository();

  bool get supabaseSyncEnabled => false;

  bool get supabaseWritesEnabled => false;

  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month);

  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  });

  Future<Map<String, String>> loadDefaultPaymentSources();

  Future<AssetLiabilityDefaultPaymentSettings>
      loadDefaultPaymentSettings() async {
    final values = await Future.wait<Object>(<Future<Object>>[
      loadDefaultPaymentSources(),
      loadDefaultCardBillingAccounts(),
    ]);
    return AssetLiabilityDefaultPaymentSettings(
      paymentSourceAccountIds:
          Map<String, String>.from(values[0] as Map<String, String>),
      cardBillingAccountIds:
          Map<String, String>.from(values[1] as Map<String, String>),
    );
  }

  Future<void> saveDefaultPaymentSources(Map<String, String> sources);

  Future<Map<String, String>> loadDefaultCardBillingAccounts();

  Future<void> saveDefaultCardBillingAccounts(Map<String, String> accounts);

  /// 負債ごとの支払日 (1-31) 手動設定。契約属性のため月をまたいで共有する。
  Future<Map<String, int>> loadDebtPaymentDayOverrides() async {
    return const <String, int>{};
  }

  Future<void> saveDebtPaymentDayOverrides(Map<String, int> overrides) async {}

  Future<List<AssetLiabilityRecurringIncomeTemplate>>
      loadRecurringIncomeTemplates();

  Future<void> saveRecurringIncomeTemplates(
    List<AssetLiabilityRecurringIncomeTemplate> templates,
  );

  Future<AssetLiabilityMonthlyState> copyPreviousMonthToMonth(
    DateTime targetMonth, {
    bool carryOverIncompleteTransferTasks = false,
  });

  Future<List<AssetLiabilityMonthlySnapshot>> loadMonthlySnapshots();

  Future<void> saveMonthlySnapshot(AssetLiabilityMonthlySnapshot snapshot);

  Future<List<AssetLiabilityMonthlyReport>> loadMonthlyReports({
    int limit = 24,
  }) async {
    return const <AssetLiabilityMonthlyReport>[];
  }

  Future<List<AssetLiabilitySyncAuditLog>> loadSyncAuditLogs({
    int limit = 20,
  }) async {
    return const <AssetLiabilitySyncAuditLog>[];
  }

  Future<void> saveSyncAuditLog(AssetLiabilitySyncAuditLog log) async {}

  Future<AssetLiabilityManualSyncResult> syncMonth(DateTime month) async {
    return AssetLiabilityManualSyncResult.disabled();
  }

  Future<AssetLiabilitySyncPreviewResult> previewSyncMonth(
    DateTime month,
  ) async {
    return AssetLiabilitySyncPreviewResult.disabled();
  }

  Future<AssetLiabilityConflictResolutionResult> resolveSyncConflicts({
    required DateTime month,
    required List<AssetLiabilityConflictResolution> resolutions,
  }) async {
    return AssetLiabilityConflictResolutionResult.disabled();
  }

  Future<AssetLiabilityPersistenceSnapshot> loadPersistenceSnapshot(
    DateTime month,
  ) async {
    return AssetLiabilityPersistenceSnapshot(
      monthKey: AssetLiabilityMonthlyStateStore.formatMonthKey(month),
      monthlyState: await loadMonth(month),
      defaultPaymentSourceAccountIds: await loadDefaultPaymentSources(),
      defaultCardBillingAccountIds: await loadDefaultCardBillingAccounts(),
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

  Future<AssetLiabilityDefaultPaymentSettings?> loadDefaultPaymentSettings({
    required String userId,
  }) async {
    final values = await Future.wait<Object?>(<Future<Object?>>[
      loadDefaultPaymentSources(userId: userId),
      loadDefaultCardBillingAccounts(userId: userId),
    ]);
    final sources = values[0] as Map<String, String>?;
    final accounts = values[1] as Map<String, String>?;
    if (sources == null && accounts == null) {
      return null;
    }
    return AssetLiabilityDefaultPaymentSettings(
      paymentSourceAccountIds: sources ?? const <String, String>{},
      cardBillingAccountIds: accounts ?? const <String, String>{},
    );
  }

  Future<void> saveDefaultPaymentSources({
    required String userId,
    required Map<String, String> sources,
  });

  Future<Map<String, String>?> loadDefaultCardBillingAccounts({
    required String userId,
  });

  Future<void> saveDefaultCardBillingAccounts({
    required String userId,
    required Map<String, String> accounts,
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

  Future<List<AssetLiabilityMonthlyReport>?> loadMonthlyReports({
    required String userId,
    int limit = 24,
  });
}

class AssetLiabilityRepositoryFactory {
  static const String syncFlagName = 'ASSET_LIABILITY_SUPABASE_SYNC_ENABLED';
  static const String writeFlagName =
      'ASSET_LIABILITY_SUPABASE_PRODUCTION_WRITES_ENABLED';
  static const bool supabaseSyncEnabled = bool.fromEnvironment(syncFlagName);
  static const bool supabaseWritesEnabled = bool.fromEnvironment(writeFlagName);

  const AssetLiabilityRepositoryFactory._();

  static AssetLiabilityRepository createDefault({
    SupabaseClient? supabaseClient,
    AssetLiabilityRepository localRepository =
        const SharedPreferencesAssetLiabilityRepository(),
    bool syncEnabled = supabaseSyncEnabled,
    bool remoteWritesEnabled = supabaseWritesEnabled,
    AssetLiabilityRemoteStore? remoteStore,
    AssetLiabilityUserIdProvider? userIdProvider,
    AssetLiabilitySyncErrorHandler? onSyncError,
  }) {
    if (!syncEnabled) {
      return localRepository;
    }

    final client = supabaseClient ??
        (remoteStore == null || userIdProvider == null
            ? Supabase.instance.client
            : null);
    return FeatureFlaggedAssetLiabilityRepository(
      localRepository: localRepository,
      remoteStore: remoteStore ?? AssetLiabilitySupabaseRemoteStore(client!),
      syncEnabled: syncEnabled,
      remoteWritesEnabled: remoteWritesEnabled,
      userIdProvider: userIdProvider ?? () => client!.auth.currentUser?.id,
      onSyncError: onSyncError,
    );
  }
}

class FeatureFlaggedAssetLiabilityRepository extends AssetLiabilityRepository {
  final AssetLiabilityRepository localRepository;
  final AssetLiabilityRemoteStore? remoteStore;
  final bool syncEnabled;
  final bool remoteWritesEnabled;
  final AssetLiabilityUserIdProvider userIdProvider;
  final AssetLiabilitySyncErrorHandler? onSyncError;
  final Map<String, Future<AssetLiabilityMonthlyState>> _inFlightMonthLoads =
      <String, Future<AssetLiabilityMonthlyState>>{};

  FeatureFlaggedAssetLiabilityRepository({
    required this.localRepository,
    required this.remoteStore,
    required this.syncEnabled,
    this.remoteWritesEnabled = false,
    required this.userIdProvider,
    this.onSyncError,
  });

  @override
  bool get supabaseSyncEnabled => syncEnabled;

  @override
  bool get supabaseWritesEnabled => syncEnabled && remoteWritesEnabled;

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) {
    final monthKey = AssetLiabilityMonthlyStateStore.formatMonthKey(month);
    final existing = _inFlightMonthLoads[monthKey];
    if (existing != null) {
      return existing;
    }

    late final Future<AssetLiabilityMonthlyState> load;
    load = _loadMonthOnce(month).whenComplete(() {
      if (identical(_inFlightMonthLoads[monthKey], load)) {
        _inFlightMonthLoads.remove(monthKey);
      }
    });
    _inFlightMonthLoads[monthKey] = load;
    return load;
  }

  Future<AssetLiabilityMonthlyState> _loadMonthOnce(DateTime month) async {
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
      if (!local.isEmpty && supabaseWritesEnabled) {
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

    // 双方に編集時刻 (updatedAt) があり差があるなら last-write-wins =
    // 新しい方の状態全体を採用する。union と違い「支払済みのチェック解除 (削除)」も
    // 新しい端末の状態として伝播する。
    final localUpdatedAt = local.updatedAt;
    final remoteUpdatedAt = remoteState.updatedAt;
    if (localUpdatedAt != null &&
        remoteUpdatedAt != null &&
        !localUpdatedAt.isAtSameMomentAs(remoteUpdatedAt)) {
      if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
        await localRepository.saveMonth(month: month, state: remoteState);
        return remoteState;
      }
      if (supabaseWritesEnabled) {
        await _tryRemote(
          () => remote.saveMonth(userId: userId, month: month, state: local),
        );
      }
      return local;
    }

    // timestamp が無い/同時刻 (旧データを含む) ときは union マージへ退避する。
    // 旧実装は無条件に local を返し、別端末で付けた「支払済み」等を無視した上に、
    // その local をサーバへ保存し直してリモートの入力を上書き消去していた。
    // union は monotonic なので、両端末の入力を取りこぼさず収束する。
    final merged = local.mergeWith(remoteState);
    if (merged.totalEntryCount > local.totalEntryCount) {
      await localRepository.saveMonth(month: month, state: merged);
    }
    if (supabaseWritesEnabled &&
        merged.totalEntryCount > remoteState.totalEntryCount) {
      await _tryRemote(
        () => remote.saveMonth(userId: userId, month: month, state: merged),
      );
    }
    return merged;
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
    if (supabaseWritesEnabled) {
      await _tryRemote(
        () => remote.saveMonth(userId: userId, month: month, state: state),
      );
    }
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
      if (local.isNotEmpty && supabaseWritesEnabled) {
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
  Future<AssetLiabilityDefaultPaymentSettings>
      loadDefaultPaymentSettings() async {
    final local = await localRepository.loadDefaultPaymentSettings();
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return local;
    }

    final remoteSettings = await _tryRemote(
      () => remote.loadDefaultPaymentSettings(userId: userId),
    );
    if (remoteSettings == null) {
      return local;
    }

    var paymentSources = local.paymentSourceAccountIds;
    final remotePaymentSources = remoteSettings.paymentSourceAccountIds;
    if (remotePaymentSources.isEmpty) {
      if (paymentSources.isNotEmpty && supabaseWritesEnabled) {
        await _tryRemote(
          () => remote.saveDefaultPaymentSources(
            userId: userId,
            sources: paymentSources,
          ),
        );
      }
    } else if (paymentSources.isEmpty) {
      await localRepository.saveDefaultPaymentSources(remotePaymentSources);
      paymentSources = remotePaymentSources;
    }

    var cardBillingAccounts = local.cardBillingAccountIds;
    final remoteCardBillingAccounts = remoteSettings.cardBillingAccountIds;
    if (remoteCardBillingAccounts.isEmpty) {
      if (cardBillingAccounts.isNotEmpty && supabaseWritesEnabled) {
        await _tryRemote(
          () => remote.saveDefaultCardBillingAccounts(
            userId: userId,
            accounts: cardBillingAccounts,
          ),
        );
      }
    } else if (cardBillingAccounts.isEmpty) {
      await localRepository.saveDefaultCardBillingAccounts(
        remoteCardBillingAccounts,
      );
      cardBillingAccounts = remoteCardBillingAccounts;
    }

    return AssetLiabilityDefaultPaymentSettings(
      paymentSourceAccountIds: paymentSources,
      cardBillingAccountIds: cardBillingAccounts,
    );
  }

  @override
  Future<void> saveDefaultPaymentSources(Map<String, String> sources) async {
    await localRepository.saveDefaultPaymentSources(sources);
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return;
    }
    if (supabaseWritesEnabled) {
      await _tryRemote(
        () =>
            remote.saveDefaultPaymentSources(userId: userId, sources: sources),
      );
    }
  }

  @override
  Future<Map<String, String>> loadDefaultCardBillingAccounts() async {
    final local = await localRepository.loadDefaultCardBillingAccounts();
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return local;
    }

    final remoteAccounts = await _tryRemote(
      () => remote.loadDefaultCardBillingAccounts(userId: userId),
    );
    if (remoteAccounts == null || remoteAccounts.isEmpty) {
      if (local.isNotEmpty && supabaseWritesEnabled) {
        await _tryRemote(
          () => remote.saveDefaultCardBillingAccounts(
            userId: userId,
            accounts: local,
          ),
        );
      }
      return local;
    }

    if (local.isEmpty) {
      await localRepository.saveDefaultCardBillingAccounts(remoteAccounts);
      return remoteAccounts;
    }

    return local;
  }

  @override
  Future<void> saveDefaultCardBillingAccounts(
    Map<String, String> accounts,
  ) async {
    await localRepository.saveDefaultCardBillingAccounts(accounts);
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return;
    }
    if (supabaseWritesEnabled) {
      await _tryRemote(
        () => remote.saveDefaultCardBillingAccounts(
          userId: userId,
          accounts: accounts,
        ),
      );
    }
  }

  // 支払日手動設定はローカル保存のみ (リモート同期は将来対応)。
  @override
  Future<Map<String, int>> loadDebtPaymentDayOverrides() {
    return localRepository.loadDebtPaymentDayOverrides();
  }

  @override
  Future<void> saveDebtPaymentDayOverrides(Map<String, int> overrides) {
    return localRepository.saveDebtPaymentDayOverrides(overrides);
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
      if (local.isNotEmpty && supabaseWritesEnabled) {
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
    if (supabaseWritesEnabled) {
      await _tryRemote(
        () => remote.saveRecurringIncomeTemplates(
          userId: userId,
          templates: templates,
        ),
      );
    }
  }

  @override
  Future<AssetLiabilityMonthlyState> copyPreviousMonthToMonth(
    DateTime targetMonth, {
    bool carryOverIncompleteTransferTasks = false,
  }) async {
    final previousMonth = DateTime(targetMonth.year, targetMonth.month - 1);
    final previousState = await loadMonth(previousMonth);
    final copied = AssetLiabilityMonthlyStateStore.copyPreviousMonthState(
      previousState: previousState,
      targetMonth: targetMonth,
      carryOverIncompleteTransferTasks: carryOverIncompleteTransferTasks,
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
      if (local.isNotEmpty && supabaseWritesEnabled) {
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
  Future<List<AssetLiabilityMonthlyReport>> loadMonthlyReports({
    int limit = 24,
  }) async {
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null || userId == null) {
      return const <AssetLiabilityMonthlyReport>[];
    }
    final remoteReports = await _tryRemote(
      () => remote.loadMonthlyReports(userId: userId, limit: limit),
    );
    if (remoteReports == null || remoteReports.isEmpty) {
      return const <AssetLiabilityMonthlyReport>[];
    }
    final sorted = List<AssetLiabilityMonthlyReport>.from(remoteReports)
      ..sort((a, b) => b.monthKey.compareTo(a.monthKey));
    return sorted.take(limit < 0 ? 0 : limit).toList(growable: false);
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
    if (supabaseWritesEnabled) {
      await _tryRemote(
        () => remote.saveMonthlySnapshot(userId: userId, snapshot: snapshot),
      );
    }
  }

  @override
  Future<List<AssetLiabilitySyncAuditLog>> loadSyncAuditLogs({int limit = 20}) {
    return localRepository.loadSyncAuditLogs(limit: limit);
  }

  @override
  Future<void> saveSyncAuditLog(AssetLiabilitySyncAuditLog log) {
    return localRepository.saveSyncAuditLog(log);
  }

  @override
  Future<AssetLiabilityManualSyncResult> syncMonth(DateTime month) async {
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null) {
      return AssetLiabilityManualSyncResult.disabled();
    }
    if (userId == null) {
      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.failed,
        targetDataType: 'all_targets',
        count: 0,
        result: 'missing_supabase_user',
        errorMessage: 'Supabase user is not available.',
      );
      return AssetLiabilityManualSyncResult.failure(
        message: 'Supabaseユーザーが確認できません',
      );
    }

    try {
      final syncData = await _loadSyncData(
        month: month,
        remote: remote,
        userId: userId,
      );
      final preview = _buildSyncPreview(syncData);
      if (preview.hasConflict) {
        await _recordAuditLog(
          month: month,
          type: AssetLiabilitySyncAuditType.manualSync,
          targetDataType: 'all_targets',
          count: preview.targetCount,
          result: 'conflict',
        );
        await _recordAuditLog(
          month: month,
          type: AssetLiabilitySyncAuditType.conflictDetected,
          targetDataType: preview.conflictTargetTypes
              .map((target) => target.storageKey)
              .join(','),
          count: preview.conflictCount,
          result: 'conflict_non_destructive_stop',
          errorMessage: 'Both local and Supabase data exist; no overwrite.',
        );
        return AssetLiabilityManualSyncResult.conflict(
          targets: preview.conflictTargets,
        );
      }

      final writesEnabled = supabaseWritesEnabled;
      var uploaded = 0;
      var restored = 0;
      var skippedRemoteWrites = 0;

      if (!syncData.localMonth.isEmpty) {
        if (writesEnabled) {
          await remote.saveMonth(
            userId: userId,
            month: month,
            state: syncData.localMonth,
          );
          uploaded++;
        } else {
          skippedRemoteWrites++;
        }
      } else if (!_remoteMonthIsEmpty(syncData.remoteMonth)) {
        await localRepository.saveMonth(
          month: month,
          state: syncData.remoteMonth!,
        );
        restored++;
      }

      if (syncData.localSources.isNotEmpty) {
        if (writesEnabled) {
          await remote.saveDefaultPaymentSources(
            userId: userId,
            sources: syncData.localSources,
          );
          uploaded++;
        } else {
          skippedRemoteWrites += syncData.localSources.length;
        }
      } else if (syncData.remoteSources?.isNotEmpty ?? false) {
        await localRepository.saveDefaultPaymentSources(
          syncData.remoteSources!,
        );
        restored++;
      }

      if (syncData.localDefaultCardBillingAccounts.isNotEmpty) {
        if (writesEnabled) {
          await remote.saveDefaultCardBillingAccounts(
            userId: userId,
            accounts: syncData.localDefaultCardBillingAccounts,
          );
          uploaded++;
        } else {
          skippedRemoteWrites +=
              syncData.localDefaultCardBillingAccounts.length;
        }
      } else if (syncData.remoteDefaultCardBillingAccounts?.isNotEmpty ??
          false) {
        await localRepository.saveDefaultCardBillingAccounts(
          syncData.remoteDefaultCardBillingAccounts!,
        );
        restored++;
      }

      if (syncData.localTemplates.isNotEmpty) {
        if (writesEnabled) {
          await remote.saveRecurringIncomeTemplates(
            userId: userId,
            templates: syncData.localTemplates,
          );
          uploaded++;
        } else {
          skippedRemoteWrites += syncData.localTemplates.length;
        }
      } else if (syncData.remoteTemplates?.isNotEmpty ?? false) {
        await localRepository.saveRecurringIncomeTemplates(
          syncData.remoteTemplates!,
        );
        restored++;
      }

      if (syncData.localSnapshots.isNotEmpty) {
        if (writesEnabled) {
          for (final snapshot in syncData.localSnapshots) {
            await remote.saveMonthlySnapshot(
              userId: userId,
              snapshot: snapshot,
            );
          }
          uploaded += syncData.localSnapshots.length;
        } else {
          skippedRemoteWrites += syncData.localSnapshots.length;
        }
      } else if (syncData.remoteSnapshots?.isNotEmpty ?? false) {
        for (final snapshot in syncData.remoteSnapshots!) {
          await localRepository.saveMonthlySnapshot(snapshot);
        }
        restored += syncData.remoteSnapshots!.length;
      }

      final syncedCount = uploaded + restored;
      final auditCount = syncedCount + skippedRemoteWrites;
      final syncResult =
          skippedRemoteWrites > 0 ? 'success_remote_write_disabled' : 'success';
      final syncMessage = skippedRemoteWrites > 0
          ? 'Remote writes are disabled; upload candidates were skipped.'
          : null;
      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.manualSync,
        targetDataType: 'all_targets',
        count: auditCount,
        result: syncResult,
        errorMessage: syncMessage,
      );
      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.success,
        targetDataType: 'all_targets',
        count: auditCount,
        result: syncResult,
        errorMessage: syncMessage,
      );

      if (skippedRemoteWrites > 0) {
        return AssetLiabilityManualSyncResult.success(
          message:
              'Supabase remote writes are disabled. Uploaded $uploaded item(s), restored $restored item(s), skipped $skippedRemoteWrites upload candidate(s).',
        );
      }

      return AssetLiabilityManualSyncResult.success(
        message: '同期完了（アップロード $uploaded 件 / 復元 $restored 件）',
      );
    } catch (error, stackTrace) {
      if (onSyncError != null) {
        onSyncError!(error, stackTrace);
      } else {
        debugPrint('Asset liability manual Supabase sync failed: $error');
      }
      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.failed,
        targetDataType: 'all_targets',
        count: 0,
        result: 'failed',
        errorMessage: error.toString(),
      );
      return AssetLiabilityManualSyncResult.failure(
        message: 'Supabase同期に失敗しました: $error',
      );
    }
  }

  @override
  Future<AssetLiabilitySyncPreviewResult> previewSyncMonth(
    DateTime month,
  ) async {
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null) {
      return AssetLiabilitySyncPreviewResult.disabled();
    }
    if (userId == null) {
      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.failed,
        targetDataType: 'preview',
        count: 0,
        result: 'missing_supabase_user',
        errorMessage: 'Supabase user is not available.',
      );
      return AssetLiabilitySyncPreviewResult.failure(
        message: 'Supabaseユーザーが確認できません',
      );
    }

    try {
      final syncData = await _loadSyncData(
        month: month,
        remote: remote,
        userId: userId,
      );
      final preview = _buildSyncPreview(syncData);
      await _recordPreviewAuditLogs(month: month, preview: preview);
      return preview;
    } catch (error, stackTrace) {
      if (onSyncError != null) {
        onSyncError!(error, stackTrace);
      } else {
        debugPrint('Asset liability Supabase sync preview failed: $error');
      }
      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.failed,
        targetDataType: 'preview',
        count: 0,
        result: 'failed',
        errorMessage: error.toString(),
      );
      return AssetLiabilitySyncPreviewResult.failure(
        message: 'Supabase同期プレビューに失敗しました: $error',
      );
    }
  }

  @override
  Future<AssetLiabilityConflictResolutionResult> resolveSyncConflicts({
    required DateTime month,
    required List<AssetLiabilityConflictResolution> resolutions,
  }) async {
    final remote = _remoteOrNull();
    final userId = _userIdOrNull();
    if (remote == null) {
      return AssetLiabilityConflictResolutionResult.disabled();
    }
    if (userId == null) {
      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.failed,
        targetDataType: 'conflict_resolution',
        count: 0,
        result: 'missing_supabase_user',
        errorMessage: 'Supabase user is not available.',
      );
      return AssetLiabilityConflictResolutionResult.failure(
        message: 'Supabaseユーザーが確認できません',
      );
    }
    if (resolutions.isEmpty) {
      return AssetLiabilityConflictResolutionResult.success(
        message: '競合解決の対象がありません',
        resolvedTargets: const <AssetLiabilitySyncTarget>[],
        skippedTargets: const <AssetLiabilitySyncTarget>[],
      );
    }
    if (!supabaseWritesEnabled &&
        resolutions.any(
          (resolution) =>
              resolution.choice ==
              AssetLiabilityConflictResolutionChoice.localWins,
        )) {
      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.failed,
        targetDataType: 'conflict_resolution',
        count: 0,
        result: 'production_writes_disabled',
        errorMessage: 'Supabase production writes are disabled.',
      );
      return AssetLiabilityConflictResolutionResult.failure(
        message: 'Supabase production writes are disabled.',
      );
    }

    try {
      final syncData = await _loadSyncData(
        month: month,
        remote: remote,
        userId: userId,
      );
      final preview = _buildSyncPreview(syncData);
      final conflictTargets = preview.conflictTargetTypes.toSet();
      final resolved = <AssetLiabilitySyncTarget>[];
      final skipped = <AssetLiabilitySyncTarget>[];
      var affectedCount = 0;

      for (final resolution in resolutions) {
        if (!conflictTargets.contains(resolution.target)) {
          skipped.add(resolution.target);
          continue;
        }
        switch (resolution.choice) {
          case AssetLiabilityConflictResolutionChoice.localWins:
            final count = await _uploadLocalTarget(
              target: resolution.target,
              data: syncData,
              remote: remote,
              userId: userId,
              month: month,
            );
            affectedCount += count;
            if (count > 0) {
              resolved.add(resolution.target);
            } else {
              skipped.add(resolution.target);
            }
          case AssetLiabilityConflictResolutionChoice.supabaseWins:
            final count = await _restoreRemoteTarget(
              target: resolution.target,
              data: syncData,
              month: month,
            );
            affectedCount += count;
            if (count > 0) {
              resolved.add(resolution.target);
            } else {
              skipped.add(resolution.target);
            }
          case AssetLiabilityConflictResolutionChoice.skip:
            skipped.add(resolution.target);
        }
      }

      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.conflictResolved,
        targetDataType: resolutions
            .map(
              (resolution) =>
                  '${resolution.target.storageKey}:${resolution.choice.storageKey}',
            )
            .join(','),
        count: affectedCount,
        result: resolved.isEmpty ? 'skipped' : 'resolved_explicitly',
      );

      final resolvedLabel = resolved.map((target) => target.label).join('、');
      final skippedLabel = skipped.map((target) => target.label).join('、');
      final message = resolved.isNotEmpty
          ? '競合を解決しました: $resolvedLabel'
          : skipped.isNotEmpty
              ? '競合解決をスキップしました: $skippedLabel'
              : '競合解決の対象がありません';

      return AssetLiabilityConflictResolutionResult.success(
        message: message,
        resolvedTargets: resolved,
        skippedTargets: skipped,
      );
    } catch (error, stackTrace) {
      if (onSyncError != null) {
        onSyncError!(error, stackTrace);
      } else {
        debugPrint('Asset liability conflict resolution failed: $error');
      }
      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.failed,
        targetDataType: 'conflict_resolution',
        count: 0,
        result: 'failed',
        errorMessage: error.toString(),
      );
      return AssetLiabilityConflictResolutionResult.failure(
        message: '競合解決に失敗しました: $error',
      );
    }
  }

  Future<int> _uploadLocalTarget({
    required AssetLiabilitySyncTarget target,
    required _AssetLiabilitySyncData data,
    required AssetLiabilityRemoteStore remote,
    required String userId,
    required DateTime month,
  }) async {
    switch (target) {
      case AssetLiabilitySyncTarget.monthlyState:
        if (data.localMonth.isEmpty) {
          return 0;
        }
        await remote.saveMonth(
          userId: userId,
          month: month,
          state: data.localMonth,
        );
        return 1;
      case AssetLiabilitySyncTarget.paymentSourceSettings:
        if (data.localSources.isEmpty) {
          return 0;
        }
        await remote.saveDefaultPaymentSources(
          userId: userId,
          sources: data.localSources,
        );
        return data.localSources.length;
      case AssetLiabilitySyncTarget.cardBillingDefaults:
        if (data.localDefaultCardBillingAccounts.isEmpty) {
          return 0;
        }
        await remote.saveDefaultCardBillingAccounts(
          userId: userId,
          accounts: data.localDefaultCardBillingAccounts,
        );
        return data.localDefaultCardBillingAccounts.length;
      case AssetLiabilitySyncTarget.recurringIncomeTemplates:
        if (data.localTemplates.isEmpty) {
          return 0;
        }
        await remote.saveRecurringIncomeTemplates(
          userId: userId,
          templates: data.localTemplates,
        );
        return data.localTemplates.length;
      case AssetLiabilitySyncTarget.monthlySnapshots:
        if (data.localSnapshots.isEmpty) {
          return 0;
        }
        for (final snapshot in data.localSnapshots) {
          await remote.saveMonthlySnapshot(userId: userId, snapshot: snapshot);
        }
        return data.localSnapshots.length;
    }
  }

  Future<int> _restoreRemoteTarget({
    required AssetLiabilitySyncTarget target,
    required _AssetLiabilitySyncData data,
    required DateTime month,
  }) async {
    switch (target) {
      case AssetLiabilitySyncTarget.monthlyState:
        if (_remoteMonthIsEmpty(data.remoteMonth)) {
          return 0;
        }
        await localRepository.saveMonth(month: month, state: data.remoteMonth!);
        return 1;
      case AssetLiabilitySyncTarget.paymentSourceSettings:
        if (data.remoteSources?.isNotEmpty != true) {
          return 0;
        }
        await localRepository.saveDefaultPaymentSources(data.remoteSources!);
        return data.remoteSources!.length;
      case AssetLiabilitySyncTarget.cardBillingDefaults:
        if (data.remoteDefaultCardBillingAccounts?.isNotEmpty != true) {
          return 0;
        }
        await localRepository.saveDefaultCardBillingAccounts(
          data.remoteDefaultCardBillingAccounts!,
        );
        return data.remoteDefaultCardBillingAccounts!.length;
      case AssetLiabilitySyncTarget.recurringIncomeTemplates:
        if (data.remoteTemplates?.isNotEmpty != true) {
          return 0;
        }
        await localRepository.saveRecurringIncomeTemplates(
          data.remoteTemplates!,
        );
        return data.remoteTemplates!.length;
      case AssetLiabilitySyncTarget.monthlySnapshots:
        if (data.remoteSnapshots?.isNotEmpty != true) {
          return 0;
        }
        for (final snapshot in data.remoteSnapshots!) {
          await localRepository.saveMonthlySnapshot(snapshot);
        }
        return data.remoteSnapshots!.length;
    }
  }

  Future<void> _recordPreviewAuditLogs({
    required DateTime month,
    required AssetLiabilitySyncPreviewResult preview,
  }) async {
    await _recordAuditLog(
      month: month,
      type: AssetLiabilitySyncAuditType.preview,
      targetDataType: 'all_targets',
      count: preview.targetCount,
      result: preview.hasConflict ? 'conflict' : 'success',
    );
    if (preview.uploadCandidateCount > 0) {
      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.uploadCandidate,
        targetDataType: 'upload_candidates',
        count: preview.uploadCandidateCount,
        result: 'detected',
      );
    }
    if (preview.downloadCandidateCount > 0) {
      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.downloadCandidate,
        targetDataType: 'download_candidates',
        count: preview.downloadCandidateCount,
        result: 'detected',
      );
    }
    if (preview.conflictCount > 0) {
      await _recordAuditLog(
        month: month,
        type: AssetLiabilitySyncAuditType.conflictDetected,
        targetDataType: preview.conflictTargetTypes
            .map((target) => target.storageKey)
            .join(','),
        count: preview.conflictCount,
        result: 'conflict_non_destructive_stop',
        errorMessage: 'Both local and Supabase data exist; no overwrite.',
      );
    }
  }

  Future<void> _recordAuditLog({
    required DateTime month,
    required AssetLiabilitySyncAuditType type,
    required String targetDataType,
    required int count,
    required String result,
    String? errorMessage,
  }) async {
    try {
      await localRepository.saveSyncAuditLog(
        AssetLiabilitySyncAuditLog.create(
          type: type,
          monthKey: AssetLiabilityMonthlyStateStore.formatMonthKey(month),
          targetDataType: targetDataType,
          count: count,
          result: result,
          errorMessage: errorMessage,
        ),
      );
    } catch (error) {
      debugPrint('Asset liability sync audit log skipped: $error');
    }
  }

  AssetLiabilityRemoteStore? _remoteOrNull() {
    return syncEnabled ? remoteStore : null;
  }

  bool _remoteMonthIsEmpty(AssetLiabilityMonthlyState? state) {
    return state == null || state.isEmpty;
  }

  Future<_AssetLiabilitySyncData> _loadSyncData({
    required DateTime month,
    required AssetLiabilityRemoteStore remote,
    required String userId,
  }) async {
    return _AssetLiabilitySyncData(
      localMonth: await localRepository.loadMonth(month),
      localSources: await localRepository.loadDefaultPaymentSources(),
      localDefaultCardBillingAccounts:
          await localRepository.loadDefaultCardBillingAccounts(),
      localTemplates: await localRepository.loadRecurringIncomeTemplates(),
      localSnapshots: await localRepository.loadMonthlySnapshots(),
      remoteMonth: await remote.loadMonth(userId: userId, month: month),
      remoteSources: await remote.loadDefaultPaymentSources(userId: userId),
      remoteDefaultCardBillingAccounts:
          await remote.loadDefaultCardBillingAccounts(userId: userId),
      remoteTemplates: await remote.loadRecurringIncomeTemplates(
        userId: userId,
      ),
      remoteSnapshots: await remote.loadMonthlySnapshots(userId: userId),
    );
  }

  AssetLiabilitySyncPreviewResult _buildSyncPreview(
    _AssetLiabilitySyncData data,
  ) {
    final comparableLocalSnapshots = _latestMonthlySnapshots(
      data.localSnapshots,
    );
    final items = <AssetLiabilitySyncPreviewItem>[
      AssetLiabilitySyncPreviewItem(
        target: AssetLiabilitySyncTarget.monthlyState,
        localHasData: !data.localMonth.isEmpty,
        remoteHasData: !_remoteMonthIsEmpty(data.remoteMonth),
        localCount: data.localMonth.isEmpty ? 0 : 1,
        remoteCount: _remoteMonthIsEmpty(data.remoteMonth) ? 0 : 1,
        dataMatches: !data.localMonth.isEmpty &&
            !_remoteMonthIsEmpty(data.remoteMonth) &&
            _monthlyStatesEqual(data.localMonth, data.remoteMonth!),
      ),
      AssetLiabilitySyncPreviewItem(
        target: AssetLiabilitySyncTarget.paymentSourceSettings,
        localHasData: data.localSources.isNotEmpty,
        remoteHasData: data.remoteSources?.isNotEmpty ?? false,
        localCount: data.localSources.length,
        remoteCount: data.remoteSources?.length ?? 0,
        dataMatches: data.localSources.isNotEmpty &&
            (data.remoteSources?.isNotEmpty ?? false) &&
            _stringMapEquals(data.localSources, data.remoteSources!),
      ),
      AssetLiabilitySyncPreviewItem(
        target: AssetLiabilitySyncTarget.cardBillingDefaults,
        localHasData: data.localDefaultCardBillingAccounts.isNotEmpty,
        remoteHasData:
            data.remoteDefaultCardBillingAccounts?.isNotEmpty ?? false,
        localCount: data.localDefaultCardBillingAccounts.length,
        remoteCount: data.remoteDefaultCardBillingAccounts?.length ?? 0,
        dataMatches: data.localDefaultCardBillingAccounts.isNotEmpty &&
            (data.remoteDefaultCardBillingAccounts?.isNotEmpty ?? false) &&
            _stringMapEquals(
              data.localDefaultCardBillingAccounts,
              data.remoteDefaultCardBillingAccounts!,
            ),
      ),
      AssetLiabilitySyncPreviewItem(
        target: AssetLiabilitySyncTarget.recurringIncomeTemplates,
        localHasData: data.localTemplates.isNotEmpty,
        remoteHasData: data.remoteTemplates?.isNotEmpty ?? false,
        localCount: data.localTemplates.length,
        remoteCount: data.remoteTemplates?.length ?? 0,
        dataMatches: data.localTemplates.isNotEmpty &&
            (data.remoteTemplates?.isNotEmpty ?? false) &&
            _recurringTemplatesEqual(
              data.localTemplates,
              data.remoteTemplates!,
            ),
      ),
      AssetLiabilitySyncPreviewItem(
        target: AssetLiabilitySyncTarget.monthlySnapshots,
        localHasData: comparableLocalSnapshots.isNotEmpty,
        remoteHasData: data.remoteSnapshots?.isNotEmpty ?? false,
        localCount: comparableLocalSnapshots.length,
        remoteCount: data.remoteSnapshots?.length ?? 0,
        dataMatches: comparableLocalSnapshots.isNotEmpty &&
            (data.remoteSnapshots?.isNotEmpty ?? false) &&
            _monthlySnapshotsEqual(
              comparableLocalSnapshots,
              data.remoteSnapshots!,
            ),
      ),
    ];
    return AssetLiabilitySyncPreviewResult.ready(items: items);
  }

  bool _monthlyStatesEqual(
    AssetLiabilityMonthlyState local,
    AssetLiabilityMonthlyState remote,
  ) {
    return _doubleMapEquals(local.paymentOverrides, remote.paymentOverrides) &&
        _doubleMapEquals(
          local.actualPaymentAmounts,
          remote.actualPaymentAmounts,
        ) &&
        _stringMapEquals(
          local.paymentDifferenceReasons,
          remote.paymentDifferenceReasons,
        ) &&
        _doubleMapEquals(
          local.annualRateOverrides,
          remote.annualRateOverrides,
        ) &&
        _annualRateEvidencesEqual(
          local.annualRateEvidences,
          remote.annualRateEvidences,
        ) &&
        _stringSetEquals(local.paidAccountNames, remote.paidAccountNames) &&
        _stringSetEquals(
          local.billingConfirmedAccountIds,
          remote.billingConfirmedAccountIds,
        ) &&
        _stringMapEquals(
          local.paymentSourceAccountIds,
          remote.paymentSourceAccountIds,
        ) &&
        _stringMapEquals(
          local.cardBillingAccountIds,
          remote.cardBillingAccountIds,
        ) &&
        _cardStatementLinesEqual(
          local.cardStatementLines,
          remote.cardStatementLines,
        ) &&
        _incomePlansEqual(local.incomePlans, remote.incomePlans) &&
        _transferTasksEqual(local.transferTasks, remote.transferTasks);
  }

  bool _doubleMapEquals(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  bool _stringMapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  bool _annualRateEvidencesEqual(
    Map<String, AssetLiabilityAnnualRateEvidence> a,
    Map<String, AssetLiabilityAnnualRateEvidence> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      final other = b[entry.key];
      final current = entry.value;
      if (other == null ||
          other.accountId != current.accountId ||
          other.fileName != current.fileName ||
          other.mimeType != current.mimeType ||
          other.submittedAt.toUtc() != current.submittedAt.toUtc() ||
          other.submittedAnnualRate != current.submittedAnnualRate ||
          other.detectedAnnualRate != current.detectedAnnualRate ||
          other.status != current.status ||
          other.summary != current.summary ||
          other.source != current.source ||
          other.errorMessage != current.errorMessage) {
        return false;
      }
    }
    return true;
  }

  bool _stringSetEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) {
      return false;
    }
    return a.every(b.contains);
  }

  bool _incomePlansEqual(
    List<AssetLiabilityIncomePlan> a,
    List<AssetLiabilityIncomePlan> b,
  ) {
    final first = List<AssetLiabilityIncomePlan>.from(a)
      ..sort((left, right) => left.id.compareTo(right.id));
    final second = List<AssetLiabilityIncomePlan>.from(b)
      ..sort((left, right) => left.id.compareTo(right.id));
    if (first.length != second.length) {
      return false;
    }
    for (var i = 0; i < first.length; i++) {
      final left = first[i];
      final right = second[i];
      if (left.id != right.id ||
          left.date != right.date ||
          left.name != right.name ||
          left.amount != right.amount ||
          left.destinationAccountId != right.destinationAccountId ||
          left.destinationAccountName != right.destinationAccountName ||
          left.received != right.received) {
        return false;
      }
    }
    return true;
  }

  bool _cardStatementLinesEqual(
    List<AssetLiabilityCardStatementLine> a,
    List<AssetLiabilityCardStatementLine> b,
  ) {
    final first = List<AssetLiabilityCardStatementLine>.from(a)
      ..sort((left, right) => left.id.compareTo(right.id));
    final second = List<AssetLiabilityCardStatementLine>.from(b)
      ..sort((left, right) => left.id.compareTo(right.id));
    if (first.length != second.length) {
      return false;
    }
    for (var i = 0; i < first.length; i++) {
      final left = first[i];
      final right = second[i];
      if (left.id != right.id ||
          left.billingAccountId != right.billingAccountId ||
          left.billingAccountName != right.billingAccountName ||
          left.postedAt != right.postedAt ||
          left.description != right.description ||
          left.amount != right.amount) {
        return false;
      }
    }
    return true;
  }

  bool _transferTasksEqual(
    List<AssetLiabilityTransferTask> a,
    List<AssetLiabilityTransferTask> b,
  ) {
    final first = List<AssetLiabilityTransferTask>.from(a)
      ..sort((left, right) => left.id.compareTo(right.id));
    final second = List<AssetLiabilityTransferTask>.from(b)
      ..sort((left, right) => left.id.compareTo(right.id));
    if (first.length != second.length) {
      return false;
    }
    for (var i = 0; i < first.length; i++) {
      final left = first[i];
      final right = second[i];
      if (left.id != right.id ||
          left.fromAccountId != right.fromAccountId ||
          left.fromAccountName != right.fromAccountName ||
          left.toAccountId != right.toAccountId ||
          left.toAccountName != right.toAccountName ||
          left.amount != right.amount ||
          left.dueDate != right.dueDate ||
          left.completed != right.completed ||
          left.completedAt != right.completedAt ||
          left.completionMemo != right.completionMemo ||
          left.canceled != right.canceled ||
          left.canceledAt != right.canceledAt ||
          left.cancellationReason != right.cancellationReason) {
        return false;
      }
    }
    return true;
  }

  bool _recurringTemplatesEqual(
    List<AssetLiabilityRecurringIncomeTemplate> a,
    List<AssetLiabilityRecurringIncomeTemplate> b,
  ) {
    final first = List<AssetLiabilityRecurringIncomeTemplate>.from(a)
      ..sort((left, right) => left.id.compareTo(right.id));
    final second = List<AssetLiabilityRecurringIncomeTemplate>.from(b)
      ..sort((left, right) => left.id.compareTo(right.id));
    if (first.length != second.length) {
      return false;
    }
    for (var i = 0; i < first.length; i++) {
      final left = first[i];
      final right = second[i];
      if (left.id != right.id ||
          left.dayOfMonth != right.dayOfMonth ||
          left.name != right.name ||
          left.amount != right.amount ||
          left.destinationAccountId != right.destinationAccountId ||
          left.destinationAccountName != right.destinationAccountName) {
        return false;
      }
    }
    return true;
  }

  bool _monthlySnapshotsEqual(
    List<AssetLiabilityMonthlySnapshot> a,
    List<AssetLiabilityMonthlySnapshot> b,
  ) {
    final first = List<AssetLiabilityMonthlySnapshot>.from(a)
      ..sort((left, right) => left.monthKey.compareTo(right.monthKey));
    final second = List<AssetLiabilityMonthlySnapshot>.from(b)
      ..sort((left, right) => left.monthKey.compareTo(right.monthKey));
    if (first.length != second.length) {
      return false;
    }
    for (var i = 0; i < first.length; i++) {
      final left = first[i];
      final right = second[i];
      if (left.monthKey != right.monthKey ||
          left.savedAt != right.savedAt ||
          left.positiveAssetTotal != right.positiveAssetTotal ||
          left.liabilityTotal != right.liabilityTotal ||
          left.netWorth != right.netWorth ||
          left.cashLikeTotal != right.cashLikeTotal ||
          left.monthlyScheduledPaymentTotal !=
              right.monthlyScheduledPaymentTotal ||
          left.monthlyPaidPaymentTotal != right.monthlyPaidPaymentTotal ||
          left.monthlyUnpaidPaymentTotal != right.monthlyUnpaidPaymentTotal ||
          left.overduePaymentCount != right.overduePaymentCount) {
        return false;
      }
    }
    return true;
  }

  List<AssetLiabilityMonthlySnapshot> _latestMonthlySnapshots(
    List<AssetLiabilityMonthlySnapshot> snapshots,
  ) {
    final sorted = List<AssetLiabilityMonthlySnapshot>.from(snapshots)
      ..sort((left, right) => left.monthKey.compareTo(right.monthKey));
    const maxSnapshots = AssetManagementEgressPolicy.maxMonthlySnapshots;
    if (sorted.length <= maxSnapshots) {
      return sorted;
    }
    return sorted.sublist(sorted.length - maxSnapshots);
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

class _AssetLiabilitySyncData {
  final AssetLiabilityMonthlyState localMonth;
  final Map<String, String> localSources;
  final Map<String, String> localDefaultCardBillingAccounts;
  final List<AssetLiabilityRecurringIncomeTemplate> localTemplates;
  final List<AssetLiabilityMonthlySnapshot> localSnapshots;
  final AssetLiabilityMonthlyState? remoteMonth;
  final Map<String, String>? remoteSources;
  final Map<String, String>? remoteDefaultCardBillingAccounts;
  final List<AssetLiabilityRecurringIncomeTemplate>? remoteTemplates;
  final List<AssetLiabilityMonthlySnapshot>? remoteSnapshots;

  const _AssetLiabilitySyncData({
    required this.localMonth,
    required this.localSources,
    required this.localDefaultCardBillingAccounts,
    required this.localTemplates,
    required this.localSnapshots,
    required this.remoteMonth,
    required this.remoteSources,
    required this.remoteDefaultCardBillingAccounts,
    required this.remoteTemplates,
    required this.remoteSnapshots,
  });
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
      payload: buildMonthlyStatesPayload(row),
    );
    await _upsertPayloadRow(
      AssetLiabilitySupabaseTablePlan.incomePlansTable,
      userId: userId,
      monthKey: monthKey,
      payload: <String, Object?>{'income_plans': row['income_plans']},
    );
  }

  /// `monthly_states` テーブルへ書き込む payload を [row]
  /// (= [AssetLiabilityMonthlyStatePayload.toSupabaseJson] の出力) から構築する。
  ///
  /// 明示的な allowlist で詰め替えると、以前のように新フィールドを書き忘れて
  /// リモートへ届かない事故 (= `billing_confirmed_account_ids` /
  /// `transfer_tasks` が漏れ、端末間で同期されず LWW でローカルを消去していた
  /// `paid_account_ids` と同型の潜在バグ) が起こる。これを構造的に防ぐため、
  /// [row] から「monthly_states に属さないキーだけ」を除外して導出する:
  ///
  /// - `user_id` / `month_key`: 識別子カラムは [_upsertPayloadRow] が個別に付与する。
  /// - `income_plans`: 別テーブル
  ///   ([AssetLiabilitySupabaseTablePlan.incomePlansTable]) へ保存する。
  /// - `updated_at`: サーバ upsert 時刻のカラム用。payload には載せない
  ///   (クライアント編集時刻は `state_updated_at` として別に保持する)。
  ///
  /// こうすることで `toSupabaseJson` に新キーが増えても自動的にリモートへ同期され、
  /// `fromSupabaseJson` 側の読み込みと取りこぼしなく対応する。
  @visibleForTesting
  static Map<String, Object?> buildMonthlyStatesPayload(
    Map<String, Object?> row,
  ) {
    return Map<String, Object?>.from(row)
      ..remove('user_id')
      ..remove('month_key')
      ..remove('income_plans')
      ..remove('updated_at');
  }

  @override
  Future<AssetLiabilityDefaultPaymentSettings?> loadDefaultPaymentSettings({
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
    final settings = AssetLiabilityUserSettingsPayload.fromSupabaseJson(
      payload,
    );
    return AssetLiabilityDefaultPaymentSettings(
      paymentSourceAccountIds: settings.defaultPaymentSourceAccountIds,
      cardBillingAccountIds: settings.defaultCardBillingAccountIds,
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
      defaultCardBillingAccountIds: const <String, String>{},
      recurringIncomeTemplates: const <AssetLiabilityRecurringIncomeTemplate>[],
    ).toSupabaseJson(userId: userId);
    await _upsertMergedPayloadRow(
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
  Future<Map<String, String>?> loadDefaultCardBillingAccounts({
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
    ).defaultCardBillingAccountIds;
  }

  @override
  Future<void> saveDefaultCardBillingAccounts({
    required String userId,
    required Map<String, String> accounts,
  }) async {
    final row = AssetLiabilityUserSettingsPayload(
      defaultPaymentSourceAccountIds: const <String, String>{},
      defaultCardBillingAccountIds: accounts,
      recurringIncomeTemplates: const <AssetLiabilityRecurringIncomeTemplate>[],
    ).toSupabaseJson(userId: userId);
    await _upsertMergedPayloadRow(
      AssetLiabilitySupabaseTablePlan.paymentSourceSettingsTable,
      userId: userId,
      monthKey: AssetLiabilitySupabaseTablePlan.globalMonthKey,
      payload: <String, Object?>{
        'default_card_billing_account_ids':
            row['default_card_billing_account_ids'],
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
      defaultCardBillingAccountIds: const <String, String>{},
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
        .order('month_key', ascending: false)
        .limit(AssetManagementEgressPolicy.maxMonthlySnapshots);

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

  @override
  Future<List<AssetLiabilityMonthlyReport>?> loadMonthlyReports({
    required String userId,
    int limit = 24,
  }) async {
    final response = await client
        .from('monthly_asset_reports')
        .select(
          'year_month,total_assets,total_liabilities,net_worth,ai_summary,ai_model,generated_at',
        )
        .eq('user_id', userId)
        .order('year_month', ascending: false)
        .limit(limit < 0 ? 0 : limit);

    final reports = <AssetLiabilityMonthlyReport>[];
    for (final item in response) {
      final monthKey = _monthKeyFromReportValue(item['year_month']);
      final generatedAt = _dateTimeFromReportValue(item['generated_at']);
      if (monthKey == null || generatedAt == null) {
        continue;
      }
      reports.add(
        AssetLiabilityMonthlyReport(
          monthKey: monthKey,
          generatedAt: generatedAt,
          totalAssets: _doubleFromReportValue(item['total_assets']),
          totalLiabilities: _doubleFromReportValue(item['total_liabilities']),
          netWorth: _doubleFromReportValue(item['net_worth']),
          aiSummary: item['ai_summary']?.toString() ?? '',
          aiModel: item['ai_model']?.toString() ?? '',
        ),
      );
    }
    reports.sort((a, b) => b.monthKey.compareTo(a.monthKey));
    return reports;
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

  Future<void> _upsertMergedPayloadRow(
    String table, {
    required String userId,
    required String monthKey,
    required Map<String, Object?> payload,
  }) async {
    final current =
        await _loadPayloadRow(table, userId: userId, monthKey: monthKey) ??
            const <String, Object?>{};
    await _upsertPayloadRow(
      table,
      userId: userId,
      monthKey: monthKey,
      payload: <String, Object?>{...current, ...payload},
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

  String? _monthKeyFromReportValue(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    final direct = RegExp(r'^(\d{4})-(\d{2})').firstMatch(text);
    if (direct != null) {
      final month = int.tryParse(direct.group(2)!);
      if (month != null && month >= 1 && month <= 12) {
        return '${direct.group(1)}-${direct.group(2)}';
      }
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      return null;
    }
    return AssetLiabilityMonthlyStateStore.formatMonthKey(parsed);
  }

  DateTime? _dateTimeFromReportValue(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text);
  }

  double _doubleFromReportValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }
    return 0;
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
  Future<Map<String, String>> loadDefaultCardBillingAccounts() {
    return store.loadDefaultCardBillingAccounts();
  }

  @override
  Future<void> saveDefaultCardBillingAccounts(Map<String, String> accounts) {
    return store.saveDefaultCardBillingAccounts(accounts);
  }

  @override
  Future<Map<String, int>> loadDebtPaymentDayOverrides() {
    return store.loadDebtPaymentDayOverrides();
  }

  @override
  Future<void> saveDebtPaymentDayOverrides(Map<String, int> overrides) {
    return store.saveDebtPaymentDayOverrides(overrides);
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
    DateTime targetMonth, {
    bool carryOverIncompleteTransferTasks = false,
  }) {
    return store.copyPreviousMonthToMonth(
      targetMonth,
      carryOverIncompleteTransferTasks: carryOverIncompleteTransferTasks,
    );
  }

  @override
  Future<List<AssetLiabilityMonthlySnapshot>> loadMonthlySnapshots() {
    return store.loadMonthlySnapshots();
  }

  @override
  Future<void> saveMonthlySnapshot(AssetLiabilityMonthlySnapshot snapshot) {
    return store.saveMonthlySnapshot(snapshot);
  }

  @override
  Future<List<AssetLiabilitySyncAuditLog>> loadSyncAuditLogs({int limit = 20}) {
    return store.loadSyncAuditLogs(limit: limit);
  }

  @override
  Future<void> saveSyncAuditLog(AssetLiabilitySyncAuditLog log) {
    return store.saveSyncAuditLog(log);
  }
}
