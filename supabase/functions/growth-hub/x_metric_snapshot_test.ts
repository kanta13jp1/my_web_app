import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { compactXMetricSnapshotMedia } from "./x_metric_snapshot.ts";

Deno.test("metric snapshots retain media presence without copying a data URL", () => {
  const metadata = {
    media_url: `data:image/png;base64,${"a".repeat(2 * 1024 * 1024)}`,
  };

  const compact = compactXMetricSnapshotMedia(metadata);

  assertEquals(compact, { has_media: true });
  assert(!Object.hasOwn(compact, "media_url"));
  assert(JSON.stringify(compact).length < 64);
});
