import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/org_idp_rbac_models.dart';

/// Supabase Edge (`admin-hub`) repository for Org/IdP Group RBAC & SSO (#2691).
class SupabaseOrgIdpRbacRepository implements OrgIdpRbacRepository {
  SupabaseOrgIdpRbacRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String _requireUserId(final SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('組織・IdP RBAC 設定にアクセスするにはログインが必要です。');
    }
    return userId;
  }

  Map<String, Object?> _asStringKeyMap(final Object? raw) {
    if (raw is Map<Object?, Object?>) {
      return raw.map<String, Object?>(
        (final Object? k, final Object? v) => MapEntry(k.toString(), v),
      );
    }
    return const <String, Object?>{};
  }

  OrgUiCapabilities _mapCapabilities(
    final Map<String, Object?> raw,
    final OrgRbacRole fallbackRole,
  ) {
    if (raw.isEmpty) {
      return OrgUiCapabilities.fromRole(fallbackRole);
    }
    final role = OrgRbacRole.fromWire(
      raw['role'] as String? ?? fallbackRole.wireValue,
    );
    return OrgUiCapabilities(
      role: role,
      canViewOrg: raw['can_view_org'] as bool? ?? role != OrgRbacRole.none,
      canExecuteMemberActions: raw['can_execute_member_actions'] as bool? ??
          role.satisfies(OrgRbacRole.member),
      canManageIdpMappings: raw['can_manage_idp_mappings'] as bool? ??
          role.satisfies(OrgRbacRole.admin),
      canAssignOwnerRole:
          raw['can_assign_owner_role'] as bool? ?? role == OrgRbacRole.owner,
    );
  }

  IdpGroupMapping _mapRule(final Map<String, Object?> row) {
    return IdpGroupMapping(
      id: (row['id'] ?? '').toString(),
      workosOrgId: (row['workos_org_id'] ?? '').toString(),
      idpProvider: IdpProviderKind.fromWire(row['idp_provider'] as String?),
      idpGroupId: (row['idp_group_id'] ?? '').toString(),
      idpGroupLabel: (row['idp_group_label'] ?? '').toString(),
      mappedRole: OrgRbacRole.fromWire(row['mapped_role'] as String?),
      priority: (row['priority'] as num?)?.toInt() ?? 100,
      isActive: row['is_active'] as bool? ?? true,
    );
  }

  SsoAuditEntry _mapAudit(final Map<String, Object?> row) {
    return SsoAuditEntry(
      id: (row['id'] ?? '').toString(),
      idpProvider: IdpProviderKind.fromWire(row['idp_provider'] as String?),
      resolvedRole: OrgRbacRole.fromWire(row['resolved_role'] as String?),
      resolutionSource: (row['resolution_source'] ?? '').toString(),
      overageDetected: row['group_overage_detected'] as bool? ?? false,
      evaluatedAt: DateTime.tryParse((row['evaluated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  List<String> _asStringList(final Object? raw) {
    if (raw is List<Object?>) {
      return raw.map((final Object? item) => item.toString()).toList();
    }
    return <String>[];
  }

  @override
  Future<List<OrgTenantSummary>> fetchOrganizations() async {
    final client = _resolvedClient;
    _requireUserId(client);
    final rows = await client
        .from('workos_organizations')
        .select('workos_org_id,organization_name')
        .order('created_at', ascending: false)
        .limit(20);
    return rows.map((final Object? raw) {
      final row = _asStringKeyMap(raw);
      return OrgTenantSummary(
        workosOrgId: (row['workos_org_id'] ?? '').toString(),
        organizationName: (row['organization_name'] ?? '').toString(),
      );
    }).toList();
  }

  @override
  Future<OrgIdpBundle> fetchOrgIdpState(final String workosOrgId) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final response = await client.functions.invoke(
      'admin-hub',
      body: <String, Object?>{
        'action': 'workos.idp_mappings.list',
        'workos_org_id': workosOrgId.trim(),
      },
    );
    final payload = _asStringKeyMap(response.data);
    if (response.status >= 400 || payload['ok'] != true) {
      throw StateError(
        (payload['error'] ?? 'IdP マッピング取得に失敗しました').toString(),
      );
    }
    final role = OrgRbacRole.fromWire(payload['caller_role'] as String?);
    final caps = _mapCapabilities(
      _asStringKeyMap(payload['ui_capabilities']),
      role,
    );
    final rawMappings = payload['mappings'] is List<Object?>
        ? payload['mappings']! as List<Object?>
        : const <Object?>[];
    final rawAudits = payload['audits'] is List<Object?>
        ? payload['audits']! as List<Object?>
        : const <Object?>[];
    return OrgIdpBundle(
      callerRole: role,
      capabilities: caps,
      mappings: rawMappings
          .map((final Object? item) => _mapRule(_asStringKeyMap(item)))
          .toList(),
      audits: rawAudits
          .map((final Object? item) => _mapAudit(_asStringKeyMap(item)))
          .toList(),
    );
  }

  @override
  Future<IdpGroupMapping> upsertMapping({
    required final String workosOrgId,
    required final IdpProviderKind idpProvider,
    required final String idpGroupId,
    required final String idpGroupLabel,
    required final OrgRbacRole mappedRole,
    required final int priority,
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final response = await client.functions.invoke(
      'admin-hub',
      body: <String, Object?>{
        'action': 'workos.idp_mappings.upsert',
        'workos_org_id': workosOrgId.trim(),
        'idp_provider': idpProvider.wireValue,
        'idp_group_id': idpGroupId.trim(),
        'idp_group_label': idpGroupLabel.trim(),
        'mapped_role': mappedRole.wireValue,
        'priority': priority,
      },
    );
    final payload = _asStringKeyMap(response.data);
    if (response.status >= 400 || payload['ok'] != true) {
      throw StateError(
        (payload['error'] ?? 'IdP グループマッピング保存に失敗しました').toString(),
      );
    }
    return _mapRule(_asStringKeyMap(payload['mapping']));
  }

  @override
  Future<void> deleteMapping({
    required final String workosOrgId,
    required final String mappingId,
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final response = await client.functions.invoke(
      'admin-hub',
      body: <String, Object?>{
        'action': 'workos.idp_mappings.delete',
        'workos_org_id': workosOrgId.trim(),
        'mapping_id': mappingId.trim(),
      },
    );
    final payload = _asStringKeyMap(response.data);
    if (response.status >= 400 || payload['ok'] != true) {
      throw StateError(
        (payload['error'] ?? 'IdP グループマッピング削除に失敗しました').toString(),
      );
    }
  }

  @override
  Future<SsoEvaluationResult> evaluateSsoAssertion({
    required final String workosOrgId,
    required final IdpProviderKind idpProvider,
    required final List<String> assertedGroups,
    required final bool simulateAzureOverage,
    required final OrgRbacRole requiredRole,
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final claims = <String, Object?>{
      'groups': List<String>.of(assertedGroups),
      if (simulateAzureOverage) 'hasgroups': true,
    };
    final response = await client.functions.invoke(
      'admin-hub',
      body: <String, Object?>{
        'action': 'workos.sso_evaluate',
        'workos_org_id': workosOrgId.trim(),
        'idp_provider': idpProvider.wireValue,
        'required_role': requiredRole.wireValue,
        'claims': claims,
      },
    );
    final payload = _asStringKeyMap(response.data);
    final role = OrgRbacRole.fromWire(
      payload['resolved_role'] as String? ?? 'none',
    );
    return SsoEvaluationResult(
      allowed: payload['allowed'] as bool? ?? false,
      resolvedRole: role,
      resolutionSource: (payload['resolution_source'] ?? '').toString(),
      overageDetected: payload['overage_detected'] as bool? ?? false,
      matchedGroups: _asStringList(payload['matched_groups']),
      warnings: _asStringList(payload['warnings']),
      capabilities: _mapCapabilities(
        _asStringKeyMap(payload['ui_capabilities']),
        role,
      ),
    );
  }
}
