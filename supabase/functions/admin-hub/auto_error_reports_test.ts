import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  extractAutoErrorFirstLine,
  mapAutoErrorReports,
} from "./auto_error_reports.ts";

Deno.test("extractAutoErrorFirstLine: ヘッダ行を飛ばし最初の意味行を返す", () => {
  const msg =
    "[自動エラー報告]\nNull check operator used on a null value\n\n#0 foo\n#1 bar";
  assertEquals(
    extractAutoErrorFirstLine(msg),
    "Null check operator used on a null value",
  );
});

Deno.test("extractAutoErrorFirstLine: 空/ヘッダのみは空文字", () => {
  assertEquals(extractAutoErrorFirstLine(""), "");
  assertEquals(extractAutoErrorFirstLine("[自動エラー報告]"), "");
});

Deno.test("extractAutoErrorFirstLine: 長い行は140字で省略", () => {
  const long = "E".repeat(200);
  const out = extractAutoErrorFirstLine(`[自動エラー報告]\n${long}`);
  assertEquals(out.length, 139); // 138 + "…"
  assertEquals(out.endsWith("…"), true);
});

Deno.test("mapAutoErrorReports: 行を写像し先頭行を抽出", () => {
  const rows = [
    {
      id: "a1",
      created_at: "2026-07-18T09:00:00Z",
      metadata: {
        source: "auto_error_report",
        message: "[自動エラー報告]\nRangeError: index out of range\n#0 x",
      },
    },
    { id: 2, created_at: "2026-07-18T08:00:00Z", metadata: { message: "" } },
  ];
  const out = mapAutoErrorReports(rows);
  assertEquals(out.length, 2);
  assertEquals(out[0].id, "a1");
  assertEquals(out[0].firstLine, "RangeError: index out of range");
  assertEquals(out[0].createdAt, "2026-07-18T09:00:00Z");
  assertEquals(out[1].id, "2");
  assertEquals(out[1].firstLine, "");
});

Deno.test("mapAutoErrorReports: null/空入力は空配列", () => {
  assertEquals(mapAutoErrorReports(null), []);
  assertEquals(mapAutoErrorReports(undefined), []);
  assertEquals(mapAutoErrorReports([]), []);
});
