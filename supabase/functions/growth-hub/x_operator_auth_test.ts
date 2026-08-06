import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { isUuid, resolveXLogOwnerUserId } from "./x_operator_auth.ts";

const OWNER = "123e4567-e89b-42d3-a456-426614174000";

Deno.test("only service role may bind an X log to an owner", () => {
  assertEquals(resolveXLogOwnerUserId("service_role", OWNER), OWNER);
  assertEquals(
    resolveXLogOwnerUserId("user-a", OWNER),
    "user-a",
  );
  assertEquals(
    resolveXLogOwnerUserId("service_role", "../../spoof"),
    "service_role",
  );
});

Deno.test("operator owner IDs use strict UUID syntax", () => {
  assertEquals(isUuid(OWNER), true);
  assertEquals(isUuid(""), false);
  assertEquals(isUuid("service_role"), false);
});
