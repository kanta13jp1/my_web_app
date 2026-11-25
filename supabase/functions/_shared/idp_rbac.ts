import type { WorkosOrgRole } from "./workos_scim.ts";

export type IdpProviderKind =
  | "okta"
  | "azure_ad"
  | "google_workspace"
  | "workos_sso"
  | "generic_oidc"
  | "generic_saml";

export type IdpRoleResolutionSource =
  | "idp_group_mapping"
  | "scim_directory"
  | "org_owner"
  | "overage_denied"
  | "no_matching_group";

export const VALID_IDP_PROVIDERS: ReadonlySet<IdpProviderKind> = new Set([
  "okta",
  "azure_ad",
  "google_workspace",
  "workos_sso",
  "generic_oidc",
  "generic_saml",
]);

const ROLE_PRIORITY: Record<WorkosOrgRole, number> = {
  owner: 4,
  admin: 3,
  member: 2,
  viewer: 1,
};

export interface IdpGroupMappingRule {
  id: string;
  workos_org_id: string;
  idp_provider: IdpProviderKind;
  idp_group_id: string;
  idp_group_label: string;
  mapped_role: WorkosOrgRole;
  priority: number;
  is_active: boolean;
}

export interface NormalizedIdpAssertion {
  provider: IdpProviderKind;
  subject: string;
  groups: string[];
  overageDetected: boolean;
  warnings: string[];
}

export interface IdpRbacEvaluation {
  allowed: boolean;
  resolvedRole: WorkosOrgRole | "none";
  resolutionSource: IdpRoleResolutionSource;
  overageDetected: boolean;
  matchedGroups: string[];
  warnings: string[];
  appMetadataClaims: Record<string, unknown>;
}

const OKTA_OIDC_GROUP_CAP = 100;

function extractStringList(raw: unknown): string[] {
  if (Array.isArray(raw)) {
    return raw
      .map((item) => String(item ?? "").trim())
      .filter((val) => val.length > 0)
      .slice(0, 250);
  }
  if (typeof raw === "string" && raw.trim().length > 0) {
    return raw
      .split(/[,;\s]+/)
      .map((val) => val.trim())
      .filter((val) => val.length > 0)
      .slice(0, 250);
  }
  return [];
}

/**
 * Normalizes SAML/OIDC group claims across Okta, Microsoft Entra ID (Azure AD),
 * Google Workspace, and WorkOS SSO while detecting overage / truncation edges.
 */
export function normalizeIdpGroupAssertion(input: {
  provider: string;
  claims: Record<string, unknown>;
  claimSource?: "app_metadata" | "id_token" | "saml" | "user_metadata";
}): NormalizedIdpAssertion {
  const providerRaw = input.provider.trim().toLowerCase() as IdpProviderKind;
  const provider: IdpProviderKind = VALID_IDP_PROVIDERS.has(providerRaw)
    ? providerRaw
    : "generic_oidc";
  const claims = input.claims;
  const warnings: string[] = [];

  if (input.claimSource === "user_metadata") {
    return {
      provider,
      subject: String(claims.sub ?? "").trim(),
      groups: [],
      overageDetected: false,
      warnings: ["Rejected untrusted user_metadata group claim source"],
    };
  }

  const subject = String(
    claims.sub ?? claims.nameid ?? claims.idp_id ?? "",
  ).trim().slice(0, 200);

  const rawGroups = claims.groups ??
    claims.idp_groups ??
    claims["http://schemas.xmlsoap.org/claims/Group"] ??
    claims["http://schemas.microsoft.com/ws/2008/06/identity/claims/groups"];
  const groups = Array.from(new Set(extractStringList(rawGroups)));

  let overageDetected = false;
  const claimNames = claims._claim_names;
  const hasAzureOverage = claims.hasgroups === true ||
    (claimNames !== null && typeof claimNames === "object" &&
      !Array.isArray(claimNames) &&
      "groups" in (claimNames as Record<string, unknown>));

  if (provider === "azure_ad" && hasAzureOverage) {
    overageDetected = true;
    warnings.push(
      "Microsoft Entra ID group overage detected (hasgroups/_claim_names); use App Roles or Graph lookup",
    );
  }

  if (provider === "okta" && groups.length >= OKTA_OIDC_GROUP_CAP) {
    overageDetected = true;
    warnings.push(
      "Okta group claim reached 100-group expression cap; filter groups or use Graph/SCIM",
    );
  }

  if (
    provider === "azure_ad" &&
    groups.length > 0 &&
    groups.some((item) => !/^[0-9a-f-]{36}$/i.test(item))
  ) {
    warnings.push(
      "Entra ID returned non-GUID group names; verify Group Claims emits Object IDs or App Roles cleanly",
    );
  }

  return {
    provider,
    subject,
    groups,
    overageDetected,
    warnings,
  };
}

