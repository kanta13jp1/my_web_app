function constantTimeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  let mismatch = leftBytes.length ^ rightBytes.length;
  const length = Math.max(leftBytes.length, rightBytes.length);
  for (let index = 0; index < length; index++) {
    mismatch |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return mismatch === 0;
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

const CLOUD_INVENTORY_ACTIONS = new Set([
  "inventory.plan_expand",
  "inventory.expand",
]);

export function isCloudInventoryActionAllowed(action: string): boolean {
  return CLOUD_INVENTORY_ACTIONS.has(action);
}

export function resolveCloudInventoryOwner(args: {
  authorization: string;
  serviceRoleKey: string;
  requestedOwner: string;
}): string | null {
  const requestedOwner = args.requestedOwner.trim().toLowerCase();
  if (
    args.serviceRoleKey === "" ||
    !constantTimeEqual(
      args.authorization,
      `Bearer ${args.serviceRoleKey}`,
    ) ||
    !isUuid(requestedOwner)
  ) {
    return null;
  }
  return requestedOwner;
}
