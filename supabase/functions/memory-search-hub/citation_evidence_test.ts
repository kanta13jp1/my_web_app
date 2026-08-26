import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildCitationEvidence,
  hasOnlyValidCitationMarkers,
} from "./citation_evidence.ts";

function evidence(
  overrides: Partial<Parameters<typeof buildCitationEvidence>[0]> = {},
) {
  return buildCitationEvidence({
    citationId: "1",
    query: "予算の上限",
    filePath: "docs/roadmap.md",
    title: "Roadmap",
    content: "# Roadmap\n\n予算の上限は月額10万円です。\n承認者はCFOです。",
    snippet: "予算の上限は月額10万円です。",
    sourceType: "doc",
    sourceUrl: "docs/roadmap.md",
    metadata: {},
    confidence: 0.94,
    lastSyncedAt: "2026-08-23T10:00:00Z",
    ...overrides,
  });
}

Deno.test("citation includes file, line location, and exact highlight offsets", () => {
  const citation = evidence();

  assertEquals(citation.citation_id, "1");
  assertEquals(citation.file_name, "roadmap.md");
  assertEquals(citation.position.start_line, 3);
  assertEquals(citation.position.end_line, 3);
  assertEquals(citation.position.label, "line 3");
  assertEquals(citation.highlight_text, "予算の上限は月額10万円です。");
  assertEquals(
    citation.preview_text.slice(
      citation.highlight_start,
      citation.highlight_end,
    ),
    citation.highlight_text,
  );
});

Deno.test("citation preserves indexed page and section metadata", () => {
  const citation = evidence({
    citationId: "2",
    sourceUrl: "https://example.com/files/handbook.pdf?download=1",
    metadata: {
      page_number: 8,
      section: "費用申請",
      start_line: 40,
      end_line: 42,
    },
  });

  assertEquals(citation.citation_id, "2");
  assertEquals(citation.file_name, "handbook.pdf");
  assertEquals(citation.position.page_number, 8);
  assertEquals(citation.position.section, "費用申請");
  assertEquals(citation.position.label, "page 8 · 費用申請 · lines 40-42");
});

Deno.test("citation preview is bounded while retaining the highlighted range", () => {
  const prefix = "前提情報。".repeat(400);
  const highlight = "承認期限は申請から3営業日です。";
  const suffix = "補足情報。".repeat(400);
  const citation = evidence({
    query: "承認期限",
    content: `${prefix}\n${highlight}\n${suffix}`,
    snippet: highlight,
  });

  assert(citation.preview_text.length <= 1600);
  assert(citation.preview_truncated_before);
  assert(citation.preview_truncated_after);
  assertEquals(
    citation.preview_text.slice(
      citation.highlight_start,
      citation.highlight_end,
    ),
    highlight,
  );
});

Deno.test("AI answers require at least one in-range citation marker", () => {
  assert(hasOnlyValidCitationMarkers("根拠です [1]。補足です [2]。", 2));
  assertEquals(hasOnlyValidCitationMarkers("引用のない回答です。", 2), false);
  assertEquals(hasOnlyValidCitationMarkers("範囲外です [3]。", 2), false);
  assertEquals(
    hasOnlyValidCitationMarkers("有効 [1] と範囲外 [9]。", 2),
    false,
  );
});
