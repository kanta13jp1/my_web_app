/// Domain models & repository contract for Org/IdP Group RBAC & SSO (#2691).
enum IdpProviderKind {
  okta('okta', 'Okta (OIDC / SAML)'),
  azureAd('azure_ad', 'Microsoft Entra ID (Azure AD)'),
  googleWorkspace('google_workspace', 'Google Workspace'),
  workosSso('workos_sso', 'WorkOS SSO'),
  genericOidc('generic_oidc', '汎用 OIDC'),
  genericSaml('generic_saml', '汎用 SAML');

  const IdpProviderKind(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static IdpProviderKind fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final provider in IdpProviderKind.values) {
      if (provider.wireValue == normalized) {
        return provider;
      }
    }
    return IdpProviderKind.okta;
  }
}

enum OrgRbacRole {
  owner('owner', 'オーナー', 4),
  admin('admin', '管理者', 3),
  member('member', 'メンバー', 2),
  viewer('viewer', '閲覧者', 1),
  none('none', 'アクセス不可', 0);

  const OrgRbacRole(this.wireValue, this.label, this.rank);

  final String wireValue;
  final String label;
  final int rank;

  bool satisfies(final OrgRbacRole required) =>
      this != OrgRbacRole.none && rank >= required.rank;

  static OrgRbacRole fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final role in OrgRbacRole.values) {
      if (role.wireValue == normalized) {
        return role;
      }
    }
    return OrgRbacRole.viewer;
  }
}

class OrgUiCapabilities {
  const OrgUiCapabilities({
    required this.role,
    required this.canViewOrg,
    required this.canExecuteMemberActions,
    required this.canManageIdpMappings,
    required this.canAssignOwnerRole,
  });

  factory OrgUiCapabilities.fromRole(final OrgRbacRole role) {
    return OrgUiCapabilities(
      role: role,
      canViewOrg: role != OrgRbacRole.none,
      canExecuteMemberActions: role == OrgRbacRole.owner ||
          role == OrgRbacRole.admin ||
          role == OrgRbacRole.member,
      canManageIdpMappings:
          role == OrgRbacRole.owner || role == OrgRbacRole.admin,
      canAssignOwnerRole: role == OrgRbacRole.owner,
    );
  }

  final OrgRbacRole role;
  final bool canViewOrg;
  final bool canExecuteMemberActions;
  final bool canManageIdpMappings;
  final bool canAssignOwnerRole;
}

class OrgTenantSummary {
  const OrgTenantSummary({
    required this.workosOrgId,
    required this.organizationName,
  });

  final String workosOrgId;
  final String organizationName;
}

class IdpGroupMapping {
  const IdpGroupMapping({
    required this.id,
    required this.workosOrgId,
    required this.idpProvider,
    required this.idpGroupId,
    required this.idpGroupLabel,
    required this.mappedRole,
    required this.priority,
    required this.isActive,
  });

  final String id;
  final String workosOrgId;
  final IdpProviderKind idpProvider;
  final String idpGroupId;
  final String idpGroupLabel;
  final OrgRbacRole mappedRole;
  final int priority;
  final bool isActive;
}

class SsoAuditEntry {
  const SsoAuditEntry({
    required this.id,
    required this.idpProvider,
    required this.resolvedRole,
    required this.resolutionSource,
    required this.overageDetected,
    required this.evaluatedAt,
  });

  final String id;
  final IdpProviderKind idpProvider;
  final OrgRbacRole resolvedRole;
  final String resolutionSource;
  final bool overageDetected;
  final DateTime evaluatedAt;
}

class OrgIdpBundle {
  const OrgIdpBundle({
    required this.callerRole,
    required this.capabilities,
    required this.mappings,
    required this.audits,
  });

  final OrgRbacRole callerRole;
  final OrgUiCapabilities capabilities;
  final List<IdpGroupMapping> mappings;
  final List<SsoAuditEntry> audits;
}

class SsoEvaluationResult {
  const SsoEvaluationResult({
    required this.allowed,
    required this.resolvedRole,
    required this.resolutionSource,
    required this.overageDetected,
    required this.matchedGroups,
    required this.warnings,
    required this.capabilities,
  });

  final bool allowed;
  final OrgRbacRole resolvedRole;
  final String resolutionSource;
  final bool overageDetected;
  final List<String> matchedGroups;
  final List<String> warnings;
  final OrgUiCapabilities capabilities;
}

abstract class OrgIdpRbacRepository {
  Future<List<OrgTenantSummary>> fetchOrganizations();

  Future<OrgIdpBundle> fetchOrgIdpState(final String workosOrgId);

  Future<IdpGroupMapping> upsertMapping({
    required final String workosOrgId,
    required final IdpProviderKind idpProvider,
    required final String idpGroupId,
    required final String idpGroupLabel,
    required final OrgRbacRole mappedRole,
    required final int priority,
  });

  Future<void> deleteMapping({
    required final String workosOrgId,
    required final String mappingId,
  });

  Future<SsoEvaluationResult> evaluateSsoAssertion({
    required final String workosOrgId,
    required final IdpProviderKind idpProvider,
    required final List<String> assertedGroups,
    required final bool simulateAzureOverage,
    required final OrgRbacRole requiredRole,
  });
}
