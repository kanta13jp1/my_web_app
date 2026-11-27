import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ARTIFACT_SCOPE_LABELS,
  createArtifactRecord,
  resolveLwwRecord,
  validateArtifactKey,
} from "./artifact_kv_storage.ts";

Deno.test(
  "validateArtifactKey enforces namespace:id format",
  () => {
    assertEquals(validateArtifactKey("table:user_prefs").valid, true);
    assertEquals(validateArtifactKey("missing_colon").valid, false);
    assertEquals(validateArtifactKey("a:b:c").valid, false);
    assertEquals(ARTIFACT_SCOPE_LABELS.private, "Private User Scope");
  },
);

Deno.test(
  "resolveLwwRecord keeps newer timestamp on concurrent updates",
  () => {
    const newer = createArtifactRecord(
      "shared",
      "board:layout-1",
      '{"cols":3}',
      "2026-11-27T02:00:00.000Z",
    );
    const stale = createArtifactRecord(
      "shared",
      "board:layout-1",
      '{"cols":2}',
      "2026-11-27T01:00:00.000Z",
    );

    const winner = resolveLwwRecord(newer, stale);
    assertEquals(winner.payloadJson, '{"cols":3}');
    assertEquals(winner.updatedAtIso, "2026-11-27T02:00:00.000Z");
  },
);

Deno.test(
  "createArtifactRecord rejects payloads exceeding max bytes",
  () => {
    assertThrows(
      () =>
        createArtifactRecord(
          "private",
          "note:draft-1",
          "0123456789",
          "2026-11-27T02:00:00.000Z",
          5,
        ),
      Error,
      "exceeds limit 5",
    );
  },
);
