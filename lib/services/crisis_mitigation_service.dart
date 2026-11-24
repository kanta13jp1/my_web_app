import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 危機管理リスクカテゴリ (#2584)。
enum CrisisCategory {
  naturalDisaster('natural_disaster', '自然災害'),
  infraOutage('infra_outage', 'インフラ障害'),
  security('security', 'セキュリティ'),
  supplyChain('supply_chain', '外部依存・調達'),
  operations('operations', '業務継続');

  const CrisisCategory(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CrisisCategory parse(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase() ?? '';
    for (final item in values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return CrisisCategory.naturalDisaster;
  }
}

/// リスク深刻度 (#2584)。
enum CrisisSeverity {
  low('low', '低'),
  medium('medium', '中'),
  high('high', '高'),
  critical('critical', '重大');

  const CrisisSeverity(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CrisisSeverity parse(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase() ?? '';
    for (final item in values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return CrisisSeverity.medium;
  }
}

/// リスク対応ステータス (#2584)。
enum CrisisStatus {
  monitoring('monitoring', '監視中'),
  mitigating('mitigating', '対策中'),
  resolved('resolved', '収束');

  const CrisisStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CrisisStatus parse(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase() ?? '';
    for (final item in values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return CrisisStatus.monitoring;
  }
}

/// `public.crisis_risks` テーブルの不変モデル (#2584)。
@immutable
class CrisisRiskItem {
  const CrisisRiskItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.severity,
    required this.likelihood,
    required this.impact,
    this.status = CrisisStatus.monitoring,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final CrisisCategory category;
  final CrisisSeverity severity;
  final int likelihood;
  final int impact;
  final CrisisStatus status;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get riskScore => likelihood.clamp(1, 5) * impact.clamp(1, 5);

  factory CrisisRiskItem.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at']?.toString().trim();
    final updatedRaw = json['updated_at']?.toString().trim();
    return CrisisRiskItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      category: CrisisCategory.parse(json['category']),
      severity: CrisisSeverity.parse(json['severity']),
      likelihood: (_parseInt(json['likelihood']) ?? 3).clamp(1, 5),
      impact: (_parseInt(json['impact']) ?? 3).clamp(1, 5),
      status: CrisisStatus.parse(json['status']),
      notes: (json['notes'] as String?)?.trim() ?? '',
      createdAt: createdRaw == null || createdRaw.isEmpty
          ? null
          : DateTime.tryParse(createdRaw)?.toUtc(),
      updatedAt: updatedRaw == null || updatedRaw.isEmpty
          ? null
          : DateTime.tryParse(updatedRaw)?.toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id.isNotEmpty) 'id': id,
      if (userId.isNotEmpty) 'user_id': userId,
      'title': title,
      'category': category.wireValue,
      'severity': severity.wireValue,
      'likelihood': likelihood.clamp(1, 5),
      'impact': impact.clamp(1, 5),
      'status': status.wireValue,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}

/// `public.mitigation_plans` テーブルの不変モデル (#2584)。
@immutable
class MitigationPlanItem {
  const MitigationPlanItem({
    required this.id,
    required this.riskId,
    required this.userId,
    required this.actionTitle,
    this.ownerRole = '',
    this.triggerCondition = '',
    this.offlinePriority = 1,
    this.isOfflineEssential = true,
    this.createdAt,
  });

  final String id;
  final String riskId;
  final String userId;
  final String actionTitle;
  final String ownerRole;
  final String triggerCondition;
  final int offlinePriority;
  final bool isOfflineEssential;
  final DateTime? createdAt;

  factory MitigationPlanItem.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at']?.toString().trim();
    final essentialRaw = json['is_offline_essential'];
    return MitigationPlanItem(
      id: json['id']?.toString() ?? '',
      riskId: json['risk_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      actionTitle: (json['action_title'] as String?)?.trim() ?? '',
      ownerRole: (json['owner_role'] as String?)?.trim() ?? '',
      triggerCondition: (json['trigger_condition'] as String?)?.trim() ?? '',
      offlinePriority: (_parseInt(json['offline_priority']) ?? 1).clamp(1, 5),
      isOfflineEssential: essentialRaw is bool ? essentialRaw : true,
      createdAt: createdRaw == null || createdRaw.isEmpty
          ? null
          : DateTime.tryParse(createdRaw)?.toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id.isNotEmpty) 'id': id,
      'risk_id': riskId,
      if (userId.isNotEmpty) 'user_id': userId,
      'action_title': actionTitle,
      'owner_role': ownerRole,
      'trigger_condition': triggerCondition,
      'offline_priority': offlinePriority.clamp(1, 5),
      'is_offline_essential': isOfflineEssential,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

/// オンライン同期データまたはオフラインキャッシュから復元したスナップショット (#2584)。
@immutable
class CrisisIntakeSnapshot {
  const CrisisIntakeSnapshot({
    required this.risks,
    required this.plans,
    this.fromOfflineCache = false,
    this.cachedAt,
    this.warningMessage,
  });

  final List<CrisisRiskItem> risks;
  final List<MitigationPlanItem> plans;
  final bool fromOfflineCache;
  final DateTime? cachedAt;
  final String? warningMessage;

  List<MitigationPlanItem> get offlineEssentialPlans {
    final essential =
        plans.where((plan) => plan.isOfflineEssential).toList(growable: false);
    final sorted = List<MitigationPlanItem>.from(essential)
      ..sort((a, b) => a.offlinePriority.compareTo(b.offlinePriority));
    return List<MitigationPlanItem>.unmodifiable(sorted);
  }
}

/// 災害時オフラインキャッシュの永続化ストア抽象 (#2584)。
abstract class CrisisOfflineCacheStore {
  Future<void> writePayload(String rawJson);
  Future<String?> readPayload();
}

/// `SharedPreferences` を用いた本番用オフラインキャッシュストア (#2584)。
class SharedPreferencesCrisisOfflineCacheStore
    implements CrisisOfflineCacheStore {
  const SharedPreferencesCrisisOfflineCacheStore({
    this.storageKey = defaultStorageKey,
  });

  static const String defaultStorageKey = 'crisis_mitigation_offline_cache_v1';

  final String storageKey;

  @override
  Future<String?> readPayload() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  @override
  Future<void> writePayload(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, rawJson);
  }
}

/// プラットフォームチャネル非依存のメモリ内キャッシュストア（テスト・フォールバック兼用）(#2584)。
class InMemoryCrisisOfflineCacheStore implements CrisisOfflineCacheStore {
  InMemoryCrisisOfflineCacheStore([this._payload]);

  String? _payload;

  @override
  Future<String?> readPayload() async => _payload;

  @override
  Future<void> writePayload(String rawJson) async {
    _payload = rawJson;
  }
}

/// `isOfflineEssential == true` の対策プランと関連リスクを JSON 永続化するキャッシュサービス (#2584)。
class CrisisOfflineCacheService {
  const CrisisOfflineCacheService({
    CrisisOfflineCacheStore? store,
  }) : _store = store ?? const SharedPreferencesCrisisOfflineCacheStore();

  final CrisisOfflineCacheStore _store;

  Future<CrisisIntakeSnapshot> saveSnapshot({
    required List<CrisisRiskItem> risks,
    required List<MitigationPlanItem> plans,
    DateTime? cachedAt,
  }) async {
    final timestamp = (cachedAt ?? DateTime.now()).toUtc();
    final essentialPlans = List<MitigationPlanItem>.from(
      plans.where((plan) => plan.isOfflineEssential),
    )..sort((a, b) => a.offlinePriority.compareTo(b.offlinePriority));

    final encoded = jsonEncode(<String, Object?>{
      'schema_version': 1,
      'cached_at': timestamp.toIso8601String(),
      'risks': risks.map((risk) => risk.toJson()).toList(growable: false),
      'plans':
          essentialPlans.map((plan) => plan.toJson()).toList(growable: false),
    });
    await _store.writePayload(encoded);

    return CrisisIntakeSnapshot(
      risks: List<CrisisRiskItem>.unmodifiable(risks),
      plans: List<MitigationPlanItem>.unmodifiable(essentialPlans),
      fromOfflineCache: true,
      cachedAt: timestamp,
    );
  }

  Future<CrisisIntakeSnapshot?> loadCachedSnapshot() async {
    try {
      final raw = await _store.readPayload();
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, Object?>.from(decoded);
      final rawRisks = map['risks'];
      final rawPlans = map['plans'];
      final risks = rawRisks is List
          ? rawRisks
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (item) => CrisisRiskItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <CrisisRiskItem>[];
      final plans = rawPlans is List
          ? rawPlans
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (item) => MitigationPlanItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((plan) => plan.isOfflineEssential)
              .toList(growable: false)
          : const <MitigationPlanItem>[];
      final sortedPlans = List<MitigationPlanItem>.from(plans)
        ..sort((a, b) => a.offlinePriority.compareTo(b.offlinePriority));
      final cachedAtRaw = map['cached_at']?.toString();
      final cachedAt =
          cachedAtRaw == null ? null : DateTime.tryParse(cachedAtRaw)?.toUtc();
      return CrisisIntakeSnapshot(
        risks: List<CrisisRiskItem>.unmodifiable(risks),
        plans: List<MitigationPlanItem>.unmodifiable(sortedPlans),
        fromOfflineCache: true,
        cachedAt: cachedAt,
      );
    } catch (_) {
      return null;
    }
  }
}

/// `crisis_risks` / `mitigation_plans` の読み書きリポジトリ抽象 (#2584)。
abstract class CrisisIntakeRepository {
  Future<CrisisIntakeSnapshot> fetchAll();

  Future<CrisisRiskItem> createRisk({
    required String title,
    required CrisisCategory category,
    required CrisisSeverity severity,
    required int likelihood,
    required int impact,
    CrisisStatus status = CrisisStatus.monitoring,
    String notes = '',
  });

  Future<MitigationPlanItem> createMitigationPlan({
    required String riskId,
    required String actionTitle,
    String ownerRole = '',
    String triggerCondition = '',
    int offlinePriority = 1,
    bool isOfflineEssential = true,
  });
}

/// 遅延解決型 `Supabase.instance.client` を用いる本番用リポジトリ (#2584)。
class SupabaseCrisisIntakeRepository implements CrisisIntakeRepository {
  const SupabaseCrisisIntakeRepository({
    SupabaseClient Function()? clientResolver,
  }) : _clientResolver = clientResolver;

  final SupabaseClient Function()? _clientResolver;

  SupabaseClient _resolveClient() {
    final resolver = _clientResolver;
    if (resolver != null) {
      return resolver();
    }
    return Supabase.instance.client;
  }

  @override
  Future<CrisisIntakeSnapshot> fetchAll() async {
    final client = _resolveClient();
    final riskRows = await client
        .from('crisis_risks')
        .select()
        .order('updated_at', ascending: false);
    final planRows = await client
        .from('mitigation_plans')
        .select()
        .order('offline_priority', ascending: true);

    final risks = riskRows.map(CrisisRiskItem.fromJson).toList(growable: false);
    final plans =
        planRows.map(MitigationPlanItem.fromJson).toList(growable: false);
    return CrisisIntakeSnapshot(
      risks: List<CrisisRiskItem>.unmodifiable(risks),
      plans: List<MitigationPlanItem>.unmodifiable(plans),
    );
  }

  @override
  Future<CrisisRiskItem> createRisk({
    required String title,
    required CrisisCategory category,
    required CrisisSeverity severity,
    required int likelihood,
    required int impact,
    CrisisStatus status = CrisisStatus.monitoring,
    String notes = '',
  }) async {
    final client = _resolveClient();
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('認証済みユーザーが必要です。');
    }
    final payload = <String, Object?>{
      'user_id': userId,
      'title': title.trim(),
      'category': category.wireValue,
      'severity': severity.wireValue,
      'likelihood': likelihood.clamp(1, 5),
      'impact': impact.clamp(1, 5),
      'status': status.wireValue,
      'notes': notes.trim(),
    };
    final inserted =
        await client.from('crisis_risks').insert(payload).select().single();
    return CrisisRiskItem.fromJson(inserted);
  }

  @override
  Future<MitigationPlanItem> createMitigationPlan({
    required String riskId,
    required String actionTitle,
    String ownerRole = '',
    String triggerCondition = '',
    int offlinePriority = 1,
    bool isOfflineEssential = true,
  }) async {
    final client = _resolveClient();
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('認証済みユーザーが必要です。');
    }
    final payload = <String, Object?>{
      'risk_id': riskId,
      'user_id': userId,
      'action_title': actionTitle.trim(),
      'owner_role': ownerRole.trim(),
      'trigger_condition': triggerCondition.trim(),
      'offline_priority': offlinePriority.clamp(1, 5),
      'is_offline_essential': isOfflineEssential,
    };
    final inserted =
        await client.from('mitigation_plans').insert(payload).select().single();
    return MitigationPlanItem.fromJson(inserted);
  }
}

/// オンライン取得と災害時オフラインキャッシュフォールバックを統括するサービス (#2584)。
class CrisisMitigationService {
  const CrisisMitigationService({
    required this.repository,
    this.cacheService = const CrisisOfflineCacheService(),
  });

  final CrisisIntakeRepository repository;
  final CrisisOfflineCacheService cacheService;

  Future<CrisisIntakeSnapshot> loadWithOfflineFallback() async {
    try {
      final live = await repository.fetchAll();
      await cacheService.saveSnapshot(
        risks: live.risks,
        plans: live.plans,
      );
      return live;
    } catch (_) {
      final cached = await cacheService.loadCachedSnapshot();
      if (cached != null) {
        return CrisisIntakeSnapshot(
          risks: cached.risks,
          plans: cached.plans,
          fromOfflineCache: true,
          cachedAt: cached.cachedAt,
          warningMessage: '通信障害またはオフライン環境のため、端末キャッシュ済みの緊急対策プランを表示しています。',
        );
      }
      return const CrisisIntakeSnapshot(
        risks: <CrisisRiskItem>[],
        plans: <MitigationPlanItem>[],
        fromOfflineCache: true,
        warningMessage: '通信障害またはオフライン環境です。利用可能なローカルキャッシュがまだ保存されていません。',
      );
    }
  }

  Future<CrisisRiskItem> createRiskAndSyncCache({
    required List<CrisisRiskItem> currentRisks,
    required List<MitigationPlanItem> currentPlans,
    required String title,
    required CrisisCategory category,
    required CrisisSeverity severity,
    required int likelihood,
    required int impact,
    CrisisStatus status = CrisisStatus.monitoring,
    String notes = '',
  }) async {
    final created = await repository.createRisk(
      title: title,
      category: category,
      severity: severity,
      likelihood: likelihood,
      impact: impact,
      status: status,
      notes: notes,
    );
    await cacheService.saveSnapshot(
      risks: <CrisisRiskItem>[created, ...currentRisks],
      plans: currentPlans,
    );
    return created;
  }

  Future<MitigationPlanItem> createPlanAndSyncCache({
    required List<CrisisRiskItem> currentRisks,
    required List<MitigationPlanItem> currentPlans,
    required String riskId,
    required String actionTitle,
    String ownerRole = '',
    String triggerCondition = '',
    int offlinePriority = 1,
    bool isOfflineEssential = true,
  }) async {
    final created = await repository.createMitigationPlan(
      riskId: riskId,
      actionTitle: actionTitle,
      ownerRole: ownerRole,
      triggerCondition: triggerCondition,
      offlinePriority: offlinePriority,
      isOfflineEssential: isOfflineEssential,
    );
    await cacheService.saveSnapshot(
      risks: currentRisks,
      plans: <MitigationPlanItem>[created, ...currentPlans],
    );
    return created;
  }
}

int? _parseInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}