export function evaluateIdpGroupRbac(input: {
  workosOrgId: string;
  assertion: NormalizedIdpAssertion;
  mappings: readonly IdpGroupMappingRule[];
  isOrgOwner?: boolean;
  existingScimRole?: WorkosOrgRole | null;
  requiredRole?: WorkosOrgRole;
  existingAppMetadata?: Record<string, unknown>;
}): IdpRbacEvaluation {
  const required = input.requiredRole ?? "viewer";
  const prevMeta = input.existingAppMetadata ?? {};
  const prevOrgRoles =
    prevMeta.org_roles !== null && typeof prevMeta.org_roles === "object" &&
      !Array.isArray(prevMeta.org_roles)
      ? { ...(prevMeta.org_roles as Record<string, unknown>) }
      : {};

  if (input.isOrgOwner) {
    const claimsOut = {
      ...prevMeta,
      idp_provider: input.assertion.provider,
      idp_group_overage: false,
      idp_groups: input.assertion.groups.slice(0, 50),
      org_roles: { ...prevOrgRoles, [input.workosOrgId]: "owner" },
    };
    return {
      allowed: true,
      resolvedRole: "owner",
      resolutionSource: "org_owner",
      overageDetected: false,
      matchedGroups: [],
      warnings: input.assertion.warnings,
      appMetadataClaims: claimsOut,
    };
  }

  if (input.assertion.overageDetected && !input.existingScimRole) {
    return {
      allowed: false,
      resolvedRole: "none",
      resolutionSource: "overage_denied",
      overageDetected: true,
      matchedGroups: [],
      warnings: input.assertion.warnings,
      appMetadataClaims: {
        ...prevMeta,
        idp_provider: input.assertion.provider,
        idp_group_overage: true,
        idp_groups: [],
        org_roles: prevOrgRoles,
      },
    };
  }

  const groupSet = new Set(input.assertion.groups.map((g) => g.toLowerCase()));
  const matched = input.mappings
    .filter(
      (rule) =>
        rule.is_active &&
        rule.workos_org_id === input.workosOrgId &&
        rule.idp_provider === input.assertion.provider &&
        groupSet.has(rule.idp_group_id.trim().toLowerCase()),
    )
    .sort((a, b) => {
      const roleDiff = ROLE_PRIORITY[b.mapped_role] -
        ROLE_PRIORITY[a.mapped_role];
      return roleDiff !== 0 ? roleDiff : a.priority - b.priority;
    });

  let resolvedRole: WorkosOrgRole | "none" = "none";
  let source: IdpRoleResolutionSource = "no_matching_group";

  if (matched.length > 0) {
    resolvedRole = matched[0].mapped_role;
    source = "idp_group_mapping";
  }

  if (
    input.existingScimRole &&
    (resolvedRole === "none" ||
      ROLE_PRIORITY[input.existingScimRole] > ROLE_PRIORITY[resolvedRole])
  ) {
    resolvedRole = input.existingScimRole;
    source = "scim_directory";
  }

  const allowed = resolvedRole !== "none" &&
    ROLE_PRIORITY[resolvedRole] >= ROLE_PRIORITY[required];

  const nextOrgRoles = resolvedRole === "none"
    ? prevOrgRoles
    : { ...prevOrgRoles, [input.workosOrgId]: resolvedRole };

  return {
    allowed,
    resolvedRole,
    resolutionSource: source,
    overageDetected: input.assertion.overageDetected,
    matchedGroups: matched.map((m) => m.idp_group_id),
    warnings: input.assertion.warnings,
    appMetadataClaims: {
      ...prevMeta,
      idp_provider: input.assertion.provider,
      idp_group_overage: input.assertion.overageDetected,
      idp_groups: input.assertion.groups.slice(0, 50),
      org_roles: nextOrgRoles,
    },
  };
}
