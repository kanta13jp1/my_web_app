import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workos_scim_models.dart';

/// Supabase-backed repository for WorkOS Admin Portal & Directory Sync (#2683).
class SupabaseWorkosScimRepository implements WorkosScimRepository {
  SupabaseWorkosScimRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String _requireUserId(final SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('WorkOS テナント管理を利用するにはログインが必要です。');
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

  WorkosOrganization _mapOrg(final Map<String, Object?> row) {
    return WorkosOrganization(
      id: (row['id'] ?? '').toString(),
      workosOrgId: (row['workos_org_id'] ?? '').toString(),
      organizationName: (row['organization_name'] ?? '').toString(),
      ownerUserId: (row['owner_user_id'] ?? '').toString(),
      scimEnabled: row['scim_enabled'] as bool? ?? true,
      defaultRole: WorkosOrgRole.fromWire(row['default_role'] as String?),
      lastIntent: WorkosPortalIntent.fromWire(
        row['admin_portal_last_intent'] as String?,
      ),
      lastPortalGeneratedAt: row['last_portal_generated_at'] is String
          ? DateTime.tryParse(row['last_portal_generated_at']! as String)
          : null,
    );
  }

  WorkosDirectoryMember _mapMember(final Map<String, Object?> row) {
    return WorkosDirectoryMember(
      id: (row['id'] ?? '').toString(),
      workosOrgId: (row['workos_org_id'] ?? '').toString(),
      directoryUserId: (row['workos_directory_user_id'] ?? '').toString(),
      email: (row['email'] ?? '').toString(),
      displayName: (row['display_name'] ?? '').toString(),
      role: WorkosOrgRole.fromWire(row['role'] as String?),
      status: WorkosProvisioningStatus.fromWire(
        row['provisioning_status'] as String?,
      ),
      lastEventType:
          (row['last_event_type'] ?? 'dsync.user.created').toString(),
      lastSyncedAt: DateTime.tryParse(
            (row['last_synced_at'] ?? '').toString(),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      supabaseUserId: row['supabase_user_id'] as String?,
    );
  }

  WorkosScimEvent _mapEvent(final Map<String, Object?> row) {
    return WorkosScimEvent(
      id: (row['id'] ?? '').toString(),
      workosOrgId: (row['workos_org_id'] ?? '').toString(),
      workosEventId: (row['workos_event_id'] ?? '').toString(),
      eventType: (row['event_type'] ?? '').toString(),
      directoryUserId: (row['directory_user_id'] ?? '').toString(),
      targetStatus: WorkosProvisioningStatus.fromWire(
        row['target_status'] as String?,
      ),
      processedAt: DateTime.tryParse(
            (row['processed_at'] ?? '').toString(),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  List<T> _mapRows<T>(
    final List<Object?> rows,
    final T Function(Map<String, Object?>) mapper,
  ) {
    return rows
        .map((final Object? row) => mapper(_asStringKeyMap(row)))
        .toList();
  }

  @override
  Future<List<WorkosOrganization>> fetchOrganizations() async {
    final client = _resolvedClient;
    _requireUserId(client);
    final rows = await client
        .from('workos_organizations')
        .select(
          'id,workos_org_id,organization_name,owner_user_id,scim_enabled,default_role,admin_portal_last_intent,last_portal_generated_at',
        )
        .order('created_at', ascending: false)
        .limit(20);
    return _mapRows(rows, _mapOrg);
  }

  @override
  Future<List<WorkosDirectoryMember>> fetchMembers(
    final String workosOrgId,
  ) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final rows = await client
        .from('workos_directory_memberships')
        .select(
          'id,workos_org_id,workos_directory_user_id,supabase_user_id,email,display_name,role,provisioning_status,last_event_type,last_synced_at',
        )
        .eq('workos_org_id', workosOrgId)
        .order('last_synced_at', ascending: false)
        .limit(100);
    return _mapRows(rows, _mapMember);
  }

  @override
  Future<List<WorkosScimEvent>> fetchRecentEvents(
    final String workosOrgId,
  ) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final rows = await client
        .from('workos_scim_sync_events')
        .select(
          'id,workos_org_id,workos_event_id,event_type,directory_user_id,target_status,processed_at',
        )
        .eq('workos_org_id', workosOrgId)
        .order('processed_at', ascending: false)
        .limit(30);
    return _mapRows(rows, _mapEvent);
  }

  @override
  Future<WorkosOrganization> registerOrganization({
    required final String workosOrgId,
    required final String organizationName,
  }) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final row = await client
        .from('workos_organizations')
        .upsert(
          <String, Object?>{
            'workos_org_id': workosOrgId.trim(),
            'organization_name': organizationName.trim(),
            'owner_user_id': userId,
          },
          onConflict: 'workos_org_id',
        )
        .select(
          'id,workos_org_id,organization_name,owner_user_id,scim_enabled,default_role,admin_portal_last_intent,last_portal_generated_at',
        )
        .single();
    return _mapOrg(_asStringKeyMap(row));
  }

  @override
  Future<WorkosPortalLinkResult> generateAdminPortalLink({
    required final String workosOrgId,
    required final WorkosPortalIntent intent,
    final String? returnUrl,
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final response = await client.functions.invoke(
      'admin-hub',
      body: <String, Object?>{
        'action': 'workos.portal_link',
        'workos_org_id': workosOrgId.trim(),
        'intent': intent.wireValue,
        if (returnUrl != null && returnUrl.trim().isNotEmpty)
          'return_url': returnUrl.trim(),
      },
    );
    final data = _asStringKeyMap(response.data);
    return WorkosPortalLinkResult(
      ok: data['ok'] as bool? ?? false,
      isOfflineFallback: data['fallback'] as bool? ?? false,
      intent: WorkosPortalIntent.fromWire(data['intent'] as String?),
      workosOrgId: (data['workos_org_id'] ?? workosOrgId).toString(),
      portalUrl: data['link'] as String?,
      expiresInSeconds: (data['expires_in_seconds'] as num?)?.toInt() ?? 300,
      message: (data['message'] ?? '').toString(),
    );
  }

  @override
  Future<WorkosDirectoryMember> updateMemberRole({
    required final String workosOrgId,
    required final String directoryUserId,
    required final WorkosOrgRole role,
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final response = await client.functions.invoke(
      'admin-hub',
      body: <String, Object?>{
        'action': 'workos.update_member_role',
        'workos_org_id': workosOrgId.trim(),
        'workos_directory_user_id': directoryUserId.trim(),
        'role': role.wireValue,
      },
    );
    final data = _asStringKeyMap(response.data);
    return _mapMember(_asStringKeyMap(data['member']));
  }
}
