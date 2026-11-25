import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  evaluateIdpGroupRbac,
  type IdpGroupMappingRule,
  normalizeIdpGroupAssertion,
} from "./idp_rbac.ts";

const MAPPINGS: IdpGroupMappingRule[] = [
  {
    id: "m1",
    workos_org_id: "org_acme",
    idp_provider: "okta",
    idp_group_id: "acme-admins",
    idp_group_label: "Okta Admins",
    mapped_role: "admin",
    priority: 10,
    is_active: true,
  },
  {
    id: "m2",
    workos_org_id: "org_acme",
    idp_provider: "azure_ad",
    idp_group_id: "11111111-1111-4111-8111-111111111111",
    idp_group_label: "Entra Finance Members",
    mapped_role: "member",
    priority: 50,
    is_active: true,
  },
];

Deno.test("Okta groups resolve highest active role and reject user_metadata", () => {
  const untrusted = normalizeIdpGroupAssertion({
    provider: "okta",
    claims: { groups: ["acme-admins"] },
    claimSource: "user_metadata",
  });
  assertEquals(untrusted.groups.length, 0);

  const okta = normalizeIdpGroupAssertion({
    provider: "okta",
    claims: { sub: "okta-u1", groups: ["viewer-all", "acme-admins"] },
    claimSource: "id_token",
  });
  const decision = evaluateIdpGroupRbac({
    workosOrgId: "org_acme",
    assertion: okta,
    mappings: MAPPINGS,
    requiredRole: "admin",
  });
  assertEquals(decision.allowed, true);
  assertEquals(decision.resolvedRole, "admin");
  assertEquals(decision.resolutionSource, "idp_group_mapping");
  assertEquals(
    (decision.appMetadataClaims.org_roles as Record<string, string>).org_acme,
    "admin",
  );
});

Deno.test("Azure AD GUIDs map cleanly and group overage fails closed", () => {
  const guidOk = normalizeIdpGroupAssertion({
    provider: "azure_ad",
    claims: {
      sub: "aad-u1",
      groups: ["11111111-1111-4111-8111-111111111111"],
    },
    claimSource: "id_token",
  });
  const okDecision = evaluateIdpGroupRbac({
    workosOrgId: "org_acme",
    assertion: guidOk,
    mappings: MAPPINGS,
    requiredRole: "member",
  });
  assertEquals(okDecision.allowed, true);
  assertEquals(okDecision.resolvedRole, "member");

  const overage = normalizeIdpGroupAssertion({
    provider: "azure_ad",
    claims: {
      sub: "aad-u2",
      hasgroups: true,
      _claim_names: { groups: "src1" },
    },
    claimSource: "id_token",
  });
  assertEquals(overage.overageDetected, true);
  const denied = evaluateIdpGroupRbac({
    workosOrgId: "org_acme",
    assertion: overage,
    mappings: MAPPINGS,
    requiredRole: "viewer",
  });
  assertEquals(denied.allowed, false);
  assertEquals(denied.resolvedRole, "none");
  assertEquals(denied.resolutionSource, "overage_denied");
});
