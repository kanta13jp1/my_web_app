import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { parseNativeCitations } from "./native_citation_parser.ts";

Deno.test("parses <|answer_start|> envelope and <|source_start|> spans", () => {
  const raw = "<|thought_start|>internal trace<|thought_end|>" +
    "<|answer_start|>Budget cap is " +
    "<|source_start|>1<|source_end|>100k JPY<|/source|> per month." +
    "<|answer_end|>";

  const parsed = parseNativeCitations(raw);
  assertEquals(parsed.has_native_tokens, true);
  assertEquals(parsed.plain_text, "Budget cap is 100k JPY per month.");
  assertEquals(parsed.reference_ids, ["1"]);
  assertEquals(parsed.segments, [
    { text: "Budget cap is " },
    { text: "100k JPY", reference_id: "1" },
    { text: " per month." },
  ]);
});

Deno.test(
  "parses <|citation_start|> spans in both paired and inline forms",
  () => {
    const paired =
      "<|citation_start|>2<|citation_end|>CFO approval<|/citation|>";
    const parsedPaired = parseNativeCitations(paired);
    assertEquals(parsedPaired.has_native_tokens, true);
    assertEquals(parsedPaired.plain_text, "CFO approval");
    assertEquals(parsedPaired.reference_ids, ["2"]);
    assertEquals(parsedPaired.segments, [
      { text: "CFO approval", reference_id: "2" },
    ]);

    const inline = "<|citation_start|>Inline proof [3]<|citation_end|>";
    const parsedInline = parseNativeCitations(inline);
    assertEquals(parsedInline.has_native_tokens, true);
    assertEquals(parsedInline.plain_text, "Inline proof [3]");
    assertEquals(parsedInline.reference_ids, ["3"]);
  },
);

Deno.test("parses <ref> XML spans, [source:N], and [N] markers", () => {
  const raw = '<ref id="doc-1">Primary rule</ref> and [source:2] plus [3].';
  const parsed = parseNativeCitations(raw);

  assertEquals(parsed.has_native_tokens, true);
  assertEquals(parsed.plain_text, "Primary rule and [source:2] plus [3].");
  assertEquals(parsed.reference_ids, ["doc-1", "2", "3"]);
  assertEquals(parsed.segments, [
    { text: "Primary rule", reference_id: "doc-1" },
    { text: " and " },
    { text: "[source:2]", reference_id: "2", marker_only: true },
    { text: " plus " },
    { text: "[3]", reference_id: "3", marker_only: true },
    { text: "." },
  ]);
});

Deno.test(
  "handles bare <ref>, self-closing <ref/>, and ignores markdown links",
  () => {
    const raw =
      "See <ref>4</ref> and <ref source='5' /> and [link](https://a.test).";
    const parsed = parseNativeCitations(raw);

    assertEquals(parsed.has_native_tokens, true);
    assertEquals(parsed.reference_ids, ["4", "5"]);
    assertEquals(
      parsed.plain_text,
      "See [source:4] and [source:5] and [link](https://a.test).",
    );
  },
);

Deno.test("leaves plain text untouched with has_native_tokens=false", () => {
  const parsed = parseNativeCitations("Plain answer without tokens.");
  assertEquals(parsed.has_native_tokens, false);
  assertEquals(parsed.plain_text, "Plain answer without tokens.");
  assertEquals(parsed.reference_ids, []);
  assertEquals(parsed.segments, [{ text: "Plain answer without tokens." }]);
});
