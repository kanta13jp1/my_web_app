import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  isCloudInventoryActionAllowed,
  resolveCloudInventoryOwner,
} from "./cloud_inventory_auth.ts";

const OWNER = "11111111-1111-4111-8111-111111111111";

Deno.test("service role resolves only a valid explicit inventory owner", () => {
  assertEquals(
    resolveCloudInventoryOwner({
      authorization: "Bearer protected-service-role",
      serviceRoleKey: "protected-service-role",
      requestedOwner: OWNER,
    }),
    OWNER,
  );
});

Deno.test("ordinary and malformed credentials cannot select an owner", () => {
  assertEquals(
    resolveCloudInventoryOwner({
      authorization: "Bearer ordinary-user-token",
      serviceRoleKey: "protected-service-role",
      requestedOwner: OWNER,
    }),
    null,
  );
  assertEquals(
    resolveCloudInventoryOwner({
      authorization: "Bearer protected-service-role",
      serviceRoleKey: "",
      requestedOwner: OWNER,
    }),
    null,
  );
  assertEquals(
    resolveCloudInventoryOwner({
      authorization: "Bearer protected-service-role",
      serviceRoleKey: "protected-service-role",
      requestedOwner: "../../another-user",
    }),
    null,
  );
});

Deno.test("cloud inventory service role has a minimal action allowlist", () => {
  assertEquals(isCloudInventoryActionAllowed("inventory.plan_expand"), true);
  assertEquals(isCloudInventoryActionAllowed("inventory.expand"), true);
  assertEquals(isCloudInventoryActionAllowed("inventory.start"), false);
  assertEquals(isCloudInventoryActionAllowed("stage.wbs"), false);
  assertEquals(isCloudInventoryActionAllowed("reconcile.wbs"), false);
});
