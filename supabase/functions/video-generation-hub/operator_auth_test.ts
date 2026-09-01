import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { resolveVideoOperator } from "./operator_auth.ts";

const SERVICE_ROLE_KEY = "service-role-secret";
const USER_ID = "11111111-1111-4111-8111-111111111111";

Deno.test("service role may inspect and resume one explicit owner", () => {
  for (
    const action of [
      "authorization_status",
      "run_authorized_improvement",
      "status",
    ]
  ) {
    assertEquals(
      resolveVideoOperator({
        authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        serviceRoleKey: SERVICE_ROLE_KEY,
        action,
        requestedUserId: USER_ID,
      }),
      { kind: "service_role", userId: USER_ID },
    );
  }
});

Deno.test("service role cannot mint authorization or bypass normal creation", () => {
  for (
    const action of [
      "authorize_improvement",
      "create",
      "review_artifact",
      "revoke_authorization",
    ]
  ) {
    assertEquals(
      resolveVideoOperator({
        authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        serviceRoleKey: SERVICE_ROLE_KEY,
        action,
        requestedUserId: USER_ID,
      }),
      {
        kind: "error",
        code: "service_role_action_not_allowed",
        status: 403,
      },
    );
  }
});

Deno.test("service role requires one valid explicit owner UUID", () => {
  assertEquals(
    resolveVideoOperator({
      authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      serviceRoleKey: SERVICE_ROLE_KEY,
      action: "run_authorized_improvement",
      requestedUserId: "",
    }),
    {
      kind: "error",
      code: "invalid_service_role_user_id",
      status: 400,
    },
  );
  assertEquals(
    resolveVideoOperator({
      authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      serviceRoleKey: SERVICE_ROLE_KEY,
      action: "authorization_status",
      requestedUserId: "../../other-owner",
    }),
    {
      kind: "error",
      code: "invalid_service_role_user_id",
      status: 400,
    },
  );
});

Deno.test("non-service bearer stays on the normal user auth path", () => {
  assertEquals(
    resolveVideoOperator({
      authorization: "Bearer user-access-token",
      serviceRoleKey: SERVICE_ROLE_KEY,
      action: "run_authorized_improvement",
      requestedUserId: USER_ID,
    }),
    { kind: "user" },
  );
});
