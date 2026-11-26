/// WorkOS Admin Portal & Directory Sync (SCIM) domain models (#2683).
enum WorkosPortalIntent {
  dsync('dsync', 'Directory Sync (SCIM)'),
  sso('sso', 'SAML / OIDC SSO'),
  auditLogs('audit_logs', '監査ログ'),
  logStreams('log_streams', 'ログストリーム'),
  domainVerification('domain_verification', 'ドメイン認証'),
  certificateRenewal('certificate_renewal', '証明書更新');

  const WorkosPortalIntent(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static WorkosPortalIntent fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final intent in WorkosPortalIntent.values) {
      if (intent.wireValue == normalized) {
        return intent;
      }
    }
    return WorkosPortalIntent.dsync;
  }
}

enum WorkosProvisioningStatus {
  active('active', '有効 (Active)'),
  suspended('suspended', '停止中 (Suspended)'),
  deprovisioned('deprovisioned', '剥奪済み (Deprovisioned)');

  const WorkosProvisioningStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static WorkosProvisioningStatus fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final status in WorkosProvisioningStatus.values) {
      if (status.wireValue == normalized) {
        return status;
      }
    }
    return WorkosProvisioningStatus.active;
  }
}

enum WorkosOrgRole {
  owner('owner', 'オーナー', 4),
  admin('admin', '管理者', 3),
  member('member', 'メンバー', 2),
  viewer('viewer', '閲覧者', 1);

  const WorkosOrgRole(this.wireValue, this.label, this.rank);

  final String wireValue;
  final String label;
  final int rank;

  bool satisfies(final WorkosOrgRole requiredRole) => rank >= requiredRole.rank;

  static WorkosOrgRole fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final role in WorkosOrgRole.values) {
      if (role.wireValue == normalized) {
        return role;
      }
    }
    return WorkosOrgRole.member;
  }
}

class WorkosOrganization {
  const WorkosOrganization({
    required this.id,
    required this.workosOrgId,
    required this.organizationName,
    required this.ownerUserId,
    required this.scimEnabled,
    required this.defaultRole,
    required this.lastIntent,
    this.lastPortalGeneratedAt,
  });

  final String id;
  final String workosOrgId;
  final String organizationName;
  final String ownerUserId;
  final bool scimEnabled;
  final WorkosOrgRole defaultRole;
  final WorkosPortalIntent lastIntent;
  final DateTime? lastPortalGeneratedAt;

  WorkosOrganization copyWith({
    final String? organizationName,
    final bool? scimEnabled,
    final WorkosPortalIntent? lastIntent,
    final DateTime? lastPortalGeneratedAt,
  }) {
    return WorkosOrganization(
      id: id,
      workosOrgId: workosOrgId,
      organizationName: organizationName ?? this.organizationName,
      ownerUserId: ownerUserId,
      scimEnabled: scimEnabled ?? this.scimEnabled,
      defaultRole: defaultRole,
      lastIntent: lastIntent ?? this.lastIntent,
      lastPortalGeneratedAt:
          lastPortalGeneratedAt ?? this.lastPortalGeneratedAt,
    );
  }
}

class WorkosDirectoryMember {
  const WorkosDirectoryMember({
    required this.id,
    required this.workosOrgId,
    required this.directoryUserId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    required this.lastEventType,
    required this.lastSyncedAt,
    this.supabaseUserId,
  });

  final String id;
  final String workosOrgId;
  final String directoryUserId;
  final String email;
  final String displayName;
  final WorkosOrgRole role;
  final WorkosProvisioningStatus status;
  final String lastEventType;
  final DateTime lastSyncedAt;
  final String? supabaseUserId;

  bool canAccess({
    required final bool orgScimEnabled,
    required final WorkosOrgRole requiredRole,
  }) {
    if (!orgScimEnabled) {
      return false;
    }
    if (status != WorkosProvisioningStatus.active) {
      return false;
    }
    return role.satisfies(requiredRole);
  }

  WorkosDirectoryMember copyWith({
    final WorkosOrgRole? role,
    final WorkosProvisioningStatus? status,
    final DateTime? lastSyncedAt,
  }) {
    return WorkosDirectoryMember(
      id: id,
      workosOrgId: workosOrgId,
      directoryUserId: directoryUserId,
      email: email,
      displayName: displayName,
      role: role ?? this.role,
      status: status ?? this.status,
      lastEventType: lastEventType,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      supabaseUserId: supabaseUserId,
    );
  }
}

class WorkosScimEvent {
  const WorkosScimEvent({
    required this.id,
    required this.workosOrgId,
    required this.workosEventId,
    required this.eventType,
    required this.directoryUserId,
    required this.targetStatus,
    required this.processedAt,
  });

  final String id;
  final String workosOrgId;
  final String workosEventId;
  final String eventType;
  final String directoryUserId;
  final WorkosProvisioningStatus targetStatus;
  final DateTime processedAt;
}

class WorkosPortalLinkResult {
  const WorkosPortalLinkResult({
    required this.ok,
    required this.isOfflineFallback,
    required this.intent,
    required this.workosOrgId,
    required this.message,
    this.portalUrl,
    this.expiresInSeconds = 300,
  });

  final bool ok;
  final bool isOfflineFallback;
  final WorkosPortalIntent intent;
  final String workosOrgId;
  final String message;
  final String? portalUrl;
  final int expiresInSeconds;
}

abstract class WorkosScimRepository {
  Future<List<WorkosOrganization>> fetchOrganizations();

  Future<List<WorkosDirectoryMember>> fetchMembers(final String workosOrgId);

  Future<List<WorkosScimEvent>> fetchRecentEvents(final String workosOrgId);

  Future<WorkosOrganization> registerOrganization({
    required final String workosOrgId,
    required final String organizationName,
  });

  Future<WorkosPortalLinkResult> generateAdminPortalLink({
    required final String workosOrgId,
    required final WorkosPortalIntent intent,
    final String? returnUrl,
  });

  Future<WorkosDirectoryMember> updateMemberRole({
    required final String workosOrgId,
    required final String directoryUserId,
    required final WorkosOrgRole role,
  });
}
