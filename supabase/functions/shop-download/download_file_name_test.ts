import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { safeDownloadFileName } from "./download_file_name.ts";

Deno.test("configured Japanese file name is preserved", () => {
  assertEquals(
    safeDownloadFileName("制作テンプレート-v2.zip", "template", "2"),
    "制作テンプレート-v2.zip",
  );
});

Deno.test("path separators and control characters cannot escape the filename", () => {
  const value = safeDownloadFileName(
    "../private\\secret\nasset.zip",
    "prompt-pack",
    "1.0",
  );
  assertFalse(value.includes("/"));
  assertFalse(value.includes("\\"));
  assertFalse(value.includes("\n"));
});

Deno.test("blank configured name falls back to a stable product filename", () => {
  assertEquals(
    safeDownloadFileName(" ", "idea-pack", "3"),
    "idea-pack-v3.zip",
  );
});
