import {
  assertEquals,
  assertMatch,
  assertNotEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { inventoryExpansionPlanSha256 } from "./inventory_expansion_plan.ts";

const CANDIDATE = {
  id: "11111111-1111-4111-8111-111111111111",
  source_id: "page:22222222-2222-4222-8222-222222222222",
  source_kind: "page",
  metadata: { inventory_cursor: null, private_title: "never hashed" },
};

Deno.test("inventory expansion plan is deterministic and content-minimal", async () => {
  const first = await inventoryExpansionPlanSha256([CANDIDATE]);
  const second = await inventoryExpansionPlanSha256([
    { ...CANDIDATE, metadata: { private_title: "different private value" } },
  ]);

  assertMatch(first, /^[0-9a-f]{64}$/);
  assertEquals(first, second);
});

Deno.test("inventory cursor changes invalidate the expansion plan", async () => {
  const first = await inventoryExpansionPlanSha256([CANDIDATE]);
  const second = await inventoryExpansionPlanSha256([
    { ...CANDIDATE, metadata: { inventory_cursor: "next-page" } },
  ]);

  assertNotEquals(first, second);
});

Deno.test("unknown expansion kinds fail closed", async () => {
  await assertRejects(
    () =>
      inventoryExpansionPlanSha256([
        { ...CANDIDATE, source_kind: "private-kind" },
      ]),
    Error,
    "invalid_inventory_expansion_candidate",
  );
});
