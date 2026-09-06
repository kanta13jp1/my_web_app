export type VideoOperatorResolution =
  | { kind: "user" }
  | { kind: "service_role"; userId: string }
  | { kind: "error"; code: string; status: number };

const SERVICE_ROLE_ACTIONS = new Set([
  "capabilities",
  "authorization_status",
  "run_authorized_improvement",
  "review_authorized_artifact",
  "status",
]);

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function resolveVideoOperator(params: {
  authorization: string;
  serviceRoleKey: string;
  action: string;
  requestedUserId: string;
}): VideoOperatorResolution {
  const serviceRoleKey = params.serviceRoleKey.trim();
  if (
    !serviceRoleKey ||
    params.authorization !== `Bearer ${serviceRoleKey}`
  ) {
    return { kind: "user" };
  }

  if (!SERVICE_ROLE_ACTIONS.has(params.action)) {
    return {
      kind: "error",
      code: "service_role_action_not_allowed",
      status: 403,
    };
  }

  const userId = params.requestedUserId.trim();
  if (!UUID_PATTERN.test(userId)) {
    return {
      kind: "error",
      code: "invalid_service_role_user_id",
      status: 400,
    };
  }

  return { kind: "service_role", userId };
}
