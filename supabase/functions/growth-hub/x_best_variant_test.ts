import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { hasNamedVariant, pickBestVariant } from "./x_best_variant.ts";

Deno.test("pickBestVariant: unknown バケットが先頭でも除外して次点を返す", () => {
  const variants = [
    { variant: "unknown" },
    { variant: "daily_briefing" },
    { variant: "daily_briefing_v2_numbers" },
  ];
  assertEquals(pickBestVariant(variants), "daily_briefing");
});

Deno.test("pickBestVariant: named が先頭ならそのまま返す", () => {
  const variants = [
    { variant: "daily_briefing_fallback" },
    { variant: "unknown" },
  ];
  assertEquals(pickBestVariant(variants), "daily_briefing_fallback");
});

Deno.test("pickBestVariant: 全行 unknown / 空は fallback へ", () => {
  assertEquals(pickBestVariant([{ variant: "unknown" }]), "daily_briefing");
  assertEquals(pickBestVariant([]), "daily_briefing");
  assertEquals(pickBestVariant([], "question_post"), "question_post");
});

Deno.test("hasNamedVariant: unknown のみ→false / named 混在→true", () => {
  assertEquals(hasNamedVariant([{ variant: "unknown" }]), false);
  assertEquals(hasNamedVariant([]), false);
  assertEquals(
    hasNamedVariant([{ variant: "unknown" }, { variant: "daily_briefing" }]),
    true,
  );
});
