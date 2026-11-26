import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  FACT_STANCE_LABELS,
  LegislativeFactRegistry,
  validateSourceUrl,
} from "./legislative_facts.ts";

Deno.test(
  "validateSourceUrl requires valid http or https URLs",
  () => {
    assertEquals(
      validateSourceUrl("https://www.shugiin.go.jp/example"),
      "https://www.shugiin.go.jp/example",
    );
    assertThrows(() => validateSourceUrl(""));
    assertThrows(() => validateSourceUrl("ftp://example.com/file"));
    assertThrows(() => validateSourceUrl("not-a-url"));
  },
);

Deno.test(
  "buildComparisonMatrix groups facts by faction for a topic",
  () => {
    const registry = new LegislativeFactRegistry();
    registry.registerFact({
      id: "f1",
      topicKey: "emergency-clause",
      factionName: "Faction B",
      summary: "Existing statutory measures cover disaster response.",
      sourceUrl: "https://example.go.jp/statute-a",
      sourceTitle: "Official Statute A",
      stance: "contextual",
    });
    registry.registerFact({
      id: "f2",
      topicKey: "emergency-clause",
      factionName: "Faction A",
      summary: "Diet term extension criteria require explicit rules.",
      sourceUrl: "https://example.go.jp/report-b",
      sourceTitle: "Committee Report B",
      stance: "supporting",
    });

    const matrix = registry.buildComparisonMatrix("emergency-clause");
    assertEquals(matrix.totalFacts, 2);
    assertEquals(matrix.columns.length, 2);
    assertEquals(matrix.columns[0].factionName, "Faction A");
    assertEquals(matrix.columns[1].factionName, "Faction B");
    assertEquals(FACT_STANCE_LABELS.disputed, "Disputed");
  },
);
